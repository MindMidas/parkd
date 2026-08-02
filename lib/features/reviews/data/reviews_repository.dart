import '../../../core/models/review_row.dart';

abstract class ReviewsRepository {
  Future<ReviewRow?> myReviewForReservation({
    required String reservationId,
    required String reviewerId,
  });

  Future<ReviewRow> submitReview({
    required String reservationId,
    required String reviewerId,
    required String revieweeId,
    required int rating,
    String? comment,
  });
}
