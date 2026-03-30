// time range when listing is treated as unavailable (ex: a reservation)
class BookingTimeWindow {
  const BookingTimeWindow({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}
