import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'app_search_field_decoration.dart';

// Map overlay search
class AppMapSearchField extends StatefulWidget {
  const AppMapSearchField({
    super.key,
    this.hintText = 'Search',
    this.onChanged,
    this.controller,
    this.showFilterButton = false,
    this.onFilterTap,
  });

  final String hintText;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final bool showFilterButton;
  final VoidCallback? onFilterTap;

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

  InputDecoration _decoration() {
    final filterInField =
        widget.showFilterButton && widget.onFilterTap != null;
    return AppSearchFieldDecoration.outline(
      hintText: widget.hintText,
      suffixIcon: filterInField
          ? IconButton(
              onPressed: widget.onFilterTap,
              icon: Icon(
                Icons.tune_rounded,
                color: AppColors.iconGrey.withValues(alpha: 0.9),
                size: 18,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 40,
              ),
              visualDensity: VisualDensity.compact,
            )
          : null,
      suffixIconConstraints: filterInField
          ? const BoxConstraints(minWidth: 40, minHeight: 40)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final filterInside =
        widget.showFilterButton && widget.onFilterTap != null;

    final searchRow = filterInside
        ? TextField(
            controller: _controller,
            onChanged: widget.onChanged,
            onTapOutside: (_) =>
                FocusManager.instance.primaryFocus?.unfocus(),
            decoration: _decoration(),
            style: AppTypography.body,
          )
        : TextField(
            controller: _controller,
            onChanged: widget.onChanged,
            onTapOutside: (_) =>
                FocusManager.instance.primaryFocus?.unfocus(),
            decoration: _decoration(),
            style: AppTypography.body,
          );

    return searchRow;
  }
}
