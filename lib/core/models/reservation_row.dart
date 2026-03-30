import 'reservation_status.dart';

// Mirrors public.reservations
class ReservationRow {
  const ReservationRow({
    required this.id,
    required this.listingId,
    required this.driverId,
    required this.hostId,
    required this.startTime,
    required this.endTime,
    required this.totalPrice,
    required this.serviceFee,
    required this.status,
    this.extendedFromReservationId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String listingId;
  final String driverId;
  final String hostId;
  final DateTime startTime;
  final DateTime endTime;
  final double totalPrice;
  final double serviceFee;
  final ReservationStatus status;
  final String? extendedFromReservationId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static ReservationRow fromJson(Map<String, dynamic> json) {
    return ReservationRow(
      id: json['id'] as String,
      listingId: json['listing_id'] as String,
      driverId: json['driver_id'] as String,
      hostId: json['host_id'] as String,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      totalPrice: (json['total_price'] as num).toDouble(),
      serviceFee: (json['service_fee'] as num).toDouble(),
      status: ReservationStatus.fromString(json['status'] as String?) ??
          ReservationStatus.pending,
      extendedFromReservationId:
          json['extended_from_reservation_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }
}
