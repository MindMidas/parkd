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

export interface DeleteAccountDependencies {
  authenticate(req: Request): Promise<{ id: string }>;
  getStripeCustomerId(userId: string): Promise<string | null>;
  deleteStripeCustomer(customerId: string): Promise<void>;
  prepareAccountDeletion(userId: string): Promise<readonly StorageObject[]>;
  deleteStorageObjects(objects: readonly StorageObject[]): Promise<void>;
  deleteAuthUser(userId: string): Promise<void>;
  completeAccountDeletion(userId: string): Promise<void>;
}

export interface StorageObject {
  bucketId: string;
  name: string;
}

const ACCOUNT_MEDIA_BUCKETS = new Set(["avatars", "listing-photos"]);

export function parseAccountDeletionStorageObjects(
  value: unknown,
  userId: string,
): readonly StorageObject[] {
  if (!Array.isArray(value) || value.length > 10_000) {
    throw new Error("Account deletion storage snapshot is invalid.");
  }
  return value.map((object) => {
    if (!object || typeof object !== "object" || Array.isArray(object)) {
      throw new Error("Account deletion storage object is invalid.");
    }
    const record = object as Record<string, unknown>;
    const bucketId = typeof record.bucket_id === "string" ? record.bucket_id : "";
    const name = typeof record.name === "string" ? record.name : "";
    if (
      !ACCOUNT_MEDIA_BUCKETS.has(bucketId) || !name.startsWith(`${userId}/`) ||
      name.length > 1024
    ) {
      throw new Error("Account deletion storage object is invalid.");
    }
    return { bucketId, name };
  });
}

export function deleteAccountHandler(
  dependencies: DeleteAccountDependencies,
): (req: Request) => Promise<Response> {
  return async (req: Request): Promise<Response> => {
    const requestId = requestIdFor(req);
    if (req.method === "OPTIONS") return optionsResponse(req, requestId);

    try {
      assertPostJson(req);
      const user = await dependencies.authenticate(req);
      const body = await readJsonObject(req);
      // A target user ID is intentionally never accepted. The verified JWT is
      // the only source of account identity.
      assertOnlyKeys(body, ["confirmation"]);
      if (requiredString(body, "confirmation", { maxLength: 6 }) !== "DELETE") {
        throw new HttpError(
          400,
          "confirmation_required",
          "Type DELETE to confirm account deletion.",
        );
      }

      // Remove the external customer first. If a later local step fails the
      // still-authenticated caller can retry; deleting a Stripe customer is idempotent.
      const stripeCustomerId = await dependencies.getStripeCustomerId(user.id);
      if (stripeCustomerId) {
        await dependencies.deleteStripeCustomer(stripeCustomerId);
      }

      // The RPC is idempotent and atomically removes/anonymizes app-owned data.
      // Auth deletion runs last so a failed cleanup remains retryable.
      const storageObjects = await dependencies.prepareAccountDeletion(user.id);
      await dependencies.deleteStorageObjects(storageObjects);
      await dependencies.deleteAuthUser(user.id);
      // Completion is persisted separately from preparation. If this final RPC
      // fails, the scheduled cleanup worker can safely reconcile Stripe,
      // Storage, and Auth because every destructive operation is idempotent.
      await dependencies.completeAccountDeletion(user.id);

      safeLog("info", "account_deleted", {
        request_id: requestId,
        user_id: user.id,
      });
      return json(req, { deleted: true }, 200, requestId);
    } catch (error) {
      return errorResponse(req, error, requestId);
    }
  };
}
