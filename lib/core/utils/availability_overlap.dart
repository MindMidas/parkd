import 'time_step_minutes.dart';

// overlap checks for host availability slots (matches DB trigger semantics: half-open intervals: '[start, end)' in time/DT)
abstract final class AvailabilityOverlap {
  static const weeklyCode = 'OVERLAP_AVAILABILITY_WEEKLY';
  static const specificCode = 'OVERLAP_AVAILABILITY_SPECIFIC';

  static const userMessageWeekly =
      'This time overlaps another slot on the same day. Change the times or remove a slot.';
  static const userMessageSpecific =
      'This period overlaps another scheduled slot. Use different dates or times.';

  // '[a0,a1)' vs '[b0,b1)' in mins from midnight (same calendar day)
  static bool intervalsOverlapHalfOpenMinutes(
    int a0,
    int a1,
    int b0,
    int b1,
  ) {
    return a0 < b1 && b0 < a1;
  }

  static bool dateTimeRangesOverlap(
    DateTime aStart,
    DateTime aEnd,
    DateTime bStart,
    DateTime bEnd,
  ) {
    return aStart.isBefore(bEnd) && bStart.isBefore(aEnd);
  }

  // parses '"9:15 AM - 1:00 PM"' (en dash, em dash, or hyphen) to mins; null if invalid
  static ({int startMin, int endMin})? tryParseAmPmTimeRange(String timeRange) {
    final normalized =
        timeRange.replaceAll(RegExp(r'[–—]'), '-').trim();
    final parts = normalized.split(RegExp(r'\s+-\s+'));
    if (parts.length != 2) return null;
    final a = TimeStepMinutes.tryParseMinutesFromAmPm(parts[0]);
    final b = TimeStepMinutes.tryParseMinutesFromAmPm(parts[1]);
    if (a == null || b == null || b <= a) return null;
    return (startMin: a, endMin: b);
  }

  static ({int startMin, int endMin})? weeklyRowToMinutes({
    required String startHhMm,
    required String endHhMm,
  }) {
    final a = TimeStepMinutes.tryParseMinutesFromHhMm(startHhMm);
    final b = TimeStepMinutes.tryParseMinutesFromHhMm(endHhMm);
    if (a == null || b == null || b <= a) return null;
    return (startMin: a, endMin: b);
  }

  // same listing and same day_of_week (0=Mon to 6=Sun)
  static bool weeklyAnyPairOverlaps(
    List<({int dayPg, int startMin, int endMin})> slots,
  ) {
    for (var i = 0; i < slots.length; i++) {
      for (var j = i + 1; j < slots.length; j++) {
        if (slots[i].dayPg != slots[j].dayPg) continue;
        if (intervalsOverlapHalfOpenMinutes(
          slots[i].startMin,
          slots[i].endMin,
          slots[j].startMin,
          slots[j].endMin,
        )) {
          return true;
        }
      }
    }
    return false;
  }

  static bool specificListHasOverlap(List<({DateTime start, DateTime end})> slots) {
    for (var i = 0; i < slots.length; i++) {
      for (var j = i + 1; j < slots.length; j++) {
        if (dateTimeRangesOverlap(
          slots[i].start,
          slots[i].end,
          slots[j].start,
          slots[j].end,
        )) {
          return true;
        }
      }
    }
    return false;
  }

  static bool specificNewOverlaps(
    DateTime start,
    DateTime end,
    List<({DateTime start, DateTime end})> existing,
  ) {
    for (final e in existing) {
      if (dateTimeRangesOverlap(start, end, e.start, e.end)) return true;
    }
    return false;
  }

  static String? messageForException(Object e) {
    final s = e.toString();
    if (s.contains(weeklyCode)) return userMessageWeekly;
    if (s.contains(specificCode)) return userMessageSpecific;
    return null;
  }
}
