import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/core/auth/auth_provider.dart';
import 'package:monaco_mobile/core/auth/auth_service.dart';
import 'package:monaco_mobile/core/utils/constants.dart';

import '../../providers/login_flow_provider.dart';
import '../../utils/phone_format.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/shake.dart';

/// Paso 2 y último: el código de WhatsApp.
///
/// **Si el teléfono es nuevo, el nombre se pide ACÁ**, en la misma pantalla y
/// junto al código, no en un paso aparte (`/login/nombre` se eliminó). El
/// server contesta `name_required` en `start`, así que sabemos antes de dibujar
/// si hace falta; y el `NAME_REQUIRED` de `verify` llega **sin consumir el
/// desafío**, así que aun en el caso raro en que el server cambie de opinión el
/// código sigue vigente y sólo hay que completar el campo.
///
/// El flujo anterior apilaba una tercera pantalla que verificaba el código
/// recién ahí: un código incorrecto obligaba a volver atrás con un error
/// arrastrado en el estado (`pendingCodeError`), que es la máquina que se borró
/// con este cambio.
class LoginCodeScreen extends ConsumerStatefulWidget {
  const LoginCodeScreen({super.key});

  @override
  ConsumerState<LoginCodeScreen> createState() => _LoginCodeScreenState();
}

class _LoginCodeScreenState extends ConsumerState<LoginCodeScreen> {
  final _codeCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  final _nombreFocus = FocusNode();

  bool _loading = false;
  bool _resending = false;
  String? _error;
  String? _nombreError;
  String? _bannerError;
  VoidCallback? _bannerAction;
  String? _bannerActionLabel;

  /// El código venció o el server lo dijo: habilita "Reenviar" aunque el
  /// countdown no haya terminado.
  bool _forceResend = false;

  /// Bloqueo por RATE_LIMITED del reenvío.
  DateTime? _resendBlockedUntil;

  int _shakeSeed = 0;
  Timer? _ticker;
  String _code = '';

  /// La verificación salió bien: el router ya está yendo a la pantalla que
  /// sigue. Mientras tanto seguimos dibujando con la última copia del flujo
  /// (que se limpia al terminar) para que no aparezca "Este paso venció"
  /// durante la transición.
  bool _done = false;
  LoginFlow? _lastFlow;

