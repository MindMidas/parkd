import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

// Reusable top app bar with optional back button. Title wraps up to 2 lines and bar height grows to fit.
// Titles are automatically formatted in title case (first letter of each word capitalized).
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.showBack = true,
    this.onBack,
    this.actions,
  });

  final String title;
  final bool showBack;
  final VoidCallback? onBack;
  final List<Widget>? actions;

  static const double _toolbarHeight = 80;

  /// Standard title-case formatting for app bar: first letter of each word capitalized.
  static String formatTitle(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final displayTitle = formatTitle(title);
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      toolbarHeight: _toolbarHeight,
      foregroundColor: AppColors.black,
      title: SizedBox(
        width: double.infinity,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            displayTitle,
            style: AppTypography.title.copyWith(color: AppColors.black),
            maxLines: 2,
            softWrap: true,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.left,
          ),
        ),
      ),
      actions: actions,
      leading: showBack
          ? IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.primaryBlue,
              ),
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            )
          : null,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(_toolbarHeight);
}
