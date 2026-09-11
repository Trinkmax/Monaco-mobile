import 'dart:io';

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
      // Con el observer de deep links de supabase_flutter prendido, cualquier
      // link con `code` se trata como callback de OAuth. Hoy está apagado
      // (`detectSessionInUri: false`), así que esto ya no es lo único que nos
      // separa de ese choque — pero el nombre se mantiene igual para no
      // depender de una opción que alguien puede revertir de pasada.
      expect(
        DeepLinkHandler.rutaPara(Uri.parse('monaco://pago?code=abc12345678')),
        isNull,
      );
    });
  });

  group('destinos de contenido (link_value cargado a mano)', () {
    test('acepta las rutas conocidas, con y sin query', () {
      expect(esRutaInternaDeContenido('/home'), isTrue);
      expect(esRutaInternaDeContenido('/rewards'), isTrue);
      // El QR del local manda al wizard con la sucursal ya elegida.
      expect(esRutaInternaDeContenido('/turnos/reservar?branch=rondeau'),
          isTrue);
      expect(esRutaInternaDeContenido('/branch/8f2c1d3e'), isTrue);
      expect(esRutaInternaDeContenido('/convenio/12'), isTrue);
    });

    test('rechaza lo que le pintaría al cliente la pantalla de error', () {
      const invalidos = [
        // Rutas que existieron y el dueño puede tener guardadas.
        '/catalog',
        '/elegir-sucursal',
        // Typos.
        '/premios',
        '/Home',
        // Prefijo sin id: `/branch/` solo no es ninguna sucursal.
        '/branch/',
        // No empieza con barra, o no es una ruta.
        'rewards',
        'https://monacobarber.vercel.app/turnos/monaco',
        '//evil.example.com',
        '',
      ];
      for (final v in invalidos) {
        expect(esRutaInternaDeContenido(v), isFalse, reason: v);
      }
    });

    test('sólo http y https se abren en el navegador', () {
      expect(esUrlExterna('https://instagram.com/monaco.barberia'), isTrue);
      expect(esUrlExterna('HTTP://monacobarber.vercel.app'), isTrue);
      for (final v in const [
        'javascript:alert(1)',
        'monaco://pago?deposit=abc12345',
        'ftp://archivos',
        '/rewards',
      ]) {
        expect(esUrlExterna(v), isFalse, reason: v);
      }
    });

    test('cada ruta de la lista blanca existe de verdad en el router', () {
      // La lista espeja `app_router.dart` (que `core/deeplink` no puede
      // importar sin ciclo). Si alguien renombra una ruta, la entrada queda
      // apuntando a la nada y el link deja de funcionar en silencio.
      final fuente = File('lib/core/router/app_router.dart').readAsStringSync();
      final delRouter = RegExp(r"path:\s*'([^']+)'")
          .allMatches(fuente)
          .map((m) => m.group(1)!)
          .toSet();
      expect(delRouter, contains('/home'), reason: 'no se pudo leer el router');
      for (final ruta in rutasInternasDeContenido) {
        expect(delRouter, contains(ruta));
      }
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
