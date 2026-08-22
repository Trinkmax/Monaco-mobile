import 'package:flutter_test/flutter_test.dart';

import 'package:monaco_mobile/features/onboarding/utils/phone_format.dart';

void main() {
  group('ArPhone.normalizeTyped', () {
    test('deja los 10 dígitos nacionales tal cual', () {
      expect(ArPhone.normalizeTyped('3512125249'), '3512125249');
      expect(ArPhone.normalizeTyped('351 212-5249'), '3512125249');
    });

    test('saca +54 9 / 54 / 0 troncal / 9 / 15', () {
      expect(ArPhone.normalizeTyped('+54 9 351 212 5249'), '3512125249');
      expect(ArPhone.normalizeTyped('5493512125249'), '3512125249');
      expect(ArPhone.normalizeTyped('543512125249'), '3512125249');
      expect(ArPhone.normalizeTyped('03512125249'), '3512125249');
      expect(ArPhone.normalizeTyped('93512125249'), '3512125249');
      expect(ArPhone.normalizeTyped('351152125249'), '3512125249');
      expect(ArPhone.normalizeTyped('0351 15 212 5249'), '3512125249');
    });

    test('AMBA: área de 2 dígitos', () {
      expect(ArPhone.normalizeTyped('11 1234-5678'), '1112345678');
      expect(ArPhone.normalizeTyped('011 15 1234 5678'), '1112345678');
    });

    test('no pasa de 10 dígitos y tolera parciales', () {
      expect(ArPhone.normalizeTyped('35121252491234'), '3512125249');
      expect(ArPhone.normalizeTyped('35'), '35');
      expect(ArPhone.normalizeTyped(''), '');
    });
  });

  group('ArPhone.format / mask', () {
    test('formatea completo y parcial', () {
      expect(ArPhone.format('3512125249'), '351 212-5249');
      expect(ArPhone.format('1112345678'), '11 1234-5678');
      expect(ArPhone.format('35121'), '351 21');
      expect(ArPhone.format('351'), '351');
      expect(ArPhone.format(''), '');
    });

    test('internacional y enmascarado', () {
      expect(ArPhone.formatInternational('3512125249'), '+54 9 351 212-5249');
      expect(ArPhone.mask('3512125249'), '+54 9 351 ••• 5249');
      expect(ArPhone.mask('1112345678'), '+54 9 11 ••• 5678');
    });

    test('isCompleteMobile', () {
      expect(ArPhone.isCompleteMobile('351 212-5249'), isTrue);
      expect(ArPhone.isCompleteMobile('351 212-524'), isFalse);
      expect(ArPhone.isCompleteMobile('+54 9 351 212 5249'), isTrue);
    });
  });

  group('ArPhoneInputFormatter', () {
    const f = ArPhoneInputFormatter();

    TextEditingValue apply(String text) => f.formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(text: text),
    );

    test('dibuja el separador mientras se tipea', () {
      expect(apply('3').text, '3');
      expect(apply('3512').text, '351 2');
      expect(apply('3512125').text, '351 212-5');
      expect(apply('3512125249').text, '351 212-5249');
    });

    test('pegado con prefijo internacional', () {
      final v = apply('+54 9 351 212-5249');
      expect(v.text, '351 212-5249');
      expect(v.selection.baseOffset, v.text.length);
    });

    test('ignora letras', () {
      expect(apply('35a1b').text, '351');
    });
  });
}
