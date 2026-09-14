import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/core/auth/auth_provider.dart';

import '../../providers/login_flow_provider.dart';
import '../widgets/auth_opciones.dart';
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
/// que repetía lo que ya dicen el título y el subtítulo, y le comía ~45 px de
/// alto a la ilustración — que es lo que el dueño mira mientras pasan las
/// láminas. La lámina manda; el texto explica.
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

/// **Puerta de entrada.** Tres láminas de contexto arriba y, abajo, las formas
/// de entrar.
///
/// Las opciones están en la PRIMERA pantalla, no escondidas detrás de un
/// carrusel que hay que terminar: el dueño va a hacer publicidad y el que baja
/// la app por un anuncio no es cliente todavía. Antes acá había un "¿Aún no sos
/// cliente?" que explicaba que la cuenta nacía en la tablet del local —o sea,
/// que la app rechazaba a todo el que llegara desde afuera—; eso murió junto
/// con `no_cliente_sheet.dart`.
///
/// **El link "Seguir mirando" (modo invitado) se sacó de acá el 12/sep/2026**
/// por pedido del dueño: no entraba. Lo que NO se tocó es la maquinaria —
/// `AuthNotifier.continuarComoInvitado()`, `AuthStatus.guest`, el muro de
/// login y la marca persistida— porque la guideline 5.1.1 de App Store exige
/// poder navegar sin cuenta cuando la app no es toda "account-based", y si App
/// Review lo reclama hay que reponer un botón, no un flujo. Antes de reponerlo,
/// arreglar por qué no entraba.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _pageCtrl = PageController();
  int _page = 0;

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
        children: [
          _Dots(count: _slides.length, index: _page).liquidEnter(index: 3),
          const SizedBox(height: 16),
          const AuthOpciones().liquidEnter(index: 4),
          const SizedBox(height: 10),
          const LegalFooter().liquidEnter(index: 5),
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
}

class _SlideView extends StatelessWidget {
  final _Slide slide;
  final bool compact;
  const _SlideView({super.key, required this.slide, required this.compact});

  @override
  Widget build(BuildContext context) {
    // La ilustración se adapta al alto que queda. Sacar la pastilla verde y el
    // link de invitado devolvió ~90 px, que van acá: la lámina es lo que el
    // cliente mira mientras pasa los slides. Si aun así no entra (pantalla
    // chica), el slide scrollea en vez de desbordar.
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final imageSize = (h * 0.58).clamp(120.0, compact ? 215.0 : 280.0);
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: h),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Ilustración sobre un halo verde ──
                Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: imageSize * 0.9,
                            height: imageSize * 0.9,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  MonacoColors.monacoGreen.withValues(
                                    alpha: 0.16,
                                  ),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                          Image.asset(
                            slide.imagePath,
                            width: imageSize,
                            height: imageSize,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.medium,
                          ),
                        ],
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 480.ms)
                    .scale(
                      begin: const Offset(0.86, 0.86),
                      end: const Offset(1, 1),
                      duration: 560.ms,
                      curve: Curves.easeOutCubic,
                    ),
                SizedBox(height: compact ? 14 : 22),
                _SlideCopy(slide: slide, compact: compact),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Título + subtítulo de un slide, con entrada escalonada.
class _SlideCopy extends StatelessWidget {
  final _Slide slide;
  final bool compact;
  const _SlideCopy({required this.slide, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Título ──
        Text(
              slide.title,
              style: TextStyle(
                color: MonacoColors.textPrimary,
                fontSize: compact ? 26 : 30,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.2,
                height: 1.05,
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

        // ── Subtítulo ──
        Text(
              slide.subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.4,
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

/// Indicador de páginas: pastilla activa verde que se estira.
class _Dots extends StatelessWidget {
  final int count;
  final int index;
  const _Dots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final on = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          width: on ? 26 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 3.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: on
                ? MonacoColors.monacoGreen
                : Colors.white.withValues(alpha: 0.22),
            boxShadow: on
                ? [
                    BoxShadow(
                      color: MonacoColors.monacoGreen.withValues(alpha: 0.45),
                      blurRadius: 10,
                      spreadRadius: -2,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}
