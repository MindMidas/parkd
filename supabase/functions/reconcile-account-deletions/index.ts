import "jsr:@supabase/functions-js@2/edge-runtime.d.ts";

import { adminClient, runtimeConfig, stripeClient } from "../_shared/runtime.ts";
import {
  assertServiceRoleAuthorization,
  type CleanupCandidate,
  reconcileAccountDeletionsHandler,
  type StorageObject,
} from "./handler.ts";

const config = runtimeConfig();
const admin = adminClient(config);
const stripe = stripeClient(config.stripeSecretKey);

const handler = reconcileAccountDeletionsHandler({
  authorize: (req) => assertServiceRoleAuthorization(req, config.serviceRoleKey),
  async advanceReservationLifecycle() {
    const { error } = await admin.rpc("advance_reservation_lifecycle");
    if (error) throw error;
  },
  async claimCandidates(limit) {
    const { data, error } = await admin.rpc("claim_account_deletion_jobs", {
      p_limit: limit,
    });
    if (error) throw error;
    if (!Array.isArray(data)) throw new Error("Cleanup RPC returned an invalid result.");
    return data.map(candidateFromRow);
  },
  async deleteStripeCustomer(customerId) {
    try {
      await stripe.customers.del(customerId);
    } catch (error) {
      if ((error as { code?: unknown }).code !== "resource_missing") throw error;
    }
  },
  async prepareAccountDeletion(userId) {
    const { data, error } = await admin.rpc("prepare_account_deletion", {
      p_user_id: userId,
    });
    if (error) throw error;
    const record = objectRecord(data);
    return storageObjectsFromValue(record.storage_objects);
  },
  async deleteStorageObjects(objects) {
    const byBucket = new Map<string, string[]>();
    for (const object of objects) {
      const names = byBucket.get(object.bucketId) ?? [];
      names.push(object.name);
      byBucket.set(object.bucketId, names);
    }
    for (const [bucket, names] of byBucket) {
      for (let offset = 0; offset < names.length; offset += 100) {
        const { error } = await admin.storage.from(bucket).remove(
          names.slice(offset, offset + 100),
        );
        if (error) throw error;
      }
    }
  },
  async deleteAuthUser(userId) {
    const { error } = await admin.auth.admin.deleteUser(userId, false);
    if (error && (error as { status?: number }).status !== 404) throw error;
  },
  async completeAccountDeletion(userId) {
    const { data, error } = await admin.rpc("complete_account_deletion", {
      p_user_id: userId,
    });
    if (error) throw error;
    if (data !== true) throw new Error("Cleanup job was not found.");
  },
  async recordFailure(userId, failureCode) {
    const { data, error } = await admin.rpc("record_account_deletion_failure", {
      p_user_id: userId,
      p_error: failureCode,
    });
    if (error) throw error;
    if (data !== true) throw new Error("Cleanup job was not found.");
  },
});

Deno.serve(handler);

function candidateFromRow(value: unknown): CleanupCandidate {
  const record = objectRecord(value);
  return {
    userId: typeof record.user_id === "string" ? record.user_id : "",
    stripeCustomerId: record.stripe_customer_id === null
      ? null
      : typeof record.stripe_customer_id === "string"
      ? record.stripe_customer_id
      : "",
    storageObjects: storageObjectsFromValue(record.storage_objects),
    prepared: typeof record.prepared === "boolean" ? record.prepared : false,
    attemptCount: typeof record.attempt_count === "number" ? record.attempt_count : 0,
  };
}

function storageObjectsFromValue(value: unknown): readonly StorageObject[] {
  if (!Array.isArray(value)) throw new Error("Cleanup storage snapshot is invalid.");
  return value.map((item) => {
    const record = objectRecord(item);
    return {
      bucketId: typeof record.bucket_id === "string" ? record.bucket_id : "",
      name: typeof record.name === "string" ? record.name : "",
    };
  });
}

function objectRecord(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("Cleanup response is invalid.");
  }
  return value as Record<string, unknown>;
}
