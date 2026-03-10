# Widgets README

This folder is for shared widgets we can reuse in different screens.

Path: `lib/core/widgets/`

## What is here right now
- `app_bottom_nav.dart` -> bottom nav (map/profile)
- `app_buttons.dart` -> primary + secondary buttons
- `app_card.dart` -> common card with padding
- `app_text_field.dart` -> common text field
- `app_top_bar.dart` -> top app bar with optional back button
- `section_title.dart` -> section heading text

## How to import widgets
Use the barrel file:

```dart
import 'package:parkd/core/widgets/widgets.dart';
```

## How to add a new widget
1. Make a new file in this folder using `snake_case.dart`.
2. Name the class clearly (example: `AppStatusChip`).
3. Keep it reusable (no feature-specific logic inside).
4. Add export in `widgets.dart`.
5. If needed, add tests in `test/`.

## Quick template
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

## Before you open MR
- widget should be reusable
- export is added in `widgets.dart`
- any screen using it is updated
