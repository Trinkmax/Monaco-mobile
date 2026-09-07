import 'package:flutter_test/flutter_test.dart';

import 'package:monaco_mobile/core/deeplink/deep_link_handler.dart';
import 'package:monaco_mobile/features/senas/data/sena_pendiente_store.dart';

void main() {
  group('DeepLinkHandler.rutaPara', () {
    test('monaco://pago?deposit=<id> lleva a /pago/<id>', () {
      expect(
        DeepLinkHandler.rutaPara(
          Uri.parse('monaco://pago?deposit=3f2b9c10-5c1a-4f0e-9a11-77d2b8e4c001'),
        ),
        '/pago/3f2b9c10-5c1a-4f0e-9a11-77d2b8e4c001',
      );
    });

    test('ignora todo lo que no sea nuestro esquema y host', () {
      // Un deep link que navegue a cualquier lado es una puerta abierta: sólo
      // se reconoce la vuelta del checkout, nada más.
      const ajenos = [
        'https://monacobarber.vercel.app/pago/abc12345',
        'monaco://home?deposit=abc12345',
        'otra://pago?deposit=abc12345',
        'monaco://pago',
        'monaco://pago?deposit=',
        // Barras y puntos: el id va en el path y no puede reescribir la ruta.
        'monaco://pago?deposit=../../login',
        'monaco://pago?deposit=abc/def',
        'monaco://pago?deposit=corto',
      ];
      for (final u in ajenos) {
        expect(DeepLinkHandler.rutaPara(Uri.parse(u)), isNull, reason: u);
      }
    });

    test('el parámetro NO se llama code', () {
      // supabase_flutter engancha todos los deep links del proceso y trata
      // cualquiera con `code` como callback de OAuth. Si algún día alguien
      // "simplifica" el nombre, este test cae.
      expect(
        DeepLinkHandler.rutaPara(Uri.parse('monaco://pago?code=abc12345678')),
        isNull,
      );
    });
  });

  group('SenaPendiente', () {
    SenaPendiente marca({DateTime? vence, DateTime? creada}) => SenaPendiente(
          depositId: 'dep-1',
          resumen: 'Corte + Barba · Jue 4 sep 18:30',
          monto: 8000,
          initPoint: 'https://mp/checkout',
          venceEn: vence,
          creadaEn: creada ?? DateTime.utc(2026, 9, 4, 12),
        );

    test('roundtrip por JSON', () {
      final original = marca(vence: DateTime.utc(2026, 9, 4, 12, 30));
      final vuelta = SenaPendiente.fromJson(original.toJson());
      expect(vuelta, isNotNull);
      expect(vuelta!.depositId, 'dep-1');
      expect(vuelta.monto, 8000);
      expect(vuelta.initPoint, 'https://mp/checkout');
      expect(vuelta.venceEn, DateTime.utc(2026, 9, 4, 12, 30));
    });

    test('sigue vigente 30 minutos después del vencimiento', () {
      // Un pago hecho sobre el filo todavía puede acreditarse: cortar justo en
      // `expires_at` esconde el resultado que el cliente está esperando.
      final m = marca(vence: DateTime.utc(2026, 9, 4, 12, 30));
      expect(m.vigente(ahora: DateTime.utc(2026, 9, 4, 12, 40)), isTrue);
      expect(m.vigente(ahora: DateTime.utc(2026, 9, 4, 12, 59)), isTrue);
      expect(m.vigente(ahora: DateTime.utc(2026, 9, 4, 13, 5)), isFalse);
    });

    test('sin fecha de vencimiento vive como mucho 6 horas', () {
      final m = marca(vence: null);
      expect(m.vigente(ahora: DateTime.utc(2026, 9, 4, 17)), isTrue);
      expect(m.vigente(ahora: DateTime.utc(2026, 9, 4, 18, 30)), isFalse);
    });

    test('una marca sin id no se lee', () {
      expect(SenaPendiente.fromJson({'resumen': 'x'}), isNull);
    });
  });
}