  String get _nombre => _nombreCtrl.text.trim();
  bool get _nombreValido => _nombre.length >= 2 && _nombre.length <= 80;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    // El nombre que trajo Google/Apple. En Apple es la ÚNICA vez que se puede
    // obtener, así que precargarlo no es comodidad: es no perderlo.
    final sugerido = ref.read(signupPendienteProvider)?.nombreSugerido?.trim();
    if (sugerido != null && sugerido.isNotEmpty) _nombreCtrl.text = sugerido;
    _nombreCtrl.addListener(() {
      if (_nombreError != null) setState(() => _nombreError = null);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _codeCtrl.dispose();
    _nombreCtrl.dispose();
    _nombreFocus.dispose();
    super.dispose();
  }

  void _clearErrors() {
    _error = null;
    _nombreError = null;
    _bannerError = null;
    _bannerAction = null;
    _bannerActionLabel = null;
  }

  void _resetCode() {
    _codeCtrl.clear();
    _code = '';
  }

  Future<void> _onCompleted(String code) async {
    final flow = ref.read(loginFlowProvider);
    if (flow == null || _loading) return;
    HapticFeedback.lightImpact();

    if (flow.nameRequired && !_nombreValido) {
      // No se manda: `verify` rebotaría con NAME_REQUIRED y el cliente
      // quedaría mirando un error por un campo que tiene delante.
      setState(() {
        _nombreError = 'Contanos al menos tu nombre (2 letras o más).';
      });
      _nombreFocus.requestFocus();
      return;
    }
    await _verify(flow, code);
  }

  Future<void> _verify(LoginFlow flow, String code) async {
    final signup = ref.read(signupPendienteProvider);
    setState(() {
      _loading = true;
      _clearErrors();
    });
    try {
      await ref
          .read(authProvider.notifier)
          .verifyCode(
            flow.phone,
            code,
            name: flow.nameRequired ? _nombre : null,
            signupToken: signup?.token,
          );
      if (!mounted) return;
      // Sesión lista: el router redirige a /home. El CTA queda en "cargando"
      // hasta que esta pantalla desaparezca.
      _done = true;
      ref.read(loginFlowProvider.notifier).state = null;
      ref.read(signupPendienteProvider.notifier).state = null;
      return;
    } on AuthException catch (e) {
      if (!mounted) return;
      _handleVerifyError(e, flow, code);
    } catch (e, st) {
      debugPrint('[login] verifyCode error inesperado: $e\n$st');
      if (!mounted) return;
      setState(() {
        _error = 'Algo salió mal. Probá de nuevo.';
        _shakeSeed++;
      });
    }
    if (mounted) setState(() => _loading = false);
  }

  void _handleVerifyError(AuthException e, LoginFlow flow, String code) {
    switch (e.code) {
      case 'OTP_INVALID':
        final left = e.attemptsLeft;
        setState(() {
          _error = left == null
              ? 'Código incorrecto.'
              : left <= 0
              ? 'Código incorrecto. Pedí uno nuevo.'
              : 'Código incorrecto. Te ${left == 1 ? 'queda 1 intento' : 'quedan $left intentos'}.';
          _shakeSeed++;
          if (left != null && left <= 0) _forceResend = true;
          _resetCode();
        });
        HapticFeedback.heavyImpact();
      case 'OTP_EXPIRED':
        setState(() {
          _error = 'El código venció. Pedí uno nuevo.';
          _forceResend = true;
          _shakeSeed++;
          _resetCode();
        });
      case 'OTP_NOT_FOUND':
        _restartFlow();
      case 'RATE_LIMITED':
        final secs = e.retryIn ?? 60;
        setState(() {
          _resendBlockedUntil = DateTime.now().add(Duration(seconds: secs));
          _error =
              'Demasiados intentos. Esperá ${_fmt(secs)} y pedí un código nuevo.';
          _forceResend = true;
          _resetCode();
        });
      case 'NAME_REQUIRED':
        // El server dice que hace falta el nombre aunque `start` no lo hubiera
        // pedido. **El código NO se consumió**: alcanza con mostrar el campo y
        // reintentar con el mismo.
        ref.read(loginFlowProvider.notifier).state = flow.copyWith(
          nameRequired: true,
          clientKnown: false,
        );
        setState(() {
          _nombreError = 'Necesitamos tu nombre para crear la cuenta.';
        });
        _nombreFocus.requestFocus();
      case 'SOCIAL_ALREADY_LINKED':
        // Tampoco consume el código: la cuenta social ya es de otro cliente.
        // Se puede seguir sin ella, con este mismo código.
        ref.read(signupPendienteProvider.notifier).state = null;
        setState(() {
          _bannerError =
              'Esa cuenta ya está vinculada a otro cliente. Podés seguir con '
              'este número: volvé a tocar Confirmar.';
        });
      case 'SIGNUP_TOKEN_INVALID':
        ref.read(signupPendienteProvider.notifier).state = null;
        setState(() {
          _bannerError = e.expired
              ? 'Pasó demasiado tiempo desde que entraste con tu cuenta. '
                    'Seguimos sólo con tu número: volvé a tocar Confirmar.'
              : 'No pudimos usar tu cuenta social. Seguimos sólo con tu '
                    'número: volvé a tocar Confirmar.';
        });
      case 'NETWORK':
        setState(() {
          _bannerError = e.message;
          _bannerActionLabel = 'Reintentar';
          _bannerAction = () => _verify(flow, code);
        });
      default:
        setState(() {
          _error = e.message;
          _shakeSeed++;
          _resetCode();
        });
    }
  }

  Future<void> _restartFlow() async {
    final go = await showLiquidDialog<bool>(
      context,
      title: 'Volvé a empezar',
      message:
          'Ese código ya no es válido para este teléfono. Pedí uno nuevo desde tu número.',
      icon: Icons.restart_alt_rounded,
      actions: const [
        LiquidDialogAction(
          label: 'Ingresar mi número',
          value: true,
          primary: true,
        ),
      ],
      barrierDismissible: false,
    );
    if (!mounted) return;
    if (go == true || go == null) {
      ref.read(loginFlowProvider.notifier).state = null;
      context.go('/login');
    }
  }

  Future<void> _resend() async {
    final flow = ref.read(loginFlowProvider);
    if (flow == null || _resending || _loading) return;
    setState(() {
      _resending = true;
      _clearErrors();
    });
    try {
      final signup = ref.read(signupPendienteProvider);
      final res = await ref
          .read(authProvider.notifier)
          .startLogin(flow.phone, signupToken: signup?.token);
      if (!mounted) return;
      if (res.sessionReady) {
        // Raro (el dispositivo pasó a ser conocido) pero válido: sesión lista.
        _done = true;
        ref.read(loginFlowProvider.notifier).state = null;
        ref.read(signupPendienteProvider.notifier).state = null;
        return;
      }
      if (res.otpSent) {
        ref.read(loginFlowProvider.notifier).state = LoginFlow.fromStart(
          flow.phone,
          res,
          fallbackMasked: flow.phoneMasked,
        );
        setState(() {
          _forceResend = false;
          _resendBlockedUntil = null;
          _resetCode();
        });
        showLiquidToast(
          context,
          'Te mandamos un código nuevo por WhatsApp',
          tone: LiquidToastTone.success,
          icon: Icons.chat_rounded,
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      switch (e.code) {
        case 'RATE_LIMITED':
          final secs = e.retryIn ?? 600;
          setState(() {
            _resendBlockedUntil = DateTime.now().add(Duration(seconds: secs));
            _bannerError =
                'Demasiados envíos. Podés pedir otro código en ${_fmt(secs)}.';
          });
        case 'OTP_DELIVERY_FAILED':
          setState(() {
            _bannerError =
                'No pudimos mandarte el código por WhatsApp. Probá de nuevo en un rato o escribinos.';
            _bannerActionLabel = 'Escribinos';
            _bannerAction = _openSupport;
          });
        case 'NETWORK':
          setState(() {
            _bannerError = e.message;
            _bannerActionLabel = 'Reintentar';
            _bannerAction = _resend;
          });
        default:
          setState(() => _bannerError = e.message);
      }
    } catch (e, st) {
      debugPrint('[login] resend error inesperado: $e\n$st');
      if (!mounted) return;
      setState(
        () => _bannerError = 'No pudimos reenviar el código. Probá de nuevo.',
      );
    } finally {
      if (mounted) setState(() => _resending = false);
    }
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

  void _changeNumber() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/login');
    }
  }

  static String _fmt(int seconds) {
    if (seconds < 60) return '$seconds s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return s == 0 ? '$m min' : '$m:${s.toString().padLeft(2, '0')} min';
  }

  static String _mmss(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(loginFlowProvider);
    if (current != null) _lastFlow = current;
    final flow = current ?? (_done ? _lastFlow : null);
    if (flow == null) return const _ExpiredStep();

    final blockedLeft = _resendBlockedUntil == null
        ? 0
        : _resendBlockedUntil!
              .difference(DateTime.now())
              .inSeconds
              .clamp(0, 1 << 20);
    final remaining = _forceResend ? 0 : flow.resendRemaining;
    final canResend =
        remaining == 0 && blockedLeft == 0 && !_resending && !_loading;

    final String resendLabel;
    if (_resending) {
      resendLabel = 'Enviando…';
    } else if (blockedLeft > 0) {
      resendLabel = 'Reenviar en ${_mmss(blockedLeft)}';
    } else if (remaining > 0) {
      resendLabel = 'Reenviar en ${_mmss(remaining)}';
    } else {
      resendLabel = 'Reenviar código';
    }

    final greeting = flow.clientKnown && flow.firstName != null
        ? _GreetingChip(name: flow.firstName!)
        : null;

    final listo =
        _code.length == AppConstants.otpLength &&
        (!flow.nameRequired || _nombreValido);

    return OnboardingScaffold(
      showBack: true,
      onBack: _changeNumber,
      topRight: const MonacoLogo.monogram(width: 30),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          OnboardingCta(
            label: flow.nameRequired ? 'Crear mi cuenta' : 'Confirmar',
            icon: Icons.arrow_forward_rounded,
            loading: _loading || _done,
            onPressed: listo && !_done ? () => _onCompleted(_code) : null,
          ).liquidEnter(index: 5),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OnboardingLink(
                label: 'Cambiar número',
                icon: Icons.edit_rounded,
                onTap: _loading ? null : _changeNumber,
              ),
              OnboardingLink(
                label: resendLabel,
                icon: Icons.refresh_rounded,
                color: canResend ? MonacoColors.monacoGreen : null,
                onTap: canResend ? _resend : null,
              ),
            ],
          ).liquidEnter(index: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 18),
          OnboardingTitle(
            eyebrow: greeting,
            title: 'Revisá tu WhatsApp',
            subtitle:
                'Te mandamos un código de ${AppConstants.otpLength} dígitos a '
                '${flow.phoneMasked.isNotEmpty ? flow.phoneMasked : ArPhone.mask(flow.phone)}.',
          ).liquidEnter(index: 0),
          const SizedBox(height: 28),
          Center(
            child: ShakeOnChange(
              trigger: _shakeSeed,
              child: LiquidCodeField(
                key: const ValueKey('otp'),
                controller: _codeCtrl,
                length: AppConstants.otpLength,
                autofocus: true,
                enabled: !_loading,
                errorText: _error,
                boxSize: 46,
                onChanged: (v) => setState(() {
                  _code = v;
                  if (_error != null && v.isNotEmpty) _error = null;
                }),
                // Con el campo Nombre en pantalla NO se auto-envía al sexto
                // dígito: el cliente todavía puede estar por escribir el
                // nombre, y un submit automático que rebota se lee como que la
                // app se adelantó.
                onCompleted: flow.nameRequired ? null : _onCompleted,
              ),
            ),
          ).liquidEnter(index: 1),

          // ── Nombre (sólo si el teléfono es nuevo) ──
          if (flow.nameRequired) ...[
            const SizedBox(height: 22),
            LiquidTextField(
              controller: _nombreCtrl,
              focusNode: _nombreFocus,
              label: 'TU NOMBRE',
              hint: 'Ignacio Baldovino',
              helper: 'Así te saludamos y reservamos los turnos a tu nombre',
              keyboardType: TextInputType.name,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              enabled: !_loading,
              maxLength: 60,
              errorText: _nombreError,
              onSubmitted: (_) {
                if (listo) _onCompleted(_code);
              },
            ).liquidEnter(index: 2),
          ],

          const SizedBox(height: 20),
          AnimatedSize(
            duration: LiquidTokens.swap,
            curve: LiquidTokens.curveSwap,
            alignment: Alignment.topCenter,
            child: _bannerError == null
                ? const SizedBox.shrink()
                : OnboardingErrorBox(
                    message: _bannerError!,
                    actionLabel: _bannerActionLabel,
                    onAction: _bannerAction,
                  ).animate().fadeIn(duration: 220.ms),
          ),
          const SizedBox(height: 8),
          _ExpiryHint(flow: flow).liquidEnter(index: 3),
        ],
      ),
    );
  }
}

