import 'package:supabase_flutter/supabase_flutter.dart';

// GoTrue / MFA only
class AuthRemote {
  AuthRemote(this._client);

  final SupabaseClient _client;

  Stream<AuthState> authStateChanges() => _client.auth.onAuthStateChange;

  Session? currentSession() => _client.auth.currentSession;

  bool needsMfaChallenge() {
    final session = _client.auth.currentSession;
    if (session == null) return false;
    final aal = _client.auth.mfa.getAuthenticatorAssuranceLevel();
    return aal.currentLevel == AuthenticatorAssuranceLevels.aal1 &&
        aal.nextLevel == AuthenticatorAssuranceLevels.aal2;
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String username,
    required String phoneE164,
    DateTime? birthDate,
  }) {
    final data = <String, dynamic>{
      'full_name': fullName.trim(),
      'username': username.trim().toLowerCase(),
      'phone': phoneE164,
    };
    if (birthDate != null) {
      final m = birthDate.month.toString().padLeft(2, '0');
      final d = birthDate.day.toString().padLeft(2, '0');
      data['birth_date'] = '${birthDate.year}-$m-$d';
    }
    return _client.auth.signUp(
      email: email,
      password: password,
      data: data,
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<ResendResponse> resendSignupEmail({required String email}) {
    return _client.auth.resend(
      type: OtpType.signup,
      email: email,
    );
  }

  Future<AuthResponse> verifySignupOtp({
    required String email,
    required String token,
  }) {
    return _client.auth.verifyOTP(
      email: email.trim(),
      token: token.trim(),
      type: OtpType.signup,
    );
  }

  Future<void> mfaRemoveUnverifiedTotpFactors() async {
    try {
      final list = await _client.auth.mfa.listFactors();
      for (final factor in list.all) {
        if (factor.factorType != FactorType.totp ||
            factor.status != FactorStatus.unverified) {
          continue;
        }
        try {
          await _client.auth.mfa.unenroll(factor.id);
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<AuthMFAEnrollResponse> mfaEnrollTotp({
    String issuer = 'Parkd',
    String friendlyName = 'Authenticator app',
  }) async {
    await mfaRemoveUnverifiedTotpFactors();
    return _client.auth.mfa.enroll(
      factorType: FactorType.totp,
      issuer: issuer,
      friendlyName: friendlyName,
    );
  }

  Future<AuthMFAVerifyResponse> mfaVerifyNewFactor({
    required String factorId,
    required String code,
  }) async {
    final challenge = await _client.auth.mfa.challenge(factorId: factorId);
    return _client.auth.mfa.verify(
      factorId: factorId,
      challengeId: challenge.id,
      code: code.trim(),
    );
  }

  Future<AuthMFAVerifyResponse> mfaChallengeAndVerify({
    required String factorId,
    required String code,
  }) {
    return _client.auth.mfa.challengeAndVerify(
      factorId: factorId,
      code: code.trim(),
    );
  }

  Future<AuthMFAListFactorsResponse> mfaListFactors() {
    return _client.auth.mfa.listFactors();
  }

  Future<void> mfaUnenroll(String factorId) {
    return _client.auth.mfa.unenroll(factorId);
  }

  Future<void> resetPasswordForEmail({
    required String email,
    String? redirectTo,
  }) {
    return _client.auth.resetPasswordForEmail(
      email,
      redirectTo: redirectTo,
    );
  }

  Future<UserResponse> updateUserEmail(String newEmail) {
    return _client.auth.updateUser(
      UserAttributes(email: newEmail.trim()),
    );
  }

  Future<AuthResponse> verifyEmailChangeOtp({
    required String email,
    required String token,
  }) {
    return _client.auth.verifyOTP(
      email: email.trim(),
      token: token.trim(),
      type: OtpType.emailChange,
    );
  }
}
