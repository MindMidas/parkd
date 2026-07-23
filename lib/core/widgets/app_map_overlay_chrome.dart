import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_ink.dart';
import '../theme/app_radius.dart';
import '../utils/app_feedback.dart';

/// Circular map control (recenter) — matches search-card soft chrome.
class AppMapFloatingIconButton extends StatelessWidget {
  const AppMapFloatingIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 44,
    this.iconSize = 22,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final button = DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowElevated,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: AppColors.surface,
        elevation: 0,
        shadowColor: AppColors.transparent,
        surfaceTintColor: AppColors.transparent,
        shape: CircleBorder(
          side: BorderSide(
            color: AppColors.secondaryGrey.withValues(alpha: 0.85),
            width: 0.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            AppFeedback.selection(context);
            onPressed();
          },
          customBorder: const CircleBorder(),
          splashColor: AppInk.splash,
          highlightColor: AppInk.highlight,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              icon,
              color: AppColors.primaryBlue,
              size: iconSize,
            ),
          ),
        ),
      ),
    );

    final tip = tooltip?.trim();
    if (tip == null || tip.isEmpty) return button;
    return Tooltip(message: tip, child: button);
  }
}

/// Solid map overlay card (error / status strips) — same soft lift as search.
class AppMapOverlayCard extends StatelessWidget {
  const AppMapOverlayCard({
    super.key,
    required this.child,
    this.borderColor,
  });

  final Widget child;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowElevated,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: AppColors.surface,
        elevation: 0,
        shadowColor: AppColors.transparent,
        surfaceTintColor: AppColors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(
            color: borderColor ?? AppColors.secondaryGrey,
            width: 0.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}
