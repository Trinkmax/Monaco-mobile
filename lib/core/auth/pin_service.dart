import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../utils/constants.dart';
import 'secure_storage.dart';

/// PIN **local** de 4 dígitos: un gate de pantalla, no una credencial.
///
/// Antes se guardaba en el server (`set_client_pin` / `verify_client_pin`);
/// ahora vive sólo en el dispositivo como `sha256(pin + device_id)` dentro del
/// Keychain / EncryptedSharedPreferences. El `device_id` actúa de sal: el mismo
/// PIN en dos teléfonos da hashes distintos, y un hash filtrado no sirve sin el
/// dispositivo. Nada de esto viaja a Supabase.
class PinService {
  PinService._();

  static const int length = AppConstants.pinLength;

  /// `true` si el PIN tiene exactamente [length] dígitos.
  static bool isValidFormat(String pin) =>
      pin.length == length && RegExp(r'^\d+$').hasMatch(pin);

  static Future<String> _hash(String pin) async {
    final deviceId = await SecureStorageService.getOrCreateDeviceId();
    return sha256.convert(utf8.encode(pin + deviceId)).toString();
  }

  /// Hay un PIN configurado en este dispositivo.
  static Future<bool> hasPin() async =>
      (await SecureStorageService.getLocalPinHash()) != null;

  /// El gate de PIN está activo (hay hash guardado y la preferencia prendida).
  static Future<bool> isEnabled() async {
    final enabled = await SecureStorageService.isPinEnabled();
    return enabled && await hasPin();
  }

  /// Guarda el PIN (reemplaza el anterior si había) y prende el gate.
  static Future<void> setPin(String pin) async {
    if (!isValidFormat(pin)) {
      throw ArgumentError('El PIN debe tener $length dígitos');
    }
    await SecureStorageService.setLocalPinHash(await _hash(pin));
    await SecureStorageService.setPinEnabled(true);
  }

  /// Compara contra el hash guardado en tiempo constante.
  static Future<bool> verifyPin(String pin) async {
    if (!isValidFormat(pin)) return false;
    final stored = await SecureStorageService.getLocalPinHash();
    if (stored == null) return false;
    return _constantTimeEquals(stored, await _hash(pin));
  }

  /// Borra el PIN y apaga el gate.
  static Future<void> removePin() async {
    await SecureStorageService.setLocalPinHash(null);
    await SecureStorageService.setPinEnabled(false);
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
