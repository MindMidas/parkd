import 'package:flutter/material.dart';

import 'app_search_field.dart';
import '../theme/app_colors.dart';

// Shadow card around AppSearchField; parent owns the controller
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
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowFloating,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 4),
        child: AppSearchField(
          controller: controller,
          hintText: hintText,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
