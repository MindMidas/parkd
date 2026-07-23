import "jsr:@supabase/functions-js@2/edge-runtime.d.ts";

import { adminClient, runtimeConfig, stripeClient } from "../_shared/runtime.ts";
import { authenticateRateLimited } from "../_shared/rate_limit.ts";
import { finalizeReservationPaymentHandler } from "./handler.ts";

const config = runtimeConfig();
const stripe = stripeClient(config.stripeSecretKey);
const admin = adminClient(config);

const handler = finalizeReservationPaymentHandler({
  authenticate: (req) =>
    authenticateRateLimited(req, config, admin, "payment_finalize", {
      userLimit: 30,
      ipLimit: 60,
      windowSeconds: 60,
    }),
  async retrievePaymentIntent(id) {
    const intent = await stripe.paymentIntents.retrieve(id);
    return {
      id: intent.id,
      status: intent.status,
      livemode: intent.livemode,
      amountReceived: intent.amount_received,
      currency: intent.currency,
      metadata: intent.metadata,
    };
  },
  async finalizeVerifiedPayment(input) {
    const { data, error } = await admin.rpc("finalize_verified_stripe_payment", {
      p_user_id: input.userId,
      p_payment_intent_id: input.paymentIntentId,
      p_payment_id: input.paymentId,
      p_reservation_id: input.reservationId,
      p_amount_cents: input.amountCents,
      p_currency: input.currency,
    });
    if (error) throw error;
    const row = Array.isArray(data) ? data[0] : data;
    const outcome = typeof row === "string"
      ? row
      : row && typeof row === "object"
      ? (row as Record<string, unknown>).outcome
      : null;
    return outcome === "already_processed" ? "already_processed" : "processed";
  },
});

Deno.serve(handler);
