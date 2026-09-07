import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:monaco_mobile/features/loyalty/data/loyalty_models.dart';

/// El JSON real que arma `get_client_loyalty()` (mig 197) para un cliente Oro
/// con 7 visitas, 650 pts y 120 por vencer. Si la RPC cambia de forma, este
/// test es el que tiene que romperse primero.
Map<String, dynamic> _tier(
  String code,
  String name,
  int sort,
  int min,
  int? max,
  int mult,
  String p,
  String s,
  String t,
  List<String> benefits,
) =>
    {
      'code': code,
      'name': name,
      'sort': sort,
      'min_visits': min,
      'max_visits': max,
      'multiplier_pct': mult,
      'color_primary': p,
      'color_secondary': s,
      'text_color': t,
      'benefits': benefits,
    };

/// Seed de la mig 202: el texto es SIEMPRE blanco y los extremos claros del
/// dorado y del plateado se oscurecieron para que el blanco se lea.
final _tiers = [
  _tier('bronce', 'Bronce', 1, 0, 2, 100, '#7A4A22', '#C78A4E', '#FFFFFF',
      ['Sumás puntos en cada visita', 'Acceso al catálogo de premios']),
  _tier('plata', 'Plata', 2, 3, 5, 105, '#3E444D', '#A9B1BA', '#FFFFFF',
      ['5 % más de puntos por visita', 'Premios exclusivos Plata']),
  _tier('oro', 'Oro', 3, 6, 8, 110, '#7A5A12', '#D8AE3C', '#FFFFFF',
      ['10 % más de puntos por visita', 'Premios exclusivos Oro', 'Prioridad en novedades']),
  _tier('platinum', 'Platinum', 4, 9, null, 115, '#0B0B0D', '#3A3A44', '#FFFFFF',
      ['15 % más de puntos por visita', 'Premios exclusivos Platinum', 'Beneficios en comercios asociados']),
];

Map<String, dynamic> _oro() => {
      'program': {
        'enabled': true,
        'started_at': '2026-08-30T12:00:00+00:00',
        'base_points': 100,
        'expiry_days': 120,
        'window_weeks': 12,
        'grace_days': 14,
        'welcome_bonus_points': 100,
        'reward_validity_days': 30,
      },
      'client': {
        'id': 'c1',
        'name': 'Nacho Baldovino',
        'member_since': '2024-03-14T15:20:00+00:00',
      },
      'tier': {..._tiers[2], 'reached_at': '2026-08-01T10:00:00+00:00'},
      'next_tier': {..._tiers[3], 'faltan': 2},
      'visits_in_window': 7,
      'grace': null,
      'points': {
        'balance': 650,
        'expiring_soon_points': 120,
        'expiring_soon_days': 14,
        'next_expiry_at': '2026-12-28T03:00:00+00:00',
        'next_expiry_points': 120,
        'earned_total': 1250,
        'redeemed_total': 600,
      },
      'referral': {
        'enabled': true,
        'code': 'MNC7K2PQ',
        'discount_pct': 20,
        'referred_points': 100,
        'referrer_points': 150,
        'completed_count': 3,
      },
      'tiers': _tiers,
    };

/// Lo que manda la RPC con `is_enabled = false` (el estado de Monaco hoy).
Map<String, dynamic> _apagado() => {
      'program': {'enabled': false, 'reward_validity_days': 30},
      'client': {'id': 'c1', 'name': 'Nacho', 'member_since': '2025-01-15T12:00:00+00:00'},
      'tier': null,
      'next_tier': null,
      'visits_in_window': 0,
      'grace': null,
      'points': {'balance': 40, 'expiring_soon_points': 0, 'next_expiry_at': null, 'next_expiry_points': 0},
      'referral': {'enabled': false},
      'tiers': _tiers,
    };

