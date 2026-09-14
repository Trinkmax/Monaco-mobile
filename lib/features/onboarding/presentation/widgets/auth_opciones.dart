import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart'
    show AppleLogoPainter;

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/core/auth/auth_provider.dart';
import 'package:monaco_mobile/core/auth/auth_service.dart';
import 'package:monaco_mobile/core/auth/social_auth_service.dart';

import '../../providers/login_flow_provider.dart';
import 'google_g.dart';
import 'onboarding_scaffold.dart';

/// Las tres puertas de entrada, en un bloque reutilizable.
///
/// Lo usan la pantalla de bienvenida y el muro de login que aparece cuando un
/// invitado toca una acción con cuenta: si fueran dos implementaciones, el día
/// que se agregue un proveedor una de las dos se olvidaría.
///
/// El orden no es casual: **Google y Apple primero** porque son un toque, y el
/// teléfono tercero **con el mismo peso visual** (mismo alto, misma lámina)
/// porque sigue siendo el camino de los ~6.400 clientes que ya existen y no
/// tienen por qué usar una cuenta de terceros.
class AuthOpciones extends ConsumerStatefulWidget {
  /// Qué hacer cuando la sesión quedó lista. Si es `null`, no se hace nada: el
  /// router redirige solo al cambiar el `AuthStatus`.
  final VoidCallback? onSesionLista;

  /// Se llama antes de navegar a `/login` (para cerrar la hoja del muro).
  final VoidCallback? onAntesDeNavegar;

  const AuthOpciones({super.key, this.onSesionLista, this.onAntesDeNavegar});

  @override
  ConsumerState<AuthOpciones> createState() => _AuthOpcionesState();
}

class _AuthOpcionesState extends ConsumerState<AuthOpciones> {
  SocialProvider? _cargando;
  String? _error;

  Future<void> _social(SocialProvider provider) async {
    if (_cargando != null) return;
    setState(() {
      _cargando = provider;
      _error = null;
    });
    try {
      final res = await ref
          .read(authProvider.notifier)
          .signInWithSocial(provider);
      if (!mounted) return;

      if (res.sessionReady) {
        // El router ya está redirigiendo: dejamos el botón en "cargando" para
        // que no parezca que no pasó nada mientras la pantalla se va.
        widget.onSesionLista?.call();
        return;
      }

      // Falta el teléfono. El `signup_token` vive 15 minutos y viaja en memoria
      // hasta `verify`: no se guarda en ningún lado.
      ref.read(signupPendienteProvider.notifier).state = SignupPendiente(
        token: res.signupToken!,
        proveedor: provider,
        nombreSugerido: res.suggestedName,
        email: res.email,
      );
      ref.read(loginFlowProvider.notifier).state = null;
      // El router se toma ANTES de cerrar la hoja: `onAntesDeNavegar` hace pop
      // y con eso este widget queda desactivado, así que `context.push` ya no
      // encontraría el GoRouter en el árbol.
      final router = GoRouter.of(context);
      widget.onAntesDeNavegar?.call();
      router.push('/login');
    } on SocialAuthCancelled {
      // Cerró la hoja del proveedor: no es un error, no se dice nada.
    } on SocialAuthUnavailable catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = _mensajeDeServidor(e, provider));
    } catch (e, st) {
      debugPrint('[auth] social inesperado: $e\n$st');
      if (mounted) {
        setState(
          () => _error = 'Algo salió mal. Probá de nuevo en un momento.',
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = null);
    }
  }

  /// Traduce lo que contesta `client-auth`. Regla que no hay que aflojar:
  /// **`SOCIAL_VERIFY_UNAVAILABLE` no se le echa a la cuenta del cliente.** Es
  /// un 503: no pudimos bajar el JWKS del proveedor o falta configurar los
  /// client IDs. Decirle "tu cuenta de Google no sirve" lo manda a resolver un
  /// problema que no tiene.
  String _mensajeDeServidor(AuthException e, SocialProvider provider) {
    switch (e.code) {
      case 'SOCIAL_VERIFY_UNAVAILABLE':
        return 'No pudimos verificar tu cuenta de ${provider.label} en este '
            'momento. Probá de nuevo o entrá con tu número.';
      case 'SOCIAL_TOKEN_INVALID':
        return 'No pudimos validar tu cuenta de ${provider.label}. Probá de '
            'nuevo o entrá con tu número.';
      case 'SOCIAL_ALREADY_LINKED':
        return 'Esa cuenta de ${provider.label} ya está vinculada a otro '
            'cliente. Entrá con el número de teléfono de esa cuenta.';
      case 'SIGNUP_DISABLED':
        return 'Por ahora no podemos crear cuentas nuevas desde la app. '
            'Entrá con el número que registraste en la barbería.';
      case 'RATE_LIMITED':
        return 'Demasiados intentos. Esperá un momento y probá de nuevo.';
      case 'NETWORK':
        return e.message;
      default:
        return e.message;
    }
  }

  void _telefono() {
    // Entrar con el número es un camino propio: cualquier `signup_token` de un
    // intento social anterior se descarta, o el server intentaría vincular una
    // identidad que el cliente ya abandonó.
    ref.read(signupPendienteProvider.notifier).state = null;
    ref.read(loginFlowProvider.notifier).state = null;
    // Ídem: capturar el router antes del pop de la hoja.
    final router = GoRouter.of(context);
    widget.onAntesDeNavegar?.call();
    router.push('/login');
  }

  @override
  Widget build(BuildContext context) {
    final ocupado = _cargando != null;
    final google = SocialAuthService.googleConfigurado;
    final apple = SocialAuthService.appleDisponible;
    // Sin ningún proveedor social (Android sin client id, o una build con
    // `SOCIAL_LOGIN_ENABLED=false`) la columna quedaba con UNA sola pastilla
    // translúcida y ningún botón primario: una bienvenida que se ve inconclusa.
    // El teléfono toma la lámina sólida sólo en ese caso — con Google o Apple
    // en pantalla, el primario es el social y dos superficies blancas juntas
    // anularían la jerarquía.
    final telefonoEsPrimario = !google && !apple;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_error != null) ...[
          OnboardingErrorBox(message: _error!),
          const SizedBox(height: 12),
        ],
        if (google) ...[
          _BotonSocial(
            label: 'Continuar con Google',
            glyph: const GoogleG(size: 20),
            solido: true,
            cargando: _cargando == SocialProvider.google,
            onPressed: ocupado ? null : () => _social(SocialProvider.google),
          ),
          const SizedBox(height: 10),
        ],
        // Apple SÓLO en iOS. En Android `sign_in_with_apple` abre un Custom Tab
        // contra un servidor propio (deja de ser nativo) y la guideline 4.8 —la
        // que obliga a ofrecer Apple si ofrecemos Google— es de la App Store.
        //
        // Va con el MISMO peso visual que Google (lámina blanca sólida, logo
        // negro): la HIG de Sign in with Apple pide que el botón no sea más
        // chico ni menos prominente que los otros, y App Review lo mira bajo la
        // 4.8. El borde blanco sobre negro que tenía antes es una forma válida
        // del botón, pero al lado de una lámina opaca se leía como secundario.
        if (apple) ...[
          _BotonSocial(
            label: 'Continuar con Apple',
            // **La caja NO es cuadrada, y no se puede volver cuadrada.**
            // `AppleLogoPainter` normaliza el path de la manzana a 0..1 en los
            // DOS ejes, así que pinta lo que le den: en un cuadrado de 20×20 la
            // manzana sale ensanchada. El glifo real mide 0,83 de ancho por
            // cada 1 de alto (es el ratio del logo de Apple, hoja incluida), y
            // eso es 17 × 20,5.
            glyph: const SizedBox(
              width: 17,
              height: 20.5,
              child: CustomPaint(
                painter: AppleLogoPainter(color: Colors.black),
              ),
            ),
            solido: true,
            cargando: _cargando == SocialProvider.apple,
            onPressed: ocupado ? null : () => _social(SocialProvider.apple),
          ),
          const SizedBox(height: 10),
        ],
        _BotonSocial(
          label: 'Usar mi número de teléfono',
          glyph: Icon(
            Icons.chat_rounded,
            size: 20,
            // **Gris, no verde** (decisión del dueño, 12/sep/2026). El verde es
            // el color del NEGOCIO ("sin espera", turno confirmado, éxito), no
            // el de un ícono decorativo al lado de un botón: pintado acá
            // competía con los dos botones sociales y con la pastilla del
            // carrusel. Sobre la lámina blanca (cuando el teléfono es el
            // primario) el gris tiene que ser más oscuro para leerse.
            color: telefonoEsPrimario
                ? MonacoColors.foregroundSubtle
                : MonacoColors.foregroundMuted,
          ),
          solido: telefonoEsPrimario,
          cargando: false,
          onPressed: ocupado ? null : _telefono,
        ),
      ],
    );
  }
}

