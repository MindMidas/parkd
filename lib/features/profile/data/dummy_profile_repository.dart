import '../../../core/models/profile.dart';
import 'profile_repository.dart';

/// Returns hardcoded dummy profile. Use until Supabase is wired (see database/README.md).
class DummyProfileRepository implements ProfileRepository {
  @override
  Future<Profile?> getProfile(String userId) async {
    return _dummyProfile;
  }

  static final _dummyProfile = Profile(
    id: 'user-1',
    username: 'lucasscott3',
    fullName: 'Lucas Scott',
    email: 'lucas@example.com',
    avatarUrl: null,
    rating: 0,
    ratingCount: 0,
  );
}
