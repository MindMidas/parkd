import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/booking_time_window.dart';
import '../models/reservation_row.dart';

// Inserts and reads public.reservations — host_id filled by trigger
class ReservationsRemote {
  ReservationsRemote(this._client);

  final SupabaseClient _client;

  static const _driverHostActiveTripStatuses = ['confirmed', 'active'];
  static const _pastStatuses = ['completed', 'cancelled'];

  Future<ReservationRow?> fetchById(String id) async {
    final row = await _client
        .from('reservations')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return ReservationRow.fromJson(Map<String, dynamic>.from(row));
  }

  List<ReservationRow> _mapRows(dynamic rows) {
    return (rows as List)
        .map(
          (e) =>
              ReservationRow.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  // Past = completed/cancelled in DB, or confirmed/active whose window has ended
  List<ReservationRow> _mergePastReservationRows(dynamic a, dynamic b) {
    final seen = <String>{};
    final merged = <ReservationRow>[];
    void take(dynamic rows) {
      for (final e in rows as List) {
        final m = Map<String, dynamic>.from(e as Map);
        final id = m['id'] as String;
        if (!seen.add(id)) continue;
        final row = ReservationRow.fromJson(m);
        if (row.isCheckoutHoldNoise) continue;
        merged.add(row);
      }
    }

    take(a);
    take(b);
    merged.sort((x, y) => y.startTime.compareTo(x.startTime));
    return merged;
  }

  Future<List<ReservationRow>> fetchForDriver(
    String driverId, {
    required bool activeOnly,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    if (activeOnly) {
      final rows = await _client
          .from('reservations')
          .select()
          .eq('driver_id', driverId)
          .inFilter('status', _driverHostActiveTripStatuses)
          .gt('end_time', nowIso)
          .order('start_time');
      return _mapRows(rows);
    }
    final byPastStatus = await _client
        .from('reservations')
        .select()
        .eq('driver_id', driverId)
        .inFilter('status', _pastStatuses)
        .order('start_time', ascending: false);
    final expiredActive = await _client
        .from('reservations')
        .select()
        .eq('driver_id', driverId)
        .inFilter('status', _driverHostActiveTripStatuses)
        .lte('end_time', nowIso)
        .order('start_time', ascending: false);
    return _mergePastReservationRows(byPastStatus, expiredActive);
  }

  Future<List<ReservationRow>> fetchForHost(
    String hostId, {
    required bool activeOnly,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    if (activeOnly) {
      final rows = await _client
          .from('reservations')
          .select()
          .eq('host_id', hostId)
          .inFilter('status', _driverHostActiveTripStatuses)
          .gt('end_time', nowIso)
          .order('start_time');
      return _mapRows(rows);
    }
    final byPastStatus = await _client
        .from('reservations')
        .select()
        .eq('host_id', hostId)
        .inFilter('status', _pastStatuses)
        .order('start_time', ascending: false);
    final expiredActive = await _client
        .from('reservations')
        .select()
        .eq('host_id', hostId)
        .inFilter('status', _driverHostActiveTripStatuses)
        .lte('end_time', nowIso)
        .order('start_time', ascending: false);
    return _mergePastReservationRows(byPastStatus, expiredActive);
  }

  // Bookings you host for a single listing (active = confirmed/active only)
  Future<List<ReservationRow>> fetchForHostListing(
    String hostId,
    String listingId, {
    required bool activeOnly,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    if (activeOnly) {
      final rows = await _client
          .from('reservations')
          .select()
          .eq('host_id', hostId)
          .eq('listing_id', listingId)
          .inFilter('status', _driverHostActiveTripStatuses)
          .gt('end_time', nowIso)
          .order('start_time');
      return _mapRows(rows);
    }
    final byPastStatus = await _client
        .from('reservations')
        .select()
        .eq('host_id', hostId)
        .eq('listing_id', listingId)
        .inFilter('status', _pastStatuses)
        .order('start_time', ascending: false);
    final expiredActive = await _client
        .from('reservations')
        .select()
        .eq('host_id', hostId)
        .eq('listing_id', listingId)
        .inFilter('status', _driverHostActiveTripStatuses)
        .lte('end_time', nowIso)
        .order('start_time', ascending: false);
    return _mergePastReservationRows(byPastStatus, expiredActive);
  }

  Future<void> cancelCheckoutHold(String reservationId) async {
    await _client.rpc(
      'cancel_checkout_hold',
      params: {
        'p_reservation_id': reservationId,
        'p_reason': 'driver_cancelled_checkout',
      },
    );
  }

  // Busy windows for heatmap / slot picker (overlaps [rangeStart, rangeEnd))
  Future<List<BookingTimeWindow>> fetchOverlappingBlocksForListing(
    String listingId, {
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    final fromIso = rangeStart.toUtc().toIso8601String();
    final toIso = rangeEnd.toUtc().toIso8601String();
    final rows = await _client
        .from('public_listing_busy_windows')
        .select('start_time, end_time')
        .eq('listing_id', listingId)
        .gt('end_time', fromIso)
        .lt('start_time', toIso);
    final out = <BookingTimeWindow>[];
    for (final e in rows as List) {
      final m = Map<String, dynamic>.from(e as Map);
      final s = m['start_time'];
      final t = m['end_time'];
      if (s == null || t == null) continue;
      out.add(
        BookingTimeWindow(
          start: DateTime.parse(s as String).toLocal(),
          end: DateTime.parse(t as String).toLocal(),
        ),
      );
    }
    return out;
  }

  // Busy windows for several public listings in one privacy-safe query.
  Future<Map<String, List<BookingTimeWindow>>>
  fetchOverlappingBlocksForListings(
    List<String> listingIds, {
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    final ids = listingIds.toSet().toList(growable: false);
    if (ids.isEmpty) return const {};

    final rows = await _client
        .from('public_listing_busy_windows')
        .select('listing_id, start_time, end_time')
        .inFilter('listing_id', ids)
        .gt('end_time', rangeStart.toUtc().toIso8601String())
        .lt('start_time', rangeEnd.toUtc().toIso8601String());
    final out = <String, List<BookingTimeWindow>>{};
    for (final value in rows as List) {
      final row = Map<String, dynamic>.from(value as Map);
      final listingId = row['listing_id'];
      final start = row['start_time'];
      final end = row['end_time'];
      if (listingId is! String || start is! String || end is! String) continue;
      (out[listingId] ??= []).add(
        BookingTimeWindow(
          start: DateTime.parse(start).toLocal(),
          end: DateTime.parse(end).toLocal(),
        ),
      );
    }
    return out;
  }
}
