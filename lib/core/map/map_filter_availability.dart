import '../models/availability_specific.dart';
import '../models/availability_weekly.dart';
import '../models/booking_time_window.dart';
import '../models/listing.dart';
import 'availability_heatmap_logic.dart';
import 'listing_next_available.dart' show mergeBookingWindows;

// Map filter: host is open for the whole slice and nothing confirmed or active overlaps it.
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
  final rs = DateTime(rangeStartDay.year, rangeStartDay.month, rangeStartDay.day);
  final re = DateTime(rangeEndDay.year, rangeEndDay.month, rangeEndDay.day);
  if (re.isBefore(rs)) return false;

  final globalStart = rs.add(Duration(minutes: startMinutes));
  final globalEnd = re.add(Duration(minutes: endMinutes));
  if (!globalEnd.isAfter(globalStart)) return false;

  final mergedBookings = mergeBookingWindows(bookings);

  bool sliceFreeOfBookings(DateTime sliceStart, DateTime sliceEnd) {
    for (final b in mergedBookings) {
      if (sliceStart.isBefore(b.end) && sliceEnd.isAfter(b.start)) {
        return false;
      }
    }
    return true;
  }

  var dayCursor = rs;
  while (!dayCursor.isAfter(re)) {
    final d0 = DateTime(dayCursor.year, dayCursor.month, dayCursor.day);
    final d1 = d0.add(const Duration(days: 1));
    final sliceStart = globalStart.isAfter(d0) ? globalStart : d0;
    final sliceEnd = globalEnd.isBefore(d1) ? globalEnd : d1;
    if (sliceEnd.isAfter(sliceStart)) {
      final intervals = hostOpenIntervalsForDay(d0, listing, weekly, specific);
      if (!hostOpenUnionCoversRange(sliceStart, sliceEnd, intervals)) {
        return false;
      }
      if (!sliceFreeOfBookings(sliceStart, sliceEnd)) {
        return false;
      }
    }
    dayCursor = d1;
  }
  return true;
}
