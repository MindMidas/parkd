# Shared widgets (`lib/core/widgets/`)

Reusable layout and styling only — import the barrel:

```dart
import 'package:parkd/core/widgets/widgets.dart';
```

Exports are alphabetical in **`widgets.dart`**. Internal helper **`app_search_field_decoration.dart`** is not exported (shared by search fields only).

### Design tokens

| Token | Where |
|-------|--------|
| `AppRadius` | `lib/core/theme/app_radius.dart` — sm/md/lg/xl/sheet/card/pill |
| `AppMotion` | `lib/core/theme/app_motion.dart` — durations, pressScale, spring |
| `AppColors` / `AppTypography` / `AppSpacing` | existing theme files; typeface is bundled **DM Sans** |

### Feedback contract

- Transient errors/success → **`AppMessenger`** (no new raw `SnackBar`s)
- Loading / empty / error bodies → **`AppPageStatus`** / **`AppAsyncBody`**
- Modal sheets → **`AppModalSheet`**
- Sticky CTAs → **`AppStickyFooter`**
- Nested pushes → **`AppPageRoute`**
- Settings / hub rows → **`AppNavTile`** only (`bodyStrong`, soft blue icon wells, optional subtitle)
- Hub menus → **`AppHubMenuIntro`** (white surface, slim blue accent + ~2-line lead; optional Account header) + **`AppHubMenuSection`**
- Prefer medium weights over bold for chrome; `navTitle` / `bodyStrong` / buttons are w500–w600, not w700
- Entity lists → **`AppMenuRow`** (solid parking thumb, calm caption stack; list search uses same card chrome as map)
- Tappable cards / chips → **`InkWell`** / **`Material`** (solid surfaces; ink only, no press scale)
- CTA press → darken overlay + **0.97** scale + light haptic (`AppFeedback.light`); rows use stronger `AppInk` splash/highlight (keep the flicker); tab change → `AppFeedback.selection`
- Buttons are always filled: primary blue or soft `secondaryBlue` (never white/outline CTAs); switches stay adaptive
- **Button library (import `widgets.dart` only — do not use raw `FilledButton` / `OutlinedButton` / `TextButton` in feature screens):**
  - **`AppPrimaryButton`** — primary / destructive filled CTA
  - **`AppSecondaryButton`** — soft filled secondary / cancel
  - **`AppCompactPrimaryTextButton`** — inline text links only (auth helpers, legal spans)
  - **`AppConfirmDialog`** — cancel + confirm (wired to the button pair above)
  - Icon chrome: **`AppTopBarIconButton`**, **`AppMapFloatingIconButton`**, **`AppOverflowMenuButton`**
- Bottom nav → selected icon + label share accent blue; Map uses a filled selected glyph
- Map search → one `AppMapSearchCard` bar with optional in-bar filter (divider + tune)
- No frosted glass / page-fade chrome
- Hub / nested **`AppTopBar`** uses a bottom hairline for edge separation

### Chrome

Feature screens use **solid** surfaces (`AppColors.surface`, borders, `AppRadius`) — not frosted glass chrome. Decorative `ImageFilter` on hub washes only. **`AppStickyFooter`**, **`AppModalSheet`**, and **`AppMapSearchCard`** are solid Material chrome. Map search uses the same card for the field, filter chip, and results (no ad-hoc shadow-only field).

### Goldens

Widget goldens live under `test/goldens/`. After intentional visual changes:

```bash
flutter test --update-goldens
```

---

## Also from the barrel (not in this folder)

| Export | One-line |
|--------|----------|
| `display_formatting` | Date/time split, duration, USD, title-case helpers from `lib/core/utils/`. |
| `scrollViewBottomInset` | Extra bottom padding above the home indicator. |
| `AppMessenger` | Success/error snackbars. |
| `FormValidators` | Shared `FormFieldValidator`s. |
| `userFacingErrorMessage` | Generic load/list failure copy (`lib/core/utils/user_facing_error.dart`). |

---

## Widget files (A–Z)

