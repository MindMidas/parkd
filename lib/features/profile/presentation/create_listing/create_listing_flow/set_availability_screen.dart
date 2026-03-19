import 'package:flutter/material.dart';
import 'package:parkd/core/widgets/app_step_top_bar.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/widgets/widgets.dart';
import '../../../../home/presentation/home_map_screen.dart';
import '../../manage_listings/edit/confirmation_success_screen.dart';
import 'set_pricing_screen.dart';
import 'terms_and_conditions_screen.dart';

// Specific slot with optional per-slot pricing
typedef SpecificSlot = ({
  DateTime fromDate,
  DateTime toDate,
  String startTime,
  String endTime,
  double? hourlyPrice,
  double? dailyPrice,
});

class SetAvailabilityScreen extends StatefulWidget {
  const SetAvailabilityScreen({
    super.key,
    required this.listingId,
    this.onPublish,
  });

  final String listingId;
  final VoidCallback? onPublish;

  @override
  State<SetAvailabilityScreen> createState() => _SetAvailabilityScreenState();
}

class _SetAvailabilityScreenState extends State<SetAvailabilityScreen> {
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  final Set<DateTime> _selectedDates = {};
  int _activeTab = 0;

  // Specific slots — each has its own optional price
  final List<SpecificSlot> _slots = [];

  // Recurring schedule — plain strings, one global price for all recurring
  final Map<int, List<String>> _recurringSchedule = {};
  double? _recurringHourlyPrice;
  double? _recurringDailyPrice;

  final DateTime _minDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  String _startTime = '9:15 AM';
  String _endTime = '3:00 PM';

  bool get _hasSlots => _slots.isNotEmpty || _recurringSchedule.isNotEmpty;

  bool get _allSlotsPriced {
    final specificPriced = _slots.every((s) => s.hourlyPrice != null);
    final recurringPriced =
        _recurringSchedule.isEmpty || _recurringHourlyPrice != null;
    return specificPriced && recurringPriced;
  }

  bool get _hasValidListing => _hasSlots && _allSlotsPriced;

