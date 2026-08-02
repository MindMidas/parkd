import 'availability_specific.dart';
import 'availability_weekly.dart';

// Computes display strings from slot-level hourly/daily prices
abstract final class SlotPricingSummary {
  // Minimum hourly across all slots, or null if none
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

  // Minimum daily rate where set, or null if no slot has a daily price
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

  // Compact money for UI, e.g. `\$8` or `\$8.50`
  static String moneyCompact(double v) {
    if (v <= 0) return '\$0';
    if (v == v.roundToDouble()) return '\$${v.round()}';
    return '\$${v.toStringAsFixed(2)}';
  }

  // Readable slot label, e.g. `Hourly $8/hr`
  static String hourlyRateCaption(double priceHour) =>
      'Hourly ${moneyCompact(priceHour)}/hr';

  // Readable daily label, or null if unset
  static String? dailyRateCaption(double? priceDay) {
    if (priceDay == null || priceDay <= 0) return null;
    return 'Daily ${moneyCompact(priceDay)}/day';
  }

  // Legacy single string (e.g. logs); prefer hourlyRateCaption + dailyRateCaption in UI
  static String perSlotLine(double priceHour, double? priceDay) {
    final h = hourlyRateCaption(priceHour);
    final d = dailyRateCaption(priceDay);
    return d == null ? h : '$h · $d';
  }

  // One-line summary for listing cards (e.g. "\$10/hr • \$30/day", or "—")
  static String label(
    List<AvailabilityWeekly> weekly,
    List<AvailabilitySpecific> specific,
  ) {
    final minH = minHourly(weekly, specific);
    if (minH == null) return '—';
    final hr = '\$${minH.toStringAsFixed(0)}/hr';
    final minD = minDailyWhereSet(weekly, specific);
    if (minD != null) return '$hr • \$${minD.toStringAsFixed(0)}/day';
    return hr;
  }
}
