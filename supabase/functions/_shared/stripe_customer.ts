import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import Stripe from "npm:stripe@17.4.0";

import { HttpError } from "./http.ts";
import { stripeIdempotencyKey } from "./runtime.ts";

/** One Stripe Customer per Supabase user; required to reuse saved PaymentMethods on PaymentIntents. */
export async function getOrCreateStripeCustomer(
  stripe: Stripe,
  admin: SupabaseClient,
  userId: string,
): Promise<string> {
  const { data: row, error } = await admin
    .from("profiles")
    .select("stripe_customer_id, email")
    .eq("id", userId)
    .maybeSingle();

  if (error) {
    throw new Error(`profiles: ${error.message}`);
  }

  const existing = (row?.stripe_customer_id as string | null | undefined)?.trim();
  if (existing) {
    if (!existing.startsWith("cus_")) {
      throw new HttpError(
        500,
        "invalid_customer_record",
        "The saved payment profile is invalid.",
      );
    }
    return existing;
  }

  const email = (row?.email as string | null | undefined)?.trim() || undefined;
  const customer = await stripe.customers.create(
    {
      email: email || undefined,
      metadata: {
        supabase_user_id: userId,
        application: "parkd",
      },
    },
    { idempotencyKey: stripeIdempotencyKey("customer", userId) },
  );
  const { data: updated, error: upErr } = await admin
    .from("profiles")
    .update({ stripe_customer_id: customer.id })
    .eq("id", userId)
    .is("stripe_customer_id", null)
    .select("id")
    .maybeSingle();

  if (upErr) {
    throw new Error(`Could not save Stripe customer: ${upErr.message}`);
  }
  if (!updated) {
    // Another concurrent request may have won the profile update. Stripe's
    // idempotency key means both requests still created/retrieved one customer.
    const { data: concurrent, error: concurrentError } = await admin
      .from("profiles")
      .select("stripe_customer_id")
      .eq("id", userId)
      .maybeSingle();
    const concurrentId = (concurrent?.stripe_customer_id as string | null)?.trim();
    if (concurrentError || !concurrentId) {
      throw new Error("Profile not found; cannot attach Stripe customer.");
    }
    return concurrentId;
  }

  return customer.id;
}

/** Saved cards must be attached to the Customer before PaymentIntent.create({ payment_method }). */
export async function ensurePaymentMethodOnCustomer(
  stripe: Stripe,
  customerId: string,
  paymentMethodId: string,
): Promise<void> {
  const pm = await stripe.paymentMethods.retrieve(paymentMethodId);
  if (pm.customer === customerId) {
    return;
  }
  if (pm.customer) {
    throw new Error(
      "This card is tied to another Stripe customer. Remove it and add the card again from Payment methods.",
    );
  }
  await stripe.paymentMethods.attach(paymentMethodId, { customer: customerId });
}
