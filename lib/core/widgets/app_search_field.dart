import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class AppSearchField extends StatefulWidget {
  const AppSearchField({
    super.key,
    this.hintText = 'Search',
    this.onChanged,
    this.onSelected,
    this.suggestionsBuilder,
    this.showFilterButton = true,
    this.onFilterTap,
  });

  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSelected;

  /// Return the list of suggestion strings based on the current query.
  /// If null, no dropdown is shown.
  final Future<List<String>> Function(String query)? suggestionsBuilder;

  final bool showFilterButton;
  final VoidCallback? onFilterTap;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  final SearchController _searchController = SearchController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SearchAnchor(
            searchController: _searchController,
            viewBackgroundColor: Colors.white,
            viewElevation: 4,
            viewShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            // The pill-shaped bar sitting over the map
            builder: (context, controller) {
              return TextField(
                controller: controller,
                onChanged: (value) {
                  widget.onChanged?.call(value);
                  // Open the suggestions overlay as the user types
                  if (value.isNotEmpty) {
                    controller.openView();
                  }
                },
                onTap: controller.openView,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.iconGrey,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(32),
                    borderSide: BorderSide(
                      color: AppColors.iconGrey,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(32),
                    borderSide: BorderSide(
                      color: AppColors.iconGrey,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(32),
                    borderSide: const BorderSide(color: AppColors.primaryBlue),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                ),
              );
            },

            // Suggestion rows in the dropdown
            suggestionsBuilder: (context, controller) async {
              final query = controller.text;
              if (widget.suggestionsBuilder == null || query.isEmpty) {
                return const [];
              }

              final results = await widget.suggestionsBuilder!(query);

              return results.map((address) {
                return ListTile(
                  leading: const Icon(
                    Icons.location_on_outlined,
                    color: AppColors.iconGrey,
                    size: 20,
                  ),
                  title: Text(
                    address,
                    style: AppTypography.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    controller.closeView(address);
                    widget.onSelected?.call(address);
                  },
                );
              }).toList();
            },
          ),
        ),

        // ── Filter button (optional) ──────────────────────────────────────
        if (widget.showFilterButton) ...[
          const SizedBox(width: AppSpacing.sm),
          GestureDetector(
            onTap: widget.onFilterTap,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.iconGrey.withValues(alpha: 0.2),
                ),
              ),
              child: const Icon(
                Icons.tune_rounded,
                color: AppColors.iconGrey,
                size: 20,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
