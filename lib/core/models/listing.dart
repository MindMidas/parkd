/// Mirrors public.listings.
/// Schema: database/schema.sql
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
    this.priceHour = 0,
    this.priceDay,
    this.isActive = false,
    this.isPublished = false,
    this.termsAccepted = false,
    this.termsAcceptedAt,
    this.createdAt,
    this.updatedAt,
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
  final double priceHour;
  final double? priceDay;
  final bool isActive;
  final bool isPublished;
  final bool termsAccepted;
  final DateTime? termsAcceptedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Single-line address for list rows (e.g. "25 Macdonell Street").
  String get addressLine => address;

  /// Subtitle for list rows (e.g. "Guelph, ON N1L 0M5\nSpot #345").
  String get subtitle {
    final parts = <String>[];
    if (city.isNotEmpty) parts.add(city);
    if (postalCode != null && postalCode!.isNotEmpty) parts.add(postalCode!);
    final line1 = parts.join(', ');
    if (spotNumber != null && spotNumber!.isNotEmpty) {
      return line1.isEmpty ? 'Spot #$spotNumber' : '$line1\nSpot #$spotNumber';
    }
    return line1;
  }

  /// Price summary for display (e.g. "$10/hr • $30/day").
  String get priceSummary {
    final hr = '\$${priceHour.toStringAsFixed(0)}/hr';
    if (priceDay != null) return '$hr • \$${priceDay!.toStringAsFixed(0)}/day';
    return hr;
  }

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
      priceHour: (json['price_hour'] as num?)?.toDouble() ?? 0,
      priceDay: (json['price_day'] as num?)?.toDouble(),
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
        'price_hour': priceHour,
        'price_day': priceDay,
        'is_active': isActive,
        'is_published': isPublished,
        'terms_accepted': termsAccepted,
        'terms_accepted_at': termsAcceptedAt?.toIso8601String(),
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };
}
