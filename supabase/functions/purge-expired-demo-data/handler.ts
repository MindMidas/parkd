import {
  assertOnlyKeys,
  HttpError,
  readJsonObject,
  requestIdFor,
  safeLog,
  webhookJson,
} from "../_shared/http.ts";

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const STRIPE_CUSTOMER_PATTERN = /^cus_[A-Za-z0-9_]+$/;
const JSON_CONTENT_TYPE_PATTERN = /^application\/json(?:\s*;|$)/i;
const STORAGE_BUCKETS = new Set(["avatars", "listing-photos"]);

export interface StorageObject {
  bucketId: string;
  name: string;
}

export interface CleanupCandidate {
  userId: string;
  stripeCustomerId: string | null;
  storageObjects: readonly StorageObject[];
  prepared: boolean;
  attemptCount: number;
}

export interface CleanupDependencies {
  authorize(req: Request): Promise<void>;
  advanceReservationLifecycle(): Promise<void>;
  claimCandidates(limit: number): Promise<readonly CleanupCandidate[]>;
  deleteStripeCustomer(customerId: string): Promise<void>;
  prepareAccountDeletion(userId: string): Promise<readonly StorageObject[]>;
  deleteStorageObjects(objects: readonly StorageObject[]): Promise<void>;
  deleteAuthUser(userId: string): Promise<void>;
  completeAccountDeletion(userId: string): Promise<void>;
  recordFailure(userId: string, failureCode: string): Promise<void>;
}

/** Exact, timing-insensitive bearer-token comparison for the cron endpoint. */
export async function assertServiceRoleAuthorization(
  req: Request,
  expectedToken: string,
): Promise<void> {
  if (!expectedToken) {
    throw new HttpError(500, "service_misconfigured", "Cleanup is not configured.");
  }
  const authorization = req.headers.get("authorization")?.trim() ?? "";
  const match = /^Bearer\s+([^\s]+)$/i.exec(authorization);
  const rawToken = match?.[1] ?? "";
  const suppliedToken = rawToken.length <= 8192 ? rawToken : "";

  const encoder = new TextEncoder();
  const [suppliedDigest, expectedDigest] = await Promise.all([
    crypto.subtle.digest("SHA-256", encoder.encode(suppliedToken)),
    crypto.subtle.digest("SHA-256", encoder.encode(expectedToken)),
  ]);
  const supplied = new Uint8Array(suppliedDigest);
  const expected = new Uint8Array(expectedDigest);
  let difference = 0;
  for (let index = 0; index < expected.length; index += 1) {
    difference |= supplied[index]! ^ expected[index]!;
  }
  if (!suppliedToken || difference !== 0) {
    throw new HttpError(401, "unauthorized", "A valid service credential is required.");
  }
}

