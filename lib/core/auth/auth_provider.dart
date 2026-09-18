import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../supabase/supabase_provider.dart';
import 'auth_service.dart';
import 'secure_storage.dart';
import 'biometric_service.dart';
import 'pin_service.dart';
import 'social_auth_service.dart';

/// Estados del ciclo de auth.
///
/// - `needsBiometric`: hay sesión pero el cliente activó el gate local.
/// - `guest`: **no hay sesión y está bien.** El cliente tocó "Seguir mirando":
///   navega sucursales, servicios, la fila en vivo, la cartelera y la vidriera
///   de premios, y el muro de login aparece recién cuando toca una acción que
///   necesita cuenta. Es requisito de la App Store (5.1.1: si la app no es
///   toda "account-based", tiene que dejar usarla sin login) y además es lo que
///   conviene con publicidad: el que baja la app por un anuncio todavía no es
///   cliente.
///
/// **No hay `needsBranch`.** La app es de Monaco entera, no de una sucursal: el
/// cliente entra directo al home y la sucursal se elige recién cuando importa
/// —en el primer paso de la reserva de turno—. Antes había un gate de
/// onboarding "¿a qué sucursal vas?" y una sucursal pegada al perfil que
/// filtraba media app; eso se eliminó (24/ago/2026).
enum AuthStatus {
  initial,
  unauthenticated,
  guest,
  needsBiometric,
  authenticated,
}

/// Estado de auth (mono-org: la organización es `AppConstants.organizationId`).
class AuthState {
  final AuthStatus status;
  final String? clientId;
  final String? clientName;
  final String? clientPhone;
  final String? error;
  final bool isNewClient;

  const AuthState({
    this.status = AuthStatus.initial,
    this.clientId,
    this.clientName,
    this.clientPhone,
    this.error,
    this.isNewClient = false,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated;

  /// Está mirando sin cuenta. **No es lo mismo que `!isAuthenticated`**: el
  /// estado `unauthenticated` es "todavía no decidió" (pantalla de bienvenida)
  /// y `guest` es "decidió que no, por ahora".
  bool get isGuest => status == AuthStatus.guest;

  /// Puede usar cualquier cosa que necesite `client_id`. Es el gate que miran
  /// las pantallas antes de mostrar datos personales.
  bool get tieneCuenta =>
      clientId != null && status == AuthStatus.authenticated;

  /// Primer nombre para saludar ("Hola, Nacho"). Si el nombre es sólo
  /// dígitos (cuenta vieja sin nombre) devuelve "".
  String get firstName {
    final n = (clientName ?? '').trim();
    if (n.isEmpty || RegExp(r'^\d+$').hasMatch(n)) return '';
    return n.split(RegExp(r'\s+')).first;
  }

  AuthState copyWith({
    AuthStatus? status,
    String? clientId,
    String? clientName,
    String? clientPhone,
    String? error,
    bool? isNewClient,
  }) {
    return AuthState(
      status: status ?? this.status,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      error: error,
      isNewClient: isNewClient ?? this.isNewClient,
    );
  }
}

/// Resultado de `startLogin`: o hay sesión, o se mandó un código.
class StartResult {
  final bool sessionReady;
  final bool otpSent;
  final String? phoneMasked;
  final int expiresIn;
  final int resendIn;
  final bool clientKnown;

  /// El server pide el nombre ANTES de `verify`. Cuando es `true`, la pantalla
  /// del código tiene que incluir el campo Nombre: si no, `verify` rebota con
  /// `NAME_REQUIRED` con el código ya tipeado.
  ///
  /// No es exactamente `!clientKnown`: el nombre puede venir en el
  /// `signup_token` de Google/Apple, y ahí el teléfono es nuevo pero el nombre
  /// no hace falta.
  final bool nameRequired;

  final String? firstName;

  const StartResult({
    required this.sessionReady,
    required this.otpSent,
    this.phoneMasked,
    this.expiresIn = 600,
    this.resendIn = 45,
    this.clientKnown = false,
    this.nameRequired = false,
    this.firstName,
  });
}

/// Lo que devuelve un intento de entrar con Google/Apple.
///
/// `sessionReady` = la identidad ya estaba vinculada y el cliente está adentro.
/// Si no, hay que pedirle el teléfono y arrastrar [signupToken] hasta `verify`.
class SocialOutcome {
  final bool sessionReady;
  final String? signupToken;
  final String? suggestedName;
  final String? email;
  final SocialProvider provider;

  const SocialOutcome({
    required this.sessionReady,
    required this.provider,
    this.signupToken,
    this.suggestedName,
    this.email,
  });
}

/// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(supabaseClientProvider));
});

