import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/theme/monaco_theme.dart';
import 'package:monaco_mobile/features/home/presentation/widgets/wallet_points_card.dart';
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
  }) =>
      PremioItem(
        id: 'p1',
        origen: PremioOrigen.catalogo,
        categoria: PremioCategoria.cortes,
        nombre: nombre,
        subtitulo: subtitulo,
        puntos: puntos,
        stock: stock,
      );

  group('WalletPointsCard', () {
    testWidgets('muestra el saldo y el pie, y no desborda', (tester) async {
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

      expect(find.text('Tus puntos'), findsOneWidget);
      expect(find.text('240'), findsOneWidget);
      expect(find.text('A 60 pts de Corte gratis'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('un saldo de 6 cifras y un premio de nombre largo no desbordan',
        (tester) async {
      await tester.pumpWidget(envolver(
        WalletPointsCard(
          saldo: 128450,
          progreso: 0.03,
          pie: 'A 121.550 pts de Un año de cortes gratis más la camiseta',
          onTap: () {},
          onPremios: () {},
        ),
      ));
      await frames(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sin progreso no dibuja barra pero sí el pie', (tester) async {
      await tester.pumpWidget(envolver(
        WalletPointsCard(
          saldo: 0,
          progreso: null,
          pie: 'Sumás puntos en cada visita',
          onTap: () {},
          onPremios: () {},
        ),
      ));
      await frames(tester);
      expect(find.text('Sumás puntos en cada visita'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('el número y el pie son CLAROS (la tarjeta es vidrio gris)',
        (tester) async {
      // La versión blanca sólida se probó y el dueño la rechazó: rompía el
      // lenguaje Liquid Glass del resto de la app. Este test fija que no vuelva
      // por accidente — sobre vidrio oscuro el texto tiene que ser claro.
      await tester.pumpWidget(envolver(
        WalletPointsCard(
          saldo: 240,
          progreso: 0.5,
          pie: 'A 60 pts de Corte',
          onTap: () {},
          onPremios: () {},
        ),
      ));
      await frames(tester);

      final numero = tester.widget<Text>(find.text('240')).style!;
      expect(numero.color!.computeLuminance(), greaterThan(0.8));
      final pie = tester.widget<Text>(find.text('A 60 pts de Corte')).style!;
      expect(pie.color!.computeLuminance(), greaterThan(0.3));
    });

    testWidgets('el botón de regalo es un destino aparte del cuerpo',
        (tester) async {
      var cuerpo = 0;
      var regalo = 0;
      await tester.pumpWidget(envolver(
        WalletPointsCard(
          saldo: 240,
          progreso: 0.5,
          pie: 'x',
          onTap: () => cuerpo++,
          onPremios: () => regalo++,
        ),
      ));
      await frames(tester);

      await tester.tap(find.byIcon(Icons.card_giftcard_rounded));
      await frames(tester);
      expect(regalo, 1);
      expect(cuerpo, 0);

      await tester.tap(find.text('240'));
      await frames(tester);
      expect(cuerpo, 1);
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

      expect(find.text('Agotado'), findsOneWidget);
      expect(find.text('Sin stock por ahora'), findsOneWidget);
      expect(find.text('Canjear'), findsNothing);
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
      final manana = DateTime.now().add(const Duration(days: 12));
      await tester.pumpWidget(envolver(
        PremioListoCard(
          reward: {
            'reward_name': 'Corte gratis',
            'qr_code': 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4',
            'expires_at': manana.toIso8601String(),
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
      expect(find.textContaining('Vence el'), findsOneWidget);
      expect(tester.takeException(), isNull);
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
