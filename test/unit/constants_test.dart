import 'package:flutter_test/flutter_test.dart';
import 'package:monaco_mobile/core/utils/constants.dart';
import 'package:monaco_mobile/features/senas/presentation/widgets/arrepentimiento_link.dart';

/// Guardas baratas sobre la configuración fija de la app: lo que las tiendas
/// revisan (links legales, soporte) y lo que tiene que coincidir con el
/// backend (org, canal de push).
void main() {
  group('AppConstants', () {
    test('la app es mono-org Monaco', () {
      expect(AppConstants.organizationId,
          'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11');
      expect(AppConstants.organizationSlug, 'monaco');
      expect(AppConstants.testBranchSlug, 'test');
      expect(AppConstants.appName, 'Monaco');
    });

    test('URLs de backend son https y sin barra final', () {
      for (final url in [AppConstants.supabaseUrl, AppConstants.apiBaseUrl]) {
        expect(url, startsWith('https://'));
        expect(url, isNot(endsWith('/')));
      }
    });

    test('los links legales salen del dashboard propio, no de un dominio ajeno',
        () {
      expect(AppConstants.privacyPolicyUrl,
          '${AppConstants.apiBaseUrl}/privacidad');
      expect(AppConstants.termsOfServiceUrl,
          '${AppConstants.apiBaseUrl}/terminos');
      expect(AppConstants.privacyPolicyUrl, isNot(contains('barberos.app')));
      expect(AppConstants.termsOfServiceUrl, isNot(contains('barberos.app')));
    });

    test('las cuatro URL que declaran las fichas de tienda salen del dashboard',
        () {
      // Support URL de App Store Connect, recurso de borrado de cuenta de Play,
      // política de privacidad y botón de arrepentimiento. Si alguna se escribe
      // a mano en otro lado, la ficha y la app terminan apuntando a distinto.
      expect(AppConstants.supportUrl, '${AppConstants.apiBaseUrl}/soporte');
      expect(AppConstants.deleteAccountUrl,
          '${AppConstants.apiBaseUrl}/eliminar-cuenta');
      expect(AppConstants.arrepentimientoUrl,
          '${AppConstants.apiBaseUrl}/arrepentimiento');
      // El widget de seña usa la constante, no una copia (era un literal).
      expect(urlArrepentimiento, AppConstants.arrepentimientoUrl);
      for (final url in [
        AppConstants.privacyPolicyUrl,
        AppConstants.termsOfServiceUrl,
        AppConstants.supportUrl,
        AppConstants.deleteAccountUrl,
        AppConstants.arrepentimientoUrl,
      ]) {
        expect(url, startsWith('https://'));
      }
    });

    test('contacto de soporte real (no placeholders)', () {
      expect(AppConstants.supportEmail, contains('@'));
      expect(AppConstants.supportEmail, isNot(contains('barberos.app')));
      expect(AppConstants.supportWhatsappUrl, startsWith('https://wa.me/'));
      expect(AppConstants.supportWhatsappUrl, isNot(contains('5491100000000')));
    });

    test('el canal de push coincide con el manifest de Android (monaco_default)',
        () {
      expect(AppConstants.androidNotificationChannelId, 'monaco_default');
    });

    test('el código del modo prueba no es adivinable de un intento', () {
      // El gesto de los 7 toques destapa la sucursal `test`, que es una
      // sucursal REAL de producción y toma turnos. El código es el candado que
      // separa "lo encontré sin querer" de "sabía lo que hacía": si fuera
      // 0000/1234 no separaría nada.
      const codigo = AppConstants.testModeCode;
      expect(codigo, isNot(anyOf('', '0000', '1234', '000000', '123456')));
      expect(codigo.length, greaterThanOrEqualTo(6));
      expect(RegExp(r'^(.)\1*$').hasMatch(codigo), isFalse,
          reason: 'todos los dígitos iguales');
    });

    test('OTP de 6 dígitos, PIN local de 4, país 54', () {
      expect(AppConstants.otpLength, 6);
      expect(AppConstants.pinLength, 4);
      expect(AppConstants.defaultCountryCode, '54');
      expect(AppConstants.apiTimeout, const Duration(seconds: 15));
    });
  });
}
