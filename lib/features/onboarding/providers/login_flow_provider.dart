import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:monaco_mobile/core/auth/auth_provider.dart' show StartResult;
import 'package:monaco_mobile/core/auth/social_auth_service.dart'
    show SocialProvider;

/// Estado efímero del flujo teléfono → código → nombre. Vive sólo mientras
/// dura el login (se limpia al terminar o al volver a /welcome). Nada de esto
/// se persiste: si la app se cierra a mitad de camino, se vuelve a empezar.
class LoginFlow {
  /// Dígitos nacionales tal como los tipeó el usuario (sin +54 9).
  final String phone;

  /// "+54 9 351 ••• 5249" (lo devuelve el server; si falta, se calcula local).
  final String phoneMasked;

  /// El server ya conocía el teléfono.
  final bool clientKnown;

  /// El server pide el nombre junto con el código (`name_required`). Es lo que
  /// decide si la pantalla del código dibuja el campo Nombre. **No se deduce de
  /// `clientKnown`**: con Google/Apple el teléfono puede ser nuevo y el nombre
  /// venir dentro del `signup_token`.
  final bool nameRequired;

  /// Primer nombre del cliente conocido, para saludarlo en el paso del código.
  final String? firstName;

  /// Segundos hasta poder reenviar y hasta que vence el código, contados
  /// desde [sentAt].
  final int resendIn;
  final int expiresIn;
  final DateTime sentAt;

  const LoginFlow({
    required this.phone,
    required this.phoneMasked,
    required this.clientKnown,
    required this.nameRequired,
    required this.firstName,
    required this.resendIn,
    required this.expiresIn,
    required this.sentAt,
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
      nameRequired: res.nameRequired,
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

  LoginFlow copyWith({bool? clientKnown, bool? nameRequired}) {
    return LoginFlow(
      phone: phone,
      phoneMasked: phoneMasked,
      clientKnown: clientKnown ?? this.clientKnown,
      nameRequired: nameRequired ?? this.nameRequired,
      firstName: firstName,
      resendIn: resendIn,
      expiresIn: expiresIn,
      sentAt: sentAt,
    );
  }
}

/// Alta social a medio camino: el proveedor validó la identidad pero todavía
/// falta el teléfono.
///
/// El `signup_token` es un HMAC autocontenido de **15 minutos** que el server
/// firma en la acción `social` y que hay que devolver en `start` **y** en
/// `verify`. Vive sólo en memoria: no se persiste en el Keychain porque es
/// efímero por diseño y porque un token de alta guardado sobreviviría a un
/// cambio de cuenta.
class SignupPendiente {
  final String token;
  final SocialProvider proveedor;

  /// Nombre que trajo el proveedor. En Apple es la ÚNICA vez que se puede
  /// obtener, así que precargarlo no es una comodidad: es la diferencia entre
  /// tener el nombre y no tenerlo nunca.
  final String? nombreSugerido;

  final String? email;
  final DateTime creadoEn;

  SignupPendiente({
    required this.token,
    required this.proveedor,
    this.nombreSugerido,
    this.email,
    DateTime? creadoEn,
  }) : creadoEn = creadoEn ?? DateTime.now();

  /// Margen de 60 s sobre los 15 minutos del server: preferimos mandar al
  /// cliente a rehacer el paso social ANTES de que el server rebote con
  /// `SIGNUP_TOKEN_INVALID` con el código ya tipeado.
  bool get vencido =>
      DateTime.now().difference(creadoEn) > const Duration(seconds: 840);
}

/// Alta social en curso. `null` = el cliente entra por teléfono a secas.
final signupPendienteProvider = StateProvider<SignupPendiente?>(
  (ref) => null,
  name: 'signupPendiente',
);

/// Flujo de login en curso. `null` = no hay código pendiente.
final loginFlowProvider = StateProvider<LoginFlow?>(
  (ref) => null,
  name: 'loginFlow',
);
