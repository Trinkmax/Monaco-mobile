import 'package:flutter_test/flutter_test.dart';
import 'package:monaco_mobile/core/auth/social_auth_service.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart'
    show AuthorizationErrorCode;

/// Lo que le decimos al cliente cuando la hoja del proveedor falla.
///
/// La regla: **"Probá de nuevo" sólo si reintentar puede funcionar.** Los dos
/// casos que se veían más seguido en una revisión de tienda —un emulador de
/// Play sin cuenta de Google, un iPhone sin sesión de iCloud— no se arreglan
/// reintentando, y el cliente necesita saber qué le falta o por dónde entrar.
void main() {
  group('Google', () {
    test('"No credential available" = el teléfono no tiene cuenta de Google',
        () {
      // `google_sign_in_android` 7.2 envuelve el `noCredential` de Credential
      // Manager como `unknownError` con esta descripción.
      expect(
        SocialAuthService.esSinCuentaDeGoogle(
          'No credential available: androidx.credentials.exceptions.'
          'NoCredentialException',
        ),
        isTrue,
      );
      expect(SocialAuthService.esSinCuentaDeGoogle('no credential'), isTrue);
    });

    test('otras descripciones no se confunden con esa', () {
      expect(SocialAuthService.esSinCuentaDeGoogle(null), isFalse);
      expect(SocialAuthService.esSinCuentaDeGoogle(''), isFalse);
      expect(
        SocialAuthService.esSinCuentaDeGoogle('Network error, try again'),
        isFalse,
      );
    });
  });

  group('Apple', () {
    test('cancelar no es un error', () {
      expect(
        SocialAuthService.traducirApple(AuthorizationErrorCode.canceled),
        isA<SocialAuthCancelled>(),
      );
    });

    test('unknown (1000) = iPhone sin cuenta de Apple activa', () {
      // Es el equipo sin sesión de iCloud (o una build sin la capability, que
      // no llega a la tienda). "Probá de nuevo" no resuelve ninguna de las dos.
      final e = SocialAuthService.traducirApple(AuthorizationErrorCode.unknown);
      expect(e, isA<SocialAuthUnavailable>());
      final msg = (e as SocialAuthUnavailable).message;
      expect(msg, contains('cuenta de Apple'));
      expect(msg, contains('número'));
      expect(msg, isNot(contains('Probá de nuevo')));
    });

    test('los fallos reintentables sí dicen "probá de nuevo"', () {
      for (final code in [
        AuthorizationErrorCode.failed,
        AuthorizationErrorCode.invalidResponse,
        AuthorizationErrorCode.notHandled,
        AuthorizationErrorCode.notInteractive,
      ]) {
        final e = SocialAuthService.traducirApple(code);
        expect(e, isA<SocialAuthUnavailable>(), reason: '$code');
        expect(
          (e as SocialAuthUnavailable).message,
          contains('Probá de nuevo'),
          reason: '$code',
        );
      }
    });

    test('todo código conocido tiene traducción (nada en inglés se escapa)',
        () {
      for (final code in AuthorizationErrorCode.values) {
        expect(
          SocialAuthService.traducirApple(code),
          anyOf(isA<SocialAuthCancelled>(), isA<SocialAuthUnavailable>()),
          reason: '$code',
        );
      }
    });
  });
}
