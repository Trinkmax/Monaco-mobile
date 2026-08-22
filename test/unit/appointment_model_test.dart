import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:monaco_mobile/features/appointments/data/appointment_model.dart';

/// Helpers puros del modelo de turno: parseo de la fila de Supabase,
/// instantes en la zona de la sucursal y formatos. No toca red ni providers.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_AR');
  });

  group('AppointmentStatus', () {
    test('fromString mapea los estados de la tabla appointments', () {
      expect(AppointmentStatus.fromString('scheduled'), AppointmentStatus.scheduled);
      expect(AppointmentStatus.fromString('pending_payment'), AppointmentStatus.pendingPayment);
      expect(AppointmentStatus.fromString('confirmed'), AppointmentStatus.confirmed);
      expect(AppointmentStatus.fromString('checked_in'), AppointmentStatus.checkedIn);
      expect(AppointmentStatus.fromString('in_progress'), AppointmentStatus.inProgress);
      expect(AppointmentStatus.fromString('completed'), AppointmentStatus.completed);
      expect(AppointmentStatus.fromString('cancelled'), AppointmentStatus.cancelled);
      expect(AppointmentStatus.fromString('no_show'), AppointmentStatus.noShow);
    });

    test('un estado desconocido o nulo no rompe: unknown', () {
      expect(AppointmentStatus.fromString('lo-que-sea'), AppointmentStatus.unknown);
      expect(AppointmentStatus.fromString(null), AppointmentStatus.unknown);
    });

    test('rawValue es la inversa de fromString', () {
      for (final s in AppointmentStatus.values) {
        if (s == AppointmentStatus.unknown) continue;
        expect(AppointmentStatus.fromString(s.rawValue), s);
      }
    });

    test('upcomingRaw/pastRaw cubren todos los estados reales sin solaparse', () {
      final all = {...AppointmentStatus.upcomingRaw, ...AppointmentStatus.pastRaw};
      expect(AppointmentStatus.upcomingRaw.toSet().intersection(
            AppointmentStatus.pastRaw.toSet(),
          ), isEmpty);
      for (final s in AppointmentStatus.values) {
        if (s == AppointmentStatus.unknown) continue;
        expect(all, contains(s.rawValue), reason: s.rawValue);
      }
    });

    test('isActive / isAtShop / isCancellable siguen la misma regla que el server', () {
      expect(AppointmentStatus.confirmed.isActive, isTrue);
      expect(AppointmentStatus.inProgress.isActive, isTrue);
      expect(AppointmentStatus.completed.isActive, isFalse);
      expect(AppointmentStatus.cancelled.isActive, isFalse);

      expect(AppointmentStatus.checkedIn.isAtShop, isTrue);
      expect(AppointmentStatus.inProgress.isAtShop, isTrue);
      expect(AppointmentStatus.confirmed.isAtShop, isFalse);

      expect(AppointmentStatus.scheduled.isCancellable, isTrue);
      expect(AppointmentStatus.confirmed.isCancellable, isTrue);
      expect(AppointmentStatus.checkedIn.isCancellable, isTrue);
      expect(AppointmentStatus.inProgress.isCancellable, isFalse);
      expect(AppointmentStatus.pendingPayment.isCancellable, isFalse);
      expect(AppointmentStatus.completed.isCancellable, isFalse);
    });

    test('las etiquetas están en español', () {
      expect(AppointmentStatus.confirmed.label, 'Confirmado');
      expect(AppointmentStatus.scheduled.label, 'Confirmado');
      expect(AppointmentStatus.pendingPayment.label, 'Pendiente de pago');
      expect(AppointmentStatus.checkedIn.label, 'Ya llegaste');
      expect(AppointmentStatus.inProgress.label, 'En atención');
      expect(AppointmentStatus.completed.label, 'Completado');
      expect(AppointmentStatus.cancelled.label, 'Cancelado');
      expect(AppointmentStatus.noShow.label, 'Ausente');
    });
  });

  group('AppointmentService.fromJson', () {
    test('lee el snapshot de appointment_services con join services', () {
      final s = AppointmentService.fromJson({
        'service_id': 'svc-1',
        'price_snapshot': 12000,
        'duration_snapshot': 45,
        'services': {'id': 'svc-1', 'name': 'Corte', 'price': 13000, 'duration_minutes': 30},
      });
      expect(s.id, 'svc-1');
      expect(s.name, 'Corte');
      // El snapshot manda sobre el precio/duración actuales del servicio.
      expect(s.price, 12000);
      expect(s.durationMinutes, 45);
    });

    test('sin snapshot cae en los valores del servicio', () {
      final s = AppointmentService.fromJson({
        'service_id': 'svc-2',
        'services': {'name': 'Barba', 'price': 8000, 'duration_minutes': 20},
      });
      expect(s.price, 8000);
      expect(s.durationMinutes, 20);
    });

    test('forma plana (fila de services)', () {
      final s = AppointmentService.fromJson({
        'id': 'svc-3',
        'name': 'Color',
        'price': 25000,
        'duration_minutes': 90,
      });
      expect(s.id, 'svc-3');
      expect(s.name, 'Color');
      expect(s.price, 25000);
      expect(s.durationMinutes, 90);
    });
  });

  group('Appointment.fromJson', () {
    final row = <String, dynamic>{
      'id': 'apt-1',
      'organization_id': 'org-1',
      'branch_id': 'br-1',
      'client_id': 'cli-1',
      'barber_id': 'stf-1',
      'appointment_date': '2026-08-21',
      'start_time': '15:00:00',
      'end_time': '15:45:00',
      'duration_minutes': 45,
      'status': 'confirmed',
      'source': 'public',
      'cancellation_token': 'tok',
      'branch': {
        'name': 'Rondeau',
        'slug': 'rondeau',
        'address': 'Rondeau 123',
        'phone': '3434000000',
        'timezone': 'America/Argentina/Buenos_Aires',
        'latitude': -31.73,
        'longitude': -60.52,
      },
      'barber': {'full_name': 'Fabrizio', 'avatar_url': 'https://x/y.png'},
      'appointment_services': [
        {
          'service_id': 'svc-2',
          'sort_order': 2,
          'price_snapshot': 8000,
          'services': {'name': 'Barba'},
        },
        {
          'service_id': 'svc-1',
          'sort_order': 1,
          'price_snapshot': 12000,
          'services': {'name': 'Corte'},
        },
      ],
    };

    test('hidrata sucursal, barbero y servicios (ordenados por sort_order)', () {
      final a = Appointment.fromJson(row);
      expect(a.id, 'apt-1');
      expect(a.branchName, 'Rondeau');
      expect(a.branchSlug, 'rondeau');
      expect(a.branchAddress, 'Rondeau 123');
      expect(a.branchPhone, '3434000000');
      expect(a.branchTimezone, 'America/Argentina/Buenos_Aires');
      expect(a.branchLatitude, closeTo(-31.73, 1e-9));
      expect(a.barberName, 'Fabrizio');
      expect(a.barberAvatarUrl, 'https://x/y.png');
      expect(a.status, AppointmentStatus.confirmed);
      expect(a.services.map((s) => s.name), ['Corte', 'Barba']);
      expect(a.durationMinutes, 45);
      expect(a.cancellationToken, 'tok');
    });

    test('la hora se normaliza a HH:MM y la fecha queda como string de pared', () {
      final a = Appointment.fromJson(row);
      expect(a.dateStr, '2026-08-21');
      expect(a.startTime, '15:00');
      expect(a.endTime, '15:45');
      expect(a.horaLabel, '15:00');
      expect(a.dayOfWeek, 5, reason: '21/8/2026 es viernes (JS: 5)');
    });

    test('una appointment_date con hora (timestamptz) se recorta al día', () {
      final a = Appointment.fromJson({...row, 'appointment_date': '2026-08-21T00:00:00+00:00'});
      expect(a.dateStr, '2026-08-21');
    });

    test('startInstant/endInstant son el instante REAL en Buenos Aires (UTC-3)', () {
      final a = Appointment.fromJson(row);
      expect(a.startInstant, DateTime.utc(2026, 8, 21, 18, 0));
      expect(a.endInstant, DateTime.utc(2026, 8, 21, 18, 45));
    });

    test('sin end_time útil, endInstant usa la duración', () {
      final a = Appointment.fromJson({...row, 'end_time': '15:00:00', 'duration_minutes': 30});
      expect(a.endInstant, DateTime.utc(2026, 8, 21, 18, 30));
    });

    test('el servicio principal viene en service:service_id(...) si no hay lista', () {
      final a = Appointment.fromJson({
        ...row,
        'appointment_services': null,
        'service': {'id': 'svc-9', 'name': 'Corte clásico', 'price': 9000},
      });
      expect(a.services.single.id, 'svc-9');
      expect(a.servicesLabel, 'Corte clásico');
      expect(a.totalPrice, 9000);
    });

    test('servicesLabel une con " + " y totalPrice suma los snapshots', () {
      final a = Appointment.fromJson(row);
      expect(a.servicesLabel, 'Corte + Barba');
      expect(a.totalPrice, 20000);
    });

    test('sin servicios: label de respaldo y total nulo', () {
      final a = Appointment.fromJson({
        ...row,
        'appointment_services': <Map<String, dynamic>>[],
        'service_id': null,
      });
      expect(a.servicesLabel, 'Servicio');
      expect(a.totalPrice, isNull);
    });

    test('fechaLarga / fechaCorta en español y capitalizadas', () {
      final a = Appointment.fromJson(row);
      expect(a.fechaLarga, 'Viernes, 21 de agosto');
      expect(a.fechaCorta, 'Vie 21 ago');
    });

    test('etiquetaDia depende del "hoy" de la sucursal, no del teléfono', () {
      final a = Appointment.fromJson(row);
      // 21/8 00:30 en Buenos Aires = 03:30 UTC del 21/8 → "Hoy".
      expect(a.etiquetaDia(now: DateTime.utc(2026, 8, 21, 3, 30)), 'Hoy');
      // 20/8 23:00 en Buenos Aires = 02:00 UTC del 21/8 → todavía es 20/8 allá → "Mañana".
      expect(a.etiquetaDia(now: DateTime.utc(2026, 8, 21, 2, 0)), 'Mañana');
      expect(a.etiquetaDia(now: DateTime.utc(2026, 8, 10, 12, 0)), 'Viernes, 21 de agosto');
    });

    group('canCancel', () {
      test('confirmado y con margen → se puede', () {
        final a = Appointment.fromJson(row);
        // 15:00 BA = 18:00 UTC; a las 15:00 UTC faltan 3 h.
        expect(a.canCancel(minHours: 2, now: DateTime.utc(2026, 8, 21, 15, 0)), isTrue);
      });

      test('confirmado pero dentro de la ventana mínima → no', () {
        final a = Appointment.fromJson(row);
        // faltan 90 min, la ventana es de 2 h.
        expect(a.canCancel(minHours: 2, now: DateTime.utc(2026, 8, 21, 16, 30)), isFalse);
      });

      test('justo en el límite de la ventana → se puede (>=)', () {
        final a = Appointment.fromJson(row);
        expect(a.canCancel(minHours: 2, now: DateTime.utc(2026, 8, 21, 16, 0)), isTrue);
      });

      test('estados no cancelables nunca se pueden, aunque falte mucho', () {
        for (final st in ['in_progress', 'completed', 'cancelled', 'no_show', 'pending_payment']) {
          final a = Appointment.fromJson({...row, 'status': st});
          expect(a.canCancel(minHours: 2, now: DateTime.utc(2026, 8, 1)), isFalse, reason: st);
        }
      });
    });

    group('isLive', () {
      test('confirmado y no terminó → vive', () {
        final a = Appointment.fromJson(row);
        expect(a.isLive(now: DateTime.utc(2026, 8, 21, 18, 30)), isTrue);
      });

      test('confirmado pero ya terminó → no vive', () {
        final a = Appointment.fromJson(row);
        expect(a.isLive(now: DateTime.utc(2026, 8, 21, 19, 0)), isFalse);
      });

      test('en el local (checked_in) vive aunque haya pasado la hora', () {
        final a = Appointment.fromJson({...row, 'status': 'checked_in'});
        expect(a.isLive(now: DateTime.utc(2026, 8, 21, 20, 0)), isTrue);
      });

      test('cancelado no vive nunca', () {
        final a = Appointment.fromJson({...row, 'status': 'cancelled'});
        expect(a.isLive(now: DateTime.utc(2026, 8, 1)), isFalse);
      });
    });

    test('mapsUrl prefiere coordenadas y cae a la dirección', () {
      final a = Appointment.fromJson(row);
      expect(a.canOpenMaps, isTrue);
      expect(a.mapsUrl, 'https://www.google.com/maps/search/?api=1&query=-31.73,-60.52');

      final sinCoords = Appointment.fromJson({
        ...row,
        'branch': {'name': 'Rondeau', 'address': 'Rondeau 123'},
      });
      expect(sinCoords.mapsUrl, contains('query=Rondeau%20123'));

      final sinNada = Appointment.fromJson({...row, 'branch': {'name': 'Rondeau'}});
      expect(sinNada.canOpenMaps, isFalse);
      expect(sinNada.mapsUrl, isNull);
    });

    test('copyWith(status) cambia sólo el estado', () {
      final a = Appointment.fromJson(row);
      final b = a.copyWith(status: AppointmentStatus.cancelled);
      expect(b.status, AppointmentStatus.cancelled);
      expect(b.id, a.id);
      expect(b.services.length, a.services.length);
      expect(b.startInstant, a.startInstant);
    });
  });
}
