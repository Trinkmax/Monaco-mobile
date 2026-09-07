import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const _keyDeviceSecret = 'device_secret';
  static const _keyDeviceId = 'device_id';
  static const _keyClientId = 'client_id';
  static const _keyClientName = 'client_name';
  static const _keyClientPhone = 'client_phone';
  static const _keyBiometricEnabled = 'biometric_enabled';
  static const _keyPinEnabled = 'pin_enabled';
  static const _keyTestMode = 'test_mode_enabled';
  static const _keyLocalPinHash = 'local_pin_hash';
  static const _keySelectedBranchId = 'selected_branch_id';
  static const _keySelectedBranchName = 'selected_branch_name';
  static const _keySelectedBranchOperationMode =
      'selected_branch_operation_mode';
  static const _keySelectedBranchSlug = 'selected_branch_slug';
  static const _keyLoyaltyLastTierSeen = 'loyalty_last_tier_seen';
  static const _keyGuestMode = 'guest_mode';
  static const _keySenaPendiente = 'sena_pendiente';

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
  static Future<String?> getClientPhone() =>
      _storage.read(key: _keyClientPhone);

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

  // Modo prueba (muestra la sucursal Test)
  static Future<bool> isTestModeEnabled() async =>
      (await _storage.read(key: _keyTestMode)) == 'true';

  static Future<void> setTestModeEnabled(bool enabled) =>
      _storage.write(key: _keyTestMode, value: enabled.toString());

  // PIN local (hash sha256 con sal del dispositivo)
  static Future<String?> getLocalPinHash() =>
      _storage.read(key: _keyLocalPinHash);
  static Future<void> setLocalPinHash(String? hash) => hash == null
      ? _storage.delete(key: _keyLocalPinHash)
      : _storage.write(key: _keyLocalPinHash, value: hash);

  // ── Fidelización: última categoría que el cliente VIO ───────────────────
  // Sirve para festejar una subida de categoría una sola vez (ver
  // `TierUpCelebration`). Se borra con la sesión: el próximo cliente que entre
  // en este equipo no tiene que heredar la categoría del anterior.
  static Future<String?> getLoyaltyLastTierSeen() =>
      _storage.read(key: _keyLoyaltyLastTierSeen);

  static Future<void> setLoyaltyLastTierSeen(String? code) => code == null
      ? _storage.delete(key: _keyLoyaltyLastTierSeen)
      : _storage.write(key: _keyLoyaltyLastTierSeen, value: code);

  // ── Seña en curso ───────────────────────────────────────────────────────
  // JSON con el `deposit_id` de la seña que el cliente fue a pagar. Existe por
  // una razón concreta: mientras paga, la app está en segundo plano y iOS
  // puede matarla. Si al volver no queda rastro del pago, el cliente tiene un
  // cobro hecho y ninguna pantalla que se lo explique.
  //
  // No es un secreto (el id ya viaja en la URL del checkout), pero va acá
  // porque es el almacenamiento que la app ya tiene y porque se borra con la
  // sesión: el próximo cliente que use este equipo no hereda un pago ajeno.
  static Future<String?> getSenaPendiente() =>
      _storage.read(key: _keySenaPendiente);

  static Future<void> setSenaPendiente(String? json) => json == null
      ? _storage.delete(key: _keySenaPendiente)
      : _storage.write(key: _keySenaPendiente, value: json);

  // ── Modo invitado ────────────────────────────────────────────────────────
  // "Seguir mirando" tiene que sobrevivir a cerrar la app: si no, el que entró
  // sin cuenta se come el muro de bienvenida en cada arranque, que es
  // exactamente lo que la guideline 5.1.1 pide no hacer.
  static Future<bool> isGuestMode() async =>
      (await _storage.read(key: _keyGuestMode)) == 'true';

  static Future<void> setGuestMode(bool enabled) => enabled
      ? _storage.write(key: _keyGuestMode, value: 'true')
      : _storage.delete(key: _keyGuestMode);

  // ── Sucursal elegida — LEGADO ────────────────────────────────────────────
  // La app dejó de tener sucursal global (24/ago/2026): la sucursal se elige en
  // el primer paso de la reserva y no se persiste. Estas 4 keys ya no se
  // escriben ni se leen; lo único que queda es borrarlas, y se hace una vez en
  // `AuthNotifier._init()` para no dejar residuo en el Keychain de los equipos
  // que ya tenían la app instalada.
  static Future<void> clearSelectedBranch() async {
    await Future.wait([
      _storage.delete(key: _keySelectedBranchId),
      _storage.delete(key: _keySelectedBranchName),
      _storage.delete(key: _keySelectedBranchOperationMode),
      _storage.delete(key: _keySelectedBranchSlug),
    ]);
  }

  // Clear all on logout
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  /// Borra todo lo de la SESIÓN y conserva la identidad del DISPOSITIVO
  /// (`device_id` y `device_secret`).
  ///
  /// **El `device_secret` no se rota al cerrar sesión a propósito**: es la
  /// password del usuario de Auth y es lo que habilita el login silencioso
  /// (`start` devuelve la sesión sin mandar código si coincide). Rotarlo acá
  /// obligaría a un OTP por WhatsApp en cada re-ingreso desde el mismo teléfono.
  ///
  /// **Sí se borran el PIN y la biometría**: son gates de ESTA cuenta en ESTE
  /// equipo. Antes sobrevivían al logout, así que el que entraba después
  /// —cuenta nueva o cuenta de otro— se encontraba con el candado del anterior
  /// y sin forma de abrirlo (el PIN es un hash local, no hay "olvidé mi PIN").
  static Future<void> clearSession() async {
    await Future.wait([
      _storage.delete(key: _keyClientId),
      _storage.delete(key: _keyClientName),
      _storage.delete(key: _keyClientPhone),
      _storage.delete(key: _keyPinEnabled),
      _storage.delete(key: _keyLocalPinHash),
      _storage.delete(key: _keyBiometricEnabled),
      _storage.delete(key: _keyGuestMode),
      _storage.delete(key: _keySelectedBranchId),
      _storage.delete(key: _keySelectedBranchName),
      _storage.delete(key: _keySelectedBranchOperationMode),
      _storage.delete(key: _keySelectedBranchSlug),
      _storage.delete(key: _keyLoyaltyLastTierSeen),
      _storage.delete(key: _keySenaPendiente),
    ]);
  }
}
