import 'package:flutter_test/flutter_test.dart';
import 'package:monaco_mobile/core/auth/auth_provider.dart';

void main() {
  group('AuthState', () {
    test('default state has initial status', () {
      const state = AuthState();
      expect(state.status, AuthStatus.initial);
      expect(state.clientId, isNull);
      expect(state.clientName, isNull);
      expect(state.error, isNull);
      expect(state.isNewClient, isFalse);
    });

    test('constructor accepts all fields', () {
      const state = AuthState(
        status: AuthStatus.authenticated,
        clientId: 'abc-123',
        clientName: 'John',
        error: 'some error',
        isNewClient: true,
      );
      expect(state.status, AuthStatus.authenticated);
      expect(state.clientId, 'abc-123');
      expect(state.clientName, 'John');
      expect(state.error, 'some error');
      expect(state.isNewClient, isTrue);
    });

    test('copyWith preserves unchanged fields', () {
      const state = AuthState(
        status: AuthStatus.authenticated,
        clientId: '123',
        clientName: 'Test',
      );
      final copied = state.copyWith(error: 'some error');
      expect(copied.status, AuthStatus.authenticated);
      expect(copied.clientId, '123');
      expect(copied.clientName, 'Test');
      expect(copied.error, 'some error');
    });

    test('copyWith overrides status', () {
      const state = AuthState(status: AuthStatus.initial);
      final copied = state.copyWith(status: AuthStatus.authenticated);
      expect(copied.status, AuthStatus.authenticated);
    });

    test('copyWith overrides clientId', () {
      const state = AuthState(clientId: 'old');
      final copied = state.copyWith(clientId: 'new');
      expect(copied.clientId, 'new');
    });

    test('copyWith overrides isNewClient', () {
      const state = AuthState(isNewClient: false);
      final copied = state.copyWith(isNewClient: true);
      expect(copied.isNewClient, isTrue);
    });

    test('copyWith without error sets error to null', () {
      // The copyWith implementation passes error directly (not error ?? this.error),
      // so calling copyWith without specifying error will clear it to null.
      const state = AuthState(
        status: AuthStatus.authenticated,
        error: 'previous error',
      );
      final copied = state.copyWith(status: AuthStatus.unauthenticated);
      expect(copied.error, isNull);
    });

    test('copyWith with explicit error preserves it', () {
      const state = AuthState(error: 'old error');
      final copied = state.copyWith(error: 'new error');
      expect(copied.error, 'new error');
    });
  });

  group('AuthStatus', () {
    test('has all expected values', () {
      expect(
        AuthStatus.values,
        containsAll([
          AuthStatus.initial,
          AuthStatus.unauthenticated,
          AuthStatus.needsBiometric,
          AuthStatus.authenticated,
        ]),
      );
    });

    test('has exactly 4 values', () {
      expect(AuthStatus.values.length, 4);
    });

    test('initial is at index 0', () {
      expect(AuthStatus.initial.index, 0);
    });

    test('authenticated is the last value', () {
      expect(AuthStatus.authenticated, AuthStatus.values.last);
    });
  });
}
