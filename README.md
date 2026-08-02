<p align="center">
  <img src="lib/core/assets/logo.png" alt="Parkd" width="170">
</p>

<p align="center">
  <strong>Space to spare. Parking to share.</strong><br>
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
</p>

<p align="center">
  <img src="docs/assets/showcase/slide_1.png" alt="Parkd app screens showing login, map, listing, and location views" width="100%">
</p>

## Overview

Parkd is a parking marketplace where drivers can find and reserve nearby
parking while hosts can list and manage unused spaces. The application includes
payments, messaging, listing management, availability, notifications, and a
Supabase backend protected by PostgreSQL RLS.

## Features

- Search parking spots and view approximate locations on Mapbox.
- Reserve available parking and complete Stripe checkout (test mode for local).
- Manage active and past reservations with participant messaging.
- Create listings, upload photos, configure availability, and review earnings.
- Manage profiles, payment methods, and notification preferences.

## More Frames

<p align="center">
  <img src="docs/assets/showcase/slide_2.png" alt="Parkd app screens showing booking, review, messages, and hosting views" width="100%">
  <img src="docs/assets/showcase/slide_3.png" alt="Parkd app screens showing location sharing, spot marking, availability, and listing heatmap views" width="100%">
</p>

## Quick Start

Install [Flutter 3.41.5](https://docs.flutter.dev/get-started/install), then run:

```bash
cp dart_defines.example.json dart_defines.local.json
flutter pub get
flutter run --dart-define-from-file=dart_defines.local.json
```

Put your Supabase, Mapbox, and Stripe (test) keys in `dart_defines.local.json`.

## Checks

```bash
flutter analyze
flutter build web --release
```

## Project Map

| Path | Purpose |
|---|---|
| `lib/` | Flutter features, providers, repositories, and shared UI |
| `supabase/migrations/` | Database schema |
| `supabase/functions/` | Stripe, geocoding, and related APIs |

## Contributors

Parkd was created by [Paul Mancion](https://github.com/MindMidas),
[Somtochukwu Umeh](https://github.com/Augustine-Umeh),
[Ashmit Mittal](https://github.com/ashmitmittal04), and Ayomide Awofisayo.

## License

Copyright (c) 2026 Parkd contributors. All rights reserved. This source code is
provided for portfolio and review purposes only. See [LICENSE](LICENSE) for
details.