export function purgeExpiredDemoDataHandler(
  dependencies: CleanupDependencies,
): (req: Request) => Promise<Response> {
  return async (req: Request): Promise<Response> => {
    const requestId = requestIdFor(req);
    try {
      await dependencies.authorize(req);
      assertMachineRequest(req);
      const body = await readJsonObject(req);
      assertOnlyKeys(body, ["limit"]);
      const limit = cleanupLimit(body.limit);

      // One trusted scheduler advances reservation states and reconciles demo
      // cleanup. A lifecycle failure prevents claiming work and is safe to retry.
      await dependencies.advanceReservationLifecycle();
      const candidates = await dependencies.claimCandidates(limit);
      let completed = 0;
      let failed = 0;

      for (const rawCandidate of candidates) {
        let userId: string | null = null;
        let stage = "candidate";
        try {
          // Keep a trusted-looking queue key available so validation failures
          // can release its lease without accepting arbitrary identifiers.
          if (UUID_PATTERN.test(rawCandidate.userId)) userId = rawCandidate.userId;
          const candidate = validateCandidate(rawCandidate);
          userId = candidate.userId;

          stage = "stripe";
          if (candidate.stripeCustomerId) {
            await dependencies.deleteStripeCustomer(candidate.stripeCustomerId);
          }

          stage = "prepare";
          const preparedObjects = validateStorageObjects(
            await dependencies.prepareAccountDeletion(candidate.userId),
            candidate.userId,
          );

          stage = "storage";
          await dependencies.deleteStorageObjects(
            mergeStorageObjects(candidate.storageObjects, preparedObjects),
          );

          stage = "auth";
          await dependencies.deleteAuthUser(candidate.userId);

          stage = "complete";
          await dependencies.completeAccountDeletion(candidate.userId);
          completed += 1;
        } catch (_error) {
          failed += 1;
          safeLog("error", "account_cleanup_attempt_failed", {
            request_id: requestId,
            stage,
            ...(userId ? { user_id: userId } : {}),
          });
          if (userId) {
            try {
              await dependencies.recordFailure(userId, `${stage}_failed`);
            } catch (_recordError) {
              safeLog("error", "account_cleanup_failure_record_failed", {
                request_id: requestId,
                user_id: userId,
              });
            }
          }
        }
      }

      if (failed > 0) {
        return webhookJson(
          {
            error: "Cleanup is incomplete and will be retried.",
            error_code: "cleanup_incomplete",
            completed,
            failed,
          },
          500,
          requestId,
        );
      }

      safeLog("info", "account_cleanup_batch_completed", {
        request_id: requestId,
        completed,
      });
      return webhookJson({ completed, failed: 0 }, 200, requestId);
    } catch (error) {
      const httpError = error instanceof HttpError
        ? error
        : new HttpError(500, "internal_error", "Cleanup could not complete.");
      safeLog(httpError.status >= 500 ? "error" : "warn", "cleanup_request_failed", {
        request_id: requestId,
        error_code: httpError.code,
      });
      return webhookJson(
        { error: httpError.publicMessage, error_code: httpError.code },
        httpError.status,
        requestId,
      );
    }
  };
}

function assertMachineRequest(req: Request): void {
  if (req.headers.has("origin")) {
    throw new HttpError(403, "origin_not_allowed", "Browser requests are not allowed.");
  }
  if (req.method !== "POST") {
    throw new HttpError(405, "method_not_allowed", "Method not allowed.");
  }
  const contentType = req.headers.get("content-type")?.trim() ?? "";
  if (!JSON_CONTENT_TYPE_PATTERN.test(contentType)) {
    throw new HttpError(
      415,
      "unsupported_media_type",
      "Content-Type must be application/json.",
    );
  }
}

function cleanupLimit(value: unknown): number {
  if (value == null) return 25;
  if (typeof value !== "number" || !Number.isInteger(value) || value < 1 || value > 100) {
    throw new HttpError(400, "invalid_limit", "limit must be an integer from 1 to 100.");
  }
  return value;
}

function validateCandidate(candidate: CleanupCandidate): CleanupCandidate {
  if (!UUID_PATTERN.test(candidate.userId)) {
    throw new Error("Invalid cleanup candidate user ID.");
  }
  if (
    candidate.stripeCustomerId !== null &&
    !STRIPE_CUSTOMER_PATTERN.test(candidate.stripeCustomerId)
  ) {
    throw new Error("Invalid cleanup candidate Stripe customer ID.");
  }
  if (typeof candidate.prepared !== "boolean") {
    throw new Error("Invalid cleanup candidate preparation state.");
  }
  if (!Number.isInteger(candidate.attemptCount) || candidate.attemptCount < 1) {
    throw new Error("Invalid cleanup candidate attempt count.");
  }
  return {
    ...candidate,
    storageObjects: validateStorageObjects(candidate.storageObjects, candidate.userId),
  };
}

function validateStorageObjects(
  objects: readonly StorageObject[],
  userId: string,
): readonly StorageObject[] {
  if (!Array.isArray(objects) || objects.length > 10_000) {
    throw new Error("Invalid cleanup candidate storage snapshot.");
  }
  for (const object of objects) {
    if (
      !object || typeof object.bucketId !== "string" || typeof object.name !== "string" ||
      !STORAGE_BUCKETS.has(object.bucketId) || !object.name.startsWith(`${userId}/`) ||
      object.name.length > 1024
    ) {
      throw new Error("Invalid cleanup candidate storage object.");
    }
  }
  return objects;
}

function mergeStorageObjects(
  first: readonly StorageObject[],
  second: readonly StorageObject[],
): readonly StorageObject[] {
  const merged = new Map<string, StorageObject>();
  for (const object of [...first, ...second]) {
    merged.set(`${object.bucketId}\0${object.name}`, object);
  }
  return [...merged.values()];
}
