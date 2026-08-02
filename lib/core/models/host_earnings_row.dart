// One row from public.host_earnings view
class HostEarningsRow {
  const HostEarningsRow({
    required this.hostId,
    required this.month,
    required this.reservationCount,
    required this.grossEarnings,
  });

  final String hostId;
  final DateTime month;
  final int reservationCount;
  final double grossEarnings;

  static HostEarningsRow fromJson(Map<String, dynamic> json) {
    return HostEarningsRow(
      hostId: json['host_id'] as String,
      month: DateTime.parse(json['month'] as String),
      reservationCount: json['reservation_count'] as int? ?? 0,
      grossEarnings: (json['gross_earnings'] as num?)?.toDouble() ?? 0,
    );
  }
}
