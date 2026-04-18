import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;
import '../supabase/supabase_provider.dart';
import 'auth_service.dart';
import 'secure_storage.dart';
import 'biometric_service.dart';

/// Auth state enum
enum AuthStatus {
  initial,
  unauthenticated,
  needsBiometric,
  authenticated,
}

/// Auth state model
class AuthState {
  final AuthStatus status;
  final String? clientId;
  final String? clientName;
  final String? error;
  final bool isNewClient;
  final String? selectedOrgId;
  final String? selectedOrgName;
  final String? selectedBranchId;
  final String? selectedBranchName;

  const AuthState({
    this.status = AuthStatus.initial,
    this.clientId,
    this.clientName,
    this.error,
    this.isNewClient = false,
    this.selectedOrgId,
    this.selectedOrgName,
    this.selectedBranchId,
    this.selectedBranchName,
  });

  bool get hasOrg => selectedOrgId != null;
  bool get hasBranch => selectedBranchId != null;

  AuthState copyWith({
    AuthStatus? status,
    String? clientId,
    String? clientName,
    String? error,
    bool? isNewClient,
    String? selectedOrgId,
    String? selectedOrgName,
    String? selectedBranchId,
    String? selectedBranchName,
  }) {
    return AuthState(
      status: status ?? this.status,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      error: error,
      isNewClient: isNewClient ?? this.isNewClient,
      selectedOrgId: selectedOrgId ?? this.selectedOrgId,
      selectedOrgName: selectedOrgName ?? this.selectedOrgName,
      selectedBranchId: selectedBranchId ?? this.selectedBranchId,
      selectedBranchName: selectedBranchName ?? this.selectedBranchName,
    );
  }
}

/// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(supabaseClientProvider));
});

