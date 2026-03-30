import 'availability_specific.dart';
import 'availability_weekly.dart';

// computes display strings from slot-level hourly/daily prices
abstract final class SlotPricingSummary {
  // min hourly across all slots, or null if none
  static double? minHourly(
    List<AvailabilityWeekly> weekly,
    List<AvailabilitySpecific> specific,
  ) {
    double? m;
    for (final w in weekly) {
      final p = w.priceHour;
      if (m == null || p < m) m = p;
    }
    for (final s in specific) {
      final p = s.priceHour;
      if (m == null || p < m) m = p;
    }
    return m;
  }

  // min daily rate where set, or null if no slot has a daily price
  static double? minDailyWhereSet(
    List<AvailabilityWeekly> weekly,
    List<AvailabilitySpecific> specific,
  ) {
    double? m;
    for (final w in weekly) {
      final p = w.priceDay;
      if (p != null && (m == null || p < m)) m = p;
    }
    for (final s in specific) {
      final p = s.priceDay;
      if (p != null && (m == null || p < m)) m = p;
    }
    return m;
  }

  // compact money for UI, '\$8' or '\$8.50'
  static String moneyCompact(double v) {
    if (v <= 0) return '\$0';
    if (v == v.roundToDouble()) return '\$${v.round()}';
    return '\$${v.toStringAsFixed(2)}';
  }

  // slot label, 'Hourly $8/hr'
  static String hourlyRateCaption(double priceHour) =>
      'Hourly ${moneyCompact(priceHour)}/hr';

  // daily label, or null if unset
  static String? dailyRateCaption(double? priceDay) {
    if (priceDay == null || priceDay <= 0) return null;
    return 'Daily ${moneyCompact(priceDay)}/day';
  }

  // string (logs); hourlyRateCaption + dailyRateCaption in UI
  static String perSlotLine(double priceHour, double? priceDay) {
    final h = hourlyRateCaption(priceHour);
    final d = dailyRateCaption(priceDay);
    return d == null ? h : '$h · $d';
  }

  // line summary for listing cards ("$10/hr · $30/day", or dash placeholder)
  static String label(
    List<AvailabilityWeekly> weekly,
    List<AvailabilitySpecific> specific,
  ) {
    final minH = minHourly(weekly, specific);
    if (minH == null) return '—';
    final hr = '\$${minH.toStringAsFixed(0)}/hr';
    final minD = minDailyWhereSet(weekly, specific);
    if (minD != null) return '$hr · \$${minD.toStringAsFixed(0)}/day';
    return hr;
  }
}
