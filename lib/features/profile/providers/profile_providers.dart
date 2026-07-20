import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/availability_specific.dart';
import '../../../core/models/availability_weekly.dart';
import '../../../core/models/listing.dart';
import '../../../core/models/listing_photo.dart';
import '../../../core/models/payment_method_row.dart';
import '../../../core/models/profile.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/listings_repository.dart';
import '../data/payment_methods_repository.dart';
import '../data/profile_repository.dart';
import '../data/supabase_listings_repository.dart';
import '../data/supabase_payment_methods_repository.dart';
import '../data/supabase_profile_repository.dart';

final listingsRepositoryProvider = Provider<ListingsRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseListingsRepository(client);
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseProfileRepository(client);
});

final paymentMethodsRepositoryProvider = Provider<PaymentMethodsRepository>((
  ref,
) {
  return SupabasePaymentMethodsRepository(ref.watch(supabaseClientProvider));
});

final profileByUserIdProvider = FutureProvider.family<Profile?, String>((
  ref,
  userId,
) async {
  return ref.read(profileRepositoryProvider).getProfile(userId);
});

final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  final session = ref.watch(currentSessionProvider);
  final userId = session?.user.id;
  if (userId == null) return null;
  return ref.read(profileRepositoryProvider).getProfile(userId);
});

final paymentMethodsForCurrentUserProvider =
    FutureProvider<List<PaymentMethodRow>>((ref) async {
      final uid = ref.watch(currentSessionProvider)?.user.id;
      if (uid == null) return [];
      return ref.read(paymentMethodsRepositoryProvider).listForUser(uid);
    });

final myListingsForCurrentUserProvider = FutureProvider<List<Listing>>((
  ref,
) async {
  final session = ref.watch(currentSessionProvider);
  final userId = session?.user.id;
  if (userId == null) return [];
  return ref.read(listingsRepositoryProvider).getMyListings(userId);
});

final listingByIdProvider = FutureProvider.family<Listing?, String>((
  ref,
  id,
) async {
  return ref.read(listingsRepositoryProvider).getListingById(id);
});

final listingPhotosProvider = FutureProvider.family<List<ListingPhoto>, String>(
  (ref, listingId) async {
    return ref.read(listingsRepositoryProvider).getListingPhotos(listingId);
  },
);

final listingAvailabilityWeeklyProvider =
    FutureProvider.family<List<AvailabilityWeekly>, String>((
      ref,
      listingId,
    ) async {
      return ref
          .read(listingsRepositoryProvider)
          .getAvailabilityWeekly(listingId);
    });

final listingAvailabilitySpecificProvider =
    FutureProvider.family<List<AvailabilitySpecific>, String>((
      ref,
      listingId,
    ) async {
      return ref
          .read(listingsRepositoryProvider)
          .getAvailabilitySpecific(listingId);
    });

/// Refetch profile everywhere it is shown (account, edit form, chats, trip cards)
void invalidateProfileSurfaces(WidgetRef ref, String userId) {
  ref.invalidate(currentProfileProvider);
  ref.invalidate(profileByUserIdProvider(userId));
}
