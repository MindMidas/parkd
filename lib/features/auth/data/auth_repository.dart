import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/auth_remote.dart';

class AuthRepository {
  AuthRepository(SupabaseClient client) : _auth = AuthRemote(client);

  final AuthRemote _auth;

  Stream<AuthState> authStateChanges() => _auth.authStateChanges();

  Session? currentSession() => _auth.currentSession();

  bool needsMfaChallenge() => _auth.needsMfaChallenge();

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String username,
    String? phoneE164,
    DateTime? birthDate,
    String? captchaToken,
  }) {
    return _auth.signUp(
      email: email,
      password: password,
      fullName: fullName,
      username: username,
      phoneE164: phoneE164,
      birthDate: birthDate,
      captchaToken: captchaToken,
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

  Future<AuthMFAListFactorsResponse> mfaListFactors() => _auth.mfaListFactors();

  Future<void> mfaUnenroll(String factorId) => _auth.mfaUnenroll(factorId);

  Future<void> resetPasswordForEmail({
    required String email,
    String? redirectTo,
  }) {
    return _auth.resetPasswordForEmail(email: email, redirectTo: redirectTo);
  }

  Future<UserResponse> updateUserEmail(String newEmail) =>
      _auth.updateUserEmail(newEmail);

  Future<UserResponse> updatePassword(String newPassword) =>
      _auth.updatePassword(newPassword);

  Future<void> deleteCurrentAccount() => _auth.deleteCurrentAccount();

  Future<AuthResponse> verifyEmailChangeOtp({
    required String email,
    required String token,
  }) {
    return _auth.verifyEmailChangeOtp(email: email, token: token);
  }
}
