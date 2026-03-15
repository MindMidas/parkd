/// Mirrors public.reservation_status enum in database/schema.sql
enum ReservationStatus {
  pending,
  confirmed,
  active,
  completed,
  cancelled;

  static ReservationStatus? fromString(String? value) {
    if (value == null) return null;
    for (final e in ReservationStatus.values) {
      if (e.name == value) return e;
    }
    return null;
  }
}
