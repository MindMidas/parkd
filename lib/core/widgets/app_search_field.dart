import 'package:flutter/material.dart';

import '../theme/app_typography.dart';
import 'app_search_field_decoration.dart';

// List/menu search, same shape as AppMapSearchField; onChanged only
class AppSearchField extends StatefulWidget {
  const AppSearchField({
    super.key,
    this.hintText = 'Search',
    this.onChanged,
    this.controller,
  });

  final String hintText;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;

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
    // No outer shadow, AppListScreenSearchPanel supplies hub chrome
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      decoration: AppSearchFieldDecoration.outline(hintText: widget.hintText),
      style: AppTypography.body,
    );
  }
}
