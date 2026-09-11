import 'package:flutter_test/flutter_test.dart';

import 'package:monaco_mobile/features/profile/presentation/screens/profile_screen.dart';

/// El rechazo de la baja de cuenta por una **seña pagada sin resolver**
/// (migración 215 → HTTP 409 `DEPOSIT_PENDING`).
///
/// El borrado no pasa por `MobileApi`, así que no hay `MobileApiException` con
/// su `code`: `AuthService.deleteAccount()` colapsa la respuesta a un `String?`
/// con el campo `error` del body. Por eso el Perfil reconoce el CÓDIGO, y por
/// eso vale la pena fijarlo: si el día de mañana ese camino empieza a devolver
/// el `message`, este test cae en vez de fallar en producción mostrándole al
/// cliente un toast con una palabra en inglés y ninguna salida.
void main() {
  group('esRechazoPorSenaPendiente', () {
    test('reconoce el código de la edge function', () {
      expect(esRechazoPorSenaPendiente(codigoSenaPendiente), isTrue);
      expect(esRechazoPorSenaPendiente('DEPOSIT_PENDING'), isTrue);
      // Por si el server manda el código de la RPC en minúsculas o embebido.
      expect(esRechazoPorSenaPendiente('deposit_pending'), isTrue);
      expect(
        esRechazoPorSenaPendiente('No se pudo: deposit_pending'),
        isTrue,
      );
    });

    test('cualquier otro error sigue siendo un error común', () {
      for (final e in const [
        null,
        '',
        'No pudimos eliminar la cuenta (HTTP 500).',
        'Sin conexión. Revisá tu internet y volvé a intentar.',
        'No hay una sesión abierta.',
      ]) {
        expect(esRechazoPorSenaPendiente(e), isFalse, reason: '$e');
      }
    });
  });
}
