import '../../../../core/models/listing.dart';
import '../../../../core/models/search_result.dart';

// One row in the create-listing specific-date schedule UI
typedef CreateListingSpecificSlot = ({
  DateTime fromDate,
  DateTime toDate,
  String startTime,
  String endTime,
  double? hourlyPrice,
  double? dailyPrice,
});

// One row in the create-listing weekly schedule UI
typedef CreateListingWeeklySlot = ({
  String day,
  String timeRange,
  double? hourlyPrice,
  double? dailyPrice,
});

enum CreateListingAvailabilityKind { specific, weekly }

// In-memory wizard state; committed on TermsAndConditionsScreen → publish
class CreateListingDraft {
  SearchResult? picked;
  double? pinLat;
  double? pinLon;

  String? photoLocalPath;
  double? markerX;
  double? markerY;

  // Optional label (e.g. stall B2) so multiple spots at one address can coexist in DB
  String? spotNumber;

  // Airbnb-style map privacy for drivers before booking.
  ListingLocationSharing locationSharing = ListingLocationSharing.general;

  CreateListingAvailabilityKind? availabilityKind;
  final List<CreateListingSpecificSlot> specificSlots = [];
  final List<CreateListingWeeklySlot> weeklySlots = [];

  // Prevents overlapping CreateListingPublish.submit calls on the same draft
  bool publishInProgress = false;

  // Set after a successful publish so Terms cannot submit twice
  bool publishedSuccessfully = false;

  String get addressLine {
    final r = picked;
    if (r == null) return '';
    return r.houseNumber.isNotEmpty
        ? '${r.houseNumber} ${r.road}'
        : (r.road.isNotEmpty ? r.road : r.displayName.split(',').first.trim());
  }

  String get cityLine {
    final r = picked;
    if (r == null) return 'Unknown';
    var c = r.city.trim();
    if (c.isNotEmpty) return c;
    c = r.state.trim();
    if (c.isNotEmpty) return c;
    final parts = r.displayName
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.length > 1) return parts[1];
    if (parts.isNotEmpty) return parts.first;
    return 'Unknown';
  }

  String? get postalCode {
    final p = picked?.postcode.trim();
    if (p == null || p.isEmpty) return null;
    return p;
  }

  bool get isCompleteForPublish {
    return picked != null &&
        pinLat != null &&
        pinLon != null &&
        photoLocalPath != null &&
        photoLocalPath!.isNotEmpty &&
        markerX != null &&
        markerY != null &&
        availabilityKind != null &&
        (availabilityKind == CreateListingAvailabilityKind.specific
            ? specificSlots.isNotEmpty
            : weeklySlots.isNotEmpty);
  }
}
