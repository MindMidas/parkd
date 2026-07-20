import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

// Little pill on bottom sheets so users know they can drag
class AppBottomSheetGrabber extends StatelessWidget {
  const AppBottomSheetGrabber({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 40,
        height: 4,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.iconGrey.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
