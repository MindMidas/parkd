import '../models/availability_specific.dart';
import '../models/availability_weekly.dart';
import '../models/booking_time_window.dart';
import '../models/listing.dart';
import 'availability_heatmap_logic.dart';
import 'listing_next_available.dart' show mergeBookingWindows;

bool listingMatchesMapAvailabilityWindow({
  required Listing listing,
  required List<AvailabilityWeekly> weekly,
  required List<AvailabilitySpecific> specific,
  required List<BookingTimeWindow> bookings,
  required DateTime rangeStartDay,
  required DateTime rangeEndDay,
  required int startMinutes,
  required int endMinutes,
}) {
  final rangeStart = DateTime(
    rangeStartDay.year,
    rangeStartDay.month,
    rangeStartDay.day,
  );
  final rangeEnd = DateTime(
    rangeEndDay.year,
    rangeEndDay.month,
    rangeEndDay.day,
  );
  if (rangeEnd.isBefore(rangeStart)) return false;

  final requestedStart = rangeStart.add(Duration(minutes: startMinutes));
  final requestedEnd = rangeEnd.add(Duration(minutes: endMinutes));
  if (!requestedEnd.isAfter(requestedStart)) return false;

  final mergedBookings = mergeBookingWindows(bookings);

  bool isFreeOfBookings(DateTime sliceStart, DateTime sliceEnd) {
    for (final booking in mergedBookings) {
      if (sliceStart.isBefore(booking.end) && sliceEnd.isAfter(booking.start)) {
        return false;
      }
    }
    return true;
  }

  var day = rangeStart;
  while (!day.isAfter(rangeEnd)) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final sliceStart = requestedStart.isAfter(dayStart)
        ? requestedStart
        : dayStart;
    final sliceEnd = requestedEnd.isBefore(dayEnd) ? requestedEnd : dayEnd;
    if (sliceEnd.isAfter(sliceStart)) {
      final hostIntervals = hostOpenIntervalsForDay(
        dayStart,
        listing,
        weekly,
        specific,
      );
      if (!hostOpenUnionCoversRange(sliceStart, sliceEnd, hostIntervals)) {
        return false;
      }
      if (!isFreeOfBookings(sliceStart, sliceEnd)) return false;
    }
    day = dayEnd;
  }
  return true;
}
