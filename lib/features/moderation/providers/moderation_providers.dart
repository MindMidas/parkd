import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../data/moderation_repository.dart';
import '../data/supabase_moderation_repository.dart';

final moderationRepositoryProvider = Provider<ModerationRepository>((ref) {
  return SupabaseModerationRepository(ref.watch(supabaseClientProvider));
});
