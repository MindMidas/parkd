# Shared widgets (`lib/core/widgets/`)

Reusable layout and styling only — import the barrel:

```dart
import 'package:parkd/core/widgets/widgets.dart';
```

Exports are alphabetical in **`widgets.dart`**. Internal helper **`app_search_field_decoration.dart`** is not exported (shared by search fields only).

---

## Also from the barrel (not in this folder)

| Export | One-line |
|--------|----------|
| `display_formatting` | Date/time split, duration, USD, title-case helpers from `lib/core/utils/`. |
| `scrollViewBottomInset` | Extra bottom padding above the home indicator. |
| `AppMessenger` | Success/error snackbars. |
| `FormValidators` | Shared `FormFieldValidator`s. |

---

## Widget files (A–Z)

| File | What it does |
|------|----------------|
| **app_annotate_photo.dart** | Draggable car marker on a photo; reports 0–1 position for save. |
| **app_availability_slots.dart** | Summarizes weekly and/or date-range slots with optional prices. |
| **app_bottom_nav.dart** | Main shell bottom dock (custom top-aligned row, M3-style pill + labels; not centered `NavigationBar`). |
| **app_bottom_sheet_grabber.dart** | Centered drag handle for bottom sheets (`AppBottomSheetGrabber`). |
| **app_buttons.dart** | Primary and secondary Material buttons (`AppButtonStyleTokens`, loading, icons). |
| **app_chat_message_bubble.dart** | Single chat row styled for sender vs receiver. |
| **app_checkbox_rich_text_row.dart** | Checkbox with a rich-text label (tappable spans in terms). |
| **app_checkout_payment_method.dart** | Checkout row showing selected saved card + change affordance. |
| **app_compact_primary_text_button.dart** | Dense text button using caption link styling. |
| **app_confirm_dialog.dart** | Card-style alert with cancel and confirm actions. |
| **app_country_picker_dialog.dart** | Searchable country list for the phone field (scrollable dialog). |
| **app_date_picker.dart** | `showAppDatePicker` — platform-appropriate date picker sheet. |
| **app_date_range_calendar.dart** | Start/end range picker with optional weekday filter. |
| **app_day_checkboxes.dart** | Mon–Sun chips for weekly availability UI. |
| **app_detail_layout.dart** | Detail scroll body, host inline card, hero image + fullscreen viewer. |
| **app_display_fields.dart** | Outline cards, booking time/duration blocks, money, address, checkout breakdown. |
| **app_divider.dart** | Full-width, wide, and inset horizontal dividers. |
| **app_form_helper_text.dart** | Small muted helper above or below fields. |
| **app_form_scroll_body.dart** | Padded scroll surface for forms and menu-style pages. |
| **app_info_text.dart** | Muted caption paragraph for footnotes and disclaimers. |
| **app_intl_phone_field.dart** | Phone field with country picker and NANP formatting helpers. |
| **app_list_item.dart** | Tappable list row with optional leading icon and chevron. |
| **app_list_screen_search_panel.dart** | Elevated search card wrapping `AppSearchField` for list hubs. |
| **app_listing_availability_heatmap.dart** | Week × hour heatmap for listing availability. |
| **app_listing_edit_cards.dart** | Titled cards for edit listing (availability, price, slots, delete). |
| **app_listing_photo_frame.dart** | Fixed aspect photo frame with optional overlay and tap. |
| **app_listing_photo_spot_overlay.dart** | Read-only car pin on a photo from normalized coordinates. |
| **app_login_hero_image.dart** | Login hero asset with theme shadow (`AppColors.shadowFloating`). |
| **app_map_address_search_panel.dart** | Floating address search card with async results list. |
| **app_map_search_card.dart** | White elevated Material shell for map overlay content. |
| **app_map_search_field.dart** | Map-styled search field with optional in-field filter icon. |
| **app_mapbox_preview.dart** | Embedded Mapbox map with optional pin and gesture lock. |
| **app_menu_row.dart** | Settings-style rows, pills; `AppMenuProfileAvatar` (menu style + `hostListingPlaceholder` factory for listing cards). |
| **app_month_calendar.dart** | Month grid with navigation and multi-day selection. |
| **app_muted_link_row.dart** | Centered muted caption with a tappable link (e.g. auth switcher). |
| **app_outcome_view.dart** | Success/failure mark, headline, and primary action(s). |
| **app_payment_card_form_sections.dart** | Titled cards for card fields and billing address on add-card flows. |
| **app_payment_method_pill.dart** | Tappable payment brand pill with selection state. |
| **app_price_stepper.dart** | Label with − / value / + for money or counts. |
| **app_readonly_copy_field.dart** | Read-only value with a copy action. |
| **app_requirement_checklist.dart** | Password rule row with met/unmet/neutral state icons. |
| **app_saved_payment_card_row.dart** | Compact selectable row for a saved card. |
| **app_screen_section.dart** | Section with optional title, helper, and top divider. |
| **app_selectable_icon_chevron_card.dart** | Bordered tappable card: blue leading icon, title/subtitle, chevron. |
| **app_search_field.dart** | List-hub search field (parent filters on `onChanged`). |
| **app_section_divider_title.dart** | Horizontal rule with centered title. |
| **app_section_label.dart** | Small uppercase section label. |
| **app_section_title.dart** | In-content 16/600 section heading. |
| **app_settings_nav_tile.dart** | Settings row with icon, title, subtitle, chevron. |
| **app_slot_card_remove.dart** | Slot row with remove control wrapping weekly or date-range content. |
| **app_surface_footer_pad.dart** | Surface-colored footer strip with horizontal padding (sticky CTAs). |
| **app_step_top_bar.dart** | App bar with step indicator for multi-step flows. |
| **app_terms_gate_widgets.dart** | Numbered terms blocks and agreement checkbox for full-screen gates. |
| **app_text_field.dart** | Themed text field with password toggle and validation chrome. |
| **app_time_picker_row.dart** | Tappable row that opens a time picker. |
| **app_time_picker_sheet.dart** | Cupertino wheel time sheets (minutes since midnight). |
| **app_time_stepper_row.dart** | Time row with repeating −/+ steppers. |
| **app_top_bar.dart** | Tall app bar (`navTitle`); optional back; `centerTitle` for tab hubs; no implied leading when `showBack` is false. |

---

## Adding a widget

1. Add **`app_<name>.dart`** (snake_case, **`app_`** prefix).
2. Public types prefixed **`App…`** (or a small shared enum in the same file).
3. Export in **`widgets.dart`** in alphabetical order.
4. Add one table row here.
5. Use **`AppColors`** when adding tints (see `app_colors.dart`).
