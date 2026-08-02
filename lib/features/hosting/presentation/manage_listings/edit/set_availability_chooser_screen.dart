import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/widgets.dart';
import 'set_availability_dates_screen.dart';
import 'set_availability_weekly_screen.dart';

// Chooses between weekly and specific-date availability editors.
class SetAvailabilityChooserScreen extends StatelessWidget {
  const SetAvailabilityChooserScreen({
    super.key,
    required this.listingId,
    this.currentStep,
    this.totalSteps,
  });

  final String listingId;
  final int? currentStep;
  final int? totalSteps;

  bool get _inWizard => currentStep != null && totalSteps != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: _inWizard
          ? AppStepTopBar(
              title: 'Availability',
              currentStep: currentStep!,
              totalSteps: totalSteps!,
            )
          : const AppTopBar(title: 'Availability', showBack: true),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppHubMenuIntro(
              lead:
                  'Choose one schedule type for this listing — weekly hours or '
                  'specific dates.',
            ),
            AppNavTile(
              icon: Icons.date_range_rounded,
              label: 'Weekly schedule',
              subtitle: 'Same hours on chosen days every week',
              showDividerAbove: true,
              onTap: () {
                Navigator.of(context).push(
                  AppPageRoute<void>(
                    builder: (_) => SetAvailabilityWeeklyScreen(
                      listingId: listingId,
                      currentStep: currentStep,
                      totalSteps: totalSteps,
                    ),
                  ),
                );
              },
            ),
            AppNavTile(
              icon: Icons.event_note_rounded,
              label: 'Specific dates',
              subtitle: 'Calendar days or ranges with time windows',
              showDividerAbove: true,
              showDividerBelow: true,
              onTap: () {
                Navigator.of(context).push(
                  AppPageRoute<void>(
                    builder: (_) => SetAvailabilityDatesScreen(
                      listingId: listingId,
                      currentStep: currentStep,
                      totalSteps: totalSteps,
                    ),
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
