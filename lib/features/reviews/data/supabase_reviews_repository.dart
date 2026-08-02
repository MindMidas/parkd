import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/review_row.dart';
import '../../../core/supabase/reviews_remote.dart';
import 'reviews_repository.dart';

class SupabaseReviewsRepository implements ReviewsRepository {
  SupabaseReviewsRepository(SupabaseClient client) : _remote = ReviewsRemote(client);

  final ReviewsRemote _remote;

  @override
  Future<ReviewRow?> myReviewForReservation({
    required String reservationId,
    required String reviewerId,
  }) =>
      _remote.fetchMineForReservation(
        reservationId: reservationId,
        reviewerId: reviewerId,
      );

  @override
  Future<ReviewRow> submitReview({
    required String reservationId,
    required String reviewerId,
    required String revieweeId,
    required int rating,
    String? comment,
  }) =>
      _remote.insert(
        reservationId: reservationId,
        reviewerId: reviewerId,
        revieweeId: revieweeId,
        rating: rating,
        comment: comment,
      );
}
