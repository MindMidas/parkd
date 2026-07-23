import "jsr:@supabase/functions-js@2/edge-runtime.d.ts";
import type Stripe from "npm:stripe@17.4.0";

import { adminClient, runtimeConfig, stripeClient } from "../_shared/runtime.ts";
import { stripeWebhookHandler, type VerifiedWebhookEvent } from "./handler.ts";

const config = runtimeConfig();
const webhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET")?.trim();
if (!webhookSecret?.startsWith("whsec_")) {
  throw new Error("STRIPE_WEBHOOK_SECRET must be configured");
}

const stripe = stripeClient(config.stripeSecretKey);
const admin = adminClient(config);

const handler = stripeWebhookHandler({
  async verifyEvent(payload, signature): Promise<VerifiedWebhookEvent> {
    const event = await stripe.webhooks.constructEventAsync(
      payload,
      signature,
      webhookSecret,
    );
    const object = event.data.object;
    const intent = object.object === "payment_intent" ? object as Stripe.PaymentIntent : null;
    const checkout = object.object === "checkout.session"
      ? object as Stripe.Checkout.Session
      : null;
    return {
      id: event.id,
      type: event.type,
      livemode: event.livemode,
      created: event.created,
      paymentIntent: intent
        ? {
          id: intent.id,
          livemode: intent.livemode,
          amount: intent.amount,
          amountReceived: intent.amount_received,
          currency: intent.currency,
          metadata: intent.metadata,
        }
        : null,
      checkoutSession: checkout
        ? {
          id: checkout.id,
          livemode: checkout.livemode,
          paymentStatus: checkout.payment_status,
          paymentIntentId: typeof checkout.payment_intent === "string"
            ? checkout.payment_intent
            : checkout.payment_intent?.id ?? null,
          amountTotal: checkout.amount_total,
          currency: checkout.currency,
          metadata: checkout.metadata ?? {},
        }
        : null,
    };
  },
  async processEvent(input): Promise<"processed" | "duplicate"> {
    // This SECURITY DEFINER RPC inserts the event receipt and mutates payment +
    // reservation in one transaction. Any error rolls back the receipt so Stripe
    // can safely retry; a repeated event ID returns "duplicate".
    const { data, error } = await admin.rpc("process_stripe_webhook_event", {
      p_event_id: input.eventId,
      p_event_type: input.eventType,
      p_event_created: input.eventCreatedAt,
      p_payment_intent_id: input.paymentIntentId,
      p_checkout_session_id: input.checkoutSessionId,
      p_status: input.eventType === "payment_intent.payment_failed" ||
          input.eventType === "payment_intent.canceled"
        ? "failed"
        : "succeeded",
      p_amount_received: input.amountCents,
      p_currency: input.currency,
    });
    if (error) throw error;
    const row = Array.isArray(data) ? data[0] : data;
    const rawOutcome = typeof row === "string"
      ? row
      : row && typeof row === "object"
      ? (row as Record<string, unknown>).outcome
      : null;
    const wasProcessed = row && typeof row === "object"
      ? (row as Record<string, unknown>).processed
      : null;
    return rawOutcome === "duplicate" || wasProcessed === false ? "duplicate" : "processed";
  },
});

Deno.serve(handler);
