import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'app_sticky_footer.dart';

/// Thin wrapper → [AppStickyFooter] (solid sticky CTA strip).
@Deprecated('Use AppStickyFooter directly')
class AppSurfaceFooterPad extends StatelessWidget {
  const AppSurfaceFooterPad({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.sm,
      AppSpacing.lg,
      AppSpacing.md,
    ),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return AppStickyFooter(padding: padding, child: child);
  }
}
