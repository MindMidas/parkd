const LOCAL_ORIGINS = [
  "http://localhost:3000",
  "http://localhost:5173",
  "http://localhost:8080",
  "http://127.0.0.1:3000",
  "http://127.0.0.1:5173",
  "http://127.0.0.1:8080",
] as const;

const REQUEST_ID_PATTERN = /^[A-Za-z0-9._:-]{1,80}$/;
const JSON_CONTENT_TYPE_PATTERN = /^application\/json(?:\s*;|$)/i;

export class HttpError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    readonly publicMessage: string,
    readonly logContext?: Record<string, unknown>,
  ) {
    super(publicMessage);
    this.name = "HttpError";
  }
}

export function requestIdFor(req: Request): string {
  const supplied = req.headers.get("x-request-id")?.trim();
  return supplied && REQUEST_ID_PATTERN.test(supplied) ? supplied : crypto.randomUUID();
}

export function configuredAllowedOrigins(): readonly string[] {
  const raw = (Deno.env.get("SUPABASE_FUNCTION_ALLOWED_ORIGINS") ?? "").trim();

  if (!raw) return LOCAL_ORIGINS;

  const origins = raw
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean);

  if (origins.includes("*")) {
    throw new HttpError(
      500,
      "cors_misconfigured",
      "This service is not configured safely.",
    );
  }

  for (const origin of origins) {
    let parsed: URL;
    try {
      parsed = new URL(origin);
    } catch {
      throw new HttpError(
        500,
        "cors_misconfigured",
        "This service is not configured safely.",
      );
    }
    if (parsed.origin !== origin || !["http:", "https:"].includes(parsed.protocol)) {
      throw new HttpError(
        500,
        "cors_misconfigured",
        "This service is not configured safely.",
      );
    }
  }

  return [...new Set(origins)];
}

/** Native clients do not send Origin. Browser origins must match the allowlist. */
export function assertAllowedOrigin(req: Request): string | null {
  const origin = req.headers.get("origin")?.trim() || null;
  if (origin && !configuredAllowedOrigins().includes(origin)) {
    throw new HttpError(403, "origin_not_allowed", "Origin is not allowed.");
  }
  return origin;
}

export function corsHeadersFor(req: Request): Record<string, string> {
  const origin = req.headers.get("origin")?.trim();
  const headers: Record<string, string> = {
    "Access-Control-Allow-Headers":
      "authorization, apikey, content-type, idempotency-key, x-client-info, x-request-id",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Max-Age": "600",
    "Vary": "Origin",
  };

  if (origin) {
    try {
      if (configuredAllowedOrigins().includes(origin)) {
        headers["Access-Control-Allow-Origin"] = origin;
      }
    } catch {
      // Keep the response unreadable cross-origin when the allowlist is invalid.
      // assertAllowedOrigin() is responsible for returning the configuration error.
    }
  }

  return headers;
}

export function securityHeaders(): Record<string, string> {
  return {
    "Cache-Control": "no-store",
    "Content-Security-Policy": "default-src 'none'; frame-ancestors 'none'",
    "Referrer-Policy": "no-referrer",
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
  };
}

export function optionsResponse(req: Request, requestId = requestIdFor(req)): Response {
  try {
    assertAllowedOrigin(req);
    return new Response(null, {
      status: 204,
      headers: {
        ...corsHeadersFor(req),
        ...securityHeaders(),
        "X-Request-Id": requestId,
      },
    });
  } catch (error) {
    return errorResponse(req, error, requestId);
  }
}

export function assertPostJson(req: Request): void {
  assertAllowedOrigin(req);
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

  const contentLength = Number(req.headers.get("content-length") ?? "0");
  if (Number.isFinite(contentLength) && contentLength > 16_384) {
    throw new HttpError(413, "request_too_large", "Request body is too large.");
  }
}

export async function readJsonObject(req: Request): Promise<Record<string, unknown>> {
  const text = await req.text();
  if (new TextEncoder().encode(text).byteLength > 16_384) {
    throw new HttpError(413, "request_too_large", "Request body is too large.");
  }

  let value: unknown;
  try {
    value = JSON.parse(text || "{}");
  } catch {
    throw new HttpError(400, "invalid_json", "Request body must be valid JSON.");
  }

  if (!value || Array.isArray(value) || typeof value !== "object") {
    throw new HttpError(400, "invalid_body", "Request body must be a JSON object.");
  }
  return value as Record<string, unknown>;
}

export function assertOnlyKeys(
  body: Record<string, unknown>,
  allowed: readonly string[],
): void {
  const unexpected = Object.keys(body).filter((key) => !allowed.includes(key));
  if (unexpected.length > 0) {
    throw new HttpError(400, "unexpected_field", "Request contains an unexpected field.");
  }
}

export function requiredString(
  body: Record<string, unknown>,
  key: string,
  options: { maxLength?: number; pattern?: RegExp } = {},
): string {
  const value = body[key];
  if (typeof value !== "string" || !value.trim()) {
    throw new HttpError(400, "invalid_body", `${key} is required.`);
  }
  const normalized = value.trim();
  if (normalized.length > (options.maxLength ?? 256)) {
    throw new HttpError(400, "invalid_body", `${key} is invalid.`);
  }
  if (options.pattern && !options.pattern.test(normalized)) {
    throw new HttpError(400, "invalid_body", `${key} is invalid.`);
  }
  return normalized;
}

