import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_bottom_sheet_grabber.dart';

// Shared Cupertino picker chrome — matches AppModalSheet top radius + grabber.
class AppPickerSheet extends StatelessWidget {
  const AppPickerSheet({
    super.key,
    required this.onCancel,
    required this.onDone,
    required this.child,
    this.cancelLabel = 'Cancel',
    this.doneLabel = 'Done',
  });

  final VoidCallback onCancel;
  final VoidCallback onDone;
  final Widget child;
  final String cancelLabel;
  final String doneLabel;

  static const BorderRadius sheetRadius = BorderRadius.vertical(
    top: Radius.circular(AppRadius.sheet),
  );

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Material(
      color: AppColors.surface,
      borderRadius: sheetRadius,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: SafeArea(
          top: false,
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppBottomSheetGrabber(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    onPressed: onCancel,
                    child: Text(
                      cancelLabel,
                      style: AppTypography.bodySecondary.copyWith(
                        color: AppColors.iconGrey,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    onPressed: onDone,
                    child: Text(doneLabel, style: AppTypography.textAction),
                  ),
                ],
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
