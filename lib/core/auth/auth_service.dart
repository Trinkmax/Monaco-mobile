import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'secure_storage.dart';

class AuthResult {
  final bool success;
  final String? error;
  final String? errorCode;
  final String? clientId;
  final bool isNewClient;

  const AuthResult({
    required this.success,
    this.error,
    this.errorCode,
    this.clientId,
    this.isNewClient = false,
  });
}

class AuthService {
  final SupabaseClient _client;

  AuthService(this._client);

  /// Login/Register via phone number using the client-auth edge function
  Future<AuthResult> loginWithPhone({
    required String phone,
    String? name,
  }) async {
    try {
      final deviceSecret = await SecureStorageService.getOrCreateDeviceSecret();
      final deviceId = await SecureStorageService.getOrCreateDeviceId();

      final response = await _client.functions.invoke(
        'client-auth',
        body: {
          'phone': phone,
          'device_id': deviceId,
          'device_secret': deviceSecret,
          if (name != null) 'name': name,
        },
      );

      if (response.status != 200) {
        final body = response.data is String
            ? jsonDecode(response.data) as Map<String, dynamic>
            : response.data as Map<String, dynamic>;
        return AuthResult(
          success: false,
          error: body['error'] as String? ?? 'Error desconocido',
          errorCode: body['code'] as String?,
        );
      }

      final data = response.data is String
          ? jsonDecode(response.data) as Map<String, dynamic>
          : response.data as Map<String, dynamic>;

      // Set the session in Supabase client (setSession expects refresh_token)
      await _client.auth.setSession(data['refresh_token'] as String);

      final clientId = data['client_id'] as String;
      final isNew = data['is_new_client'] as bool? ?? false;

      // Fetch actual client name from DB (may differ from what was sent)
      String clientName = name ?? phone;
      try {
        final clientRow = await _client
            .from('clients')
            .select('name')
            .eq('id', clientId)
            .maybeSingle();
        final dbName = clientRow?['name'] as String?;
        if (dbName != null && dbName.isNotEmpty) {
          clientName = dbName;
        }
      } catch (_) {
        // Fall back to provided name or phone
      }

      // Save client info locally
      await SecureStorageService.saveClientInfo(
        clientId: clientId,
        name: clientName,
        phone: phone,
      );

      return AuthResult(
        success: true,
        clientId: clientId,
        isNewClient: isNew,
      );
    } catch (e) {
      return AuthResult(
        success: false,
        error: 'Error de conexión: ${e.toString()}',
      );
    }
  }

  /// Check if user has an active session
  bool get isAuthenticated => _client.auth.currentSession != null;

  /// Get current session
  Session? get currentSession => _client.auth.currentSession;

  /// Refresh session
  Future<bool> refreshSession() async {
    try {
      final response = await _client.auth.refreshSession();
      return response.session != null;
    } catch (_) {
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (_) {
      // Ignore errors on sign out
    }
    await SecureStorageService.clearSession();
  }
}
