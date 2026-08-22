import 'package:flutter/services.dart';

/// Formateo y enmascarado de teléfonos argentinos **sólo para mostrar**.
///
/// La validez la decide el server (`normalizarTelefonoAR` en la edge function
/// `client-auth`); acá únicamente limpiamos lo que tipea o pega el usuario y
/// lo dibujamos como "351 212-5249". Lo que viaja al server son los dígitos.
class ArPhone {
  ArPhone._();

  /// Dígitos nacionales de un celular (código de área + número, sin 0 ni 15).
  static const int nationalLength = 10;

  /// Limpia lo tipeado/pegado y devuelve a lo sumo [nationalLength] dígitos:
  /// saca `+54`/`549`/`54`, el `0` troncal, el `9` de celular y el `15`
  /// después del código de área cuando sobran dígitos.
  static String normalizeTyped(String raw) {
    var d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('00')) d = d.substring(2);
    if (d.startsWith('549') && d.length >= 13) d = d.substring(3);
    if (d.startsWith('54') && d.length >= 12) d = d.substring(2);
    if (d.startsWith('0')) d = d.substring(1);
    if (d.length == 11 && d.startsWith('9')) d = d.substring(1);
    // "351 15 212 5249" → el 15 es el viejo prefijo de celular, no va.
    if (d.length > nationalLength) {
      final area = areaCodeLength(d);
      if (d.length >= area + 2 && d.substring(area, area + 2) == '15') {
        d = d.substring(0, area) + d.substring(area + 2);
      }
    }
    if (d.length > nationalLength) d = d.substring(0, nationalLength);
    return d;
  }

  /// Largo del código de área: 2 para AMBA (11), 3 para el resto. Los códigos
  /// de 4 dígitos (3541, 2964…) se dibujan como 3+7: cambia sólo el espaciado
  /// visual, los dígitos son los mismos.
  static int areaCodeLength(String digits) => digits.startsWith('11') ? 2 : 3;

  /// "3512125249" → "351 212-5249"; parcial: "35121" → "351 21".
  static String format(String digits) {
    final d = digits.replaceAll(RegExp(r'\D'), '');
    if (d.isEmpty) return '';
    final area = areaCodeLength(d);
    final buf = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (i == area || i == area + (nationalLength - area - 4)) {
        buf.write(i == area ? ' ' : '-');
      }
      buf.write(d[i]);
    }
    return buf.toString();
  }

  /// "+54 9 351 212-5249" para mostrar un número completo.
  static String formatInternational(String digits) {
    final d = normalizeTyped(digits);
    return '+54 9 ${format(d)}';
  }

  /// "+54 9 351 ••• 5249" (misma forma que el `phone_masked` del server).
  static String mask(String digits) {
    final d = normalizeTyped(digits);
    if (d.length < 7) return formatInternational(d);
    final area = areaCodeLength(d);
    final head = d.substring(0, area);
    final tail = d.substring(d.length - 4);
    return '+54 9 $head ••• $tail';
  }

  static bool isCompleteMobile(String digits) =>
      normalizeTyped(digits).length == nationalLength;
}

/// `TextInputFormatter` que mantiene sólo dígitos y dibuja "351 212-5249"
/// mientras se tipea. El texto del controller queda formateado; para obtener
/// los dígitos usar [ArPhone.normalizeTyped] sobre `controller.text`.
class ArPhoneInputFormatter extends TextInputFormatter {
  const ArPhoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = ArPhone.normalizeTyped(newValue.text);
    final formatted = ArPhone.format(digits);

    // Cursor al final siempre: el formateo mueve separadores y el usuario
    // tipea de corrido; es lo que hace el marcador del teléfono.
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