/// Aviso pendiente para la pantalla de bienvenida: por qué se cerró la sesión.
///
/// Lo escribe [AuthNotifier.sesionInvalidada] y lo consume `WelcomeScreen` una
/// sola vez (lo lee, muestra el toast y lo apaga). Existe porque el cierre
/// pasa lejos de cualquier pantalla —lo dispara una respuesta de la API— y sin
/// una palabra el cliente ve la app "volver sola al principio" sin motivo.
final mensajeDeSesionProvider = StateProvider<String?>((ref) => null);

/// Main auth state provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

/// Coordinador de auth: resuelve el estado al arrancar, expone los tres caminos
/// de entrada (social, teléfono, invitado) y limpia lo que hay que limpiar al
/// salir.
class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;
  StreamSubscription? _authSub;
  bool _initialized = false;
  bool _cerrandoSesionInvalida = false;

  /// `true` mientras corre [deleteAccount]. `AuthService.deleteAccount()`
  /// hace un `signOut()` local después de que el server borró la cuenta, y el
  /// evento `signedOut` de ese signOut llegaría a [_onAuthEvent] a MITAD del
  /// flujo: pondría `unauthenticated` y el router redirigiría a `/welcome`
  /// mientras la pantalla de Perfil todavía espera la respuesta — que es como
  /// terminó en pantalla negra el 18/9/2026 (ver `_executeDeleteAccount`).
  /// Con la marca puesta el evento se ignora y el estado lo fija
  /// [deleteAccount] una sola vez, al final.
  bool _borrandoCuenta = false;

  AuthNotifier(this._ref) : super(const AuthState()) {
    _init();
  }

  SupabaseClient get _client => _ref.read(supabaseClientProvider);
  AuthService get _authService => _ref.read(authServiceProvider);

  Future<void> _init() async {
    _authSub = _client.auth.onAuthStateChange.listen(_onAuthEvent);
    try {
      final session = _client.auth.currentSession;
      if (session == null) {
        state = AuthState(status: await _estadoSinSesion());
        return;
      }
      final clientId = await SecureStorageService.getClientId();
      if (clientId == null) {
        await _clearLocalSession();
        state = AuthState(status: await _estadoSinSesion());
        return;
      }
      final name = await SecureStorageService.getClientName();
      final phone = await SecureStorageService.getClientPhone();
      // Residuo de la sucursal global (app <= ago/2026): se borra una vez y no
      // se vuelve a leer. Sin esto quedaría escrito en el Keychain de todos los
      // instalados para siempre.
      unawaited(SecureStorageService.clearSelectedBranch());
      // Gate local: biometría o PIN (cualquiera de los dos lo pide al abrir).
      final bioEnabled = await SecureStorageService.isBiometricEnabled();
      final pinEnabled = await PinService.isEnabled();
      state = AuthState(
        status: (bioEnabled || pinEnabled)
            ? AuthStatus.needsBiometric
            : AuthStatus.authenticated,
        clientId: clientId,
        clientName: name,
        clientPhone: phone,
      );
    } catch (e, st) {
      debugPrint('[auth] _init error: $e\n$st');
      await _clearLocalSession();
      state = const AuthState(status: AuthStatus.unauthenticated);
    } finally {
      _initialized = true;
    }
  }

  /// Sin sesión hay dos estados posibles y no son lo mismo: el que nunca
  /// decidió va a la bienvenida; el que ya eligió "Seguir mirando" vuelve al
  /// Home de invitado. La marca vive en el Keychain justamente para sobrevivir
  /// a cerrar la app.
  Future<AuthStatus> _estadoSinSesion() async {
    try {
      if (await SecureStorageService.isGuestMode()) return AuthStatus.guest;
    } catch (e) {
      debugPrint('[auth] no se pudo leer el modo invitado: $e');
    }
    return AuthStatus.unauthenticated;
  }

  void _onAuthEvent(sb.AuthState data) {
    if (!_initialized) return;
    if (_borrandoCuenta) return;
    if (data.event == sb.AuthChangeEvent.signedOut) {
      unawaited(SecureStorageService.clearSession());
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> _clearLocalSession() async {
    try {
      await _client.auth.signOut();
    } catch (_) {}
    await SecureStorageService.clearSession();
  }

  /// Entrar con Google o Apple. Devuelve si ya hay sesión o si falta el
  /// teléfono (`need_phone`, con el `signup_token` de 15 minutos).
  ///
  /// Deja pasar hacia arriba [SocialAuthCancelled] (el usuario cerró la hoja:
  /// no se muestra nada), [SocialAuthUnavailable] (problema nuestro o de red:
  /// reintentable) y [AuthException] (lo que contestó nuestro server).
  Future<SocialOutcome> signInWithSocial(SocialProvider provider) async {
    final cred = provider == SocialProvider.google
        ? await SocialAuthService.google()
        : await SocialAuthService.apple();

    final res = await _authService.signInWithSocial(cred);
    if (res.sessionReady) {
      await _afterSession(
        StartResult(
          sessionReady: true,
          otpSent: false,
          clientKnown: res.clientKnown,
        ),
      );
      return SocialOutcome(sessionReady: true, provider: provider);
    }
    return SocialOutcome(
      sessionReady: false,
      provider: provider,
      signupToken: res.signupToken,
      // El nombre de Apple llega FUERA del token y sólo la primera vez: si el
      // server no lo sugirió, usamos el que nos dio la credencial para no
      // perderlo.
      suggestedName: (res.suggestedName?.isNotEmpty ?? false)
          ? res.suggestedName
          : cred.name,
      email: res.email ?? cred.email,
    );
  }

  /// Paso 1 del login: teléfono. Si el dispositivo ya es conocido, la sesión
  /// queda lista; si no, se mandó un código por WhatsApp. [signupToken] va sólo
  /// si el cliente viene de Google/Apple.
  Future<StartResult> startLogin(String phone, {String? signupToken}) async {
    final res = await _authService.startLogin(
      phone: phone,
      signupToken: signupToken,
    );
    if (res.sessionReady) {
      await _afterSession(res);
    }
    return res;
  }

  /// Paso 2: código (y nombre si el teléfono es nuevo).
  Future<void> verifyCode(
    String phone,
    String code, {
    String? name,
    String? signupToken,
  }) async {
    final res = await _authService.verifyCode(
      phone: phone,
      code: code,
      name: name,
      signupToken: signupToken,
    );
    await _afterSession(res);
  }

  // ── Modo invitado ────────────────────────────────────────────────────────

  /// "Seguir mirando": pasa a invitado. La marca se persiste para que la
  /// próxima apertura no vuelva a plantarle la bienvenida.
  ///
  /// **No navega: el que llama tiene que hacer `context.go('/home')`.** Cambiar
  /// el estado NO alcanza para salir de la bienvenida: `/welcome` está en la
  /// lista blanca del invitado (un invitado que entró a `/login` desde el muro
  /// y toca "volver" cae ahí), así que el redirect del router ve `guest` +
  /// `/welcome` y contesta "quedate". Y si ya era invitado, el estado ni
  /// cambia y el router ni se entera. Fue el bug por el que el link "no
  /// entraba" (12–18/sep/2026).
  ///
  /// Si el Keychain falla, igual se entra: lo único que se pierde es que la
  /// próxima apertura vuelva a mostrar la bienvenida.
  Future<void> continuarComoInvitado() async {
    try {
      await SecureStorageService.setGuestMode(true);
    } catch (e) {
      debugPrint('[auth] no se pudo persistir el modo invitado: $e');
    }
    state = const AuthState(status: AuthStatus.guest);
  }

  /// Vuelve a la pantalla de bienvenida desde el modo invitado (el link
  /// "Crear cuenta" del perfil de invitado).
  Future<void> salirDelModoInvitado() async {
    await SecureStorageService.setGuestMode(false);
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> _afterSession(StartResult res) async {
    // Ya no es invitado: si quedara la marca, un logout futuro lo devolvería al
    // Home sin cuenta en vez de a la bienvenida.
    await SecureStorageService.setGuestMode(false);
    final clientId = await SecureStorageService.getClientId();
    final name = await SecureStorageService.getClientName();
    final phone = await SecureStorageService.getClientPhone();
    state = AuthState(
      status: AuthStatus.authenticated,
      clientId: clientId,
      clientName: name,
      clientPhone: phone,
      isNewClient: !res.clientKnown,
    );
  }

  Future<bool> authenticateWithBiometrics() async {
    final success = await BiometricService.authenticate();
    if (success) completeBiometric();
    return success;
  }

  void completeBiometric() {
    state = state.copyWith(status: AuthStatus.authenticated);
  }

  /// Cierra sesión. `signOut()` → `clearSession()` borra también el PIN, la
  /// biometría y la marca de invitado: son gates de ESTA cuenta en ESTE equipo
  /// y sobrevivirle al cambio de cuenta dejaba al siguiente con un candado
  /// ajeno que no podía abrir. El `device_secret` **no** se toca (es lo que
  /// permite volver a entrar sin código).
  Future<void> logout() async {
    await _authService.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// La API contestó que este JWT ya no representa a ningún cliente
  /// (`UNAUTHENTICATED` / 401 con la sesión ya refrescada, o `NO_CLIENT`
  /// porque la ficha se borró o se fusionó desde el dashboard). Cierra la
  /// sesión local y deja un aviso para la bienvenida.
  ///
  /// **No entra en loop**: sólo actúa si hay una sesión abierta, y el estado
  /// pasa a `unauthenticated` antes de que ninguna otra request pueda volver a
  /// llamarla; las que ya estaban en vuelo encuentran el guard cerrado.
  Future<void> sesionInvalidada() async {
    if (_cerrandoSesionInvalida) return;
    final s = state.status;
    if (s != AuthStatus.authenticated && s != AuthStatus.needsBiometric) return;
    _cerrandoSesionInvalida = true;
    try {
      _ref.read(mensajeDeSesionProvider.notifier).state =
          'Tu sesión ya no es válida. Volvé a entrar.';
      await logout();
    } catch (e) {
      debugPrint('[auth] cierre por sesión inválida falló: $e');
      state = const AuthState(status: AuthStatus.unauthenticated);
    } finally {
      _cerrandoSesionInvalida = false;
    }
  }

  /// Apple 5.1.1(v): borrar la cuenta desde la app. `null` = OK.
  ///
  /// El estado se fija acá y sólo acá, al final: el `signedOut` que dispara el
  /// signOut local de `AuthService.deleteAccount()` se ignora mientras
  /// [_borrandoCuenta] está puesta (ver el campo). Si el borrado falla, el
  /// estado no se toca: el cliente sigue adentro y ve el motivo.
  Future<String?> deleteAccount() async {
    _borrandoCuenta = true;
    try {
      final err = await _authService.deleteAccount();
      if (err == null) {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
      return err;
    } finally {
      _borrandoCuenta = false;
    }
  }

  /// Actualiza el nombre en el estado + storage local (la persistencia remota
  /// la hace quien llama, vía API).
  Future<void> updateClientName(String name) async {
    final clientId = state.clientId;
    if (clientId != null) {
      await SecureStorageService.saveClientInfo(
        clientId: clientId,
        name: name,
        phone: state.clientPhone ?? '',
      );
    }
    state = state.copyWith(clientName: name);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
