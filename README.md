<p align="center">
  <img src="lib/core/assets/logo.png" alt="Parkd Logo" width="200"/>
</p>

<h1 align="center">Parkd</h1>

<p align="center">
  <strong>CIS*4030 – Mobile Computing | Group 14</strong><br/>
  Paul Mancion · Ashmit Mittal · Somtochukwu Umeh · Ayomide Awofisayo
</p>

---

## About

Parkd is a Flutter-based peer-to-peer parking marketplace designed to address the ongoing parking shortage at the University of Guelph. The app connects residents who have unused driveway or parking space with students and commuters who need convenient, affordable parking near campus.

Think of it as **Airbnb, but for parking spots.** Parkd turns underutilized private driveways into bookable parking spaces through a structured, location-based mobile platform.

## What You Can Do

**As a Driver (Student / Commuter):**

- Browse nearby available parking spots on an interactive map
- Filter listings by price, distance, and availability
- Book a spot for a specific time window and pay securely in-app
- Receive booking confirmation and navigate directly to the reserved spot
- View booking history and manage active reservations
- Rate and review hosts after parking

**As a Host (Resident Near Campus):**

- List your driveway or parking space with photos, pricing, and availability
- Annotate uploaded photos to highlight exact spots
- Set flexible pricing — hourly, daily, weekly, or monthly
- Manage incoming bookings through a host dashboard
- Track earnings and receive payouts via Stripe
- Communicate with drivers through in-app messaging

**Platform Highlights:**

- Map-based interface powered by OpenStreetMap (via `flutter_map`)
- Secure authentication and session management through Supabase
- Real-time booking updates
- Image hosting via Cloudinary
- Stripe-powered payment processing
- Push notifications for confirmations and reminders

## Project Structure (`lib/`)

```
lib/
├── main.dart                  # App entry point
├── app/                       # App-level configuration
│   ├── app.dart               # Root MaterialApp widget
│   ├── go_router_provider.dart# Route definitions (go_router)
│   ├── listing_invalidation.dart
│   ├── main_shell_tab_provider.dart
│   └── main_tab.dart
├── core/                      # Shared infrastructure & utilities
│   ├── assets/                # Static assets (logo, map pins, images)
│   ├── cloudinary/            # Cloudinary image upload helpers
│   ├── map/                   # Map utilities and configuration
│   ├── messaging/             # In-app messaging helpers
│   ├── models/                # Shared data models
│   ├── stripe/                # Stripe payment integration
│   ├── supabase/              # Supabase client, queries, and auth helpers
│   ├── theme/                 # App-wide theming (colors, typography)
│   ├── utils/                 # General utility functions
│   ├── validation/            # Input validation logic
│   └── widgets/               # Reusable UI components
└── features/                  # Feature modules (by domain)
    ├── auth/                  # Authentication (sign-up, login, verification)
    │   ├── data/
    │   ├── presentation/
    │   └── providers/
    ├── hosting/               # Host listing creation, editing, and management
    │   ├── data/
    │   ├── presentation/
    │   └── providers/
    ├── listings/              # Listing browsing and detail views
    ├── map/                   # Map screen and nearby-spot discovery
    │   ├── presentation/
    │   └── providers/
    ├── profile/               # User profile, settings, and earnings
    │   ├── data/
    │   ├── presentation/
    │   └── providers/
    └── reservations/          # Booking flow, history, and management
        ├── data/
        ├── presentation/
        └── providers/
```

Each feature follows a **layered architecture**: `data/` for repositories and API calls, `presentation/` for screens and widgets, and `providers/` for Riverpod state management.

## Tech Stack

- **Flutter (Dart)** — Cross-platform mobile framework
- **Supabase** — PostgreSQL database, authentication, real-time subscriptions
- **Cloudinary** — Image storage and hosting
- **Stripe** — Payment processing and host payouts
- **flutter_map + OpenStreetMap** — Interactive map display
- **Riverpod** — State management
- **go_router** — Declarative navigation
- **Geolocator** — Real-time GPS location
- **flutter_secure_storage** — Secure token storage

## Getting Started

1. `flutter pub get`
2. Copy env for local runs (`.env` is gitignored):
   ```
   cp .env.example .env
   ```
   Then edit `.env` with your Supabase **Project URL** and **anon key** and set Stripe CLI secret and Edge Functions.
3. `flutter run`

**GitLab CI** runs `flutter analyze` and a **`flutter build web --release`** smoke build.