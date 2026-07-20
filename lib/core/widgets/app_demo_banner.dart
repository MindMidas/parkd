import 'package:flutter/material.dart';

import '../config/app_environment.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Persistent disclosure used by the public portfolio build.
class AppDemoFrame extends StatelessWidget {
  const AppDemoFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!AppEnvironment.isPortfolioDemo) return child;

    return Column(
      children: [
        Material(
          color: AppColors.demoBannerBackground,
          child: SafeArea(
            bottom: false,
            child: Semantics(
              container: true,
              liveRegion: true,
              label:
                  'Portfolio demonstration. Test data resets after 24 hours. '
                  'Do not enter real personal or payment information.',
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xxs,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.science_outlined,
                      size: 16,
                      color: AppColors.demoBannerForeground,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        'Portfolio demo · Test data resets after 24 hours · '
                        'Never enter real personal or payment information',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppTypography.captionStrong.copyWith(
                          color: AppColors.demoBannerForeground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child,
          ),
        ),
      ],
    );
  }
}
