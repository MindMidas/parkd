import '../../../core/models/profile.dart';

/// Abstracts fetching profile by user id (auth.uid())
abstract class ProfileRepository {
  Future<Profile?> getProfile(String userId);

  Future<void> updateProfile({
    required String userId,
    required String fullName,
    String? phoneE164,
    DateTime? birthDate,
    String? username,
  });

  /// Uploads a new avatar image and updates [profiles.avatar_url]
  Future<void> uploadAvatar({
    required String userId,
    required String localFilePath,
  });
}
