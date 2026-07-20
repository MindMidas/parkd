import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/display_formatting.dart';

// Top bar + optional back; title wraps 2 lines; title case via formatTitleCaseWords
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.showBack = true,
    this.centerTitle = false,
    this.onBack,
    this.actions,
  });

  final String title;
  final bool showBack;

  final bool centerTitle;
  final VoidCallback? onBack;
  final List<Widget>? actions;

  // Same toolbar height as step bar
  static const double kToolbarHeight = 80;

  static const double _leadingWidthWhenBack = 56;

  // Alias for app_step_top_bar and older call sites
  static String formatTitle(String text) => formatTitleCaseWords(text);

  @override
  Widget build(BuildContext context) {
    final displayTitle = formatTitleCaseWords(title);
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      centerTitle: centerTitle,
      toolbarHeight: kToolbarHeight,
      foregroundColor: AppColors.black,
      automaticallyImplyLeading: false,
      leadingWidth: showBack ? _leadingWidthWhenBack : 0,
      title: Text(
        displayTitle,
        style: AppTypography.navTitle.copyWith(color: AppColors.black),
        maxLines: 2,
        softWrap: true,
        overflow: TextOverflow.ellipsis,
        textAlign: centerTitle ? TextAlign.center : TextAlign.left,
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
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
