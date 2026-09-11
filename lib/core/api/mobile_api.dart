import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_provider.dart';
import '../supabase/supabase_provider.dart';
import '../utils/constants.dart';

/// Error tipado de la API mobile (`/api/mobile/*`). `code` es el código que
/// devuelve el server (`SLOT_TAKEN`, `RATE_LIMITED`, `UNAUTHENTICATED`, …) o
/// uno sintético (`NETWORK`, `TIMEOUT`, `BAD_RESPONSE`).
///
/// **`message` está SIEMPRE en español y listo para mostrar.** El detalle
/// técnico de una falla de red (`Failed host lookup: '…'`, `OS Error: nodename
/// nor servname provided`) va en [detail], que sólo se loguea: media app
/// imprime `e.message` tal cual —el wizard de reserva, la grilla de horarios,
/// el toast de cancelar— y un reviewer probando en modo avión no tiene por qué
/// ver una excepción de Dart en inglés.
class MobileApiException implements Exception {
  final String code;
  final String message;
  final int? status;
  final Map<String, dynamic>? body;

  /// Motivo técnico, para `debugPrint` y para `toString()`. Nunca para la UI.
  final String? detail;

  const MobileApiException(
    this.code,
    this.message, {
    this.status,
    this.body,
    this.detail,
  });

  bool get isNetwork => code == 'NETWORK' || code == 'TIMEOUT';
  bool get isUnauthenticated => status == 401 || code == 'UNAUTHENTICATED';

  /// El JWT ya no representa a ningún cliente: o venció y el refresh no
  /// alcanzó (401 / `UNAUTHENTICATED`), o la ficha de `clients` fue borrada o
  /// fusionada desde el dashboard y el token sigue siendo criptográficamente
  /// válido (`NO_CLIENT`). Los dos casos se arreglan igual: volver a entrar.
  bool get esSesionMuerta => isUnauthenticated || code == 'NO_CLIENT';

  @override
  String toString() =>
      'MobileApiException($code, $status): $message'
      '${detail == null ? '' : ' [$detail]'}';
}

/// Mensajes de red. Fijos, en español y sin datos técnicos adentro.
const _kSinConexion = 'Sin conexión. Revisá tu internet e intentá de nuevo.';
const _kConexionInsegura =
    'Conexión insegura. Revisá tu red e intentá de nuevo.';
const _kTimeout = 'El servidor tardó demasiado en responder. Probá de nuevo.';

final mobileApiProvider = Provider<MobileApi>((ref) {
  return MobileApi(
    ref.watch(supabaseClientProvider),
    // Sesión zombi: una sola puerta para todas las pantallas. Sin esto, un
    // cliente cuya ficha se borró o fusionó desde /dashboard/clientes queda
    // con un JWT válido y una app que falla en TODAS las pantallas, y la única
    // salida (Perfil → Cerrar sesión) no es evidente para nadie.
    onSesionInvalida: (e) {
      debugPrint('[api] sesión inválida (${e.code}): ${e.message}');
      unawaited(ref.read(authProvider.notifier).sesionInvalidada());
    },
  );
});

/// Cliente HTTP hacia el dashboard (`AppConstants.apiBaseUrl`). Manda el JWT
/// del cliente como Bearer; si la sesión está por vencer la refresca antes.
class MobileApi {
  final SupabaseClient _supabase;
  final http.Client _http;
  final String baseUrl;

  /// Se llama UNA vez por respuesta que dice que la sesión ya no sirve
  /// ([MobileApiException.esSesionMuerta]). Quien lo recibe decide (el
  /// provider cierra la sesión local y manda a la bienvenida); acá no se
  /// navega ni se muestra nada, para que `MobileApi` siga siendo testeable sin
  /// Riverpod ni contexto.
  final void Function(MobileApiException e)? onSesionInvalida;

  MobileApi(
    this._supabase, {
    http.Client? client,
    String? baseUrl,
    this.onSesionInvalida,
  })  : _http = client ?? http.Client(),
        baseUrl = (baseUrl ?? AppConstants.apiBaseUrl).replaceAll(RegExp(r'/$'), '');

  static String? _appVersion;

  static Future<String> appVersion() async {
    if (_appVersion != null) return _appVersion!;
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {
      _appVersion = 'unknown';
    }
    return _appVersion!;
  }

  Future<String?> _accessToken() async {
    var session = _supabase.auth.currentSession;
    if (session == null) return null;
    final expiresAt = session.expiresAt;
    if (expiresAt != null) {
      final expiry = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
      if (expiry.isBefore(DateTime.now().add(const Duration(seconds: 90)))) {
        try {
          final res = await _supabase.auth.refreshSession();
          session = res.session ?? session;
        } catch (e) {
          debugPrint('[api] refresh antes de request falló: $e');
        }
      }
    }
    return session?.accessToken;
  }

  Future<Map<String, String>> _headers() async {
    final token = await _accessToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-App-Platform': Platform.isIOS ? 'ios' : 'android',
      'X-App-Version': await appVersion(),
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$p').replace(
      queryParameters: (query == null || query.isEmpty) ? null : query,
    );
  }

  /// `timeout` sólo se pasa donde el default de 15 s es corto de verdad: hoy,
  /// los endpoints de seña, que del otro lado tienen que hablar con Mercado
  /// Pago. No subir el default: protege a toda la app de quedarse colgada.
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
    Duration? timeout,
  }) =>
      _send(
        () async => _http.get(_uri(path, query), headers: await _headers()),
        timeout: timeout,
      );

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    Duration? timeout,
  }) =>
      _send(
        () async => _http.post(
          _uri(path),
          headers: await _headers(),
          body: jsonEncode(body),
        ),
        timeout: timeout,
      );

  Future<Map<String, dynamic>> deleteJson(
    String path,
    Map<String, dynamic> body,
  ) =>
      _send(() async => _http.delete(
            _uri(path),
            headers: await _headers(),
            body: jsonEncode(body),
          ));

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() run, {
    Duration? timeout,
  }) async {
    http.Response res;
    try {
      res = await run().timeout(timeout ?? AppConstants.apiTimeout);
    } on TimeoutException {
      throw const MobileApiException('TIMEOUT', _kTimeout);
    } on SocketException catch (e) {
      throw MobileApiException('NETWORK', _kSinConexion, detail: e.message);
    } on http.ClientException catch (e) {
      throw MobileApiException('NETWORK', _kSinConexion, detail: e.message);
    } on HandshakeException catch (e) {
      throw MobileApiException(
        'NETWORK',
        _kConexionInsegura,
        detail: e.message,
      );
    }

    Map<String, dynamic> json;
    try {
      final decoded = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body);
      json = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{'data': decoded};
    } catch (_) {
      throw MobileApiException(
        'BAD_RESPONSE',
        'Respuesta inválida del servidor (${res.statusCode}).',
        status: res.statusCode,
      );
    }

    if (res.statusCode >= 200 && res.statusCode < 300) return json;

    final code = (json['error'] as String?) ?? 'HTTP_${res.statusCode}';
    final message = (json['message'] as String?) ??
        (json['error'] is String ? json['error'] as String : null) ??
        'Algo salió mal (${res.statusCode}).';
    final error = MobileApiException(
      code,
      message,
      status: res.statusCode,
      body: json,
    );
    if (error.esSesionMuerta) onSesionInvalida?.call(error);
    throw error;
  }

  void close() => _http.close();
}