| File | What it does |
|------|----------------|
| **app_annotate_photo.dart** | Draggable car marker on a photo; reports 0–1 position for save. |
| **app_async_body.dart** | `AsyncValue` → loading/empty/error/data via `AppPageStatus`. |
| **app_availability_slots.dart** | Summarizes weekly and/or date-range slots with optional prices. |
| **app_bottom_nav.dart** | Main shell bottom dock (custom top-aligned row, M3-style pill + labels; not centered `NavigationBar`). |
| **app_bottom_sheet_grabber.dart** | Centered drag handle for bottom sheets (`AppBottomSheetGrabber`). |
| **app_buttons.dart** | `AppPrimaryButton` / `AppSecondaryButton` — filled CTAs only (`AppButtonStyleTokens`, loading, compact, icons). |
| **app_chat_message_bubble.dart** | Single chat row styled for sender vs receiver. |
| **app_checkbox_rich_text_row.dart** | Checkbox with a rich-text label (tappable spans in terms). |
| **app_checkout_payment_method.dart** | Checkout row showing selected saved card + change affordance. |
| **app_compact_primary_text_button.dart** | Dense text button using caption link styling. |
| **app_confirm_dialog.dart** | Card-style alert with cancel and confirm actions. |
| **app_dialog_surface.dart** | Shared dialog card chrome (`AppRadius.xl` + soft shadow). |
| **app_country_picker_dialog.dart** | Searchable country list for the phone field (scrollable dialog). |
| **app_date_picker.dart** | `showAppDatePicker` — platform-appropriate date picker sheet. |
| **app_date_range_calendar.dart** | Start/end range picker with optional weekday filter. |
| **app_day_checkboxes.dart** | Mon–Sun day pills for weekly availability UI. |
| **app_detail_layout.dart** | Detail scroll body, host inline card, hero image + fullscreen viewer. |
| **app_display_fields.dart** | Outline cards, booking time/duration blocks, money, address, checkout breakdown. |
| **app_divider.dart** | Full-width, wide, and inset horizontal dividers. |
| **app_form_helper_text.dart** | Small muted helper above or below fields. |
| **app_form_scroll_body.dart** | Padded scroll surface for forms and menu-style pages. |
| **app_info_text.dart** | Muted caption paragraph for footnotes and disclaimers. |
| **app_intl_phone_field.dart** | Phone field with country picker and NANP formatting helpers. |
| **app_list_item.dart** | Tappable list row with optional leading icon and chevron. |
| **app_list_screen_search_panel.dart** | Solid `AppMapSearchCard` + embedded search for list screens. |
| **app_listing_availability_heatmap.dart** | Week × hour heatmap for listing availability. |
| **app_listing_edit_cards.dart** | Titled cards for edit listing (availability, price, slots, delete). |
| **app_listing_photo_frame.dart** | Fixed aspect photo frame with optional overlay and tap. |
| **app_listing_photo_spot_overlay.dart** | Read-only car pin on a photo from normalized coordinates. |
| **app_login_hero_image.dart** | Login hero asset with theme shadow (`AppColors.shadowFloating`). |
| **app_map_address_search_panel.dart** | Floating address search card with async results list. |
| **app_map_overlay_chrome.dart** | Soft-shadow map recenter button + overlay status cards. |
| **app_map_search_card.dart** | Solid elevated Material shell (hairline + elevation) for map overlay content. |
| **app_map_search_field.dart** | Map search in `AppMapSearchCard`; optional separate filter chip. |
| **app_mapbox_preview.dart** | Embedded Mapbox map with pin or approximate halo; `AppApproximateLocationMap`. |
| **app_menu_row.dart** | Entity list row (listings/bookings); parking thumb + caption stack; `AppMenuProfileAvatar`. |
| **app_modal_sheet.dart** | Grabber, radius, max height, optional sticky footer. |
| **app_month_calendar.dart** | Month grid with navigation and multi-day selection. |
| **app_muted_link_row.dart** | Centered muted caption with a tappable link (e.g. auth switcher). |
| **app_hub_menu_intro.dart** | Quiet hub lead (white + blue accent bar; optional Account header). |
| **app_hub_menu_section.dart** | Section title above a group of hub `AppNavTile`s. |
| **app_nav_tile.dart** | Hub/settings row with icon well, bodyStrong label, chevron. |
| **app_outcome_view.dart** | Success/failure mark, headline, and primary action(s). |
| **app_overflow_menu.dart** | App-bar overflow menu with Parkd row chrome (`AppOverflowMenuButton`). |
| **app_page_route.dart** | Shared `MaterialPageRoute` for nested navigators. |
| **app_page_status.dart** | Loading / empty / error (icon, title, message, optional retry). |
| **app_payment_card_form_sections.dart** | Titled cards for card fields and billing address on add-card flows. |
| **app_payment_method_pill.dart** | Tappable payment brand pill with selection state. |
| **app_picker_sheet.dart** | Shared Cupertino picker chrome (sheet radius + grabber + Cancel/Done). |
| **app_price_stepper.dart** | Label with − / value / + for money or counts. |
| **app_readonly_copy_field.dart** | Read-only value with a copy action. |
| **app_requirement_checklist.dart** | Password rule row with met/unmet/neutral state icons. |
| **app_saved_payment_card_row.dart** | Compact selectable row for a saved card. |
| **app_screen_section.dart** | Section with optional title, helper, and top divider. |
| **app_segment_control.dart** | Soft track + selected pill segments (heatmap range, card brand). |
| **app_selectable_icon_chevron_card.dart** | Bordered tappable card: blue leading icon, title/subtitle, chevron. |
| **app_search_field.dart** | List-hub search field (parent filters on `onChanged`). |
| **app_section_divider_title.dart** | Horizontal rule with centered title. |
| **app_section_label.dart** | Small uppercase section label. |
| **app_section_title.dart** | In-content 16/600 section heading. |
| **app_settings_nav_tile.dart** | Settings row with icon, title, subtitle, chevron. |
| **app_slot_card_remove.dart** | Slot row with remove control wrapping weekly or date-range content. |
| **app_sticky_footer.dart** | Surface footer with top border + safe area for sticky CTAs. |
| **app_surface_footer_pad.dart** | Surface-colored footer strip with horizontal padding (sticky CTAs). |
| **app_step_top_bar.dart** | App bar with step indicator for multi-step flows. |
| **app_terms_gate_widgets.dart** | Numbered terms blocks and agreement checkbox for full-screen gates. |
| **app_text_field.dart** | Themed text field with password toggle and validation chrome. |
| **app_time_picker_row.dart** | Tappable row that opens a time picker. |
| **app_time_picker_sheet.dart** | Cupertino wheel time sheets (minutes since midnight). |
| **app_time_stepper_row.dart** | Time row with repeating −/+ steppers. |
| **app_top_bar.dart** | Tall app bar (`navTitle`); optional back; bottom hairline; `centerTitle` for tab hubs; no implied leading when `showBack` is false. |

---

## Adding a widget

1. Add **`app_<name>.dart`** (snake_case, **`app_`** prefix).
2. Public types prefixed **`App…`** (or a small shared enum in the same file).
3. Export in **`widgets.dart`** in alphabetical order.
4. Add one table row here.
5. Use **`AppColors`** when adding tints (see `app_colors.dart`).
6. Prefer **`AppRadius`** / **`AppMotion`** over magic numbers.
