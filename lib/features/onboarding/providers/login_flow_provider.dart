import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:monaco_mobile/core/auth/auth_provider.dart' show StartResult;

/// Estado efímero del flujo teléfono → código → nombre. Vive sólo mientras
/// dura el login (se limpia al terminar o al volver a /welcome). Nada de esto
/// se persiste: si la app se cierra a mitad de camino, se vuelve a empezar.
class LoginFlow {
  /// Dígitos nacionales tal como los tipeó el usuario (sin +54 9).
  final String phone;

  /// "+54 9 351 ••• 5249" (lo devuelve el server; si falta, se calcula local).
  final String phoneMasked;

  /// El server ya conocía el teléfono: no hay que pedir nombre.
  final bool clientKnown;

  /// Primer nombre del cliente conocido, para saludarlo en el paso del código.
  final String? firstName;

  /// Segundos hasta poder reenviar y hasta que vence el código, contados
  /// desde [sentAt].
  final int resendIn;
  final int expiresIn;
  final DateTime sentAt;

  /// Código completo ingresado (cuando el cliente es nuevo viaja al paso del
  /// nombre y recién ahí se verifica).
  final String? code;

  /// Error que el paso del nombre quiere mostrar al volver al código
  /// (OTP_INVALID / OTP_EXPIRED).
  final String? pendingCodeError;

  const LoginFlow({
    required this.phone,
    required this.phoneMasked,
    required this.clientKnown,
    required this.firstName,
    required this.resendIn,
    required this.expiresIn,
    required this.sentAt,
    this.code,
    this.pendingCodeError,
  });

  factory LoginFlow.fromStart(
    String phone,
    StartResult res, {
    required String fallbackMasked,
  }) {
    return LoginFlow(
      phone: phone,
      phoneMasked: res.phoneMasked ?? fallbackMasked,
      clientKnown: res.clientKnown,
      firstName: (res.firstName ?? '').trim().isEmpty ? null : res.firstName,
      resendIn: res.resendIn,
      expiresIn: res.expiresIn,
      sentAt: DateTime.now(),
    );
  }

  /// Segundos que faltan para poder reenviar (0 si ya se puede).
  int get resendRemaining {
    final elapsed = DateTime.now().difference(sentAt).inSeconds;
    final left = resendIn - elapsed;
    return left < 0 ? 0 : left;
  }

  bool get isExpired =>
      DateTime.now().difference(sentAt).inSeconds >= expiresIn;

  LoginFlow copyWith({
    String? code,
    bool clearCode = false,
    String? pendingCodeError,
    bool clearPendingCodeError = false,
    bool? clientKnown,
  }) {
    return LoginFlow(
      phone: phone,
      phoneMasked: phoneMasked,
      clientKnown: clientKnown ?? this.clientKnown,
      firstName: firstName,
      resendIn: resendIn,
      expiresIn: expiresIn,
      sentAt: sentAt,
      code: clearCode ? null : (code ?? this.code),
      pendingCodeError: clearPendingCodeError
          ? null
          : (pendingCodeError ?? this.pendingCodeError),
    );
  }
}

/// Flujo de login en curso. `null` = no hay código pendiente.
final loginFlowProvider = StateProvider<LoginFlow?>(
  (ref) => null,
  name: 'loginFlow',
);
