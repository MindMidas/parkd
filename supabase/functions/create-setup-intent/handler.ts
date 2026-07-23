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

const IDEMPOTENCY_PATTERN = /^[A-Za-z0-9_-]{16,128}$/;

export interface SetupIntentResult {
  id: string;
  clientSecret: string | null;
  livemode: boolean;
}

export interface CreateSetupDependencies {
  authenticate(req: Request): Promise<{ id: string }>;
  getOrCreateCustomer(userId: string): Promise<string>;
  createSetupIntent(input: {
    userId: string;
    customerId: string;
    idempotencyKey: string;
  }): Promise<SetupIntentResult>;
}

export function createSetupIntentHandler(
  dependencies: CreateSetupDependencies,
): (req: Request) => Promise<Response> {
  return async (req: Request): Promise<Response> => {
    const requestId = requestIdFor(req);
    if (req.method === "OPTIONS") return optionsResponse(req, requestId);

    try {
      assertPostJson(req);
      const user = await dependencies.authenticate(req);
      const body = await readJsonObject(req);
      assertOnlyKeys(body, ["idempotency_key"]);
      const idempotencyKey = requiredString(body, "idempotency_key", {
        maxLength: 128,
        pattern: IDEMPOTENCY_PATTERN,
      });
      const customerId = await dependencies.getOrCreateCustomer(user.id);
      const intent = await dependencies.createSetupIntent({
        userId: user.id,
        customerId,
        idempotencyKey: `parkd:setup:${user.id}:${idempotencyKey}`,
      });
      if (!intent.clientSecret) {
        throw new HttpError(500, "stripe_response_invalid", "Card setup could not be started.");
      }
      return json(
        req,
        { client_secret: intent.clientSecret, setup_intent_id: intent.id },
        200,
        requestId,
      );
    } catch (error) {
      return errorResponse(req, error, requestId);
    }
  };
}
