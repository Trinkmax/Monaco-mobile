import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/theme/monaco_theme.dart';
import 'package:monaco_mobile/features/home/presentation/widgets/banda_sin_conexion.dart';

/// La banda de "Sin conexión" del Home y la regla que decide cuándo aparece.
///
/// El Home es la única pantalla sin `LiquidErrorState`: sus secciones colapsan
/// en silencio. Sin esta banda, un arranque en frío sin internet se ve igual
/// que una cuenta recién creada y el cliente no tiene forma de saber cuál de
/// las dos cosas está mirando.
void main() {
  final red = SocketException('Failed host lookup: gzsfoqpxvnwmvngfoqqk');
  final noRed = StateError('columna inexistente');

  group('sinConexionEn', () {
    test('un error de red la prende', () {
      expect(
        sinConexionEn([
          const AsyncValue<int>.data(1),
          AsyncValue<int>.error(red, StackTrace.empty),
        ]),
        isTrue,
      );
    });

    test('un error que NO es de red no la prende', () {
      // Un 500 nuestro o una fila mal formada no son "revisá tu wifi".
      expect(
        sinConexionEn([AsyncValue<int>.error(noRed, StackTrace.empty)]),
        isFalse,
      );
    });

    test('cargando o con datos, no aparece', () {
      expect(
        sinConexionEn([
          const AsyncValue<int>.loading(),
          const AsyncValue<int>.data(3),
        ]),
        isFalse,
      );
    });

    test('sin fuentes (invitado sin nada que pedir) tampoco', () {
      expect(sinConexionEn(const <AsyncValue<Object?>>[]), isFalse);
    });
  });

  group('hayDatosPreviosEn', () {
    test('true si alguna fuente conserva su último valor', () {
      expect(
        hayDatosPreviosEn([
          const AsyncValue<int>.data(7),
          AsyncValue<int>.error(red, StackTrace.empty),
        ]),
        isTrue,
      );
    });

    test('false en un arranque en frío sin red', () {
      expect(
        hayDatosPreviosEn([
          AsyncValue<int>.error(red, StackTrace.empty),
          AsyncValue<int>.error(red, StackTrace.empty),
        ]),
        isFalse,
      );
    });
  });

  Widget envolver(Widget child) => MaterialApp(
        theme: MonacoTheme.dark,
        home: Scaffold(
          backgroundColor: MonacoColors.background,
          body: Center(child: SizedBox(width: 390, child: child)),
        ),
      );

  testWidgets('con datos previos dice que lo que se ve es viejo', (t) async {
    await t.pumpWidget(
      envolver(BandaSinConexion(conDatosPrevios: true, onReintentar: () {})),
    );
    await t.pump(const Duration(milliseconds: 300));

    expect(find.text('Sin conexión'), findsOneWidget);
    expect(find.text('Mostrando lo último disponible.'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('sin datos previos no promete que haya algo', (t) async {
    await t.pumpWidget(
      envolver(BandaSinConexion(conDatosPrevios: false, onReintentar: () {})),
    );
    await t.pump(const Duration(milliseconds: 300));

    expect(find.text('No pudimos traer tus datos todavía.'), findsOneWidget);
    expect(find.text('Mostrando lo último disponible.'), findsNothing);
  });

  testWidgets('"Reintentar" llama al refresco del Home', (t) async {
    var veces = 0;
    await t.pumpWidget(
      envolver(BandaSinConexion(conDatosPrevios: true, onReintentar: () => veces++)),
    );
    await t.pump(const Duration(milliseconds: 300));

    await t.tap(find.text('Reintentar'));
    await t.pump(const Duration(milliseconds: 300));
    expect(veces, 1);
  });

  testWidgets('no desborda en una pantalla angosta', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: MonacoTheme.dark,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: BandaSinConexion(conDatosPrevios: true, onReintentar: () {}),
            ),
          ),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 300));
    expect(sinExcepciones(), isTrue);
  });
}

/// `pumpWidget` no tira por un overflow: lo reporta como excepción del
/// framework. Esto la levanta.
bool sinExcepciones() {
  final e = TestWidgetsFlutterBinding.instance.takeException();
  return e == null;
}
