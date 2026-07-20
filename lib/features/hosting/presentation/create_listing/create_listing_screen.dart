import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import 'create_listing_flow/add_location_screen.dart';

// Wizard entry — hero frame plus CTA into add-location
class CreateListingScreen extends StatelessWidget {
  const CreateListingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const AppTopBar(title: 'Create listing'),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _WelcomePhotoSection(), // full width, no padding
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Create a parking listing in just a few steps',
                            textAlign: TextAlign.left,
                            style: AppTypography.navTitle.copyWith(
                              color: AppColors.black,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Add the location, upload a photo of the spot, mark the parking space, and set your price and availability.',
                            textAlign: TextAlign.left,
                            style: AppTypography.bodyMuted,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: AppPrimaryButton(
                label: 'Get Started',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AddLocationScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomePhotoSection extends StatefulWidget {
  @override
  State<_WelcomePhotoSection> createState() => _WelcomePhotoSectionState();
}

class _WelcomePhotoSectionState extends State<_WelcomePhotoSection> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: AppListingPhotoFrame(
        borderRadius: 0,
        child: Container(
          color: AppColors.secondaryBlue.withValues(alpha: 0.2),
          child: Icon(
            Icons.photo_rounded,
            size: 80,
            color: AppColors.primaryBlue.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}
