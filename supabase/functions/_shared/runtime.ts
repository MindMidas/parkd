import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";
import Stripe from "npm:stripe@17.4.0";

import { HttpError } from "./http.ts";

export interface AuthenticatedUser {
  id: string;
  email?: string;
}

export interface SupabaseRuntimeConfig {
  supabaseUrl: string;
  anonKey: string;
  serviceRoleKey: string;
}

export interface RuntimeConfig extends SupabaseRuntimeConfig {
  stripeSecretKey: string;
}

function requiredEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) {
    throw new HttpError(
      500,
      "service_misconfigured",
      "The payment service is not configured.",
      { missing_env: name },
    );
  }
  return value;
}

export function supabaseRuntimeConfig(): SupabaseRuntimeConfig {
  return {
    supabaseUrl: requiredEnv("SUPABASE_URL"),
    anonKey: requiredEnv("SUPABASE_ANON_KEY"),
    serviceRoleKey: requiredEnv("SUPABASE_SERVICE_ROLE_KEY"),
  };
}

export function runtimeConfig(): RuntimeConfig {
  const config = {
    ...supabaseRuntimeConfig(),
    stripeSecretKey: requiredEnv("STRIPE_SECRET_KEY"),
  };
  assertTestStripeSecret(config.stripeSecretKey);
  return config;
}

export function assertTestStripeSecret(secret: string): void {
  if (!secret.startsWith("sk_test_") || secret.length < 16) {
    throw new HttpError(
      500,
      "live_payments_disabled",
      "This portfolio demo only supports Stripe test mode.",
    );
  }
}

export function stripeClient(secret: string): Stripe {
  assertTestStripeSecret(secret);
  return new Stripe(secret, {
    appInfo: { name: "Parkd portfolio demo" },
    maxNetworkRetries: 2,
  });
}

export function adminClient(config: SupabaseRuntimeConfig): SupabaseClient {
  return createClient(config.supabaseUrl, config.serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

export function bearerToken(req: Request): string {
  const authorization = req.headers.get("authorization")?.trim() ?? "";
  const match = /^Bearer\s+([^\s]+)$/i.exec(authorization);
  const token = match?.[1];
  if (!token || token.length > 8192) {
    throw new HttpError(401, "unauthorized", "A valid sign-in session is required.");
  }
  return token;
}

export async function authenticate(
  req: Request,
  config: SupabaseRuntimeConfig,
): Promise<AuthenticatedUser> {
  const token = bearerToken(req);
  const authClient = createClient(config.supabaseUrl, config.anonKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data, error } = await authClient.auth.getUser(token);
  if (error || !data.user) {
    throw new HttpError(401, "unauthorized", "A valid sign-in session is required.");
  }
  return { id: data.user.id, email: data.user.email };
}

export function assertTestModeObject(
  object: { livemode?: boolean },
  objectType: string,
): void {
  if (object.livemode !== false) {
    throw new HttpError(
      500,
      "live_object_rejected",
      "This portfolio demo only accepts Stripe test data.",
      { stripe_object: objectType },
    );
  }
}

export function stripeIdempotencyKey(namespace: string, stableId: string): string {
  const normalized = stableId.replace(/[^A-Za-z0-9_-]/g, "-").slice(0, 160);
  return `parkd-demo:${namespace}:${normalized}:v1`;
}
