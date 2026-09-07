import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Sonido + háptica de "confirmado", al estilo de las apps de pedidos: un
/// "ta-da" corto de dos notas ascendentes (`assets/sounds/confirmacion.wav`,
/// generado por nosotros: G5 → C6, ~0,9 s) que acompaña al velo verde.
///
/// Reglas:
/// - Respeta el switch de silencio de iOS (`ambient` + `mixWithOthers`): es un
///   sonido de interfaz, no música. En Android va como `sonification` sin
///   pedir foco de audio, así no corta Spotify ni un audio de WhatsApp.
/// - Nunca tira: si el audio falla (sin asset, sin salida), la animación sigue
///   igual. El feedback es un adorno de la confirmación, no la confirmación.
/// - Un solo `AudioPlayer` reutilizado (modo baja latencia): crearlo por
///   reproducción en iOS tardaba más que el propio sonido.
class FeedbackConfirmacion {
  FeedbackConfirmacion._();

  static AudioPlayer? _player;
  static bool _configurado = false;

  static Future<AudioPlayer> _obtenerPlayer() async {
    final existente = _player;
    if (existente != null && _configurado) return existente;
    final p = existente ?? AudioPlayer(playerId: 'monaco-confirmacion');
    _player = p;
    try {
      await p.setAudioContext(
        AudioContext(
          // `ambient` YA mezcla con lo que esté sonando y respeta el switch de
          // silencio; pedir además `mixWithOthers` dispara un assert de
          // audioplayers ("sólo con playback/playAndRecord/multiRoute") que
          // hacía fallar la configuración entera y dejaba el "ta-da" mudo en
          // todos los iPhone. Se ve en el log de cualquier corrida del banco
          // visual: "[feedback] no se pudo configurar el audio".
          iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
          android: const AudioContextAndroid(
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.assistanceSonification,
            audioFocus: AndroidAudioFocus.none,
          ),
        ),
      );
      await p.setPlayerMode(PlayerMode.lowLatency);
      await p.setReleaseMode(ReleaseMode.stop);
      _configurado = true;
    } catch (e) {
      debugPrint('[feedback] no se pudo configurar el audio: $e');
    }
    return p;
  }

  /// Háptica media + sonido. Llamar en el momento en que el tilde empieza a
  /// dibujarse (ver `ConfirmacionVerde`).
  static Future<void> reproducir() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
    try {
      final p = await _obtenerPlayer();
      await p.stop();
      await p.play(AssetSource('sounds/confirmacion.wav'), volume: 1.0);
    } catch (e) {
      debugPrint('[feedback] no se pudo reproducir el sonido: $e');
    }
  }

  /// Segundo toque háptico, más suave, cuando el tilde termina de trazarse.
  static Future<void> remate() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }
}
