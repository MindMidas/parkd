# Parkd

Parkd is a Flutter-based peer-to-peer parking marketplace for discovering, listing, booking, and managing parking spaces.

## Run

1. `flutter pub get`
2. Copy `.env.example` to `.env` and configure the required Supabase, Stripe, Mapbox, and Cloudinary values.
3. `flutter run`

CI is configured to run `flutter analyze` and a `flutter build web --release` smoke build.
