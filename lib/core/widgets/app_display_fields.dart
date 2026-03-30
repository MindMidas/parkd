import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/slot_pricing_summary.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/display_formatting.dart';

// Bordered white card with md padding
class AppDisplayOutlineCard extends StatelessWidget {
  const AppDisplayOutlineCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.secondaryGrey.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowWisp,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: child,
      ),
    );
  }
}

class AppDisplayTitledOutlineCard extends StatelessWidget {
  const AppDisplayTitledOutlineCard({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Stack(
        fit: StackFit.passthrough,
        clipBehavior: Clip.none,
        children: [
          AppDisplayOutlineCard(child: child),
          Positioned(
            top: -AppSpacing.xs,
            left: AppSpacing.lg,
            child: DecoratedBox(
              decoration: const BoxDecoration(color: AppColors.surface),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Text(title, style: AppTypography.caption),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// From / To columns; pairs with outline card or duration block
class AppDateTimeRangeColumns extends StatelessWidget {
  const AppDateTimeRangeColumns({
    super.key,
    required this.fromDate,
    required this.toDate,
    this.fromTime = '',
    this.toTime = '',
    this.fromLabel = 'From',
    this.toLabel = 'To',
  });

  final String fromDate;
  final String toDate;
  final String fromTime;
  final String toTime;
  final String fromLabel;
  final String toLabel;

  factory AppDateTimeRangeColumns.fromCombined({
    required String fromValue,
    required String toValue,
    String fromLabel = 'From',
    String toLabel = 'To',
  }) {
    final f = splitDisplayDateTime(fromValue);
    final t = splitDisplayDateTime(toValue);
    return AppDateTimeRangeColumns(
      fromDate: f.$1,
      fromTime: f.$2,
      toDate: t.$1,
      toTime: t.$2,
      fromLabel: fromLabel,
      toLabel: toLabel,
    );
  }

  factory AppDateTimeRangeColumns.fromDateTimes({
    required DateTime start,
    required DateTime end,
    String fromLabel = 'From',
    String toLabel = 'To',
  }) {
    final df = DateFormat('MMM d, y');
    final tf = DateFormat('h:mm a');
    return AppDateTimeRangeColumns(
      fromDate: df.format(start),
      fromTime: tf.format(start),
      toDate: df.format(end),
      toTime: tf.format(end),
      fromLabel: fromLabel,
      toLabel: toLabel,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _ColumnBlock(label: fromLabel, date: fromDate, time: fromTime),
        ),
        SizedBox(width: AppSpacing.lg),
        Expanded(
          child: _ColumnBlock(label: toLabel, date: toDate, time: toTime),
        ),
      ],
    );
  }
}

class _ColumnBlock extends StatelessWidget {
  const _ColumnBlock({
    required this.label,
    required this.date,
    required this.time,
  });

  final String label;
  final String date;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.caption),
        SizedBox(height: AppSpacing.xxs),
        Text(date, style: AppTypography.body),
        if (time.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(time, style: AppTypography.body),
        ],
      ],
    );
  }
}

class AppAvailabilityWeeklySlotBlock extends StatelessWidget {
  const AppAvailabilityWeeklySlotBlock({
    super.key,
    required this.day,
    required this.timeRange,
    required this.priceHour,
    this.priceDay,
  });

  final String day;
  final String timeRange;
  final double priceHour;
  final double? priceDay;

  @override
  Widget build(BuildContext context) {
    final captionBlue =
        AppTypography.caption.copyWith(color: AppColors.primaryBlue);
    final daily = SlotPricingSummary.dailyRateCaption(priceDay);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(day, style: AppTypography.bodyStrong),
            Text(
              timeRange,
              style: AppTypography.body,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            Text(
              SlotPricingSummary.hourlyRateCaption(priceHour),
              style: captionBlue,
            ),
            if (daily != null) Text(daily, style: captionBlue),
          ],
        ),
      ],
    );
  }
}

class AppAvailabilityDateRangeSlotBlock extends StatelessWidget {
  static const double _labelColumnWidth = 44;

