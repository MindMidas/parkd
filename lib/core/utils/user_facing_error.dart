import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_error_messages.dart';

/// Short user-facing copy for list/load failures (and auth when applicable).
String userFacingErrorMessage(Object error) {
  if (error is AuthException || error is AuthWeakPasswordException) {
    return userFacingAuthMessage(error);
  }
  final raw = error.toString().trim();
  if (raw.isEmpty) {
    return 'Something went wrong. Check your connection and try again.';
  }
  // Avoid dumping stack-like strings into snackbars.
  if (raw.length > 160 || raw.contains('\n')) {
    return 'Something went wrong. Check your connection and try again.';
  }
  if (raw.startsWith('Exception: ')) {
    return raw.substring('Exception: '.length);
  }
  return raw;
}
