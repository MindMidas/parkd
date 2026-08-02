import 'dart:math' as math;

// Parkd reservation subtotal rules:
abstract final class ReservationPricing {
  static const int minBillableMinutes = 10;
  static const int minutesPerDay = 24 * 60;

  static double serviceFeeForSubtotal(double subtotal) =>
      (subtotal * 0.035 * 100).round() / 100;

  // Rounds to cents
  static double roundMoney(double v) => (v * 100).round() / 100;

  // rawMinutes = `end.difference(start).inMinutes` (truncated; sub-10m still bills as 10m)
  static double computeSubtotal({
    required int rawMinutes,
    required double hourlyRate,
    required double dailyRate,
  }) {
    if (rawMinutes <= 0 || hourlyRate < 0) return 0;
    final m = rawMinutes < minBillableMinutes ? minBillableMinutes : rawMinutes;
    final hourly = _hourlyStyleTotalMinutes(m, hourlyRate);
    if (m > minutesPerDay && dailyRate > 0) {
      final daily = _dailyBlockPlusRemainder(m, dailyRate, hourlyRate);
      return roundMoney(math.min(hourly, daily));
    }
    return roundMoney(hourly);
  }

  static double _hourlyStyleTotalMinutes(int minutes, double hourly) {
    if (minutes <= 0) return 0;
    if (minutes < 60) {
      final m = math.max(minBillableMinutes, minutes);
      final units = _ceilTenMinuteUnits(m);
      return units * hourly / 6.0;
    }
    final h = minutes ~/ 60;
    var rem = minutes % 60;
    if (rem > 0 && rem < minBillableMinutes) rem = minBillableMinutes;
    final tail = rem == 0 ? 0.0 : _hourlyStyleTotalMinutes(rem, hourly);
    return h * hourly + tail;
  }

  static int _ceilTenMinuteUnits(int minutes) {
    if (minutes <= 0) return 0;
    return (minutes + 9) ~/ 10;
  }

  static double _dailyBlockPlusRemainder(
    int minutes,
    double daily,
    double hourly,
  ) {
    final days = minutes ~/ minutesPerDay;
    var rem = minutes % minutesPerDay;
    if (rem > 0 && rem < minBillableMinutes) {
      rem = minBillableMinutes;
    }
    final remCost = rem == 0 ? 0.0 : _hourlyStyleTotalMinutes(rem, hourly);
    return days * daily + remCost;
  }

  // Human-readable duration (calendar-agnostic; uses total minutes)
  static String formatDurationLabel(int totalMinutes) {
    if (totalMinutes <= 0) return '';
    final days = totalMinutes ~/ minutesPerDay;
    var rem = totalMinutes % minutesPerDay;
    final hours = rem ~/ 60;
    final mins = rem % 60;
    final parts = <String>[];
    if (days > 0) parts.add('$days day${days == 1 ? '' : 's'}');
    if (hours > 0) parts.add('$hours hour${hours == 1 ? '' : 's'}');
    if (mins > 0 && days == 0) {
      parts.add('$mins min${mins == 1 ? '' : 's'}');
    }
    return parts.join(' and ');
  }
}