  const AppAvailabilityDateRangeSlotBlock({
    super.key,
    required this.fromDate,
    required this.fromTime,
    required this.toDate,
    required this.toTime,
    required this.priceHour,
    this.priceDay,
  });

  final String fromDate;
  final String fromTime;
  final String toDate;
  final String toTime;
  final double priceHour;
  final double? priceDay;

  // from/to strings with * or between date and time
  factory AppAvailabilityDateRangeSlotBlock.fromSlotStrings({
    required String from,
    required String to,
    required double priceHour,
    double? priceDay,
  }) {
    final f = splitDisplayDateTime(from);
    final t = splitDisplayDateTime(to);
    return AppAvailabilityDateRangeSlotBlock(
      fromDate: f.$1,
      fromTime: f.$2,
      toDate: t.$1,
      toTime: t.$2,
      priceHour: priceHour,
      priceDay: priceDay,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fromSide =
        fromTime.isNotEmpty ? '$fromDate, $fromTime' : fromDate;
    final toSide = toTime.isNotEmpty ? '$toDate, $toTime' : toDate;
    final captionBlue =
        AppTypography.caption.copyWith(color: AppColors.primaryBlue);
    final daily = SlotPricingSummary.dailyRateCaption(priceDay);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _labelColumnWidth,
              child: Text('From', style: AppTypography.bodyStrong),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(fromSide, style: AppTypography.body),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _labelColumnWidth,
              child: Text('To', style: AppTypography.bodyStrong),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(toSide, style: AppTypography.body),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            Text(
              SlotPricingSummary.hourlyRateCaption(priceHour),
              style: captionBlue,
            ),
            if (daily != null) Text(daily, style: captionBlue),
          ],
        ),
      ],
    );
  }
}

// Total time + time left row (only used inside duration block)
class _DetailTimingColumns extends StatelessWidget {
  const _DetailTimingColumns({
    super.key,
    required this.leftLabel,
    required this.leftValue,
    required this.rightLabel,
    required this.rightValue,
  });

  final String leftLabel;
  final String leftValue;
  final String rightLabel;
  final String rightValue;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _TimingColumn(label: leftLabel, value: leftValue),
        ),
        SizedBox(width: AppSpacing.lg),
        Expanded(
          child: _TimingColumn(label: rightLabel, value: rightValue),
        ),
      ],
    );
  }
}

// Booking/checkout from-to + divider + duration + optional animated time left
class AppDetailDurationTimingBlock extends StatelessWidget {
  const AppDetailDurationTimingBlock({
    super.key,
    required this.fromValue,
    required this.toValue,
    required this.totalTimeLabel,
    this.timeLeftLabel,
    this.fromLabel = 'From',
    this.toLabel = 'To',
    this.animatedKey,
    this.animate = true,
  });

  final String fromValue;
  final String toValue;
  final String totalTimeLabel;

  final String? timeLeftLabel;
  final String fromLabel;
  final String toLabel;
  final Key? animatedKey;
  final bool animate;

  factory AppDetailDurationTimingBlock.fromDateTimes({
    Key? key,
    required DateTime start,
    required DateTime end,
    required String totalTimeLabel,
    String? timeLeftLabel,
    bool animate = true,
    Key? animatedKey,
    String fromLabel = 'From',
    String toLabel = 'To',
  }) {
    final df = DateFormat('MMM d, y');
    final tf = DateFormat('h:mm a');
    const sep = ' · ';
    return AppDetailDurationTimingBlock(
      key: key,
      fromValue: '${df.format(start)}$sep${tf.format(start)}',
      toValue: '${df.format(end)}$sep${tf.format(end)}',
      totalTimeLabel: totalTimeLabel,
      timeLeftLabel: timeLeftLabel,
      fromLabel: fromLabel,
      toLabel: toLabel,
      animatedKey: animatedKey,
      animate: animate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final showTimeLeft =
        timeLeftLabel != null && timeLeftLabel!.trim().isNotEmpty;

    final Widget timing = showTimeLeft
        ? _DetailTimingColumns(
            key: animatedKey,
            leftLabel: 'Total time',
            leftValue: totalTimeLabel,
            rightLabel: 'Time left',
            rightValue: timeLeftLabel!.trim(),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total time', style: AppTypography.caption),
              SizedBox(height: AppSpacing.xxs),
              Text(totalTimeLabel, style: AppTypography.body),
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppDateTimeRangeColumns.fromCombined(
          fromLabel: fromLabel,
          fromValue: fromValue,
          toLabel: toLabel,
          toValue: toValue,
        ),
        const SizedBox(height: AppSpacing.sm),
        Divider(height: 1, thickness: 0.5, color: AppColors.secondaryGrey),
        const SizedBox(height: AppSpacing.sm),
        if (animate && showTimeLeft)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: timing,
          )
        else
          timing,
      ],
    );
  }
}

