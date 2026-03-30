// public.listings (+ embed hero url)
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
    // hero image URL for list rows (from embedded 'listing_photos', not DB column)
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
    return Listing(
      id: json['id'] as String,
      hostId: json['host_id'] as String,
      address: json['address'] as String? ?? '',
      city: json['city'] as String? ?? '',
      postalCode: json['postal_code'] as String?,
      country: json['country'] as String? ?? 'Canada',
      spotNumber: json['spot_number'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
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
      heroPhotoUrl: _nonEmptyString(json['hero_photo_url']),
    );
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
    if (heroPhotoUrl != null) 'hero_photo_url': heroPhotoUrl,
  };
}
