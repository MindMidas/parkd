import "jsr:@supabase/functions-js@2/edge-runtime.d.ts";

import { adminClient, runtimeConfig, stripeClient } from "../_shared/runtime.ts";
import { authenticateRateLimited } from "../_shared/rate_limit.ts";
import { cancelReservationHandler } from "./handler.ts";

const config = runtimeConfig();
const stripe = stripeClient(config.stripeSecretKey);
const admin = adminClient(config);

const handler = cancelReservationHandler({
  authenticate: (req) =>
    authenticateRateLimited(req, config, admin, "reservation_cancel", {
      userLimit: 20,
      ipLimit: 40,
      windowSeconds: 60,
    }),
  async loadReservation(reservationId) {
    const { data, error } = await admin
      .from("reservations")
      .select("id, driver_id, status, start_time")
      .eq("id", reservationId)
      .maybeSingle();
    if (error) throw error;
    if (data == null) return null;
    return {
      id: data.id as string,
      driverId: data.driver_id as string,
      status: data.status as string,
      startTime: data.start_time as string,
    };
  },
  async loadSucceededPayment(reservationId) {
    const { data, error } = await admin
      .from("payments")
      .select("id, status, stripe_payment_intent_id, stripe_refund_id")
      .eq("reservation_id", reservationId)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    if (error) throw error;
    if (data == null) return null;
    return {
      id: data.id as string,
      status: data.status as string,
      stripePaymentIntentId: (data.stripe_payment_intent_id as string | null) ??
        null,
      stripeRefundId: (data.stripe_refund_id as string | null) ?? null,
    };
  },
  async createRefund(paymentIntentId) {
    const refund = await stripe.refunds.create(
      {
        payment_intent: paymentIntentId,
        reason: "requested_by_customer",
      },
      {
        idempotencyKey: `parkd_refund_${paymentIntentId}`,
      },
    );
    return { id: refund.id };
  },
  async applyCancellation(input) {
    const { data, error } = await admin.rpc(
      "apply_driver_reservation_cancellation",
      {
        p_user_id: input.userId,
        p_reservation_id: input.reservationId,
        p_mark_payment_refunded: input.markPaymentRefunded,
        p_stripe_refund_id: input.stripeRefundId,
        p_reason: input.reason,
      },
    );
    if (error) throw error;
    const outcome = typeof data === "string" ? data : String(data ?? "");
    return outcome === "already_cancelled" ? "already_cancelled" : "cancelled";
  },
});

Deno.serve(handler);
