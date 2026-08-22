// Recorrido de QA visual de la app: arranca la app REAL (Supabase prod +
// API mobile local), navega por todas las pantallas y saca capturas.
//
// Correr con el driver para que las capturas se guarden en disco:
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/qa_flow_test.dart -d <simulador> \
//     --dart-define=API_BASE_URL=http://localhost:3000 \
//     --dart-define=QA_PHONE=1100000000
//
// Cada paso es tolerante: si un finder no aparece, se anota y se sigue, así
// una pantalla rota no tapa el resto del recorrido. Al final se imprimen las
// notas.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:monaco_mobile/core/auth/secure_storage.dart';
import 'package:monaco_mobile/core/utils/constants.dart';
import 'package:monaco_mobile/main.dart' as app;

const qaPhone = String.fromEnvironment('QA_PHONE', defaultValue: '1100000000');

final notas = <String>[];
int _shot = 0;

Future<void> shot(IntegrationTestWidgetsFlutterBinding binding, WidgetTester tester, String name) async {
  _shot++;
  final n = '${_shot.toString().padLeft(2, '0')}_$name';
  try {
    await tester.pump(const Duration(milliseconds: 400));
    await binding.takeScreenshot(n);
  } catch (e) {
    notas.add('screenshot $n falló: $e');
  }
}

/// Pumpea hasta que el finder aparezca (no usamos pumpAndSettle: hay
/// animaciones infinitas —LEDs, shimmers— que nunca "settlean").
Future<bool> esperar(WidgetTester tester, Finder f, {Duration timeout = const Duration(seconds: 20)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (f.evaluate().isNotEmpty) return true;
  }
  return false;
}

Future<void> pausa(WidgetTester tester, [int ms = 800]) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<bool> tapSi(WidgetTester tester, Finder f, String desc, {Duration timeout = const Duration(seconds: 12)}) async {
  if (!await esperar(tester, f, timeout: timeout)) {
    notas.add('NO encontré "$desc"');
    return false;
  }
  await tester.tap(f.first, warnIfMissed: false);
  await pausa(tester, 700);
  return true;
}

Finder texto(String t) => find.text(t, skipOffstage: false);
Finder textoQueContiene(String t) => find.textContaining(t, skipOffstage: false);

