import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _sessionKey = 'parkd.supabase.session.v1';
const _pkceKeyPrefix = 'parkd.supabase.pkce.';
const _secureStorage = FlutterSecureStorage(
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.unlocked_this_device,
  ),
  aOptions: AndroidOptions(storageNamespace: 'parkd_supabase_auth'),
);

LocalStorage createSupabaseSessionStorage() =>
    const SecureSupabaseSessionStorage();

GotrueAsyncStorage createSupabasePkceStorage() =>
    const SecureSupabasePkceStorage();

/// Stores the serialized Supabase session in Keychain/Keystore-backed storage.
class SecureSupabaseSessionStorage extends LocalStorage {
  const SecureSupabaseSessionStorage({
    FlutterSecureStorage storage = _secureStorage,
  }) : _storage = storage;

  final FlutterSecureStorage _storage;

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> accessToken() => _storage.read(key: _sessionKey);

  @override
  Future<bool> hasAccessToken() => _storage.containsKey(key: _sessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: _sessionKey, value: persistSessionString);

  @override
  Future<void> removePersistedSession() => _storage.delete(key: _sessionKey);
}

/// Protects PKCE verifiers with the same native secure-storage boundary.
class SecureSupabasePkceStorage extends GotrueAsyncStorage {
  const SecureSupabasePkceStorage({
    FlutterSecureStorage storage = _secureStorage,
  }) : _storage = storage;

  final FlutterSecureStorage _storage;

  String _key(String key) => '$_pkceKeyPrefix$key';

  @override
  Future<String?> getItem({required String key}) =>
      _storage.read(key: _key(key));

  @override
  Future<void> setItem({required String key, required String value}) =>
      _storage.write(key: _key(key), value: value);

  @override
  Future<void> removeItem({required String key}) =>
      _storage.delete(key: _key(key));
}
