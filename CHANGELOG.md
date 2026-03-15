# Changelog

## Profile + Listings (this branch)

- Profile menu, listings menu, manage listings list, and full edit-listing flow (photo, price, availability, delete).
- All screens use dummy data from `lib/features/profile/data/`; ready to swap to Supabase later (see `database/README.md`).
- Shared widgets in `lib/core/widgets/` (buttons, top bar, availability slots, calendar, dialogs, etc.).
- Models and repo interfaces in `lib/core/models/` and `lib/features/profile/data/` so wiring real data is just a repo swap.