/// Botón de 56 de alto con el glifo del proveedor a la izquierda y el texto
/// centrado ópticamente.
///
/// [solido] = lámina blanca opaca. Sobre vidrio oscuro es lo que el ojo lee
/// como "esto se toca", así que se reserva para los botones que la pantalla
/// quiere que se usen: **los sociales** (Google y Apple con el mismo peso, que
/// es lo que exige la HIG de Sign in with Apple) o, cuando no hay ninguno, el
/// del teléfono. Nunca dos láminas blancas compitiendo con una tercera.
class _BotonSocial extends StatelessWidget {
  final String label;
  final Widget glyph;
  final bool solido;
  final bool cargando;
  final VoidCallback? onPressed;

  const _BotonSocial({
    required this.label,
    required this.glyph,
    required this.solido,
    required this.cargando,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final habilitado = onPressed != null && !cargando;
    final colorTexto = solido ? MonacoColors.background : Colors.white;

    final contenido = cargando
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: colorTexto,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              glyph,
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorTexto,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          );

    return Semantics(
      button: true,
      enabled: habilitado,
      label: label,
      child: AnimatedOpacity(
        duration: LiquidTokens.swap,
        opacity: habilitado ? 1 : 0.55,
        child: SizedBox(
          height: 56,
          width: double.infinity,
          child: solido
              // `LiquidTapEffect.onTap` no es opcional: el gate del estado
              // deshabilitado lo pone el AbsorbPointer.
              ? AbsorbPointer(
                  absorbing: !habilitado,
                  child: LiquidTapEffect(
                    onTap: onPressed ?? () {},
                    borderRadius: BorderRadius.circular(18),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.34),
                            blurRadius: 16,
                            spreadRadius: -4,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(child: contenido),
                    ),
                  ),
                )
              : LiquidPill(
                  onTap: habilitado ? onPressed : null,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  borderRadius: 18,
                  tintOpacity: 0.08,
                  child: Center(child: contenido),
                ),
        ),
      ),
    );
  }
}
