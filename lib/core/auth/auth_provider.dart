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

/// Estados del ciclo de auth.
///
/// - `needsBiometric`: hay sesión pero el cliente activó el gate local.
///
/// **No hay `needsBranch`.** La app es de Monaco entera, no de una sucursal: el
/// cliente entra directo al home y la sucursal se elige recién cuando importa
/// —en el primer paso de la reserva de turno—. Antes había un gate de
/// onboarding "¿a qué sucursal vas?" y una sucursal pegada al perfil que
/// filtraba media app; eso se eliminó (24/ago/2026).
enum AuthStatus {
  initial,
  unauthenticated,
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
  final String? firstName;

  const StartResult({
    required this.sessionReady,
    required this.otpSent,
    this.phoneMasked,
    this.expiresIn = 600,
    this.resendIn = 45,
    this.clientKnown = false,
    this.firstName,
  });
}

/// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(supabaseClientProvider));
});

/// Main auth state provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

/// NOTA para el agente de auth (F1): este notifier es el ESQUELETO del
/// coordinador para que el router y el resto compilen. Reemplazalo entero
/// respetando la API pública (nombres y firmas de abajo) y los estados.
class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;
  StreamSubscription? _authSub;
  bool _initialized = false;

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
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }
      final clientId = await SecureStorageService.getClientId();
      if (clientId == null) {
        await _clearLocalSession();
        state = const AuthState(status: AuthStatus.unauthenticated);
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

  void _onAuthEvent(sb.AuthState data) {
    if (!_initialized) return;
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

  /// Paso 1 del login: teléfono. Si el dispositivo ya es conocido, la sesión
  /// queda lista; si no, se mandó un código por WhatsApp.
  Future<StartResult> startLogin(String phone) async {
    final res = await _authService.startLogin(phone: phone);
    if (res.sessionReady) {
      await _afterSession(res);
    }
    return res;
  }

  /// Paso 2: código (y nombre si el cliente es nuevo).
  Future<void> verifyCode(String phone, String code, {String? name}) async {
    final res = await _authService.verifyCode(phone: phone, code: code, name: name);
    await _afterSession(res);
  }

  Future<void> _afterSession(StartResult res) async {
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

  Future<void> logout() async {
    await _authService.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Apple 5.1.1(v): borrar la cuenta desde la app. `null` = OK.
  Future<String?> deleteAccount() async {
    final err = await _authService.deleteAccount();
    if (err == null) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
    return err;
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
