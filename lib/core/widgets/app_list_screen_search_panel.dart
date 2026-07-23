import 'package:flutter/material.dart';

import 'app_map_search_card.dart';
import 'app_search_field.dart';

/// Solid search chrome for list screens (Manage Listings, bookings, etc.).
class AppListScreenSearchPanel extends StatelessWidget {
  const AppListScreenSearchPanel({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppMapSearchCard(
      child: AppSearchField(
        controller: controller,
        hintText: hintText,
        onChanged: onChanged,
        embeddedInChrome: true,
      ),
    );
  }
}
