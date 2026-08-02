import '../models/availability_specific.dart';
import '../models/availability_weekly.dart';
import '../models/booking_time_window.dart';
import '../models/listing.dart';
import '../utils/time_step_minutes.dart';

// Preset parking durations for the map listing preview (minutes)
const List<int> kMapPreviewDurationPresetsMinutes = [15, 30, 60, 120, 300];

String formatMapPreviewDurationLabel(int minutes) {
  if (minutes < 60) return '${minutes}m';
  if (minutes % 60 == 0) {
    final h = minutes ~/ 60;
    return h == 1 ? '1 hr' : '$h hr';
  }
  return '${minutes ~/ 60}h ${minutes % 60}m';
}

DateTime _dateOnlyLocal(DateTime t) => DateTime(t.year, t.month, t.day);

// Postgres `day_of_week`: 0 = Sunday … 6 = Saturday → Dart DateTime.weekday
int _pgDayToDartWeekday(int pg) {
  final p = pg < 0 ? 0 : (pg > 6 ? 6 : pg);
  return p == 0 ? DateTime.sunday : p;
}

List<BookingTimeWindow> mergeBookingWindows(List<BookingTimeWindow> raw) {
  if (raw.isEmpty) return [];
  final sorted = [...raw]..sort((a, b) => a.start.compareTo(b.start));
  final out = <BookingTimeWindow>[];
  var cur = sorted.first;
  for (var i = 1; i < sorted.length; i++) {
    final n = sorted[i];
    if (n.start.isBefore(cur.end)) {
      final end = n.end.isAfter(cur.end) ? n.end : cur.end;
      cur = BookingTimeWindow(start: cur.start, end: end);
    } else {
      out.add(cur);
      cur = n;
    }
  }
  out.add(cur);
  return out;
}

bool _intervalBlocked(
  DateTime start,
  DateTime end,
  List<BookingTimeWindow> merged,
) {
  for (final b in merged) {
    if (start.isBefore(b.end) && end.isAfter(b.start)) return true;
  }
  return false;
}

DateTime _alignStartUpToGrid(DateTime t, int gridMinutes) {
  final base = _dateOnlyLocal(t);
  final dayMinutes = t.difference(base).inMinutes;
  var need = dayMinutes;
  if (t.second > 0 || t.millisecond > 0 || t.microsecond > 0) need += 1;
  final rem = need % gridMinutes;
  final aligned = rem == 0 ? need : need + (gridMinutes - rem);
  return base.add(Duration(minutes: aligned));
}

DateTime? findSoonestAvailableStart({
  required DateTime now,
  required int desiredDurationMinutes,
  required Listing listing,
  required List<AvailabilityWeekly> weekly,
  required List<AvailabilitySpecific> specific,
  required List<BookingTimeWindow> bookings,
  int horizonDays = 14,
  int gridMinutes = TimeStepMinutes.step,
}) {
  if (desiredDurationMinutes <= 0) return null;
  final nowLocal = now.toLocal();
  final rangeEndInstant = nowLocal.add(Duration(days: horizonDays));

  final windows = <({DateTime start, DateTime end})>[];

  if (listing.isWeeklyAvailability && weekly.isNotEmpty) {
    final startDay = _dateOnlyLocal(nowLocal);
    for (var i = 0; i < horizonDays; i++) {
      final d = startDay.add(Duration(days: i));
      final dartDow = d.weekday;
      for (final w in weekly) {
        if (_pgDayToDartWeekday(w.dayOfWeek) != dartDow) continue;
        final sm = TimeStepMinutes.tryParseMinutesFromHhMm(w.startTime);
        final em = TimeStepMinutes.tryParseMinutesFromHhMm(w.endTime);
        if (sm == null || em == null || em <= sm) continue;
        final winStart = d.add(Duration(minutes: sm));
        final winEnd = d.add(Duration(minutes: em));
        if (!winEnd.isAfter(winStart)) continue;
        windows.add((start: winStart, end: winEnd));
      }
    }
  } else if (specific.isNotEmpty) {
    for (final s in specific) {
      var a = s.startDatetime.toLocal();
      var b = s.endDatetime.toLocal();
      if (!b.isAfter(a)) continue;
      if (!b.isAfter(nowLocal)) continue;
      if (a.isAfter(rangeEndInstant)) continue;
      if (a.isBefore(nowLocal)) a = nowLocal;
      if (b.isAfter(rangeEndInstant)) b = rangeEndInstant;
      if (!b.isAfter(a)) continue;
      windows.add((start: a, end: b));
    }
  }

  if (windows.isEmpty) return null;

  windows.sort((u, v) => u.start.compareTo(v.start));
  final merged = mergeBookingWindows(bookings);
  final need = Duration(minutes: desiredDurationMinutes);

  for (final w in windows) {
    var t = _alignStartUpToGrid(
      w.start.isAfter(nowLocal) ? w.start : nowLocal,
      gridMinutes,
    );
    if (t.isBefore(w.start)) t = _alignStartUpToGrid(w.start, gridMinutes);
    while (true) {
      final endT = t.add(need);
      if (endT.isAfter(w.end)) break;
      if (!_intervalBlocked(t, endT, merged)) return t;
      t = t.add(Duration(minutes: gridMinutes));
    }
  }
  return null;
}

