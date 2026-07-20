import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/profiles_remote.dart';
import '../../../core/models/profile.dart';
import 'profile_repository.dart';

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(SupabaseClient client)
    : _remote = ProfilesRemote(client);

  final ProfilesRemote _remote;

  @override
  Future<Profile?> getProfile(String userId) => _remote.fetchById(userId);

  @override
  Future<void> updateProfile({
    required String userId,
    required String fullName,
    String? phoneE164,
    DateTime? birthDate,
    String? username,
  }) {
    return _remote.updateProfile(
      userId: userId,
      fullName: fullName,
      phoneE164: phoneE164,
      birthDate: birthDate,
      username: username,
    );
  }

  @override
  Future<void> uploadAvatar({
    required String userId,
    required String localFilePath,
  }) {
    return _remote.uploadAvatarFromLocalPath(
      userId: userId,
      localFilePath: localFilePath,
    );
  }
}