class AppDetailAmountRow extends StatelessWidget {
  const AppDetailAmountRow({
    super.key,
    required this.label,
    required this.amount,
    this.moneyStyle = AppMoneyStyle.bodyStrong,
    this.moneyColor,
  });

  final String label;
  final double amount;
  final AppMoneyStyle moneyStyle;
  final Color? moneyColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: AppMoneyText(amount, style: moneyStyle, color: moneyColor),
          ),
        ),
      ],
    );
  }
}

class _TimingColumn extends StatelessWidget {
  const _TimingColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.caption),
        SizedBox(height: AppSpacing.xxs),
        Text(
          value,
          style: AppTypography.body,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

enum AppStreetAddressDensity {
  section,
  sheetHeader, 
  listRow,
}

class AppStreetAddressBlock extends StatelessWidget {
  const AppStreetAddressBlock({
    super.key,
    required this.streetLine,
    this.secondaryLine,
    this.tertiaryLine,
    this.density = AppStreetAddressDensity.section,
    this.usePrimaryColorForSecondaryLines = false,
  });

  final String streetLine;
  final String? secondaryLine;
  final String? tertiaryLine;
  final AppStreetAddressDensity density;
  final bool usePrimaryColorForSecondaryLines;

  TextStyle get _streetStyle => switch (density) {
    AppStreetAddressDensity.section ||
    AppStreetAddressDensity.listRow => AppTypography.bodyStrong,
    AppStreetAddressDensity.sheetHeader => AppTypography.navTitle,
  };

  TextStyle get _secondaryStyle => switch (density) {
    AppStreetAddressDensity.section => AppTypography.bodyMuted,
    AppStreetAddressDensity.sheetHeader ||
    AppStreetAddressDensity.listRow => AppTypography.caption,
  };

  TextStyle get _effectiveSecondaryStyle => usePrimaryColorForSecondaryLines
      ? _secondaryStyle.copyWith(color: AppColors.textPrimary)
      : _secondaryStyle;

  double get _afterStreetGap => switch (density) {
    AppStreetAddressDensity.sheetHeader => 2,
    _ => AppSpacing.xs,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(streetLine, style: _streetStyle),
        if (secondaryLine != null && secondaryLine!.isNotEmpty) ...[
          SizedBox(height: _afterStreetGap),
          Text(secondaryLine!, style: _effectiveSecondaryStyle),
        ],
        if (tertiaryLine != null && tertiaryLine!.isNotEmpty) ...[
          SizedBox(height: _afterStreetGap),
          Text(tertiaryLine!, style: _effectiveSecondaryStyle),
        ],
      ],
    );
  }
}

class AppStreetAddressCard extends StatelessWidget {
  const AppStreetAddressCard({
    super.key,
    required this.streetLine,
    this.localityLine,
    this.spotLine,
    this.density = AppStreetAddressDensity.section,
    this.title,
    this.footer,
    this.usePrimaryColorForSecondaryLines = false,
  });

  final String streetLine;
  final String? localityLine;
  final String? spotLine;
  final AppStreetAddressDensity density;
  final String? title;
  final Widget? footer;
  final bool usePrimaryColorForSecondaryLines;

