import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';

import '../../providers/login_flow_provider.dart';
import '../widgets/no_cliente_sheet.dart';
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

/// Tres slides de bienvenida. "Empezar" y "Ya tengo cuenta" van al mismo
/// lugar (/login): el OTP resuelve si sos nuevo o no, así que no hay dos
/// caminos. El link sirve para el que ya conoce la app y no quiere deslizar.
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
    // ni siquiera para precargar el teléfono de otra persona.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(loginFlowProvider.notifier).state = null;
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _goLogin() => context.go('/login');

  void _next() {
    if (_page < _slides.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    } else {
      _goLogin();
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _slides.length - 1;
    final size = MediaQuery.sizeOf(context);
    final compact = size.height < 720;

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
          const SizedBox(height: 18),
          OnboardingCta(
            label: last ? 'Ingresar con mi número' : 'Siguiente',
            icon: last ? Icons.arrow_forward_rounded : null,
            onPressed: _next,
          ).liquidEnter(index: 4),
          const SizedBox(height: 4),
          // La app no crea cuentas (la cuenta nace en la tablet del local):
          // en la última lámina el enlace explica eso; en las anteriores,
          // atajo al login para el que ya es cliente.
          last
              ? OnboardingLink(
                  label: '¿Aún no sos cliente?',
                  icon: Icons.help_outline_rounded,
                  onTap: () => showNoClienteSheet(context),
                ).liquidEnter(index: 5)
              : OnboardingLink(
                  label: 'Ya soy cliente, ingresar',
                  icon: Icons.login_rounded,
                  onTap: _goLogin,
                ).liquidEnter(index: 5),
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
    // La ilustración se adapta al alto que queda (teclados no hay, pero sí
    // pantallas de 16:9 y el modo "texto grande"): entre 150 y 290 px, y
    // si aun así no entra, el slide scrollea en vez de desbordar.
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final imageSize = (h * 0.46).clamp(150.0, compact ? 230.0 : 290.0);
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
                SizedBox(height: compact ? 18 : 30),
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
        const SizedBox(height: 14),

        // ── Título ──
        Text(
              slide.title,
              style: TextStyle(
                color: MonacoColors.textPrimary,
                fontSize: compact ? 30 : 34,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.3,
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
        const SizedBox(height: 12),

        // ── Subtítulo ──
        Text(
              slide.subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1.45,
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
