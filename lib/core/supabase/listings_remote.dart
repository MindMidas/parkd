import 'package:supabase_flutter/supabase_flutter.dart';

import '../map/map_filters.dart';
import '../models/listing.dart';

/// public.listings reads and writes
class ListingsRemote {
  ListingsRemote(this._client);

  final SupabaseClient _client;
  static const _listingPhotosBucket = 'listing-photos';

  Future<List<Listing>> listByHostId(String hostId) async {
    final rows = await _client
        .from('listings')
        .select('*, listing_photos(photo_url, sort_order)')
        .eq('host_id', hostId)
        .order('created_at', ascending: false);
    return (rows as List).map((e) {
      final row = Map<String, dynamic>.from(e as Map);
      final photos = row.remove('listing_photos');
      final hero = _heroPhotoUrlFromListingPhotosEmbed(photos);
      if (hero != null) row['hero_photo_url'] = hero;
      return Listing.fromJson(row);
    }).toList();
  }

  /// Lowest [sort_order] wins (hero is 0)
  String? _heroPhotoUrlFromListingPhotosEmbed(dynamic raw) {
    if (raw is! List || raw.isEmpty) return null;
    String? bestUrl;
    var bestOrder = 1 << 30;
    for (final e in raw) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final url = m['photo_url'] as String?;
      if (url == null || url.trim().isEmpty) continue;
      final order = (m['sort_order'] as num?)?.toInt() ?? 0;
      if (order < bestOrder) {
        bestOrder = order;
        bestUrl = _publicPhotoUrl(url.trim());
      }
    }
    return bestUrl;
  }

  String _publicPhotoUrl(String storedPathOrUrl) {
    if (storedPathOrUrl.startsWith('http')) return storedPathOrUrl;
    return _client.storage
        .from(_listingPhotosBucket)
        .getPublicUrl(storedPathOrUrl);
  }

  Future<Listing?> fetchById(String id) async {
    final row = await _client
        .from('listings')
        .select('*, listing_photos(photo_url, sort_order)')
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    final map = Map<String, dynamic>.from(row);
    final embedded = map.remove('listing_photos');
    final hero = _heroPhotoUrlFromListingPhotosEmbed(embedded);
    if (hero != null) map['hero_photo_url'] = hero;
    return Listing.fromJson(map);
  }

  Future<List<Listing>> fetchPublishedForMap({MapFilters? filters}) async {
    final flt = filters ?? const MapFilters();
    final rows = await _client
        .from('public_listing_cards')
        .select()
        .order('created_at', ascending: false);
    final list = <Listing>[];
    for (final e in rows as List) {
      final row = Map<String, dynamic>.from(e as Map);
      final hero = row['hero_photo_url'];
      if (hero is String && hero.trim().isNotEmpty) {
        row['hero_photo_url'] = _publicPhotoUrl(hero.trim());
      }
      final listing = Listing.fromJson(row);
      final minH = listing.minHourlyPrice;
      if (minH == null || minH > flt.maxPricePerHour) continue;
      if (flt.guelphOnly && listing.city.trim().toLowerCase() != 'guelph') {
        continue;
      }
      list.add(listing);
    }
    return list;
  }

  Future<Listing> insertListing({
    required String hostId,
    required String address,
    required String city,
    String? postalCode,
    required String country,
    String? spotNumber,
    required double latitude,
    required double longitude,
    String availabilityMode = 'weekly',
  }) async {
    final row = await _client
        .from('listings')
        .insert({
          'host_id': hostId,
          'address': address,
          'city': city,
          'postal_code': postalCode,
          'country': country,
          'spot_number': spotNumber,
          'latitude': latitude,
          'longitude': longitude,
          'availability_mode': availabilityMode,
        })
        .select()
        .single();
    return Listing.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> updateListing({
    required String listingId,
    String? address,
    String? city,
    String? postalCode,
    String? country,
    String? spotNumber,
    double? latitude,
    double? longitude,
    bool? isActive,
    bool? isPublished,
    bool? termsAccepted,
    DateTime? termsAcceptedAt,
    String? availabilityMode,
  }) async {
    final payload = <String, dynamic>{};
    if (address != null) payload['address'] = address;
    if (city != null) payload['city'] = city;
    if (postalCode != null) payload['postal_code'] = postalCode;
    if (country != null) payload['country'] = country;
    if (spotNumber != null) payload['spot_number'] = spotNumber;
    if (latitude != null) payload['latitude'] = latitude;
    if (longitude != null) payload['longitude'] = longitude;
    if (isActive != null) payload['is_active'] = isActive;
    if (isPublished != null) payload['is_published'] = isPublished;
    if (termsAccepted != null) payload['terms_accepted'] = termsAccepted;
    if (termsAcceptedAt != null) {
      payload['terms_accepted_at'] = termsAcceptedAt.toUtc().toIso8601String();
    }
    if (availabilityMode != null) {
      payload['availability_mode'] = availabilityMode;
    }
    if (payload.isEmpty) return;
    await _client.from('listings').update(payload).eq('id', listingId);
  }

  Future<void> deleteListing(String listingId) async {
    final deleted = await _client.rpc(
      'soft_delete_listing',
      params: {'p_listing_id': listingId},
    );
    if (deleted != true) {
      throw StateError('Listing was not found or could not be removed.');
    }
  }
}
