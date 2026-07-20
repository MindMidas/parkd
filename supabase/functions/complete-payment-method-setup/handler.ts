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
} from "../_shared/http.ts";

const SETUP_INTENT_PATTERN = /^seti_[A-Za-z0-9_]{8,255}$/;

export interface CompletedSetupIntent {
  id: string;
  status: string;
  livemode: boolean;
  userId: string | null;
  environment: string | null;
  customerId: string | null;
  paymentMethodId: string | null;
}

export interface CardDetails {
  paymentMethodId: string;
  livemode: boolean;
  brand: string;
  last4: string;
  expMonth: number;
  expYear: number;
}

export interface CompleteSetupDependencies {
  authenticate(req: Request): Promise<{ id: string }>;
  retrieveSetupIntent(id: string): Promise<CompletedSetupIntent>;
  retrieveCard(paymentMethodId: string): Promise<CardDetails>;
  getOrCreateCustomer(userId: string): Promise<string>;
  ensurePaymentMethodOnCustomer(customerId: string, paymentMethodId: string): Promise<void>;
  savePaymentMethod(input: CardDetails & { userId: string }): Promise<string>;
}

export function completePaymentMethodSetupHandler(
  dependencies: CompleteSetupDependencies,
): (req: Request) => Promise<Response> {
  return async (req: Request): Promise<Response> => {
    const requestId = requestIdFor(req);
    if (req.method === "OPTIONS") return optionsResponse(req, requestId);

    try {
      assertPostJson(req);
      const user = await dependencies.authenticate(req);
      const body = await readJsonObject(req);
      assertOnlyKeys(body, ["setup_intent_id"]);
      const setupIntentId = requiredString(body, "setup_intent_id", {
        maxLength: 255,
        pattern: SETUP_INTENT_PATTERN,
      });

      const setup = await dependencies.retrieveSetupIntent(setupIntentId);
      if (setup.livemode !== false) {
        throw new HttpError(400, "live_object_rejected", "Live Stripe data is disabled.");
      }
      if (setup.environment !== "portfolio_demo" || setup.userId !== user.id) {
        throw new HttpError(403, "forbidden", "This card setup does not belong to you.");
      }
      if (setup.status !== "succeeded" || !setup.paymentMethodId) {
        throw new HttpError(409, "setup_not_complete", "Card setup is not complete.");
      }

      const customerId = await dependencies.getOrCreateCustomer(user.id);
      if (setup.customerId !== customerId) {
        throw new HttpError(409, "customer_mismatch", "Card setup does not match your account.");
      }

      const card = await dependencies.retrieveCard(setup.paymentMethodId);
      if (card.livemode !== false) {
        throw new HttpError(400, "live_object_rejected", "Live Stripe data is disabled.");
      }
      await dependencies.ensurePaymentMethodOnCustomer(
        customerId,
        setup.paymentMethodId,
      );
      const savedId = await dependencies.savePaymentMethod({ ...card, userId: user.id });

      return json(
        req,
        { ok: true, payment_method_id: savedId, test_mode: true },
        200,
        requestId,
      );
    } catch (error) {
      return errorResponse(req, error, requestId);
    }
  };
}
