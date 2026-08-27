import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/core/auth/auth_provider.dart';
import 'package:monaco_mobile/core/auth/auth_service.dart';

import '../../providers/login_flow_provider.dart';
import '../widgets/onboarding_scaffold.dart';

/// Paso 3 (sólo clientes nuevos): el nombre. Recién acá se llama a `verify`
/// con el código del paso anterior + el nombre, que el server exige para
/// crear la fila en `clients`.
class LoginNameScreen extends ConsumerStatefulWidget {
  const LoginNameScreen({super.key});

  @override
  ConsumerState<LoginNameScreen> createState() => _LoginNameScreenState();
}

class _LoginNameScreenState extends ConsumerState<LoginNameScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _lastFocus = FocusNode();

  bool _loading = false;
  String? _fieldError;
  String? _banner;
  VoidCallback? _bannerAction;

  /// Verificación exitosa: el router ya está navegando. Seguimos dibujando con
  /// la última copia del flujo para no mostrar "Este paso venció" un frame.
  bool _done = false;
  LoginFlow? _lastFlow;

  String get _fullName => '${_first.text.trim()} ${_last.text.trim()}'.trim();
  bool get _valid => _first.text.trim().length >= 2 && _fullName.length <= 80;

  @override
  void initState() {
    super.initState();
    _first.addListener(_onChanged);
    _last.addListener(_onChanged);
  }

  void _onChanged() => setState(() {
    _fieldError = null;
    _banner = null;
  });

  @override
  void dispose() {
    _first.removeListener(_onChanged);
    _last.removeListener(_onChanged);
    _first.dispose();
    _last.dispose();
    _lastFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final flow = ref.read(loginFlowProvider);
    if (_loading) return;
    if (flow == null || flow.code == null) {
      context.go('/login');
      return;
    }
    if (!_valid) {
      setState(
        () => _fieldError = 'Contanos al menos tu nombre (2 letras o más).',
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _fieldError = null;
      _banner = null;
    });

    final name = _fullName;
    try {
      await ref
          .read(authProvider.notifier)
          .verifyCode(flow.phone, flow.code!, name: name);
      if (!mounted) return;
      // Sesión lista: el router manda directo a /home (la sucursal ya no se
      // elige en el onboarding: se elige al reservar). El CTA
      // queda en "cargando" hasta que esta pantalla desaparezca.
      _done = true;
      ref.read(loginFlowProvider.notifier).state = null;
      return;
    } on AuthException catch (e) {
      if (!mounted) return;
      switch (e.code) {
        case 'OTP_INVALID':
          final left = e.attemptsLeft;
          _backToCode(
            left == null
                ? 'Código incorrecto.'
                : left <= 0
                ? 'Código incorrecto. Pedí uno nuevo.'
                : 'Código incorrecto. Te ${left == 1 ? 'queda 1 intento' : 'quedan $left intentos'}.',
          );
        case 'OTP_EXPIRED':
          _backToCode('El código venció. Pedí uno nuevo.');
        case 'OTP_NOT_FOUND':
          ref.read(loginFlowProvider.notifier).state = null;
          showLiquidToast(
            context,
            'Ese código ya no es válido. Volvé a ingresar tu número.',
            tone: LiquidToastTone.error,
          );
          context.go('/login');
        case 'NAME_REQUIRED':
          setState(
            () => _fieldError = 'Necesitamos tu nombre para crear la cuenta.',
          );
        case 'RATE_LIMITED':
          _backToCode(
            'Demasiados intentos. Esperá un momento y pedí un código nuevo.',
          );
        case 'NETWORK':
          setState(() {
            _banner = e.message;
            _bannerAction = _submit;
          });
        default:
          setState(() {
            _banner = e.message;
            _bannerAction = null;
          });
      }
    } catch (e, st) {
      debugPrint('[login] verify con nombre error inesperado: $e\n$st');
      if (!mounted) return;
      setState(() {
        _banner = 'Algo salió mal. Probá de nuevo.';
        _bannerAction = _submit;
      });
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Vuelve al paso del código dejándole el error para que lo muestre.
  void _backToCode(String error) {
    final flow = ref.read(loginFlowProvider);
    if (flow != null) {
      ref.read(loginFlowProvider.notifier).state = flow.copyWith(
        pendingCodeError: error,
        clearCode: true,
      );
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/login/codigo');
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(loginFlowProvider);
    if (current != null) _lastFlow = current;
    final flow = current ?? (_done ? _lastFlow : null);
    if (flow == null || flow.code == null) {
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

    return OnboardingScaffold(
      showBack: true,
      onBack: _back,
      topRight: const MonacoLogo.monogram(width: 30),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          OnboardingCta(
            label: 'Listo',
            icon: Icons.check_rounded,
            loading: _loading || _done,
            onPressed: _valid && !_done ? _submit : null,
          ).liquidEnter(index: 4),
          const SizedBox(height: 8),
          Text(
            'Lo podés cambiar después desde tu perfil.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.42),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ).liquidEnter(index: 5),
        ],
      ),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 18),
            const OnboardingTitle(
              title: '¿Cómo te llamás?',
              subtitle:
                  'Así te saludamos en la barbería y reservamos los turnos a tu nombre.',
            ).liquidEnter(index: 0),
            const SizedBox(height: 32),
            LiquidTextField(
              controller: _first,
              autofocus: true,
              label: 'NOMBRE',
              hint: 'Ignacio',
              keyboardType: TextInputType.name,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.givenName],
              enabled: !_loading,
              maxLength: 40,
              errorText: _fieldError,
              onSubmitted: (_) => _lastFocus.requestFocus(),
            ).liquidEnter(index: 1),
            const SizedBox(height: 16),
            LiquidTextField(
              controller: _last,
              focusNode: _lastFocus,
              label: 'APELLIDO',
              hint: 'Baldovino',
              helper: 'Opcional',
              keyboardType: TextInputType.name,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.familyName],
              enabled: !_loading,
              maxLength: 40,
              onSubmitted: (_) => _submit(),
            ).liquidEnter(index: 2),
            const SizedBox(height: 18),
            AnimatedSize(
              duration: LiquidTokens.swap,
              curve: LiquidTokens.curveSwap,
              alignment: Alignment.topCenter,
              child: _banner == null
                  ? const SizedBox.shrink()
                  : OnboardingErrorBox(
                      message: _banner!,
                      actionLabel: _bannerAction == null ? null : 'Reintentar',
                      onAction: _bannerAction,
                    ).animate().fadeIn(duration: 220.ms),
            ),
            const SizedBox(height: 10),
            _PreviewChip(name: _fullName).liquidEnter(index: 3),
          ],
        ),
      ),
    );
  }
}

/// "Te vamos a saludar como: Hola, Ignacio" — feedback inmediato del nombre.
class _PreviewChip extends StatelessWidget {
  final String name;
  const _PreviewChip({required this.name});

  @override
  Widget build(BuildContext context) {
    final first = name.trim().isEmpty
        ? null
        : name.trim().split(RegExp(r'\s+')).first;
    return AnimatedOpacity(
      duration: LiquidTokens.swap,
      opacity: first == null ? 0 : 1,
      child: Row(
        children: [
          LiquidAvatar(name: name, size: 40, tint: MonacoColors.monacoGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hola, ${first ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Así te vamos a saludar',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
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
