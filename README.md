# Parkd

Parkd is a Flutter parking marketplace demo for discovering spaces, publishing
listings, reserving time slots, messaging hosts, and completing Stripe test
payments. The same codebase targets iOS, Android, and a Vercel-hosted web demo.
Generated desktop runners remain unsupported development scaffolding.

> **Portfolio demo:** Parkd accepts test data and Stripe test cards only. Never
> enter real personal, parking-access, or payment information. Demo accounts and
> their content are designed to expire after 24 hours.

## Highlights

- Approximate public map pins; exact locations are visible only to the host and
  drivers with a confirmed or completed reservation.
- Server-authoritative availability, pricing, service fees, reservation holds,
  and payment records.
- Stripe Payment Sheet on mobile and Stripe-hosted test Checkout on web.
- Signature-verified, idempotent Stripe webhooks as the payment source of truth.
- Supabase authentication, MFA, password recovery, row-level security, Storage,
  account deletion, reporting, blocking, and demo-data retention.
- Rate-limited Edge Functions for checkout, card setup, account deletion, and
  Nominatim/Photon geocoding.
- Responsive shared components with explicit loading, empty, error, offline,
  and retry states for critical flows.
- Flutter unit/widget tests, Supabase pgTAP security tests, Deno Edge Function
  tests, an integration smoke test, and release-web CI.

## Architecture

- `lib/` — Flutter app, feature repositories, Riverpod providers, and UI
- `test/` — unit, repository/provider, routing, and widget tests
- `integration_test/` — device-level launch/navigation smoke test
- `supabase/migrations/` — ordered schema, RLS, checkout, moderation, and
  retention migrations
- `supabase/tests/` — database security and cross-user access tests
- `supabase/functions/` — Stripe, deletion, rate-limit, and geocoding handlers
- `.github/workflows/` — secret scan, quality gates, and Vercel deployment
- `docs/` — security, privacy, deployment, and store-readiness notes

## Local setup

Install Flutter `3.41.5`, Dart `3.11.x`, Deno `2.4.5`, the Supabase CLI, and a
local PostgreSQL/Docker runtime supported by Supabase.

```sh
flutter pub get
cp dart_defines.example.json dart_defines.local.json
flutter run --dart-define-from-file=dart_defines.local.json
```

`dart_defines.local.json` is gitignored. Flutter configuration is compiled into
the client and therefore must contain public values only:

- Supabase project URL and anonymous/publishable key
- App-restricted Mapbox public token for native iOS/Android builds; web uses a
  privacy-safe listing fallback and does not require Mapbox
- Stripe key beginning with `pk_test_`
- Cloudflare Turnstile public site key
- Password-reset callback URL

Service-role, Stripe secret, webhook, rate-limit hash, and provider contact
values belong only in Supabase Edge Function secrets. Parkd does not bundle or
load a `.env` file.

## Quality gates

```sh
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test test --coverage
cd supabase/functions
deno fmt --check
deno lint
deno task check
deno task test
```

Run database/RLS tests against a disposable local Supabase stack:

```sh
supabase db reset
supabase test db
```

Run the integration smoke test on an attached simulator/device:

```sh
flutter test -d DEVICE_ID integration_test/app_smoke_test.dart
```

## Deployment

The portfolio web build targets Vercel Hobby. GitHub Actions tests one release
artifact and deploys that exact artifact after all quality gates pass. Vercel is
preferred over GitHub Pages here because Parkd needs reliable SPA route rewrites,
security headers, and authentication/payment callback routes.

See [deployment readiness](docs/deployment_readiness.md). Publishing still requires
the repository owner to supply external credentials, apply the migrations,
deploy Edge Functions, configure the Stripe webhook, and verify the live demo.

## Mobile stores

The code contains production bundle identifiers, privacy metadata, hardened
release configuration, and account/data deletion. Actual App Store and Google
Play submission still requires owned developer accounts, signing certificates,
provisioning, stable legal/support URLs, completed privacy questionnaires,
screenshots, device QA, and reviewer access. The portfolio demo must not be
presented as a production parking or payment service without a separate legal,
operational, and security review.

## Security

Do not report vulnerabilities through public demo content. Use the private
security contact configured by the repository owner. Technical controls and
remaining production limitations are documented in
[the security review](docs/security_review.md).
