import '../models/reservation_row.dart';
import '../models/reservation_status.dart';

/// Matches [ReservationsRemote] active lists: confirmed/active with end in the future,
/// or pending with end in the future (anything else is treated as past for badges).
bool reservationAppearsInActiveTripsList(ReservationRow r, DateTime nowUtc) {
  final end = r.endTime.toUtc();
  switch (r.status) {
    case ReservationStatus.completed:
    case ReservationStatus.cancelled:
      return false;
    case ReservationStatus.confirmed:
    case ReservationStatus.active:
    case ReservationStatus.pending:
      return end.isAfter(nowUtc);
  }
}
