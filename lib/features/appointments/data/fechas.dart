import 'package:intl/intl.dart';

/// Fechas, horas y formato del módulo de turnos.
///
/// `appointment_date` + `start_time` son hora de PARED de la sucursal. Todas
/// las sucursales de Monaco están en `America/Argentina/Buenos_Aires` (UTC-3
/// fijo, sin horario de verano), así que el instante real se calcula con ese
/// offset y NO con la zona del dispositivo: un cliente de viaje tiene que ver
/// el mismo "faltan 2 h" que uno en Córdoba, y "hoy" es el hoy de la
/// barbería, no el del teléfono.
///
/// Nada de acá usa `toIso8601String()` para fechas de comparación (contrato
/// §0.7): las fechas se arman campo por campo.
class Fechas {
  Fechas._();

  static const String tzBuenosAires = 'America/Argentina/Buenos_Aires';
  static const String locale = 'es_AR';

  /// Offsets fijos (en horas) de las zonas que conocemos. Una zona
  /// desconocida cae al offset del dispositivo.
  static const Map<String, int> _offsets = {
    'America/Argentina/Buenos_Aires': -3,
    'America/Argentina/Cordoba': -3,
    'America/Argentina/Mendoza': -3,
    'America/Buenos_Aires': -3,
    'America/Montevideo': -3,
    'America/Sao_Paulo': -3,
    'UTC': 0,
  };

  static const List<String> diasLargos = [
    'domingo',
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
  ];

  /// Abreviaturas de 3 letras (mismo set que `DIAS_ABREV_3` del turnero web).
  static const List<String> diasAbrev3 = [
    'Dom',
    'Lun',
    'Mar',
    'Mié',
    'Jue',
    'Vie',
    'Sáb',
  ];

  static const List<String> diasAbrevMayus = [
    'DOM',
    'LUN',
    'MAR',
    'MIÉ',
    'JUE',
    'VIE',
    'SÁB',
  ];

  static const List<String> meses = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  // ── Zona horaria ───────────────────────────────────────────────────────

  static Duration offsetOf(String? tz) {
    final h = _offsets[tz ?? tzBuenosAires];
    if (h == null) return DateTime.now().timeZoneOffset;
    return Duration(hours: h);
  }

  /// "Ahora" como hora de pared de la sucursal. El `DateTime` devuelto está
  /// marcado UTC pero sus campos (año, mes, día, hora, minuto) son los del
  /// reloj de la barbería: sirve para formatear y para sacar "hoy".
  static DateTime nowWall(String? tz, {DateTime? now}) =>
      (now ?? DateTime.now()).toUtc().add(offsetOf(tz));

  /// 'yyyy-MM-dd' de HOY en la zona de la sucursal.
  static String todayStr(String? tz, {DateTime? now}) =>
      toDateStr(nowWall(tz, now: now));

  /// Instante real (UTC) de una hora de pared (`'yyyy-MM-dd'` + `'HH:MM'`)
  /// en la zona de la sucursal.
  static DateTime instantOf(String dateStr, String hhmm, String? tz) {
    final d = parseDate(dateStr);
    final (h, m) = parseHm(hhmm);
    return DateTime.utc(d.year, d.month, d.day, h, m).subtract(offsetOf(tz));
  }

  // ── Parseo / armado de strings ─────────────────────────────────────────

  /// 'yyyy-MM-dd' a partir de los campos del `DateTime` (sin convertir zona).
  static String toDateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Parsea 'yyyy-MM-dd' a un `DateTime` UTC a las 12:00. Sólo para
  /// formatear y sacar el día de la semana: las 12:00 evitan que un offset
  /// mueva el día.
  static DateTime parseDate(String s) {
    final parts = s.split('-');
    if (parts.length < 3) return DateTime.now().toUtc();
    final y = int.tryParse(parts[0]) ?? 1970;
    final m = int.tryParse(parts[1]) ?? 1;
    final d = int.tryParse(parts[2].substring(0, 2)) ?? 1;
    return DateTime.utc(y, m, d, 12);
  }

  /// Suma días a una fecha 'yyyy-MM-dd'.
  static String addDays(String dateStr, int days) =>
      toDateStr(parseDate(dateStr).add(Duration(days: days)));

  /// Día de la semana estilo JS (0 = domingo … 6 = sábado).
  static int dayOfWeek(String dateStr) => parseDate(dateStr).weekday % 7;

  static (int, int) parseHm(String s) {
    final parts = s.split(':');
    final h = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return (h, m);
  }

  static int minutesOf(String hhmm) {
    final (h, m) = parseHm(hhmm);
    return h * 60 + m;
  }

