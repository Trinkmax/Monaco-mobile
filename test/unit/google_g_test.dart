import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:monaco_mobile/features/onboarding/presentation/widgets/google_g.dart';

/// El "G" de Google se dibuja parseando las rutas del SVG oficial. Un parser
/// que se equivoca no explota: devuelve un `Path` raro y el botón queda con una
/// mancha. Estos tests miran la GEOMETRÍA, que es lo único que delata eso.
void main() {
  group('parsearRutaSvg', () {
    test('los comandos absolutos y relativos dan la misma figura', () {
      // Un cuadrado de 10×10 escrito de las dos formas.
      final abs = parsearRutaSvg('M0 0 L10 0 L10 10 L0 10 Z');
      final rel = parsearRutaSvg('m0 0 l10 0 l0 10 l-10 0 z');
      expect(abs.getBounds(), rel.getBounds());
      expect(abs.getBounds(), const Rect.fromLTRB(0, 0, 10, 10));
    });

    test('H y V son horizontal y vertical, absolutos y relativos', () {
      final p = parsearRutaSvg('M2 2 H12 V12 h-10 v-10 z');
      expect(p.getBounds(), const Rect.fromLTRB(2, 2, 12, 12));
    });

    test('coordenadas repetidas después de M son L implícitas', () {
      final p = parsearRutaSvg('M0 0 5 0 5 5 0 5 z');
      expect(p.getBounds(), const Rect.fromLTRB(0, 0, 5, 5));
    });

    test('una ruta malformada devuelve un path vacío, no una excepción', () {
      expect(parsearRutaSvg('12 34 nada').computeMetrics().isEmpty, isTrue);
      expect(parsearRutaSvg('').computeMetrics().isEmpty, isTrue);
    });

    test('cierra la ruta volviendo al inicio del subpath', () {
      // Después de `z` el punto actual vuelve al del `M`: el segundo trazo
      // arranca ahí y la figura no se estira hacia el origen.
      final p = parsearRutaSvg('M10 10 h5 v5 z h-5');
      expect(p.getBounds().left, 5);
      expect(p.getBounds().top, 10);
    });
  });

  group('logo oficial de Google', () {
    test('las 4 rutas entran justo en el viewBox 18×18', () {
      // Si el parser se comiera un comando, la figura se saldría del viewBox
      // (o quedaría degenerada) y el botón mostraría cualquier cosa.
      for (final (d, _) in rutasGoogleG) {
        final b = parsearRutaSvg(d).getBounds();
        expect(b.left, greaterThanOrEqualTo(-0.01));
        expect(b.top, greaterThanOrEqualTo(-0.01));
        expect(b.right, lessThanOrEqualTo(18.01));
        expect(b.bottom, lessThanOrEqualTo(18.01));
        // Ninguna de las cuatro es un punto: todas tienen área visible.
        expect(b.width, greaterThan(2));
        expect(b.height, greaterThan(2));
      }
    });

    test('las cuatro juntas cubren el círculo entero de la marca', () {
      var union = Rect.zero;
      for (final (d, _) in rutasGoogleG) {
        final b = parsearRutaSvg(d).getBounds();
        union = union == Rect.zero ? b : union.expandToInclude(b);
      }
      expect(union.width, closeTo(17.7, 0.6));
      expect(union.height, closeTo(18, 0.3));
    });
  });
}
