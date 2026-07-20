# Privacy and store disclosure inventory

This inventory maps current Parkd behavior to Apple and Google disclosure
categories. It is a preparation aid; the App Store Connect and Play Console
answers must also include data collected by every SDK in the final signed
artifact.

| Parkd data | Apple manifest category | Google Data Safety category | Linked to account | Purpose |
| --- | --- | --- | --- | --- |
| Name | Name | Personal info / Name | Yes | App functionality, account management |
| Email | Email address | Personal info / Email address | Yes | Authentication and account management |
| Optional phone | Phone number | Personal info / Phone number | Yes | Account/profile functionality |
| Username, Supabase ID, Stripe customer reference | User ID | Personal info / User IDs | Yes | Authentication, authorization, payments |
| Optional birth date | Other data types | Personal info / Other info | Yes | Profile functionality; remove if unnecessary |
| Listing address | Physical address | Location / Precise location | Yes | Listing and reservation functionality |
| Device/listing coordinates | Precise and coarse location | Precise and approximate location | Sometimes/Yes | Map, search, and listing functionality |
| Avatar and listing images | Photos or videos | Photos and videos / Photos | Yes | Profile and listing functionality |
| Stripe test token references, brand/last four/expiry | Payment info | Financial info / Payment info | Yes | Test checkout and saved-method display |
| Reservations and test transactions | Purchase history | Financial info / Purchase history | Yes | Booking, reconciliation, support |
| In-app messages | Emails or text messages | Messages / Other in-app messages | Yes | Participant communication |
| In-app notification event, routing IDs, read state | Other data types | App activity / Other actions | Yes | Booking, review, and message alerts |
| Listings, reviews, reports | Other user content | App activity / Other user-generated content | Yes | Marketplace and safety functionality |
| Address search text | Search history | App activity / Search history | Yes while signed in | Ephemeral address lookup |
| Hashed rate-limit/network subjects and error context | Other diagnostic data | App info and performance / Diagnostics; Device or other IDs where applicable | Possibly | Security, fraud prevention, reliability |

## Current declarations

- Tracking: **No**.
- Advertising: **None**.
- Data sale: **No**.
- Primary purpose: app functionality, including authentication, safety, fraud
  prevention, and customer support.
- Location, phone, birth date, and photos are optional from a feature
  perspective. Listing an actual parking space necessarily requires a location.
- Stripe is in test mode; full card number and CVC stay in Stripe interfaces and
  are not stored by Parkd.

## Final-release verification

1. Archive the iOS app and generate Xcode's Privacy Report. Verify manifests
   from Mapbox, Stripe, shared preferences, secure storage, image picker, and
   every other included SDK.
2. Inspect the Android merged manifest and Play SDK Index. Reconcile every
   permission and SDK declaration with the Data Safety form.
3. Confirm whether Supabase, Vercel, Mapbox, Stripe, Cloudflare, Nominatim,
   Photon, or runtime font delivery makes data a third-party “share” under the
   store definitions and the governing contracts.
4. Verify the deployed retention contract: demo accounts become eligible after
   24 hours; the cleanup worker runs every five minutes and retries incomplete
   Stripe test-customer, Storage, and Auth deletion; completed cleanup snapshots
   containing external identifiers are deleted after seven days. Anonymized
   reservation/payment rows needed for integrity remain until the portfolio
   Supabase project is reset. Separately document concrete provider retention
   for Edge logs, backups, Stripe records, and hosting logs before publication.
   Privacy-minimized in-app notification metadata is automatically deleted
   after 30 days by the same scheduled cleanup worker.
5. Re-run the inventory whenever a dependency, analytics/crash SDK, ad SDK,
   payment mode, or backend destination changes.
