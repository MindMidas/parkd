import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../utils/scroll_view_bottom_inset.dart';

// Padded form scroll (auth, settings)
class AppFormScrollBody extends StatelessWidget {
  const AppFormScrollBody({
    super.key,
    required this.child,
    this.topPadding = AppSpacing.md,
    this.horizontalPadding = AppSpacing.lg,
    this.physics,
  });

  final Widget child;
  final double topPadding;
  final double horizontalPadding;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    final bottom = scrollViewBottomInset(context);
    return SingleChildScrollView(
      physics:
          physics ??
          const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        topPadding,
        horizontalPadding,
        AppSpacing.xl + bottom,
      ),
      child: child,
    );
  }
}

// Vertical padding only — rows/dividers go full width; sections pad themselves
class AppMenuScrollBody extends StatelessWidget {
  const AppMenuScrollBody({
    super.key,
    required this.child,
    this.topPadding = AppSpacing.lg,
    this.bottomPadding = AppSpacing.lg,
    this.physics,
  });

  final Widget child;
  final double topPadding;
  final double bottomPadding;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    final bottom = scrollViewBottomInset(context);
    return SingleChildScrollView(
      physics:
          physics ??
          const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding + bottom),
      child: child,
    );
  }
}
