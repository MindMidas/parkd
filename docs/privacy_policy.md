# Parkd portfolio demo privacy notice (draft)

Last updated: July 20, 2026

This notice describes the current Parkd portfolio demo. It is a technical
draft, not a published policy. Before public deployment, the project owner must
add an accountable organization/contact, publish the notice at a stable HTTPS
URL, and verify it against the deployed services and store disclosures.

## Demo limitation

Parkd is configured for Stripe test mode. Do not submit real payment details,
private messages, sensitive personal information, or a real parking address.
Demo accounts become eligible for cleanup after 24 hours. A worker runs every
five minutes and retries incomplete Stripe test-customer, upload, and Auth
deletion, so provider outages can delay completion. Anonymized transaction and
audit records needed for integrity remain until the portfolio database is
reset. Cleanup snapshots containing external identifiers are removed seven days
after a job completes. Provider logs and backups follow separately documented
provider retention and must be verified before publication.

## Information processed

- Account details: user ID, username, name, email address, optional phone
  number, optional date of birth, authentication state, and avatar.
- Listing details: address, precise and reduced-precision coordinates, price,
  availability, photos, and user-provided listing content.
- Reservation and test-payment details: participants, booking times, amounts,
  statuses, Stripe test identifiers, card brand, expiry, and last four digits.
  Parkd does not store full card numbers or security codes.
- Communications and safety: messages, reviews, reports, blocks, and moderation
  records.
- Location and search: device location when permission is granted and address
  search text/results. Location permission is optional.
- Security/operations: short-lived hashed rate-limit subjects, request metadata,
  error information, and audit records needed to prevent abuse and reconcile
  test transactions.

Native authentication credentials are kept in operating-system secure storage.
The web demo keeps its session only for the lifetime of the current browser tab.

## Purposes

Information is used only to provide the demo: authenticate accounts, show maps
and listings, create reservations, process test payments, enable messages and
reviews, prevent abuse, moderate content, support deletion, and diagnose
failures. Parkd does not sell data, serve behavioral advertising, or use data
to track people across other companies' apps and websites.

## Service providers

- Supabase provides authentication, database, policy-controlled public profile
  and listing media, and Edge Functions.
- Stripe provides test-mode payment interfaces and tokenized card references.
- Mapbox provides native iOS/Android map rendering. The web demo uses a local
  non-interactive fallback and does not contact Mapbox.
- OpenStreetMap Nominatim and Photon provide address search through a
  rate-limited Parkd Edge Function.
- Cloudflare Turnstile provides bot protection on the web sign-up flow.
- Vercel hosts the static web build. Parkd uses platform-native fonts and does
  not download a runtime web font.

Each provider may process network identifiers and technical request data under
its own terms. Provider configuration and disclosures must be reviewed again
before publication.

## Sharing and visibility

Public discovery exposes only reduced listing/profile fields and approximate
location. Precise listing addresses and participant details are limited to the
listing owner and eligible reservation participants under database policies.
Service providers receive only the information needed for their functions.

## Retention and deletion

The portfolio environment makes demo accounts eligible for cleanup after 24
hours. A signed-in user can initiate account deletion from the Account screen;
the client cannot invoke destructive database preparation directly. The trusted
cleanup service deletes Stripe test customers, account-owned uploads, and Auth users,
and anonymizes identity/contact fields. It retries partial failures and retains
its completed reconciliation snapshot for seven days. Anonymized
transaction/audit records remain until the portfolio database is reset. The
public deployment must publish a separate web deletion request path and state
concrete provider log/backup retention periods.

## User choices

Users can deny location access, search manually, edit optional profile data,
remove uploaded content where permitted, block or report users/content, remove
saved test payment methods, and initiate account deletion. Device permissions
can be changed in system settings.

## Security

Parkd uses encrypted HTTPS connections, restricted database/storage policies,
server-authoritative checkout values, Stripe webhooks, request validation,
rate limits, and secret separation. No internet service can guarantee absolute
security; the portfolio demo must not be used for real transactions.
