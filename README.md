# Parkd

CIS*4030 Group 14 – mobile app.

## Group

- Paul Mancion  
- Ashmit Mittal  
- Somtochukwu Umeh  
- Ayomide Awofisayo

## Run

1. `flutter pub get`
2. Copy env for local runs (`.env` is gitignored):
  `cp .env.example .env`  
   Then edit `.env` with your Supabase **Project URL** and **anon key** and set Stripe CLI secret and Edge Functions.
3. `flutter run`

**GitLab CI** runs `flutter analyze` and a **`flutter build web --release`** smoke build.