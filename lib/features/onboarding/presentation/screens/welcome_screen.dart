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
  final IconData icon;
  final String badge;

  const _Slide({
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.icon,
    required this.badge,
  });
}

/// Las ilustraciones vienen de la app anterior (se mantienen); el copy es el
/// de Monaco. Ojo que los nombres de archivo no coinciden con lo que dibujan:
/// `onboarding_reviews.png` muestra la moneda de puntos + ticket, y
/// `onboarding_gifts.png` las cinco estrellas de la reseña.
const _slides = [
  _Slide(
    title: 'Tu barbería,\nen tu bolsillo',
    subtitle:
        'Mirá la fila en vivo de cada sucursal y llegá justo cuando te toca.',
    imagePath: 'assets/images/onboarding_barber.png',
    icon: Icons.storefront_rounded,
    badge: 'Fila en vivo',
  ),
  _Slide(
    title: 'Sumá puntos,\nllevate premios',
    subtitle:
        'Cada corte suma. Canjeá tus puntos por servicios, productos y beneficios.',
    imagePath: 'assets/images/onboarding_reviews.png',
    icon: Icons.stars_rounded,
    badge: 'Puntos y premios',
  ),
  _Slide(
    title: 'Turnos en\ntres toques',
    subtitle:
        'Elegí barbero y horario, te confirmamos por WhatsApp y después nos contás cómo te fue.',
    imagePath: 'assets/images/onboarding_gifts.png',
    icon: Icons.event_available_rounded,
    badge: 'Turnos online',
  ),
];

/// **Puerta de entrada.** Tres láminas de contexto arriba y, abajo, las tres
/// formas de entrar + "Seguir mirando".
///
/// Las opciones están en la PRIMERA pantalla, no escondidas detrás de un
/// carrusel que hay que terminar: el dueño va a hacer publicidad y el que baja
/// la app por un anuncio no es cliente todavía. Antes acá había un "¿Aún no sos
/// cliente?" que explicaba que la cuenta nacía en la tablet del local —o sea,
/// que la app rechazaba a todo el que llegara desde afuera—; eso murió junto
/// con `no_cliente_sheet.dart`.
///
/// **"Seguir mirando" no es una cortesía, es requisito de App Store** (5.1.1:
/// si la app no es toda "account-based", tiene que dejar usarla sin login).
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
          const SizedBox(height: 2),
          const _SeguirMirando().liquidEnter(index: 5),
          const SizedBox(height: 2),
          const LegalFooter().liquidEnter(index: 6),
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

/// Modo invitado. Va como link y no como botón a propósito: es la salida, no
/// la acción que queremos. Pero tiene que estar **visible sin scrollear** —un
/// "sin cuenta" escondido es lo mismo que no tenerlo.
class _SeguirMirando extends ConsumerStatefulWidget {
  const _SeguirMirando();

  @override
  ConsumerState<_SeguirMirando> createState() => _SeguirMirandoState();
}

class _SeguirMirandoState extends ConsumerState<_SeguirMirando> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return OnboardingLink(
      label: _busy ? 'Entrando…' : 'Seguir mirando',
      icon: Icons.visibility_outlined,
      onTap: _busy
          ? null
          : () async {
              setState(() => _busy = true);
              // El router redirige solo al cambiar el AuthStatus a `guest`.
              await ref.read(authProvider.notifier).continuarComoInvitado();
              if (mounted) setState(() => _busy = false);
            },
    );
  }
}

class _SlideView extends StatelessWidget {
  final _Slide slide;
  final bool compact;
  const _SlideView({super.key, required this.slide, required this.compact});

  @override
  Widget build(BuildContext context) {
    // La ilustración se adapta al alto que queda. El pie de esta pantalla ahora
    // lleva tres botones de 56 + el link + los legales, así que la lámina es
    // bastante más chica que antes; si aun así no entra, el slide scrollea en
    // vez de desbordar.
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final imageSize = (h * 0.42).clamp(96.0, compact ? 150.0 : 190.0);
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

/// Badge + título + subtítulo de un slide, con entrada escalonada.
class _SlideCopy extends StatelessWidget {
  final _Slide slide;
  final bool compact;
  const _SlideCopy({required this.slide, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Badge ──
        LiquidPill(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              tint: MonacoColors.monacoGreen,
              tintOpacity: 0.14,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(slide.icon, size: 14, color: MonacoColors.monacoGreen),
                  const SizedBox(width: 7),
                  Text(
                    slide.badge.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.9,
                    ),
                  ),
                ],
              ),
            )
            .animate()
            .fadeIn(delay: 120.ms, duration: 420.ms)
            .slideY(
              begin: 0.2,
              end: 0,
              delay: 120.ms,
              duration: 420.ms,
              curve: Curves.easeOutCubic,
            ),
        const SizedBox(height: 12),

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
            .fadeIn(delay: 200.ms, duration: 460.ms)
            .slideY(
              begin: 0.18,
              end: 0,
              delay: 200.ms,
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
            .fadeIn(delay: 300.ms, duration: 460.ms)
            .slideY(
              begin: 0.18,
              end: 0,
              delay: 300.ms,
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
