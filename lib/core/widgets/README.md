# Shared widgets

Import from `package:parkd/core/widgets/widgets.dart` when you can. That barrel
also re-exports a few utils, messaging helpers, and validators we use a lot.

If something is missing from the list below, check `lib/core/widgets/` — names
are usually `app_*.dart` with a public `App…` type.

## What’s in the barrel

| File | What it’s for |
|---|---|
| `app_annotate_photo.dart` | Crop / mark listing photos |
| `app_async_body.dart` | AsyncValue loading / empty / error / data |
| `app_availability_slots.dart` | Weekly + date-range availability blocks |
| `app_bottom_nav.dart` | Main tab bar |
| `app_bottom_sheet_grabber.dart` | Sheet drag handle |
| `app_buttons.dart` | Primary / secondary buttons |
| `app_chat_message_bubble.dart` | Chat bubbles |
| `app_checkbox_rich_text_row.dart` | Checkbox + rich label |
| `app_checkout_payment_method.dart` | Checkout card picker |
| `app_compact_primary_text_button.dart` | Small text button |
| `app_confirm_dialog.dart` | Confirm dialog |
| `app_country_picker_dialog.dart` | Country picker |
| `app_date_picker.dart` | Date picker sheet |
| `app_date_range_calendar.dart` | Start/end calendar |
| `app_day_checkboxes.dart` | Weekday checkboxes |
| `app_detail_layout.dart` | Detail layouts + image viewer |
| `app_dialog_surface.dart` | Dialog chrome |
| `app_display_fields.dart` | Cards, pricing, checkout breakdown |
| `app_divider.dart` | Thin dividers |
| `app_form_helper_text.dart` | Helper / error under fields |
| `app_form_scroll_body.dart` | Scrollable form padding |
| `app_hub_menu_intro.dart` | Hub intro text |
| `app_hub_menu_section.dart` | Hub section title |
| `app_info_text.dart` | Muted info text |
| `app_inline_error.dart` | Inline error (not a snackbar) |
| `app_intl_phone_field.dart` | Phone + country |
| `app_list_item.dart` | Simple list row |
| `app_list_screen_search_panel.dart` | List search panel |
| `app_listing_availability_heatmap.dart` | Availability heatmap |
| `app_listing_edit_cards.dart` | Edit availability / pricing cards |
| `app_listing_photo_frame.dart` | Listing photo frame |
| `app_listing_photo_spot_overlay.dart` | Spot marker on photo |
| `app_login_hero_image.dart` | Login hero |
| `app_map_address_search_panel.dart` | Address search (map / create listing) |
| `app_map_overlay_chrome.dart` | Map overlay controls |
| `app_map_search_card.dart` | Map search result card |
| `app_map_search_field.dart` | Map search field |
| `app_mapbox_preview.dart` | Mapbox preview |
| `app_menu_row.dart` | Settings-style row |
| `app_modal_sheet.dart` | Modal sheet chrome |
| `app_month_calendar.dart` | Month calendar |
| `app_muted_link_row.dart` | Muted link row |
| `app_nav_tile.dart` | Hub / settings tile |
| `app_notification_badge.dart` | Unread badge |
| `app_outcome_view.dart` | Success / error outcome |
| `app_overflow_menu.dart` | Overflow menu |
| `app_page_route.dart` | Shared page route |
| `app_page_status.dart` | Loading / empty / error body |
| `app_payment_card_form_sections.dart` | Card + billing fields |
| `app_payment_method_pill.dart` | Saved card pill |
| `app_picker_sheet.dart` | Picker sheet |
| `app_price_stepper.dart` | Price stepper |
| `app_reference_id_copy_field.dart` | Copyable reference id |
| `app_readonly_copy_field.dart` | Readonly + copy |
| `app_requirement_checklist.dart` | Requirement checklist |
| `app_saved_payment_card_row.dart` | Saved card row |
| `app_screen_section.dart` | Titled section |
| `app_segment_control.dart` | Segment control |
| `app_selectable_icon_chevron_card.dart` | Selectable icon card |
| `app_search_field.dart` | Search field |
| `app_section_divider_title.dart` | Divider + title |
| `app_section_label.dart` | Small section label |
| `app_section_title.dart` | Section heading |
| `app_settings_nav_tile.dart` | Settings nav row |
| `app_slot_card_remove.dart` | Slot row with remove |
| `app_static_map_preview.dart` | Static map preview |
| `app_step_top_bar.dart` | Multi-step top bar |
| `app_sticky_footer.dart` | Sticky footer CTA |
| `app_terms_gate_widgets.dart` | Terms checkbox + sections |
| `app_text_field.dart` | Text field |
| `app_time_picker_row.dart` | Time picker row |
| `app_time_picker_sheet.dart` | Time picker sheet |
| `app_time_stepper_row.dart` | Time steppers |
| `app_top_bar.dart` | App bar |

`app_search_field_decoration.dart` is shared decoration only — import that file
directly if you need it.

When adding a widget: `app_snake_case.dart`, public `AppSomething` type, and
stick to `AppColors` for colors.
