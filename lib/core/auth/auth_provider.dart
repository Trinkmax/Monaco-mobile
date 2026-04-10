import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  AuthNotifier(this._ref) : super(const AuthState()) {
    _init();
  }

  SupabaseClient get _client => _ref.read(supabaseClientProvider);
  AuthService get _authService => _ref.read(authServiceProvider);

  Future<void> _init() async {
    // Listen to auth state changes
    _authSub = _client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut) {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    });

    // Check for existing session
    final session = _client.auth.currentSession;
    if (session != null) {
      final clientId = await SecureStorageService.getClientId();
      var clientName = await SecureStorageService.getClientName();

      if (clientId != null) {
        // Refresh name from DB if stored name looks like a phone number
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

        // Restaurar organización y sucursal seleccionadas
        final orgId = await SecureStorageService.getSelectedOrgId();
        final orgName = await SecureStorageService.getSelectedOrgName();
        final branchId = await SecureStorageService.getSelectedBranchId();
        final branchName = await SecureStorageService.getSelectedBranchName();

        final bioEnabled = await SecureStorageService.isBiometricEnabled();
        if (bioEnabled) {
          state = AuthState(
            status: AuthStatus.needsBiometric,
            clientId: clientId,
            clientName: clientName,
            selectedOrgId: orgId,
            selectedOrgName: orgName,
            selectedBranchId: branchId,
            selectedBranchName: branchName,
          );
        } else {
          state = AuthState(
            status: AuthStatus.authenticated,
            clientId: clientId,
            clientName: clientName,
            selectedOrgId: orgId,
            selectedOrgName: orgName,
            selectedBranchId: branchId,
            selectedBranchName: branchName,
          );
        }
        return;
      }
    }

    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> login({required String phone, String? name}) async {
    final result = await _authService.loginWithPhone(phone: phone, name: name);

    if (result.success) {
      // Read the name that auth_service saved (fetched from DB)
      final savedName = await SecureStorageService.getClientName();
      state = AuthState(
        status: AuthStatus.authenticated,
        clientId: result.clientId,
        clientName: savedName ?? name ?? phone,
        isNewClient: result.isNewClient,
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
