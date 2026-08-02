import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/review_row.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/reviews_repository.dart';
import '../data/supabase_reviews_repository.dart';

final reviewsRepositoryProvider = Provider<ReviewsRepository>((ref) {
  return SupabaseReviewsRepository(ref.watch(supabaseClientProvider));
});

final myReviewForReservationProvider =
    FutureProvider.family<ReviewRow?, String>((ref, reservationId) async {
      final uid = ref.watch(currentSessionProvider)?.user.id;
      if (uid == null) return null;
      return ref
          .read(reviewsRepositoryProvider)
          .myReviewForReservation(
            reservationId: reservationId,
            reviewerId: uid,
          );
    });
