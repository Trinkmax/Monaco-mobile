import 'dart:ui';

/// Modelos del programa de fidelización. Son el espejo **exacto** del JSON que
/// devuelve la RPC `get_client_loyalty()` (migración 197): la app no decide
/// umbrales, multiplicadores ni colores — los lee de acá y los pinta.
///
/// Todo el parseo es tolerante a nulls y a tipos flojos (`num` en vez de
/// `int`, `String` vacío en vez de null): un campo que falte deja el default y
/// nunca tira. Con el programa apagado (`program.enabled = false`) la RPC
/// manda `tier: null`, `grace: null` y `referral.enabled = false`, y la app
/// tiene que verse bien igual.

int _int(Object? v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim()) ?? fallback;
  return fallback;
}

int? _intOrNull(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

bool _bool(Object? v, [bool fallback = false]) {
  if (v is bool) return v;
  if (v is String) {
    final s = v.trim().toLowerCase();
    if (s == 'true' || s == 't' || s == '1') return true;
    if (s == 'false' || s == 'f' || s == '0') return false;
  }
  if (v is num) return v != 0;
  return fallback;
}

String? _str(Object? v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

DateTime? _date(Object? v) {
  final s = _str(v);
  if (s == null) return null;
  return DateTime.tryParse(s)?.toLocal();
}

Map<String, dynamic> _map(Object? v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return const {};
}

/// `'#RRGGBB'` (o `'#RGB'`, `'RRGGBB'`, `'#AARRGGBB'`) → [Color]. Cualquier cosa
/// que no se pueda leer devuelve [fallback]: un color mal cargado en el
/// dashboard no puede dejar la tarjeta transparente ni tirar la pantalla.
Color colorDesdeHex(Object? raw, Color fallback) {
  // Sólo texto: un número suelto ("123") se leería como "#112233" y pintaría
  // un color que nadie eligió.
  if (raw is! String) return fallback;
  final s = _str(raw);
  if (s == null) return fallback;
  var hex = s.startsWith('#') ? s.substring(1) : s;
  if (hex.startsWith('0x') || hex.startsWith('0X')) hex = hex.substring(2);
  if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex)) return fallback;
  if (hex.length == 3) {
    hex = hex.split('').map((c) => '$c$c').join();
  }
  if (hex.length == 6) hex = 'FF$hex';
  if (hex.length != 8) return fallback;
  final value = int.tryParse(hex, radix: 16);
  return value == null ? fallback : Color(value);
}

/// Una categoría del programa (`loyalty_tiers`).
class LoyaltyTier {
  final String code;
  final String name;
  final int sort;
  final int minVisits;

  /// `null` = sin tope (la categoría más alta).
  final int? maxVisits;
  final int multiplierPct;
  final Color colorPrimary;
  final Color colorSecondary;
  final Color textColor;
  final List<String> benefits;

  const LoyaltyTier({
    required this.code,
    required this.name,
    required this.sort,
    required this.minVisits,
    this.maxVisits,
    required this.multiplierPct,
    required this.colorPrimary,
    required this.colorSecondary,
    required this.textColor,
    this.benefits = const [],
  });

  /// Colores de emergencia si el server manda algo ilegible. Son los del seed
  /// de "plata" a propósito: neutros, así una tarjeta con datos rotos se ve
  /// gris y no de una categoría que el cliente no tiene.
  static const Color _fallbackPrimary = Color(0xFF3E444D);
  static const Color _fallbackSecondary = Color(0xFFC9CFD6);
  static const Color _fallbackText = Color(0xFFFFFFFF);

  factory LoyaltyTier.fromJson(Map<String, dynamic> j) {
    final rawBenefits = j['benefits'];
    final benefits = rawBenefits is List
        ? rawBenefits.map((b) => b?.toString().trim() ?? '').where((b) => b.isNotEmpty).toList()
        : const <String>[];
    return LoyaltyTier(
      code: _str(j['code']) ?? '',
      name: _str(j['name']) ?? (_str(j['code']) ?? ''),
      sort: _int(j['sort'] ?? j['sort_order']),
      minVisits: _int(j['min_visits']),
      maxVisits: _intOrNull(j['max_visits']),
      multiplierPct: _int(j['multiplier_pct'], 100),
      colorPrimary: colorDesdeHex(j['color_primary'], _fallbackPrimary),
      colorSecondary: colorDesdeHex(j['color_secondary'], _fallbackSecondary),
      textColor: colorDesdeHex(j['text_color'], _fallbackText),
      benefits: benefits,
    );
  }

