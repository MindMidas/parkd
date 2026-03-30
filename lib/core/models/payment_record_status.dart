// mirrors public.payment_status
enum PaymentRecordStatus {
  pending,
  succeeded,
  failed,
  refunded;

  static PaymentRecordStatus? fromWire(String? value) {
    if (value == null) return null;
    for (final e in PaymentRecordStatus.values) {
      if (e.name == value) return e;
    }
    return null;
  }
}
