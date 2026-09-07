import 'package:flutter_test/flutter_test.dart';
import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/features/loyalty/data/referido.dart';
import 'package:monaco_mobile/features/rewards/data/beneficio_canjeado.dart';

/// Los helpers que comparten la tira de Premios, "Mis premios" y el QR sobre
/// una fila de `get_client_wallet()` (mig 197).
void main() {
  group('EstadoBeneficio', () {
    test('mapea los cuatro status y un desconocido NO es disponible', () {
      expect(EstadoBeneficio.porSlug('available'), EstadoBeneficio.disponible);
      expect(EstadoBeneficio.porSlug('redeemed'), EstadoBeneficio.utilizado);
      expect(EstadoBeneficio.porSlug('expired'), EstadoBeneficio.vencido);
      expect(EstadoBeneficio.porSlug('cancelled'), EstadoBeneficio.cancelado);
      expect(EstadoBeneficio.porSlug('lo_que_sea'), isNot(EstadoBeneficio.disponible));
      expect(EstadoBeneficio.porSlug(null), isNot(EstadoBeneficio.disponible));
    });

    test('etiquetas y colores', () {
      expect(EstadoBeneficio.disponible.label, 'Disponible');
      expect(EstadoBeneficio.utilizado.label, 'Utilizado');
      expect(EstadoBeneficio.vencido.label, 'Vencido');
      expect(EstadoBeneficio.cancelado.label, 'Cancelado');
      expect(EstadoBeneficio.disponible.color, MonacoColors.monacoGreen);
      expect(EstadoBeneficio.vencido.color, MonacoColors.destructive);
    });
  });

  group('BeneficioCanjeado.etiqueta — por kind', () {
    test('descuento con porcentaje, con y sin servicio', () {
      expect(
        BeneficioCanjeado.etiqueta({'kind': 'descuento', 'discount_pct': 20}),
        '20 % de descuento',
      );
      expect(
        BeneficioCanjeado.etiqueta({
          'kind': 'descuento',
          'discount_pct': 20,
          'service_name': 'Corte clásico',
        }),
        '20 % de descuento en Corte clásico',
      );
    });

    test('descuento 100 o is_free_service → servicio gratis', () {
      expect(
        BeneficioCanjeado.etiqueta({'kind': 'descuento', 'discount_pct': 100}),
        'Servicio gratis',
      );
      expect(
        BeneficioCanjeado.etiqueta({
          'kind': 'descuento',
          'is_free_service': true,
          'service_name': 'Barba',
        }),
        'Gratis: Barba',
      );
    });

    test('merch y especial', () {
      expect(BeneficioCanjeado.etiqueta({'kind': 'merch'}), 'Retirá en la barbería');
      expect(BeneficioCanjeado.etiqueta({'kind': 'especial'}), 'Beneficio especial');
      expect(BeneficioCanjeado.esMerch({'kind': 'merch'}), isTrue);
      expect(BeneficioCanjeado.esMerch({'kind': 'descuento'}), isFalse);
    });

    test('fila vieja sin kind: manda lo que hace y reward_type desempata', () {
      expect(BeneficioCanjeado.etiqueta({'is_free_service': true}), 'Servicio gratis');
      expect(BeneficioCanjeado.etiqueta({'discount_pct': 15}), '15 % de descuento');
      expect(
        BeneficioCanjeado.etiqueta({'reward_type': 'spin_prize'}),
        'Premio de la ruleta',
      );
      expect(BeneficioCanjeado.etiqueta({}), 'Premio');
    });
  });

  group('BeneficioCanjeado.cuentaRegresiva', () {
    final ahora = DateTime(2026, 8, 30, 12);

    test('verde si faltan más de 7 días, ámbar si es esta semana', () {
      final lejos = BeneficioCanjeado.cuentaRegresiva(
        ahora.add(const Duration(days: 12)),
        ahora: ahora,
      )!;
      expect(lejos.label, 'Vence en 12 días');
      expect(lejos.color, MonacoColors.monacoGreen);

      final cerca = BeneficioCanjeado.cuentaRegresiva(
        ahora.add(const Duration(days: 3)),
        ahora: ahora,
      )!;
      expect(cerca.label, 'Vence en 3 días');
      expect(cerca.color, MonacoColors.warning);
    });

    test('redondea para arriba: mañana a la mañana es "Vence mañana"', () {
      final r = BeneficioCanjeado.cuentaRegresiva(
        DateTime(2026, 8, 31, 9),
        ahora: DateTime(2026, 8, 30, 23),
      )!;
      expect(r.label, 'Vence mañana');
    });

    test('hoy y vencido', () {
      expect(
        BeneficioCanjeado.cuentaRegresiva(ahora, ahora: ahora)!.label,
        'Vence hoy',
      );
      final v = BeneficioCanjeado.cuentaRegresiva(
        ahora.subtract(const Duration(hours: 1)),
        ahora: ahora,
      )!;
      expect(v.label, 'Vencido');
      expect(v.color, MonacoColors.destructive);
      expect(BeneficioCanjeado.cuentaRegresiva(null), isNull);
    });
  });

  group('BeneficioCanjeado — campos', () {
    test('points_spent 0 no se muestra; cancel_reason en blanco es null', () {
      expect(BeneficioCanjeado.puntosGastados({'points_spent': 0}), isNull);
      expect(BeneficioCanjeado.puntosGastados({'points_spent': 500}), 500);
      expect(BeneficioCanjeado.motivoCancelacion({'cancel_reason': '  '}), isNull);
      expect(
        BeneficioCanjeado.motivoCancelacion({'cancel_reason': 'Sin stock'}),
        'Sin stock',
      );
    });

    test('available con expires_at pasado se lee como vencido (cron perezoso)',
        () {
      final ahora = DateTime(2026, 8, 30, 15);
      final vencida = <String, dynamic>{
        'status': 'available',
        'expires_at':
            ahora.subtract(const Duration(hours: 1)).toIso8601String(),
      };
      expect(
        BeneficioCanjeado.estadoDe(vencida, ahora: ahora),
        EstadoBeneficio.vencido,
      );
      final viva = <String, dynamic>{
        'status': 'available',
        'expires_at': ahora.add(const Duration(hours: 1)).toIso8601String(),
      };
      expect(
        BeneficioCanjeado.estadoDe(viva, ahora: ahora),
        EstadoBeneficio.disponible,
      );
      // Sin fecha no se inventa un vencimiento.
      expect(
        BeneficioCanjeado.estadoDe(<String, dynamic>{'status': 'available'},
            ahora: ahora),
        EstadoBeneficio.disponible,
      );
      // Un status terminal no se re-deriva.
      expect(
        BeneficioCanjeado.estadoDe(<String, dynamic>{
          'status': 'redeemed',
          'expires_at':
              ahora.subtract(const Duration(hours: 1)).toIso8601String(),
        }, ahora: ahora),
        EstadoBeneficio.utilizado,
      );
    });
  });

  group('Referido.fromJson', () {
    test('lee la fila de get_client_referrals', () {
      final r = Referido.fromJson({
        'id': 'x',
        'status': 'completed',
        'created_at': '2026-08-01T12:00:00Z',
        'completed_at': '2026-08-10T12:00:00Z',
        'points': 150,
        'friend_first_name': 'Juan',
        'i_am_referrer': true,
      });
      expect(r.completada, isTrue);
      expect(r.pendiente, isFalse);
      expect(r.points, 150);
      expect(r.friendFirstName, 'Juan');
      expect(r.iAmReferrer, isTrue);
      expect(r.completedAt, isNotNull);
    });

    test('tolera nulls y trata rejected como cancelada', () {
      final r = Referido.fromJson({'status': 'rejected'});
      expect(r.cancelada, isTrue);
      expect(r.friendFirstName, isNull);
      expect(r.points, 0);
    });
  });
}
