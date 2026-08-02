import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import 'app_bottom_sheet_grabber.dart';

// Shared modal sheet chrome: solid surface, grabber, optional sticky footer.
class AppModalSheet extends StatelessWidget {
  const AppModalSheet({
    super.key,
    required this.child,
    this.footer,
    this.maxHeightFraction = 0.92,
    this.showGrabber = true,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      0,
      AppSpacing.lg,
      AppSpacing.lg,
    ),
  });

  final Widget child;
  final Widget? footer;
  final double maxHeightFraction;
  final bool showGrabber;
  final EdgeInsetsGeometry padding;

  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isScrollControlled = true,
    bool useRootNavigator = false,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      useRootNavigator: useRootNavigator,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: AppColors.transparent,
      barrierColor: AppColors.scrimOnImage,
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * maxHeightFraction;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final radius = const BorderRadius.vertical(
      top: Radius.circular(AppRadius.sheet),
    );

    // Full-height route (isScrollControlled) — empty space above the card must
    // dismiss, not eat taps meant for the barrier.
    return AnimatedPadding(
      duration: AppMotion.fast,
      curve: AppMotion.decelerate,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).maybePop(),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            // Keep taps on the sheet from bubbling to the dismiss layer.
            onTap: () {},
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxH),
              child: Material(
                color: AppColors.surface,
                borderRadius: radius,
                clipBehavior: Clip.antiAlias,
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showGrabber) const AppBottomSheetGrabber(),
                      Flexible(
                        child: Padding(padding: padding, child: child),
                      ),
                      ?footer,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
