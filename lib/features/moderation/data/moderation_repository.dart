abstract class ModerationRepository {
  Future<String> submitReport({
    required String targetType,
    required String targetId,
    required String reason,
    String? details,
  });

  Future<void> setUserBlocked({required String userId, required bool blocked});
}
