import 'availability_specific.dart';
import 'availability_weekly.dart';

// public.listings (+ embed hero url); rates on availability rows.
class ListingAvailabilityMode {
  static const weekly = 'weekly';
  static const specific = 'specific';
}

// Airbnb-style map sharing. Street address stays private until booking either way.
enum ListingLocationSharing {
  general,
  specific;

  static const dbGeneral = 'general';
  static const dbSpecific = 'specific';

  bool get isGeneral => this == ListingLocationSharing.general;
  bool get isSpecific => this == ListingLocationSharing.specific;

  String get dbValue => switch (this) {
    ListingLocationSharing.general => dbGeneral,
    ListingLocationSharing.specific => dbSpecific,
  };

  static ListingLocationSharing fromDb(Object? raw) {
    if (raw == dbSpecific) return ListingLocationSharing.specific;
    return ListingLocationSharing.general;
  }
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
    this.locationSharing = ListingLocationSharing.general,
    this.isActive = false,
    this.isPublished = false,
    this.termsAccepted = false,
    this.termsAcceptedAt,
    this.createdAt,
    this.updatedAt,

    // Public discovery + general sharing: coarse/obfuscated map location.
    this.isApproximateLocation = false,
    this.minHourlyPrice,
    this.minDailyPrice,
    this.publicWeeklyAvailability = const [],
    this.publicSpecificAvailability = const [],

    // Hero image URL for list rows (from embedded `listing_photos`, not a DB column)
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
  final ListingLocationSharing locationSharing;
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

  // Town and country for driver-facing location.
  String get townCountryLine {
    final parts = <String>[];
    final c = city.trim();
    if (c.isNotEmpty) parts.add(c);
    final co = country.trim();
    if (co.isNotEmpty) parts.add(co);
    return parts.join(', ');
  }

  // Driver-facing label when only the privacy-safe public card is available.
  String get approximateAreaHeadline {
    final line = townCountryLine;
    if (line.isEmpty) return 'Approximate parking area';
    return line;
  }

  // Public cards use "Parking in {city}" instead of the street address.
  bool get revealsExactStreetAddress {
    final a = address.trim().toLowerCase();
    return a.isNotEmpty && !a.startsWith('parking in ');
  }

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
    final locationSharing = ListingLocationSharing.fromDb(
      json['location_sharing'],
    );
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
      locationSharing: locationSharing,
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
      // Public and general sharing use the approximate map. Specific sharing hides
      // the street address, but the pin can sit on the true coordinates.
      isApproximateLocation: isPublicCard && locationSharing.isGeneral,
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

  Listing copyWith({
    String? id,
    String? hostId,
    String? address,
    String? city,
    String? postalCode,
    String? country,
    String? spotNumber,
    double? latitude,
    double? longitude,
    String? availabilityMode,
    ListingLocationSharing? locationSharing,
    bool? isActive,
    bool? isPublished,
    bool? termsAccepted,
    DateTime? termsAcceptedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isApproximateLocation,
    double? minHourlyPrice,
    double? minDailyPrice,
    List<AvailabilityWeekly>? publicWeeklyAvailability,
    List<AvailabilitySpecific>? publicSpecificAvailability,
    String? heroPhotoUrl,
  }) {
    return Listing(
      id: id ?? this.id,
      hostId: hostId ?? this.hostId,
      address: address ?? this.address,
      city: city ?? this.city,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      spotNumber: spotNumber ?? this.spotNumber,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      availabilityMode: availabilityMode ?? this.availabilityMode,
      locationSharing: locationSharing ?? this.locationSharing,
      isActive: isActive ?? this.isActive,
      isPublished: isPublished ?? this.isPublished,
      termsAccepted: termsAccepted ?? this.termsAccepted,
      termsAcceptedAt: termsAcceptedAt ?? this.termsAcceptedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isApproximateLocation:
          isApproximateLocation ?? this.isApproximateLocation,
      minHourlyPrice: minHourlyPrice ?? this.minHourlyPrice,
      minDailyPrice: minDailyPrice ?? this.minDailyPrice,
      publicWeeklyAvailability:
          publicWeeklyAvailability ?? this.publicWeeklyAvailability,
      publicSpecificAvailability:
          publicSpecificAvailability ?? this.publicSpecificAvailability,
      heroPhotoUrl: heroPhotoUrl ?? this.heroPhotoUrl,
    );
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
    'location_sharing': locationSharing.dbValue,
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
