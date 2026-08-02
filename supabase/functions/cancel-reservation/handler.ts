import {
  assertOnlyKeys,
  assertPostJson,
  errorResponse,
  HttpError,
  json,
  optionsResponse,
  readJsonObject,
  requestIdFor,
  requiredString,
  safeLog,
} from "../_shared/http.ts";

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const REFUND_LEAD_MS = 2 * 60 * 60 * 1000;

export interface CancelReservationRecord {
  id: string;
  driverId: string;
  status: string;
  startTime: string;
}

export interface CancelPaymentRecord {
  id: string;
  status: string;
  stripePaymentIntentId: string | null;
  stripeRefundId: string | null;
}

export interface CancelReservationDependencies {
  authenticate(req: Request): Promise<{ id: string }>;
  loadReservation(reservationId: string): Promise<CancelReservationRecord | null>;
  loadSucceededPayment(
    reservationId: string,
  ): Promise<CancelPaymentRecord | null>;
  createRefund(paymentIntentId: string): Promise<{ id: string }>;
  applyCancellation(input: {
    userId: string;
    reservationId: string;
    markPaymentRefunded: boolean;
    stripeRefundId: string | null;
    reason: string;
  }): Promise<"cancelled" | "already_cancelled">;
  now?: () => Date;
}

function isRefundable(startTimeIso: string, now: Date): boolean {
  const start = Date.parse(startTimeIso);
  if (!Number.isFinite(start)) return false;
  return start > now.getTime() + REFUND_LEAD_MS;
}

/**
 * Driver cancels a confirmed upcoming reservation.
 * Full Stripe refund when more than 2 hours remain before start.
 */
export function cancelReservationHandler(
  dependencies: CancelReservationDependencies,
): (req: Request) => Promise<Response> {
  return async (req: Request): Promise<Response> => {
    const requestId = requestIdFor(req);
    if (req.method === "OPTIONS") return optionsResponse(req, requestId);

    try {
      assertPostJson(req);
      const user = await dependencies.authenticate(req);
      const body = await readJsonObject(req);
      assertOnlyKeys(body, ["reservation_id"]);
      const reservationId = requiredString(body, "reservation_id", {
        maxLength: 36,
        pattern: UUID_PATTERN,
      });

      const reservation = await dependencies.loadReservation(reservationId);
      if (reservation == null) {
        throw new HttpError(404, "reservation_not_found", "Reservation not found.");
      }
      if (reservation.driverId !== user.id) {
        throw new HttpError(
          403,
          "reservation_forbidden",
          "You can only cancel your own reservations.",
        );
      }

      if (reservation.status === "cancelled") {
        return json(
          req,
          {
            ok: true,
            outcome: "already_cancelled",
            refunded: false,
          },
          200,
          requestId,
        );
      }

      if (reservation.status !== "confirmed") {
        throw new HttpError(
          409,
          "reservation_not_cancellable",
          "Only upcoming confirmed reservations can be cancelled.",
        );
      }

      const now = dependencies.now?.() ?? new Date();
      const startMs = Date.parse(reservation.startTime);
      if (!Number.isFinite(startMs) || startMs <= now.getTime()) {
        throw new HttpError(
          409,
          "reservation_already_started",
          "This reservation has already started.",
        );
      }

      const payment = await dependencies.loadSucceededPayment(reservationId);
      const refundable = isRefundable(reservation.startTime, now);
      let stripeRefundId: string | null = payment?.stripeRefundId ?? null;
      let markPaymentRefunded = false;

      if (refundable) {
        if (payment == null || payment.status === "pending") {
          throw new HttpError(
            409,
            "payment_missing",
            "A completed payment is required to refund this reservation.",
          );
        }
        if (payment.status === "refunded") {
          markPaymentRefunded = true;
        } else if (payment.status === "succeeded") {
          const pi = payment.stripePaymentIntentId?.trim() ?? "";
          if (!pi.startsWith("pi_")) {
            throw new HttpError(
              409,
              "payment_intent_missing",
              "This payment cannot be refunded automatically.",
            );
          }
          const refund = await dependencies.createRefund(pi);
          stripeRefundId = refund.id;
          markPaymentRefunded = true;
        } else {
          throw new HttpError(
            409,
            "payment_not_refundable",
            "This payment cannot be refunded.",
          );
        }
      }

      const reason = refundable
        ? "driver_cancelled_refunded"
        : "driver_cancelled_no_refund";

      const outcome = await dependencies.applyCancellation({
        userId: user.id,
        reservationId,
        markPaymentRefunded,
        stripeRefundId,
        reason,
      });

      safeLog("info", "reservation_cancelled", {
        request_id: requestId,
        user_id: user.id,
        reservation_id: reservationId,
        outcome,
        refunded: markPaymentRefunded,
      });

      return json(
        req,
        {
          ok: true,
          outcome,
          refunded: markPaymentRefunded,
        },
        200,
        requestId,
      );
    } catch (error) {
      return errorResponse(req, error, requestId);
    }
  };
}

export { isRefundable, REFUND_LEAD_MS };
