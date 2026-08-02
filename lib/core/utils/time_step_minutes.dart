// 5-minute grid for availability steppers (0 = midnight … 23:55)
abstract final class TimeStepMinutes {
  static const step = 5;
  static const maxMinutes = 24 * 60 - step; // 23:55

  static String formatAmPm(int totalMinutes) {
    final clamped = totalMinutes.clamp(0, maxMinutes);
    final h24 = clamped ~/ 60;
    final m = clamped % 60;
    final period = h24 >= 12 ? 'PM' : 'AM';
    var h12 = h24 % 12;
    if (h12 == 0) h12 = 12;
    final mm = m.toString().padLeft(2, '0');
    return '$h12:$mm $period';
  }

  static int addSteps(int current, int steps) {
    final next = current + steps * step;
    return next.clamp(0, maxMinutes);
  }

  // Parses `"HH:mm"` or `"HH:mm:ss"` (24h) to minutes from midnight
  static int? tryParseMinutesFromHhMm(String input) {
    final t = input.trim();
    if (t.isEmpty) return null;
    final head = t.length >= 5 ? t.substring(0, 5) : t;
    final parts = head.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;
    return h * 60 + m;
  }

  // Parses `"9:15 AM"` / `"3:00 PM"` (flexible spacing) to minutes from midnight
  static int? tryParseMinutesFromAmPm(String input) {
    final re = RegExp(
      r'^\s*(\d{1,2}):(\d{2})\s*(AM|PM)\s*$',
      caseSensitive: false,
    );
    final m = re.firstMatch(input.trim());
    if (m == null) return null;
    var h = int.tryParse(m.group(1)!);
    final min = int.tryParse(m.group(2)!);
    final ap = m.group(3)!.toUpperCase();
    if (h == null || min == null) return null;
    if (min < 0 || min > 59 || h < 1 || h > 12) return null;
    if (ap == 'PM' && h != 12) h += 12;
    if (ap == 'AM' && h == 12) h = 0;
    return h * 60 + min;
  }

  // If stored is already `"h:mm AM/PM"`, returns it; if `"HH:mm"` from DB, formats AM/PM
  static String formatHhMmOrAmPmToDisplay(String stored) {
    final t = stored.trim();
    final u = t.toUpperCase();
    if (u.contains('AM') || u.contains('PM')) return t;
    final mins = tryParseMinutesFromHhMm(t);
    if (mins == null) return stored;
    return formatAmPm(mins);
  }

  // `"09:15"` style for Postgres `time` / API payloads
  static String minutesToHhMm(int totalMinutes) {
    final clamped = totalMinutes.clamp(0, 23 * 60 + 59);
    final h = clamped ~/ 60;
    final m = clamped % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}
