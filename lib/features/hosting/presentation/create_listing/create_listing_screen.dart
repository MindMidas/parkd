import 'package:flutter/material.dart';

import '../../../../core/assets/parkd_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
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
                    _WelcomePhotoSection(),
                    const AppHubMenuIntro(
                      lead:
                          'Add the location, upload a photo of the spot, mark '
                          'the parking space, and set your price and '
                          'availability.',
                    ),
                  ],
                ),
              ),
            ),
            AppStickyFooter(
              child: AppPrimaryButton(
                label: 'Get Started',
                onPressed: () {
                  Navigator.of(context).push(
                    AppPageRoute<void>(
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

class _WelcomePhotoSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: AppListingPhotoFrame(
        borderRadius: 0,
        child: Image.asset(
          ParkdAssets.listingDrivewayJpg,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, _, _) => Container(
            color: AppColors.secondaryBlue.withValues(alpha: 0.2),
            child: Icon(
              Icons.photo_rounded,
              size: 80,
              color: AppColors.primaryBlue.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}
