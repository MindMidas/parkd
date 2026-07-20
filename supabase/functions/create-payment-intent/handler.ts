import {
  assertOnlyKeys,
  assertPostJson,
  configuredAllowedOrigins,
  errorResponse,
  HttpError,
  json,
  optionalString,
  optionsResponse,
  readJsonObject,
  requestIdFor,
  requiredString,
  safeLog,
} from "../_shared/http.ts";

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const IDEMPOTENCY_PATTERN = /^[A-Za-z0-9_-]{16,128}$/;
const CURRENCY_PATTERN = /^[a-z]{3}$/;

export interface CheckoutUser {
  id: string;
}

export interface PrepareCheckoutInput {
  userId: string;
  listingId: string;
  startTime: string;
  endTime: string;
  paymentMethodId: string | null;
  idempotencyKey: string;
  platform: "mobile" | "web";
}

export interface PreparedCheckout {
  reservationId: string;
  paymentId: string;
  subtotalCents: number;
  serviceFeeCents: number;
  amountCents: number;
  currency: string;
  stripePaymentIntentId: string | null;
  stripeCheckoutSessionId: string | null;
  stripePaymentMethodId: string | null;
}

export interface PaymentIntentResult {
  id: string;
  clientSecret: string | null;
  status: string;
  livemode: boolean;
  amount: number;
  currency: string;
  paymentMethodId: string | null;
  metadata: Record<string, string>;
}

export interface CreatePaymentIntentInput {
  amount: number;
  currency: string;
  customerId?: string;
  paymentMethodId?: string;
  confirm: boolean;
  metadata: Record<string, string>;
  idempotencyKey: string;
}

export interface CheckoutSessionResult {
  id: string;
  url: string | null;
  livemode: boolean;
  amountTotal: number | null;
  currency: string | null;
  paymentIntentId: string | null;
  metadata: Record<string, string>;
  status: string | null;
}

export interface CreateCheckoutSessionInput {
  amount: number;
  currency: string;
  customerId: string;
  successUrl: string;
  cancelUrl: string;
  reservationId: string;
  paymentId: string;
  idempotencyKey: string;
}

export interface CheckoutDependencies {
  authenticate(req: Request): Promise<CheckoutUser>;
  prepareCheckout(input: PrepareCheckoutInput): Promise<PreparedCheckout>;
  getOrCreateCustomer(userId: string): Promise<string>;
  ensurePaymentMethodOnCustomer(
    customerId: string,
    paymentMethodId: string,
  ): Promise<void>;
  retrievePaymentIntent(id: string): Promise<PaymentIntentResult>;
  createPaymentIntent(input: CreatePaymentIntentInput): Promise<PaymentIntentResult>;
  recordPaymentIntent(paymentId: string, paymentIntentId: string): Promise<void>;
  retrieveCheckoutSession(id: string): Promise<CheckoutSessionResult>;
  createCheckoutSession(input: CreateCheckoutSessionInput): Promise<CheckoutSessionResult>;
  recordCheckoutSession(paymentId: string, checkoutSessionId: string): Promise<void>;
  maxPaymentCents: number;
}

