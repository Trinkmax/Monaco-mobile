import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/constants.dart';
import 'auth_provider.dart' show StartResult;
import 'secure_storage.dart';
import 'social_auth_service.dart';

/// Error de auth con código del server (`OTP_INVALID`, `RATE_LIMITED`,
/// `OTP_DELIVERY_FAILED`, `NAME_REQUIRED`, …) o sintético (`NETWORK`).
class AuthException implements Exception {
  final String code;
  final String message;
  final int? attemptsLeft;
  final int? retryIn;

  /// Sólo en `SIGNUP_TOKEN_INVALID`: el token venció (pasaron los 15 minutos) y
  /// hay que rehacer el paso social. Distinto de "el token es inválido", que no
  /// se arregla reintentando.
  final bool expired;

  const AuthException(
    this.code,
    this.message, {
    this.attemptsLeft,
    this.retryIn,
    this.expired = false,
  });

  @override
  String toString() => 'AuthException($code): $message';
}

/// Resultado de la acción `social`.
///
/// O la identidad ya estaba vinculada y hay sesión ([sessionReady]), o es la
/// primera vez y falta el teléfono ([signupToken] + [suggestedName]). **No se
/// creó nada** en el segundo caso: la cuenta nace recién en `verify`.
class SocialResult {
  final bool sessionReady;

  /// HMAC autocontenido de 15 minutos que ata proveedor + subject + email +
  /// nombre + organización. Hay que mandarlo en `start` **y** en `verify`: en
  /// `start` habilita el envío del código a un número que todavía no es
  /// cliente, y en `verify` es lo que vincula la identidad social con la
  /// cuenta. No se guarda en la base ni en el Keychain: vive en memoria.
  final String? signupToken;

  final String? suggestedName;
  final String? email;
  final bool clientKnown;

  const SocialResult({
    required this.sessionReady,
    this.signupToken,
    this.suggestedName,
    this.email,
    this.clientKnown = false,
  });
}

/// Habla con la Edge Function `client-auth` (acciones `social` / `start` /
/// `verify`).
class AuthService {
  final SupabaseClient _client;

  AuthService(this._client);

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    FunctionResponse response;
    try {
      response = await _client.functions.invoke('client-auth', body: body);
    } on FunctionException catch (e) {
      final details = e.details;
      final map = details is Map<String, dynamic>
          ? details
          : (details is String ? _tryDecode(details) : null);
      throw AuthException(
        (map?['error'] as String?) ?? 'AUTH_FAILED',
        (map?['message'] as String?) ??
            'No pudimos iniciar sesión. Probá de nuevo.',
        attemptsLeft: (map?['attempts_left'] as num?)?.toInt(),
        retryIn: (map?['retry_in'] as num?)?.toInt(),
        expired: map?['expired'] == true,
      );
    } catch (e) {
      debugPrint('[auth] invoke error: $e');
      throw const AuthException(
        'NETWORK',
        'No pudimos conectarnos. Revisá tu conexión e intentá de nuevo.',
      );
    }

    final data = response.data is String
        ? _tryDecode(response.data as String) ?? <String, dynamic>{}
        : (response.data as Map<String, dynamic>? ?? <String, dynamic>{});

