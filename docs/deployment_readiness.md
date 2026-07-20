# Parkd deployment readiness

Parkd has two different release lanes. The portfolio lane is a public Vercel
demo with Stripe test mode and short-lived demo data. A public App Store or
Google Play marketplace release needs additional product, legal, and account
owner work that cannot be completed in source control.

## Implemented in the repository

- The application/bundle identifier is `app.parkd.mobile` on Android, iOS,
  macOS, and Linux. Desktop display and copyright metadata is neutral.
- Android compiles and targets API 36, the requirement for new Google Play
  submissions beginning August 31, 2026.
- Android release builds never fall back to a debug key. Release tasks fail
  closed until a real upload keystore is supplied. R8/resource shrinking and
  native symbol output are enabled.
- Android backups, device transfer, cleartext HTTP, and unnecessary storage and
  camera permissions are disabled. Location remains optional.
- iOS targets iOS 14+, has no hard-coded Apple Team ID, and supports an ignored
  local signing configuration. Only location, camera, and photo-library purpose
  strings are present.
- `PrivacyInfo.xcprivacy` declares Parkd's current data categories, no tracking,
  and the UserDefaults required-reason API. Included Mapbox, Stripe, and Flutter
  plugins provide their own manifests where available.
- Web/PWA metadata and icons identify Parkd rather than Flutter. The pinned
  CropperJS resources use Subresource Integrity.
- Environment files are not bundled. Runtime public configuration is supplied
  with Dart defines; backend secrets stay in Supabase.
- Checkout pricing, holds, overlap prevention, payment records, and Stripe
  finalization are server-authoritative and idempotent.
- Public map/profile projections omit exact locations and private identity
  fields. Reporting, blocking, write throttles, soft deletion, account
  anonymization, and demo-retention functions are included.
- Scoped in-app notifications provide realtime booking/message/review badges
  without storing message bodies or adding a device-token/push dependency.
- GitHub Actions runs Flutter tests/coverage, Deno checks, secret scanning,
  pgTAP security tests, a release web build, and deployment of the tested
  artifact.

## External blockers for signed mobile artifacts

These require credentials or ownership and are intentionally absent from git:

### Android

1. Enroll in Google Play Console and create `app.parkd.mobile`.
2. Enable Play App Signing and create a dedicated upload keystore. Copy
   `android/key.properties.example` to ignored `android/key.properties`, or set
   the four `PARKD_ANDROID_*` CI environment variables.
3. Create a secret Mapbox token with only `Downloads: Read` scope and expose it
   as `SDK_REGISTRY_TOKEN` to Gradle locally/CI. This is a dependency-download
   credential, not the public `MAPBOX_ACCESS_TOKEN` Dart define, and must never
   be committed or bundled.
4. Keep the keystore, passwords, Play service-account credentials, mapping file,
   and native debug-symbol archive in the owner-controlled release vault.
5. Complete the Data Safety, account deletion, content rating, app access, ads,
   and user-generated-content declarations.

### iOS

1. Enroll in the Apple Developer Program, register `app.parkd.mobile`, and
   create the App Store Connect record.
2. Copy `ios/Flutter/Signing.xcconfig.example` to ignored
   `ios/Flutter/Signing.xcconfig` and set the owning Team ID, or configure the
   Runner target in Xcode.
3. Install an Apple Distribution certificate and App Store provisioning
   profile, or allow Xcode automatic signing for the owning team.
4. If a clean CocoaPods install requests Mapbox artifact authentication, store
   the owner-controlled Mapbox download token in the CI keychain/environment;
   never place it in an xcconfig committed to the app.
5. Archive with Xcode and generate the Privacy Report. Reconcile that report,
   Mapbox/Stripe SDK disclosures, and `docs/privacy_data_inventory.md` with App
   Privacy before submission.

Without those accounts, certificates/profiles, keystore, and passwords, the
repository can validate unsigned/simulator builds but cannot produce
uploadable signed artifacts.

The manually dispatched `Native release smoke` GitHub workflow compiles an
Android release with a disposable, non-distributable QA key and an iOS
simulator build. It is intentionally separate from the Vercel pipeline so the
more expensive macOS runner is used only when requested. A successful smoke run
does not replace store signing or physical-device QA.

## Product and legal blockers for a public store release

- Publish stable HTTPS privacy, terms, support, and web account-deletion URLs
  on an owned domain. Do not use a personal email address or a public issue as a
  deletion channel. Google requires both an in-app deletion path and a web
  deletion resource; Apple requires deletion initiation in the app.
- Replace the custom password-reset URL scheme with an owned HTTPS Universal
  Link / verified Android App Link before a commercial launch.
