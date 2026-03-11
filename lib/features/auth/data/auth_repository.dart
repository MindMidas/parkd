import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Stream<AuthState> authStateChanges() {
    return _client.auth.onAuthStateChange;
  }

  Session? currentSession() {
    return _client.auth.currentSession;
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) {
    return _client.auth.signUp(email: email, password: password);
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() {
    return _client.auth.signOut();
  }

  Future<ResendResponse> resendSignupEmail({
    required String email,
  }) {
    return _client.auth.resend(
      type: OtpType.signup,
      email: email,
    );
  }
}
