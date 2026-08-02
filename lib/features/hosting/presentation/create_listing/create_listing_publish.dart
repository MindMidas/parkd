import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/availability_overlap.dart';
import '../../../../core/utils/time_step_minutes.dart';
import '../../../../core/widgets/app_day_checkboxes.dart';
import '../../../../core/utils/weekday_ui_to_db.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../map/providers/map_providers.dart';
import '../../../profile/providers/profile_providers.dart';
import 'create_listing_draft.dart';

// Single publish flow: listing row → protected Storage upload → marker →
class CreateListingPublish {
  CreateListingPublish._();

  // Short message for the terms-step snackbar / banner
  static String describePublishError(Object e) {
    final raw = e.toString();
    if (raw.contains('23505') ||
        raw.toLowerCase().contains('duplicate key') ||
        raw.toLowerCase().contains('unique constraint')) {
      return 'This address is already listed without a distinct spot label. '
          'Add a spot number (e.g. stall B3) if this is another space at the '
          'same location.';
    }
    if (raw.contains('LISTING_NOT_READY_TO_PUBLISH')) {
      return 'Your listing is missing a photo, availability, or terms agreement.';
    }
    if (raw.contains('cannot insert specific slots') ||
        raw.contains('cannot insert weekly slots')) {
      return 'Availability could not be saved. Please go back to the '
          'availability step and try again.';
    }
    if (raw.toLowerCase().contains('storage') ||
        raw.toLowerCase().contains('bucket') ||
        raw.toLowerCase().contains('object') ||
        raw.contains('statusCode: 400') ||
        raw.contains('statusCode: 403')) {
      return 'The listing photo could not be uploaded. Try a JPEG or PNG under '
          '5 MB, then publish again.';
    }
    if (e is StateError) {
      return e.message;
    }
    final trimmed = raw.trim();
    if (trimmed.isNotEmpty && trimmed != 'Exception') {
      return trimmed.length > 160 ? '${trimmed.substring(0, 157)}…' : trimmed;
    }
    return 'Could not publish listing. Please try again.';
  }

  static DateTime _dateAtMinutes(DateTime d, int mins) {
    final h = mins ~/ 60;
    final m = mins % 60;
    return DateTime(d.year, d.month, d.day, h, m);
  }

  static ({DateTime start, DateTime end}) _specificBounds(
    CreateListingSpecificSlot s,
  ) {
    final a = TimeStepMinutes.tryParseMinutesFromAmPm(s.startTime);
    final b = TimeStepMinutes.tryParseMinutesFromAmPm(s.endTime);
    if (a == null || b == null) {
      return (start: s.fromDate, end: s.toDate);
    }
    return (
      start: _dateAtMinutes(s.fromDate, a),
      end: _dateAtMinutes(s.toDate, b),
    );
  }

  static Future<void> submit(WidgetRef ref, CreateListingDraft d) async {
    if (d.publishedSuccessfully) {
      return;
    }
    if (!d.isCompleteForPublish) {
      throw StateError('Listing draft is incomplete');
    }
    if (d.publishInProgress) {
      throw StateError('Publish is already in progress.');
    }
    d.publishInProgress = true;

    final uid = ref.read(currentSessionProvider)?.user.id;
    if (uid == null) {
      d.publishInProgress = false;
      throw StateError('Not signed in');
    }

    final repo = ref.read(listingsRepositoryProvider);
    final lat = d.pinLat!;
    final lon = d.pinLon!;
    var address = d.addressLine;
    if (address.trim().isEmpty) {
      address = d.picked!.displayName.split(',').first.trim();
    }

    final kind = d.availabilityKind!;
    final modeStr = kind == CreateListingAvailabilityKind.specific
        ? 'specific'
        : 'weekly';

    final spot = d.spotNumber?.trim();
    final spotPayload = (spot == null || spot.isEmpty) ? null : spot;

    String? rollbackListingId;
    try {
      final listing = await repo.createListing(
        hostId: uid,
        address: address,
        city: d.cityLine,
        postalCode: d.postalCode,
        country: 'Canada',
        spotNumber: spotPayload,
        latitude: lat,
        longitude: lon,
        availabilityMode: modeStr,
        locationSharing: d.locationSharing,
      );
      rollbackListingId = listing.id;

      await repo.addListingPhotoFromLocalPath(
        listingId: listing.id,
        localFilePath: d.photoLocalPath!,
        sortOrder: 0,
      );

      await repo.setHeroPhotoSpotMarker(
        listingId: listing.id,
        markerX: d.markerX!,
        markerY: d.markerY!,
      );

      if (kind == CreateListingAvailabilityKind.weekly) {
        var weeklyInserted = 0;
        for (final s in d.weeklySlots) {
          final i = kWeekdayLabels.indexOf(s.day);
          if (i < 0) continue;
          final dow = weekdayUiMonFirstToPostgres(i);
          final p = AvailabilityOverlap.tryParseAmPmTimeRange(s.timeRange);
          if (p == null) continue;
          final startHhMm = TimeStepMinutes.minutesToHhMm(p.startMin);
          final endHhMm = TimeStepMinutes.minutesToHhMm(p.endMin);
          final hourly = s.hourlyPrice ?? 0;
          await repo.insertAvailabilityWeeklySlot(
            listingId: listing.id,
            dayOfWeek: dow,
            startTimeHhMm: startHhMm,
            endTimeHhMm: endHhMm,
            priceHour: hourly,
            priceDay: s.dailyPrice,
          );
          weeklyInserted++;
        }
        if (weeklyInserted == 0) {
          throw StateError(
            'No weekly hours could be saved. Go back and check each day’s time range.',
          );
        }
      } else {
        var specificInserted = 0;
        for (final s in d.specificSlots) {
          final b = _specificBounds(s);
          await repo.insertAvailabilitySpecificSlot(
            listingId: listing.id,
            start: b.start,
            end: b.end,
            priceHour: s.hourlyPrice ?? 0,
            priceDay: s.dailyPrice,
          );
          specificInserted++;
        }
        if (specificInserted == 0) {
          throw StateError(
            'No specific-date availability could be saved. Go back and add slots.',
          );
        }
      }

      await repo.patchListing(
        listingId: listing.id,
        isActive: true,
        isPublished: true,
        termsAccepted: true,
        termsAcceptedAt: DateTime.now(),
      );

      rollbackListingId = null;
      d.publishedSuccessfully = true;

      ref.invalidate(myListingsForCurrentUserProvider);
      ref.invalidate(mapPublishedListingsProvider);
    } catch (_) {
      final id = rollbackListingId;
      if (id != null) {
        try {
          await repo.deleteListing(id);
        } catch (_) {}
      }
      rethrow;
    } finally {
      d.publishInProgress = false;
    }
  }
}
