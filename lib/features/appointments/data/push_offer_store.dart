import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// ¿Ya le ofrecimos los avisos de turno a este dispositivo?
///
/// Hace falta una marca local **porque el estado del permiso no alcanza**: en
/// iOS `notDetermined` dice "nunca se preguntó", pero en Android
/// `getNotificationSettings()` sólo devuelve `authorized` o `denied` —no existe
/// el "todavía no"—, así que sin esto no habría forma de distinguir a quien
/// dijo que no de quien nunca vio la oferta, y le preguntaríamos después de
/// cada reserva.
///
/// Se guarda en el llavero (mismas opciones que el resto de la app) y **se
/// marca aunque el cliente diga "Ahora no"**: la oferta contextual es una sola,
/// para siempre. El camino permanente para activarlas sigue siendo Perfil →
/// Notificaciones.
class PushOfrecidoStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const _key = 'push_ofrecido_tras_reserva';

  const PushOfrecidoStore();

  /// `true` = no volver a ofrecer.
  ///
  /// Si el llavero falla se contesta `true` a propósito (falla CERRADA): el
  /// costo de no ofrecer es una notificación menos; el de ofrecer en loop es
  /// un diálogo después de cada reserva.
  Future<bool> yaSeOfrecio() async {
    try {
      return (await _storage.read(key: _key)) == '1';
    } catch (e) {
      debugPrint('[push] no se pudo leer la marca de oferta: $e');
      return true;
    }
  }

  Future<void> marcarOfrecido() async {
    try {
      await _storage.write(key: _key, value: '1');
    } catch (e) {
      debugPrint('[push] no se pudo guardar la marca de oferta: $e');
    }
  }
}

final pushOfrecidoStoreProvider = Provider<PushOfrecidoStore>(
  (ref) => const PushOfrecidoStore(),
);
