// Reproducción del rechazo de App Review del 25/9/2026 (2.1a): "the app loaded
// indefinitely when we attempted to sign in" en un iPad Air 11" (M3).
//
//   xcrun simctl boot <udid-iPad-Air-11-M3>
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/login_ipad_repro_test.dart -d <udid>
//
// Por defecto entra como invitado y se loguea desde el muro (el camino que
// rompía); con REPRO_DIRECTO=true, desde la bienvenida. Hace el login con la cuenta demo por el camino del código (borra la caja
// fuerte antes, así el dispositivo es "nuevo" y el server manda OTP) y, después
// de tipear el código, registra cada 500 ms qué pantalla está arriba durante
// 25 s. Si el CTA sigue girando en la pantalla del código, el test falla.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:monaco_mobile/core/auth/secure_storage.dart';
import 'package:monaco_mobile/main.dart' as app;

Future<bool> esperar(WidgetTester t, Finder f, {int seg = 20}) async {
  final end = DateTime.now().add(Duration(seconds: seg));
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 250));
    if (f.evaluate().isNotEmpty) return true;
  }
  return false;
}

Future<void> tocar(WidgetTester t, Finder f, String desc) async {
  expect(await esperar(t, f), isTrue, reason: 'no apareció "$desc"');
  await t.tap(f.first, warnIfMissed: false);
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// `--dart-define=REPRO_DIRECTO=true` prueba el camino desde la bienvenida;
/// por defecto, el del revisor (invitado → muro → teléfono → código).
const _invitado = !bool.fromEnvironment('REPRO_DIRECTO');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('login con código en iPad llega al Home', (t) async {
    await SecureStorageService.clearAll();
    app.main();

    await tocar(t, find.text('Continuar'), 'Continuar 1');
    await tocar(t, find.text('Continuar'), 'Continuar 2');
    // Camino del revisor: entra como invitado y se loguea desde el muro, con
    // el Home del invitado ABAJO de /login y /login/codigo.
    if (_invitado) {
      await tocar(t, find.text('Seguir mirando'), 'Seguir mirando');
      await tocar(t, find.text('Sumá puntos\nen cada corte'), 'tarjeta invitado');
    }
    await tocar(t, find.text('Usar mi número de teléfono'), 'Usar mi número');

    expect(await esperar(t, find.byType(TextField)), isTrue);
    await t.enterText(find.byType(TextField).first, '1100000000');
    await t.pump(const Duration(milliseconds: 300));
    await tocar(t, find.text('Continuar'), 'Continuar teléfono');

    expect(await esperar(t, find.text('Revisá tu WhatsApp'), seg: 25), isTrue,
        reason: 'no llegó a la pantalla del código');
    await binding.takeScreenshot('repro_01_codigo');
    await t.enterText(find.byType(TextField).first, '123456');

    final log = <String>[];
    var enHome = false;
    for (var i = 0; i < 50; i++) {
      await t.pump(const Duration(milliseconds: 500));
      final codigo = find.text('Revisá tu WhatsApp').evaluate().isNotEmpty;
      final hola = find.textContaining('Hola, ').evaluate().isNotEmpty;
      final spinner =
          find.byType(CircularProgressIndicator).evaluate().length;
      log.add('${(i + 1) * 500}ms codigo=$codigo hola=$hola spinners=$spinner');
      if (i == 6 || i == 20 || i == 49) {
        await binding.takeScreenshot('repro_${i.toString().padLeft(2, '0')}');
      }
      if (hola && !codigo) {
        enHome = true;
        break;
      }
    }
    // ignore: avoid_print
    print('[repro]\n${log.join('\n')}');
    expect(enHome, isTrue, reason: 'se quedó en la pantalla del código');
  });
}
