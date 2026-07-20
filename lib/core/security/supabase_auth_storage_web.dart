import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web/web.dart' as web;

const _sessionKey = 'parkd.supabase.session.v1';
const _pkceKeyPrefix = 'parkd.supabase.pkce.';

LocalStorage createSupabaseSessionStorage() =>
    const SessionSupabaseSessionStorage();

GotrueAsyncStorage createSupabasePkceStorage() =>
    const SessionSupabasePkceStorage();

/// Keeps demo authentication scoped to the current browser tab.
///
/// Session storage survives redirects and refreshes needed by PKCE, but is
/// discarded when the tab closes instead of persisting indefinitely.
class SessionSupabaseSessionStorage extends LocalStorage {
  const SessionSupabaseSessionStorage();

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> accessToken() async =>
      web.window.sessionStorage.getItem(_sessionKey);

  @override
  Future<bool> hasAccessToken() async =>
      web.window.sessionStorage.getItem(_sessionKey) != null;

  @override
  Future<void> persistSession(String persistSessionString) async {
    web.window.sessionStorage.setItem(_sessionKey, persistSessionString);
  }

  @override
  Future<void> removePersistedSession() async {
    web.window.sessionStorage.removeItem(_sessionKey);
  }
}

class SessionSupabasePkceStorage extends GotrueAsyncStorage {
  const SessionSupabasePkceStorage();

  String _key(String key) => '$_pkceKeyPrefix$key';

  @override
  Future<String?> getItem({required String key}) async =>
      web.window.sessionStorage.getItem(_key(key));

  @override
  Future<void> setItem({required String key, required String value}) async {
    web.window.sessionStorage.setItem(_key(key), value);
  }

  @override
  Future<void> removeItem({required String key}) async {
    web.window.sessionStorage.removeItem(_key(key));
  }
}
