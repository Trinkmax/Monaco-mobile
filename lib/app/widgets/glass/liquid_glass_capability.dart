import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Interruptor global del vidrio **con shaders** (`liquid_glass_renderer`).
///
/// `liquid_glass_renderer` está en `0.2.0-dev.4` —la última publicada, y su
/// propio README dice *"EXPERIMENTAL … should not be blindly added to
/// production apps for all devices"*— y es lo que dibuja el dock, o sea el
/// 100 % de la navegación. Desde Flutter 3.29 Android sin Vulkan ya no cae a
/// Skia sino a **Impeller sobre OpenGLES**, así que
/// [ui.ImageFilter.isShaderFilterSupported] devuelve `true` en todos los
/// equipos y el fallback interno del paquete no se activa nunca: en una GPU
/// Mali vieja el shader corre igual, con lo que traiga el driver.
///
/// Si el `FragmentProgram` no compila, el paquete pinta el `child` del
/// `MultiShaderBuilder` —que en el dock es un `SizedBox.expand()`—: la barra y
/// la burbuja **desaparecen** y quedan cinco íconos blancos flotando, sin
/// fondo y sin resalte de la pestaña activa. No es una pantalla en blanco, así
/// que nada tira y nadie se entera.
///
/// Por eso acá hay dos apagados y los dos terminan en el mismo lugar
/// (`fake: true`, que es el camino [FakeGlass] del paquete: `BackdropFilter`
/// con blur + color translúcido + brillo de borde, sin shader):
///
/// 1. **En el build**: `--dart-define=LIQUID_GLASS=false`. Es la palanca para
///    armar un APK de soporte sin tocar código el día que un modelo concreto
///    muestre artefactos.
/// 2. **En runtime**: [calentar] intenta compilar los cuatro shaders del
///    paquete durante el splash; si alguno tira, [apagar] deja toda la app en
///    el camino simple. Un `try/catch` alrededor del warmup es la única forma
///    de enterarse, porque el paquete reporta el error de carga por
///    `FlutterError.reportError` de forma asincrónica y sigue como si nada.
///
/// **No cambia el aspecto cuando el shader anda**: mientras [disponible] sea
/// `true` se renderiza exactamente lo mismo que antes.
class LiquidGlassCapability {
  LiquidGlassCapability._();

  /// `--dart-define=LIQUID_GLASS=false` para publicar sin shaders.
  static const bool permitidoEnElBuild =
      bool.fromEnvironment('LIQUID_GLASS', defaultValue: true);

  /// Cambia cuando el warmup falla o cuando alguien llama a [apagar].
  /// Los widgets de vidrio la escuchan con un `ValueListenableBuilder`.
  static final ValueNotifier<bool> disponible =
      ValueNotifier<bool>(permitidoEnElBuild);

  /// Atajo de lectura.
  static bool get activo => disponible.value;

  /// Motivo del último apagado (sólo para el log y el modo prueba).
  static String? get motivo => _motivo;
  static String? _motivo;

  static bool _yaCorrio = false;

  /// Las cuatro rutas que declara `liquid_glass_renderer` en su `pubspec`.
  /// Están escritas a mano a propósito: `ShaderKeys` del paquete es
  /// `@internal` y no se puede importar.
  static const List<String> _shaders = <String>[
    'packages/liquid_glass_renderer/lib/assets/shaders/liquid_glass_geometry_blended.frag',
    'packages/liquid_glass_renderer/lib/assets/shaders/liquid_glass_filter.frag',
    'packages/liquid_glass_renderer/lib/assets/shaders/liquid_glass_arbitrary.frag',
    'packages/liquid_glass_renderer/lib/assets/shaders/liquid_glass_final_render.frag',
  ];

  /// Apaga el vidrio con shaders para toda la app. Idempotente.
  static void apagar(String motivo) {
    _motivo = motivo;
    if (!disponible.value) return;
    disponible.value = false;
    debugPrint('[vidrio] shaders desactivados: $motivo');
  }

  /// Vuelve a habilitarlo. Sólo para tests y para el modo prueba: si el build
  /// lo prohibió, no hace nada (esa decisión no se revierte en runtime).
  static void prender() {
    if (!permitidoEnElBuild) return;
    _motivo = null;
    disponible.value = true;
  }

  /// Deja el interruptor como recién arrancado. Sólo para tests.
  @visibleForTesting
  static void reiniciarParaTests() {
    _yaCorrio = false;
    _motivo = null;
    disponible.value = permitidoEnElBuild;
  }

  /// Compila los shaders una vez y apaga el vidrio si alguno falla.
  ///
  /// **Nunca tira**: la peor respuesta posible a "no se pudo cargar el vidrio"
  /// es romper el arranque de la app. Corre durante el splash, así que el
  /// costo de compilar acá es el que de todas formas se iba a pagar en el
  /// primer frame del dock.
  static Future<void> calentar() async {
    if (_yaCorrio || !disponible.value) return;
    _yaCorrio = true;

    if (!ui.ImageFilter.isShaderFilterSupported) {
      // Hoy no pasa en iOS/Android (Impeller siempre está), pero si algún día
      // vuelve a pasar, el camino simple es el correcto y no hace falta que lo
      // descubra el paquete a mitad de un frame.
      apagar('el motor no soporta filtros con shader');
      return;
    }

    for (final asset in _shaders) {
      try {
        await ui.FragmentProgram.fromAsset(asset);
      } catch (e) {
        apagar('no compiló $asset: $e');
        return;
      }
    }
  }
}
