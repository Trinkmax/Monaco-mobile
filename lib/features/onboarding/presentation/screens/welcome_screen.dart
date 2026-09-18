import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/core/auth/auth_provider.dart';

import '../../providers/login_flow_provider.dart';
import '../widgets/auth_opciones.dart';
import '../widgets/boton_lamina.dart';
import '../widgets/legal_footer.dart';
import '../widgets/onboarding_scaffold.dart';

class _Slide {
  final String title;
  final String subtitle;
  final String imagePath;

  const _Slide({
    required this.title,
    required this.subtitle,
    required this.imagePath,
  });
}

/// Las ilustraciones vienen de la app anterior (se mantienen); el copy es el
/// de Monaco. Ojo que los nombres de archivo no coinciden con lo que dibujan:
/// `onboarding_reviews.png` muestra la moneda de puntos + ticket, y
/// `onboarding_gifts.png` las cinco estrellas de la reseña.
///
/// **Sin pastilla de categoría** (decisión del dueño, 12/sep/2026). Cada slide
/// llevaba un badge verde ("Fila en vivo", "Puntos y premios", "Turnos online")
/// que repetía lo que ya dicen el título y el subtítulo, y le comía alto a la
/// ilustración — que es lo que el dueño mira mientras pasan las láminas.
const _slides = [
  _Slide(
    title: 'Tu barbería,\nen tu bolsillo',
    subtitle:
        'Mirá la fila en vivo de cada sucursal y llegá justo cuando te toca.',
    imagePath: 'assets/images/onboarding_barber.png',
  ),
  _Slide(
    title: 'Sumá puntos,\nllevate premios',
    subtitle:
        'Cada corte suma. Canjeá tus puntos por servicios, productos y beneficios.',
    imagePath: 'assets/images/onboarding_reviews.png',
  ),
  _Slide(
    title: 'Turnos en\ntres toques',
    subtitle:
        'Elegí barbero y horario, te confirmamos por WhatsApp y después nos contás cómo te fue.',
    imagePath: 'assets/images/onboarding_gifts.png',
  ),
];

