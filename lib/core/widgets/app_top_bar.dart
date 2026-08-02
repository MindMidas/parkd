import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_ink.dart';
import '../theme/app_motion.dart';
import '../theme/app_typography.dart';
import '../utils/app_feedback.dart';

// Circular app-bar control with light press feedback.
class AppTopBarIconButton extends StatefulWidget {
  const AppTopBarIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color = AppColors.primaryBlue,
    this.iconSize = 22,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color color;
  final double iconSize;

  @override
  State<AppTopBarIconButton> createState() => _AppTopBarIconButtonState();
}

class _AppTopBarIconButtonState extends State<AppTopBarIconButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    // Slightly firmer than CTA [AppMotion.pressScale] so icon chrome reads.
    final scale = (!reduceMotion && enabled && _pressed) ? 0.9 : 1.0;

    final button = SizedBox(
      width: 48,
      height: 48,
      child: Listener(
        behavior: HitTestBehavior.deferToChild,
        onPointerDown: enabled ? (_) => _setPressed(true) : null,
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: Material(
          color: AppColors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            splashColor: AppInk.splash,
            highlightColor: AppInk.highlight,
            splashFactory: InkRipple.splashFactory,
            onTap: enabled
                ? () {
                    AppFeedback.selection(context);
                    widget.onPressed!();
                  }
                : null,
            child: AnimatedScale(
              scale: scale,
              duration: AppMotion.press,
              curve: AppMotion.emphasized,
              child: Center(
                child: Icon(
                  widget.icon,
                  color: enabled ? widget.color : AppColors.iconGrey,
                  size: widget.iconSize,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final tip = widget.tooltip?.trim();
    if (tip == null || tip.isEmpty) return button;
    return Tooltip(message: tip, child: button);
  }
}

// Top bar + optional back; title wraps 2 lines (pass sentence case from call sites)
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.showBack = true,
    this.centerTitle = false,
    this.onBack,
    this.actions,
    this.backgroundColor = AppColors.surface,
  });

  final String title;
  final bool showBack;

  final bool centerTitle;
  final VoidCallback? onBack;
  final List<Widget>? actions;

  // Match hub washes (Reservations / Hosting) so the top reads as one field.
  final Color backgroundColor;

  // Same toolbar height as the step bar.
  static const double kToolbarHeight = 64;

  static const double _leadingWidthWhenBack = 56;

  // Alias for app_step_top_bar and older call sites
  static String formatTitle(String text) => text;

  @override
  Widget build(BuildContext context) {
    final displayTitle = title;
    final transparent = backgroundColor.a == 0;
    return AppBar(
      backgroundColor: backgroundColor,
      forceMaterialTransparency: transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: AppColors.transparent,
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
          ? AppTopBarIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              tooltip: 'Back',
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            )
          : null,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