  /// Desde la migración 202 el texto de las tarjetas es **siempre blanco**
  /// (decisión del dueño: las letras nunca van negras; el extremo claro del
  /// dorado y del plateado se oscureció para que el blanco se lea). Esto queda
  /// como guarda por si el dashboard vuelve a cargar un `text_color` oscuro:
  /// ahí el wordmark blanco hay que teñirlo para que no desaparezca.
  bool get textoOscuro => textColor.computeLuminance() < 0.5;

  /// Color con el que se representa la categoría **fuera** de la tarjeta,
  /// sobre el vidrio oscuro de la app (ícono de "Mi categoría" en Perfil, la
  /// línea "Cliente Oro" de Premios): el secundario del tier, o blanco si es
  /// tan oscuro (Platinum `#3A3A44`) que no se distinguiría del fondo.
  Color get acentoSobreOscuro =>
      colorSecondary.computeLuminance() > 0.08 ? colorSecondary : _fallbackText;

  /// "3 a 5 visitas" / "9 o más visitas" / "Hasta 2 visitas".
  String get rangoLabel {
    final max = maxVisits;
    if (max == null) {
      return minVisits <= 0 ? 'Todas las visitas' : '$minVisits o más visitas';
    }
    if (minVisits <= 0) return 'Hasta $max visitas';
    if (minVisits == max) return '$max visitas';
    return '$minVisits a $max visitas';
  }

  LoyaltyTier copyWith({
    Color? colorPrimary,
    Color? colorSecondary,
    Color? textColor,
  }) {
    return LoyaltyTier(
      code: code,
      name: name,
      sort: sort,
      minVisits: minVisits,
      maxVisits: maxVisits,
      multiplierPct: multiplierPct,
      colorPrimary: colorPrimary ?? this.colorPrimary,
      colorSecondary: colorSecondary ?? this.colorSecondary,
      textColor: textColor ?? this.textColor,
      benefits: benefits,
    );
  }
}

/// Período de gracia antes de bajar de categoría.
class LoyaltyGrace {
  final DateTime? until;
  final int daysLeft;
  final String? tierAfterCode;
  final String? tierAfterName;

  const LoyaltyGrace({
    this.until,
    required this.daysLeft,
    this.tierAfterCode,
    this.tierAfterName,
  });

  factory LoyaltyGrace.fromJson(Map<String, dynamic> j) => LoyaltyGrace(
        until: _date(j['until']),
        daysLeft: _int(j['days_left']),
        tierAfterCode: _str(j['tier_after_code']),
        tierAfterName: _str(j['tier_after_name']),
      );
}

/// Saldo y vencimientos (`points` del JSON).
class LoyaltyPoints {
  final int balance;
  final int expiringSoonPoints;
  final int expiringSoonDays;
  final DateTime? nextExpiryAt;
  final int nextExpiryPoints;
  final int earnedTotal;
  final int redeemedTotal;

  const LoyaltyPoints({
    this.balance = 0,
    this.expiringSoonPoints = 0,
    this.expiringSoonDays = 0,
    this.nextExpiryAt,
    this.nextExpiryPoints = 0,
    this.earnedTotal = 0,
    this.redeemedTotal = 0,
  });

  factory LoyaltyPoints.fromJson(Map<String, dynamic> j) => LoyaltyPoints(
        balance: _int(j['balance']),
        expiringSoonPoints: _int(j['expiring_soon_points']),
        expiringSoonDays: _int(j['expiring_soon_days']),
        nextExpiryAt: _date(j['next_expiry_at']),
        nextExpiryPoints: _int(j['next_expiry_points']),
        earnedTotal: _int(j['earned_total']),
        redeemedTotal: _int(j['redeemed_total']),
      );

