import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

// Sticky bottom CTA strip — solid surface, soft lift (no stacked hairlines).
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
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Optional top hairline; default uses a soft lift shadow instead.
  final bool showTopBorder;

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
