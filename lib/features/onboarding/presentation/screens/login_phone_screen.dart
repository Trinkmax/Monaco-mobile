import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/core/auth/auth_provider.dart';
import 'package:monaco_mobile/core/auth/auth_service.dart';
import 'package:monaco_mobile/core/utils/constants.dart';

import 'package:monaco_mobile/core/auth/social_auth_service.dart';

import '../../providers/login_flow_provider.dart';
import '../../utils/phone_format.dart';
import '../widgets/legal_footer.dart';
import '../widgets/onboarding_scaffold.dart';

/// Paso 1 del login: el número. `start` decide si la sesión ya está lista
/// (dispositivo conocido → el router manda a /home) o si hay que verificar
/// un código por WhatsApp (→ /login/codigo).
///
/// Es también el segundo paso del alta con Google/Apple: si viene un
/// [SignupPendiente], su `signup_token` viaja en `start` (habilita mandarle el
/// código a un número que todavía no es cliente) y después en `verify` (es lo
/// que vincula la identidad social con la cuenta). Por eso el teléfono se pide
/// SIEMPRE, aunque la identidad ya esté validada: **la identidad del negocio es
/// el teléfono** —es lo que ata la cuenta con la fila del local, con WhatsApp,
/// con los puntos y con el historial—, y una cuenta sin él sería una cuenta que
/// el local no puede encontrar.
class LoginPhoneScreen extends ConsumerStatefulWidget {
  const LoginPhoneScreen({super.key});

  @override
  ConsumerState<LoginPhoneScreen> createState() => _LoginPhoneScreenState();
}