export function createPaymentIntentHandler(
  dependencies: CheckoutDependencies,
): (req: Request) => Promise<Response> {
  return async (req: Request): Promise<Response> => {
    const requestId = requestIdFor(req);
    if (req.method === "OPTIONS") return optionsResponse(req, requestId);

    try {
      assertPostJson(req);
      const user = await dependencies.authenticate(req);
      const body = await readJsonObject(req);
      assertOnlyKeys(body, [
        "listing_id",
        "start_time",
        "end_time",
        "payment_method_id",
        "idempotency_key",
        "platform",
        "success_url",
        "cancel_url",
      ]);

      const listingId = requiredString(body, "listing_id", {
        maxLength: 36,
        pattern: UUID_PATTERN,
      });
      const paymentMethodId = optionalString(body, "payment_method_id", {
        maxLength: 36,
        pattern: UUID_PATTERN,
      });
      const idempotencyKey = requiredString(body, "idempotency_key", {
        maxLength: 128,
        pattern: IDEMPOTENCY_PATTERN,
      });
      const platform = optionalString(body, "platform", { maxLength: 16 }) ?? "mobile";
      if (platform !== "mobile" && platform !== "web") {
        throw new HttpError(400, "invalid_platform", "platform must be mobile or web.");
      }
      const successUrl = platform === "web" ? validRedirectUrl(body, "success_url") : null;
      const cancelUrl = platform === "web" ? validRedirectUrl(body, "cancel_url") : null;
      if (
        platform === "mobile" &&
        (body.success_url != null || body.cancel_url != null)
      ) {
        throw new HttpError(
          400,
          "unexpected_redirect",
          "Redirect URLs are only accepted for web checkout.",
        );
      }
      const startTime = validTimestamp(body, "start_time");
      const endTime = validTimestamp(body, "end_time");
      validateWindow(startTime, endTime);

      // The RPC owns availability, host lookup, pricing, service fees, and the
      // reservation/payment transaction. No client-supplied monetary field is accepted.
      const checkout = await dependencies.prepareCheckout({
        userId: user.id,
        listingId,
        startTime: startTime.toISOString(),
        endTime: endTime.toISOString(),
        paymentMethodId,
        idempotencyKey,
        platform,
      });
      validatePreparedCheckout(checkout, dependencies.maxPaymentCents);

      if (platform === "web") {
        const customerId = await dependencies.getOrCreateCustomer(user.id);
        let session: CheckoutSessionResult;
        if (checkout.stripeCheckoutSessionId) {
          session = await dependencies.retrieveCheckoutSession(
            checkout.stripeCheckoutSessionId,
          );
        } else {
          session = await dependencies.createCheckoutSession({
            amount: checkout.amountCents,
            currency: checkout.currency,
            customerId,
            successUrl: successUrl!,
            cancelUrl: cancelUrl!,
            reservationId: checkout.reservationId,
            paymentId: checkout.paymentId,
            idempotencyKey: `parkd-demo:checkout-session:${checkout.paymentId}:v1`,
          });
          validateCheckoutSession(session, checkout);
          await dependencies.recordCheckoutSession(checkout.paymentId, session.id);
        }
        validateCheckoutSession(session, checkout);
        if (!session.url || session.status === "expired") {
          throw new HttpError(
            409,
            "checkout_expired",
            "This web checkout expired. Start a new reservation to try again.",
          );
        }

        safeLog("info", "checkout_session_ready", {
          request_id: requestId,
          user_id: user.id,
          reservation_id: checkout.reservationId,
          payment_id: checkout.paymentId,
          checkout_session_id: session.id,
        });
        return json(
          req,
          {
            reservation_id: checkout.reservationId,
            payment_id: checkout.paymentId,
            checkout_url: session.url,
            checkout_session_id: session.id,
            subtotal_cents: checkout.subtotalCents,
            service_fee_cents: checkout.serviceFeeCents,
            amount_cents: checkout.amountCents,
            currency: checkout.currency,
            test_mode: true,
          },
          200,
          requestId,
        );
      }

      let intent: PaymentIntentResult;
      if (checkout.stripePaymentIntentId) {
        intent = await dependencies.retrievePaymentIntent(
          checkout.stripePaymentIntentId,
        );
        validateIntent(intent, checkout);
      } else {
        let customerId: string | undefined;
        if (checkout.stripePaymentMethodId) {
          customerId = await dependencies.getOrCreateCustomer(user.id);
          await dependencies.ensurePaymentMethodOnCustomer(
            customerId,
            checkout.stripePaymentMethodId,
          );
        }

        intent = await dependencies.createPaymentIntent({
          amount: checkout.amountCents,
          currency: checkout.currency,
          customerId,
          paymentMethodId: checkout.stripePaymentMethodId ?? undefined,
          confirm: checkout.stripePaymentMethodId != null,
          metadata: {
            payment_id: checkout.paymentId,
            reservation_id: checkout.reservationId,
            environment: "portfolio_demo",
          },
          // Stable per trusted payment row. Stripe returns the same object for
          // concurrent/retried requests, preventing duplicate intents.
          idempotencyKey: `parkd-demo:payment:${checkout.paymentId}:v1`,
        });
        validateIntent(intent, checkout);
        await dependencies.recordPaymentIntent(checkout.paymentId, intent.id);
      }

      if (intent.status === "canceled") {
        throw new HttpError(
          409,
          "checkout_canceled",
          "This checkout was cancelled. Start a new reservation to try again.",
        );
      }
      if (!intent.clientSecret) {
        throw new HttpError(
          409,
          "checkout_unavailable",
          "This checkout cannot be resumed.",
        );
      }

      safeLog("info", "checkout_intent_ready", {
        request_id: requestId,
        user_id: user.id,
        reservation_id: checkout.reservationId,
        payment_id: checkout.paymentId,
        payment_intent_id: intent.id,
        payment_status: intent.status,
      });

      return json(
        req,
        {
          reservation_id: checkout.reservationId,
          payment_id: checkout.paymentId,
          client_secret: intent.clientSecret,
          payment_intent_status: intent.status,
          subtotal_cents: checkout.subtotalCents,
          service_fee_cents: checkout.serviceFeeCents,
          amount_cents: checkout.amountCents,
          currency: checkout.currency,
          test_mode: true,
        },
        200,
        requestId,
      );
    } catch (error) {
      return errorResponse(req, normalizeStripeFailure(error), requestId);
    }
  };
}

