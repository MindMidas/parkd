import "jsr:@supabase/functions-js@2/edge-runtime.d.ts";

import { adminClient, runtimeConfig, stripeClient } from "../_shared/runtime.ts";
import { authenticateRateLimited } from "../_shared/rate_limit.ts";
import { deleteAccountHandler, parseAccountDeletionStorageObjects } from "./handler.ts";

const config = runtimeConfig();
const admin = adminClient(config);
const stripe = stripeClient(config.stripeSecretKey);

const handler = deleteAccountHandler({
  authenticate: (req) =>
    authenticateRateLimited(req, config, admin, "account_delete", {
      userLimit: 3,
      ipLimit: 10,
      windowSeconds: 3600,
    }),
  async getStripeCustomerId(userId) {
    const { data, error } = await admin
      .from("profiles")
      .select("stripe_customer_id")
      .eq("id", userId)
      .maybeSingle();
    if (error) throw error;
    const id = data?.stripe_customer_id;
    return typeof id === "string" && id.startsWith("cus_") ? id : null;
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
    const value = data && typeof data === "object" && !Array.isArray(data)
      ? data as Record<string, unknown>
      : {};
    return parseAccountDeletionStorageObjects(value.storage_objects, userId);
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
    if (data !== true) throw new Error("Account deletion job was not found.");
  },
});

Deno.serve(handler);
