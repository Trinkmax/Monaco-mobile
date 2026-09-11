import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:monaco_mobile/core/push/push_service.dart';

/// El mapeo del estado crudo de FCM al estado que dibuja la UI.
///
/// El caso que motivó todo esto: en Android el plugin no tiene
/// `notDetermined` — `getPermissions()` contesta `areNotificationsEnabled ? 1
/// : 0` y el 0 se traduce a [AuthorizationStatus.denied]. O sea que una
/// instalación limpia de Android 13+ ya se lee `denied`, y la app lo trataba
/// como "bloqueado en el sistema": el diálogo de POST_NOTIFICATIONS no se
/// disparaba nunca y no se registraba ningún token.
void main() {
  PushPermiso android(AuthorizationStatus? status, {required bool yaSePidio}) =>
      PushService.mapearPermiso(
        disponible: true,
        status: status,
        yaSePidio: yaSePidio,
        esAndroid: true,
      );

  PushPermiso ios(AuthorizationStatus? status, {required bool yaSePidio}) =>
      PushService.mapearPermiso(
        disponible: true,
        status: status,
        yaSePidio: yaSePidio,
        esAndroid: false,
      );

  test('sin Firebase configurado, nada que mostrar', () {
    expect(
      PushService.mapearPermiso(
        disponible: false,
        status: null,
        yaSePidio: false,
        esAndroid: true,
      ),
      PushPermiso.noDisponible,
    );
    // Ni siquiera un permiso concedido lo cambia: sin Firebase no hay push.
    expect(
      PushService.mapearPermiso(
        disponible: false,
        status: AuthorizationStatus.authorized,
        yaSePidio: true,
        esAndroid: false,
      ),
      PushPermiso.noDisponible,
    );
  });

  test('Android: el denied de fábrica es "sin pedir", no "bloqueado"', () {
    expect(
      android(AuthorizationStatus.denied, yaSePidio: false),
      PushPermiso.sinPedir,
    );
  });

  test('Android: denied DESPUÉS de pedirlo sí es bloqueado', () {
    expect(
      android(AuthorizationStatus.denied, yaSePidio: true),
      PushPermiso.bloqueado,
    );
  });

  test('Android: concedido', () {
    expect(
      android(AuthorizationStatus.authorized, yaSePidio: true),
      PushPermiso.concedido,
    );
    // Y también si nunca pasamos por nuestro prompt (permiso heredado de una
    // versión anterior de la app, o Android < 13).
    expect(
      android(AuthorizationStatus.authorized, yaSePidio: false),
      PushPermiso.concedido,
    );
  });

  test('iOS: notDetermined es "sin pedir"; denied es bloqueado', () {
    expect(
      ios(AuthorizationStatus.notDetermined, yaSePidio: false),
      PushPermiso.sinPedir,
    );
    // En iOS el estado de fábrica es notDetermined, así que un denied implica
    // un prompt ya contestado aunque nosotros no tengamos la marca.
    expect(
      ios(AuthorizationStatus.denied, yaSePidio: false),
      PushPermiso.bloqueado,
    );
    expect(
      ios(AuthorizationStatus.denied, yaSePidio: true),
      PushPermiso.bloqueado,
    );
  });

  test('provisional cuenta como concedido (llegan silenciosas)', () {
    expect(
      ios(AuthorizationStatus.provisional, yaSePidio: true),
      PushPermiso.concedido,
    );
    expect(PushService.isGranted(AuthorizationStatus.provisional), isTrue);
    expect(PushService.isGranted(AuthorizationStatus.denied), isFalse);
    expect(PushService.isGranted(null), isFalse);
  });

  test('el plugin sin respuesta no se lee como bloqueado', () {
    // Simulador de iOS sin APNs: `getNotificationSettings` tira y devolvemos
    // null. Decir "bloqueado" ahí manda al cliente a Ajustes por nada.
    expect(ios(null, yaSePidio: false), PushPermiso.desconocido);
    expect(android(null, yaSePidio: true), PushPermiso.desconocido);
  });
}
