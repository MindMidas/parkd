import 'availability_specific.dart';
import 'availability_weekly.dart';

/// public.listings (+ embed hero url); rates on availability rows — supabase/schema.sql
class ListingAvailabilityMode {
  static const weekly = 'weekly';
  static const specific = 'specific';
}

class Listing {
  const Listing({
    required this.id,
    required this.hostId,
    required this.address,
    required this.city,
    this.postalCode,
    this.country = 'Canada',
    this.spotNumber,
    required this.latitude,
    required this.longitude,
    this.availabilityMode = ListingAvailabilityMode.weekly,
    this.isActive = false,
    this.isPublished = false,
    this.termsAccepted = false,
    this.termsAcceptedAt,
    this.createdAt,
    this.updatedAt,

    /// Public discovery rows intentionally contain only a coarse location.
    this.isApproximateLocation = false,
    this.minHourlyPrice,
    this.minDailyPrice,
    this.publicWeeklyAvailability = const [],
    this.publicSpecificAvailability = const [],

    /// Hero image URL for list rows (from embedded `listing_photos`, not a DB column)
    this.heroPhotoUrl,
  });

  final String id;
  final String hostId;
  final String address;
  final String city;
  final String? postalCode;
  final String country;
  final String? spotNumber;
  final double latitude;
  final double longitude;
  final String availabilityMode;
  final bool isActive;
  final bool isPublished;
  final bool termsAccepted;
  final DateTime? termsAcceptedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isApproximateLocation;
  final double? minHourlyPrice;
  final double? minDailyPrice;
  final List<AvailabilityWeekly> publicWeeklyAvailability;
  final List<AvailabilitySpecific> publicSpecificAvailability;

  final String? heroPhotoUrl;

  String get addressLine => address;

  String get localityLine => formatPostalLocalityLine(
    city: city,
    region: null,
    country: country,
    postalCode: postalCode,
  );

  String? get spotLabel {
    final s = spotNumber?.trim();
    if (s == null || s.isEmpty) return null;
    return 'Spot #$s';
  }

  static String formatPostalLocalityLine({
    required String city,
    String? region,
    required String country,
    String? postalCode,
  }) {
    final parts = <String>[];
    final c = city.trim();
    if (c.isNotEmpty) parts.add(c);
    final r = region?.trim();
    if (r != null && r.isNotEmpty) parts.add(r);
    final co = country.trim();
    if (co.isNotEmpty) parts.add(co);
    final p = postalCode?.trim();
    if (p != null && p.isNotEmpty) parts.add(p);
    return parts.join(', ');
  }

  bool get isWeeklyAvailability =>
      availabilityMode == ListingAvailabilityMode.weekly;
  bool get isSpecificAvailability =>
      availabilityMode == ListingAvailabilityMode.specific;

  static Listing fromJson(Map<String, dynamic> json) {
    final isPublicCard = json.containsKey('approximate_latitude');
    final id = json['id'] as String;
    return Listing(
      id: id,
      hostId: json['host_id'] as String,
      address:
          json['address'] as String? ?? json['display_name'] as String? ?? '',
      city: json['city'] as String? ?? '',
      postalCode:
          json['postal_code'] as String? ?? json['postal_area'] as String?,
      country: json['country'] as String? ?? 'Canada',
      spotNumber: json['spot_number'] as String?,
      latitude:
          (json['latitude'] as num? ?? json['approximate_latitude'] as num)
              .toDouble(),
      longitude:
          (json['longitude'] as num? ?? json['approximate_longitude'] as num)
              .toDouble(),
      availabilityMode:
          (json['availability_mode'] as String?) ??
          ListingAvailabilityMode.weekly,
      isActive: json['is_active'] as bool? ?? false,
      isPublished: json['is_published'] as bool? ?? false,
      termsAccepted: json['terms_accepted'] as bool? ?? false,
      termsAcceptedAt: json['terms_accepted_at'] != null
          ? DateTime.parse(json['terms_accepted_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      isApproximateLocation: isPublicCard,
      minHourlyPrice: (json['min_hourly_price'] as num?)?.toDouble(),
      minDailyPrice: (json['min_daily_price'] as num?)?.toDouble(),
      publicWeeklyAvailability: _weeklyFromPublicJson(
        json['weekly_availability'],
        id,
      ),
      publicSpecificAvailability: _specificFromPublicJson(
        json['specific_availability'],
        id,
      ),
      heroPhotoUrl: _nonEmptyString(json['hero_photo_url']),
    );
  }

  static List<AvailabilityWeekly> _weeklyFromPublicJson(
    dynamic raw,
    String listingId,
  ) {
    if (raw is! List) return const [];
    return raw
        .map((value) {
          final row = Map<String, dynamic>.from(value as Map);
          row['listing_id'] ??= listingId;
          return AvailabilityWeekly.fromJson(row);
        })
        .toList(growable: false);
  }

  static List<AvailabilitySpecific> _specificFromPublicJson(
    dynamic raw,
    String listingId,
  ) {
    if (raw is! List) return const [];
    return raw
        .map((value) {
          final row = Map<String, dynamic>.from(value as Map);
          row['listing_id'] ??= listingId;
          return AvailabilitySpecific.fromJson(row);
        })
        .toList(growable: false);
  }

  static String? _nonEmptyString(dynamic v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'host_id': hostId,
    'address': address,
    'city': city,
    'postal_code': postalCode,
    'country': country,
    'spot_number': spotNumber,
    'latitude': latitude,
    'longitude': longitude,
    'availability_mode': availabilityMode,
    'is_active': isActive,
    'is_published': isPublished,
    'terms_accepted': termsAccepted,
    'terms_accepted_at': termsAcceptedAt?.toIso8601String(),
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    'is_approximate_location': isApproximateLocation,
    'min_hourly_price': minHourlyPrice,
    'min_daily_price': minDailyPrice,
    if (publicWeeklyAvailability.isNotEmpty)
      'weekly_availability': publicWeeklyAvailability
          .map((slot) => slot.toJson())
          .toList(),
    if (publicSpecificAvailability.isNotEmpty)
      'specific_availability': publicSpecificAvailability
          .map((slot) => slot.toJson())
          .toList(),
    if (heroPhotoUrl != null) 'hero_photo_url': heroPhotoUrl,
  };
}