  static String _weekdayShort(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  static const _times = [
    '12:00 AM',
    '12:30 AM',
    '1:00 AM',
    '1:30 AM',
    '2:00 AM',
    '2:30 AM',
    '3:00 AM',
    '3:30 AM',
    '4:00 AM',
    '4:30 AM',
    '5:00 AM',
    '5:30 AM',
    '6:00 AM',
    '6:30 AM',
    '7:00 AM',
    '7:30 AM',
    '8:00 AM',
    '8:30 AM',
    '9:00 AM',
    '9:15 AM',
    '9:30 AM',
    '10:00 AM',
    '10:30 AM',
    '11:00 AM',
    '11:30 AM',
    '12:00 PM',
    '12:30 PM',
    '1:00 PM',
    '1:30 PM',
    '2:00 PM',
    '2:30 PM',
    '3:00 PM',
    '3:30 PM',
    '4:00 PM',
    '4:30 PM',
    '5:00 PM',
    '5:30 PM',
    '6:00 PM',
    '6:30 PM',
    '7:00 PM',
    '7:30 PM',
    '8:00 PM',
    '8:30 PM',
    '9:00 PM',
    '9:30 PM',
    '10:00 PM',
    '10:30 PM',
    '11:00 PM',
    '11:30 PM',
  ];

  void _stepTime(bool isStart, int delta) {
    final current = isStart ? _startTime : _endTime;
    final idx = _times.indexOf(current);
    if (idx == -1) return;
    final next = (idx + delta).clamp(0, _times.length - 1);
    setState(() {
      if (isStart) {
        _startTime = _times[next];
      } else {
        _endTime = _times[next];
      }
    });
  }

  void _onDayTap(DateTime date) {
    setState(() {
      final alreadySelected = _selectedDates.any(
        (d) =>
            d.year == date.year && d.month == date.month && d.day == date.day,
      );
      if (alreadySelected) {
        _selectedDates.removeWhere(
          (d) =>
              d.year == date.year && d.month == date.month && d.day == date.day,
        );
      } else {
        _selectedDates.add(date);
      }
    });
  }

  void _addToRecurring() {
    if (_selectedDates.isEmpty) return;
    final timeSlot = '$_startTime - $_endTime';
    setState(() {
      for (final date in _selectedDates) {
        final weekday = date.weekday;
        if (_recurringSchedule.containsKey(weekday)) {
          if (!_recurringSchedule[weekday]!.contains(timeSlot)) {
            _recurringSchedule[weekday]!.add(timeSlot);
          }
        } else {
          _recurringSchedule[weekday] = [timeSlot];
        }
      }
      _selectedDates.clear();
    });
  }

  void _addSlot() {
    if (_selectedDates.isEmpty) return;
    final sorted = _selectedDates.toList()..sort();
    setState(() {
      _slots.add((
        fromDate: sorted.first,
        toDate: sorted.last,
        startTime: _startTime,
        endTime: _endTime,
        hourlyPrice: null,
        dailyPrice: null,
      ));
      _selectedDates.clear();
    });
  }

  void _removeSlot(int index) {
    setState(() => _slots.removeAt(index));
  }

  void _removeRecurringSlot(int weekday, int slotIndex) {
    setState(() {
      _recurringSchedule[weekday]!.removeAt(slotIndex);
      if (_recurringSchedule[weekday]!.isEmpty) {
        _recurringSchedule.remove(weekday);
      }
    });
  }

  String _formatSlotDate(DateTime date, String time) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year} • $time';
  }

  // Open pricing screen for a specific slot
  Future<void> _openPricingForSlot(int index) async {
    final s = _slots[index];
    final result = await Navigator.push<({double hourly, double? daily})>(
      context,
      MaterialPageRoute(
        builder: (_) => SetPricingScreen(
          initialHourly: s.hourlyPrice,
          initialDaily: s.dailyPrice,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _slots[index] = (
          fromDate: s.fromDate,
          toDate: s.toDate,
          startTime: s.startTime,
          endTime: s.endTime,
          hourlyPrice: result.hourly,
          dailyPrice: result.daily,
        );
      });
    }
  }

  // Open pricing screen for recurring slots (sets global recurring price)
  Future<void> _openPricingForRecurring() async {
    final result = await Navigator.push<({double hourly, double? daily})>(
      context,
      MaterialPageRoute(
        builder: (_) => SetPricingScreen(
          initialHourly: _recurringHourlyPrice,
          initialDaily: _recurringDailyPrice,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _recurringHourlyPrice = result.hourly;
        _recurringDailyPrice = result.daily;
      });
    }
  }

  Widget _priceLabel(double? hourlyPrice) {
    if (hourlyPrice == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.add_circle_outline,
            size: 14,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 4),
          Text('Price', style: AppTypography.caption),
        ],
      );
    }
    return Text(
      '\$${hourlyPrice.toStringAsFixed(2)}/hr',
      style: AppTypography.caption.copyWith(
        color: AppColors.primaryBlue,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppStepTopBar(
        title: 'Set your specific dates',
        currentStep: 4,
        totalSteps: 5,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Choose when the parking spot is available',
                      style: AppTypography.body,
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: AppSpacing.md),

                    AppMonthCalendar(
                      currentMonth: _currentMonth,
                      selectedDates: _selectedDates,
                      minDate: _minDate,
                      onPrevMonth: () => setState(() {
                        _currentMonth = DateTime(
                          _currentMonth.year,
                          _currentMonth.month - 1,
                        );
                      }),
                      onNextMonth: () => setState(() {
                        _currentMonth = DateTime(
                          _currentMonth.year,
                          _currentMonth.month + 1,
                        );
                      }),
                      onDayTap: _onDayTap,
                    ),

                    const SizedBox(height: AppSpacing.lg),
                    AppTimeStepperRow(
                      label: 'Start date time',
                      value: _startTime,
                      labelWidth: 120,
                      onDecrement: () => _stepTime(true, -1),
                      onIncrement: () => _stepTime(true, 1),
                    ),
                    AppTimeStepperRow(
                      label: 'End date time',
                      value: _endTime,
                      labelWidth: 120,
                      onDecrement: () => _stepTime(false, -1),
                      onIncrement: () => _stepTime(false, 1),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    Row(
                      children: [
                        Expanded(
                          child: AppPrimaryButton(
                            label: 'Add slot',
                            onPressed: _selectedDates.isEmpty ? null : _addSlot,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: AppPrimaryButton(
                            label: 'Add Recurring',
                            onPressed: _selectedDates.isEmpty
                                ? null
                                : _addToRecurring,
                          ),
                        ),
                      ],
                    ),

                    // --- Tab bar ---
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.secondaryGrey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.all(3),
                      child: Row(
                        children: [
                          _TabChip(
                            label: 'Specific slots',
                            active: _activeTab == 0,
                            onTap: () => setState(() => _activeTab = 0),
                          ),
                          _TabChip(
                            label: 'Recurring',
                            active: _activeTab == 1,
                            onTap: () => setState(() => _activeTab = 1),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // --- Content ---
                    if (_activeTab == 0)
                      _slots.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.lg,
                                ),
                                child: Text(
                                  'No slots added yet',
                                  style: AppTypography.caption,
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _slots.length,
                              itemBuilder: (context, i) {
                                final s = _slots[i];
                                return GestureDetector(
                                  onTap: () => _openPricingForSlot(i),
                                  child: AppSlotCardRemove(
                                    onRemove: () => _removeSlot(i),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: AppSpacing.sm,
                                        horizontal: AppSpacing.md,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    SizedBox(
                                                      width: 40,
                                                      child: Text(
                                                        'From',
                                                        style: AppTypography
                                                            .caption,
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      width: AppSpacing.sm,
                                                    ),
                                                    Text(
                                                      _formatSlotDate(
                                                        s.fromDate,
                                                        s.startTime,
                                                      ),
                                                      style:
                                                          AppTypography.caption,
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Row(
                                                  children: [
                                                    SizedBox(
                                                      width: 40,
                                                      child: Text(
                                                        'To',
                                                        style: AppTypography
                                                            .caption,
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      width: AppSpacing.sm,
                                                    ),
                                                    Text(
                                                      _formatSlotDate(
                                                        s.toDate,
                                                        s.endTime,
                                                      ),
                                                      style:
                                                          AppTypography.caption,
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          _priceLabel(s.hourlyPrice),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            )
                    else
                      _recurringSchedule.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.lg,
                                ),
                                child: Text(
                                  'No recurring slots added yet',
                                  style: AppTypography.caption,
                                ),
                              ),
                            )
                          : ListView(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              children: [
                                for (final entry
                                    in _recurringSchedule.entries.toList()
                                      ..sort((a, b) => a.key.compareTo(b.key)))
                                  for (int i = 0; i < entry.value.length; i++)
                                    GestureDetector(
                                      onTap: _openPricingForRecurring,
                                      child: AppSlotCardRemove(
                                        onRemove: () =>
                                            _removeRecurringSlot(entry.key, i),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: AppSpacing.sm,
                                            horizontal: AppSpacing.md,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              Container(
                                                width: 44,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primaryBlue
                                                      .withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  _weekdayShort(entry.key),
                                                  textAlign: TextAlign.center,
                                                  style: AppTypography.caption
                                                      .copyWith(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: AppColors
                                                            .primaryBlue,
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(
                                                width: AppSpacing.md,
                                              ),
                                              Expanded(
                                                child: Text(
                                                  entry.value[i],
                                                  style: AppTypography.caption,
                                                ),
                                              ),
                                              _priceLabel(
                                                _recurringHourlyPrice,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                              ],
                            ),

                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),

            // Confirm button pinned to bottom
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Column(
                children: [
                  if (_hasSlots && !_allSlotsPriced)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Text(
                        'Tap a slot to set its price before confirming',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  AppPrimaryButton(
                    label: 'Confirm',
                    onPressed: _hasValidListing
                        ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => TermsAndConditionsScreen(
                                  onPublish: () {
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(
                                        builder: (_) => ConfirmationSuccessScreen(
                                          title: 'Listing Published',
                                          message:
                                              'Your parking spot is now live. Drivers can find and book it on Parkd.',
                                          buttonLabel: 'Go to Home',
                                          onClose: () {
                                            if (widget.onPublish != null) {
                                              widget.onPublish!();
                                            } else {
                                              Navigator.of(
                                                context,
                                              ).pushAndRemoveUntil(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      const HomeMapScreen(
                                                        initialIndex: 0,
                                                      ),
                                                ),
                                                (route) => false,
                                              );
                                            }
                                          },
                                          popsOnClose: 0,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          }
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              color: active ? AppColors.primaryBlue : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