  @override
  Widget build(BuildContext context) {
    final trimmedTitle = title?.trim();
    final hasTitle = trimmedTitle != null && trimmedTitle.isNotEmpty;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppStreetAddressBlock(
          density: density,
          usePrimaryColorForSecondaryLines: usePrimaryColorForSecondaryLines,
          streetLine: streetLine,
          secondaryLine: localityLine != null && localityLine!.isNotEmpty
              ? localityLine
              : null,
          tertiaryLine: spotLine != null && spotLine!.isNotEmpty
              ? spotLine
              : null,
        ),
        if (footer != null) ...[const SizedBox(height: AppSpacing.sm), footer!],
      ],
    );

    if (!hasTitle) {
      return AppDisplayOutlineCard(child: content);
    }

    return AppDisplayTitledOutlineCard(title: trimmedTitle, child: content);
  }
}

enum AppMoneyStyle { body, bodyStrong, numericStrong }

class AppMoneyText extends StatelessWidget {
  const AppMoneyText(
    this.amount, {
    super.key,
    this.prefix = '',
    this.style = AppMoneyStyle.body,
    this.color,
  });

  final double amount;
  final String prefix;
  final AppMoneyStyle style;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final text = '$prefix${formatUsdAmount(amount)}';
    final textStyle = switch (style) {
      AppMoneyStyle.body => AppTypography.body,
      AppMoneyStyle.bodyStrong => AppTypography.bodyStrong,
      AppMoneyStyle.numericStrong => AppTypography.numericStrong,
    };
    final effective = color != null
        ? textStyle.copyWith(color: color)
        : textStyle;
    return Text(text, style: effective);
  }
}

class AppPriceBreakdownBlock extends StatelessWidget {
  const AppPriceBreakdownBlock({
    super.key,
    required this.subtotal,
    required this.serviceFee,
    required this.total,
  });

  final double subtotal;
  final double serviceFee;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppDetailAmountRow(
          label: 'Subtotal',
          amount: subtotal,
          moneyStyle: AppMoneyStyle.body,
        ),
        SizedBox(height: AppSpacing.sm),
        AppDetailAmountRow(
          label: 'Service fee (added)',
          amount: serviceFee,
          moneyStyle: AppMoneyStyle.body,
        ),
        SizedBox(height: AppSpacing.sm),
        AppDetailAmountRow(
          label: 'Total',
          amount: total,
          moneyStyle: AppMoneyStyle.numericStrong,
          moneyColor: AppColors.success,
        ),
      ],
    );
  }
}

class AppCheckoutPriceBreakdownCard extends StatelessWidget {
  const AppCheckoutPriceBreakdownCard({
    super.key,
    required this.subtotal,
    required this.serviceFee,
    required this.total,
    this.title = 'Price breakdown',
  });

  final double subtotal;
  final double serviceFee;
  final double total;
  final String title;

  @override
  Widget build(BuildContext context) {
    return AppDisplayTitledOutlineCard(
      title: title,
      child: AppPriceBreakdownBlock(
        subtotal: subtotal,
        serviceFee: serviceFee,
        total: total,
      ),
    );
  }
}

class AppReservationTotalLine extends StatelessWidget {
  const AppReservationTotalLine({
    super.key,
    required this.priceText,
    required this.durationLabel,
  });

  final String priceText;
  final String durationLabel;

  static final _priceStyle =
      AppTypography.bodyStrong.copyWith(color: AppColors.success);

  @override
  Widget build(BuildContext context) {
    final d = durationLabel.trim();
    if (d.isEmpty) {
      return Text(priceText, style: _priceStyle);
    }
    return Text.rich(
      TextSpan(
        style: AppTypography.body,
        children: [
          TextSpan(text: priceText, style: _priceStyle),
          const TextSpan(text: ' for '),
          TextSpan(text: d),
        ],
      ),
    );
  }
}

// Scrim pill with icon + label (photo edit chip, expand hero, etc)
class AppScrimIconLabelPill extends StatelessWidget {
  const AppScrimIconLabelPill({
    super.key,
    required this.icon,
    required this.label,
    this.scrimColor = AppColors.scrimStrong,
  });

  final IconData icon;
  final String label;
  final Color scrimColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scrimColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.onPrimary),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.captionStrong.copyWith(
                color: AppColors.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
