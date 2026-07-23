import 'package:flutter/material.dart';

import '../map/availability_heatmap_logic.dart';
import '../models/availability_specific.dart';
import '../models/availability_weekly.dart';
import '../models/booking_time_window.dart';
import '../models/listing.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_segment_control.dart';

enum _HeatmapRange { day, week, month }

Color _heatmapSlotFill(AvailabilitySlotState s) {
  return switch (s) {
    AvailabilitySlotState.open => AppColors.primaryBlue,
    AvailabilitySlotState.booked => AppColors.heatmapBooked,
    AvailabilitySlotState.hostClosed => AppColors.heatmapHostClosed,
  };
}

// 24h strip per row; 5-min data rolled up to hours
class AppListingAvailabilityHeatmap extends StatefulWidget {
  const AppListingAvailabilityHeatmap({
    super.key,
    required this.loading,
    required this.listing,
    required this.weekly,
    required this.specific,
    required this.bookings,
  });

  final bool loading;
  final Listing listing;
  final List<AvailabilityWeekly> weekly;
  final List<AvailabilitySpecific> specific;
  final List<BookingTimeWindow> bookings;

  @override
  State<AppListingAvailabilityHeatmap> createState() =>
      _AppListingAvailabilityHeatmapState();
}

class _AppListingAvailabilityHeatmapState
    extends State<AppListingAvailabilityHeatmap> {
  static const _dowMedium = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  _HeatmapRange _range = _HeatmapRange.day;
  late DateTime _anchor = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  bool get _hasSchedule {
    if (widget.listing.isWeeklyAvailability) {
      return widget.weekly.isNotEmpty;
    }
    return widget.specific.isNotEmpty;
  }

  @override
  void didUpdateWidget(covariant AppListingAvailabilityHeatmap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listing.id != widget.listing.id) {
      _anchor = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
      _range = _HeatmapRange.day;
    }
  }

  DateTime get _dayOnly => DateTime(_anchor.year, _anchor.month, _anchor.day);

  DateTime _mondayOfWeekContaining(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  int _daysInMonth(int y, int m) => DateTime(y, m + 1, 0).day;

  void _shiftAnchor(int days) {
    setState(() {
      _anchor = _dayOnly.add(Duration(days: days));
    });
  }

  void _shiftMonth(int delta) {
    setState(() {
      final y = _anchor.year;
      final m = _anchor.month + delta;
      _anchor = DateTime(y, m, 1);
    });
  }

  List<AvailabilitySlotState> _hourlyFor(DateTime dayLocal) {
    final five = computeFiveMinuteSlotStates(
      dayLocal: dayLocal,
      listing: widget.listing,
      weekly: widget.weekly,
      specific: widget.specific,
      bookings: widget.bookings,
    );
    return aggregateFiveMinuteToHourly(five);
  }

  String get _navTitle {
    const mon = [
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
    const dow = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    switch (_range) {
      case _HeatmapRange.day:
        final d = _dayOnly;
        return '${dow[d.weekday - 1]}, ${mon[d.month - 1]} ${d.day}, ${d.year}';
      case _HeatmapRange.week:
        final monday = _mondayOfWeekContaining(_anchor);
        final sun = monday.add(const Duration(days: 6));
        if (monday.month == sun.month) {
          return '${mon[monday.month - 1]} ${monday.day}–${sun.day}, ${monday.year}';
        }
        return '${mon[monday.month - 1]} ${monday.day} – ${mon[sun.month - 1]} ${sun.day}, ${sun.year}';
      case _HeatmapRange.month:
        final d = _anchor;
        return '${mon[d.month - 1]} ${d.year}';
    }
  }

  void _navPrev() {
    if (_range == _HeatmapRange.day) {
      _shiftAnchor(-1);
    } else if (_range == _HeatmapRange.week) {
      _shiftAnchor(-7);
    } else {
      _shiftMonth(-1);
    }
  }

  void _navNext() {
    if (_range == _HeatmapRange.day) {
      _shiftAnchor(1);
    } else if (_range == _HeatmapRange.week) {
      _shiftAnchor(7);
    } else {
      _shiftMonth(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const SizedBox(
        height: 100,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (!_hasSchedule) {
      return Text(
        'No schedule on file yet. Check availability and pricing below.',
        style: AppTypography.caption,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSegmentControl<_HeatmapRange>(
          selected: _range,
          onChanged: (range) => setState(() => _range = range),
          options: const [
            AppSegmentOption(value: _HeatmapRange.day, label: 'Day'),
            AppSegmentOption(value: _HeatmapRange.week, label: 'Week'),
            AppSegmentOption(value: _HeatmapRange.month, label: 'Month'),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Material(
              color: AppColors.transparent,
              child: InkWell(
                onTap: _navPrev,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.chevron_left_rounded,
                    color: AppColors.iconGrey,
                    size: 22,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Text(
                _navTitle,
                textAlign: TextAlign.center,
                style: AppTypography.bodyStrong.copyWith(letterSpacing: -0.2),
              ),
            ),
            Material(
              color: AppColors.transparent,
              child: InkWell(
                onTap: _navNext,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.iconGrey,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _legendRow(),
        const SizedBox(height: AppSpacing.sm),
        switch (_range) {
          _HeatmapRange.day => _buildDayView(),
          _HeatmapRange.week => _buildWeekView(),
          _HeatmapRange.month => _buildMonthView(),
        },
      ],
    );
  }

  Widget _legendRow() {
    final cap = AppTypography.caption.copyWith(
      color: AppColors.textSecondary,
      fontSize: 11,
    );
    Widget swatch(Color c, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(
                color: AppColors.heatmapFrameStroke,
                width: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: cap),
        ],
      );
    }

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: [
        swatch(AppColors.primaryBlue, 'Open'),
        swatch(AppColors.heatmapBooked, 'Booked'),
        swatch(AppColors.heatmapHostClosed, 'Host closed'),
      ],
    );
  }

  // Time labels 0/6/12/18/24h so 6pm isn’t stuck at the far right
  Widget _timeAxisQuarters() {
    final style = AppTypography.caption.copyWith(
      color: AppColors.textSecondary,
      fontSize: 9,
      fontWeight: FontWeight.w500,
    );
    Widget tick(String label, TextAlign align) {
      return Expanded(
        child: Text(label, textAlign: align, maxLines: 1, style: style),
      );
    }

    return Row(
      children: [
        tick('12am', TextAlign.start),
        tick('6am', TextAlign.center),
        tick('12pm', TextAlign.center),
        tick('6pm', TextAlign.center),
        tick('12am', TextAlign.end),
      ],
    );
  }

  Widget _buildDayView() {
    final hourly = _hourlyFor(_dayOnly);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _timeAxisQuarters(),
        const SizedBox(height: 6),
        _HorizontalTimelineBar(segments: hourly, barHeight: 40),
      ],
    );
  }

  Widget _buildWeekView() {
    final monday = _mondayOfWeekContaining(_anchor);
    const labelW = 56.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: labelW),
          child: _timeAxisQuarters(),
        ),
        const SizedBox(height: 6),
        for (var i = 0; i < 7; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          Builder(
            builder: (context) {
              final day = monday.add(Duration(days: i));
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: labelW,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _dowMedium[i],
                          style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${day.month}/${day.day}',
                          style: AppTypography.caption.copyWith(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _HorizontalTimelineBar(
                      segments: _hourlyFor(day),
                      barHeight: 26,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildMonthView() {
    const headerH = 14.0;
    const gap = 4.0;
    const barH = 22.0;
    const cellExtent = headerH + gap + barH;

    final y = _anchor.year;
    final m = _anchor.month;
    final first = DateTime(y, m, 1);
    final leading = first.weekday - DateTime.monday;
    final dim = _daysInMonth(y, m);
    var total = leading + dim;
    while (total % 7 != 0) {
      total++;
    }

    return Column(
      children: [
        Row(
          children: [
            for (final label in _dowMedium)
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 5,
            crossAxisSpacing: 5,
            mainAxisExtent: cellExtent,
          ),
          itemCount: total,
          itemBuilder: (context, index) {
            final inMonth = index >= leading && index < leading + dim;
            final dayNum = inMonth ? index - leading + 1 : 0;
            final quad = inMonth
                ? aggregateHourlyToFourBlocks(
                    _hourlyFor(DateTime(y, m, dayNum)),
                  )
                : List<AvailabilitySlotState>.filled(
                    4,
                    AvailabilitySlotState.hostClosed,
                  );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: headerH,
                  child: Center(
                    child: Text(
                      inMonth ? '$dayNum' : '',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: gap),
                SizedBox(
                  height: barH,
                  child: _HorizontalTimelineBar(
                    segments: quad,
                    barHeight: barH,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _HorizontalTimelineBar extends StatelessWidget {
  const _HorizontalTimelineBar({required this.segments, this.barHeight});

  final List<AvailabilitySlotState> segments;
  final double? barHeight;

  @override
  Widget build(BuildContext context) {
    Widget stripes(double h) {
      return Row(
        children: List.generate(segments.length, (i) {
          return Expanded(
            child: Container(
              height: h,
              decoration: BoxDecoration(
                color: _heatmapSlotFill(segments[i]),
                border: Border(
                  right: i < segments.length - 1
                      ? const BorderSide(
                          color: AppColors.heatmapStripeDivider,
                          width: 1,
                        )
                      : BorderSide.none,
                ),
              ),
            ),
          );
        }),
      );
    }

    final framed = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.heatmapFrameStroke),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowWisp,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: barHeight != null
          ? SizedBox(height: barHeight, child: stripes(barHeight!))
          : LayoutBuilder(
              builder: (context, c) {
                final h = c.maxHeight.isFinite && c.maxHeight > 0
                    ? c.maxHeight
                    : 10.0;
                return SizedBox(height: h, child: stripes(h));
              },
            ),
    );
    return framed;
  }
}
