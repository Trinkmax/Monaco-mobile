import 'package:flutter_test/flutter_test.dart';
import 'package:monaco_mobile/features/appointments/data/appointment_model.dart';
import 'package:monaco_mobile/features/senas/data/sena_models.dart';

/// La seña embebida en el turno (`deposit:booking_deposits!...`). Lo que se
/// mide acá es que el turno sepa si hay plata en juego **antes** de ofrecer
/// cancelarlo: el copy del diálogo depende sólo de esto.
void main() {
  Map<String, dynamic> fila({
    String id = 'dep-1',
    String status = 'pagada',
    num amount = 600,
    String? createdAt,
    String? refundedAt,
  }) => {
        'id': id,
        'status': status,
        'amount': amount,
        'refunded_amount': refundedAt == null ? 0 : amount,
        'paid_at': '2026-09-09T14:27:49+00:00',
        'refunded_at': refundedAt,
        'created_at': createdAt ?? '2026-09-09T14:20:00+00:00',
      };

  group('AppointmentDeposit.deLista', () {
    test('sin seña: null (el caso normal de casi todos los turnos)', () {
      expect(AppointmentDeposit.deLista(null), isNull);
      expect(AppointmentDeposit.deLista(const []), isNull);
      expect(AppointmentDeposit.deLista('lo-que-sea'), isNull);
    });

    test('una fila pagada: la plata está del lado del local', () {
      final d = AppointmentDeposit.deLista([fila()])!;
      expect(d.estado, EstadoSena.pagada);
      expect(d.amount, 600);
      expect(d.plataDelLocal, isTrue);
      expect(d.devuelta, isFalse);
    });

    test('devuelta: hay seña pero ya no hay nada que explicar', () {
      final d = AppointmentDeposit.deLista([
        fila(status: 'devuelta', refundedAt: '2026-09-09T14:28:19+00:00'),
      ])!;
      expect(d.plataDelLocal, isFalse);
      expect(d.devuelta, isTrue);
    });

    test('perdida cuenta como plata del local (cancelación tardía)', () {
      final d = AppointmentDeposit.deLista([fila(status: 'perdida')])!;
      expect(d.plataDelLocal, isTrue);
    });

    test('manda la que tiene la plata, no la más nueva', () {
      // El cliente abandonó un checkout DESPUÉS de haber pagado: la fila más
      // nueva es la cancelada, y la que importa es la vieja que se cobró.
      final d = AppointmentDeposit.deLista([
        fila(id: 'nueva', status: 'cancelada', createdAt: '2026-09-09T18:00:00+00:00'),
        fila(id: 'vieja', status: 'pagada', createdAt: '2026-09-09T14:20:00+00:00'),
      ])!;
      expect(d.id, 'vieja');
      expect(d.plataDelLocal, isTrue);
    });

    test('sin ninguna pagada, gana la más nueva', () {
      final d = AppointmentDeposit.deLista([
        fila(id: 'vieja', status: 'expirada', createdAt: '2026-09-01T10:00:00+00:00'),
        fila(id: 'nueva', status: 'cancelada', createdAt: '2026-09-09T18:00:00+00:00'),
      ])!;
      expect(d.id, 'nueva');
      expect(d.plataDelLocal, isFalse);
    });

    test('un status que esta versión no conoce NO se lee como pagada', () {
      final d = AppointmentDeposit.deLista([fila(status: 'algo_nuevo')])!;
      expect(d.estado, EstadoSena.desconocida);
      expect(d.plataDelLocal, isFalse);
    });
  });

  group('Appointment.fromJson', () {
    Map<String, dynamic> turno(Object? deposit) => {
          'id': 'apt-1',
          'organization_id': 'org',
          'branch_id': 'br',
          'client_id': 'cli',
          'appointment_date': '2026-09-12',
          'start_time': '16:00:00',
          'end_time': '16:15:00',
          'duration_minutes': 15,
          'status': 'confirmed',
          'source': 'app',
          'deposit': ?deposit,
        };

    test('lee la seña embebida', () {
      final a = Appointment.fromJson(turno([fila()]));
      expect(a.deposit, isNotNull);
      expect(a.deposit!.amount, 600);
    });

    test('sin el embed (o con lista vacía) el turno sigue siendo válido', () {
      expect(Appointment.fromJson(turno(null)).deposit, isNull);
      expect(Appointment.fromJson(turno(const [])).deposit, isNull);
    });

    test('copyWith conserva la seña', () {
      final a = Appointment.fromJson(turno([fila()]));
      expect(a.copyWith(status: AppointmentStatus.cancelled).deposit?.id, 'dep-1');
    });
  });
}
