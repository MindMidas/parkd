// Mirrors public.reviews
class ReviewRow {
  const ReviewRow({
    required this.id,
    required this.reservationId,
    required this.reviewerId,
    required this.revieweeId,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  final String id;
  final String reservationId;
  final String reviewerId;
  final String revieweeId;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  static ReviewRow fromJson(Map<String, dynamic> json) {
    return ReviewRow(
      id: json['id'] as String,
      reservationId: json['reservation_id'] as String,
      reviewerId: json['reviewer_id'] as String,
      revieweeId: json['reviewee_id'] as String,
      rating: (json['rating'] as num).toInt(),
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'reservation_id': reservationId,
    'reviewer_id': reviewerId,
    'reviewee_id': revieweeId,
    'rating': rating,
    'comment': comment,
    'created_at': createdAt.toIso8601String(),
  };
}

// Label for profile rating aggregates.
String? profileRatingLabel({required double rating, required int ratingCount}) {
  if (ratingCount <= 0) return null;
  return '★ ${rating.toStringAsFixed(1)} ($ratingCount)';
}
