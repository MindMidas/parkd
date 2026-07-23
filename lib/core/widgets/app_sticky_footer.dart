import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Sticky bottom CTA strip — solid surface, soft lift (no stacked hairlines).
class AppStickyFooter extends StatelessWidget {
  const AppStickyFooter({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.sm,
      AppSpacing.lg,
      AppSpacing.md,
    ),
    this.showTopBorder = false,
    this.glass = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Legacy hairline; prefer the soft lift shadow (default off).
  final bool showTopBorder;

  /// Ignored — kept for call-site compatibility; glass is disabled.
  final bool glass;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: showTopBorder
            ? const Border(
                top: BorderSide(color: AppColors.secondaryGrey, width: 0.5),
              )
            : null,
        boxShadow: showTopBorder
            ? null
            : const [
                BoxShadow(
                  color: AppColors.shadowLow,
                  blurRadius: 10,
                  offset: Offset(0, -3),
                ),
              ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
