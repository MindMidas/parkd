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

const PAYMENT_INTENT_PATTERN = /^pi_[A-Za-z0-9_]{8,255}$/;
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export interface FinalizeIntent {
  id: string;
  status: string;
  livemode: boolean;
  amountReceived: number;
  currency: string;
  metadata: Record<string, string>;
}

export interface FinalizeDependencies {
  authenticate(req: Request): Promise<{ id: string }>;
  retrievePaymentIntent(id: string): Promise<FinalizeIntent>;
  finalizeVerifiedPayment(input: {
    userId: string;
    paymentIntentId: string;
    paymentId: string;
    reservationId: string;
    amountCents: number;
    currency: string;
  }): Promise<"processed" | "already_processed">;
}

/**
 * Authenticated fallback for clients that finish before Stripe's webhook lands.
 * It trusts only a fresh Stripe API response and uses the same atomic DB rules.
 */
export function finalizeReservationPaymentHandler(
  dependencies: FinalizeDependencies,
): (req: Request) => Promise<Response> {
  return async (req: Request): Promise<Response> => {
    const requestId = requestIdFor(req);
    if (req.method === "OPTIONS") return optionsResponse(req, requestId);

    try {
      assertPostJson(req);
      const user = await dependencies.authenticate(req);
      const body = await readJsonObject(req);
      assertOnlyKeys(body, ["payment_intent_id"]);
      const paymentIntentId = requiredString(body, "payment_intent_id", {
        maxLength: 255,
        pattern: PAYMENT_INTENT_PATTERN,
      });

      const intent = await dependencies.retrievePaymentIntent(paymentIntentId);
      if (intent.status !== "succeeded") {
        throw new HttpError(
          409,
          "payment_not_complete",
          "The payment has not completed yet.",
        );
      }
      if (intent.metadata.application !== "parkd") {
        throw new HttpError(400, "payment_intent_mismatch", "Payment is not a Parkd payment.");
      }

      const paymentId = intent.metadata.payment_id;
      const reservationId = intent.metadata.reservation_id;
      if (
        typeof paymentId !== "string" ||
        !UUID_PATTERN.test(paymentId) ||
        typeof reservationId !== "string" ||
        !UUID_PATTERN.test(reservationId) ||
        !Number.isSafeInteger(intent.amountReceived) ||
        intent.amountReceived < 50 ||
        intent.currency !== "cad"
      ) {
        throw new HttpError(400, "payment_intent_mismatch", "Payment details are invalid.");
      }

      const outcome = await dependencies.finalizeVerifiedPayment({
        userId: user.id,
        paymentIntentId,
        paymentId,
        reservationId,
        amountCents: intent.amountReceived,
        currency: intent.currency,
      });
      safeLog("info", "payment_finalize_fallback", {
        request_id: requestId,
        user_id: user.id,
        payment_intent_id: paymentIntentId,
        outcome,
      });
      return json(
        req,
        { ok: true, outcome },
        200,
        requestId,
      );
    } catch (error) {
      return errorResponse(req, error, requestId);
    }
  };
}
