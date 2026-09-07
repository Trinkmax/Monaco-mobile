import 'package:flutter_test/flutter_test.dart';
import 'package:monaco_mobile/features/rewards/data/premio_item.dart';

/// Fila de `get_loyalty_catalog()` (mig 197). Los campos nuevos (`kind`,
/// `locked_by_tier`, …) son opcionales para que los casos viejos sigan
/// probando la heurística de una fila pelada de `reward_catalog`.
Map<String, dynamic> _catalogo({
  String id = 'r1',
  String name = 'Premio',
  String? description,
  int pointsCost = 500,
  bool isFreeService = false,
  int? discountPct,
  int? stock,
  String? imageUrl,
  String? category,
  String? kind,
  bool? lockedByTier,
  String? tierRequiredName,
  String? tierRequiredCode,
  List<String>? allowedTiers,
  String? serviceName,
  int? validityDays,
  bool? isFeatured,
  bool? allowStacking,
}) =>
    {
      'id': id,
      'name': name,
      'description': description,
      'points_cost': pointsCost,
      'is_free_service': isFreeService,
      'discount_pct': discountPct,
      'stock': stock,
      'image_url': imageUrl,
      'category': category,
      'type': 'points_redemption',
      'valid_until': null,
      'kind': ?kind,
      'locked_by_tier': ?lockedByTier,
      'tier_required_name': ?tierRequiredName,
      'tier_required_code': ?tierRequiredCode,
      'allowed_tiers': ?allowedTiers,
      'service_name': ?serviceName,
      'validity_days': ?validityDays,
      'is_featured': ?isFeatured,
      'allow_stacking': ?allowStacking,
    };

