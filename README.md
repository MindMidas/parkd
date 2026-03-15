# Parkd

CIS*4030 Group 14 – mobile app.

## Group

- Paul Mancion  
- Ashmit Mittal  
- Somtochukwu Umeh  
- Ayomide Awofisayo  

## Run

1. `flutter pub get`
2. `flutter run`

## Test

- `flutter test`

## Project layout

- **`lib/features/auth/`** – Signup + login
- **`lib/features/home/`** – Map and home screen
- **`lib/features/profile/`** – Profile menu, listings, edit listing (photo, price, availability, delete)

See **`lib/features/README.md`** for how features are organized.

- **`lib/core/widgets/`** – Shared widgets used across screens. See **`lib/core/widgets/README.md`** for the list and how to add new ones.
- **`database/`** – Supabase schema and wiring notes. See **`database/README.md`** when you’re ready to plug in live data.
