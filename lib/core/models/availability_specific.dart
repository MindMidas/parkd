import '../utils/time_step_minutes.dart';

// mirrors public.availability_specific (date-range slots)
class AvailabilitySpecific {
  const AvailabilitySpecific({
    required this.id,
    required this.listingId,
    required this.startDatetime,
    required this.endDatetime,
    this.priceHour = 0,
    this.priceDay,
    this.createdAt,
  });

  final String id;
  final String listingId;
  final DateTime startDatetime;
  final DateTime endDatetime;
  final double priceHour;
  final double? priceDay;
  final DateTime? createdAt;

  // for UI: "Sep 15, 2026 · 9:00 AM"
  static String formatDateTime(DateTime dt) {
    const months = 'JanFebMarAprMayJunJulAugSepOctNovDec';
    final m = months.substring((dt.month - 1) * 3, dt.month * 3);
    final time = TimeStepMinutes.formatAmPm(dt.hour * 60 + dt.minute);
    return '$m ${dt.day}, ${dt.year} · $time';
  }

  String get fromDisplay => formatDateTime(startDatetime);
  String get toDisplay => formatDateTime(endDatetime);

  static AvailabilitySpecific fromJson(Map<String, dynamic> json) {
    return AvailabilitySpecific(
      id: json['id'] as String,
      listingId: json['listing_id'] as String,
      startDatetime: DateTime.parse(json['start_datetime'] as String),
      endDatetime: DateTime.parse(json['end_datetime'] as String),
      priceHour: (json['price_hour'] as num?)?.toDouble() ?? 0,
      priceDay: (json['price_day'] as num?)?.toDouble(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'listing_id': listingId,
        'start_datetime': startDatetime.toIso8601String(),
        'end_datetime': endDatetime.toIso8601String(),
        'price_hour': priceHour,
        'price_day': priceDay,
        'created_at': createdAt?.toIso8601String(),
      };
}
