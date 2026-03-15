import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/availability_specific.dart';
import '../../../core/models/availability_weekly.dart';
import '../../../core/models/listing.dart';
import '../../../core/models/listing_photo.dart';
import '../../../core/models/profile.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/dummy_listings_repository.dart';
import '../data/dummy_profile_repository.dart';
import '../data/listings_repository.dart';
import '../data/profile_repository.dart';

/// Repository implementations. Swap Dummy* for Supabase* when wiring (see database/README.md).
final listingsRepositoryProvider = Provider<ListingsRepository>((ref) {
  return DummyListingsRepository();
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return DummyProfileRepository();
});

/// Current user's profile. All profile screens should use this for display data.
final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  final session = ref.watch(currentSessionProvider);
  final userId = session?.user.id;
  if (userId == null) return null;
  return ref.read(profileRepositoryProvider).getProfile(userId);
});

/// Current user's listings (host). Uses current session; use for Manage Listings screen.
final myListingsForCurrentUserProvider = FutureProvider<List<Listing>>((ref) async {
  final session = ref.watch(currentSessionProvider);
  final userId = session?.user.id;
  if (userId == null) return [];
  return ref.read(listingsRepositoryProvider).getMyListings(userId);
});

/// Single listing by id. Use for Edit Listing and any screen that needs one listing.
final listingByIdProvider =
    FutureProvider.family<Listing?, String>((ref, id) async {
  return ref.read(listingsRepositoryProvider).getListingById(id);
});

/// Photos for a listing (hero/gallery). Use for Edit Listing photo row.
final listingPhotosProvider =
    FutureProvider.family<List<ListingPhoto>, String>((ref, listingId) async {
  return ref.read(listingsRepositoryProvider).getListingPhotos(listingId);
});

/// Weekly availability for a listing. Use for Edit Listing availability section.
final listingAvailabilityWeeklyProvider =
    FutureProvider.family<List<AvailabilityWeekly>, String>((ref, listingId) async {
  return ref.read(listingsRepositoryProvider).getAvailabilityWeekly(listingId);
});

/// Specific (date-range) availability for a listing. Use for Edit Listing availability section.
final listingAvailabilitySpecificProvider =
    FutureProvider.family<List<AvailabilitySpecific>, String>((ref, listingId) async {
  return ref.read(listingsRepositoryProvider).getAvailabilitySpecific(listingId);
});
