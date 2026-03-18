import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  static const _keyDeviceSecret = 'device_secret';
  static const _keyDeviceId = 'device_id';
  static const _keyClientId = 'client_id';
  static const _keyClientName = 'client_name';
  static const _keyClientPhone = 'client_phone';
  static const _keyBiometricEnabled = 'biometric_enabled';
  static const _keyPinEnabled = 'pin_enabled';

  // Device Secret
  static Future<String> getOrCreateDeviceSecret() async {
    var secret = await _storage.read(key: _keyDeviceSecret);
    if (secret == null || secret.length < 32) {
      secret = _generateDeviceSecret();
      await _storage.write(key: _keyDeviceSecret, value: secret);
    }
    return secret;
  }

  static String _generateDeviceSecret() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return sha256.convert(bytes).toString();
  }

  // Device ID
  static Future<String> getOrCreateDeviceId() async {
    var id = await _storage.read(key: _keyDeviceId);
    if (id == null) {
      final random = Random.secure();
      final bytes = List<int>.generate(16, (_) => random.nextInt(256));
      id = base64Url.encode(bytes);
      await _storage.write(key: _keyDeviceId, value: id);
    }
    return id;
  }

  // Client info
  static Future<void> saveClientInfo({
    required String clientId,
    required String name,
    required String phone,
  }) async {
    await Future.wait([
      _storage.write(key: _keyClientId, value: clientId),
      _storage.write(key: _keyClientName, value: name),
      _storage.write(key: _keyClientPhone, value: phone),
    ]);
  }

  static Future<String?> getClientId() => _storage.read(key: _keyClientId);
  static Future<String?> getClientName() => _storage.read(key: _keyClientName);
  static Future<String?> getClientPhone() => _storage.read(key: _keyClientPhone);

  // Biometric / PIN preferences
  static Future<bool> isBiometricEnabled() async {
    final val = await _storage.read(key: _keyBiometricEnabled);
    return val == 'true';
  }

  static Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _keyBiometricEnabled, value: enabled.toString());
  }

  static Future<bool> isPinEnabled() async {
    final val = await _storage.read(key: _keyPinEnabled);
    return val == 'true';
  }

  static Future<void> setPinEnabled(bool enabled) async {
    await _storage.write(key: _keyPinEnabled, value: enabled.toString());
  }

  // Clear all on logout
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  // Clear session but keep device info
  static Future<void> clearSession() async {
    await Future.wait([
      _storage.delete(key: _keyClientId),
      _storage.delete(key: _keyClientName),
      _storage.delete(key: _keyClientPhone),
    ]);
  }
}
