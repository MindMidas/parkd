import 'package:supabase_flutter/supabase_flutter.dart';

import '../map/map_filter_availability.dart';
import '../map/map_filters.dart';
import '../map/map_geo.dart';
import '../models/availability_specific.dart';
import '../models/availability_weekly.dart';
import '../models/listing.dart';
import '../models/slot_pricing_summary.dart';
import 'reservations_remote.dart';

// public.listings reads and writes
class ListingsRemote {
  ListingsRemote(this._client);

  final SupabaseClient _client;

  ReservationsRemote get _reservations => ReservationsRemote(_client);

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

  // lowest sort_order wins (hero is 0)
  static String? _heroPhotoUrlFromListingPhotosEmbed(dynamic raw) {
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
        bestUrl = url.trim();
      }
    }
    return bestUrl;
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
    final rows = await _client
        .from('listings')
        .select(
          'id, host_id, address, city, postal_code, country, spot_number, '
          'latitude, longitude, availability_mode, is_active, is_published, '
          'terms_accepted, terms_accepted_at, created_at, updated_at, '
          'availability_weekly(*), '
          'availability_specific(*), '
          'listing_photos(photo_url, sort_order)',
        )
        .eq('is_published', true)
        .eq('is_active', true)
        .order('created_at', ascending: false);
    final list = <Listing>[];
    final pending =
        <({Listing listing, List<AvailabilityWeekly> weekly, List<AvailabilitySpecific> specific})>[];

    DateTime? availRs;
    DateTime? availRe;
    DateTime? globalAvailStart;
    DateTime? globalAvailEnd;
    if (flt.availabilityFilterEnabled) {
      availRs = flt.availRangeStart;
      availRe = flt.availRangeEnd;
      if (availRs != null && availRe != null) {
        final gs = DateTime(availRs.year, availRs.month, availRs.day)
            .add(Duration(minutes: flt.availStartMinutes));
        final ge = DateTime(availRe.year, availRe.month, availRe.day)
            .add(Duration(minutes: flt.availEndMinutes));
        if (ge.isAfter(gs)) {
          globalAvailStart = gs;
          globalAvailEnd = ge;
        }
      }
    }
    final needAvailFilter = globalAvailStart != null && globalAvailEnd != null;

    for (final e in rows as List) {
      final row = Map<String, dynamic>.from(e as Map);
      final weekly = _embeddedWeekly(row['availability_weekly']);
      final specific = _embeddedSpecific(row['availability_specific']);
      final minH = SlotPricingSummary.minHourly(weekly, specific);
      if (minH == null || minH > flt.maxPricePerHour) continue;

      if (flt.guelphOnly) {
        final city = (row['city'] as String? ?? '').trim().toLowerCase();
        if (city != 'guelph') continue;
      }

      if (flt.proximityEnabled &&
          proximityUserLatitude != null &&
          proximityUserLongitude != null) {
        final lat = row['latitude'];
        final lon = row['longitude'];
        if (lat is! num || lon is! num) continue;
        final km = distanceKmBetween(
          proximityUserLatitude,
          proximityUserLongitude,
          lat.toDouble(),
          lon.toDouble(),
        );
        if (km > flt.proximityRadiusKm) continue;
      }

      row.remove('availability_weekly');
      row.remove('availability_specific');
      final embeddedPhotos = row.remove('listing_photos');
      final hero = _heroPhotoUrlFromListingPhotosEmbed(embeddedPhotos);
      if (hero != null) row['hero_photo_url'] = hero;
      final l = Listing.fromJson(row);

      if (needAvailFilter) {
        pending.add((listing: l, weekly: weekly, specific: specific));
      } else {
        list.add(l);
      }
    }

    if (pending.isNotEmpty &&
        globalAvailStart != null &&
        globalAvailEnd != null &&
        availRs != null &&
        availRe != null) {
      final bookingMap = await _reservations.fetchOverlappingBlocksForListings(
        pending.map((p) => p.listing.id).toList(),
        rangeStart: globalAvailStart,
        rangeEnd: globalAvailEnd,
      );
      for (final p in pending) {
        final bookings = bookingMap[p.listing.id] ?? const [];
        if (!listingMatchesMapAvailabilityWindow(
          listing: p.listing,
          weekly: p.weekly,
          specific: p.specific,
          bookings: bookings,
          rangeStartDay: availRs,
          rangeEndDay: availRe,
          startMinutes: flt.availStartMinutes,
          endMinutes: flt.availEndMinutes,
        )) {
          continue;
        }
        list.add(p.listing);
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
    await _client.from('listings').delete().eq('id', listingId);
  }

  List<AvailabilityWeekly> _embeddedWeekly(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .map((e) => AvailabilityWeekly.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  List<AvailabilitySpecific> _embeddedSpecific(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .map(
          (e) => AvailabilitySpecific.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

}
