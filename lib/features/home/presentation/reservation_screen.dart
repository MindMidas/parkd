import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import 'confirm_pay_screen.dart';

class ReservationScreen extends StatefulWidget {
  const ReservationScreen({
    super.key,
    required this.hourlyRate,
    required this.dailyRate,
    required this.availableWeekdays,
    required this.streetAddress,
    required this.cityLine,
    required this.latitude,
    required this.longitude,
  });

  final double hourlyRate;
  final double dailyRate;
  final String streetAddress;
  final String cityLine;
  final double latitude;
  final double longitude;

  /// Set of weekday numbers that are available (DateTime.monday == 1 .. DateTime.sunday == 7).
  final Set<int> availableWeekdays;

  @override
  State<ReservationScreen> createState() => _ReservationScreenState();
}

class _ReservationScreenState extends State<ReservationScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 15, minute: 0);

  // -----------------------------------------------------------------------
  // Price calculation: $dailyRate per full day + $hourlyRate per extra hour
  // -----------------------------------------------------------------------
  String get _totalPrice {
    if (_startDate == null || _endDate == null) return '\$0.00';

    final start = DateTime(
      _startDate!.year,
      _startDate!.month,
      _startDate!.day,
      _startTime.hour,
      _startTime.minute,
    );
    final end = DateTime(
      _endDate!.year,
      _endDate!.month,
      _endDate!.day,
      _endTime.hour,
      _endTime.minute,
    );

    if (end.isBefore(start) || end.isAtSameMomentAs(start)) return '\$0.00';

    final diff = end.difference(start);
    final totalHours = diff.inMinutes / 60.0;
    final fullDays = diff.inDays;
    final remainingHours = (totalHours - fullDays * 24).ceil();

    final cost =
        fullDays * widget.dailyRate + remainingHours * widget.hourlyRate;

    return '\$${cost.toStringAsFixed(2)}';
  }

  String get _durationLabel {
    if (_startDate == null || _endDate == null) return '';

    final start = DateTime(
      _startDate!.year,
      _startDate!.month,
      _startDate!.day,
      _startTime.hour,
      _startTime.minute,
    );
    final end = DateTime(
      _endDate!.year,
      _endDate!.month,
      _endDate!.day,
      _endTime.hour,
      _endTime.minute,
    );

    if (end.isBefore(start) || end.isAtSameMomentAs(start)) return '';

    final diff = end.difference(start);
    final fullDays = diff.inDays;
    final remainingHours =
        (diff.inMinutes / 60.0 - fullDays * 24).ceil();

    final parts = <String>[];
    if (fullDays > 0) parts.add('$fullDays day${fullDays == 1 ? '' : 's'}');
    if (remainingHours > 0) {
      parts.add('$remainingHours hour${remainingHours == 1 ? '' : 's'}');
    }
    return parts.join(' and ');
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primaryBlue,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '---';
    return DateFormat('MMM d, y').format(date);
  }

  String _formatTime(TimeOfDay time) {
    final now = DateTime(2000, 1, 1, time.hour, time.minute);
    return DateFormat('h:mm a').format(now);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // --- Header ---
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.lg,
                0,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: AppColors.primaryBlue,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: Text(
                      'Choose parking duration',
                      style: AppTypography.title.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // --- Scrollable content ---
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    // --- Set start and end dates label ---
                    const Center(
                      child: AppSectionLabel('Set start and end dates'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // --- Calendar card ---
                    AppDateRangeCalendar(
                      startDate: _startDate,
                      endDate: _endDate,
                      availableWeekdays: widget.availableWeekdays,
                      onRangeChanged: (start, end) {
                        setState(() {
                          _startDate = start;
                          _endDate = end;
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // --- Set start and end time label ---
                    const Center(
                      child: AppSectionLabel('Set start and end time'),
                    ),
                    const Divider(height: AppSpacing.lg),
                    // --- Start time ---
                    AppTimePickerRow(
                      label: 'Start time',
                      value: '${_formatDate(_startDate)} • ${_formatTime(_startTime)}',
                      onTap: () => _pickTime(isStart: true),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // --- End time ---
                    AppTimePickerRow(
                      label: 'End time',
                      value: '${_formatDate(_endDate)} • ${_formatTime(_endTime)}',
                      onTap: () => _pickTime(isStart: false),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // --- Reservation total ---
                    const Center(
                      child: AppSectionLabel('Reservation total'),
                    ),
                    const Divider(height: AppSpacing.lg),
                    Text(
                      '$_totalPrice for $_durationLabel',
                      style: AppTypography.body,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
            // --- Confirm button ---
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed:
                      (_startDate != null && _endDate != null)
                          ? () {
                              final start = DateTime(
                                _startDate!.year,
                                _startDate!.month,
                                _startDate!.day,
                                _startTime.hour,
                                _startTime.minute,
                              );
                              final end = DateTime(
                                _endDate!.year,
                                _endDate!.month,
                                _endDate!.day,
                                _endTime.hour,
                                _endTime.minute,
                              );
                              final diff = end.difference(start);
                              final fullDays = diff.inDays;
                              final remainingHours =
                                  (diff.inMinutes / 60.0 - fullDays * 24)
                                      .ceil();
                              final subtotal = fullDays * widget.dailyRate +
                                  remainingHours * widget.hourlyRate;

                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ConfirmPayScreen(
                                    streetAddress: widget.streetAddress,
                                    cityLine: widget.cityLine,
                                    latitude: widget.latitude,
                                    longitude: widget.longitude,
                                    startDateTime: start,
                                    endDateTime: end,
                                    durationLabel: _durationLabel,
                                    subtotal: subtotal,
                                  ),
                                ),
                              );
                            }
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.primaryBlue.withValues(alpha: 0.4),
                    disabledForegroundColor: Colors.white70,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Confirm',
                    style: AppTypography.button.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
