import 'package:flutter/material.dart';

import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/widgets.dart';
import 'set_availability_dates_screen.dart';
import 'set_availability_weekly_screen.dart';
import '../../../../../core/theme/app_colors.dart';

// Two big list tiles — weekly editor vs specific-dates editor
class SetAvailabilityChooserScreen extends StatelessWidget {
  const SetAvailabilityChooserScreen({
    super.key,
    required this.listingId,
    this.currentStep = 4,
    this.totalSteps = 5,
  });

  final String listingId;
  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppStepTopBar(
        title: 'Availability',
        currentStep: currentStep,
        totalSteps: totalSteps,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.lg),
            AppNavTile(
              label: 'Set Weekly Schedule',
              showDividerAbove: true,
              onTap: () {
                Navigator.of(context).push(
                  AppPageRoute<void>(
                    builder: (_) =>
                        SetAvailabilityWeeklyScreen(listingId: listingId),
                  ),
                );
              },
            ),
            AppNavTile(
              label: 'Set Specific Dates',
              showDividerAbove: true,
              showDividerBelow: true,
              onTap: () {
                Navigator.of(context).push(
                  AppPageRoute<void>(
                    builder: (_) =>
                        SetAvailabilityDatesScreen(listingId: listingId),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