    if (response.status < 200 || response.status >= 300) {
      throw AuthException(
        (data['error'] as String?) ?? 'AUTH_FAILED',
        (data['message'] as String?) ??
            'No pudimos iniciar sesión. Probá de nuevo.',
        attemptsLeft: (data['attempts_left'] as num?)?.toInt(),
        retryIn: (data['retry_in'] as num?)?.toInt(),
        expired: data['expired'] == true,
      );
    }
    return data;
  }

  Map<String, dynamic>? _tryDecode(String s) {
    try {
      final d = jsonDecode(s);
      return d is Map<String, dynamic> ? d : null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, String>> _deviceFields() async => {
    'device_id': await SecureStorageService.getOrCreateDeviceId(),
    'device_secret': await SecureStorageService.getOrCreateDeviceSecret(),
    'org_id': AppConstants.organizationId,
  };

  /// `social`: entra con Google/Apple. El `id_token` lo verifica el SERVER
  /// contra el JWKS del proveedor — nunca `supabase.auth.signInWithIdToken`
  /// (ver el comentario largo en `social_auth_service.dart`).
  Future<SocialResult> signInWithSocial(SocialCredential cred) async {
    final data = await _invoke({
      'action': 'social',
      'provider': cred.provider.wire,
      'id_token': cred.idToken,
      if (cred.nonce != null) 'nonce': cred.nonce,
      if ((cred.name ?? '').trim().isNotEmpty) 'name': cred.name!.trim(),
      ...await _deviceFields(),
    });

    final status = data['status'] as String?;
    if (status == 'need_phone') {
      final token = data['signup_token'] as String?;
      if (token == null || token.isEmpty) {
        throw const AuthException(
          'AUTH_FAILED',
          'Respuesta incompleta del servidor.',
        );
      }
      return SocialResult(
        sessionReady: false,
        signupToken: token,
        suggestedName: (data['suggested_name'] as String?)?.trim(),
        email: data['email'] as String?,
      );
    }

    // `ok`: identidad ya vinculada → sesión de un toque, sin código.
    final res = await _handle(
      data,
      fallbackPhone: (data['phone'] as String?) ?? '',
    );
    return SocialResult(sessionReady: true, clientKnown: res.clientKnown);
  }

  /// `start`: login silencioso si el dispositivo es conocido; si no, manda el
  /// código por WhatsApp. [signupToken] sólo va si se viene de `social`.
  Future<StartResult> startLogin({
    required String phone,
    String? signupToken,
  }) async {
    final data = await _invoke({
      'action': 'start',
      'phone': phone,
      'signup_token': ?signupToken,
      ...await _deviceFields(),
    });
    return _handle(data, fallbackPhone: phone);
  }

  /// `verify`: valida el código. `name` es obligatorio si el teléfono es nuevo
  /// (el server contesta `NAME_REQUIRED` **sin consumir el desafío**, así que
  /// se puede reintentar con el mismo código).
  Future<StartResult> verifyCode({
    required String phone,
    required String code,
    String? name,
    String? signupToken,
  }) async {
    final data = await _invoke({
      'action': 'verify',
      'phone': phone,
      'code': code,
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      'signup_token': ?signupToken,
      ...await _deviceFields(),
    });
    return _handle(data, fallbackPhone: phone);
  }

  Future<StartResult> _handle(
    Map<String, dynamic> data, {
    required String fallbackPhone,
  }) async {
    var status = data['status'] as String?;
    // Compatibilidad con la v1 de `client-auth` (sin `status`): si vienen los
    // tokens, la sesión está lista. Sólo importa mientras la v2 no esté
    // deployada; con la v2 siempre viene `status`.
    if (status == null && data['access_token'] is String) status = 'ok';
    if (status == 'otp_sent') {
      return StartResult(
        sessionReady: false,
        otpSent: true,
        phoneMasked: data['phone_masked'] as String?,
        expiresIn: (data['expires_in'] as num?)?.toInt() ?? 600,
        resendIn: (data['resend_in'] as num?)?.toInt() ?? 45,
        clientKnown: data['client_known'] == true,
        nameRequired: data['name_required'] == true,
        firstName: data['first_name'] as String?,
      );
    }
    if (status == 'ok') {
      final refresh = data['refresh_token'] as String?;
      if (refresh == null) {
        throw const AuthException(
          'AUTH_FAILED',
          'Respuesta incompleta del servidor.',
        );
      }
      await _client.auth.setSession(refresh);
      final clientId = data['client_id'] as String;
      final name = (data['name'] as String?) ?? '';
      final phone = (data['phone'] as String?) ?? fallbackPhone;
      await SecureStorageService.saveClientInfo(
        clientId: clientId,
        name: name,
        phone: phone,
      );
      return StartResult(
        sessionReady: true,
        otpSent: false,
        clientKnown: data['is_new_client'] != true,
        firstName: name.isEmpty ? null : name.split(' ').first,
      );
    }
    throw AuthException(
      (data['error'] as String?) ?? 'AUTH_FAILED',
      (data['message'] as String?) ?? 'Respuesta inesperada del servidor.',
    );
  }

  bool get isAuthenticated => _client.auth.currentSession != null;
  Session? get currentSession => _client.auth.currentSession;

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (_) {}
    // Sesión local del SDK de Google, no la autorización: el cliente quiere
    // salir, no romper el vínculo. La revocación (`disconnect`) es cosa del
    // borrado de cuenta.
    await SocialAuthService.cerrarSesionGoogle();
    await SecureStorageService.clearSession();
  }

  /// Apple 5.1.1(v): borra la cuenta vía Edge Function `delete-client-account`.
  /// Devuelve `null` si salió bien o un mensaje de error.
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
        final msg = data is Map<String, dynamic>
            ? data['error'] as String?
            : null;
        return msg ?? 'No se pudo eliminar la cuenta (HTTP ${res.status})';
      }
      // Revocar la autorización de Google es parte del borrado: si no, el
      // equipo sigue teniendo a Monaco entre las apps autorizadas de esa cuenta
      // y el próximo "Continuar con Google" entra sin hoja a una cuenta que ya
      // no existe.
      await SocialAuthService.desvincularGoogle();
      await SecureStorageService.clearAll();
      try {
        await _client.auth.signOut();
      } catch (_) {}
      return null;
    } on FunctionException catch (e) {
      final d = e.details;
      final msg = d is Map<String, dynamic> ? d['error'] as String? : null;
      return msg ?? 'No se pudo eliminar la cuenta (HTTP ${e.status})';
    } catch (e) {
      debugPrint('[auth] deleteAccount error: $e');
      return 'Error inesperado: $e';
    }
  }
}