/// **Puerta de entrada: un carrusel de tres láminas y, recién en la última,
/// las formas de entrar** (rediseño del 18/sep/2026, pedido del dueño).
///
/// Cada lámina es la ilustración GRANDE arriba, el texto centrado abajo y un
/// solo botón "Continuar" que pasa a la siguiente. En la tercera, el pie se
/// convierte —en el mismo lugar y con la misma lámina blanca— en las puertas
/// de entrada (Google · Apple · teléfono), el link "Seguir mirando" y los
/// legales. Antes las tres opciones estaban en la primera pantalla compitiendo
/// con el carrusel: la ilustración quedaba chica, el texto apretado y abajo
/// tres botones + un link + los legales, todo a la vez.
///
/// **"Seguir mirando" no es una cortesía, es requisito de App Store** (5.1.1:
/// si la app no es toda "account-based", tiene que dejar usarla sin login).
/// Se sacó el 12/sep/2026 porque "no entraba" y volvió el 18/sep con el bug
/// arreglado: el link cambiaba el estado a `guest` y esperaba que el router
/// lo moviera, pero `/welcome` está en la lista blanca del invitado y el
/// redirect contestaba "quedate". Ahora navega él mismo (`_SeguirMirando`).
///
/// Sin pastilla verde por lámina ("Fila en vivo", …): repetía el título y le
/// comía alto a la ilustración (12/sep/2026).
///
/// Tampoco hay verde en la interfaz de esta pantalla (ni en los puntos del
/// carrusel ni en el halo de la ilustración): el verde es del NEGOCIO, no de
/// un estado de UI. "Seleccionado" acá se lee en blanco, como en el resto.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  static const _pasoDeLamina = Duration(milliseconds: 380);

  final _pageCtrl = PageController();
  int _page = 0;

  bool get _ultima => _page == _slides.length - 1;

  @override
  void initState() {
    super.initState();
    // Llegar acá es empezar de cero (primera vez o después de cerrar sesión):
    // un flujo de código a medias del login anterior no tiene que sobrevivir,
    // ni siquiera para precargar el teléfono de otra persona. Lo mismo con un
    // alta social abandonada a mitad de camino.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(loginFlowProvider.notifier).state = null;
      ref.read(signupPendienteProvider.notifier).state = null;
      _avisoDeSesion();
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  /// Si la sesión se cerró sola (la API dijo que el JWT ya no representa a
  /// ningún cliente), acá es donde el cliente se entera: si no, la app
  /// "vuelve al principio" sin decir nada y parece que se rompió. El aviso se
  /// consume una vez.
  void _avisoDeSesion() {
    final aviso = ref.read(mensajeDeSesionProvider);
    if (aviso == null || aviso.isEmpty) return;
    ref.read(mensajeDeSesionProvider.notifier).state = null;
    showLiquidToast(
      context,
      aviso,
      tone: LiquidToastTone.error,
      icon: Icons.lock_reset_rounded,
      duration: const Duration(seconds: 5),
    );
  }

  void _siguiente() {
    if (_ultima) return;
    _pageCtrl.nextPage(duration: _pasoDeLamina, curve: Curves.easeOutCubic);
  }

  void _irA(int i) {
    if (i == _page) return;
    _pageCtrl.animateToPage(
      i,
      duration: _pasoDeLamina,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.height < 760;

    return OnboardingScaffold(
      scrollable: false,
      padding: EdgeInsets.zero,
      topRight: const Padding(
        padding: EdgeInsets.only(right: 4, top: 4),
        child: MonacoLogo.wordmark(width: 132),
      ),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Dots(
            count: _slides.length,
            index: _page,
            onTap: _irA,
          ).liquidEnter(index: 3),
          const SizedBox(height: 14),
          // El pie cambia de forma con la lámina: un "Continuar" en las dos
          // primeras, las puertas de entrada en la última. `AnimatedSize`
          // acompaña el cambio de alto —y el carrusel de arriba, que es un
          // `Expanded`, cede o recupera ese alto en el mismo movimiento—;
          // `AnimatedSwitcher` cruza el contenido.
          AnimatedSize(
            duration: const Duration(milliseconds: 340),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: LiquidTokens.swap,
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: _transicionDelPie,
              layoutBuilder: _elPieMideSoloAlQueEntra,
              child: _ultima
                  ? const _PuertasDeEntrada(key: ValueKey('entrar'))
                  : BotonLamina(
                      key: const ValueKey('continuar'),
                      label: 'Continuar',
                      trailing: Icons.arrow_forward_rounded,
                      solido: true,
                      onPressed: _siguiente,
                    ),
            ),
          ).liquidEnter(index: 4),
        ],
      ),
      child: PageView.builder(
        controller: _pageCtrl,
        onPageChanged: (i) => setState(() => _page = i),
        itemCount: _slides.length,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, i) =>
            _SlideView(key: ValueKey(i), slide: _slides[i], compact: compact),
      ),
    );
  }

  static Widget _transicionDelPie(Widget child, Animation<double> anim) {
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.05),
          end: Offset.zero,
        ).animate(anim),
        child: child,
      ),
    );
  }

  /// El `Stack` mide SÓLO al hijo que entra: los que salen quedan pegados
  /// arriba, fuera del flujo, desvaneciéndose encima. Con el layout por
  /// default (todos en flujo) la caja saltaba en el acto al tamaño del más
  /// alto y el `AnimatedSize` de afuera no tenía nada que animar a la ida; a la
  /// vuelta se quedaba grande hasta que el saliente terminaba de irse.
  static Widget _elPieMideSoloAlQueEntra(
    Widget? actual,
    List<Widget> anteriores,
  ) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        for (final w in anteriores)
          Positioned(top: 0, left: 0, right: 0, child: w),
        ?actual,
      ],
    );
  }
}

/// Google · Apple · teléfono, "Seguir mirando" y los legales. Sólo en la
/// última lámina.
class _PuertasDeEntrada extends StatelessWidget {
  const _PuertasDeEntrada({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthOpciones(),
        SizedBox(height: 2),
        _SeguirMirando(),
        SizedBox(height: 2),
        LegalFooter(),
      ],
    );
  }
}

/// Modo invitado. Va como link y no como botón a propósito: es la salida, no
/// la acción que queremos. Pero tiene que estar **visible sin scrollear** —un
/// "sin cuenta" escondido es lo mismo que no tenerlo.
///
/// **Navega él mismo a `/home`.** No alcanza con cambiar el estado: `/welcome`
/// está permitida para el invitado (el "volver" de `/login` cae ahí), así que
/// el redirect del router ve `guest` + `/welcome` y no mueve a nadie; y si ya
/// era invitado, el estado ni cambia. Es exactamente por lo que el link "no
/// entraba" antes.
class _SeguirMirando extends ConsumerStatefulWidget {
  const _SeguirMirando();