Future<Map<String, dynamic>?> apiGet(String path) async {
  final token = Supabase.instance.client.auth.currentSession?.accessToken;
  if (token == null) return null;
  final res = await http.get(
    Uri.parse('${AppConstants.apiBaseUrl}$path'),
    headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
  );
  if (res.statusCode >= 300) {
    notas.add('API $path → ${res.statusCode} ${res.body.substring(0, res.body.length.clamp(0, 160))}');
    return null;
  }
  return jsonDecode(res.body) as Map<String, dynamic>;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('recorrido completo de la app con capturas', (tester) async {
    // Estado limpio + modo prueba (para ver la sucursal Test y reservar ahí).
    await SecureStorageService.clearAll();
    await SecureStorageService.setTestModeEnabled(true);

    app.main();
    await pausa(tester, 1500);

    // ── Splash → Welcome ──────────────────────────────────────────────
    await shot(binding, tester, 'splash');
    await esperar(tester, texto('Siguiente'), timeout: const Duration(seconds: 15));
    await shot(binding, tester, 'welcome_1');
    await tapSi(tester, texto('Siguiente'), 'Siguiente');
    await shot(binding, tester, 'welcome_2');
    await tapSi(tester, texto('Siguiente'), 'Siguiente');
    await shot(binding, tester, 'welcome_3');
    await tapSi(tester, texto('Empezar'), 'Empezar');

    // ── Login: teléfono ───────────────────────────────────────────────
    await esperar(tester, find.byType(TextField));
    await shot(binding, tester, 'login_phone');
    final phoneField = find.byType(TextField).first;
    await tester.tap(phoneField, warnIfMissed: false);
    await pausa(tester, 300);
    await tester.enterText(phoneField, qaPhone);
    await pausa(tester, 400);
    await shot(binding, tester, 'login_phone_filled');
    await tapSi(tester, texto('Continuar'), 'Continuar (login)');

    // Con la v1 de client-auth la sesión entra directo; con la v2 aparece el
    // paso del código (teléfono de prueba, código fijo 123456).
    final llegoCodigo = await esperar(tester, textoQueContiene('Revisá tu WhatsApp'), timeout: const Duration(seconds: 12));
    if (llegoCodigo) {
      await shot(binding, tester, 'login_code');
      await tester.enterText(find.byType(TextField).first, '123456');
      await pausa(tester, 1200);
      await shot(binding, tester, 'login_code_filled');
      // Cliente nuevo → nombre
      if (await esperar(tester, textoQueContiene('¿Cómo te llamás?'), timeout: const Duration(seconds: 6))) {
        await shot(binding, tester, 'login_name');
        final fields = find.byType(TextField);
        await tester.enterText(fields.at(0), 'Nacho');
        if (fields.evaluate().length > 1) await tester.enterText(fields.at(1), 'QA');
        await pausa(tester, 400);
        await shot(binding, tester, 'login_name_filled');
        await tapSi(tester, texto('Listo'), 'Listo (nombre)');
      }
    }

    // ── Elegir sucursal (onboarding) ──────────────────────────────────
    final hayPicker = await esperar(tester, texto('¿A qué sucursal vas?'), timeout: const Duration(seconds: 25));
    if (!hayPicker) notas.add('No llegó al selector de sucursal (¿login falló?)');
    await pausa(tester, 2500); // señales + ubicación
    await shot(binding, tester, 'branch_picker');
    // Elegimos Test (reservable y seguro para crear/cancelar un turno).
    if (!await tapSi(tester, texto('Test'), 'sucursal Test')) {
      await tapSi(tester, texto('Rondeau'), 'sucursal Rondeau');
    }

    // ── Home ──────────────────────────────────────────────────────────
    await esperar(tester, textoQueContiene('Hola'), timeout: const Duration(seconds: 20));
    await pausa(tester, 3000);
    await shot(binding, tester, 'home');
    // scroll al fondo
    await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -900), warnIfMissed: false);
    await pausa(tester, 900);
    await shot(binding, tester, 'home_scrolled');
    await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, 900), warnIfMissed: false);
    await pausa(tester, 400);

    // ── Turnos (tab) ──────────────────────────────────────────────────
    await tapSi(tester, texto('Turnos'), 'dock Turnos');
    await pausa(tester, 2500);
    await shot(binding, tester, 'turnos_empty');

    // ── Wizard de reserva ─────────────────────────────────────────────
    await tapSi(tester, texto('Reservar'), 'FAB Reservar');
    await pausa(tester, 3500);
    await shot(binding, tester, 'wizard_step1');

    // Servicios del bootstrap de Test → tocar el primero.
    final boot = await apiGet('/api/mobile/turnos/test');
    final services = (boot?['services'] as List?) ?? const [];
    if (services.isNotEmpty) {
      final name = (services.first as Map)['name'] as String;
      if (await tapSi(tester, texto(name), 'servicio $name')) {
        await shot(binding, tester, 'wizard_service_selected');
      }
    } else {
      notas.add('bootstrap de Test sin servicios (o sin sesión): ${boot?.keys}');
    }
    await tapSi(tester, texto('Continuar'), 'Continuar (servicios)');
    await pausa(tester, 4000);
    await shot(binding, tester, 'wizard_slots');

    // Hoja de barberos
    if (await tapSi(tester, texto('Elegir barbero'), 'Elegir barbero', timeout: const Duration(seconds: 6))) {
      await pausa(tester, 1000);
      await shot(binding, tester, 'wizard_barber_sheet');
      await tapSi(tester, textoQueContiene('Cualquiera'), 'Cualquiera disponible', timeout: const Duration(seconds: 4));
      await pausa(tester, 800);
    }

    // Primer horario disponible (texto HH:MM dentro de un chip).
    final slotFinder = find.byWidgetPredicate(
      (w) => w is Text && w.data != null && RegExp(r'^\d{2}:\d{2}$').hasMatch(w.data!),
      skipOffstage: false,
    );
    var slotOk = false;
    if (await esperar(tester, slotFinder, timeout: const Duration(seconds: 15))) {
      // el primero suele ser la hora grande del resumen; probamos varios
      final all = slotFinder.evaluate().toList();
      for (var i = 0; i < all.length && i < 6; i++) {
        await tester.tap(find.byWidget(all[i].widget), warnIfMissed: false);
        await pausa(tester, 700);
        if (textoQueContiene('Entiendo que puedo cancelar').evaluate().isNotEmpty) {
          slotOk = true;
          break;
        }
      }
    }
    if (!slotOk) notas.add('No pude elegir un horario (¿sin slots en Test?)');
    await shot(binding, tester, 'wizard_slot_selected');

    // Política + confirmar
    await tapSi(tester, textoQueContiene('Entiendo que puedo cancelar'), 'checkbox política', timeout: const Duration(seconds: 4));
    await shot(binding, tester, 'wizard_policy_checked');
    var reservado = false;
    if (await tapSi(tester, texto('Confirmar turno'), 'Confirmar turno', timeout: const Duration(seconds: 4))) {
      await pausa(tester, 1500);
      await shot(binding, tester, 'confirmacion_verde');
      reservado = await esperar(tester, textoQueContiene('Turno confirmado'), timeout: const Duration(seconds: 12));
      await pausa(tester, 2800);
      await shot(binding, tester, 'confirmacion');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -700), warnIfMissed: false);
      await pausa(tester, 800);
      await shot(binding, tester, 'confirmacion_scrolled');
      await tapSi(tester, texto('Ver mi turno'), 'Ver mi turno', timeout: const Duration(seconds: 6));
    }

    // ── Mis turnos con el turno ───────────────────────────────────────
    // Si seguimos dentro del wizard (sin slots, error, etc.), salimos con "Atrás"
    // hasta volver al shell para que el resto del recorrido no quede trabado.
    for (var i = 0; i < 4; i++) {
      if (texto('Turnos').evaluate().isNotEmpty && texto('Perfil').evaluate().isNotEmpty) break;
      final back = find.byIcon(Icons.arrow_back_ios_new_rounded);
      if (back.evaluate().isNotEmpty) {
        await tester.tap(back.first, warnIfMissed: false);
        await pausa(tester, 900);
      } else if (texto('Atrás').evaluate().isNotEmpty) {
        await tester.tap(texto('Atrás').first, warnIfMissed: false);
        await pausa(tester, 900);
      } else {
        break;
      }
    }
    await pausa(tester, 3000);
    await shot(binding, tester, 'turnos_con_turno');
    if (reservado) {
      // Detalle
      if (await tapSi(tester, textoQueContiene('Ver'), 'Ver (detalle)', timeout: const Duration(seconds: 5))) {
        await pausa(tester, 2500);
        await shot(binding, tester, 'turno_detalle');
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -800), warnIfMissed: false);
        await pausa(tester, 700);
        await shot(binding, tester, 'turno_detalle_scrolled');
        // Cancelar
        if (await tapSi(tester, texto('Cancelar turno'), 'Cancelar turno', timeout: const Duration(seconds: 5)) ||
            await tapSi(tester, texto('Cancelar'), 'Cancelar', timeout: const Duration(seconds: 3))) {
          await pausa(tester, 800);
          await shot(binding, tester, 'cancelar_dialogo');
          await tapSi(tester, texto('Sí, cancelar'), 'Sí, cancelar', timeout: const Duration(seconds: 4));
          await pausa(tester, 3000);
          await shot(binding, tester, 'turno_cancelado');
        }
      }
    }
    // Volver al shell
    final back = find.byIcon(Icons.arrow_back_ios_new_rounded);
    if (back.evaluate().isNotEmpty) {
      await tester.tap(back.first, warnIfMissed: false);
      await pausa(tester, 900);
    }
    await tapSi(tester, texto('Turnos'), 'dock Turnos (2)');
    await pausa(tester, 2000);
    await tapSi(tester, texto('Anteriores'), 'tab Anteriores', timeout: const Duration(seconds: 4));
    await pausa(tester, 1500);
    await shot(binding, tester, 'turnos_anteriores');

    // ── Sucursales ────────────────────────────────────────────────────
    await tapSi(tester, texto('Sucursales'), 'dock Sucursales');
    await pausa(tester, 3000);
    await shot(binding, tester, 'sucursales');
    if (await tapSi(tester, texto('Rondeau'), 'Rondeau (detalle)', timeout: const Duration(seconds: 5))) {
      await pausa(tester, 3500);
      await shot(binding, tester, 'sucursal_detalle');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -700), warnIfMissed: false);
      await pausa(tester, 700);
      await shot(binding, tester, 'sucursal_detalle_scrolled');
      final b = find.byIcon(Icons.arrow_back_ios_new_rounded);
      if (b.evaluate().isNotEmpty) {
        await tester.tap(b.first, warnIfMissed: false);
        await pausa(tester, 900);
      }
    }

    // ── Premios ───────────────────────────────────────────────────────
    await tapSi(tester, texto('Premios'), 'dock Premios');
    await pausa(tester, 2500);
    await shot(binding, tester, 'premios');

    // ── Perfil ────────────────────────────────────────────────────────
    await tapSi(tester, texto('Perfil'), 'dock Perfil');
    await pausa(tester, 2500);
    await shot(binding, tester, 'perfil');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700), warnIfMissed: false);
    await pausa(tester, 700);
    await shot(binding, tester, 'perfil_scrolled');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 700), warnIfMissed: false);
    await pausa(tester, 500);

    // Editar nombre
    if (await tapSi(tester, texto('Editar nombre'), 'Editar nombre', timeout: const Duration(seconds: 5))) {
      await pausa(tester, 900);
      await shot(binding, tester, 'perfil_editar_nombre');
      final f = find.byType(TextField);
      if (f.evaluate().isNotEmpty) {
        await tester.enterText(f.last, 'Nacho QA');
        await pausa(tester, 300);
        await tapSi(tester, texto('Guardar'), 'Guardar nombre', timeout: const Duration(seconds: 4));
        await pausa(tester, 2500);
        await shot(binding, tester, 'perfil_nombre_guardado');
      }
    }

    // Notificaciones + preferencias
    if (await tapSi(tester, textoQueContiene('Bandeja'), 'Bandeja de notificaciones', timeout: const Duration(seconds: 4)) ||
        await tapSi(tester, textoQueContiene('Notificaciones'), 'Notificaciones', timeout: const Duration(seconds: 4))) {
      await pausa(tester, 2500);
      await shot(binding, tester, 'notificaciones');
      final b = find.byIcon(Icons.arrow_back_ios_new_rounded);
      if (b.evaluate().isNotEmpty) {
        await tester.tap(b.first, warnIfMissed: false);
        await pausa(tester, 900);
      }
    }
    if (await tapSi(tester, textoQueContiene('Preferencias'), 'Preferencias', timeout: const Duration(seconds: 4))) {
      await pausa(tester, 2500);
      await shot(binding, tester, 'notificaciones_preferencias');
      final b = find.byIcon(Icons.arrow_back_ios_new_rounded);
      if (b.evaluate().isNotEmpty) {
        await tester.tap(b.first, warnIfMissed: false);
        await pausa(tester, 900);
      }
    }

    // PIN setup
    if (await tapSi(tester, textoQueContiene('PIN'), 'PIN', timeout: const Duration(seconds: 4))) {
      await pausa(tester, 1200);
      await shot(binding, tester, 'pin_setup');
      final b = find.byIcon(Icons.arrow_back_ios_new_rounded);
      if (b.evaluate().isNotEmpty) {
        await tester.tap(b.first, warnIfMissed: false);
        await pausa(tester, 900);
      }
    }

    // Historial: visitas, puntos, canjes
    for (final item in ['Mis visitas', 'Transacciones de puntos', 'Mis canjes']) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300), warnIfMissed: false);
      await pausa(tester, 400);
      if (await tapSi(tester, textoQueContiene(item.split(' ').last), item, timeout: const Duration(seconds: 4))) {
        await pausa(tester, 2500);
        await shot(binding, tester, item.toLowerCase().replaceAll(' ', '_'));
        final b = find.byIcon(Icons.arrow_back_ios_new_rounded);
        if (b.evaluate().isNotEmpty) {
          await tester.tap(b.first, warnIfMissed: false);
          await pausa(tester, 900);
        }
      }
    }

    // ── Home: catálogo, convenios, cambiar sucursal ───────────────────
    await tapSi(tester, texto('Inicio'), 'dock Inicio');
    await pausa(tester, 2000);
    if (await tapSi(tester, texto('Catálogo'), 'Catálogo', timeout: const Duration(seconds: 5))) {
      await pausa(tester, 2500);
      await shot(binding, tester, 'catalogo');
      final b = find.byIcon(Icons.arrow_back_ios_new_rounded);
      if (b.evaluate().isNotEmpty) {
        await tester.tap(b.first, warnIfMissed: false);
        await pausa(tester, 900);
      }
    }
    // Pill de sucursal → cambiar sucursal
    if (await tapSi(tester, texto('Test'), 'pill sucursal', timeout: const Duration(seconds: 5))) {
      await pausa(tester, 2500);
      await shot(binding, tester, 'cambiar_sucursal');
      await tapSi(tester, texto('Rondeau'), 'elegir Rondeau', timeout: const Duration(seconds: 5));
      await pausa(tester, 2000);
      await shot(binding, tester, 'home_rondeau');
    }

    // ── Cerrar sesión ─────────────────────────────────────────────────
    await tapSi(tester, texto('Perfil'), 'dock Perfil (2)');
    await pausa(tester, 1500);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1200), warnIfMissed: false);
    await pausa(tester, 600);
    if (await tapSi(tester, texto('Cerrar sesión'), 'Cerrar sesión', timeout: const Duration(seconds: 5))) {
      await pausa(tester, 800);
      await shot(binding, tester, 'cerrar_sesion_dialogo');
      // confirmar (segundo botón con el mismo texto)
      final btns = texto('Cerrar sesión');
      if (btns.evaluate().length > 1) {
        await tester.tap(btns.last, warnIfMissed: false);
      }
      await pausa(tester, 2500);
      await shot(binding, tester, 'welcome_despues_logout');
    }

    // ignore: avoid_print
    print('[qa] NOTAS:\n${notas.isEmpty ? '(sin notas)' : notas.map((n) => ' - $n').join('\n')}');
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  }, timeout: const Timeout(Duration(minutes: 12)));
}
