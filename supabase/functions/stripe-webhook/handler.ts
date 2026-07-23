import { HttpError, requestIdFor, safeLog, webhookJson } from "../_shared/http.ts";

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const EVENT_ID_PATTERN = /^evt_[A-Za-z0-9_]{8,255}$/;
const PAYMENT_INTENT_PATTERN = /^pi_[A-Za-z0-9_]{8,255}$/;
const CHECKOUT_SESSION_PATTERN = /^cs_(test|live)_[A-Za-z0-9_]{8,255}$/;
const HANDLED_TYPES = new Set([
  "payment_intent.succeeded",
  "payment_intent.payment_failed",
  "payment_intent.canceled",
  "checkout.session.completed",
]);

export interface WebhookPaymentIntent {
  id: string;
  livemode: boolean;
  amount: number;
  amountReceived: number;
  currency: string;
  metadata: Record<string, string>;
}

export interface VerifiedWebhookEvent {
  id: string;
  type: string;
  livemode: boolean;
  created: number;
  paymentIntent: WebhookPaymentIntent | null;
  checkoutSession: WebhookCheckoutSession | null;
}

export interface WebhookCheckoutSession {
  id: string;
  livemode: boolean;
  paymentStatus: string;
  paymentIntentId: string | null;
  amountTotal: number | null;
  currency: string | null;
  metadata: Record<string, string>;
}

export interface ProcessWebhookInput {
  eventId: string;
  eventType: string;
  eventCreatedAt: string;
  paymentIntentId: string;
  checkoutSessionId: string | null;
  paymentId: string;
  reservationId: string;
  amountCents: number;
  currency: string;
  livemode: boolean;
}

export interface WebhookDependencies {
  verifyEvent(payload: string, signature: string): Promise<VerifiedWebhookEvent>;
  processEvent(input: ProcessWebhookInput): Promise<"processed" | "duplicate">;
}

export function stripeWebhookHandler(
  dependencies: WebhookDependencies,
): (req: Request) => Promise<Response> {
  return async (req: Request): Promise<Response> => {
    const requestId = requestIdFor(req);
    if (req.method !== "POST") {
      return webhookJson(
        {
          error: "Method not allowed.",
          error_code: "method_not_allowed",
          request_id: requestId,
        },
        405,
        requestId,
      );
    }

    const contentType = req.headers.get("content-type")?.toLowerCase() ?? "";
    if (!contentType.startsWith("application/json")) {
      return webhookJson(
        {
          error: "Content-Type must be application/json.",
          error_code: "unsupported_media_type",
          request_id: requestId,
        },
        415,
        requestId,
      );
    }

    const signature = req.headers.get("stripe-signature")?.trim();
    if (!signature || signature.length > 8192) {
      return webhookJson(
        {
          error: "Stripe signature is required.",
          error_code: "invalid_signature",
          request_id: requestId,
        },
        400,
        requestId,
      );
    }

    try {
      const payload = await readRawBody(req);
      let event: VerifiedWebhookEvent;
      try {
        event = await dependencies.verifyEvent(payload, signature);
      } catch {
        throw new HttpError(400, "invalid_signature", "Webhook signature is invalid.");
      }

      if (!EVENT_ID_PATTERN.test(event.id)) {
        throw new HttpError(400, "invalid_event", "Webhook event is invalid.");
      }
      if (!Number.isSafeInteger(event.created) || event.created <= 0) {
        throw new HttpError(400, "invalid_event", "Webhook event is invalid.");
      }
      if (!HANDLED_TYPES.has(event.type)) {
        return webhookJson(
          { received: true, outcome: "ignored", request_id: requestId },
          200,
          requestId,
        );
      }

      const payment = normalizedPayment(event);
      if (!payment) {
        throw new HttpError(400, "invalid_event", "Webhook payment data is invalid.");
      }

      // Events for unrelated objects in the same Stripe account are ignored.
      if (payment.metadata.application !== "parkd") {
        return webhookJson(
          { received: true, outcome: "ignored", request_id: requestId },
          200,
          requestId,
        );
      }

      const paymentId = payment.metadata.payment_id;
      const reservationId = payment.metadata.reservation_id;
      if (
        !PAYMENT_INTENT_PATTERN.test(payment.paymentIntentId) ||
        (payment.checkoutSessionId != null &&
          !CHECKOUT_SESSION_PATTERN.test(payment.checkoutSessionId)) ||
        typeof paymentId !== "string" ||
        !UUID_PATTERN.test(paymentId) ||
        typeof reservationId !== "string" ||
        !UUID_PATTERN.test(reservationId) ||
        !Number.isSafeInteger(payment.amountCents) ||
        !/^[a-z]{3}$/.test(payment.currency)
      ) {
        throw new HttpError(400, "invalid_event", "Webhook payment data is invalid.");
      }

      const outcome = await dependencies.processEvent({
        eventId: event.id,
        eventType: event.type,
        eventCreatedAt: new Date(event.created * 1000).toISOString(),
        paymentIntentId: payment.paymentIntentId,
        checkoutSessionId: payment.checkoutSessionId,
        paymentId,
        reservationId,
        amountCents: payment.amountCents,
        currency: payment.currency,
        livemode: event.livemode,
      });

      safeLog("info", "stripe_webhook_processed", {
        request_id: requestId,
        stripe_event_id: event.id,
        stripe_event_type: event.type,
        payment_intent_id: payment.paymentIntentId,
        checkout_session_id: payment.checkoutSessionId,
        outcome,
      });
      return webhookJson(
        { received: true, outcome, request_id: requestId },
        200,
        requestId,
      );
    } catch (error) {
      const normalized = error instanceof HttpError ? error : new HttpError(
        500,
        "webhook_processing_failed",
        "Webhook could not be processed.",
      );
      safeLog(normalized.status >= 500 ? "error" : "warn", "webhook_failed", {
        request_id: requestId,
        error_code: normalized.code,
      });
      return webhookJson(
        {
          error: normalized.publicMessage,
          error_code: normalized.code,
          request_id: requestId,
        },
        normalized.status,
        requestId,
      );
    }
  };
}

function normalizedPayment(event: VerifiedWebhookEvent): {
  paymentIntentId: string;
  checkoutSessionId: string | null;
  amountCents: number;
  currency: string;
  metadata: Record<string, string>;
} | null {
  if (event.type === "checkout.session.completed") {
    const session = event.checkoutSession;
    if (
      !session ||
      session.paymentStatus !== "paid" ||
      !session.paymentIntentId ||
      session.amountTotal == null ||
      !session.currency
    ) return null;
    return {
      paymentIntentId: session.paymentIntentId,
      checkoutSessionId: session.id,
      amountCents: session.amountTotal,
      currency: session.currency,
      metadata: session.metadata,
    };
  }

  const intent = event.paymentIntent;
  if (!intent) return null;
  return {
    paymentIntentId: intent.id,
    checkoutSessionId: null,
    amountCents: event.type === "payment_intent.succeeded" ? intent.amountReceived : intent.amount,
    currency: intent.currency,
    metadata: intent.metadata,
  };
}

async function readRawBody(req: Request): Promise<string> {
  const declared = Number(req.headers.get("content-length") ?? "0");
  if (Number.isFinite(declared) && declared > 1_048_576) {
    throw new HttpError(413, "request_too_large", "Webhook body is too large.");
  }
  const payload = await req.text();
  if (new TextEncoder().encode(payload).byteLength > 1_048_576) {
    throw new HttpError(413, "request_too_large", "Webhook body is too large.");
  }
  return payload;
}
