# Shared widgets

This folder has all the reusable UI bits we use across the app. If you need a button, a list row, a calendar, etc., check here first—chances are we’ve already got something you can use. Keep everything generic (no feature-specific stuff) so anyone can drop it into any screen.

Path: `lib/core/widgets/`

## Quick reference – what’s in here

- **`app_annotate_photo.dart`** – Image with a draggable parking-spot marker. Use `AppAnnotatePhoto` + `AppAnnotatePhotoInstruction` (e.g. Edit Photo, Create Listing).
- **`app_availability_slots.dart`** – Shows scheduled slots: **date-range** (From/To) or **weekly** (day + time). Use `AppAvailabilitySlots.dateRanges()`, `.weekly()`, or `.combined()` with `DateRangeSlot` / `WeeklySlot`.
- **`app_bottom_nav.dart`** – Bottom nav (map / profile).
- **`app_buttons.dart`** – Primary and secondary buttons.
- **`app_card.dart`** – Basic card with padding.
- **`app_confirm_dialog.dart`** – Yes/no style dialog (title, message, Cancel + Confirm). Good for stuff like Delete Listing.
- **`app_date_range_calendar.dart`** – Calendar with date-range selection and optional day-level availability. Use `AppDateRangeCalendar` with `onRangeChanged` callback and optional `availableWeekdays` set to grey-out unavailable days.
- **`app_day_checkboxes.dart`** – Row of day chips (Mon–Sun). Use `AppDayCheckboxes` with `selectedIndices` and `onChanged`; `kWeekdayLabels` for the labels.
- **`app_divider.dart`** – Thin line between list items.
- **`app_editable_row.dart`** – Label + value + optional Edit button. Use on edit/detail screens.
- **`app_failure_view.dart`** – Failure/error screen: red circle with X, title, message, Close button. Same layout as success view; use when something goes wrong.
- **`app_info_text.dart`** – Grey disclaimer / info text (e.g. “Changes only apply to future reservations…”).
- **`app_label_value_row.dart`** – Row with a fixed-width bold label and a value. Use `AppLabelValueRow` for "From" / "To" style rows. Optional `labelWidth`.
- **`app_list_item.dart`** – Simple row with label + chevron. Optional top/bottom borders.
- **`app_month_calendar.dart`** – One month, prev/next, day grid. Used in the set-availability dates flow.
- **`app_payment_method_pill.dart`** – Outlined pill showing card brand + masked number + chevron. Use `AppPaymentMethodPill(brand: 'Visa', lastFour: '4242')`. Optional `onTap`.
- **`app_photo_action_button.dart`** – Full-width button with an icon (“Take photo”, “Upload photo”).
- **`app_price_stepper.dart`** – Label + minus / value / plus. Use for hourly or daily price.
- **`app_search_field.dart`** – Rounded search bar with magnifying glass.
- **`app_section_divider_title.dart`** – Horizontal line with centered text (e.g. “Scheduled time slots”).
- **`app_section_label.dart`** – Small grey caption for section headings (e.g. "Parking spot", "Duration"). Use `AppSectionLabel('Label')`.
- **`app_slot_card_remove.dart`** – Card for a slot with an X to remove it. Use `AppSlotCardRemove` with `child` and `onRemove`. Helpers: `AppSlotCardRemoveDateRange(from, to)` and `AppSlotCardRemoveWeekly(day, timeRange)`.
- **`app_success_view.dart`** – Success screen: icon, title, message, Close button. Just swap the text.
- **`app_terms_checkbox.dart`** – Scrollable terms/policy box with a checkbox + label. Use `AppTermsCheckbox` with `heading`, `termsText`, `checkboxLabel`, `value`, and `onChanged`.
- **`app_text_field.dart`** – Standard text field.
- **`app_time_picker_row.dart`** – Tappable row with bold label, date/time value, and dropdown arrow. Use `AppTimePickerRow` for "Start time" / "End time" rows.
- **`app_time_stepper_row.dart`** – Label + time + minus/plus buttons (blue, white icons). Use for Start time / End time.
- **`app_top_bar.dart`** – Top bar with optional back button.
- **`section_title.dart`** – Section heading.

## How to use them

Import the barrel file so you don’t have to remember every path:

```dart
import 'package:parkd/core/widgets/widgets.dart';
```

Then grab whatever widget you need from the list above.

## Adding a new widget

1. New file in this folder, `snake_case.dart`.
2. Name the class something obvious (e.g. `AppStatusChip`).
3. Keep it generic—no feature-specific logic.
4. Add it to the exports in `widgets.dart`.
5. Add tests in `test/` if it’s not trivial.

Copy-paste template:

```dart
import 'package:flutter/material.dart';

class AppExampleWidget extends StatelessWidget {
  const AppExampleWidget({
    super.key,
    required this.label,
    this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      child: Text(label),
    );
  }
}
```

Before you open a PR: make sure it’s reusable, it’s in `widgets.dart`, and any screen that uses it is updated.
