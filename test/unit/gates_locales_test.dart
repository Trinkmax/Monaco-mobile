import 'package:flutter_test/flutter_test.dart';
import 'package:monaco_mobile/core/auth/auth_provider.dart';
import 'package:monaco_mobile/core/auth/biometric_service.dart';
import 'package:monaco_mobile/features/onboarding/presentation/widgets/copy_sesion.dart';
import 'package:monaco_mobile/features/profile/presentation/screens/pin_verify_screen.dart';

void main() {
  group('debeOfrecerBiometria', () {
    test('con la biometría APAGADA no se ofrece, aunque el equipo la tenga',
        () {
      // Éste es el caso que estaba mal: el cliente protege la app sólo con
      // PIN, el teléfono tiene Face ID, y la pantalla dibujaba el botón de
      // biometría y la flecha atrás. Los dos van a `/biometric`, que con la
      // preferencia apagada rebota a `/pin`: parpadeo y vuelta al mismo lugar.
      expect(
        debeOfrecerBiometria(
          preferida: false,
          kind: BiometricKind.face,
          status: AuthStatus.needsBiometric,
        ),
        isFalse,
      );
    });

    test('prendida y en el gate, sí', () {
      expect(
        debeOfrecerBiometria(
          preferida: true,
          kind: BiometricKind.fingerprint,
          status: AuthStatus.needsBiometric,
        ),
        isTrue,
      );
    });

    test('sin hardware no se ofrece aunque esté prendida', () {
      expect(
        debeOfrecerBiometria(
          preferida: true,
          kind: BiometricKind.none,
          status: AuthStatus.needsBiometric,
        ),
        isFalse,
      );
    });

    test('con la sesión ya abierta no hay gate que resolver', () {
      for (final s in [
        AuthStatus.authenticated,
        AuthStatus.guest,
        AuthStatus.unauthenticated,
        AuthStatus.initial,
      ]) {
        expect(
          debeOfrecerBiometria(
            preferida: true,
            kind: BiometricKind.face,
            status: s,
          ),
          isFalse,
          reason: '$s',
        );
      }
    });
  });

  group('copy de cerrar sesión', () {
    test('no promete un código que el login silencioso no va a pedir', () {
      // `clearSession()` conserva el `device_secret`, así que `start` devuelve
      // la sesión sin mandar nada. Prometer un código de WhatsApp es describir
      // otra app.
      expect(kCerrarSesionDetalle.toLowerCase(), isNot(contains('whatsapp')));
      expect(kCerrarSesionDetalle.toLowerCase(), isNot(contains('código de')));
      expect(kCerrarSesionDetalle, contains('bienvenida'));
      expect(kCerrarSesionDetalle, contains('Google'));
      expect(kCerrarSesionDetalle, contains('Apple'));
    });
  });
}