- Remove the optional date-of-birth field unless a documented product/legal
  requirement justifies collecting it.
- Publish moderation rules, provide a monitored support path and response
  process, and prepare reviewer credentials and review notes. Report/block UI
  and database enforcement are already present.
- Prepare store descriptions, keywords, age/content ratings, localized privacy
  text, phone/tablet screenshots, feature graphics, and a support website.
- Decide whether Parkd remains a no-money portfolio demo or becomes a real
  marketplace. The repository deliberately rejects live Stripe keys. A real
  service also needs host onboarding/payouts, refunds/disputes, taxes, insurance,
  parking authorization, marketplace terms, and operational support.

## Runtime configuration

Public client values supplied at build time:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY` (publishable/anonymous key only)
- `MAPBOX_ACCESS_TOKEN` (app-restricted public token for native builds; optional
  and empty for the Vercel fallback)
- `STRIPE_PUBLISHABLE_KEY` (`pk_test_...` in the portfolio lane)
- `TURNSTILE_SITE_KEY` for web
- `PASSWORD_RESET_REDIRECT_URL`

Supabase-only secrets:

- `SUPABASE_SERVICE_ROLE_KEY`
- `STRIPE_SECRET_KEY` (`sk_test_...` in the portfolio lane)
- `STRIPE_WEBHOOK_SECRET`
- `SUPABASE_FUNCTION_ALLOWED_ORIGINS`
- `RATE_LIMIT_HASH_SECRET` (at least 16 random characters)
- `GEOCODER_CONTACT_EMAIL`

Deploy migrations and all functions under `supabase/functions/`, including
payment intent/setup/finalization, webhook, account deletion, and geocoding.
The `purge-expired-demo-data` function is the single scheduled worker: it
advances reservation lifecycle state, claims at most 25 cleanup jobs, deletes
Stripe test customers and account-owned media, prepares/anonymizes relational data,
deletes Supabase Auth users, records completion, and removes notification
metadata older than 30 days. Configure Supabase Cron (or
an equivalent secret-capable scheduler) exactly as follows:

- Schedule: `*/5 * * * *`
- Method: `POST`
- URL: `https://<project-ref>.supabase.co/functions/v1/purge-expired-demo-data`
- Headers: `Authorization: Bearer <SUPABASE_SERVICE_ROLE_KEY>` and
  `Content-Type: application/json`
- Body: `{"limit":25}`

The equivalent one-off health check is:

```sh
curl --fail-with-body --request POST \
  "$SUPABASE_URL/functions/v1/purge-expired-demo-data" \
  --header "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  --header "Content-Type: application/json" \
  --data '{"limit":25}'
```

Store the function URL and service-role key in Supabase Vault/scheduler secrets
or the external scheduler's encrypted secret store. Never place the service key
in Flutter/Vercel variables, GitHub source, logs, or a browser request. This
machine endpoint requires Supabase gateway JWT verification and also fails
closed by comparing the bearer value to `SUPABASE_SERVICE_ROLE_KEY` inside the
handler. A non-2xx response means at least one job remains incomplete; the next
five-minute run reclaims it, and repeated failures should alert the operator.
Keep `STRIPE_SECRET_KEY` set to an `sk_test_...` value in the function runtime;
the worker refuses live Stripe keys.

## Quality and release commands

```sh
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test test --coverage
cd supabase/functions
deno fmt --check
deno lint
deno task check
deno task test
cd ../..
supabase db reset
supabase test db
```

```sh
flutter build web --release \
  --dart-define-from-file=dart_defines.local.json
```

```sh
flutter build appbundle --release \
  --dart-define-from-file=dart_defines.local.json
```

```sh
flutter build ipa --release \
  --dart-define-from-file=dart_defines.local.json
```

Before upload, inspect the Android merged manifest, AAB signing certificate,
iOS archive privacy report, release symbols, nested-route recovery, account
deletion, denied permissions, offline/error states, and Stripe test flows.

The supported release targets are iOS, Android, and web. Flutter's generated
macOS, Windows, and Linux runners remain development scaffolding; they have not
received desktop sandbox/permission QA and are not release targets.

## Official references

- [Google Play target API requirements](https://developer.android.com/google/play/requirements/target-sdk)
- [Google Play Data Safety](https://support.google.com/googleplay/android-developer/answer/10787469)
- [Google Play account deletion](https://support.google.com/googleplay/android-developer/answer/13327111)
- [Apple privacy manifests](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
- [Apple App Privacy](https://developer.apple.com/app-store/app-privacy-details/)
- [Apple account deletion](https://developer.apple.com/support/offering-account-deletion-in-your-app/)
