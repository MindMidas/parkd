import 'package:flutter/material.dart';

import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/widgets.dart';
import 'set_availability_dates_screen.dart';
import 'set_availability_weekly_screen.dart';

/// Chooser: "Set weekly schedule" or "Set specific dates". Pushes the corresponding screen.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppTopBar(title: 'Set availability', showBack: true),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.lg),
            AppListItem(
              label: 'Set weekly schedule',
              showTopBorder: true,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SetAvailabilityWeeklyScreen(
                      listingId: listingId,
                      currentStep: 4,
                      totalSteps: 4,
                    ),
                  ),
                );
              },
            ),
            AppListItem(
              label: 'Set specific dates',
              showTopBorder: true,
              showBottomBorder: true,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        SetAvailabilityDatesScreen(
                        listingId: listingId,
                        currentStep: 4,
                        totalSteps: 4,
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
