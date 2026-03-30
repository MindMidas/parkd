import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/auth_remote.dart';
import '../../../core/supabase/profiles_remote.dart';

class AuthRepository {
  AuthRepository(SupabaseClient client)
      : _auth = AuthRemote(client),
        _profiles = ProfilesRemote(client);

  final AuthRemote _auth;
  final ProfilesRemote _profiles;

  Stream<AuthState> authStateChanges() => _auth.authStateChanges();

  Session? currentSession() => _auth.currentSession();

  bool needsMfaChallenge() => _auth.needsMfaChallenge();

  Future<bool> isPhoneAvailable(String phoneE164) =>
      _profiles.isPhoneAvailable(phoneE164);

  Future<bool> isUsernameAvailable(String username) =>
      _profiles.isUsernameAvailable(username);

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String username,
    required String phoneE164,
    DateTime? birthDate,
  }) {
    return _auth.signUp(
      email: email,
      password: password,
      fullName: fullName,
      username: username,
      phoneE164: phoneE164,
      birthDate: birthDate,
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signIn(email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();

  Future<ResendResponse> resendSignupEmail({required String email}) {
    return _auth.resendSignupEmail(email: email);
  }

  Future<AuthResponse> verifySignupOtp({
    required String email,
    required String token,
  }) {
    return _auth.verifySignupOtp(email: email, token: token);
  }

  Future<void> mfaRemoveUnverifiedTotpFactors() =>
      _auth.mfaRemoveUnverifiedTotpFactors();

  Future<AuthMFAEnrollResponse> mfaEnrollTotp({
    String issuer = 'Parkd',
    String friendlyName = 'Authenticator app',
  }) {
    return _auth.mfaEnrollTotp(issuer: issuer, friendlyName: friendlyName);
  }

  Future<AuthMFAVerifyResponse> mfaVerifyNewFactor({
    required String factorId,
    required String code,
  }) {
    return _auth.mfaVerifyNewFactor(factorId: factorId, code: code);
  }

  Future<AuthMFAVerifyResponse> mfaChallengeAndVerify({
    required String factorId,
    required String code,
  }) {
    return _auth.mfaChallengeAndVerify(factorId: factorId, code: code);
  }

  Future<AuthMFAListFactorsResponse> mfaListFactors() =>
      _auth.mfaListFactors();

  Future<void> mfaUnenroll(String factorId) => _auth.mfaUnenroll(factorId);

  Future<void> resetPasswordForEmail({
    required String email,
    String? redirectTo,
  }) {
    return _auth.resetPasswordForEmail(email: email, redirectTo: redirectTo);
  }

  Future<UserResponse> updateUserEmail(String newEmail) =>
      _auth.updateUserEmail(newEmail);

  Future<AuthResponse> verifyEmailChangeOtp({
    required String email,
    required String token,
  }) {
    return _auth.verifyEmailChangeOtp(email: email, token: token);
  }
}
