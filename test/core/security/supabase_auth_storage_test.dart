import 'package:flutter_test/flutter_test.dart';
import 'package:parkd/core/security/supabase_auth_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('native auth factories avoid shared-preferences session storage', () {
    final sessionStorage = createSupabaseSessionStorage();
    final pkceStorage = createSupabasePkceStorage();

    expect(sessionStorage, isA<LocalStorage>());
    expect(sessionStorage, isNot(isA<SharedPreferencesLocalStorage>()));
    expect(pkceStorage, isA<GotrueAsyncStorage>());
  });
}
