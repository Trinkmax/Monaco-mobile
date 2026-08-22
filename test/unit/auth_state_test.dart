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
      expect(state.selectedBranchId, isNull);
      expect(state.hasBranch, isFalse);
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
        selectedBranchId: 'b1',
        selectedBranchName: 'Rondeau',
        selectedBranchSlug: 'rondeau',
        selectedBranchOperationMode: 'hybrid',
      );
      expect(state.status, AuthStatus.authenticated);
      expect(state.clientId, 'abc-123');
      expect(state.clientName, 'Ignacio Baldovino');
      expect(state.clientPhone, '3512125249');
      expect(state.error, 'algo');
      expect(state.isNewClient, isTrue);
      expect(state.selectedBranchId, 'b1');
      expect(state.selectedBranchName, 'Rondeau');
      expect(state.selectedBranchSlug, 'rondeau');
      expect(state.selectedBranchOperationMode, 'hybrid');
      expect(state.hasBranch, isTrue);
      expect(state.isAuthenticated, isTrue);
    });

    test('copyWith conserva lo que no se pasa', () {
      const state = AuthState(
        status: AuthStatus.authenticated,
        clientId: '123',
        clientName: 'Test',
        clientPhone: '111',
        selectedBranchId: 'b1',
        selectedBranchSlug: 'rondeau',
      );
      final copied = state.copyWith(error: 'error nuevo');
      expect(copied.status, AuthStatus.authenticated);
      expect(copied.clientId, '123');
      expect(copied.clientName, 'Test');
      expect(copied.clientPhone, '111');
      expect(copied.selectedBranchId, 'b1');
      expect(copied.selectedBranchSlug, 'rondeau');
      expect(copied.error, 'error nuevo');
    });

    test('copyWith pisa status, clientId, isNewClient y sucursal', () {
      const state = AuthState(clientId: 'old', isNewClient: false);
      final copied = state.copyWith(
        status: AuthStatus.needsBranch,
        clientId: 'new',
        isNewClient: true,
        selectedBranchId: 'b2',
        selectedBranchName: 'Caseros',
        selectedBranchOperationMode: 'walk_in',
      );
      expect(copied.status, AuthStatus.needsBranch);
      expect(copied.clientId, 'new');
      expect(copied.isNewClient, isTrue);
      expect(copied.selectedBranchId, 'b2');
      expect(copied.selectedBranchName, 'Caseros');
      expect(copied.selectedBranchOperationMode, 'walk_in');
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

    group('acceptsAppointments / acceptsWalkIn', () {
      test('walk_in: sólo fila', () {
        const s = AuthState(selectedBranchOperationMode: 'walk_in');
        expect(s.acceptsAppointments, isFalse);
        expect(s.acceptsWalkIn, isTrue);
      });

      test('appointments: sólo turnos', () {
        const s = AuthState(selectedBranchOperationMode: 'appointments');
        expect(s.acceptsAppointments, isTrue);
        expect(s.acceptsWalkIn, isFalse);
      });

      test('hybrid: las dos', () {
        const s = AuthState(selectedBranchOperationMode: 'hybrid');
        expect(s.acceptsAppointments, isTrue);
        expect(s.acceptsWalkIn, isTrue);
      });

      test('sin modo conocido se asume walk_in (las sucursales viejas)', () {
        const s = AuthState();
        expect(s.acceptsAppointments, isFalse);
        expect(s.acceptsWalkIn, isTrue);
      });
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
    test('tiene los 5 estados del contrato, en orden', () {
      expect(AuthStatus.values, [
        AuthStatus.initial,
        AuthStatus.unauthenticated,
        AuthStatus.needsBiometric,
        AuthStatus.needsBranch,
        AuthStatus.authenticated,
      ]);
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
