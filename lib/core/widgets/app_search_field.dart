import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class AppSearchField extends StatefulWidget {
  const AppSearchField({
    super.key,
    this.hintText = 'Search',
    this.onChanged,
    this.controller,
    this.showFilterButton = false,
    this.onFilterTap,
    this.suggestionsBuilder,
    this.onSelected,
  });

  final String hintText;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;

  /// Show an optional filter/tune icon button next to the search field.
  final bool showFilterButton;
  final VoidCallback? onFilterTap;

  /// Async callback that returns suggestion strings for the given query.
  final Future<List<String>> Function(String query)? suggestionsBuilder;

  /// Called when the user taps a suggestion.
  final ValueChanged<String>? onSelected;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  late TextEditingController _controller;
  List<String> _suggestions = [];
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  Future<void> _handleChanged(String query) async {
    widget.onChanged?.call(query);

    if (widget.suggestionsBuilder != null && query.trim().isNotEmpty) {
      final results = await widget.suggestionsBuilder!(query.trim());
      if (mounted) {
        setState(() {
          _suggestions = results;
          _showSuggestions = results.isNotEmpty;
        });
      }
    } else {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            // ── Search text field ──────────────────────────────────────────
            Expanded(
              child: TextField(
                controller: _controller,
                onChanged: _handleChanged,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  prefixIcon:
                      const Icon(Icons.search, color: AppColors.iconGrey),
                  filled: true,
                  fillColor:
                      AppColors.secondaryBlue.withValues(alpha: 0.15),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(32),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                ),
              ),
            ),

            // ── Filter button (optional) ──────────────────────────────────
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
        ),

        // ── Suggestions dropdown ────────────────────────────────────────
        if (_showSuggestions)
          Container(
            margin: const EdgeInsets.only(top: AppSpacing.xs),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final item = _suggestions[index];
                return ListTile(
                  leading: const Icon(
                    Icons.location_on_outlined,
                    color: AppColors.primaryBlue,
                    size: 20,
                  ),
                  title: Text(
                    item,
                    style: AppTypography.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  dense: true,
                  onTap: () {
                    setState(() {
                      _showSuggestions = false;
                      _controller.text = item;
                    });
                    widget.onSelected?.call(item);
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
