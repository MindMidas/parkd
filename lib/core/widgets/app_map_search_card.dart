import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radius.dart';
import '../utils/app_feedback.dart';

/// Solid elevated shell for map/list search — quiet focus ring, always opaque.
class AppMapSearchCard extends StatefulWidget {
  const AppMapSearchCard({super.key, required this.child});

  final Widget child;

  @override
  State<AppMapSearchCard> createState() => _AppMapSearchCardState();
}

class _AppMapSearchCardState extends State<AppMapSearchCard> {
  bool _focused = false;

  void _onFocusChange(bool focused) {
    if (_focused == focused) return;
    setState(() => _focused = focused);
    if (focused) AppFeedback.selection(context);
  }

  @override
  Widget build(BuildContext context) {
    final side = BorderSide(
      color: _focused ? AppColors.primaryBlue : AppColors.secondaryGrey,
      width: _focused ? 1.25 : 0.5,
    );

    // Material [shape] draws a full continuous border; BoxDecoration + clip
    // was eating top/bottom edges and leaving blue “ears”.
    return Focus(
      canRequestFocus: false,
      onFocusChange: _onFocusChange,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.decelerate,
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
            side: side,
          ),
          clipBehavior: Clip.antiAlias,
          child: widget.child,
        ),
      ),
    );
  }
}
