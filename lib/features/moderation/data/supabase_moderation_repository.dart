import 'package:supabase_flutter/supabase_flutter.dart';

import 'moderation_repository.dart';

class SupabaseModerationRepository implements ModerationRepository {
  SupabaseModerationRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<String> submitReport({
    required String targetType,
    required String targetId,
    required String reason,
    String? details,
  }) async {
    final normalizedDetails = details?.trim();
    final value = await _client.rpc(
      'submit_report',
      params: {
        'p_target_type': targetType,
        'p_target_id': targetId,
        'p_reason': reason,
        'p_details': normalizedDetails == null || normalizedDetails.isEmpty
            ? null
            : normalizedDetails,
      },
    );
    if (value is! String || value.trim().isEmpty) {
      throw StateError('Report service returned no reference.');
    }
    return value.trim();
  }

  @override
  Future<void> setUserBlocked({
    required String userId,
    required bool blocked,
  }) async {
    await _client.rpc(
      'set_user_block',
      params: {'p_blocked_user_id': userId, 'p_blocked': blocked},
    );
  }
}
