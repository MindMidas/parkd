/// Mirrors public.listing_photos
/// Schema: supabase/schema.sql
class ListingPhoto {
  const ListingPhoto({
    required this.id,
    required this.listingId,
    required this.photoUrl,
    this.sortOrder = 0,
    this.markerX,
    this.markerY,
    this.createdAt,
  });

  final String id;
  final String listingId;
  final String photoUrl;
  final int sortOrder;

  final double? markerX;

  final double? markerY;

  final DateTime? createdAt;

  static ListingPhoto fromJson(Map<String, dynamic> json) {
    return ListingPhoto(
      id: json['id'] as String,
      listingId: json['listing_id'] as String,
      photoUrl: json['photo_url'] as String,
      sortOrder: json['sort_order'] as int? ?? 0,
      markerX: (json['marker_x'] as num?)?.toDouble(),
      markerY: (json['marker_y'] as num?)?.toDouble(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'listing_id': listingId,
    'photo_url': photoUrl,
    'sort_order': sortOrder,
    if (markerX != null) 'marker_x': markerX,
    if (markerY != null) 'marker_y': markerY,
    'created_at': createdAt?.toIso8601String(),
  };
}
