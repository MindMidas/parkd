import '../models/availability_specific.dart';
import '../models/availability_weekly.dart';
import '../models/booking_time_window.dart';
import '../models/listing.dart';
import '../utils/time_step_minutes.dart';
import 'listing_next_available.dart' show mergeBookingWindows;

// 5min slots per day (24x12 steps)
const int kHeatmapSlotsPerDay = (24 * 60) ~/ TimeStepMinutes.step;

// closed outside host hours, open bookable, booked by confirmed+active (pending doesn't block)
enum AvailabilitySlotState {
  hostClosed,
  open,
  booked,
}

// host allowed window in local time
class OpenInterval {
  const OpenInterval({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

List<OpenInterval> _mergeOpenIntervals(List<OpenInterval> raw) {
  if (raw.isEmpty) return [];
  final sorted = [...raw]..sort((a, b) => a.start.compareTo(b.start));
  final out = <OpenInterval>[];
  var cur = sorted.first;
  for (var i = 1; i < sorted.length; i++) {
    final n = sorted[i];
    if (!n.start.isAfter(cur.end)) {
      final end = n.end.isAfter(cur.end) ? n.end : cur.end;
      cur = OpenInterval(start: cur.start, end: end);
    } else {
      out.add(cur);
      cur = n;
    }
  }
  out.add(cur);
  return out;
}

// host open intervals for day (local)
List<OpenInterval> hostOpenIntervalsForDay(
  DateTime dayLocal,
  Listing listing,
  List<AvailabilityWeekly> weekly,
  List<AvailabilitySpecific> specific,
) {
  final dayStart = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
  final dayEnd = dayStart.add(const Duration(days: 1));
  final raw = <OpenInterval>[];

  if (listing.isWeeklyAvailability && weekly.isNotEmpty) {
    final dartDow = dayStart.weekday;
    for (final w in weekly) {
      if (AvailabilityWeekly.toDartWeekday(w.dayOfWeek) != dartDow) continue;
      final sm = TimeStepMinutes.tryParseMinutesFromHhMm(w.startTime);
      final em = TimeStepMinutes.tryParseMinutesFromHhMm(w.endTime);
      if (sm == null || em == null || em <= sm) continue;
      raw.add(
        OpenInterval(
          start: dayStart.add(Duration(minutes: sm)),
          end: dayStart.add(Duration(minutes: em)),
        ),
      );
    }
  } else if (specific.isNotEmpty) {
    for (final s in specific) {
      var a = s.startDatetime.toLocal();
      var b = s.endDatetime.toLocal();
      if (!b.isAfter(a)) continue;
      if (!b.isAfter(dayStart)) continue;
      if (!a.isBefore(dayEnd)) continue;
      if (a.isBefore(dayStart)) a = dayStart;
      if (b.isAfter(dayEnd)) b = dayEnd;
      if (b.isAfter(a)) raw.add(OpenInterval(start: a, end: b));
    }
  }

  return _mergeOpenIntervals(raw);
}

List<BookingTimeWindow> _bookingsForDay(
  DateTime dayLocal,
  List<BookingTimeWindow> bookings,
) {
  final dayStart = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
  final dayEnd = dayStart.add(const Duration(days: 1));
  final clipped = <BookingTimeWindow>[];
  for (final b in bookings) {
    if (!b.end.isAfter(dayStart) || !b.start.isBefore(dayEnd)) continue;
    var bs = b.start.isBefore(dayStart) ? dayStart : b.start;
    var be = b.end.isAfter(dayEnd) ? dayEnd : b.end;
    if (be.isAfter(bs)) clipped.add(BookingTimeWindow(start: bs, end: be));
  }
  return clipped;
}

// 5min grid: hostClosed vs open vs booked
List<AvailabilitySlotState> computeFiveMinuteSlotStates({
  required DateTime dayLocal,
  required Listing listing,
  required List<AvailabilityWeekly> weekly,
  required List<AvailabilitySpecific> specific,
  required List<BookingTimeWindow> bookings,
}) {
  final dayStart = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
  final host = hostOpenIntervalsForDay(dayLocal, listing, weekly, specific);
  final dayBookings = _bookingsForDay(dayLocal, bookings);
  final bookedMerged = mergeBookingWindows(dayBookings);

  bool fullyInsideHost(DateTime slotStart, DateTime slotEnd) {
    for (final h in host) {
      if (!h.start.isAfter(slotStart) && !slotEnd.isAfter(h.end)) return true;
    }
    return false;
  }

  final slots = <AvailabilitySlotState>[];
  for (var i = 0; i < kHeatmapSlotsPerDay; i++) {
    final slotStart = dayStart.add(
      Duration(minutes: i * TimeStepMinutes.step),
    );
    final slotEnd = slotStart.add(
      const Duration(minutes: TimeStepMinutes.step),
    );
    if (!fullyInsideHost(slotStart, slotEnd)) {
      slots.add(AvailabilitySlotState.hostClosed);
      continue;
    }
    var blocked = false;
    for (final b in bookedMerged) {
      if (slotStart.isBefore(b.end) && slotEnd.isAfter(b.start)) {
        blocked = true;
        break;
      }
    }
    slots.add(
      blocked ? AvailabilitySlotState.booked : AvailabilitySlotState.open,
    );
  }
  return slots;
}

// 5min to 24hrs (booked wins, then open, else closed)
List<AvailabilitySlotState> aggregateFiveMinuteToHourly(
  List<AvailabilitySlotState> fiveMinute,
) {
  assert(fiveMinute.length == kHeatmapSlotsPerDay);
  const perHour = 60 ~/ TimeStepMinutes.step;
  return List.generate(24, (h) {
    final start = h * perHour;
    return aggregateSlotSlice(fiveMinute.sublist(start, start + perHour));
  });
}

// 24 hourly to four 6hr blocks
List<AvailabilitySlotState> aggregateHourlyToFourBlocks(
  List<AvailabilitySlotState> hourly24,
) {
  assert(hourly24.length == 24);
  return List.generate(4, (q) {
    final start = q * 6;
    return aggregateSlotSlice(hourly24.sublist(start, start + 6));
  });
}

AvailabilitySlotState aggregateSlotSlice(
  Iterable<AvailabilitySlotState> slice,
) {
  final list = slice.toList();
  if (list.isEmpty) return AvailabilitySlotState.hostClosed;
  if (list.every((s) => s == AvailabilitySlotState.hostClosed)) {
    return AvailabilitySlotState.hostClosed;
  }
  if (list.any((s) => s == AvailabilitySlotState.booked)) {
    return AvailabilitySlotState.booked;
  }
  return AvailabilitySlotState.open;
}

