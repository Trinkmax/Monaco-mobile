import 'dart:convert';
import 'dart:io' show Platform;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../utils/constants.dart';

/// Proveedor social. El valor de [wire] es lo que espera el campo `provider`
/// de la acción `social` de `client-auth`.
enum SocialProvider {
  google('google'),
  apple('apple');

  const SocialProvider(this.wire);
  final String wire;

  String get label => this == SocialProvider.google ? 'Google' : 'Apple';
}

/// Lo que devuelve el proveedor y viaja tal cual a nuestra edge function.
///
/// **El `idToken` NO se le entrega a `supabase.auth.signInWithIdToken`.** Ese
/// camino es la tentación obvia —Supabase soporta Google y Apple de fábrica— y
/// está mal para esta app: crearía un usuario de Auth suelto, sin fila en
/// `clients`, sin teléfono y **sin `app_metadata.user_type = 'client'`**, que es
/// exactamente de lo que depende toda la RLS de la migración 192. Ese usuario
/// tendría un JWT válido y no podría leer nada suyo, y después habría que
/// fusionarlo a mano con el usuario-alias del teléfono.
///
/// La identidad del negocio es el TELÉFONO (es lo que ata la cuenta con la fila
/// del local, con WhatsApp, con los puntos y con el historial). Google y Apple
/// son login de un toque y recuperación de cuenta, no una identidad paralela:
/// toda cuenta nueva termina con un teléfono verificado por OTP.
@immutable
class SocialCredential {
  final SocialProvider provider;

  /// `id_token` del proveedor, sin tocar. Lo verifica el server contra el JWKS
  /// de Google/Apple (firma, `iss`, `aud`, `exp`, `nonce`).
  final String idToken;

  /// Nonce **crudo** que generamos nosotros. A Apple se le manda el sha256 en
  /// hex y el claim del token trae ese hash; el server acepta las dos formas
  /// comparando siempre contra este valor.
  final String? nonce;

  /// Nombre para mostrar. En Apple es la ÚNICA vez que se puede obtener (ver
  /// [SocialAuthService.apple]).
  final String? name;

  final String? email;

  const SocialCredential({
    required this.provider,
    required this.idToken,
    this.nonce,
    this.name,
    this.email,
  });
}

/// El usuario cerró la hoja del proveedor. No es un error: no se muestra nada.
class SocialAuthCancelled implements Exception {
  const SocialAuthCancelled();
}

/// No se pudo hablar con el proveedor (red, SDK sin configurar, dispositivo sin
/// soporte). Es problema NUESTRO o de la red, nunca "tu cuenta de Google no
/// sirve": el mensaje tiene que decir eso y ofrecer reintentar.
class SocialAuthUnavailable implements Exception {
  final String message;
  const SocialAuthUnavailable(this.message);

  @override
  String toString() => 'SocialAuthUnavailable: $message';
}

/// Google y Apple nativos. Todo lo que sale de acá es una [SocialCredential],
/// una [SocialAuthCancelled] o una [SocialAuthUnavailable]: ninguna excepción
/// cruda del SDK llega a la UI.
class SocialAuthService {
  SocialAuthService._();

  /// `initialize()` de `google_sign_in` 7.x es **una sola vez por proceso**.
  static Future<void>? _googleInit;

  /// Google sólo se ofrece si los client IDs están cargados
  /// (`--dart-define=GOOGLE_IOS_CLIENT_ID/GOOGLE_SERVER_CLIENT_ID`). Sin ellos
  /// el SDK levanta un `clientConfigurationError` que el cliente no puede
  /// resolver: mejor no mostrar el botón que mostrar uno que siempre falla.
  static bool get googleConfigurado {
    if (Platform.isIOS) return AppConstants.googleIosClientId.isNotEmpty;
    if (Platform.isAndroid) return AppConstants.googleServerClientId.isNotEmpty;
    return false;
  }

  /// **Apple sólo en iOS.**
  ///
  /// `SignInWithApple.isAvailable()` devuelve `true` en Android (el paquete
  /// soporta el flujo web ahí), así que NO sirve como gate: en Android abriría
  /// un Custom Tab contra un servidor propio que no tenemos, y deja de ser
  /// nativo. La guideline 4.8 —"si ofrecés login social de terceros, ofrecé
  /// también Sign in with Apple"— es de la App Store: en Play no aplica.
  static bool get appleDisponible => Platform.isIOS;

  // ── Google ───────────────────────────────────────────────────────────────

  static Future<SocialCredential> google() async {
    if (!googleConfigurado) {
      throw const SocialAuthUnavailable(
        'El ingreso con Google todavía no está disponible en esta versión.',
      );
    }
    try {
      await (_googleInit ??= GoogleSignIn.instance.initialize(
        clientId: AppConstants.googleIosClientId.isEmpty
            ? null
            : AppConstants.googleIosClientId,
        serverClientId: AppConstants.googleServerClientId.isEmpty
            ? null
            : AppConstants.googleServerClientId,
      ));
    } catch (e) {
      // Un `initialize` fallido no puede quedar memoizado: el próximo intento
      // tiene que volver a probar.
      _googleInit = null;
      debugPrint('[social] GoogleSignIn.initialize falló: $e');
      throw const SocialAuthUnavailable(
        'No pudimos abrir el ingreso con Google. Probá de nuevo.',
      );
    }

    GoogleSignInAccount? cuenta;
    try {
      // El silencioso primero: si el equipo ya tiene la cuenta autorizada, no
      // hay hoja que mostrar. Para un usuario NUEVO devuelve null siempre —por
      // eso no alcanza con él y hay que caer a `authenticate()`.
      cuenta = await GoogleSignIn.instance.attemptLightweightAuthentication();
    } on GoogleSignInException catch (e) {
      // El silencioso que falla no es un error del usuario: seguimos al
      // interactivo, que es el que puede resolverlo.
      debugPrint('[social] lightweight falló (${e.code}), sigo al interactivo');
    } catch (e) {
      debugPrint('[social] lightweight falló: $e');
    }

    if (cuenta == null) {
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        // Sólo pasa en web, donde el SDK impone su propio botón.
        throw const SocialAuthUnavailable(
          'El ingreso con Google no está disponible en este dispositivo.',
        );
      }
      try {
        cuenta = await GoogleSignIn.instance.authenticate();
      } on GoogleSignInException catch (e) {
        throw _traducirGoogle(e);
      } catch (e) {
        debugPrint('[social] authenticate falló: $e');
        throw const SocialAuthUnavailable(
          'No pudimos completar el ingreso con Google. Probá de nuevo.',
        );
      }
    }

