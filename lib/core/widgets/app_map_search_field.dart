import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_typography.dart';
import '../utils/app_feedback.dart';
import 'app_map_search_card.dart';
import 'app_search_field_decoration.dart';

class AppMapSearchField extends StatefulWidget {
  const AppMapSearchField({
    super.key,
    this.hintText = 'Search',
    this.onChanged,
    this.controller,
    this.showFilterButton = false,
    this.onFilterTap,
    this.isLoading = false,
  });

  final String hintText;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final bool showFilterButton;
  final VoidCallback? onFilterTap;

  // Compact trailing spinner while geocoding / address search runs.
  final bool isLoading;

  @override
  State<AppMapSearchField> createState() => _AppMapSearchFieldState();
}

class _AppMapSearchFieldState extends State<AppMapSearchField> {
  late TextEditingController _controller;

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

  Widget? get _loadingSuffix {
    if (!widget.isLoading) return null;
    // Fill suffixIconConstraints and keep the suffix centered.
    return const SizedBox(
      width: 40,
      height: 44,
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primaryBlue,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showFilter = widget.showFilterButton && widget.onFilterTap != null;

    final field = TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      onTap: () => AppFeedback.selection(context),
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      cursorColor: AppColors.primaryBlue,
      decoration: AppSearchFieldDecoration.mapEmbedded(
        hintText: widget.hintText,
        suffixIcon: _loadingSuffix,
      ),
      style: AppTypography.bodySecondary.copyWith(color: AppColors.textPrimary),
      textInputAction: TextInputAction.search,
    );

    if (!showFilter) {
      return AppMapSearchCard(child: field);
    }

    return AppMapSearchCard(
      child: Row(
        children: [
          Expanded(child: field),
          SizedBox(
            height: 36,
            child: VerticalDivider(
              width: 1,
              thickness: 1,
              color: AppColors.secondaryGrey.withValues(alpha: 0.9),
              indent: 8,
              endIndent: 8,
            ),
          ),
          Tooltip(
            message: 'Filters',
            child: Material(
              color: AppColors.transparent,
              child: InkWell(
                onTap: () {
                  AppFeedback.selection(context);
                  widget.onFilterTap!();
                },
                borderRadius: BorderRadius.circular(AppRadius.sm),
                splashColor: AppColors.secondaryBlue.withValues(alpha: 0.45),
                child: const SizedBox(
                  width: 44,
                  height: 48,
                  child: Center(
                    child: Icon(
                      Icons.tune_rounded,
                      color: AppColors.iconBlue,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
