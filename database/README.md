# Database (Supabase)

Notes for when we hook the app up to real Supabase data. Right now we’re on dummy data; this is your cheat sheet for the switch.

## Schema file

**`schema.sql`** – Put your Supabase schema here (or paste it from the dashboard) so we can see table and column names. Helps when you’re writing repos or debugging.

## Which table = which model

So you don’t have to guess:

| Supabase table              | Our Dart model | Where we use it |
|----------------------------|----------------|-----------------|
| `public.profiles`          | `lib/core/models/profile.dart` | Profile menu, header |
| `public.listings`          | `lib/core/models/listing.dart` | Manage Listings, Edit Listing |
| `public.listing_photos`    | `lib/core/models/listing_photo.dart` | Hero photo, gallery |
| `public.availability_weekly`   | `lib/core/models/availability_weekly.dart` | Weekly slots UI |
| `public.availability_specific`| `lib/core/models/availability_specific.dart` | Date-range slots UI |
| `public.reservations`      | (later) `reservation_status` in `lib/core/models/reservation_status.dart` | When we do bookings |
| `public.host_earnings`     | (later) | When we do earnings |

Models use `fromJson` / `toJson` with Supabase’s snake_case (`host_id`, `price_hour`, etc.).

## Switching to live data

Screens already get everything through Riverpod and the repos. Data path: `lib/features/profile/data/` (dummy right now) → `lib/features/profile/providers/profile_providers.dart`. To go live:

1. **Repos** – Implement `ListingsRepository` and `ProfileRepository` with Supabase (e.g. `SupabaseListingsRepository`). Use `Supabase.instance.client.from('listings')` (and the other tables), and parse rows with `Listing.fromJson(row)`, `Profile.fromJson(row)`, etc.

2. **Providers** – In `profile_providers.dart`, swap out `DummyListingsRepository()` and `DummyProfileRepository()` for your new Supabase repos. Screens don’t need to change.

3. **Screens** – Already wired. Profile menu uses `currentProfileProvider`, Manage Listings uses `myListingsForCurrentUserProvider`, Edit Listing uses `listingByIdProvider` + `listingPhotosProvider` + the two availability providers, Modify Price uses `listingByIdProvider` for the initial price.

4. **Auth / RLS** – Schema already has RLS. Keep using the same anon key and auth so `auth.uid()` is set. If you’re using the Supabase client from `auth_providers.dart`, you’re good.

That’s it. Once the repos are swapped, the app talks to Supabase instead of the dummy data.