  /// Días hasta el próximo vencimiento (redondeando hacia arriba, mínimo 1 si
  /// ya hay fecha). `null` = no hay lote por vencer.
  int? get diasHastaVencimiento {
    final at = nextExpiryAt;
    if (at == null) return null;
    final diff = at.difference(DateTime.now());
    if (diff.isNegative) return 0;
    final d = (diff.inMinutes / (60 * 24)).ceil();
    return d < 1 ? 1 : d;
  }
}

/// Promo de referidos (`referral`).
class LoyaltyReferralInfo {
  final bool enabled;
  final String? code;
  final int discountPct;
  final int referredPoints;
  final int referrerPoints;
  final int completedCount;

  const LoyaltyReferralInfo({
    this.enabled = false,
    this.code,
    this.discountPct = 0,
    this.referredPoints = 0,
    this.referrerPoints = 0,
    this.completedCount = 0,
  });

  factory LoyaltyReferralInfo.fromJson(Map<String, dynamic> j) =>
      LoyaltyReferralInfo(
        enabled: _bool(j['enabled']),
        code: _str(j['code']),
        discountPct: _int(j['discount_pct']),
        referredPoints: _int(j['referred_points']),
        referrerPoints: _int(j['referrer_points']),
        completedCount: _int(j['completed_count']),
      );
}

/// Parámetros del programa (`program`). Son los valores que el dueño carga en
/// el dashboard; la pantalla "Cómo funciona" los imprime tal cual.
class LoyaltyProgram {
  final bool enabled;
  final int basePoints;
  final int expiryDays;
  final int windowWeeks;
  final int graceDays;
  final int welcomeBonusPoints;

  /// Días de validez de un premio canjeado cuando el premio no define
  /// `validity_days` propio (`loyalty_settings.reward_validity_days`, mig
  /// 200). Viaja también con el programa apagado. `null` = el server no lo
  /// mandó (RPC vieja): la confirmación de canje no inventa un número.
  final int? rewardValidityDays;
  final DateTime? startedAt;

  const LoyaltyProgram({
    this.enabled = false,
    this.basePoints = 0,
    this.expiryDays = 0,
    this.windowWeeks = 0,
    this.graceDays = 0,
    this.welcomeBonusPoints = 0,
    this.rewardValidityDays,
    this.startedAt,
  });

  factory LoyaltyProgram.fromJson(Map<String, dynamic> j) => LoyaltyProgram(
        enabled: _bool(j['enabled']),
        basePoints: _int(j['base_points']),
        expiryDays: _int(j['expiry_days']),
        windowWeeks: _int(j['window_weeks']),
        graceDays: _int(j['grace_days']),
        welcomeBonusPoints: _int(j['welcome_bonus_points']),
        rewardValidityDays: _intOrNull(j['reward_validity_days']),
        startedAt: _date(j['started_at']),
      );

  /// La regla de la gracia en criollo, para "Cómo funciona". Con
  /// `grace_days = 0` el server baja de categoría en el acto (el dashboard lo
  /// permite): "tenés 0 días para mantener tu categoría" se lee como un bug.
  String get textoGracia {
    if (graceDays <= 0) {
      return 'Si dejás de cumplir la frecuencia, bajás de categoría enseguida.';
    }
    final dias = graceDays == 1 ? '1 día' : '$graceDays días';
    return 'Si dejás de venir tenés $dias de gracia para mantener tu categoría.';
  }
}

/// Lo que devuelve `get_client_loyalty()`: el estado completo del cliente en
/// el programa, más el catálogo de categorías para dibujar el carrusel.
class LoyaltySummary {
  final LoyaltyProgram program;
  final String clientName;
  final DateTime? memberSince;

  /// `null` = no enrolado o programa apagado.
  final LoyaltyTier? tier;

  /// `null` = ya está en la categoría más alta (o no hay programa).
  final LoyaltyTier? nextTier;

  /// Visitas que faltan para [nextTier] (0 si no hay siguiente).
  final int nextTierFaltan;
  final int visitsInWindow;
  final LoyaltyGrace? grace;
  final LoyaltyPoints points;
  final LoyaltyReferralInfo referral;
  final List<LoyaltyTier> tiers;

