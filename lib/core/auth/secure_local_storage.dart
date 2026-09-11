import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Persiste la sesión de Supabase (access/refresh token) en el Keychain de
/// iOS / EncryptedSharedPreferences de Android, en vez de las SharedPreferences
/// planas que usa `supabase_flutter` por defecto. Es la misma caja fuerte donde
/// vive el `device_secret`, así los dos storages no se desincronizan.
///
/// **Ninguna lectura ni escritura de acá tira.** `supabase_flutter` llama a
/// [hasAccessToken] dentro de `Supabase.initialize` SIN try/catch: un blob que
/// no se puede descifrar (Keystore de Android invalidado tras un update de OS o
/// un cambio de bloqueo de pantalla) hacía que `initialize` reventara antes de
/// `runApp` y la app quedara en pantalla negra en cada apertura, para siempre.
/// Acá un fallo de lectura se trata como "no hay sesión" (el cliente vuelve a
/// entrar con el código, que es el comportamiento aceptado) y un fallo de
/// escritura se loguea (la sesión vive en memoria hasta cerrar la app).
///
/// La detección de un almacenamiento ROTO —para limpiarlo y reintentar— no es
/// de acá sino de `main.dart`, que antes de inicializar Supabase hace una
/// lectura de prueba con [comprobarLectura] (ésa sí propaga el error).
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
  Future<String?> accessToken() => _leer();

  @override
  Future<bool> hasAccessToken() async => (await _leer()) != null;

  @override
  Future<void> persistSession(String persistSessionString) async {
    try {
      await _storage.write(key: _key, value: persistSessionString);
    } catch (e) {
      debugPrint('[storage] no se pudo guardar la sesión: $e');
    }
  }

  @override
  Future<void> removePersistedSession() async {
    try {
      await _storage.delete(key: _key);
    } catch (e) {
      debugPrint('[storage] no se pudo borrar la sesión: $e');
    }
  }

  Future<String?> _leer() async {
    try {
      return await _storage.read(key: _key);
    } catch (e) {
      debugPrint('[storage] no se pudo leer la sesión (se ignora): $e');
      return null;
    }
  }

  // ── Lo que usa el arranque ───────────────────────────────────────────────

  /// Lectura de prueba que **sí tira** si el almacenamiento seguro está roto.
  /// `main.dart` la corre antes de `Supabase.initialize` para decidir si hay
  /// que limpiar y reintentar; no la usa nadie más.
  static Future<void> comprobarLectura() => _storage.read(key: _key);

  /// Hay una sesión de Supabase guardada. Lo mira el guard de reinstalación:
  /// en iOS el Keychain sobrevive a desinstalar la app, así que "hay sesión
  /// pero no hay marca de instalación" significa "es de una instalación
  /// anterior".
  static Future<bool> tieneSesionGuardada() async =>
      (await _storage.read(key: _key)) != null;

  /// Borra la sesión guardada. Tira si el almacenamiento está roto (quien lo
  /// llama decide qué hacer con eso).
  static Future<void> borrarSesionGuardada() => _storage.delete(key: _key);
}