void main() {
  group('PremioItem.deCatalogo — categoría', () {
    test('servicio gratis → Cortes', () {
      final p = PremioItem.deCatalogo(_catalogo(isFreeService: true));
      expect(p.categoria, PremioCategoria.cortes);
      expect(p.esServicioGratis, isTrue);
    });

    test('descuento > 0 → Cortes', () {
      final p = PremioItem.deCatalogo(_catalogo(discountPct: 20));
      expect(p.categoria, PremioCategoria.cortes);
    });

    test('descuento 0 no cuenta como descuento (hay filas con discount_pct=0)',
        () {
      final p = PremioItem.deCatalogo(_catalogo(discountPct: 0));
      expect(p.categoria, PremioCategoria.merch);
    });

    test('un producto cualquiera → Merch', () {
      final p = PremioItem.deCatalogo(_catalogo(name: 'Café'));
      expect(p.categoria, PremioCategoria.merch);
    });

    test('la columna `category` MANDA sobre la heurística', () {
      // Una gorra con descuento caería en Cortes por la regla; el dueño la
      // corrige desde el dashboard y tiene que ganar él.
      final p = PremioItem.deCatalogo(
        _catalogo(name: 'Gorra', discountPct: 15, category: 'merch'),
      );
      expect(p.categoria, PremioCategoria.merch);
    });

    test('una `category` desconocida se ignora y se deriva', () {
      final p = PremioItem.deCatalogo(
        _catalogo(isFreeService: true, category: 'cualquier_cosa'),
      );
      expect(p.categoria, PremioCategoria.cortes);
    });
  });

  group('PremioItem.deCatalogo — kind (mig 196)', () {
    test('kind descuento → Cortes aunque no traiga porcentaje', () {
      final p = PremioItem.deCatalogo(_catalogo(kind: 'descuento'));
      expect(p.kind, PremioKind.descuento);
      expect(p.categoria, PremioCategoria.cortes);
    });

    test('kind merch → Merch aunque tenga descuento cargado', () {
      final p = PremioItem.deCatalogo(_catalogo(kind: 'merch', discountPct: 15));
      expect(p.kind, PremioKind.merch);
      expect(p.esMerch, isTrue);
      expect(p.categoria, PremioCategoria.merch);
    });

    test('el override `category` sigue mandando sobre kind', () {
      final p = PremioItem.deCatalogo(
        _catalogo(kind: 'merch', category: 'cortes'),
      );
      expect(p.categoria, PremioCategoria.cortes);
    });

    test('kind especial cae a la heurística (gratis → Cortes, resto → Merch)', () {
      expect(
        PremioItem.deCatalogo(_catalogo(kind: 'especial', isFreeService: true))
            .categoria,
        PremioCategoria.cortes,
      );
      expect(
        PremioItem.deCatalogo(_catalogo(kind: 'especial')).categoria,
        PremioCategoria.merch,
      );
    });

    test('un kind desconocido no rompe: se deriva como antes', () {
      final p = PremioItem.deCatalogo(_catalogo(kind: 'raro', discountPct: 20));
      expect(p.kind, isNull);
      expect(p.categoria, PremioCategoria.cortes);
    });

    test('lee los campos nuevos del catálogo', () {
      final p = PremioItem.deCatalogo(_catalogo(
        kind: 'descuento',
        serviceName: 'Corte clásico',
        validityDays: 45,
        isFeatured: true,
        allowStacking: true,
        allowedTiers: ['oro', 'platinum'],
      ));
      expect(p.serviceName, 'Corte clásico');
      expect(p.validityDays, 45);
      expect(p.isFeatured, isTrue);
      expect(p.allowStacking, isTrue);
      expect(p.allowedTiers, ['oro', 'platinum']);
    });
  });

  group('PremioItem — candado por categoría', () {
    test('locked_by_tier lo bloquea aunque le sobre saldo y haya stock', () {
      final p = PremioItem.deCatalogo(_catalogo(
        pointsCost: 100,
        stock: 5,
        lockedByTier: true,
        tierRequiredName: 'Oro',
        tierRequiredCode: 'oro',
        allowedTiers: ['oro', 'platinum'],
      ));
      expect(p.lockedByTier, isTrue);
      expect(p.tierRequiredName, 'Oro');
      expect(p.tierRequiredCode, 'oro');
      // `alcanza` sigue midiendo sólo el saldo: la tarjeta lo usa para el
      // texto. Lo que decide "Canjear" es `puedeCanjear`.
      expect(p.alcanza(1000), isTrue);
      expect(p.puedeCanjear(1000), isFalse);
    });

    test('sin candado, puedeCanjear = alcanza y hay stock', () {
      final p = PremioItem.deCatalogo(_catalogo(pointsCost: 100, lockedByTier: false));
      expect(p.lockedByTier, isFalse);
      expect(p.puedeCanjear(99), isFalse);
      expect(p.puedeCanjear(100), isTrue);
      expect(
        PremioItem.deCatalogo(_catalogo(pointsCost: 100, stock: 0)).puedeCanjear(500),
        isFalse,
      );
    });

    test('una fila vieja sin locked_by_tier nunca queda bloqueada', () {
      expect(PremioItem.deCatalogo(_catalogo()).lockedByTier, isFalse);
      expect(PremioItem.deCatalogo(_catalogo()).allowedTiers, isNull);
    });

    test('un convenio nunca está bloqueado por categoría', () {
      final p = PremioItem.deConvenio({'id': 'b1', 'title': 'X'});
      expect(p.lockedByTier, isFalse);
      expect(p.puedeCanjear(0), isTrue);
    });
  });

  group('PremioItem.deCatalogo — campos', () {
    test('nombre vacío cae a "Premio" y los strings en blanco quedan null', () {
      final p = PremioItem.deCatalogo(
        _catalogo(name: '   ', description: '  ', imageUrl: ''),
      );
      expect(p.nombre, 'Premio');
      expect(p.subtitulo, isNull);
      expect(p.imagenUrl, isNull);
    });

    test('stock null = sin control; stock 0 = agotado', () {
      expect(PremioItem.deCatalogo(_catalogo()).agotado, isFalse);
      expect(PremioItem.deCatalogo(_catalogo(stock: 0)).agotado, isTrue);
      expect(PremioItem.deCatalogo(_catalogo(stock: 3)).agotado, isFalse);
    });
  });

  group('PremioItem.deConvenio', () {
    final row = {
      'id': 'b1',
      'title': '50% off en cheese burger',
      'discount_text': '50% off',
      'image_url': 'https://x/y.png',
      'valid_until': '2099-01-01T00:00:00+00:00',
      'partner': {'business_name': 'Bar Ítaca', 'logo_url': 'https://x/logo.png'},
    };

    test('siempre es categoría Marcas y siempre gratis', () {
      final p = PremioItem.deConvenio(row);
      expect(p.categoria, PremioCategoria.marcas);
      expect(p.origen, PremioOrigen.convenio);
      expect(p.esGratis, isTrue);
      expect(p.puntos, isNull);
    });

    test('el NOMBRE de la tarjeta es el comercio y el subtítulo el beneficio',
        () {
      final p = PremioItem.deConvenio(row);
      expect(p.nombre, 'Bar Ítaca');
      expect(p.subtitulo, '50% off');
      expect(p.marca, 'Bar Ítaca');
    });

    test('sin comercio cargado, el título hace de nombre', () {
      final p = PremioItem.deConvenio({...row, 'partner': null});
      expect(p.nombre, '50% off en cheese burger');
      expect(p.marca, isNull);
    });

    test('sin imagen propia usa el logo del comercio', () {
      final p = PremioItem.deConvenio({...row, 'image_url': null});
      expect(p.imagenUrl, 'https://x/logo.png');
    });
  });

  group('alcanza / faltan / progreso', () {
    test('un convenio siempre "alcanza" y nunca falta nada', () {
      final p = PremioItem.deConvenio({'id': 'b1', 'title': 'X'});
      expect(p.alcanza(0), isTrue);
      expect(p.faltan(0), 0);
      expect(p.progreso(0), 1);
    });

    test('con saldo justo alcanza (>=, no >)', () {
      final p = PremioItem.deCatalogo(_catalogo(pointsCost: 500));
      expect(p.alcanza(499), isFalse);
      expect(p.alcanza(500), isTrue);
      expect(p.faltan(500), 0);
      expect(p.faltan(200), 300);
    });

    test('faltan nunca es negativo y progreso está acotado a [0,1]', () {
      final p = PremioItem.deCatalogo(_catalogo(pointsCost: 100));
      expect(p.faltan(1000), 0);
      expect(p.progreso(1000), 1);
      expect(p.progreso(0), 0);
      expect(p.progreso(50), 0.5);
    });
  });

  group('icono', () {
    test('cae por lo que el premio HACE, no por su tipo', () {
      expect(
        PremioItem.deCatalogo(_catalogo(isFreeService: true)).icono.codePoint,
        isNot(PremioItem.deCatalogo(_catalogo()).icono.codePoint),
      );
    });
  });

  group('PremioCategoria', () {
    test('porSlug reconoce los tres y rechaza el resto', () {
      expect(PremioCategoria.porSlug('cortes'), PremioCategoria.cortes);
      expect(PremioCategoria.porSlug('merch'), PremioCategoria.merch);
      expect(PremioCategoria.porSlug('marcas'), PremioCategoria.marcas);
      expect(PremioCategoria.porSlug('otra'), isNull);
      expect(PremioCategoria.porSlug(null), isNull);
    });

    test('el orden de los chips es Cortes → Merch → Marcas', () {
      expect(
        PremioCategoria.values.map((c) => c.slug),
        ['cortes', 'merch', 'marcas'],
      );
    });
  });
}
