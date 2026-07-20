import "jsr:@supabase/functions-js@2/edge-runtime.d.ts";

import { adminClient, runtimeConfig, stripeClient } from "../_shared/runtime.ts";
import { authenticateRateLimited } from "../_shared/rate_limit.ts";
import {
  ensurePaymentMethodOnCustomer,
  getOrCreateStripeCustomer,
} from "../_shared/stripe_customer.ts";
import { completePaymentMethodSetupHandler } from "./handler.ts";

const config = runtimeConfig();
const admin = adminClient(config);
const stripe = stripeClient(config.stripeSecretKey);

const handler = completePaymentMethodSetupHandler({
  authenticate: (req) =>
    authenticateRateLimited(req, config, admin, "save_payment_method", {
      userLimit: 10,
      ipLimit: 30,
      windowSeconds: 60,
    }),
  async retrieveSetupIntent(id) {
    const setup = await stripe.setupIntents.retrieve(id);
    const method = setup.payment_method;
    const customer = setup.customer;
    return {
      id: setup.id,
      status: setup.status,
      livemode: setup.livemode,
      userId: setup.metadata?.supabase_user_id ?? null,
      environment: setup.metadata?.environment ?? null,
      customerId: typeof customer === "string" ? customer : customer?.id ?? null,
      paymentMethodId: typeof method === "string" ? method : method?.id ?? null,
    };
  },
  async retrieveCard(paymentMethodId) {
    const method = await stripe.paymentMethods.retrieve(paymentMethodId);
    if (!method.card) throw new Error("Stripe payment method is not a card");
    return {
      paymentMethodId: method.id,
      livemode: method.livemode,
      brand: titleCaseBrand(method.card.brand),
      last4: method.card.last4 ?? "",
      expMonth: method.card.exp_month,
      expYear: method.card.exp_year,
    };
  },
  getOrCreateCustomer: (userId) => getOrCreateStripeCustomer(stripe, admin, userId),
  ensurePaymentMethodOnCustomer: (customerId, paymentMethodId) =>
    ensurePaymentMethodOnCustomer(stripe, customerId, paymentMethodId),
  async savePaymentMethod(input) {
    const { data: existing, error: existingError } = await admin
      .from("payment_methods")
      .select("id,user_id")
      .eq("stripe_payment_method_id", input.paymentMethodId)
      .maybeSingle();
    if (existingError) throw existingError;
    if (existing) {
      if (existing.user_id !== input.userId) throw new Error("Payment method owner mismatch");
      return existing.id as string;
    }

    const { count, error: countError } = await admin
      .from("payment_methods")
      .select("id", { count: "exact", head: true })
      .eq("user_id", input.userId);
    if (countError) throw countError;

    const { data, error } = await admin
      .from("payment_methods")
      .insert({
        user_id: input.userId,
        stripe_payment_method_id: input.paymentMethodId,
        brand: input.brand,
        last4: input.last4,
        exp_month: input.expMonth,
        exp_year: input.expYear,
        is_default: (count ?? 0) === 0,
      })
      .select("id")
      .single();
    if (error || !data?.id) throw error ?? new Error("Payment method insert failed");
    return data.id as string;
  },
});

Deno.serve(handler);

function titleCaseBrand(brand: string | undefined): string {
  if (!brand) return "Card";
  return brand.length < 2
    ? brand.toUpperCase()
    : brand.charAt(0).toUpperCase() + brand.slice(1).toLowerCase();
}
