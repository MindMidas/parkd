import 'package:flutter/material.dart';

import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../home/presentation/home_map_screen.dart';
import 'create_listing_flow/add_location_screen.dart';

class CreateListingScreen extends StatelessWidget {
  const CreateListingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppTopBar(
        title: 'Follow the steps to create your listing',
        showBack: true
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WelcomePhotoSection(), // full width, no padding
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Create a parking listing in just a few steps',
                  style: AppTypography.headline,
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Add the location, upload a photo of the spot, mark the parking space, and set your price and availability.',
                  style: AppTypography.body,
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: AppSpacing.md),
                AppPrimaryButton(
                  label: 'Get Started', 
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AddLocationScreen(
                          listingId: 'temp-id'
                        ),
                      ),
                    );
                  }
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 1,
        onDestinationSelected: (index) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => HomeMapScreen(initialIndex: index),
            ),
            (route) => false,
          );
        },
      ),
    );
  }
}

class _WelcomePhotoSection extends StatefulWidget {
  @override
  State<_WelcomePhotoSection> createState() => _WelcomePhotoSectionState();
}

class _WelcomePhotoSectionState extends State<_WelcomePhotoSection> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const int _pageCount = 3;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 400,
      child: Stack(
        children: [
          // --- Pager ---
          PageView.builder(
            controller: _pageController,
            itemCount: _pageCount,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) => Container(
              color: AppColors.secondaryBlue.withValues(alpha: 0.35),
              child: Icon(
                Icons.photo_rounded,
                size: 80,
                color: AppColors.primaryBlue.withValues(alpha: 0.6),
              ),
            ),
          ),

          // --- Dot indicators ---
          Positioned(
            bottom: AppSpacing.lg,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pageCount, (index) {
                final isActive = index == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isActive ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.primaryBlue
                        : AppColors.primaryBlue.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}