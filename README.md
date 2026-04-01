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
- Book a spot for a specific time window and pay securely in-app via Stripe
- Receive booking confirmation and navigate directly to the reserved spot
- View booking history and manage active reservations

**As a Host (Resident Near Campus):**

- List your driveway or parking space with photos, pricing, and availability(weekly schedule or specific dates)
- Annotate uploaded photos to highlight exact spots
- Set flexible pricing — hourly, or daily
- Manage incoming bookings through a host dashboard
- Track earnings and receive payouts
- Communicate with drivers through in-app messaging

**Platform Highlights:**

- Map-based interface powered by Mapbox (`mapbox_maps_flutter`)
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

**Core Infrastructure:**

- **Flutter (Dart)** — Cross-platform mobile framework
- **Supabase** — PostgreSQL database, authentication, real-time subscriptions, and Edge Functions (Deno/TypeScript)
- **Cloudinary** — Image storage and hosting
- **Stripe** (`flutter_stripe`) — Payment processing and host payouts
- **Mapbox** (`mapbox_maps_flutter`) — Interactive map display

**Key Packages:**

- **Riverpod** (`flutter_riverpod`) — State management
- **go_router** — Declarative navigation
- **Geolocator** — Real-time GPS location
- **image_picker** + **image_cropper** — Photo capture and editing
- **google_fonts** — Custom typography
- **shared_preferences** — Local caching

**Utilities:**

- **flutter_dotenv** — Environment variable loading
- **url_launcher** — External link handling
- **intl** — Date and number formatting
- **flutter_svg** — SVG rendering
- **intl_phone_field** — International phone number input
- **package_info_plus** — App version info

<p align="center" style="overflow-x: auto; white-space: nowrap;">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter"/>
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart"/>
  <img src="https://img.shields.io/badge/Supabase-3FCF8E?style=for-the-badge&logo=supabase&logoColor=white" alt="Supabase"/>
  <img src="https://img.shields.io/badge/Stripe-635BFF?style=for-the-badge&logo=stripe&logoColor=white" alt="Stripe"/>
  <img src="https://img.shields.io/badge/Mapbox-000000?style=for-the-badge&logo=mapbox&logoColor=white" alt="Mapbox"/>
  <img src="https://img.shields.io/badge/Cloudinary-3448C5?style=for-the-badge&logo=cloudinary&logoColor=white" alt="Cloudinary"/>
  <img src="https://img.shields.io/badge/Riverpod-00B0FF?style=for-the-badge&logo=dart&logoColor=white" alt="Riverpod"/>
  <img src="https://img.shields.io/badge/Deno-000000?style=for-the-badge&logo=deno&logoColor=white" alt="Deno"/>
  <img src="https://img.shields.io/badge/PostgreSQL-4169E1?style=for-the-badge&logo=postgresql&logoColor=white" alt="PostgreSQL"/>
  <img src="https://img.shields.io/badge/Google_Fonts-4285F4?style=for-the-badge&logo=google&logoColor=white" alt="Google Fonts"/>
</p>

## Getting Started

1. `flutter pub get`
2. Copy env for local runs (`.env` is gitignored):
   ```
   cp .env.example .env
   ```
   Then edit `.env` with your Supabase **Project URL** and **anon key** and set Stripe CLI secret and Edge Functions.
3. `flutter run`

**GitLab CI** runs `flutter analyze` and a **`flutter build web --release`** smoke build.