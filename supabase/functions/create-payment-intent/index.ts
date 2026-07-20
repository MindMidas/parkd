import "jsr:@supabase/functions-js@2/edge-runtime.d.ts";
import type Stripe from "npm:stripe@17.4.0";

import { adminClient, runtimeConfig, stripeClient } from "../_shared/runtime.ts";
import { authenticateRateLimited } from "../_shared/rate_limit.ts";
import {
  ensurePaymentMethodOnCustomer,
  getOrCreateStripeCustomer,
} from "../_shared/stripe_customer.ts";
import {
  type CheckoutSessionResult,
  createPaymentIntentHandler,
  type PaymentIntentResult,
  type PreparedCheckout,
} from "./handler.ts";

const config = runtimeConfig();
const admin = adminClient(config);
const stripe = stripeClient(config.stripeSecretKey);
const maxPaymentCents = Number(Deno.env.get("DEMO_MAX_PAYMENT_CENTS") ?? "50000");
if (
  !Number.isSafeInteger(maxPaymentCents) ||
  maxPaymentCents < 50 ||
  maxPaymentCents > 1_000_000
) {
  throw new Error("DEMO_MAX_PAYMENT_CENTS must be an integer from 50 to 1000000");
}

function mapIntent(intent: Stripe.PaymentIntent): PaymentIntentResult {
  const method = intent.payment_method;
  return {
    id: intent.id,
    clientSecret: intent.client_secret,
    status: intent.status,
    livemode: intent.livemode,
    amount: intent.amount,
    currency: intent.currency,
    paymentMethodId: typeof method === "string" ? method : method?.id ?? null,
    metadata: intent.metadata,
  };
}

const handler = createPaymentIntentHandler({
  authenticate: (req) =>
    authenticateRateLimited(req, config, admin, "payment", {
      userLimit: 10,
      ipLimit: 30,
      windowSeconds: 60,
    }),
  async prepareCheckout(input): Promise<PreparedCheckout> {
    const { data, error } = await admin.rpc("prepare_reservation_checkout", {
      p_user_id: input.userId,
      p_listing_id: input.listingId,
      p_start_time: input.startTime,
      p_end_time: input.endTime,
      p_payment_method_id: input.paymentMethodId,
      p_idempotency_key: input.idempotencyKey,
      p_platform: input.platform,
    });
    if (error) throw error;
    const row = Array.isArray(data) ? data[0] : data;
    if (!row || typeof row !== "object") throw new Error("Checkout RPC returned no row");
    const value = row as Record<string, unknown>;
    return {
      reservationId: String(value.reservation_id ?? ""),
      paymentId: String(value.payment_id ?? ""),
      subtotalCents: Number(value.subtotal_cents),
      serviceFeeCents: Number(value.service_fee_cents),
      amountCents: Number(value.amount_cents),
      currency: String(value.currency ?? "").toLowerCase(),
      stripePaymentIntentId: nullableString(value.stripe_payment_intent_id),
      stripeCheckoutSessionId: nullableString(value.stripe_checkout_session_id),
      stripePaymentMethodId: nullableString(value.stripe_payment_method_id),
    };
  },
  getOrCreateCustomer: (userId) => getOrCreateStripeCustomer(stripe, admin, userId),
  ensurePaymentMethodOnCustomer: (customerId, paymentMethodId) =>
    ensurePaymentMethodOnCustomer(stripe, customerId, paymentMethodId),
  retrievePaymentIntent: async (id) => mapIntent(await stripe.paymentIntents.retrieve(id)),
  createPaymentIntent: async (input) => {
    const parameters: Stripe.PaymentIntentCreateParams = {
      amount: input.amount,
      currency: input.currency,
      metadata: input.metadata,
      ...(input.paymentMethodId
        ? {
          customer: input.customerId,
          payment_method: input.paymentMethodId,
          payment_method_types: ["card"],
          confirm: input.confirm,
        }
        : { automatic_payment_methods: { enabled: true } }),
    };
    return mapIntent(
      await stripe.paymentIntents.create(parameters, {
        idempotencyKey: input.idempotencyKey,
      }),
    );
  },
  async recordPaymentIntent(paymentId, paymentIntentId): Promise<void> {
    const { error } = await admin.rpc("record_checkout_payment_intent", {
      p_payment_id: paymentId,
      p_payment_intent_id: paymentIntentId,
    });
    if (error) throw error;
  },
  async retrieveCheckoutSession(id) {
    const session = await stripe.checkout.sessions.retrieve(id);
    return mapCheckoutSession(session);
  },
  async createCheckoutSession(input) {
    const session = await stripe.checkout.sessions.create(
      {
        mode: "payment",
        payment_method_types: ["card"],
        customer: input.customerId,
        success_url: input.successUrl,
        cancel_url: input.cancelUrl,
        client_reference_id: input.reservationId,
        line_items: [
          {
            quantity: 1,
            price_data: {
              currency: input.currency,
              unit_amount: input.amount,
              product_data: { name: "Parkd reservation (test mode)" },
            },
          },
        ],
        metadata: {
          payment_id: input.paymentId,
          reservation_id: input.reservationId,
          environment: "portfolio_demo",
        },
        payment_intent_data: {
          metadata: {
            payment_id: input.paymentId,
            reservation_id: input.reservationId,
            environment: "portfolio_demo",
          },
        },
      },
      { idempotencyKey: input.idempotencyKey },
    );
    return mapCheckoutSession(session);
  },
  async recordCheckoutSession(paymentId, checkoutSessionId): Promise<void> {
    const { error } = await admin.rpc("record_checkout_session", {
      p_payment_id: paymentId,
      p_checkout_session_id: checkoutSessionId,
    });
    if (error) throw error;
  },
  maxPaymentCents,
});

Deno.serve(handler);

function nullableString(value: unknown): string | null {
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

function mapCheckoutSession(
  session: Stripe.Checkout.Session,
): CheckoutSessionResult {
  const intent = session.payment_intent;
  return {
    id: session.id,
    url: session.url,
    livemode: session.livemode,
    amountTotal: session.amount_total,
    currency: session.currency,
    paymentIntentId: typeof intent === "string" ? intent : intent?.id ?? null,
    metadata: session.metadata ?? {},
    status: session.status,
  };
}
