import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";

import { HttpError } from "./http.ts";
import { authenticate, type AuthenticatedUser, type SupabaseRuntimeConfig } from "./runtime.ts";

interface LimitPolicy {
  userLimit: number;
  ipLimit: number;
  windowSeconds: number;
}

export async function authenticateRateLimited(
  req: Request,
  config: SupabaseRuntimeConfig,
  admin: SupabaseClient,
  bucket: string,
  policy: LimitPolicy,
): Promise<AuthenticatedUser> {
  const user = await authenticate(req, config);
  const secret = Deno.env.get("RATE_LIMIT_HASH_SECRET")?.trim();
  if (!secret || secret.length < 16) {
    throw new HttpError(
      500,
      "rate_limit_misconfigured",
      "The service is not configured safely.",
    );
  }

  const userAllowed = await consume(
    admin,
    bucket,
    await subjectHash(secret, `user:${user.id}`),
    policy.userLimit,
    policy.windowSeconds,
  );
  const ip = requestIp(req);
  const ipAllowed = ip
    ? await consume(
      admin,
      `${bucket}_ip`,
      await subjectHash(secret, `ip:${ip}`),
      policy.ipLimit,
      policy.windowSeconds,
    )
    : true;

  if (!userAllowed || !ipAllowed) {
    throw new HttpError(429, "rate_limited", "Too many requests. Try again shortly.");
  }
  return user;
}

async function consume(
  admin: SupabaseClient,
  bucket: string,
  subjectHashValue: string,
  limit: number,
  windowSeconds: number,
): Promise<boolean> {
  const { data, error } = await admin.rpc("consume_rate_limit", {
    p_bucket: bucket,
    p_subject_hash: subjectHashValue,
    p_limit: limit,
    p_window_seconds: windowSeconds,
  });
  if (error) throw error;
  return data === true;
}

async function subjectHash(secret: string, subject: string): Promise<string> {
  const data = new TextEncoder().encode(`${secret}:${subject}`);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function requestIp(req: Request): string | null {
  const raw = req.headers.get("cf-connecting-ip") ??
    req.headers.get("x-real-ip") ??
    req.headers.get("x-forwarded-for")?.split(",")[0] ??
    "";
  const value = raw.trim().toLowerCase();
  return value && value.length <= 64 && /^[0-9a-f:.]+$/.test(value) ? value : null;
}