/// "Hola de nuevo, Nacho" — el server ya lo conoce.
class _GreetingChip extends StatelessWidget {
  final String name;
  const _GreetingChip({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          colors: [
            MonacoColors.monacoGreen.withValues(alpha: 0.26),
            MonacoColors.monacoGreen.withValues(alpha: 0.10),
          ],
        ),
        border: Border.all(
          color: MonacoColors.monacoGreen.withValues(alpha: 0.45),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.waving_hand_rounded,
            size: 14,
            color: MonacoColors.monacoGreen,
          ),
          const SizedBox(width: 7),
          Text(
            'Hola de nuevo, $name',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// "El código vence en 9:41" / "El código venció".
class _ExpiryHint extends StatelessWidget {
  final LoginFlow flow;
  const _ExpiryHint({required this.flow});

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(flow.sentAt).inSeconds;
    final left = (flow.expiresIn - elapsed).clamp(0, 1 << 20);
    final expired = left == 0;
    final color = expired
        ? MonacoColors.warning
        : Colors.white.withValues(alpha: 0.45);
    final m = left ~/ 60;
    final s = (left % 60).toString().padLeft(2, '0');
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          expired ? Icons.timer_off_outlined : Icons.timer_outlined,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(
          expired
              ? 'El código venció: pedí uno nuevo.'
              : 'El código vence en $m:$s',
          style: TextStyle(
            color: color,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Se llegó a /login/codigo sin flujo (la app se reinició, deep link…).
class _ExpiredStep extends StatelessWidget {
  const _ExpiredStep();

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      showBack: true,
      onBack: () => context.go('/login'),
      centered: true,
      footer: OnboardingCta(
        label: 'Ingresar mi número',
        icon: Icons.arrow_forward_rounded,
        onPressed: () => context.go('/login'),
      ),
      child: const LiquidEmptyState(
        scrollable: false,
        icon: Icons.timer_off_outlined,
        title: 'Este paso venció',
        message: 'Volvé a ingresar tu número y te mandamos un código nuevo.',
      ),
    );
  }
}
