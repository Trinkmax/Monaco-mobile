import 'package:flutter_test/flutter_test.dart';
import 'package:monaco_mobile/core/auth/auth_provider.dart';

void main() {
  group('AuthState', () {
    test('el estado por defecto arranca en initial y sin datos', () {
      const state = AuthState();
      expect(state.status, AuthStatus.initial);
      expect(state.clientId, isNull);
      expect(state.clientName, isNull);
      expect(state.clientPhone, isNull);
      expect(state.error, isNull);
      expect(state.isNewClient, isFalse);
      expect(state.isAuthenticated, isFalse);
    });

    test('el constructor acepta todos los campos', () {
      const state = AuthState(
        status: AuthStatus.authenticated,
        clientId: 'abc-123',
        clientName: 'Ignacio Baldovino',
        clientPhone: '3512125249',
        error: 'algo',
        isNewClient: true,
      );
      expect(state.status, AuthStatus.authenticated);
      expect(state.clientId, 'abc-123');
      expect(state.clientName, 'Ignacio Baldovino');
      expect(state.clientPhone, '3512125249');
      expect(state.error, 'algo');
      expect(state.isNewClient, isTrue);
      expect(state.isAuthenticated, isTrue);
    });

    test('copyWith conserva lo que no se pasa', () {
      const state = AuthState(
        status: AuthStatus.authenticated,
        clientId: '123',
        clientName: 'Test',
        clientPhone: '111',
      );
      final copied = state.copyWith(error: 'error nuevo');
      expect(copied.status, AuthStatus.authenticated);
      expect(copied.clientId, '123');
      expect(copied.clientName, 'Test');
      expect(copied.clientPhone, '111');
      expect(copied.error, 'error nuevo');
    });

    test('copyWith pisa status, clientId e isNewClient', () {
      const state = AuthState(clientId: 'old', isNewClient: false);
      final copied = state.copyWith(
        status: AuthStatus.authenticated,
        clientId: 'new',
        isNewClient: true,
      );
      expect(copied.status, AuthStatus.authenticated);
      expect(copied.clientId, 'new');
      expect(copied.isNewClient, isTrue);
    });

    test('copyWith sin error lo limpia (es deliberado: error no se arrastra)',
        () {
      const state = AuthState(
        status: AuthStatus.authenticated,
        error: 'error previo',
      );
      final copied = state.copyWith(status: AuthStatus.unauthenticated);
      expect(copied.error, isNull);
    });

    group('firstName', () {
      test('devuelve el primer token del nombre', () {
        expect(
          const AuthState(clientName: 'Ignacio Nahuel Baldovino').firstName,
          'Ignacio',
        );
      });

      test('ignora espacios de más', () {
        expect(const AuthState(clientName: '  Nacho   Baldovino ').firstName,
            'Nacho');
      });

      test('nombre vacío o nulo → vacío', () {
        expect(const AuthState().firstName, '');
        expect(const AuthState(clientName: '   ').firstName, '');
      });

      test('un nombre que es sólo dígitos (cuenta vieja sin nombre) → vacío',
          () {
        expect(const AuthState(clientName: '3512125249').firstName, '');
      });
    });
  });

  group('AuthStatus', () {
    test('tiene los 4 estados del contrato, en orden', () {
      expect(AuthStatus.values, [
        AuthStatus.initial,
        AuthStatus.unauthenticated,
        AuthStatus.needsBiometric,
        AuthStatus.authenticated,
      ]);
    });

    test(
        'no existe needsBranch: la app no tiene sucursal global desde el '
        'rediseño de ago/2026 (se elige en el paso 1 de la reserva)', () {
      expect(
        AuthStatus.values.map((e) => e.name),
        isNot(contains('needsBranch')),
      );
    });
  });

  group('StartResult', () {
    test('defaults del OTP: 10 min de vigencia y 45 s para reenviar', () {
      const r = StartResult(sessionReady: false, otpSent: true);
      expect(r.expiresIn, 600);
      expect(r.resendIn, 45);
      expect(r.clientKnown, isFalse);
      expect(r.firstName, isNull);
      expect(r.phoneMasked, isNull);
    });

    test('sesión lista (dispositivo conocido) no manda código', () {
      const r = StartResult(sessionReady: true, otpSent: false, clientKnown: true);
      expect(r.sessionReady, isTrue);
      expect(r.otpSent, isFalse);
      expect(r.clientKnown, isTrue);
    });
  });
}
