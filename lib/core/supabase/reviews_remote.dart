import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/review_row.dart';

class ReviewsRemote {
  ReviewsRemote(this._client);

  final SupabaseClient _client;

  Future<ReviewRow?> fetchMineForReservation({
    required String reservationId,
    required String reviewerId,
  }) async {
    final row = await _client
        .from('reviews')
        .select()
        .eq('reservation_id', reservationId)
        .eq('reviewer_id', reviewerId)
        .maybeSingle();
    if (row == null) return null;
    return ReviewRow.fromJson(Map<String, dynamic>.from(row));
  }

  Future<ReviewRow> insert({
    required String reservationId,
    required String reviewerId,
    required String revieweeId,
    required int rating,
    String? comment,
  }) async {
    final trimmed = comment?.trim();
    final payload = <String, dynamic>{
      'reservation_id': reservationId,
      'reviewer_id': reviewerId,
      'reviewee_id': revieweeId,
      'rating': rating,
      if (trimmed != null && trimmed.isNotEmpty) 'comment': trimmed,
    };
    final row = await _client.from('reviews').insert(payload).select().single();
    return ReviewRow.fromJson(Map<String, dynamic>.from(row));
  }
}
