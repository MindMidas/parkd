import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/widgets/widgets.dart';
import 'confirmation_success_screen.dart';
import 'modify_price_screen.dart';

/// Set availability using weekly schedule: days + start/end time, add slots, list with remove, confirm.
class SetAvailabilityWeeklyScreen extends StatefulWidget {
  const SetAvailabilityWeeklyScreen({
    super.key,
    required this.listingId,
    this.currentStep,
    this.totalSteps,
  });

  final String listingId;
  final int? currentStep;
  final int? totalSteps;

  @override
  State<SetAvailabilityWeeklyScreen> createState() =>
      _SetAvailabilityWeeklyScreenState();
}

class _SetAvailabilityWeeklyScreenState
    extends State<SetAvailabilityWeeklyScreen> {
  final Set<int> _selectedDays = {0, 1, 2, 3, 4, 5, 6};
  String _startTime = '9:15 AM';
  String _endTime = '3:00 PM';
  final List<({String day, String timeRange})> _slots = [
    (day: 'Mon', timeRange: '9:15 AM to 1:00 PM'),
    (day: 'Mon', timeRange: '3:00 PM to 6:00 PM'),
    (day: 'Tue', timeRange: '8:30 AM to 3:00 PM'),
  ];

  static void _noopClose() {}

  void _onConfirm() {
    if (widget.currentStep != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ModifyPriceScreen(
            listingId: widget.listingId,
            slots: _slots.map((s) => '${s.day}  ${s.timeRange}').toList(),
            currentStep: 4,
            totalSteps: 4,
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ConfirmationSuccessScreen(
            message: 'Availability updated',
            onClose: _noopClose,
            popsOnClose: 3,
          ),
        ),
      );
    }
  }

  void _addSlot() {
    setState(() {
      final dayIndex = _selectedDays.isEmpty
          ? 0
          : _selectedDays.reduce((a, b) => a < b ? a : b);
      final day = kWeekdayLabels[dayIndex];
      _slots.add((day: day, timeRange: '$_startTime to $_endTime'));
    });
  }

  void _removeSlot(int index) {
    setState(() => _slots.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppTopBar(
        title: 'Set your weekly schedule',
        showBack: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Choose when the parking spot is available.',
                      style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppDayCheckboxes(
                      selectedIndices: _selectedDays,
                      onChanged: (v) => setState(() {
                        _selectedDays.clear();
                        _selectedDays.addAll(v);
                      }),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTimeStepperRow(
                      label: 'Start time',
                      value: _startTime,
                      labelWidth: 100,
                      onDecrement: () => setState(() => _startTime = '9:00 AM'),
                      onIncrement: () => setState(() => _startTime = '9:30 AM'),
                    ),
                    AppTimeStepperRow(
                      label: 'End time',
                      value: _endTime,
                      labelWidth: 100,
                      onDecrement: () => setState(() => _endTime = '2:30 PM'),
                      onIncrement: () => setState(() => _endTime = '3:30 PM'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppPrimaryButton(label: 'Add slot', onPressed: _addSlot),
                    const AppSectionDividerTitle('Scheduled time slots'),
                    ...List.generate(_slots.length, (i) {
                      final s = _slots[i];
                      return AppSlotCardRemove(
                        onRemove: () => _removeSlot(i),
                        child: AppSlotCardRemoveWeekly(
                          day: s.day,
                          timeRange: s.timeRange,
                        ),
                      );
                    }),
                    const SizedBox(height: AppSpacing.lg),
                    AppPrimaryButton(label: 'Confirm', onPressed: _onConfirm),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