  /// 'HH:MM:SS' → 'HH:MM'.
  static String hhmm(String raw) {
    final (h, m) = parseHm(raw);
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  // ── Formato ────────────────────────────────────────────────────────────

  static String capitalizar(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  /// "Miércoles, 6 de agosto" — sólo la primera letra en mayúscula.
  static String fechaLarga(DateTime d) =>
      capitalizar(DateFormat("EEEE, d 'de' MMMM", locale).format(d));

  static String fechaLargaDeStr(String dateStr) => fechaLarga(parseDate(dateStr));

  /// "Mié 6 ago" (sin puntos ni comas).
  static String fechaCorta(DateTime d) {
    final raw = DateFormat('EEE d MMM', locale).format(d);
    return capitalizar(raw.replaceAll('.', '').replaceAll(',', ''));
  }

  static String fechaCortaDeStr(String dateStr) => fechaCorta(parseDate(dateStr));

  /// "Agosto" / "Agosto 2027" si no es el año actual.
  static String mesLargo(DateTime d, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final nombre = capitalizar(meses[d.month - 1]);
    return d.year == n.year ? nombre : '$nombre ${d.year}';
  }

  /// "$25.000" — pesos sin decimales, miles con punto.
  static String moneda(num amount) {
    final entero = amount.round().abs();
    final s = entero.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final restantes = s.length - i;
      buf.write(s[i]);
      if (restantes > 1 && restantes % 3 == 1) buf.write('.');
    }
    return '${amount < 0 ? '-' : ''}\$$buf';
  }

  /// "45 min" / "1 h" / "1 h 30 min".
  static String duracion(int minutos) {
    if (minutos < 60) return '$minutos min';
    final h = minutos ~/ 60;
    final m = minutos % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }

  /// "1 hora" / "2 horas".
  static String horas(int n) => n == 1 ? '1 hora' : '$n horas';

  /// "10:00 a 13:00 y 16:00 a 19:00" (mismo criterio que `textoRangos`).
  static String textoRangos(List<({String start, String end})> rangos) {
    final partes = rangos.map((r) => '${hhmm(r.start)} a ${hhmm(r.end)}').toList();
    return _unirConY(partes);
  }

  /// "los martes" / "martes y jueves" / "casi todos los días".
  static String textoDias(List<int> dias) {
    final set = dias.toSet().toList()..sort();
    if (set.isEmpty) return '';
    if (set.length >= 7) return 'todos los días';
    if (set.length >= 6) return 'casi todos los días';
    String nombre(int d) {
      final n = diasLargos[d % 7];
      return (d % 7 == 0 || d % 7 == 6) ? '${n}s' : n;
    }

    if (set.length == 1) return 'los ${nombre(set.first)}';
    return _unirConY(set.map(nombre).toList());
  }

  static String _unirConY(List<String> partes) {
    if (partes.isEmpty) return '';
    if (partes.length == 1) return partes.first;
    final cabeza = partes.sublist(0, partes.length - 1).join(', ');
    return '$cabeza y ${partes.last}';
  }

  // ── Cuenta regresiva ───────────────────────────────────────────────────

  /// Texto corto de "cuánto falta": "en 25 min", "en 2 h 15 min",
  /// "Mañana 15:00", "Mié 6 ago · 15:00". Si el turno ya empezó y no
  /// terminó, "Es ahora"; si ya terminó, "Ya pasó la hora".
  static String cuentaRegresiva({
    required DateTime start,
    required DateTime end,
    required String dateStr,
    required String hhmmStr,
    String? tz,
    DateTime? now,
  }) {
    final n = (now ?? DateTime.now()).toUtc();
    final diff = start.difference(n);
    if (diff.isNegative) {
      return n.isBefore(end) ? 'Es ahora' : 'Ya pasó la hora';
    }
    if (diff.inMinutes < 1) return 'en menos de un minuto';
    if (diff.inMinutes < 60) return 'en ${diff.inMinutes} min';
    if (diff.inHours < 24) {
      final h = diff.inHours;
      final m = diff.inMinutes % 60;
      return m == 0 ? 'en $h h' : 'en $h h $m min';
    }
    final hoy = todayStr(tz, now: n);
    if (dateStr == addDays(hoy, 1)) return 'Mañana ${hhmm(hhmmStr)}';
    return '${fechaCortaDeStr(dateStr)} · ${hhmm(hhmmStr)}';
  }

  /// "Hoy" / "Mañana" / "Miércoles, 6 de agosto" según la fecha de la sucursal.
  static String etiquetaDia(String dateStr, {String? tz, DateTime? now}) {
    final hoy = todayStr(tz, now: now);
    if (dateStr == hoy) return 'Hoy';
    if (dateStr == addDays(hoy, 1)) return 'Mañana';
    return fechaLargaDeStr(dateStr);
  }
}
