import 'turnstile_challenge_stub.dart'
    if (dart.library.js_interop) 'turnstile_challenge_web.dart'
    as platform;

/// Requests a one-time Cloudflare Turnstile token for Supabase Auth.
Future<String?> requestTurnstileToken(String siteKey) {
  return platform.requestTurnstileToken(siteKey);
}
