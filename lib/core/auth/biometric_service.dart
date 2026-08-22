import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Qué biometría ofrece el dispositivo, para elegir ícono y texto
/// ("Usar Face ID" no es lo mismo que "Usar huella").
enum BiometricKind { face, fingerprint, iris, generic, none }

extension BiometricKindX on BiometricKind {
  /// Nombre humano para botones y subtítulos.
  String get label {
    switch (this) {
      case BiometricKind.face:
        return 'Face ID';
      case BiometricKind.fingerprint:
        return 'huella';
      case BiometricKind.iris:
        return 'iris';
      case BiometricKind.generic:
        return 'biometría';
      case BiometricKind.none:
        return 'biometría';
    }
  }

  /// Etiqueta de botón: "Usar Face ID" / "Usar huella".
  String get ctaLabel => 'Usar $label';

  IconData get icon {
    switch (this) {
      case BiometricKind.face:
        return Icons.face_retouching_natural_rounded;
      case BiometricKind.fingerprint:
        return Icons.fingerprint_rounded;
      case BiometricKind.iris:
        return Icons.remove_red_eye_rounded;
      case BiometricKind.generic:
      case BiometricKind.none:
        return Icons.lock_person_rounded;
    }
  }
}

/// Resultado de [BiometricService.authenticate]: además del sí/no, por qué no,
/// para que la pantalla pueda decidir si insiste, ofrece el PIN o se queda
/// callada (el usuario canceló a propósito).
enum BiometricOutcome {
  success,
  cancelled,
  notAvailable,
  notEnrolled,
  lockedOut,
  failed,
}

/// Envoltorio de `local_auth`. Todo es best-effort: ninguna excepción de la
/// plataforma sale de acá.
class BiometricService {
  BiometricService._();

  static final _auth = LocalAuthentication();

  static Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } on PlatformException {
      return false;
    }
  }

  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  /// Tipo principal de biometría enrolada. `none` si no hay ninguna.
  static Future<BiometricKind> availableKind() async {
    if (!await isAvailable()) return BiometricKind.none;
    final types = await getAvailableBiometrics();
    if (types.contains(BiometricType.face)) return BiometricKind.face;
    if (types.contains(BiometricType.fingerprint)) {
      return BiometricKind.fingerprint;
    }
    if (types.contains(BiometricType.iris)) return BiometricKind.iris;
    if (types.contains(BiometricType.strong) ||
        types.contains(BiometricType.weak)) {
      // Android no siempre discrimina el tipo: la mayoría es huella.
      return defaultTargetPlatform == TargetPlatform.iOS
          ? BiometricKind.face
          : BiometricKind.fingerprint;
    }
    return BiometricKind.none;
  }

  /// Compatibilidad: `true` si autenticó.
  static Future<bool> authenticate({
    String reason = 'Verificá tu identidad para continuar',
    bool biometricOnly = false,
  }) async {
    final r = await authenticateDetailed(
      reason: reason,
      biometricOnly: biometricOnly,
    );
    return r == BiometricOutcome.success;
  }

  /// Versión con motivo. `biometricOnly: false` deja caer al código del
  /// dispositivo si la biometría falla (comportamiento nativo de iOS/Android).
  static Future<BiometricOutcome> authenticateDetailed({
    String reason = 'Verificá tu identidad para continuar',
    bool biometricOnly = false,
  }) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: biometricOnly,
          useErrorDialogs: true,
        ),
      );
      return ok ? BiometricOutcome.success : BiometricOutcome.cancelled;
    } on PlatformException catch (e) {
      debugPrint('[biometric] ${e.code}: ${e.message}');
      switch (e.code) {
        case 'NotAvailable':
        case 'PasscodeNotSet':
          return BiometricOutcome.notAvailable;
        case 'NotEnrolled':
          return BiometricOutcome.notEnrolled;
        case 'LockedOut':
        case 'PermanentlyLockedOut':
          return BiometricOutcome.lockedOut;
        case 'auth_in_progress':
        case 'UserCanceled':
        case 'SystemCanceled':
          return BiometricOutcome.cancelled;
        default:
          return BiometricOutcome.failed;
      }
    } catch (e) {
      debugPrint('[biometric] error inesperado: $e');
      return BiometricOutcome.failed;
    }
  }

  /// Cancela un prompt en curso (al salir de la pantalla, por ejemplo).
  static Future<void> stop() async {
    try {
      await _auth.stopAuthentication();
    } catch (_) {}
  }
}