export function optionalString(
  body: Record<string, unknown>,
  key: string,
  options: { maxLength?: number; pattern?: RegExp } = {},
): string | null {
  if (body[key] == null) return null;
  return requiredString(body, key, options);
}

export function json(
  req: Request,
  body: Record<string, unknown>,
  status = 200,
  requestId = requestIdFor(req),
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeadersFor(req),
      ...securityHeaders(),
      "Content-Type": "application/json; charset=utf-8",
      "X-Request-Id": requestId,
    },
  });
}

export function webhookJson(
  body: Record<string, unknown>,
  status: number,
  requestId: string,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...securityHeaders(),
      "Content-Type": "application/json; charset=utf-8",
      "X-Request-Id": requestId,
    },
  });
}

export function errorResponse(
  req: Request,
  error: unknown,
  requestId = requestIdFor(req),
): Response {
  const httpError = error instanceof HttpError ? error : mapUnknownError(error);

  safeLog(httpError.status >= 500 ? "error" : "warn", "request_failed", {
    request_id: requestId,
    error_code: httpError.code,
    ...(httpError.logContext ?? {}),
  });

  return json(
    req,
    {
      error: httpError.publicMessage,
      error_code: httpError.code,
      request_id: requestId,
    },
    httpError.status,
    requestId,
  );
}

/** Prefer specific provider errors over a generic 500 when possible. */
export function mapUnknownError(error: unknown): HttpError {
  const message = errorMessage(error);
  const code = errorCode(error);
  const lower = message.toLowerCase();

  if (
    lower.includes("signed up for connect") ||
    lower.includes("responsible for negative balances") ||
    (lower.includes("connect") && lower.includes("not been set up")) ||
    code === "platform_account_required"
  ) {
    return new HttpError(
      503,
      "connect_not_enabled",
      "Stripe Connect is not enabled for this Stripe account yet. In the Stripe Dashboard (test mode), open Connect settings, complete platform setup, then try Set up payouts again.",
      { stripe_message: message.slice(0, 240), stripe_code: code },
    );
  }

  if (
    lower.includes("overlap_reservation") ||
    lower.includes("reservations_no_checkout_overlap") ||
    code === "23P01"
  ) {
    return new HttpError(
      409,
      "overlap_reservation",
      "That time overlaps another booking for this spot. Pick a free time and try again.",
      { stripe_message: message.slice(0, 240), stripe_code: code },
    );
  }

  if (
    lower.includes("account links") &&
    (lower.includes("invalid") || lower.includes("url"))
  ) {
    return new HttpError(
      502,
      "connect_return_url",
      "Payout setup could not open Stripe onboarding. Check STRIPE_CONNECT_RETURN_URL / REFRESH_URL secrets.",
      { stripe_message: message.slice(0, 240), stripe_code: code },
    );
  }

  if (message && isPaymentProviderError(error)) {
    return new HttpError(
      502,
      "payment_provider_error",
      "The payment service could not complete the request. Try again.",
      { stripe_message: message.slice(0, 240), stripe_code: code },
    );
  }

  return new HttpError(
    500,
    "internal_error",
    "The service could not complete the request.",
    {
      cause: error instanceof Error ? error.name : typeof error,
    },
  );
}

function errorMessage(error: unknown): string {
  if (error instanceof Error && error.message.trim()) return error.message.trim();
  if (error && typeof error === "object") {
    const raw = (error as { raw?: { message?: unknown } }).raw;
    if (typeof raw?.message === "string" && raw.message.trim()) {
      return raw.message.trim();
    }
    const msg = (error as { message?: unknown }).message;
    if (typeof msg === "string" && msg.trim()) return msg.trim();
  }
  return "";
}

function errorCode(error: unknown): string | null {
  if (!error || typeof error !== "object") return null;
  const code = (error as { code?: unknown }).code;
  if (typeof code === "string" && code.trim()) return code.trim();
  // PostgREST / supabase-js often nests Postgres codes under `details` or `hint`.
  const details = (error as { details?: unknown }).details;
  if (typeof details === "string" && /^[0-9A-Z]{5}$/.test(details.trim())) {
    return details.trim();
  }
  return null;
}

function isPaymentProviderError(error: unknown): boolean {
  if (!error || typeof error !== "object") return false;
  const value = error as {
    raw?: unknown;
    requestId?: unknown;
    statusCode?: unknown;
    type?: unknown;
  };
  return (
    value.raw != null && typeof value.raw === "object" ||
    typeof value.requestId === "string" ||
    typeof value.statusCode === "number" ||
    (typeof value.type === "string" && value.type.startsWith("Stripe"))
  );
}

export function safeLog(
  level: "info" | "warn" | "error",
  event: string,
  context: Record<string, unknown>,
): void {
  const payload = JSON.stringify({
    timestamp: new Date().toISOString(),
    level,
    event,
    ...context,
  });
  if (level === "error") console.error(payload);
  else if (level === "warn") console.warn(payload);
  else console.info(payload);
}
