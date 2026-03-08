# Parkd Context - Paul (Group 14)

## Focus
This file tracks only Paul's implementation scope for CIS*4030 so day-to-day work stays isolated from team-wide planning noise.

## Product Snapshot
Parkd is a Flutter peer-to-peer parking marketplace for the University of Guelph area:
- Drivers book nearby spots.
- Hosts list/manage driveway spots.

## Paul's Owned Scope
### Priority ownership
- Profile + Settings workflow
- Host manages listing workflow
- Brand kit/UI template consistency work
- Repo workflow hygiene (branch/PR/test discipline)

### Settings/Profile deliverables
- View and edit profile details
- Payment method management UI
- Host earnings view UI (connected to backend data)
- Session-safe account settings flow

### Host-manage-listing deliverables
- Listing management dashboard screen(s)
- Edit listing details (price, availability, photos)
- Booking approval/rejection controls (or auto-accept toggle UI)
- Listing status controls (active/inactive)

## Interfaces Paul Depends On (from team/backend)
- Auth/session availability from Supabase
- Listing/booking tables and API contracts
- Stripe/payment status fields
- Shared navigation shell and theme tokens

If any of these are unstable, implement against typed mock repositories first, then swap providers.

## Technical Guardrails (Paul)
- Flutter + Riverpod + go_router
- Keep features modular under `lib/features/...`
- No workflow should depend directly on raw Supabase calls in UI widgets
- Use repository/provider layer to keep testing and integration clean
- Match completed Figma exactly unless blocked by technical constraints

## Suggested Folder Ownership
- `lib/features/profile/`
- `lib/features/settings/`
- `lib/features/host_manage_listing/`
- `lib/shared/theme/` (only for agreed styling updates)

## Paul's Milestone Execution
### By March 10, 2026
- Profile + Settings page structure and navigation complete
- Stub state wired with Riverpod providers

### By March 17, 2026
- Host manages listing screens complete against mock/real data contracts
- Figma parity pass for owned screens

### By March 21-25, 2026
- Full CRUD hookup for owned workflows
- Error states handled (failed save, invalid input, connectivity)
- Tests for providers/repositories and key widget flows

### By March 28-30, 2026
- Integration bug fixes for owned areas
- UI consistency/polish for owned screens
- Demo readiness checks on profile/settings/listing management flows

## Definition of Done (Paul)
A workflow is done when:
- UI matches Figma
- Data read/write works end-to-end
- Loading/empty/error states exist
- Basic tests are passing
- No known blocker for demo path

## Immediate Next Steps
1. Create scaffolds for three owned feature modules.
2. Define provider + repository interfaces before screen logic.
3. Implement Profile/Settings first (earliest milestone), then Host Manage Listing.
4. Add lightweight test files as each provider/repo is created.
