# Core Widgets Guide

This folder stores shared UI building blocks used across features.

## Location
- `lib/core/widgets/`

## Current Widget Catalog
| File | Main Class(es) | Purpose |
| --- | --- | --- |
| `app_bottom_nav.dart` | `AppBottomNav` | Bottom navigation for Map/Profile tabs. |
| `app_buttons.dart` | `AppPrimaryButton`, `AppSecondaryButton` | Shared action button styles. |
| `app_card.dart` | `AppCard` | Consistent card container with padding. |
| `app_text_field.dart` | `AppTextField` | Shared text input wrapper for forms. |
| `app_top_bar.dart` | `AppTopBar` | App bar with optional back button. |
| `section_title.dart` | `SectionTitle` | Standard section heading text style. |

## Import Style (Recommended)
Import shared widgets through the barrel file:

```dart
import 'package:parkd/core/widgets/widgets.dart';
```

This keeps imports consistent and makes widgets easier to discover.

## How To Add A New Widget
1. Add a new Dart file in `lib/core/widgets/` using `snake_case.dart`.
2. Use a clear, reusable class name (for example `AppStatusChip`).
3. Keep business logic out of shared widgets; accept data and callbacks via constructor parameters.
4. Add a short file-level comment describing the widget's role.
5. Export the new file from `lib/core/widgets/widgets.dart`.
6. If behavior is non-trivial, add/extend tests in `test/`.

## Widget Template
```dart
import 'package:flutter/material.dart';

// Reusable [what this widget standardizes].
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

## Team Checklist Before Merge
- Widget is generic enough for reuse (not feature-specific).
- Naming follows app conventions (`App...` for app-level shared components).
- Export added in `widgets.dart`.
- Any required usage updates are included in the same merge request.
