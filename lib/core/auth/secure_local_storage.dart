import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Persiste la sesión de Supabase (access/refresh token) en el Keychain de
/// iOS / EncryptedSharedPreferences de Android, en vez de las SharedPreferences
/// planas que usa `supabase_flutter` por defecto. Es la misma caja fuerte donde
/// vive el `device_secret`, así los dos storages no se desincronizan.
class SecureLocalStorage extends LocalStorage {
  static const _key = 'monaco_supabase_session';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> accessToken() => _storage.read(key: _key);

  @override
  Future<bool> hasAccessToken() async =>
      (await _storage.read(key: _key)) != null;

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: _key, value: persistSessionString);

  @override
  Future<void> removePersistedSession() => _storage.delete(key: _key);
}
