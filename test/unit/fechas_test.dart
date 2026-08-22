import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:monaco_mobile/features/appointments/data/fechas.dart';

/// `Fechas` es la única fuente de verdad de "hora de pared de la sucursal"
/// en la app. Todo lo que se prueba acá es puro y determinístico (se pasa
/// `now` explícito donde aplica).
void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_AR');
  });

  const ba = Fechas.tzBuenosAires;

  group('zona horaria', () {
    test('Buenos Aires es UTC-3 fijo; UTC es 0', () {
      expect(Fechas.offsetOf(ba), const Duration(hours: -3));
      expect(Fechas.offsetOf('UTC'), Duration.zero);
      expect(Fechas.offsetOf(null), const Duration(hours: -3),
          reason: 'sin zona se asume la de Monaco');
    });

    test('nowWall/todayStr dan el día de la BARBERÍA, no el del teléfono', () {
      // 02:00 UTC del 21/8 = 23:00 del 20/8 en Buenos Aires.
      final now = DateTime.utc(2026, 8, 21, 2, 0);
      expect(Fechas.todayStr(ba, now: now), '2026-08-20');
      expect(Fechas.todayStr('UTC', now: now), '2026-08-21');
      final wall = Fechas.nowWall(ba, now: now);
      expect(wall.hour, 23);
      expect(wall.day, 20);
    });

    test('instantOf convierte hora de pared a instante UTC', () {
      expect(Fechas.instantOf('2026-08-21', '15:00', ba), DateTime.utc(2026, 8, 21, 18, 0));
      expect(Fechas.instantOf('2026-08-21', '23:30', ba), DateTime.utc(2026, 8, 22, 2, 30));
      expect(Fechas.instantOf('2026-08-21', '09:15:00', 'UTC'), DateTime.utc(2026, 8, 21, 9, 15));
    });
  });

  group('parseo y strings', () {
    test('toDateStr arma yyyy-MM-dd con ceros', () {
      expect(Fechas.toDateStr(DateTime.utc(2026, 1, 5)), '2026-01-05');
      expect(Fechas.toDateStr(DateTime(999, 12, 31)), '0999-12-31');
    });

    test('parseDate da las 12:00 UTC del día (no se corre por offset)', () {
      final d = Fechas.parseDate('2026-08-21');
      expect(d, DateTime.utc(2026, 8, 21, 12));
      expect(Fechas.parseDate('2026-08-21T13:00:00Z'), DateTime.utc(2026, 8, 21, 12));
    });

    test('addDays cruza mes y año', () {
      expect(Fechas.addDays('2026-08-31', 1), '2026-09-01');
      expect(Fechas.addDays('2026-12-31', 1), '2027-01-01');
      expect(Fechas.addDays('2026-03-01', -1), '2026-02-28');
    });

    test('dayOfWeek es estilo JS: 0 = domingo', () {
      expect(Fechas.dayOfWeek('2026-08-23'), 0); // domingo
      expect(Fechas.dayOfWeek('2026-08-24'), 1); // lunes
      expect(Fechas.dayOfWeek('2026-08-22'), 6); // sábado
    });

    test('parseHm / minutesOf / hhmm', () {
      expect(Fechas.parseHm('15:45:00'), (15, 45));
      expect(Fechas.parseHm('9'), (9, 0));
      expect(Fechas.parseHm('x'), (0, 0));
      expect(Fechas.minutesOf('01:30'), 90);
      expect(Fechas.hhmm('9:5:00'), '09:05');
      expect(Fechas.hhmm('15:00:00'), '15:00');
    });
  });

  group('formato', () {
    test('capitalizar sólo la primera letra', () {
      expect(Fechas.capitalizar('miércoles, 6 de agosto'), 'Miércoles, 6 de agosto');
      expect(Fechas.capitalizar(''), '');
    });

    test('fechaLarga y fechaCorta en español', () {
      expect(Fechas.fechaLargaDeStr('2026-08-05'), 'Miércoles, 5 de agosto');
      expect(Fechas.fechaCortaDeStr('2026-08-05'), 'Mié 5 ago');
      expect(Fechas.fechaCortaDeStr('2026-08-22'), 'Sáb 22 ago');
    });

    test('mesLargo agrega el año sólo si no es el actual', () {
      final now = DateTime(2026, 8, 20);
      expect(Fechas.mesLargo(DateTime(2026, 8, 1), now: now), 'Agosto');
      expect(Fechas.mesLargo(DateTime(2027, 1, 1), now: now), 'Enero 2027');
    });

    test('moneda: pesos sin decimales con punto de miles', () {
      expect(Fechas.moneda(0), r'$0');
      expect(Fechas.moneda(999), r'$999');
      expect(Fechas.moneda(1000), r'$1.000');
      expect(Fechas.moneda(25000), r'$25.000');
      expect(Fechas.moneda(1234567), r'$1.234.567');
      expect(Fechas.moneda(12000.49), r'$12.000');
      expect(Fechas.moneda(-1500), r'-$1.500');
    });

    test('duracion y horas', () {
      expect(Fechas.duracion(45), '45 min');
      expect(Fechas.duracion(60), '1 h');
      expect(Fechas.duracion(90), '1 h 30 min');
      expect(Fechas.horas(1), '1 hora');
      expect(Fechas.horas(2), '2 horas');
    });

    test('textoRangos une las franjas con "y"', () {
      expect(
        Fechas.textoRangos([(start: '10:00:00', end: '13:00:00'), (start: '16:00', end: '19:00')]),
        '10:00 a 13:00 y 16:00 a 19:00',
      );
      expect(Fechas.textoRangos([(start: '09:00', end: '20:00')]), '09:00 a 20:00');
      expect(Fechas.textoRangos([]), '');
    });

    test('textoDias', () {
      expect(Fechas.textoDias([]), '');
      expect(Fechas.textoDias([2]), 'los martes');
      expect(Fechas.textoDias([6]), 'los sábados');
      expect(Fechas.textoDias([0]), 'los domingos');
      expect(Fechas.textoDias([2, 4]), 'martes y jueves');
      expect(Fechas.textoDias([1, 2, 3]), 'lunes, martes y miércoles');
      expect(Fechas.textoDias([1, 2, 3, 4, 5, 6]), 'casi todos los días');
      expect(Fechas.textoDias([0, 1, 2, 3, 4, 5, 6]), 'todos los días');
      expect(Fechas.textoDias([4, 2, 2]), 'martes y jueves', reason: 'dedup + orden');
    });
  });

  group('cuentaRegresiva', () {
    final start = DateTime.utc(2026, 8, 21, 18, 0); // 15:00 BA
    final end = DateTime.utc(2026, 8, 21, 18, 45);
    String cr(DateTime now) => Fechas.cuentaRegresiva(
          start: start,
          end: end,
          dateStr: '2026-08-21',
          hhmmStr: '15:00',
          tz: ba,
          now: now,
        );

    test('minutos, horas y minutos, horas exactas', () {
      expect(cr(DateTime.utc(2026, 8, 21, 17, 35)), 'en 25 min');
      expect(cr(DateTime.utc(2026, 8, 21, 15, 45)), 'en 2 h 15 min');
      expect(cr(DateTime.utc(2026, 8, 21, 15, 0)), 'en 3 h');
      expect(cr(DateTime.utc(2026, 8, 21, 17, 59, 30)), 'en menos de un minuto');
    });

    test('ya empezó / ya terminó', () {
      expect(cr(DateTime.utc(2026, 8, 21, 18, 10)), 'Es ahora');
      expect(cr(DateTime.utc(2026, 8, 21, 19, 0)), 'Ya pasó la hora');
    });

    test('más de 24 h: "Mañana HH:MM" o fecha corta', () {
      // 20/8 10:00 BA = 13:00 UTC → faltan 29 h y el turno es mañana.
      expect(cr(DateTime.utc(2026, 8, 20, 13, 0)), 'Mañana 15:00');
      expect(cr(DateTime.utc(2026, 8, 10, 13, 0)), 'Vie 21 ago · 15:00');
    });
  });

  group('etiquetaDia', () {
    test('Hoy / Mañana / fecha larga según la zona de la sucursal', () {
      final now = DateTime.utc(2026, 8, 21, 12, 0); // 09:00 BA del 21/8
      expect(Fechas.etiquetaDia('2026-08-21', tz: ba, now: now), 'Hoy');
      expect(Fechas.etiquetaDia('2026-08-22', tz: ba, now: now), 'Mañana');
      expect(Fechas.etiquetaDia('2026-08-25', tz: ba, now: now), 'Martes, 25 de agosto');
    });
  });
}
