import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import Stripe from "npm:stripe@17.4.0";

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
    return existing;
  }

  const email = (row?.email as string | null | undefined)?.trim() || undefined;
  const customer = await stripe.customers.create({
    email: email || undefined,
    metadata: { supabase_user_id: userId },
  });

  const { data: updated, error: upErr } = await admin
    .from("profiles")
    .update({ stripe_customer_id: customer.id })
    .eq("id", userId)
    .select("id")
    .maybeSingle();

  if (upErr) {
    throw new Error(`Could not save Stripe customer: ${upErr.message}`);
  }
  if (!updated) {
    throw new Error("Profile not found; cannot attach Stripe customer.");
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