// True when a specific window still ends after [now] (any remaining date range).
bool listingHasFutureSpecificWindow(
  List<AvailabilitySpecific> specific, {
  required DateTime now,
}) {
  final nowLocal = now.toLocal();
  for (final s in specific) {
    if (s.endDatetime.toLocal().isAfter(nowLocal)) return true;
  }
  return false;
}

// Host manage list: date-specific listing whose windows have all ended.
bool listingIsExpiredSpecific(
  Listing listing, {
  DateTime? now,
}) {
  if (!listing.isSpecificAvailability) return false;
  return !listingHasFutureSpecificWindow(
    listing.publicSpecificAvailability,
    now: now ?? DateTime.now(),
  );
}

int specificAvailabilityHorizonDays(
  List<AvailabilitySpecific> specific, {
  required DateTime now,
}) {
  final nowLocal = now.toLocal();
  DateTime? maxEnd;
  for (final s in specific) {
    final end = s.endDatetime.toLocal();
    if (!end.isAfter(nowLocal)) continue;
    if (maxEnd == null || end.isAfter(maxEnd)) maxEnd = end;
  }
  if (maxEnd == null) return 0;
  final days = maxEnd.difference(nowLocal).inDays + 2;
  if (days < 1) return 1;
  if (days > 400) return 400;
  return days;
}

// Map discovery: weekly stays while published; specific needs a future window
// with at least one free slot of [minDurationMinutes] (bookings can hide/reopen).
bool listingHasDiscoverableAvailability({
  required Listing listing,
  required DateTime now,
  required List<BookingTimeWindow> bookings,
  int minDurationMinutes = 15,
}) {
  if (listing.isWeeklyAvailability) {
    return listing.publicWeeklyAvailability.isNotEmpty;
  }
  if (!listing.isSpecificAvailability) return false;
  final specific = listing.publicSpecificAvailability;
  if (!listingHasFutureSpecificWindow(specific, now: now)) return false;
  final horizon = specificAvailabilityHorizonDays(specific, now: now);
  if (horizon <= 0) return false;
  return findSoonestAvailableStart(
        now: now,
        desiredDurationMinutes: minDurationMinutes,
        listing: listing,
        weekly: const [],
        specific: specific,
        bookings: bookings,
        horizonDays: horizon,
      ) !=
      null;
}

// Single-line summary for the map preview, e.g. `Mon, Mar 31 · 9:15 AM – 10:15 AM`
String formatNextAvailableSlotLine(DateTime start, int durationMinutes) {
  final end = start.add(Duration(minutes: durationMinutes));
  const dow = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
  final head =
      '${dow[start.weekday - 1]}, ${mon[start.month - 1]} ${start.day}';
  final sh = start.hour * 60 + start.minute;
  final eh = end.hour * 60 + end.minute;
  if (_dateOnlyLocal(start) == _dateOnlyLocal(end)) {
    return '$head · ${TimeStepMinutes.formatAmPm(sh)} – ${TimeStepMinutes.formatAmPm(eh)}';
  }
  final tail =
      '${dow[end.weekday - 1]}, ${mon[end.month - 1]} ${end.day} · ${TimeStepMinutes.formatAmPm(eh)}';
  return '$head · ${TimeStepMinutes.formatAmPm(sh)} → $tail';
}
