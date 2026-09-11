import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/theme/monaco_theme.dart';
import 'package:monaco_mobile/features/home/presentation/widgets/wallet_points_card.dart';
import 'package:monaco_mobile/features/loyalty/data/loyalty_models.dart';
import 'package:monaco_mobile/features/loyalty/presentation/widgets/card_tilt.dart';
import 'package:monaco_mobile/features/loyalty/presentation/widgets/monaco_card.dart';
import 'package:monaco_mobile/features/rewards/data/premio_item.dart';
import 'package:monaco_mobile/features/rewards/presentation/widgets/premio_card.dart';
import 'package:monaco_mobile/features/rewards/presentation/widgets/premio_listo_card.dart';

/// Las piezas nuevas de la billetera. Lo que se está midiendo acá **es el
/// desborde**: son tarjetas de tamaño fijo (162–178 px de ancho, 138–158 de
/// alto) con textos que dependen del catálogo del dueño, y un overflow no
/// rompe el build ni los tests unitarios — sale como la barra amarilla en el
/// teléfono del cliente.
///
/// Se carga Poppins de verdad: con Ahem (glifos cuadrados de 1 em) los textos
/// miden casi el doble y todo desbordaría por un motivo que no existe en el
/// dispositivo.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Sin plugins en el host: la tarjeta no toca el acelerómetro.
    CardTilt.forzarSinSensor = true;
    // La tarjeta formatea el vencimiento con DateFormat('es'): sin esto tira
    // LocaleDataException dentro del build (en la app lo inicializa main.dart).
    await initializeDateFormatting('es');
    await initializeDateFormatting('es_AR');
    final loader = FontLoader('Poppins');
    for (final f in [
      'Poppins-Regular',
      'Poppins-Medium',
      'Poppins-SemiBold',
      'Poppins-Bold',
      'Poppins-ExtraBold',
      'Poppins-Black',
    ]) {
      final file = File('assets/fonts/$f.ttf');
      if (!file.existsSync()) continue;
      loader.addFont(Future.value(ByteData.sublistView(await file.readAsBytes())));
    }
    await loader.load();
  });

  Widget envolver(Widget child, {double ancho = 390}) {
    return MaterialApp(
      theme: MonacoTheme.dark,
      home: Scaffold(
        backgroundColor: MonacoColors.background,
        body: Center(
          child: SizedBox(width: ancho, child: child),
        ),
      ),
    );
  }

  /// Las tarjetas animan al entrar (flutter_animate) y el QR pinta: se bombean
  /// frames a mano en vez de `pumpAndSettle`.
  Future<void> frames(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));
  }

  PremioItem premio({
    String nombre = 'Corte gratis',
    String? subtitulo = 'Servicio',
    int? puntos = 300,
    int? stock,
    bool lockedByTier = false,
    String? tierRequiredName,
  }) =>
      PremioItem(
        id: 'p1',
        origen: PremioOrigen.catalogo,
        categoria: PremioCategoria.cortes,
        nombre: nombre,
        subtitulo: subtitulo,
        puntos: puntos,
        stock: stock,
        lockedByTier: lockedByTier,
        tierRequiredName: tierRequiredName,
      );

  // ── MonacoCard: datos fijos de un cliente Oro ───────────────────────────
  Map<String, dynamic> tierJson(String code, String name, int sort, int min,
          int? max, int mult, String p, String sec, String t) =>
      {
        'code': code,
        'name': name,
        'sort': sort,
        'min_visits': min,
        'max_visits': max,
        'multiplier_pct': mult,
        'color_primary': p,
        'color_secondary': sec,
        'text_color': t,
        'benefits': ['Beneficio uno', 'Beneficio dos'],
      };
  // Seed de la mig 202: texto SIEMPRE blanco.
  final tiers = [
    tierJson('bronce', 'Bronce', 1, 0, 2, 100, '#7A4A22', '#C78A4E', '#FFFFFF'),
    tierJson('plata', 'Plata', 2, 3, 5, 105, '#3E444D', '#A9B1BA', '#FFFFFF'),
    tierJson('oro', 'Oro', 3, 6, 8, 110, '#7A5A12', '#D8AE3C', '#FFFFFF'),
    tierJson('platinum', 'Platinum', 4, 9, null, 115, '#0B0B0D', '#3A3A44', '#FFFFFF'),
  ];
  LoyaltySummary oro({
    String nombre = 'Nacho Baldovino',
    String textoOro = '#FFFFFF',
    String nombreOro = 'Oro',
  }) =>
      LoyaltySummary.fromJson({
        'program': {
          'enabled': true,
          'base_points': 100,
          'expiry_days': 120,
          'window_weeks': 12,
          'grace_days': 14,
          'welcome_bonus_points': 100,
        },
        'client': {'id': 'c1', 'name': nombre, 'member_since': '2024-03-14T15:20:00Z'},
        'tier': {...tiers[2], 'text_color': textoOro, 'name': nombreOro},
        'next_tier': {...tiers[3], 'faltan': 2},
        'visits_in_window': 7,
        'grace': null,
        'points': {
          'balance': 650,
          'expiring_soon_points': 120,
          'expiring_soon_days': 14,
          'next_expiry_at': '2026-12-28T03:00:00Z',
          'next_expiry_points': 120,
        },
        'referral': {'enabled': true, 'code': 'ABC'},
        'tiers': tiers,
      });
  final apagado = LoyaltySummary.disabled(clientName: 'Nacho Baldovino', balance: 240);

  group('MonacoCard', () {
    testWidgets('pinta puntos, nombre, categoría y miembro desde', (tester) async {
      await tester.pumpWidget(envolver(
        MonacoCard(summary: oro(), saldo: 650, onTap: () {}),
      ));
      await frames(tester);

      expect(find.text('650'), findsOneWidget);
      expect(find.text('PUNTOS'), findsOneWidget);
      expect(find.text('NACHO BALDOVINO'), findsOneWidget);
      expect(find.text('CLIENTE ORO'), findsOneWidget);
      expect(find.text('MIEMBRO DESDE 2024'), findsOneWidget);
      expect(find.text('Ver progreso'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tiene la proporción de una tarjeta de crédito', (tester) async {
      await tester.pumpWidget(envolver(
        MonacoCard(summary: oro(), saldo: 650),
      ));
      await frames(tester);
      final r = tester.getSize(find.byType(MonacoCard));
      expect(r.width, 390);
      expect(r.width / r.height, closeTo(MonacoCard.proporcion, 0.01));
    });

    for (final ancho in const [390.0, 360.0, 320.0]) {
      testWidgets('no desborda a $ancho pt con nombre largo y saldo de 6 cifras',
          (tester) async {
        await tester.pumpWidget(envolver(
          MonacoCard(
            summary: oro(nombre: 'Maximiliano Alejandro Fernández Gutiérrez'),
            saldo: 128450,
            onTap: () {},
          ),
          ancho: ancho,
        ));
        await frames(tester);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('sin saldo dibuja un guión, nunca un 0', (tester) async {
      // `saldo: null` es "no se pudo leer" (RPC caída, primera carga sin red).
      // Un 0 en la tarjeta le dice al cliente que se quedó sin puntos, que es
      // la peor lectura posible de una billetera y encima es falsa.
      await tester.pumpWidget(envolver(
        MonacoCard(summary: oro(), saldo: null, onTap: () {}),
      ));
      await frames(tester);

      expect(find.text('—'), findsOneWidget);
      expect(find.text('0'), findsNothing);
      expect(find.text('PUNTOS'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sin saldo y sin categoría también dibuja el guión',
        (tester) async {
      await tester.pumpWidget(envolver(
        MonacoCard(summary: apagado, saldo: null),
      ));
      await frames(tester);

      expect(find.text('—'), findsOneWidget);
      expect(find.text('0'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('modo apagado: vidrio gris, sin etiqueta de categoría ni progreso',
        (tester) async {
      await tester.pumpWidget(envolver(
        MonacoCard(summary: apagado, saldo: 240, onTap: () {}),
      ));
      await frames(tester);

      expect(find.text('240'), findsOneWidget);
      expect(find.text('NACHO BALDOVINO'), findsOneWidget);
      expect(find.textContaining('CLIENTE '), findsNothing);
      expect(find.text('Ver progreso'), findsNothing);
      expect(find.text('MIEMBRO MONACO'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('en modo apagado el número y el pie son CLAROS (vidrio gris)',
        (tester) async {
      // La versión blanca sólida se probó y el dueño la rechazó: rompía el
      // lenguaje Liquid Glass del resto de la app. Sin categoría la tarjeta
      // es vidrio oscuro y el texto tiene que ser claro.
      await tester.pumpWidget(envolver(
        MonacoCard(summary: apagado, saldo: 240),
      ));
      await frames(tester);

      final numero = tester.widget<Text>(find.text('240')).style!;
      expect(numero.color!.computeLuminance(), greaterThan(0.8));
      final pie = tester.widget<Text>(find.text('PUNTOS')).style!;
      expect(pie.color!.computeLuminance(), greaterThan(0.3));
    });

    testWidgets('los colores salen del tier, no del código', (tester) async {
      // El seed es blanco (mig 202), así que para probar que el color VIAJA
      // desde el JSON se manda un crema que no coincide con ningún fallback.
      await tester.pumpWidget(envolver(
        MonacoCard(summary: oro(textoOro: '#FFE9B0'), saldo: 650, animarContador: false),
      ));
      await frames(tester);
      final numero = tester.widget<Text>(find.text('650')).style!;
      expect(numero.color, const Color(0xFFFFE9B0));
      final etiqueta = tester.widget<Text>(find.text('CLIENTE ORO')).style!;
      expect(etiqueta.color, const Color(0xFFFFE9B0));
    });

    testWidgets('un nombre de categoría de 40 caracteres no desborda la tarjeta',
        (tester) async {
      // El Zod del dashboard admite `name` hasta 40 caracteres. Sin
      // `Expanded` + ellipsis, la etiqueta desbordaba 150 px a 390 pt.
      await tester.pumpWidget(envolver(
        MonacoCard(
          summary: oro(nombreOro: 'Cliente Frecuente Premium Plus Nivel 2'),
          saldo: 650,
          animarContador: false,
        ),
      ));
      await frames(tester);
      expect(tester.takeException(), isNull);
      // Dorso: la misma etiqueta, misma regla.
      await tester.tap(find.text('Ver progreso'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.takeException(), isNull);
    });

    testWidgets('"Ver progreso" da vuelta la tarjeta y muestra cuánto falta',
        (tester) async {
      var toques = 0;
      await tester.pumpWidget(envolver(
        MonacoCard(summary: oro(), saldo: 650, onTap: () => toques++),
      ));
      await frames(tester);

      await tester.tap(find.text('Ver progreso'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('Te faltan 2 para Platinum'), findsOneWidget);
      expect(find.text('7 visitas en las últimas 12 semanas'), findsOneWidget);
      expect(find.text('7/9'), findsOneWidget);
      expect(find.text('120 pts vencen el 28/12'), findsOneWidget);
      expect(toques, 0, reason: 'la pill no dispara el onTap del cuerpo');
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Volver'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('Ver progreso'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('platinum: sin siguiente, el dorso dice que es la más alta',
        (tester) async {
      final s = LoyaltySummary.fromJson({
        'program': {'enabled': true, 'window_weeks': 12},
        'client': {'name': 'Ana'},
        'tier': tiers[3],
        'next_tier': null,
        'visits_in_window': 11,
        'points': {'balance': 2000},
        'tiers': tiers,
      });
      await tester.pumpWidget(envolver(
        MonacoCard(summary: s, saldo: 2000, animarContador: false),
      ));
      await frames(tester);
      expect(find.text('CLIENTE PLATINUM'), findsOneWidget);
      await tester.tap(find.text('Ver progreso'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('Sos Platinum, la categoría más alta'), findsOneWidget);
      expect(find.text('11'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('compact (carrusel): sin pill de progreso, entra a 300 pt',
        (tester) async {
      await tester.pumpWidget(envolver(
        MonacoCard(
          summary: oro(),
          saldo: 650,
          compact: true,
          animarContador: false,
          tier: LoyaltyTier.fromJson(tiers[0]),
        ),
        ancho: 300,
      ));
      await frames(tester);
      expect(find.text('CLIENTE BRONCE'), findsOneWidget);
      expect(find.text('Ver progreso'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tocar el cuerpo dispara onTap', (tester) async {
      var toques = 0;
      await tester.pumpWidget(envolver(
        MonacoCard(summary: oro(), saldo: 650, onTap: () => toques++),
      ));
      await frames(tester);
      await tester.tap(find.text('650'));
      await frames(tester);
      expect(toques, 1);
    });
  });

  group('WalletPointsCard (legado, ya no se usa en el Home)', () {
    testWidgets('sigue compilando y no desborda', (tester) async {
      await tester.pumpWidget(envolver(
        WalletPointsCard(
          saldo: 240,
          progreso: 0.8,
          pie: 'A 60 pts de Corte gratis',
          onTap: () {},
          onPremios: () {},
        ),
      ));
      await frames(tester);
      expect(find.text('240'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('PremioCard', () {
    testWidgets('con saldo suficiente invita a canjear', (tester) async {
      await tester.pumpWidget(envolver(
        PremioCard(premio: premio(), saldo: 500, onTap: () {}, width: 162),
        ancho: 200,
      ));
      await frames(tester);

      expect(find.text('300 pts'), findsOneWidget);
      expect(find.text('Canjear'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sin saldo dice cuánto FALTA, no cuánto cuesta', (tester) async {
      await tester.pumpWidget(envolver(
        PremioCard(premio: premio(), saldo: 40, onTap: () {}, width: 162),
        ancho: 200,
      ));
      await frames(tester);

      expect(find.text('Te faltan 260 pts'), findsOneWidget);
      expect(find.text('Canjear'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('agotado gana sobre "te alcanza"', (tester) async {
      await tester.pumpWidget(envolver(
        PremioCard(premio: premio(stock: 0), saldo: 9999, onTap: () {}, width: 162),
        ancho: 200,
      ));
      await frames(tester);

      expect(find.text('AGOTADO'), findsOneWidget);
      expect(find.text('Sin stock por ahora'), findsOneWidget);
      expect(find.text('Canjear'), findsNothing);
    });

    testWidgets('bloqueado por categoría: "Solo Oro", sin "Canjear", aunque sobre saldo',
        (tester) async {
      await tester.pumpWidget(envolver(
        PremioCard(
          premio: premio(lockedByTier: true, tierRequiredName: 'Oro'),
          saldo: 9999,
          onTap: () {},
          width: 162,
        ),
        ancho: 200,
      ));
      await frames(tester);

      expect(find.text('Solo Oro'), findsOneWidget);
      expect(find.text('Subí a Oro para canjearlo'), findsOneWidget);
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
      expect(find.text('Canjear'), findsNothing);
      expect(find.textContaining('Te faltan'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('bloqueado por categoría entra en la celda de la grilla con nombre largo',
        (tester) async {
      await tester.pumpWidget(envolver(
        SizedBox(
          width: 168,
          height: PremioCard.altoPara(168),
          child: PremioCard(
            premio: premio(
              nombre: 'Un año de cortes gratis más la camiseta',
              subtitulo: 'Exclusivo',
              puntos: 128450,
              lockedByTier: true,
              tierRequiredName: 'Platinum',
            ),
            saldo: 3,
            onTap: () {},
          ),
        ),
        ancho: 170,
      ));
      await frames(tester);
      expect(find.text('Solo Platinum'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('un convenio dice GRATIS y "Activar", no puntos', (tester) async {
      final convenio = PremioItem.deConvenio({
        'id': 'b1',
        'title': '2x1 en pintas',
        'discount_text': '2x1 pinta',
        'partner': {'business_name': 'Bar Ítaca'},
      });
      await tester.pumpWidget(envolver(
        PremioCard(premio: convenio, saldo: 0, onTap: () {}, width: 162),
        ancho: 200,
      ));
      await frames(tester);

      expect(find.text('GRATIS'), findsOneWidget);
      expect(find.text('Bar Ítaca'), findsOneWidget);
      expect(find.text('2x1 pinta'), findsOneWidget);
      expect(find.text('Activar'), findsOneWidget);
      expect(find.text('Canjear'), findsNothing);
    });

    // Estos dos casos reproducen las medidas REALES de la app. Sin constraint de
    // alto, la tarjeta crece todo lo que necesita y el overflow no aparece
    // nunca en los tests: hubo que encontrarlo corriendo el simulador.
    testWidgets('entra en la celda de la grilla con el alto que declara',
        (tester) async {
      await tester.pumpWidget(envolver(
        SizedBox(
          width: 168,
          height: PremioCard.altoPara(168),
          child: PremioCard(
            premio: premio(
              nombre: '20% off en el próximo corte',
              subtitulo: 'Descuento',
              puntos: 120,
            ),
            saldo: 240,
            onTap: () {},
          ),
        ),
        ancho: 200,
      ));
      await frames(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('entra en la tarjeta del carrusel del Home (162 de ancho)',
        (tester) async {
      await tester.pumpWidget(envolver(
        SizedBox(
          height: PremioCard.altoPara(162),
          child: PremioCard(
            premio: premio(
              nombre: '20% off en el próximo corte',
              subtitulo: 'Descuento',
              puntos: 120,
            ),
            saldo: 240,
            width: 162,
            onTap: () {},
          ),
        ),
        ancho: 200,
      ));
      await frames(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('nombre y subtítulo largos no desbordan la celda de la grilla',
        (tester) async {
      await tester.pumpWidget(envolver(
        SizedBox(
          width: 168,
          height: PremioCard.altoPara(168),
          child: PremioCard(
            premio: premio(
              nombre: 'Un año de cortes gratis más la camiseta de la selección',
              subtitulo: 'Incluye barba, lavado y peinado en cualquier sucursal',
              puntos: 128450,
            ),
            saldo: 3,
            onTap: () {},
          ),
        ),
        ancho: 170,
      ));
      await frames(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('PremioListoCard', () {
    testWidgets('dibuja el QR real y el vencimiento', (tester) async {
      // 12 días y un poco más: el mismo helper que el QR (`cuentaRegresiva`)
      // redondea hacia arriba, así que dice "Vence en 13 días" en las dos.
      final vence = DateTime.now().add(const Duration(days: 12, hours: 6));
      await tester.pumpWidget(envolver(
        PremioListoCard(
          reward: {
            'reward_name': 'Corte gratis',
            'qr_code': 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4',
            'expires_at': vence.toIso8601String(),
            'client_reward_id': 'cr1',
          },
          onTap: () {},
        ),
        ancho: 200,
      ));
      await frames(tester);

      expect(find.text('LISTO'), findsOneWidget);
      expect(find.text('Corte gratis'), findsOneWidget);
      expect(find.text('Mostrar código'), findsOneWidget);
      expect(find.text('Vence en 13 días'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a las 23:00, un premio que vence mañana NO dice "Vence hoy"',
        (tester) async {
      // Con `inDays` (trunca) la tira decía "Vence hoy" y el QR, con la misma
      // fila, "Vence mañana". Ahora comparten helper.
      final vence = DateTime.now().add(const Duration(hours: 11));
      await tester.pumpWidget(envolver(
        PremioListoCard(
          reward: {
            'reward_name': 'Café',
            'qr_code': 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4',
            'expires_at': vence.toIso8601String(),
          },
          onTap: () {},
        ),
        ancho: 200,
      ));
      await frames(tester);
      expect(find.text('Vence mañana'), findsOneWidget);
      expect(find.text('Vence hoy'), findsNothing);
    });

    testWidgets('sin código no dibuja un QR vacío: cae al ícono', (tester) async {
      await tester.pumpWidget(envolver(
        PremioListoCard(
          reward: const {'reward_name': 'Café', 'qr_code': ''},
          onTap: () {},
        ),
        ancho: 200,
      ));
      await frames(tester);

      expect(find.byIcon(Icons.qr_code_2_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('un premio vencido no imprime una fecha vieja', (tester) async {
      final ayer = DateTime.now().subtract(const Duration(days: 3));
      await tester.pumpWidget(envolver(
        PremioListoCard(
          reward: {
            'reward_name': 'Café',
            'qr_code': 'abc',
            'expires_at': ayer.toIso8601String(),
          },
          onTap: () {},
        ),
        ancho: 200,
      ));
      await frames(tester);

      expect(find.textContaining('Vence'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('un nombre largo no desborda la tarjeta fija', (tester) async {
      await tester.pumpWidget(envolver(
        PremioListoCard(
          reward: const {
            'reward_name': 'Un año de cortes gratis más la camiseta oficial',
            'qr_code': 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4',
          },
          onTap: () {},
        ),
        ancho: 200,
      ));
      await frames(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('PremioCard — el alto lo declara el widget', () {
    test('aspectoGrilla es coherente con altoPara', () {
      for (final ancho in const [140.0, 162.0, 168.0, 200.0]) {
        expect(
          PremioCard.aspectoGrilla(ancho),
          closeTo(ancho / PremioCard.altoPara(ancho), 0.0001),
        );
      }
    });

    testWidgets('el alto declarado alcanza JUSTO: con menos, desborda',
        (tester) async {
      // El bloque de texto tiene alturas fijas a propósito (layout
      // determinista, y todas las barras de canje alineadas en la grilla), así
      // que la tarjeta NO degrada: o le dan el alto que declara, o desborda.
      // Este test es la alarma si alguien baja `altoPara` "porque sobra".
      await tester.pumpWidget(envolver(
        SizedBox(
          width: 168,
          height: PremioCard.altoPara(168) - 20,
          child: PremioCard(
            premio: premio(
              nombre: '20% off en el próximo corte de pelo',
              subtitulo: 'Descuento',
              puntos: 120,
            ),
            saldo: 240,
            onTap: () {},
          ),
        ),
        ancho: 200,
      ));
      await frames(tester);
      expect(tester.takeException(), isNotNull);
    });

    testWidgets('un nombre de dos líneas se ve ENTERO, no recortado a media',
        (tester) async {
      // El bug: con el bloque de texto dentro de un Flexible, el Text de dos
      // líneas recibía menos alto del que pide y Flutter lo recortaba por la
      // mitad — la segunda línea del nombre quedaba pisada por el subtítulo.
      await tester.pumpWidget(envolver(
        SizedBox(
          width: 168,
          height: PremioCard.altoPara(168),
          child: PremioCard(
            premio: premio(
              nombre: '20% off en el próximo corte',
              subtitulo: 'Descuento',
              puntos: 120,
            ),
            saldo: 240,
            onTap: () {},
          ),
        ),
        ancho: 200,
      ));
      await frames(tester);

      final nombre = tester.getRect(find.text('20% off en el próximo corte'));
      final subtitulo = tester.getRect(find.text('Descuento'));
      // Dos líneas completas y sin solaparse con lo de abajo.
      expect(nombre.height, greaterThan(28));
      expect(nombre.bottom, lessThanOrEqualTo(subtitulo.top + 0.5));
      expect(tester.takeException(), isNull);
    });
  });
}