function validTimestamp(body: Record<string, unknown>, key: string): Date {
  const raw = requiredString(body, key, { maxLength: 40 });
  const parsed = new Date(raw);
  if (!Number.isFinite(parsed.getTime()) || !/[zZ]|[+-]\d{2}:\d{2}$/.test(raw)) {
    throw new HttpError(400, "invalid_body", `${key} must include a timezone.`);
  }
  return parsed;
}

function validateWindow(start: Date, end: Date): void {
  if (end <= start) {
    throw new HttpError(400, "invalid_time_window", "End time must be after start time.");
  }
  if (start.getTime() < Date.now() - 5 * 60_000) {
    throw new HttpError(400, "invalid_time_window", "Reservation cannot start in the past.");
  }
  if (end.getTime() - start.getTime() > 31 * 24 * 60 * 60_000) {
    throw new HttpError(400, "invalid_time_window", "Reservation cannot exceed 31 days.");
  }
}

function validRedirectUrl(body: Record<string, unknown>, key: string): string {
  const raw = requiredString(body, key, { maxLength: 2048 });
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    throw new HttpError(400, "invalid_redirect", `${key} is invalid.`);
  }
  if (
    !configuredAllowedOrigins().includes(url.origin) ||
    url.username ||
    url.password ||
    (url.protocol !== "https:" && !url.hostname.match(/^(localhost|127\.0\.0\.1)$/))
  ) {
    throw new HttpError(400, "invalid_redirect", `${key} origin is not allowed.`);
  }
  return url.toString();
}

function validatePreparedCheckout(
  checkout: PreparedCheckout,
  maxPaymentCents: number,
): void {
  if (!UUID_PATTERN.test(checkout.reservationId) || !UUID_PATTERN.test(checkout.paymentId)) {
    throw new HttpError(500, "invalid_checkout_record", "Checkout could not be prepared.");
  }
  if (
    !Number.isSafeInteger(checkout.subtotalCents) ||
    !Number.isSafeInteger(checkout.serviceFeeCents) ||
    checkout.subtotalCents < 0 ||
    checkout.serviceFeeCents < 0 ||
    checkout.subtotalCents + checkout.serviceFeeCents !== checkout.amountCents ||
    !Number.isSafeInteger(checkout.amountCents) ||
    checkout.amountCents < 50 ||
    checkout.amountCents > maxPaymentCents
  ) {
    throw new HttpError(422, "invalid_checkout_amount", "Checkout amount is not allowed.");
  }
  if (!CURRENCY_PATTERN.test(checkout.currency) || checkout.currency !== "cad") {
    throw new HttpError(500, "invalid_checkout_currency", "Checkout currency is not allowed.");
  }
}

function validateIntent(
  intent: PaymentIntentResult,
  checkout: PreparedCheckout,
): void {
  if (intent.livemode !== false) {
    throw new HttpError(500, "live_object_rejected", "Live Stripe data is not allowed.");
  }
  if (intent.amount !== checkout.amountCents || intent.currency !== checkout.currency) {
    throw new HttpError(409, "payment_intent_mismatch", "Payment details do not match checkout.");
  }
  if (
    intent.metadata.payment_id !== checkout.paymentId ||
    intent.metadata.reservation_id !== checkout.reservationId
  ) {
    throw new HttpError(409, "payment_intent_mismatch", "Payment details do not match checkout.");
  }
  if (
    checkout.stripePaymentMethodId &&
    intent.paymentMethodId &&
    checkout.stripePaymentMethodId !== intent.paymentMethodId
  ) {
    throw new HttpError(409, "payment_method_mismatch", "Saved payment method does not match.");
  }
}

function validateCheckoutSession(
  session: CheckoutSessionResult,
  checkout: PreparedCheckout,
): void {
  if (session.livemode !== false) {
    throw new HttpError(500, "live_object_rejected", "Live Stripe data is not allowed.");
  }
  if (
    session.amountTotal != null && session.amountTotal !== checkout.amountCents ||
    session.currency != null && session.currency !== checkout.currency ||
    session.metadata.payment_id !== checkout.paymentId ||
    session.metadata.reservation_id !== checkout.reservationId
  ) {
    throw new HttpError(409, "checkout_session_mismatch", "Web checkout details do not match.");
  }
}

function normalizeStripeFailure(error: unknown): unknown {
  if (error instanceof HttpError) return error;
  if (isStripeCardError(error)) {
    return new HttpError(
      402,
      "payment_failed",
      "The test payment could not be completed. Try another Stripe test card.",
    );
  }
  return error;
}

function isStripeCardError(error: unknown): boolean {
  if (!error || typeof error !== "object") return false;
  const value = error as { type?: unknown; code?: unknown };
  return value.type === "StripeCardError" || value.code === "card_declined";
}
