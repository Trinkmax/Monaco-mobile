import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart' as lgr;

import 'liquid_glass_capability.dart';
import 'liquid_tokens.dart';

class LiquidDockItem {
  final IconData icon;
  final IconData? selectedIcon;
  final String label;

  const LiquidDockItem({
    required this.icon,
    this.selectedIcon,
    required this.label,
  });
}

/// Dock flotante estilo iOS 26 (Liquid Glass de verdad).
///
/// Dos piezas de vidrio renderizadas con shaders de refracción
/// (`liquid_glass_renderer`, sólo Impeller — iOS/Android): la **barra**, que
/// refracta el contenido que pasa por detrás, y la **burbuja** del ítem
/// activo, una lente más gruesa que va POR ENCIMA de íconos y etiquetas y los
/// refracta en los bordes, igual que la barra de pestañas de iOS 26.
///
/// Interacción calcada de Apple:
/// - Tocar un ítem: la burbuja viaja con un resorte (leve sobrepaso).
/// - **Arrastrar**: la burbuja sigue al dedo por toda la barra (con
///   resistencia en los extremos), hace un tic háptico cada vez que cruza un
///   ítem, y al soltar encaja en el más cercano —con un poco de proyección
///   según la velocidad— y recién ahí se cambia de pestaña.
/// - Con "reducir movimiento" del sistema no hay resorte: salta.
///
/// `currentIndex` sigue siendo la fuente de verdad: si cambia desde afuera
/// (deep link, push), la burbuja se mueve sola.
///
/// **Las dos piezas de vidrio pasan por [LiquidGlassCapability]**: con el
/// shader apagado (`--dart-define=LIQUID_GLASS=false`, o porque el warmup no
/// pudo compilarlo) se dibujan con `fake: true`, o sea el `BackdropFilter`
/// del propio paquete. El dock sigue estando; lo que se pierde es la
/// refracción. Sin ese camino, un shader que no compila deja cinco íconos
/// blancos flotando sin barra ni resalte del activo.
class LiquidDock extends StatefulWidget {
  final List<LiquidDockItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  const LiquidDock({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelect,
  });

  @override
  State<LiquidDock> createState() => _LiquidDockState();
}