void main() {
  group('colorDesdeHex', () {
    const fb = Color(0xFF123456);
    test('lee #RRGGBB, RRGGBB, #RGB y #AARRGGBB', () {
      expect(colorDesdeHex('#F2CC5B', fb), const Color(0xFFF2CC5B));
      expect(colorDesdeHex('f2cc5b', fb), const Color(0xFFF2CC5B));
      expect(colorDesdeHex('#FFF', fb), const Color(0xFFFFFFFF));
      expect(colorDesdeHex('#80F2CC5B', fb), const Color(0x80F2CC5B));
    });

    test('cualquier basura cae al fallback en vez de tirar', () {
      expect(colorDesdeHex(null, fb), fb);
      expect(colorDesdeHex('', fb), fb);
      expect(colorDesdeHex('dorado', fb), fb);
      expect(colorDesdeHex('#GGGGGG', fb), fb);
      expect(colorDesdeHex('#12345', fb), fb);
      expect(colorDesdeHex(123, fb), fb);
    });
  });

  group('LoyaltyTier.fromJson', () {
    test('parsea el tier del seed', () {
      final t = LoyaltyTier.fromJson(_tiers[2]);
      expect(t.code, 'oro');
      expect(t.name, 'Oro');
      expect(t.sort, 3);
      expect(t.minVisits, 6);
      expect(t.maxVisits, 8);
      expect(t.multiplierPct, 110);
      expect(t.colorPrimary, const Color(0xFF7A5A12));
      expect(t.colorSecondary, const Color(0xFFD8AE3C));
      expect(t.textColor, const Color(0xFFFFFFFF));
      expect(t.benefits, hasLength(3));
      expect(t.textoOscuro, isFalse, reason: 'desde la mig 202 el texto es blanco');
    });

    test('platinum: sin tope y texto claro', () {
      final t = LoyaltyTier.fromJson(_tiers[3]);
      expect(t.maxVisits, isNull);
      expect(t.textoOscuro, isFalse);
      expect(t.rangoLabel, '9 o más visitas');
    });

    test('textoOscuro es la guarda por si el dashboard carga un texto oscuro', () {
      final t = LoyaltyTier.fromJson({..._tiers[2], 'text_color': '#1A1200'});
      expect(t.textoOscuro, isTrue);
    });

    test('acentoSobreOscuro: el secundario del tier, o blanco si es muy oscuro', () {
      expect(LoyaltyTier.fromJson(_tiers[2]).acentoSobreOscuro, const Color(0xFFD8AE3C));
      // Platinum #3A3A44 no se ve sobre el vidrio oscuro.
      expect(LoyaltyTier.fromJson(_tiers[3]).acentoSobreOscuro, const Color(0xFFFFFFFF));
    });

    test('rangoLabel', () {
      expect(LoyaltyTier.fromJson(_tiers[0]).rangoLabel, 'Hasta 2 visitas');
      expect(LoyaltyTier.fromJson(_tiers[1]).rangoLabel, '3 a 5 visitas');
    });

    test('colores inválidos: fallback neutro, nunca transparente', () {
      final t = LoyaltyTier.fromJson({
        'code': 'oro',
        'name': 'Oro',
        'sort': 3,
        'min_visits': 6,
        'color_primary': 'oro brillante',
        'color_secondary': null,
        'text_color': '#ZZZ',
        'benefits': null,
      });
      expect(t.colorPrimary.a, 1.0);
      expect(t.colorSecondary.a, 1.0);
      expect(t.textColor, const Color(0xFFFFFFFF));
      expect(t.benefits, isEmpty);
      expect(t.multiplierPct, 100);
    });

    test('tolera números como String y sort_order', () {
      final t = LoyaltyTier.fromJson({
        'code': 'plata',
        'sort_order': '2',
        'min_visits': '3',
        'max_visits': '5',
        'multiplier_pct': 105.0,
      });
      expect(t.sort, 2);
      expect(t.minVisits, 3);
      expect(t.maxVisits, 5);
      expect(t.multiplierPct, 105);
      expect(t.name, 'plata', reason: 'sin name cae al code');
    });
  });

  group('LoyaltySummary.fromJson — cliente Oro', () {
    final s = LoyaltySummary.fromJson(_oro());

    test('programa y cliente', () {
      expect(s.programEnabled, isTrue);
      expect(s.program.basePoints, 100);
      expect(s.program.expiryDays, 120);
      expect(s.program.windowWeeks, 12);
      expect(s.program.graceDays, 14);
      expect(s.program.welcomeBonusPoints, 100);
      expect(s.program.rewardValidityDays, 30, reason: 'mig 200');
      expect(s.clientName, 'Nacho Baldovino');
      expect(s.memberSinceYear, 2024);
    });

    test('textoGracia contempla 0 (baja en el acto), 1 y N días', () {
      expect(
        LoyaltyProgram.fromJson({'grace_days': 0}).textoGracia,
        'Si dejás de cumplir la frecuencia, bajás de categoría enseguida.',
      );
      expect(
        LoyaltyProgram.fromJson({'grace_days': 1}).textoGracia,
        'Si dejás de venir tenés 1 día de gracia para mantener tu categoría.',
      );
      expect(
        s.program.textoGracia,
        'Si dejás de venir tenés 14 días de gracia para mantener tu categoría.',
      );
    });

    test('categoría actual y siguiente', () {
      expect(s.tieneCategoria, isTrue);
      expect(s.tier!.code, 'oro');
      expect(s.nextTier!.code, 'platinum');
      expect(s.nextTierFaltan, 2);
      expect(s.visitsInWindow, 7);
      expect(s.grace, isNull);
      // 7 visitas entre el piso de Oro (6) y el de Platinum (9): 1/3.
      expect(s.progresoHaciaSiguiente, closeTo(1 / 3, 0.001));
    });

    test('puntos y referidos', () {
      expect(s.points.balance, 650);
      expect(s.points.expiringSoonPoints, 120);
      expect(s.points.expiringSoonDays, 14);
      expect(s.points.nextExpiryPoints, 120);
      expect(s.points.nextExpiryAt, isNotNull);
      expect(s.points.earnedTotal, 1250);
      expect(s.points.redeemedTotal, 600);
      expect(s.referral.enabled, isTrue);
      expect(s.referral.code, 'MNC7K2PQ');
      expect(s.referral.discountPct, 20);
      expect(s.referral.referrerPoints, 150);
      expect(s.referral.completedCount, 3);
    });

    test('los 4 tiers vienen ordenados por sort', () {
      expect(s.tiers.map((t) => t.code), ['bronce', 'plata', 'oro', 'platinum']);
      expect(s.tierPorCode('plata')!.name, 'Plata');
      expect(s.tierPorCode('diamante'), isNull);
    });

    test('platinum: sin siguiente, progreso 1', () {
      final json = _oro();
      json['tier'] = _tiers[3];
      json['next_tier'] = null;
      json['visits_in_window'] = 11;
      final p = LoyaltySummary.fromJson(json);
      expect(p.nextTier, isNull);
      expect(p.nextTierFaltan, 0);
      expect(p.progresoHaciaSiguiente, 1);
    });

    test('gracia', () {
      final json = _oro();
      json['grace'] = {
        'until': '2026-09-10T03:00:00+00:00',
        'days_left': 5,
        'tier_after_code': 'plata',
        'tier_after_name': 'Plata',
      };
      final g = LoyaltySummary.fromJson(json).grace;
      expect(g, isNotNull);
      expect(g!.daysLeft, 5);
      expect(g.tierAfterName, 'Plata');
      expect(g.until, isNotNull);
    });
  });

  group('LoyaltySummary.fromJson — programa apagado', () {
    final s = LoyaltySummary.fromJson(_apagado());

    test('sin categoría, con saldo y con los tiers para el carrusel', () {
      expect(s.programEnabled, isFalse);
      expect(s.tieneCategoria, isFalse);
      expect(s.tier, isNull);
      expect(s.nextTier, isNull);
      expect(s.grace, isNull);
      expect(s.points.balance, 40);
      expect(s.program.rewardValidityDays, 30,
          reason: 'la validez por default viaja también con el programa apagado');
      expect(s.referral.enabled, isFalse);
      expect(s.clientName, 'Nacho');
      expect(s.memberSinceYear, 2025);
      expect(s.tiers, hasLength(4));
      expect(s.progresoHaciaSiguiente, 1);
    });

    test('si el programa está apagado se ignora un tier que igual viniera', () {
      final json = _apagado();
      json['tier'] = _tiers[2];
      expect(LoyaltySummary.fromJson(json).tier, isNull);
    });
  });

  group('LoyaltySummary — bordes', () {
    test('un JSON vacío no tira', () {
      final s = LoyaltySummary.fromJson(const {});
      expect(s.programEnabled, isFalse);
      expect(s.program.rewardValidityDays, isNull, reason: 'sin dato no se inventa');
      expect(s.points.balance, 0);
      expect(s.tiers, isEmpty);
      expect(s.clientName, '');
      expect(s.memberSinceYear, isNull);
    });

    test('el error de la RPC (client_not_found) queda como apagado', () {
      final s = LoyaltySummary.fromJson({
        'program': {'enabled': false},
        'error': 'client_not_found',
      });
      expect(s.programEnabled, isFalse);
      expect(s.tier, isNull);
    });

    test('disabled() conserva nombre y saldo', () {
      final s = LoyaltySummary.disabled(clientName: 'Ana', balance: 12);
      expect(s.clientName, 'Ana');
      expect(s.points.balance, 12);
      expect(s.tieneCategoria, isFalse);
    });

    test('diasHastaVencimiento redondea hacia arriba y nunca da 0 con fecha futura', () {
      final p = LoyaltyPoints(
        nextExpiryAt: DateTime.now().add(const Duration(hours: 30)),
        nextExpiryPoints: 10,
      );
      expect(p.diasHastaVencimiento, 2);
      final hoy = LoyaltyPoints(
        nextExpiryAt: DateTime.now().add(const Duration(minutes: 5)),
        nextExpiryPoints: 10,
      );
      expect(hoy.diasHastaVencimiento, 1);
      expect(const LoyaltyPoints().diasHastaVencimiento, isNull);
    });
  });
}