  @override
  ConsumerState<_SeguirMirando> createState() => _SeguirMirandoState();
}

class _SeguirMirandoState extends ConsumerState<_SeguirMirando> {
  bool _busy = false;

  Future<void> _entrar() async {
    setState(() => _busy = true);
    // El router se toma ANTES del await: si algo desmonta la pantalla en el
    // medio, `context` ya no lo encuentra.
    final router = GoRouter.of(context);
    try {
      await ref.read(authProvider.notifier).continuarComoInvitado();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    router.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: OnboardingLink(
        label: _busy ? 'Entrando…' : 'Seguir mirando',
        icon: Icons.visibility_outlined,
        onTap: _busy ? null : _entrar,
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  final _Slide slide;
  final bool compact;
  const _SlideView({super.key, required this.slide, required this.compact});

  /// Alto que se le reserva al texto (título de dos líneas + subtítulo de
  /// hasta tres + el aire entre ambos y con la lámina), medido en Poppins. La
  /// ilustración se queda con TODO lo demás: es lo que el cliente mira.
  double get _altoTexto => compact ? 150 : 195;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final w = constraints.maxWidth;
        // Cuadrada, tan grande como deje el texto y el ancho, con un tope para
        // que en una pantalla alta no se vuelva un póster. Cuando el pie crece
        // (última lámina) el alto disponible baja y la lámina se achica con él,
        // animada por el `AnimatedSize` del pie. Si aun así no entra (pantalla
        // chica con tres botones), el slide scrollea en vez de desbordar.
        final tope = compact ? 260.0 : 380.0;
        final imageSize = math
            .min(math.min(h - _altoTexto, w - 48), tope)
            .clamp(140.0, tope);
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: h),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _Ilustracion(path: slide.imagePath, size: imageSize),
                SizedBox(height: compact ? 18 : 26),
                _SlideCopy(slide: slide, compact: compact),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// La ilustración sobre un halo neutro, con el borde inferior fundido al
/// fondo: las tres láminas vienen recortadas abajo (los pies del barbero, el
/// torso del cliente) y sin el fundido ese corte se lee como un error de
/// recorte, no como una viñeta.
class _Ilustracion extends StatelessWidget {
  final String path;
  final double size;
  const _Ilustracion({required this.path, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: size * 0.94,
                height: size * 0.94,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.11),
                      Colors.white.withValues(alpha: 0.035),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.55, 1],
                  ),
                ),
              ),
              ShaderMask(
                shaderCallback: (rect) => LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white,
                    Colors.white,
                    Colors.white.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.8, 1],
                ).createShader(rect),
                blendMode: BlendMode.dstIn,
                child: Image.asset(
                  path,
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 480.ms)
        .scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1, 1),
          duration: 560.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

/// Título + subtítulo de un slide, centrados, con entrada escalonada.
class _SlideCopy extends StatelessWidget {
  final _Slide slide;
  final bool compact;
  const _SlideCopy({required this.slide, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
              slide.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: MonacoColors.textPrimary,
                fontSize: compact ? 27 : 31,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.1,
                height: 1.06,
              ),
            )
            .animate()
            .fadeIn(delay: 140.ms, duration: 460.ms)
            .slideY(
              begin: 0.18,
              end: 0,
              delay: 140.ms,
              duration: 460.ms,
              curve: Curves.easeOutCubic,
            ),
        const SizedBox(height: 10),
        ConstrainedBox(
              // Un párrafo centrado de más de ~40 caracteres por línea se lee
              // peor que el mismo texto en dos o tres líneas cortas.
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                slide.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: compact ? 14 : 15,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                ),
              ),
            )
            .animate()
            .fadeIn(delay: 240.ms, duration: 460.ms)
            .slideY(
              begin: 0.18,
              end: 0,
              delay: 240.ms,
              duration: 460.ms,
              curve: Curves.easeOutCubic,
            ),
      ],
    );
  }
}

/// Indicador de páginas: pastilla activa blanca que se estira. Cada punto se
/// toca (área de 44 de alto aunque el punto mida 8).
class _Dots extends StatelessWidget {
  final int count;
  final int index;
  final ValueChanged<int> onTap;
  const _Dots({required this.count, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final on = i == index;
        return Semantics(
          button: true,
          selected: on,
          label: 'Lámina ${i + 1} de $count',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                width: on ? 28 : 8,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: on
                      ? MonacoColors.seleccion
                      : Colors.white.withValues(alpha: 0.24),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