    final idToken = cuenta.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      // Pasa cuando falta el `serverClientId` en Android: el SDK autentica pero
      // no emite id_token. Es configuración, no culpa del cliente.
      debugPrint(
        '[social] Google no devolvió id_token (¿falta serverClientId?)',
      );
      throw const SocialAuthUnavailable(
        'No pudimos verificar tu cuenta de Google. Probá con tu número.',
      );
    }

    return SocialCredential(
      provider: SocialProvider.google,
      idToken: idToken,
      // Google manda el nombre DENTRO del token, así que `name` es redundante;
      // se manda igual porque si viene, el server lo prefiere, y así el alta no
      // depende de que el token traiga el claim.
      name: cuenta.displayName,
      email: cuenta.email,
    );
  }

  static Object _traducirGoogle(GoogleSignInException e) {
    debugPrint('[social] GoogleSignInException ${e.code}: ${e.description}');
    switch (e.code) {
      case GoogleSignInExceptionCode.canceled:
      case GoogleSignInExceptionCode.interrupted:
        return const SocialAuthCancelled();
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        return const SocialAuthUnavailable(
          'El ingreso con Google no está bien configurado en esta versión de '
          'la app. Entrá con tu número mientras tanto.',
        );
      default:
        return const SocialAuthUnavailable(
          'No pudimos completar el ingreso con Google. Probá de nuevo.',
        );
    }
  }

  /// Revoca la autorización local de Google. Se llama al **borrar la cuenta**:
  /// sin esto, el equipo sigue teniendo a Monaco entre las apps autorizadas de
  /// esa cuenta de Google y el próximo "Continuar con Google" entra sin hoja,
  /// a una cuenta que ya no existe.
  ///
  /// Best-effort: que falle no puede tumbar un borrado que en el server ya se
  /// hizo.
  static Future<void> desvincularGoogle() async {
    try {
      await GoogleSignIn.instance.disconnect();
    } catch (e) {
      debugPrint('[social] disconnect de Google falló (se ignora): $e');
    }
  }

  /// Cierra la sesión local de Google **sin** revocar la autorización. Es lo
  /// que corresponde en un logout normal: el cliente quiere salir, no romper el
  /// vínculo.
  static Future<void> cerrarSesionGoogle() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('[social] signOut de Google falló (se ignora): $e');
    }
  }

  // ── Apple ────────────────────────────────────────────────────────────────

  static Future<SocialCredential> apple() async {
    if (!appleDisponible) {
      throw const SocialAuthUnavailable(
        'El ingreso con Apple sólo está disponible en iPhone.',
      );
    }

    // El nonce viaja HASHEADO al proveedor y CRUDO a nuestro server: así, quien
    // intercepte el token no puede reusarlo en otra sesión sin conocer el
    // original. El server acepta que el claim sea el crudo o su sha256 hex.
    final nonceCrudo = generateNonce();
    final nonceHash = sha256.convert(utf8.encode(nonceCrudo)).toString();

    AuthorizationCredentialAppleID cred;
    try {
      cred = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.fullName,
          AppleIDAuthorizationScopes.email,
        ],
        nonce: nonceHash,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      debugPrint('[social] Apple ${e.code}: ${e.message}');
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const SocialAuthCancelled();
      }
      throw const SocialAuthUnavailable(
        'No pudimos completar el ingreso con Apple. Probá de nuevo.',
      );
    } on SignInWithAppleNotSupportedException catch (e) {
      debugPrint('[social] Apple no soportado: ${e.message}');
      throw const SocialAuthUnavailable(
        'Tu iPhone no soporta el ingreso con Apple. Entrá con tu número.',
      );
    } catch (e) {
      debugPrint('[social] Apple error inesperado: $e');
      throw const SocialAuthUnavailable(
        'No pudimos completar el ingreso con Apple. Probá de nuevo.',
      );
    }

    final idToken = cred.identityToken;
    if (idToken == null || idToken.isEmpty) {
      throw const SocialAuthUnavailable(
        'No pudimos verificar tu cuenta de Apple. Probá con tu número.',
      );
    }

    // **Ésta es la única vez que Apple da el nombre.** Llega FUERA del token
    // (`givenName`/`familyName`) y sólo en la PRIMERA autorización de este
    // Apple ID para esta app: si no lo mandamos ahora, no se recupera nunca y
    // el alta va a tener que pedirlo a mano.
    final nombre = [cred.givenName, cred.familyName]
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .join(' ');

    return SocialCredential(
      provider: SocialProvider.apple,
      idToken: idToken,
      nonce: nonceCrudo,
      name: nombre.isEmpty ? null : nombre,
      email: cred.email,
    );
  }
}
