// Driver cancel policy for paid reservations (must match Edge + SQL).
const Duration kReservationCancelRefundLead = Duration(hours: 2);

// Full refund when startTime is more than kReservationCancelRefundLead
bool reservationCancelIsRefundable(DateTime startTime, {DateTime? now}) {
  final clock = (now ?? DateTime.now()).toUtc();
  return startTime.toUtc().isAfter(clock.add(kReservationCancelRefundLead));
}

// Driver can cancel while status is confirmed and the window has not started.
bool reservationIsDriverCancellable(
  DateTime startTime, {
  required String status,
  DateTime? now,
}) {
  if (status != 'confirmed') return false;
  final clock = (now ?? DateTime.now()).toUtc();
  return startTime.toUtc().isAfter(clock);
}
