import 'package:supabase_flutter/supabase_flutter.dart';

import '../map/listing_next_available.dart';
import '../map/map_filter_availability.dart';
import '../map/map_filters.dart';
import '../map/map_geo.dart';
import '../models/booking_time_window.dart';
import '../models/listing.dart';
import 'reservations_remote.dart';

// public.listings reads and writes
class ListingsRemote {
  ListingsRemote(this._client);

  final SupabaseClient _client;
  static const _listingPhotosBucket = 'listing-photos';

  ReservationsRemote get _reservations => ReservationsRemote(_client);

  Future<List<Listing>> listByHostId(String hostId) async {
    final rows = await _client
        .from('listings')
        .select(
          '*, listing_photos(photo_url, sort_order), '
          'availability_specific(id, start_datetime, end_datetime, '
          'price_hour, price_day)',
        )
        .eq('host_id', hostId)
        .order('created_at', ascending: false);
    return (rows as List).map((e) {
      final row = Map<String, dynamic>.from(e as Map);
      final photos = row.remove('listing_photos');
      final specific = row.remove('availability_specific');
      if (specific != null) row['specific_availability'] = specific;
      final hero = _heroPhotoUrlFromListingPhotosEmbed(photos);
      if (hero != null) row['hero_photo_url'] = hero;
      return Listing.fromJson(row);
    }).toList();
  }

  // Lowest sort_order wins (hero is 0)
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

  Future<List<Listing>> fetchPublishedForMap({
    MapFilters? filters,
    double? proximityUserLatitude,
    double? proximityUserLongitude,
  }) async {
    final flt = filters ?? const MapFilters();
    final now = DateTime.now();
    final rows = await _client
        .from('public_listing_cards')
        .select()
        .order('created_at', ascending: false);
    final list = <Listing>[];
    final specificCandidates = <Listing>[];
    final availabilityCandidates = <Listing>[];
    final availabilityStart = flt.availabilityWindowStart;
    final availabilityEnd = flt.availabilityWindowEnd;
    final applyAvailability =
        flt.availabilityFilterEnabled &&
        flt.hasValidAvailabilityWindow &&
        availabilityStart != null &&
        availabilityEnd != null;

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
      if (flt.proximityEnabled &&
          proximityUserLatitude != null &&
          proximityUserLongitude != null) {
        final distanceKm = distanceKmBetween(
          proximityUserLatitude,
          proximityUserLongitude,
          listing.latitude,
          listing.longitude,
        );
        if (distanceKm > flt.proximityRadiusKm) continue;
      }

      if (listing.isSpecificAvailability) {
        if (!listingHasFutureSpecificWindow(
          listing.publicSpecificAvailability,
          now: now,
        )) {
          continue;
        }
        specificCandidates.add(listing);
        continue;
      }

      if (listing.publicWeeklyAvailability.isEmpty) continue;
      if (applyAvailability) {
        availabilityCandidates.add(listing);
      } else {
        list.add(listing);
      }
    }

    if (specificCandidates.isNotEmpty) {
      var rangeEnd = now;
      for (final listing in specificCandidates) {
        for (final s in listing.publicSpecificAvailability) {
          if (s.endDatetime.isAfter(rangeEnd)) rangeEnd = s.endDatetime;
        }
      }
      final busyWindows = await _reservations.fetchOverlappingBlocksForListings(
        specificCandidates.map((l) => l.id).toList(growable: false),
        rangeStart: now.subtract(const Duration(hours: 1)),
        rangeEnd: rangeEnd,
      );
      for (final listing in specificCandidates) {
        final bookings = busyWindows[listing.id] ?? const <BookingTimeWindow>[];
        if (!listingHasDiscoverableAvailability(
          listing: listing,
          now: now,
          bookings: bookings,
        )) {
          continue;
        }
        if (applyAvailability) {
          availabilityCandidates.add(listing);
        } else {
          list.add(listing);
        }
      }
    }

    if (availabilityCandidates.isNotEmpty &&
        availabilityStart != null &&
        availabilityEnd != null) {
      final busyWindows = await _reservations.fetchOverlappingBlocksForListings(
        availabilityCandidates
            .map((listing) => listing.id)
            .toList(growable: false),
        rangeStart: availabilityStart,
        rangeEnd: availabilityEnd,
      );
      for (final listing in availabilityCandidates) {
        if (listingMatchesMapAvailabilityWindow(
          listing: listing,
          weekly: listing.publicWeeklyAvailability,
          specific: listing.publicSpecificAvailability,
          bookings: busyWindows[listing.id] ?? const [],
          rangeStartDay: flt.availRangeStart!,
          rangeEndDay: flt.availRangeEnd!,
          startMinutes: flt.availStartMinutes,
          endMinutes: flt.availEndMinutes,
        )) {
          list.add(listing);
        }
      }
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
    ListingLocationSharing locationSharing = ListingLocationSharing.general,
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
          'location_sharing': locationSharing.dbValue,
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
    ListingLocationSharing? locationSharing,
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
    if (locationSharing != null) {
      payload['location_sharing'] = locationSharing.dbValue;
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
