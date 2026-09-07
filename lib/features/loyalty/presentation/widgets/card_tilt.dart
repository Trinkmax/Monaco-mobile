import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Inclinación del teléfono para mover el brillo de la [MonacoCard].
///
/// Lee el acelerómetro (`sensors_plus`) y entrega un par (-1..1, -1..1) ya
/// suavizado y filtrado: la tarjeta no tiene que hacer `setState` por cada
/// muestra (el sensor manda ~20 por segundo y la mayoría no cambia nada
/// visible).
///
/// **Falla cerrado a "sin sensor"**: en el simulador de iOS el acelerómetro no
/// existe (llega un error por el canal), en `flutter test` no hay plugins y en
/// escritorio directamente no se intenta. En todos esos casos [disponible] queda
/// en `false` y la tarjeta ofrece el arrastre horizontal como reemplazo. Nunca
/// tira: el brillo es un adorno de la tarjeta, no la tarjeta.
class CardTilt {
  CardTilt._();

  /// Para tests y bancos de prueba: fuerza el camino "sin sensor" sin tocar
  /// canales de plataforma.
  static bool forzarSinSensor = false;

  /// `flutter test` corre en el host sin plugins: ni siquiera se intenta.
  static bool get _entornoConSensor {
    if (forzarSinSensor || kIsWeb) return false;
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) return false;
      return Platform.isIOS || Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  /// Empieza a escuchar. Devuelve `null` si no hay sensor en este entorno;
  /// si el sensor falla después de arrancar, llama a [onSinSensor] y se
  /// cancela solo.
  static StreamSubscription<AccelerometerEvent>? escuchar({
    required void Function(double x, double y) onTilt,
    required VoidCallback onSinSensor,
    Duration periodo = const Duration(milliseconds: 60),
  }) {
    if (!_entornoConSensor) return null;
    try {
      final stream = accelerometerEventStream(samplingPeriod: periodo);
      double sx = 0, sy = 0;
      double? lastX, lastY;
      return stream.listen(
        (e) {
          // Normaliza por g: acostado da 0, de canto ±1. Se suaviza con un
          // filtro exponencial y se descartan los cambios menores a 1 %.
          final nx = (e.x / 9.81).clamp(-1.0, 1.0);
          final ny = (e.y / 9.81).clamp(-1.0, 1.0);
          sx = sx + (nx - sx) * 0.25;
          sy = sy + (ny - sy) * 0.25;
          if (lastX != null &&
              (sx - lastX!).abs() < 0.01 &&
              (sy - lastY!).abs() < 0.01) {
            return;
          }
          lastX = sx;
          lastY = sy;
          onTilt(sx, sy);
        },
        onError: (Object e) {
          debugPrint('[loyalty] acelerómetro no disponible: $e');
          onSinSensor();
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('[loyalty] no se pudo escuchar el acelerómetro: $e');
      return null;
    }
  }
}
