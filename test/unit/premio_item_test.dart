import 'package:flutter_test/flutter_test.dart';
import 'package:monaco_mobile/features/rewards/data/premio_item.dart';

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
