import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'app_list_screen_search_panel.dart';

// Hub list layout, padded search card on top, expanded body below
class AppHubSearchListColumn extends StatelessWidget {
  const AppHubSearchListColumn({
    super.key,
    required this.searchController,
    required this.searchHint,
    required this.onSearchChanged,
    required this.expandedChild,
  });

  final TextEditingController searchController;
  final String searchHint;
  final ValueChanged<String> onSearchChanged;
  final Widget expandedChild;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: AppListScreenSearchPanel(
            controller: searchController,
            hintText: searchHint,
            onChanged: onSearchChanged,
          ),
        ),
        Expanded(child: expandedChild),
      ],
    );
  }
}
