<p align="center">
  <img src="lib/core/assets/logo.png" alt="Parkd" width="170">
</p>

<p align="center">
  <strong>Find a spot. Park easy.</strong><br>
  A parking marketplace built with Flutter
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Parking%20Search-334155?style=for-the-badge&labelColor=eaf2ff" alt="Parking search">
  <img src="https://img.shields.io/badge/Reservations-334155?style=for-the-badge&labelColor=eaf2ff" alt="Reservations">
  <img src="https://img.shields.io/badge/Host%20Tools-334155?style=for-the-badge&labelColor=eaf2ff" alt="Host tools">
  <img src="https://img.shields.io/badge/Messaging-334155?style=for-the-badge&labelColor=eaf2ff" alt="Messaging">
</p>

<p align="center">
  <a href="https://flutter.dev/"><img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter"></a>
  <a href="https://dart.dev/"><img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart"></a>
  <a href="https://riverpod.dev/"><img src="https://img.shields.io/badge/Riverpod-0553B1?style=for-the-badge" alt="Riverpod"></a>
  <a href="https://supabase.com/"><img src="https://img.shields.io/badge/Supabase-3FCF8E?style=for-the-badge&logo=supabase&logoColor=white" alt="Supabase"></a>
  <a href="https://www.postgresql.org/"><img src="https://img.shields.io/badge/PostgreSQL-4169E1?style=for-the-badge&logo=postgresql&logoColor=white" alt="PostgreSQL"></a>
  <a href="https://stripe.com/"><img src="https://img.shields.io/badge/Stripe-635BFF?style=for-the-badge&logo=stripe&logoColor=white" alt="Stripe"></a>
  <a href="https://www.mapbox.com/"><img src="https://img.shields.io/badge/Mapbox-000000?style=for-the-badge&logo=mapbox&logoColor=white" alt="Mapbox"></a>
  <a href="https://vercel.com/"><img src="https://img.shields.io/badge/Vercel-000000?style=for-the-badge&logo=vercel&logoColor=white" alt="Vercel"></a>
</p>

## Overview

Parkd is a mobile parking marketplace where drivers can find and reserve nearby
parking, and hosts can list unused spaces. It started as a university project
and grew into a larger full-stack Flutter app with payments, messaging, account
security, and a tested Supabase backend.

The public website runs in **Showcase Mode**. It uses sample data in the browser,
does not need an account, and cannot make a real payment. The full connected app
is still included in the repository.

## Features

- Search sample parking spots and view privacy-safe approximate pins.
- Walk through a local reservation and simulated checkout.
- View upcoming reservations and a sample host conversation.
- Check hosting earnings, bookings, listing views, and ratings.
- Connected implementation for Supabase Auth, PostgreSQL RLS, Storage, realtime
  messaging, Stripe test checkout, and Mapbox.
- Unit, widget, integration, Edge Function, and database security tests.

## Quick Start

Install [Flutter 3.41.5](https://docs.flutter.dev/get-started/install), then run:

```bash
flutter pub get
flutter run -d chrome --dart-define=PARKD_SHOWCASE=true
```

Showcase Mode is completely local. No environment variables or API keys are
needed.

## Connected App

To work on the real backend-connected mobile app:

```bash
cp dart_defines.example.json dart_defines.local.json
flutter run --dart-define-from-file=dart_defines.local.json
```

Fill `dart_defines.local.json` with public client configuration only:

- Supabase URL and publishable/anonymous key
- Mapbox public token
- Stripe **test** publishable key
- Turnstile public site key
- Password-reset callback URL

Do not place service-role keys, Stripe secret keys, webhook secrets, or other
private credentials in the Flutter app. Backend setup is covered in
[`docs/deployment_readiness.md`](docs/deployment_readiness.md).

## Tests

```bash
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test test --coverage

cd supabase/functions
deno fmt --check
deno lint
deno task check
deno task test
```

Database security tests use a local Supabase stack:

```bash
supabase start
supabase test db
```

## Project Map

| Path | Purpose |
|---|---|
| `lib/` | Flutter features, providers, repositories, and shared UI |
| `lib/showcase/` | Offline public portfolio experience |
| `test/` | Unit, repository, routing, and widget tests |
| `integration_test/` | App launch and navigation smoke tests |
| `supabase/migrations/` | Database schema, RLS, payments, and moderation |
| `supabase/functions/` | Stripe, geocoding, deletion, and rate-limited APIs |
| `docs/` | Deployment, privacy, security, and store-readiness notes |

## Deployment

The portfolio build is deployed to Vercel from GitHub Actions. It compiles with
`PARKD_SHOWCASE=true`, so no backend or payment keys are included in the site.
Only the Vercel deployment credentials are required.

After adding those credentials, open **Actions → Quality and Vercel deployment
→ Run workflow** in GitHub.

## License

Copyright © 2026 MindMidas. All rights reserved.

This repository is public for portfolio and educational review. Permission is
not granted to copy, redistribute, publish, sell, or submit this project as your
own work. See [`LICENSE`](LICENSE) for details.
