import 'package:flutter_test/flutter_test.dart';

import 'package:monaco_mobile/features/senas/data/sena_models.dart';

void main() {
  group('EstadoSena', () {
    test('mapea los nueve estados del contrato', () {
      expect(EstadoSena.desde('iniciada'), EstadoSena.iniciada);
      expect(EstadoSena.desde('pagada'), EstadoSena.pagada);
      expect(EstadoSena.desde('consumida'), EstadoSena.consumida);
      expect(EstadoSena.desde('perdida'), EstadoSena.perdida);
      expect(EstadoSena.desde('devuelta'), EstadoSena.devuelta);
      expect(EstadoSena.desde('sin_cupo'), EstadoSena.sinCupo);
      expect(EstadoSena.desde('rechazada'), EstadoSena.rechazada);
      expect(EstadoSena.desde('expirada'), EstadoSena.expirada);
      expect(EstadoSena.desde('cancelada'), EstadoSena.cancelada);
    });

    test('un estado que no conocemos NUNCA se lee como turno confirmado', () {
      // Si el server suma un estado nuevo, la peor reacción posible de una app
      // vieja es dar el turno por bueno y mandar al cliente a la barbería.
      final raro = EstadoSena.desde('en_disputa');
      expect(raro, EstadoSena.desconocida);
      expect(raro.turnoConfirmado, isFalse);
      // Tampoco es terminal: se sigue preguntando, que es lo seguro.
      expect(raro.terminal, isFalse);
      expect(EstadoSena.desde(null), EstadoSena.desconocida);
    });

    test('turnoConfirmado son los tres estados en los que el turno existe', () {
      for (final e in EstadoSena.values) {
        final esperado = e == EstadoSena.pagada ||
            e == EstadoSena.consumida ||
            e == EstadoSena.perdida;
        expect(e.turnoConfirmado, esperado, reason: e.name);
      }
    });

    test('sólo `iniciada` sigue en curso', () {
      expect(EstadoSena.iniciada.terminal, isFalse);
      expect(EstadoSena.pagada.terminal, isTrue);
      expect(EstadoSena.rechazada.terminal, isTrue);
      expect(EstadoSena.expirada.terminal, isTrue);
    });
  });

  group('SenaIntencion', () {
    final json = {
      'ok': true,
      'deposit_id': 'dep-1',
      'init_point': 'https://www.mercadopago.com.ar/checkout/v1/redirect?pref_id=x',
      'amount': 8000,
      'service_total': 16000,
      'resto': 8000,
      'expires_at': '2026-09-04T18:00:00.000-03:00',
      'politica': {
        'titulo': 'Seña \$8.000 ARS',
        'detalle': 'Es el 50% de Corte + Barba.',
        'cancelacion': 'Cancelando con más de 2 horas te devolvemos la seña.',
        'reserva': 'El horario se confirma cuando se acredita el pago.',
        'arrepentimiento': 'Tenés 10 días para arrepentirte.',
      },
    };

    test('lee montos, link y política', () {
      final i = SenaIntencion.fromJson(json);
      expect(i.depositId, 'dep-1');
      expect(i.monto, 8000);
      expect(i.total, 16000);
      expect(i.resto, 8000);
      expect(i.venceEn?.isUtc, isTrue);
      expect(i.politica.titulo, 'Seña \$8.000 ARS');
      expect(i.usable, isTrue);
    });

    test('tolera montos que llegan como string', () {
      final i = SenaIntencion.fromJson({...json, 'amount': '8000.00'});
      expect(i.monto, 8000);
    });

    test('un 200 sin link de pago NO es usable', () {
      // Sin este guard la app abriría una URL vacía y dejaría al cliente
      // esperando para siempre un pago que nunca se pudo hacer.
      expect(SenaIntencion.fromJson({...json, 'init_point': ''}).usable, isFalse);
      expect(SenaIntencion.fromJson({...json, 'init_point': 'monaco://x'}).usable, isFalse);
      expect(SenaIntencion.fromJson({...json, 'deposit_id': null}).usable, isFalse);
    });

    test('los párrafos de la política salen en orden y sin vacíos', () {
      final p = SenaIntencion.fromJson(json).politica;
      expect(p.parrafos, [
        'Es el 50% de Corte + Barba.',
        'El horario se confirma cuando se acredita el pago.',
        'Cancelando con más de 2 horas te devolvemos la seña.',
        'Tenés 10 días para arrepentirte.',
      ]);

      final sinArrepentimiento = PoliticaSena.fromJson({
        'titulo': 'x',
        'detalle': 'a',
        'cancelacion': '  ',
        'reserva': 'b',
        'arrepentimiento': null,
      });
      expect(sinArrepentimiento.parrafos, ['a', 'b']);
    });
  });

  group('SenaEstado', () {
    test('lee el turno confirmado', () {
      final e = SenaEstado.fromJson({
        'ok': true,
        'deposit_id': 'dep-1',
        'status': 'pagada',
        'amount': 8000,
        'resto': 8000,
        'appointment': {
          'id': 'ap-1',
          'appointment_date': '2026-09-04',
          'start_time': '18:30:00',
          'barber_name': 'Fabri',
          'branch_name': 'Paraná',
          'service_names': 'Corte + Barba',
        },
        'mensaje': null,
        'seguir_esperando': false,
      });
      expect(e.estado, EstadoSena.pagada);
      expect(e.turno?.id, 'ap-1');
      expect(e.turno?.barbero, 'Fabri');
      expect(e.seguirEsperando, isFalse);
    });

    test('sin `seguir_esperando` la bandera se deriva del estado', () {
      // Un `false` inventado deja al cliente mirando "confirmando" para
      // siempre; un `true` inventado sobre un estado terminal es sólo una
      // consulta de más.
      final enCurso = SenaEstado.fromJson({'status': 'iniciada'});
      expect(enCurso.seguirEsperando, isTrue);
      final cerrada = SenaEstado.fromJson({'status': 'rechazada'});
      expect(cerrada.seguirEsperando, isFalse);
    });

    test('un status desconocido sigue esperando y no confirma nada', () {
      final e = SenaEstado.fromJson({'status': 'no_existe'});
      expect(e.estado, EstadoSena.desconocida);
      expect(e.seguirEsperando, isTrue);
      expect(e.estado.turnoConfirmado, isFalse);
      expect(e.turno, isNull);
    });
  });

  group('ResultadoSena', () {
    test('SLOT_TAKEN pide recargar la grilla; MP_ERROR no', () {
      expect(const SenaFallo('SLOT_TAKEN', 'x').grillaVieja, isTrue);
      expect(const SenaFallo('TOO_LATE', 'x').grillaVieja, isTrue);
      expect(const SenaFallo('MP_ERROR', 'x').grillaVieja, isFalse);
    });
  });
}
