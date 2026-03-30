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

function titleCaseBrand(brand: string | undefined): string {
  if (!brand) return "Card";
  const b = brand.toLowerCase();
  if (b.length <= 1) return brand;
  return b.charAt(0).toUpperCase() + b.slice(1);
}

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
      setup_intent_id?: string;
    };
    const setupIntentId = body.setup_intent_id?.trim();
    if (!setupIntentId) {
      return json({ error: "setup_intent_id required" }, 400);
    }

    const stripe = new Stripe(stripeSecret);
    const si = await stripe.setupIntents.retrieve(setupIntentId);

    if (si.metadata?.supabase_user_id !== user.id) {
      return json({ error: "Forbidden" }, 403);
    }

    if (si.status !== "succeeded") {
      return json(
        { error: `Setup not complete (status: ${si.status})` },
        400,
      );
    }

    const pmId = typeof si.payment_method === "string"
      ? si.payment_method
      : si.payment_method?.id;
    if (!pmId) {
      return json({ error: "No payment method on setup intent" }, 400);
    }

    const pm = await stripe.paymentMethods.retrieve(pmId);
    const card = pm.card;
    if (!card) {
      return json({ error: "Not a card payment method" }, 400);
    }

    const admin = createClient(supabaseUrl, serviceRole);

    const customerId = await getOrCreateStripeCustomer(stripe, admin, user.id);
    await ensurePaymentMethodOnCustomer(stripe, customerId, pmId);

    const { count, error: countErr } = await admin
      .from("payment_methods")
      .select("id", { count: "exact", head: true })
      .eq("user_id", user.id);

    if (countErr) {
      return json({ error: "Could not check existing cards" }, 500);
    }

    const isDefault = (count ?? 0) === 0;

    if (isDefault) {
      await admin
        .from("payment_methods")
        .update({ is_default: false })
        .eq("user_id", user.id);
    }

    const { data: inserted, error: insErr } = await admin
      .from("payment_methods")
      .insert({
        user_id: user.id,
        stripe_payment_method_id: pm.id,
        brand: titleCaseBrand(card.brand),
        last4: card.last4 ?? "",
        exp_month: card.exp_month,
        exp_year: card.exp_year,
        is_default: isDefault,
      })
      .select("id")
      .single();

    if (insErr || !inserted?.id) {
      console.error(insErr);
      return json(
        { error: insErr?.message ?? "Could not save payment method" },
        500,
      );
    }

    return json({ ok: true, payment_method_id: inserted.id as string }, 200);
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
