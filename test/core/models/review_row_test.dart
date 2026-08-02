import 'package:flutter_test/flutter_test.dart';
import 'package:parkd/core/models/review_row.dart';

void main() {
  test('ReviewRow.fromJson parses columns', () {
    final row = ReviewRow.fromJson({
      'id': 'review-1',
      'reservation_id': 'res-1',
      'reviewer_id': 'driver-1',
      'reviewee_id': 'host-1',
      'rating': 5,
      'comment': 'Great spot',
      'created_at': '2026-07-24T12:00:00Z',
    });

    expect(row.rating, 5);
    expect(row.comment, 'Great spot');
    expect(row.reservationId, 'res-1');
  });

  test('profileRatingLabel hides empty aggregates', () {
    expect(profileRatingLabel(rating: 0, ratingCount: 0), isNull);
    expect(
      profileRatingLabel(rating: 4.5, ratingCount: 3),
      '★ 4.5 (3)',
    );
  });
}