  const LoyaltySummary({
    this.program = const LoyaltyProgram(),
    this.clientName = '',
    this.memberSince,
    this.tier,
    this.nextTier,
    this.nextTierFaltan = 0,
    this.visitsInWindow = 0,
    this.grace,
    this.points = const LoyaltyPoints(),
    this.referral = const LoyaltyReferralInfo(),
    this.tiers = const [],
  });

  /// Estado "sin programa": lo que se pinta sin sesión, con la RPC caída o
  /// con `is_enabled = false`. Acepta el nombre y el saldo que ya se conocían
  /// para que la tarjeta nunca quede vacía.
  factory LoyaltySummary.disabled({String clientName = '', int balance = 0}) =>
      LoyaltySummary(
        clientName: clientName,
        points: LoyaltyPoints(balance: balance),
      );

  factory LoyaltySummary.fromJson(Map<String, dynamic> j) {
    final program = LoyaltyProgram.fromJson(_map(j['program']));
    final client = _map(j['client']);
    final rawTiers = j['tiers'];
    final tiers = rawTiers is List
        ? rawTiers
            .whereType<Map>()
            .map((t) => LoyaltyTier.fromJson(Map<String, dynamic>.from(t)))
            .where((t) => t.code.isNotEmpty)
            .toList()
        : <LoyaltyTier>[];
    tiers.sort((a, b) => a.sort.compareTo(b.sort));

    final tierJson = j['tier'];
    final nextJson = j['next_tier'];
    final graceJson = j['grace'];

    // Si el programa está apagado, el server manda `tier: null`; si por lo
    // que fuera mandara uno, se ignora igual: sin programa no hay categoría.
    final tier = program.enabled && tierJson is Map
        ? LoyaltyTier.fromJson(Map<String, dynamic>.from(tierJson))
        : null;
    final next = program.enabled && nextJson is Map
        ? LoyaltyTier.fromJson(Map<String, dynamic>.from(nextJson))
        : null;

    return LoyaltySummary(
      program: program,
      clientName: _str(client['name']) ?? '',
      memberSince: _date(client['member_since']),
      tier: tier,
      nextTier: next,
      nextTierFaltan: nextJson is Map ? _int(nextJson['faltan']) : 0,
      visitsInWindow: _int(j['visits_in_window']),
      grace: program.enabled && graceJson is Map
          ? LoyaltyGrace.fromJson(Map<String, dynamic>.from(graceJson))
          : null,
      points: LoyaltyPoints.fromJson(_map(j['points'])),
      referral: LoyaltyReferralInfo.fromJson(_map(j['referral'])),
      tiers: tiers,
    );
  }

  bool get programEnabled => program.enabled;

  /// Tiene categoría para dibujar (programa prendido y enrolado).
  bool get tieneCategoria => programEnabled && tier != null;

  /// Año de "MIEMBRO DESDE 2024". `null` si el server no mandó fecha.
  int? get memberSinceYear => memberSince?.year;

  LoyaltyTier? tierPorCode(String? code) {
    if (code == null) return null;
    for (final t in tiers) {
      if (t.code == code) return t;
    }
    return null;
  }

  /// Progreso 0..1 hacia la siguiente categoría. Sin siguiente = 1.
  double get progresoHaciaSiguiente {
    final next = nextTier;
    if (next == null) return 1;
    final actual = tier;
    final desde = actual?.minVisits ?? 0;
    final rango = next.minVisits - desde;
    if (rango <= 0) return 1;
    return ((visitsInWindow - desde) / rango).clamp(0.0, 1.0);
  }

  LoyaltySummary copyWith({
    LoyaltyTier? tier,
    LoyaltyTier? nextTier,
    int? nextTierFaltan,
    int? visitsInWindow,
    LoyaltyGrace? grace,
    LoyaltyPoints? points,
    String? clientName,
  }) {
    return LoyaltySummary(
      program: program,
      clientName: clientName ?? this.clientName,
      memberSince: memberSince,
      tier: tier ?? this.tier,
      nextTier: nextTier ?? this.nextTier,
      nextTierFaltan: nextTierFaltan ?? this.nextTierFaltan,
      visitsInWindow: visitsInWindow ?? this.visitsInWindow,
      grace: grace ?? this.grace,
      points: points ?? this.points,
      referral: referral,
      tiers: tiers,
    );
  }
}
