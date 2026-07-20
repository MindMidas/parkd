# Parkd security review

## Controls implemented

- Client builds contain public runtime configuration only; secret/environment
  files are neither loaded nor bundled.
- Native sessions and PKCE verifiers use Keychain/Keystore-backed storage. The
  web demo limits them to tab-scoped session storage and enforces an
  origin-restricted Content Security Policy.
- Public profiles exclude email, phone, birth date, Stripe IDs, and deletion
  metadata. Username/phone existence checks are not exposed to clients.
- Public listings expose a coarse location, safe display text, public pricing,
  availability, and media only. Exact addresses/coordinates require ownership
  or a confirmed/active/completed reservation.
- Reservation/payment creation is atomic and server-authoritative. Clients do
  not send prices, fees, host IDs, payment states, or trusted Stripe fields.
- PostgreSQL exclusion constraints prevent overlapping pending, confirmed, or
  active reservations. Expiring holds and lifecycle changes are idempotent.
- Stripe objects are test-mode-only. Stable idempotency keys prevent duplicate
  intents/sessions; webhook signatures, metadata, amount, currency, event order,
  and event IDs are verified before state changes.
- RLS and triggers constrain profile, listing, reservation, payment, payment
  method, conversation, message, review, report, block, and storage access.
- Message content/participants are immutable; only recipients can mark messages
  read. Users can report listings/users/messages and block each other.
- In-app notifications are server-generated, owner-readable only, deduplicated,
  and contain routing IDs rather than message/review text or payment totals.
  Narrow owner RPCs handle read/delete state, and the scheduled cleanup worker
  removes notification metadata after 30 days. No device-token or push service
  is present in the current tree.
- Uploads are owner-scoped, path constrained, size limited, and checked for
  JPEG/PNG magic bytes before upload. Unsigned Cloudinary uploads were removed.
- Edge Functions enforce JWTs where applicable, strict methods/content types,
  request schemas and sizes, explicit CORS origins, safe redirects, structured
  errors, bounded upstream timeouts, and distributed user/IP rate limits.
- Address search uses a fixed-host backend proxy; clients do not directly fan
  out to public geocoders.
- Account deletion removes external test payment/storage/auth data and
  anonymizes records retained for referential or financial integrity. Clients
  cannot call preparation or queue-management RPCs directly; only the
  authenticated deletion Edge Function and exact service-role cron endpoint
  can advance the resumable cleanup job.
- Database pgTAP tests cover cross-user reads/writes, tampered totals, overlaps,
  state transitions, moderation, storage, notification isolation/retention, and
  trusted RPC grants. Edge handlers have hermetic mocked tests.

The preserved project history contains retired Firebase client configuration
from an earlier notification experiment. Those public client identifiers are
narrowly path-allowlisted for Gitleaks; the files and push implementation are
absent from the current tree. Before making the repository public, the owner
must verify the old Firebase project's API restrictions and rules or retire the
project entirely.

## Deployment-sensitive controls

These controls are correct only when operators configure them:

- Use a dedicated demo Supabase project and Stripe test account.
- Set exact allowed origins; never use `*` in production CORS.
- Keep service-role, Stripe secret/webhook, rate-limit hash, and contact values
  only in Supabase secrets.
- Restrict native Mapbox tokens to owned app IDs and Turnstile keys to deployed
  web origins.
- Register and monitor the Stripe webhook and reconciliation flags.
- Invoke `purge-expired-demo-data` every five minutes with an exact service-role
  bearer token from an encrypted scheduler secret. It also advances checkout
  lifecycle state. Alert on repeated non-2xx results; never expose this
  credential to Flutter, Vercel, source control, logs, or browsers.
- Review CSP reports, dependency advisories, logs, backups, and retention jobs.

## Not a production marketplace approval

The repository is suitable for a portfolio demo using synthetic data and test
payments. Live deployment would additionally require independent penetration
testing, legal/privacy review, fraud/chargeback controls, identity and property
verification, tax/payout design, moderation staffing, incident response,
observability, disaster recovery, accessibility/device QA, and an updated threat
model. The code intentionally rejects live Stripe data until that work exists.
