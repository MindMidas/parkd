import '../../../core/models/profile.dart';

/// Abstracts fetching profile by user id (auth.uid()).
/// Implement with [DummyProfileRepository] for UI-only; replace with
/// Supabase implementation when wiring (see database/README.md).
abstract class ProfileRepository {
  Future<Profile?> getProfile(String userId);
}