class _LoginPhoneScreenState extends ConsumerState<LoginPhoneScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  bool _loading = false;
  String? _fieldError;
  _Banner? _banner;

  /// Sesión lista (dispositivo conocido): el router ya está navegando.
  bool _done = false;

  /// Bloqueo por RATE_LIMITED: hasta cuándo no se puede reintentar.
  DateTime? _retryAt;
  Timer? _retryTicker;

  String get _digits => ArPhone.normalizeTyped(_ctrl.text);
  bool get _complete => ArPhone.isCompleteMobile(_ctrl.text);

  int get _retrySecondsLeft {
    final at = _retryAt;
    if (at == null) return 0;
    final left = at.difference(DateTime.now()).inSeconds;
    return left < 0 ? 0 : left;
  }

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onChanged);
    // Si volvemos desde el paso del código con "Cambiar número", precargamos
    // el que había para que no lo tipee de cero.
    final flow = ref.read(loginFlowProvider);
    if (flow != null && flow.phone.isNotEmpty) {
      _ctrl.text = ArPhone.format(flow.phone);
    }
  }

  void _onChanged() {
    if (_fieldError != null || _banner != null) {
      setState(() {
        _fieldError = null;
        _banner = null;
      });
    } else {
      // Para habilitar/deshabilitar el CTA.
      setState(() {});
    }
  }

  @override
  void dispose() {
    _retryTicker?.cancel();
    _ctrl.removeListener(_onChanged);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startRetryCountdown(int seconds) {
    _retryAt = DateTime.now().add(Duration(seconds: seconds));
    _retryTicker?.cancel();
    _retryTicker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_retrySecondsLeft <= 0) {
        t.cancel();
        setState(() {
          _retryAt = null;
          _banner = null;
        });
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _submit() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();

    if (!_complete) {
      setState(
        () => _fieldError =
            'Ingresá el código de área y el número, sin el 0 ni el 15.',
      );
      return;
    }
    if (_retrySecondsLeft > 0) return;

    setState(() {
      _loading = true;
      _fieldError = null;
      _banner = null;
    });

    final phone = _digits;
    final signup = ref.read(signupPendienteProvider);
    if (signup != null && signup.vencido) {
      _signupVencido();
      return;
    }
    try {
      final res = await ref
          .read(authProvider.notifier)
          .startLogin(phone, signupToken: signup?.token);
      if (!mounted) return;

      if (res.sessionReady) {
        // Dispositivo conocido: la sesión ya está y el router redirige solo
        // (unauthenticated → authenticated). No navegamos a mano
        // y dejamos el CTA en "cargando" hasta que la pantalla desaparezca.
        _done = true;
        ref.read(loginFlowProvider.notifier).state = null;
        ref.read(signupPendienteProvider.notifier).state = null;
        return;
      }
      if (res.otpSent) {
        ref.read(loginFlowProvider.notifier).state = LoginFlow.fromStart(
          phone,
          res,
          fallbackMasked: ArPhone.mask(phone),
        );
        context.push('/login/codigo');
        return;
      }
      setState(
        () => _banner = const _Banner(
          'No pudimos iniciar sesión. Probá de nuevo.',
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      _handleError(e);
    } catch (e, st) {
      debugPrint('[login] startLogin error inesperado: $e\n$st');
      if (!mounted) return;
      setState(
        () => _banner = const _Banner(
          'Algo salió mal. Probá de nuevo en un momento.',
        ),
      );
    } finally {
      if (mounted && !_done) setState(() => _loading = false);
    }
  }

  void _handleError(AuthException e) {
    switch (e.code) {
      case 'INVALID_PHONE':
        setState(() => _fieldError = 'Ese número no parece válido. Revisalo.');
      case 'RATE_LIMITED':
        final secs = e.retryIn ?? 600;
        _startRetryCountdown(secs);
        setState(
          () => _banner = _Banner(
            'Demasiados intentos. Probá de nuevo en ${_fmt(secs)}.',
            countdown: true,
          ),
        );
      case 'OTP_DELIVERY_FAILED':
        setState(
          () => _banner = _Banner(
            'No pudimos mandarte el código por WhatsApp. Probá de nuevo en '
            'un rato o escribinos.',
            actionLabel: 'Escribinos',
            onAction: _openSupport,
          ),
        );
      case 'NETWORK':
        setState(
          () => _banner = _Banner(
            e.message,
            actionLabel: 'Reintentar',
            onAction: _submit,
          ),
        );
      case 'ORG_NOT_FOUND':
        setState(
          () => _banner = const _Banner(
            'La barbería no está disponible en este momento. '
            'Probá más tarde.',
          ),
        );
      case 'CLIENT_NOT_FOUND':
        // Con el alta abierta (`organizations.allow_client_signup`, hoy sólo
        // Monaco) este código no llega: `start` manda el código igual y la
        // cuenta se crea en `verify`. Si llega, es que el dueño cerró el alta,
        // y entonces no hay nada que el cliente pueda hacer solo desde la app.
        setState(
          () => _banner = _Banner(
            'Este número todavía no está registrado y por ahora no podemos '
            'crear cuentas nuevas desde la app. Escribinos y lo resolvemos.',
            actionLabel: 'Escribinos',
            onAction: _openSupport,
          ),
        );
      case 'SIGNUP_TOKEN_INVALID':
        _signupVencido(expirado: e.expired);
      default:
        setState(() => _banner = _Banner(e.message));
    }
  }

  /// El `signup_token` de Google/Apple dura 15 minutos. Vencido, no alcanza con
  /// reintentar: hay que volver a autorizar con el proveedor. Se dice con
  /// palabras y se limpia el token, para que el próximo `start` no vuelva a
  /// rebotar con lo mismo.
  void _signupVencido({bool expirado = true}) {
    final proveedor = ref.read(signupPendienteProvider)?.proveedor;
    ref.read(signupPendienteProvider.notifier).state = null;
    setState(() {
      _loading = false;
      _banner = _Banner(
        expirado
            ? 'Pasó demasiado tiempo desde que entraste con '
                  '${proveedor?.label ?? 'tu cuenta'}. Volvé a empezar: es un toque.'
            : 'No pudimos continuar con tu cuenta de '
                  '${proveedor?.label ?? 'ese proveedor'}. Podés seguir con tu número.',
        actionLabel: 'Volver al inicio',
        onAction: () => context.go('/welcome'),
      );
    });
  }

  Future<void> _openSupport() async {
    try {
      await launchUrl(
        Uri.parse(AppConstants.supportWhatsappUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('[login] no se pudo abrir WhatsApp de soporte: $e');
    }
  }

  static String _fmt(int seconds) {
    if (seconds < 60) return '$seconds s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m >= 60) {
      final h = m ~/ 60;
      return h == 1 ? '1 hora' : '$h horas';
    }
    return s == 0 ? '$m min' : '$m:${s.toString().padLeft(2, '0')} min';
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    final retryLeft = _retrySecondsLeft;
    final banner = _banner;
    final bannerText = banner != null && banner.countdown && retryLeft > 0
        ? 'Demasiados intentos. Probá de nuevo en ${_fmt(retryLeft)}.'
        : banner?.text;

    final signup = ref.watch(signupPendienteProvider);

    return OnboardingScaffold(
      showBack: true,
      onBack: _back,
      topRight: const MonacoLogo.monogram(width: 30),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          OnboardingCta(
            label: 'Continuar',
            icon: Icons.arrow_forward_rounded,
            loading: _loading,
            onPressed: _complete && retryLeft == 0 ? _submit : null,
          ).liquidEnter(index: 4),
          const SizedBox(height: 12),
          const LegalFooter().liquidEnter(index: 5),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 18),
          if (signup != null) ...[
            _ChipProveedor(signup: signup).liquidEnter(index: 0),
            const SizedBox(height: 16),
          ],
          OnboardingTitle(
            title: signup == null ? 'Ingresá tu número' : 'Falta tu teléfono',
            subtitle: signup == null
                ? 'Te mandamos un código por WhatsApp para entrar. Sin contraseñas.'
                : 'Lo usamos para reconocerte en el local, avisarte de tus '
                      'turnos y guardar tus puntos. Te mandamos un código por '
                      'WhatsApp para confirmarlo.',
          ).liquidEnter(index: 0),
          const SizedBox(height: 32),
          LiquidTextField(
            controller: _ctrl,
            focusNode: _focus,
            autofocus: true,
            label: 'CELULAR',
            hint: '351 212-5249',
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            inputFormatters: const [ArPhoneInputFormatter()],
            autofillHints: const [AutofillHints.telephoneNumberNational],
            enabled: !_loading,
            prefix: const _CountryPrefix(),
            helper: 'Te mandamos un código por WhatsApp',
            errorText: _fieldError,
            onSubmitted: (_) => _submit(),
            style: const TextStyle(
              color: MonacoColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ).liquidEnter(index: 1),
          const SizedBox(height: 18),
          AnimatedSize(
            duration: LiquidTokens.swap,
            curve: LiquidTokens.curveSwap,
            alignment: Alignment.topCenter,
            child: bannerText == null
                ? const SizedBox.shrink()
                : OnboardingErrorBox(
                        message: bannerText,
                        actionLabel: banner?.actionLabel,
                        onAction: banner?.onAction,
                      )
                      .animate()
                      .fadeIn(duration: 220.ms)
                      .shakeX(amount: 4, hz: 4, duration: 360.ms),
          ),
          const SizedBox(height: 18),
          const _WhatsappHint().liquidEnter(index: 2),
        ],
      ),
    );
  }
}

/// Chip "+54 9" a la izquierda del campo. No es tappable: la app es sólo para
/// Argentina (la org es una sola y manda WhatsApp a números 549…).
class _CountryPrefix extends StatelessWidget {
  const _CountryPrefix();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.14),
            Colors.white.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'AR',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 7),
          const Text(
            '+54 9',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lámina informativa: cómo llega el código.
class _WhatsappHint extends StatelessWidget {
  const _WhatsappHint();

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
      borderRadius: 20,
      pressable: false,
      tintOpacity: 0.06,
      showVignette: false,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  MonacoColors.monacoGreen.withValues(alpha: 0.3),
                  MonacoColors.monacoGreen.withValues(alpha: 0.1),
                ],
              ),
              border: Border.all(
                color: MonacoColors.monacoGreen.withValues(alpha: 0.45),
                width: 0.8,
              ),
            ),
            child: const Icon(
              Icons.chat_rounded,
              size: 19,
              color: MonacoColors.monacoGreen,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Llega por WhatsApp',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Vas a recibir un mensaje de WhatsApp de Monaco con un código '
                  'de 6 dígitos. Si ya entraste desde este teléfono, pasás '
                  'directo y no te mandamos nada.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Banner {
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool countdown;
  const _Banner(
    this.text, {
    this.actionLabel,
    this.onAction,
    this.countdown = false,
  });
}

/// "Seguimos con tu cuenta de Google · nacho@gmail.com". Es lo que le dice al
/// cliente por qué le estamos pidiendo el teléfono después de haber entrado con
/// un toque, en vez de dejarlo pensando que el login falló.
class _ChipProveedor extends StatelessWidget {
  final SignupPendiente signup;
  const _ChipProveedor({required this.signup});

  @override
  Widget build(BuildContext context) {
    final email = (signup.email ?? '').trim();
    return LiquidPill(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      tintOpacity: 0.08,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            signup.proveedor == SocialProvider.google
                ? Icons.verified_rounded
                : Icons.apple_rounded,
            size: 16,
            color: MonacoColors.monacoGreen,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              email.isEmpty
                  ? 'Seguimos con tu cuenta de ${signup.proveedor.label}'
                  : '${signup.proveedor.label} · $email',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
