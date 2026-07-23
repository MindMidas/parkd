/// A time range when the listing is treated as unavailable (e.g. a reservation)
class BookingTimeWindow {
  const BookingTimeWindow({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}
