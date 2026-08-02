import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/availability_specific.dart';
import '../models/availability_weekly.dart';
import '../models/listing.dart';

// availability_weekly + availability_specific tables
class ListingAvailabilityRemote {
  ListingAvailabilityRemote(this._client);

  final SupabaseClient _client;

  Future<List<AvailabilityWeekly>> listWeekly(String listingId) async {
    final rows = await _client
        .from('availability_weekly')
        .select()
        .eq('listing_id', listingId);
    return (rows as List)
        .map(
          (e) =>
              AvailabilityWeekly.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<List<AvailabilitySpecific>> listSpecific(String listingId) async {
    final rows = await _client
        .from('availability_specific')
        .select()
        .eq('listing_id', listingId);
    return (rows as List)
        .map(
          (e) => AvailabilitySpecific.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<void> updateAllSlotPricesForListing({
    required Listing listing,
    required double priceHour,
    double? priceDay,
  }) async {
    final payload = <String, dynamic>{
      'price_hour': priceHour,
      'price_day': priceDay,
    };
    if (listing.isWeeklyAvailability) {
      await _client
          .from('availability_weekly')
          .update(payload)
          .eq('listing_id', listing.id);
    } else if (listing.isSpecificAvailability) {
      await _client
          .from('availability_specific')
          .update(payload)
          .eq('listing_id', listing.id);
    }
  }

  Future<void> updateWeeklySlotPrices({
    required String slotId,
    required double priceHour,
    double? priceDay,
  }) async {
    await _client
        .from('availability_weekly')
        .update({'price_hour': priceHour, 'price_day': priceDay})
        .eq('id', slotId);
  }

  Future<AvailabilityWeekly> insertWeeklySlot({
    required String listingId,
    required int dayOfWeek,
    required String startTimeHhMm,
    required String endTimeHhMm,
    double priceHour = 0,
    double? priceDay,
  }) async {
    final row = await _client
        .from('availability_weekly')
        .insert({
          'listing_id': listingId,
          'day_of_week': dayOfWeek,
          'start_time': startTimeHhMm,
          'end_time': endTimeHhMm,
          'price_hour': priceHour,
          'price_day': priceDay,
        })
        .select()
        .single();
    return AvailabilityWeekly.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> deleteWeeklySlot(String slotId) async {
    await _client.from('availability_weekly').delete().eq('id', slotId);
  }

  Future<AvailabilitySpecific> insertSpecificSlot({
    required String listingId,
    required DateTime start,
    required DateTime end,
    double priceHour = 0,
    double? priceDay,
  }) async {
    final row = await _client
        .from('availability_specific')
        .insert({
          'listing_id': listingId,
          'start_datetime': start.toUtc().toIso8601String(),
          'end_datetime': end.toUtc().toIso8601String(),
          'price_hour': priceHour,
          'price_day': priceDay,
        })
        .select()
        .single();
    return AvailabilitySpecific.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> deleteSpecificSlot(String slotId) async {
    await _client.from('availability_specific').delete().eq('id', slotId);
  }

  Future<void> updateSpecificSlotPrices({
    required String slotId,
    required double priceHour,
    double? priceDay,
  }) async {
    await _client
        .from('availability_specific')
        .update({'price_hour': priceHour, 'price_day': priceDay})
        .eq('id', slotId);
  }
}
