import '../../../core/models/profile.dart';

// Profile row fetch and updates keyed by user id.
abstract class ProfileRepository {
  Future<Profile?> getProfile(String userId);

  Future<void> updateProfile({
    required String userId,
    required String fullName,
    String? phoneE164,
    DateTime? birthDate,
    String? username,
    String? email,
  });

  // Upload avatar file and set profiles.avatar_url.
  Future<void> uploadAvatar({
    required String userId,
    required String localFilePath,
  });
}
