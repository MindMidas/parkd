import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import Stripe from "npm:stripe@17.4.0";

import {
  ensurePaymentMethodOnCustomer,
  getOrCreateStripeCustomer,
} from "../_shared/stripe_customer.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "Missing authorization" }, 401);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const stripeSecret = Deno.env.get("STRIPE_SECRET_KEY");
    if (!stripeSecret) {
      return json({ error: "STRIPE_SECRET_KEY not configured on project" }, 500);
    }

    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const {
      data: { user },
      error: userErr,
    } = await userClient.auth.getUser();
    if (userErr || !user) {
      return json({ error: "Unauthorized" }, 401);
    }

    const body = await req.json().catch(() => ({})) as {
      reservation_id?: string;
      /** Our `payment_methods.id` row (must belong to caller, with Stripe id set). */
      payment_method_id?: string;
    };
    const reservationId = body.reservation_id?.trim();
    if (!reservationId) {
      return json({ error: "reservation_id required" }, 400);
    }

    const admin = createClient(supabaseUrl, serviceRole);
    const { data: res, error: resErr } = await admin
      .from("reservations")
      .select("id,driver_id,status")
      .eq("id", reservationId)
      .maybeSingle();

    if (resErr || !res) {
      return json({ error: "Reservation not found" }, 404);
    }
    if (res.driver_id !== user.id) {
      return json({ error: "Forbidden" }, 403);
    }
    if (res.status !== "pending") {
      return json({ error: "Reservation is not awaiting payment" }, 400);
    }

    const { data: pay, error: payErr } = await admin
      .from("payments")
      .select("id,amount,service_fee,status,stripe_payment_intent_id")
      .eq("reservation_id", reservationId)
      .maybeSingle();

    if (payErr || !pay) {
      return json({ error: "Payment row not found" }, 404);
    }
    if (pay.status !== "pending") {
      return json({ error: "Payment already processed" }, 400);
    }

    let stripePmId: string | undefined;
    const ourPmUuid = body.payment_method_id?.trim();
    if (ourPmUuid) {
      const { data: pmRow, error: pmErr } = await admin
        .from("payment_methods")
        .select("stripe_payment_method_id")
        .eq("id", ourPmUuid)
        .eq("user_id", user.id)
        .maybeSingle();
      if (pmErr || !pmRow) {
        return json({ error: "Payment method not found" }, 404);
      }
      const sid = pmRow.stripe_payment_method_id as string | null;
      if (!sid?.trim()) {
        return json({
          error:
            "This saved card was not added through Stripe. Remove it and add a card again from Payment methods.",
        }, 400);
      }
      stripePmId = sid.trim();
    }

    const stripe = new Stripe(stripeSecret);

    const amountCents = Math.round(
      (Number(pay.amount) + Number(pay.service_fee)) * 100,
    );
    if (amountCents < 50) {
      return json({ error: "Amount below Stripe minimum" }, 400);
    }

    let stripeCustomerId: string | undefined;
    if (stripePmId) {
      stripeCustomerId = await getOrCreateStripeCustomer(stripe, admin, user.id);
      await ensurePaymentMethodOnCustomer(stripe, stripeCustomerId, stripePmId);
    }

    const metadata = {
      reservation_id: reservationId,
      payment_id: pay.id as string,
    };

    const paymentMethodOn = (pi: Stripe.PaymentIntent): string | undefined => {
      const pm = pi.payment_method;
      return typeof pm === "string" ? pm : pm?.id;
    };

    if (pay.stripe_payment_intent_id) {
      let existing = await stripe.paymentIntents.retrieve(
        pay.stripe_payment_intent_id as string,
      );
      if (existing.status === "succeeded") {
        if (existing.client_secret) {
          return json({ client_secret: existing.client_secret }, 200);
        }
        return json({ error: "Payment already completed" }, 400);
      }
      const reusableStatuses = [
        "requires_payment_method",
        "requires_confirmation",
        "requires_action",
        "processing",
      ];
      const attached0 = paymentMethodOn(existing);
      const pmMatches0 =
        !stripePmId ||
        (attached0 != null && attached0 === stripePmId);

      if (
        stripePmId &&
        pmMatches0 &&
        existing.status === "requires_confirmation" &&
        attached0 === stripePmId
      ) {
        try {
          existing = await stripe.paymentIntents.confirm(existing.id);
        } catch (err) {
          const msg = err instanceof Error ? err.message : "Card was declined";
          return json({ error: msg }, 402);
        }
      }

      const st = existing.status;
      const reusable = reusableStatuses.includes(st);
      if (
        existing.client_secret &&
        pmMatches0 &&
        (st === "succeeded" || reusable)
      ) {
        return json({ client_secret: existing.client_secret }, 200);
      }

      if (
        reusable &&
        stripePmId &&
        (existing.status === "requires_payment_method" ||
          existing.status === "requires_confirmation")
      ) {
        await stripe.paymentIntents.cancel(existing.id).catch(() => {});
      }
    }

    let pi: Stripe.PaymentIntent;
    if (stripePmId) {
      try {
        pi = await stripe.paymentIntents.create({
          amount: amountCents,
          currency: "cad",
          customer: stripeCustomerId!,
          payment_method: stripePmId,
          payment_method_types: ["card"],
          confirm: true,
          metadata,
        });
      } catch (err) {
        const msg = err instanceof Error ? err.message : "Card payment failed";
        return json({ error: msg }, 402);
      }
    } else {
      pi = await stripe.paymentIntents.create({
        amount: amountCents,
        currency: "cad",
        automatic_payment_methods: { enabled: true },
        metadata,
      });
    }

    await admin
      .from("payments")
      .update({ stripe_payment_intent_id: pi.id })
      .eq("id", pay.id);

    return json({ client_secret: pi.client_secret }, 200);
  } catch (e) {
    console.error(e);
    return json({ error: (e as Error).message ?? "Server error" }, 500);
  }
});

function json(body: Record<string, unknown>, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
