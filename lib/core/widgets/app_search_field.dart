import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/app_feedback.dart';
import 'app_search_field_decoration.dart';

/// List/menu search. Use [embeddedInChrome] when wrapped in [AppMapSearchCard].
class AppSearchField extends StatefulWidget {
  const AppSearchField({
    super.key,
    this.hintText = 'Search',
    this.onChanged,
    this.controller,
    this.embeddedInChrome = false,
  });

  final String hintText;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final bool embeddedInChrome;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
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

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      onTap: () => AppFeedback.selection(context),
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      cursorColor: AppColors.primaryBlue,
      decoration: widget.embeddedInChrome
          ? AppSearchFieldDecoration.mapEmbedded(hintText: widget.hintText)
          : AppSearchFieldDecoration.outline(hintText: widget.hintText),
      style: widget.embeddedInChrome
          ? AppTypography.bodySecondary.copyWith(color: AppColors.textPrimary)
          : AppTypography.body,
      textInputAction: TextInputAction.search,
    );
  }
}
