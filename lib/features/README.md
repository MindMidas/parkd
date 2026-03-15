# Features

Feature modules for the app. Each folder is a slice of the product (auth, home, profile).

## What’s in here

- **`auth/`** – Signup and login (when we wire Supabase auth).
- **`home/`** – Main map and home UI.
- **`profile/`** – Profile menu, listings menu, manage listings, and edit-listing flows (photo, price, availability, delete). Screens are wired to providers; data comes from `profile/data/` (dummy for now) and is ready to swap to Supabase.

## Adding new flows

When you add a new flow (e.g. under profile or home), keep the same pattern: put presentation (screens) under `presentation/`, data (repos, dummy or Supabase) under `data/`, and providers in `providers/`. That way everything stays in one place and easy to find.
