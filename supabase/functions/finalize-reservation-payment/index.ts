import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import Stripe from "npm:stripe@17.4.0";

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
      payment_intent_id?: string;
    };
    const paymentIntentId = body.payment_intent_id?.trim();
    if (!paymentIntentId) {
      return json({ error: "payment_intent_id required" }, 400);
    }

    const stripe = new Stripe(stripeSecret);

    const pi = await stripe.paymentIntents.retrieve(paymentIntentId);
    if (pi.status !== "succeeded") {
      return json(
        { error: `Payment not completed (status: ${pi.status})` },
        400,
      );
    }

    const paymentId = pi.metadata?.payment_id;
    if (!paymentId) {
      return json({ error: "Missing payment metadata" }, 400);
    }

    const admin = createClient(supabaseUrl, serviceRole);
    const { data: pay, error: payErr } = await admin
      .from("payments")
      .select("id,reservation_id,stripe_payment_intent_id")
      .eq("id", paymentId)
      .maybeSingle();

    if (payErr || !pay) {
      return json({ error: "Payment row not found" }, 404);
    }
    if (pay.stripe_payment_intent_id !== paymentIntentId) {
      return json({ error: "Payment intent mismatch" }, 400);
    }

    const { data: res, error: resErr } = await admin
      .from("reservations")
      .select("id,driver_id")
      .eq("id", pay.reservation_id as string)
      .maybeSingle();

    if (resErr || !res || res.driver_id !== user.id) {
      return json({ error: "Forbidden" }, 403);
    }

    await admin
      .from("payments")
      .update({ status: "succeeded" })
      .eq("id", pay.id);

    await admin
      .from("reservations")
      .update({ status: "confirmed" })
      .eq("id", pay.reservation_id as string);

    return json({ ok: true }, 200);
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