class _LiquidDockState extends State<LiquidDock>
    with SingleTickerProviderStateMixin {
  /// Alto de la barra, sin contar el margen inferior ni el safe area.
  static const double _height = 66;
  /// Margen interno: la burbuja se mueve entre `_padH` y `ancho - _padH`.
  static const double _padH = 6;
  static const double _padV = 6;

  /// Resorte de la burbuja: rápido, con un sobrepaso apenas perceptible.
  static const SpringDescription _spring =
      SpringDescription(mass: 1, stiffness: 420, damping: 27);

  /// La barra: vidrio fino con algo de blur, que deja ver y refracta lo que
  /// pasa por detrás.
  static const lgr.LiquidGlassSettings _barra = lgr.LiquidGlassSettings(
    thickness: 11,
    blur: 14,
    glassColor: Color(0x17FFFFFF),
    refractiveIndex: 1.15,
    chromaticAberration: 0.006,
    lightAngle: 0.55 * math.pi,
    lightIntensity: 0.45,
    ambientStrength: 0.05,
    saturation: 1.25,
  );

  /// La burbuja: lente gruesa, sin blur (tiene que verse nítido lo que hay
  /// debajo), con la aberración cromática de los bordes que delata el vidrio.
  static const lgr.LiquidGlassSettings _burbuja = lgr.LiquidGlassSettings(
    thickness: 15,
    blur: 0,
    glassColor: Color(0x1CFFFFFF),
    refractiveIndex: 1.2,
    chromaticAberration: 0.012,
    lightAngle: 0.6 * math.pi,
    lightIntensity: 0.7,
    ambientStrength: 0.08,
    saturation: 1.25,
  );

  /// Posición continua de la burbuja en unidades de "índice" (0 … n-1).
  late final AnimationController _pos = AnimationController.unbounded(
    vsync: this,
    value: widget.currentIndex.toDouble(),
  );

  bool _arrastrando = false;
  int _ultimoTic = -1;

  int get _n => widget.items.length;

  @override
  void didUpdateWidget(LiquidDock old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex && !_arrastrando) {
      _irA(widget.currentIndex.toDouble());
    }
  }

  @override
  void dispose() {
    _pos.dispose();
    super.dispose();
  }

  bool get _reduceMotion => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  void _irA(double target, {double velocity = 0}) {
    if (_reduceMotion) {
      _pos.value = target;
      return;
    }
    _pos.animateWith(SpringSimulation(_spring, _pos.value, target, velocity));
  }

  double _anchoSlot(double w) => (w - _padH * 2) / _n;

  /// dx dentro de la barra → posición en índices (el centro del dedo = centro
  /// de la burbuja).
  double _posDesdeDx(double dx, double w) => (dx - _padH) / _anchoSlot(w) - 0.5;

  void _dragStart(DragStartDetails d, double w) {
    _pos.stop();
    setState(() => _arrastrando = true);
    _ultimoTic = _pos.value.round().clamp(0, _n - 1);
    HapticFeedback.selectionClick();
    _dragMover(d.localPosition.dx, w);
  }

  void _dragMover(double dx, double w) {
    var p = _posDesdeDx(dx, w);
    // Resistencia fuera de los extremos, como el scroll de iOS.
    if (p < 0) p = p * 0.22;
    if (p > _n - 1) p = (_n - 1) + (p - (_n - 1)) * 0.22;
    _pos.value = p;
    final idx = p.round().clamp(0, _n - 1);
    if (idx != _ultimoTic) {
      _ultimoTic = idx;
      HapticFeedback.selectionClick();
    }
  }

  void _dragEnd(DragEndDetails d, double w) {
    final sw = _anchoSlot(w);
    final vIdx = (d.primaryVelocity ?? 0) / sw; // índices por segundo
    // Proyección corta: un "flick" pasa al siguiente aunque el dedo no llegó.
    final target = (_pos.value + vIdx * 0.07).round().clamp(0, _n - 1);
    setState(() => _arrastrando = false);
    _irA(target.toDouble(), velocity: vIdx);
    if (target != widget.currentIndex) widget.onSelect(target);
  }

  void _tap(int i) {
    HapticFeedback.selectionClick();
    _irA(i.toDouble());
    if (i != widget.currentIndex) widget.onSelect(i);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final sw = _anchoSlot(w);
            final alturaBurbuja = _height - _padV * 2;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (d) => _dragStart(d, w),
              onHorizontalDragUpdate: (d) => _dragMover(d.localPosition.dx, w),
              onHorizontalDragEnd: (d) => _dragEnd(d, w),
              onHorizontalDragCancel: () {
                setState(() => _arrastrando = false);
                _irA(widget.currentIndex.toDouble());
              },
              child: SizedBox(
                height: _height,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Elevación: la sombra queda DETRÁS del vidrio y la barra la
                    // refracta en los bordes, como corresponde.
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(LiquidTokens.radiusDock + 5),
                          boxShadow: LiquidTokens.dockLift(),
                        ),
                      ),
                    ),

                    // ── Barra de vidrio ──
                    Positioned.fill(
                      child: _Vidrio(
                        shape: const lgr.LiquidRoundedSuperellipse(borderRadius: 33),
                        settings: _barra,
                      ),
                    ),

                    // ── Ítems ──
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: _padH),
                        child: AnimatedBuilder(
                          animation: _pos,
                          builder: (context, _) {
                            final activo = _pos.value.round().clamp(0, _n - 1);
                            return Row(
                              children: List.generate(_n, (i) {
                                return Expanded(
                                  child: _DockSlot(
                                    item: widget.items[i],
                                    active: i == activo,
                                    onTap: () => _tap(i),
                                  ),
                                );
                              }),
                            );
                          },
                        ),
                      ),
                    ),

                    // ── Burbuja (lente) por encima de los ítems ──
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _pos,
                          builder: (context, _) {
                            final x = (_padH + _pos.value * sw).clamp(1.0, w - sw - 1.0);
                            return Padding(
                              padding: EdgeInsets.fromLTRB(x, _padV, 0, _padV),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: AnimatedScale(
                                  scale: _arrastrando ? 1.07 : 1.0,
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOutCubic,
                                  child: SizedBox(
                                    width: sw,
                                    height: alturaBurbuja,
                                    child: _Vidrio(
                                      shape: const lgr.LiquidRoundedSuperellipse(borderRadius: 25),
                                      settings: _burbuja,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Una pieza de vidrio que respeta el interruptor global.
///
/// Es el ÚNICO lugar de la app que llama al paquete de shaders. Escucha
/// [LiquidGlassCapability.disponible], así que apagar el vidrio en runtime
/// repinta el dock en el frame siguiente sin reiniciar nada.
class _Vidrio extends StatelessWidget {
  final lgr.LiquidShape shape;
  final lgr.LiquidGlassSettings settings;

  const _Vidrio({required this.shape, required this.settings});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: LiquidGlassCapability.disponible,
      builder: (context, conShader, _) {
        return lgr.LiquidGlass.withOwnLayer(
          shape: shape,
          settings: settings,
          fake: !conShader,
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

/// Precalienta los shaders del vidrio durante el splash: compila los cuatro
/// `FragmentProgram` del paquete y deja una lente de 2×2 px invisible para que
/// además arme su propio cache de widget. Sin esto, el dock aparece sin vidrio
/// durante los primeros frames de la app (el shader se carga en forma
/// asincrónica) y después "aparece": un parpadeo que se nota justo en la
/// primera impresión.
///
/// Es también el detector del fallback: si alguno de los cuatro no compila,
/// [LiquidGlassCapability.calentar] apaga el vidrio para toda la app y el dock
/// pasa al camino simple. La compilación va en un `try/catch` porque el
/// paquete reporta ese error por `FlutterError.reportError` (asincrónico) y
/// sigue dibujando un `SizedBox` vacío en lugar de la barra.
class LiquidGlassWarmup extends StatefulWidget {
  const LiquidGlassWarmup({super.key});

  @override
  State<LiquidGlassWarmup> createState() => _LiquidGlassWarmupState();
}

class _LiquidGlassWarmupState extends State<LiquidGlassWarmup> {
  @override
  void initState() {
    super.initState();
    // Sin await: el splash no espera al vidrio. Si falla, el notifier avisa.
    unawaited(LiquidGlassCapability.calentar());
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: 2,
        height: 2,
        child: _Vidrio(
          shape: const lgr.LiquidOval(),
          settings: const lgr.LiquidGlassSettings(
            thickness: 1,
            blur: 0,
            glassColor: Color(0x00FFFFFF),
            lightIntensity: 0,
          ),
        ),
      ),
    );
  }
}

class _DockSlot extends StatelessWidget {
  final LiquidDockItem item;
  final bool active;
  final VoidCallback onTap;

  const _DockSlot({
    required this.item,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Sin caja propia: el resalte es la burbuja de vidrio que pasa por encima.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: active ? 1.08 : 1.0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: Icon(
              active ? (item.selectedIcon ?? item.icon) : item.icon,
              size: 22,
              color: active ? Colors.white : Colors.white.withValues(alpha: 0.58),
            ),
          ),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? Colors.white : Colors.white.withValues(alpha: 0.5),
              letterSpacing: 0.1,
            ),
            child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
