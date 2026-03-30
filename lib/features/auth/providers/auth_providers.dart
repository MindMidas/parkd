import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AuthRepository(client);
});

final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return authRepository.authStateChanges();
});

final currentSessionProvider = Provider<Session?>((ref) {
  ref.watch(authStateChangesProvider);
  final authRepository = ref.watch(authRepositoryProvider);
  return authRepository.currentSession();
});

final needsMfaChallengeProvider = Provider<bool>((ref) {
  ref.watch(authStateChangesProvider);
  final authRepository = ref.watch(authRepositoryProvider);
  return authRepository.needsMfaChallenge();
});