/// Main auth state provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

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
    // Importante: suscribirse ANTES de cualquier lectura/refresh para no
    // perder eventos (signedOut) que dispara recoverSession internamente
    // cuando el refresh_token persistido es inválido.
    _authSub = _client.auth.onAuthStateChange.listen(_onAuthEvent);

    try {
      final session = _client.auth.currentSession;

      sb.Session? validSession = session;
      if (session != null && _isSessionStale(session)) {
        validSession = await _tryRefresh();
        if (validSession == null) {
          await _clearLocalSession();
          state = const AuthState(status: AuthStatus.unauthenticated);
          return;
        }
      }

      if (validSession == null) {
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }

      final clientId = await SecureStorageService.getClientId();
      if (clientId == null) {
        // Sesión en Supabase pero sin datos locales → inconsistencia, sign out.
        await _clearLocalSession();
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }

      var clientName = await SecureStorageService.getClientName();
      if (clientName != null && RegExp(r'^\d+$').hasMatch(clientName)) {
        try {
          final row = await _client
              .from('clients')
              .select('name')
              .eq('id', clientId)
              .maybeSingle();
          final dbName = row?['name'] as String?;
          if (dbName != null && dbName.isNotEmpty) {
            clientName = dbName;
            await SecureStorageService.saveClientInfo(
              clientId: clientId,
              name: dbName,
              phone: await SecureStorageService.getClientPhone() ?? '',
            );
          }
        } catch (_) {}
      }

      final orgId = await SecureStorageService.getSelectedOrgId();
      final orgName = await SecureStorageService.getSelectedOrgName();
      final branchId = await SecureStorageService.getSelectedBranchId();
      final branchName = await SecureStorageService.getSelectedBranchName();

      final bioEnabled = await SecureStorageService.isBiometricEnabled();
      state = AuthState(
        status:
            bioEnabled ? AuthStatus.needsBiometric : AuthStatus.authenticated,
        clientId: clientId,
        clientName: clientName,
        selectedOrgId: orgId,
        selectedOrgName: orgName,
        selectedBranchId: branchId,
        selectedBranchName: branchName,
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
    // Durante _init manejamos transiciones manualmente para evitar carreras.
    if (!_initialized) return;

    switch (data.event) {
      case sb.AuthChangeEvent.signedOut:
        _handleSignedOut();
        break;
      default:
        break;
    }
  }

  void _handleSignedOut() {
    // Limpia storage en background; el estado UI va inmediato.
    unawaited(_clearLocalSession());
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  bool _isSessionStale(sb.Session session) {
    final expiresAt = session.expiresAt;
    if (expiresAt == null) return false;
    final expiry = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
    // Considerar expirado si faltan menos de 60s.
    return expiry.isBefore(DateTime.now().add(const Duration(seconds: 60)));
  }

  Future<sb.Session?> _tryRefresh() async {
    try {
      final res = await _client.auth.refreshSession();
      return res.session;
    } catch (e) {
      debugPrint('[auth] refresh failed: $e');
      return null;
    }
  }

  Future<void> _clearLocalSession() async {
    try {
      await _client.auth.signOut();
    } catch (_) {}
    await SecureStorageService.clearSession();
  }

  Future<void> login({
    required String phone,
    required String orgId,
    required String orgName,
    String? name,
  }) async {
    final result = await _authService.loginWithPhone(
      phone: phone,
      orgId: orgId,
      name: name,
    );

    if (result.success) {
      final savedName = await SecureStorageService.getClientName();
      await SecureStorageService.saveSelectedOrg(
        orgId: orgId,
        orgName: orgName,
      );
      state = AuthState(
        status: AuthStatus.authenticated,
        clientId: result.clientId,
        clientName: savedName ?? name ?? phone,
        isNewClient: result.isNewClient,
        selectedOrgId: orgId,
        selectedOrgName: orgName,
      );
    } else {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: result.error,
      );
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    final success = await BiometricService.authenticate();
    if (success) {
      state = state.copyWith(status: AuthStatus.authenticated);
    }
    return success;
  }

  Future<void> logout() async {
    await _authService.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Apple App Store Guideline 5.1.1(v): el cliente elimina su cuenta desde la app.
  /// Llama a la Edge Function `delete-client-account` que borra todos los datos
  /// PII y el usuario de auth.users. Devuelve `null` si fue OK, o un mensaje de error.
  Future<String?> deleteAccount() async {
    try {
      final session = _client.auth.currentSession;
      if (session == null) return 'No hay sesión activa';

      final res = await _client.functions.invoke(
        'delete-client-account',
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      );

      if (res.status >= 400) {
        final data = res.data;
        final msg = (data is Map<String, dynamic>)
            ? (data['error'] as String?)
            : null;
        return msg ?? 'No se pudo eliminar la cuenta (HTTP ${res.status})';
      }

      // Borrado OK → limpiar todo localmente.
      await SecureStorageService.clearAll();
      try {
        await _client.auth.signOut();
      } catch (_) {}
      state = const AuthState(status: AuthStatus.unauthenticated);
      return null;
    } catch (e) {
      debugPrint('[auth] deleteAccount error: $e');
      return 'Error inesperado: $e';
    }
  }

  Future<void> completeBiometric() async {
    state = state.copyWith(status: AuthStatus.authenticated);
  }

  /// Guarda la organización seleccionada por el cliente.
  Future<void> setSelectedOrg(String orgId, String orgName) async {
    await SecureStorageService.saveSelectedOrg(
      orgId: orgId,
      orgName: orgName,
    );
    state = state.copyWith(
      selectedOrgId: orgId,
      selectedOrgName: orgName,
    );
  }

  /// Limpia la organización y sucursal (para cambiar de org).
  Future<void> clearSelectedOrg() async {
    await SecureStorageService.clearSelectedOrg();
    state = AuthState(
      status: state.status,
      clientId: state.clientId,
      clientName: state.clientName,
      isNewClient: state.isNewClient,
    );
  }

  /// Guarda la sucursal seleccionada por el cliente.
  Future<void> setSelectedBranch(String branchId, String branchName) async {
    await SecureStorageService.saveSelectedBranch(
      branchId: branchId,
      branchName: branchName,
    );
    state = state.copyWith(
      selectedBranchId: branchId,
      selectedBranchName: branchName,
    );
  }

  /// Limpia la sucursal seleccionada (vuelve a selección de branch dentro de la org).
  Future<void> clearSelectedBranch() async {
    await SecureStorageService.clearSelectedBranch();
    state = AuthState(
      status: state.status,
      clientId: state.clientId,
      clientName: state.clientName,
      isNewClient: state.isNewClient,
      selectedOrgId: state.selectedOrgId,
      selectedOrgName: state.selectedOrgName,
    );
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
