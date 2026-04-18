import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:monaco_mobile/core/auth/auth_provider.dart';
import 'package:monaco_mobile/core/supabase/supabase_provider.dart';

// ── Branch Signals (one-shot) ──────────────────────────────────────────────

/// Sucursales de la org actualmente seleccionada por el cliente
/// (puede ser distinta a la org del JWT — el cliente puede explorar otras
/// barberías). Usa el RPC paramétrico para no depender de `get_user_org_id()`.
final branchSignalsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final orgId = ref.watch(authProvider).selectedOrgId;
  if (orgId == null) return [];

  final supabase = ref.read(supabaseClientProvider);
  final res = await supabase.rpc(
    'get_org_branch_signals',
    params: {'p_org_id': orgId},
  );
  if (res is List) {
    return res.map((e) => Map<String, dynamic>.from(e)).toList();
  }
  return [];
});

// ── Branch Signals Realtime ────────────────────────────────────────────────

final branchOccupancyRealtimeProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final supabase = ref.read(supabaseClientProvider);

  // First, fetch initial data, then listen for changes
  return supabase
      .from('branch_signals')
      .stream(primaryKey: ['id']).map((rows) {
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  });
});

// ── Branch Detail (by ID) ──────────────────────────────────────────────────

final branchDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, branchId) async {
  final supabase = ref.read(supabaseClientProvider);

  // Un solo RPC SECURITY DEFINER trae todos los datos públicos de la sucursal,
  // sin importar que sea de la org del cliente o no (modelo "browse libre").
  final res = await supabase.rpc(
    'get_branch_public_detail',
    params: {'p_branch_id': branchId},
  );
  final data = res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};

  final branch = data['branch'] is Map
      ? Map<String, dynamic>.from(data['branch'] as Map)
      : <String, dynamic>{};
  final queueEntries = (data['queue_entries'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e))
          .toList() ??
      [];
  final staffList = (data['staff'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e))
          .toList() ??
      [];
  final visitsList = (data['visits_recent'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e))
          .toList() ??
      [];
  final appSettings = data['app_settings'] is Map
      ? Map<String, dynamic>.from(data['app_settings'] as Map)
      : <String, dynamic>{};
  final attendanceLogs = (data['attendance_logs_today'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e))
          .toList() ??
      [];
  final schedulesList = (data['staff_schedules'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e))
          .toList() ??
      [];
  final shiftEndMargin =
      (appSettings['shift_end_margin_minutes'] as num?)?.toInt() ?? 35;

  // Última acción de asistencia por barbero (lista ya viene ordenada desc)
  final latestAttendance = <String, String>{};
  for (final log in attendanceLogs) {
    final sid = log['staff_id'] as String?;
    if (sid != null && !latestAttendance.containsKey(sid)) {
      latestAttendance[sid] = log['action_type'] as String? ?? '';
    }
  }

  // Solo barberos que ficharon entrada hoy (última acción = clock_in)
  final activatedStaff = staffList.where((s) {
    final lastAction = latestAttendance[s['id'] as String?];
    return lastAction == 'clock_in';
  }).toList();

  // Compute per-barber average minutes from real visit data
  final barberAvgMap = _buildBarberAvgMinutes(visitsList, 25);

  // Compute metrics
  final waiting =
      queueEntries.where((e) => e['status'] == 'waiting').toList();
  final inProgress =
      queueEntries.where((e) => e['status'] == 'in_progress').toList();
  // Build staff with status and individual ETA (solo barberos con clock_in)
  final staffWithStatus = activatedStaff.map((s) {
    final barberId = s['id'] as String;
    final activeQueue =
        inProgress.where((q) => q['barber_id'] == barberId).toList();
    final waitingForBarber =
        waiting.where((q) => q['barber_id'] == barberId).toList();
    String status;
    Map<String, dynamic>? currentClient;
    if (activeQueue.isNotEmpty) {
      status = 'ocupado';
      currentClient = activeQueue.first;
    } else if (s['status'] == 'paused' || s['status'] == 'blocked') {
      status = 'descanso';
    } else if (_isBarberBlockedByShiftEnd(
        barberId, schedulesList, DateTime.now(), shiftEndMargin)) {
      status = 'fin_turno';
    } else {
      status = 'disponible';
    }
    final avg = barberAvgMap[barberId] ?? barberAvgMap['__fallback'] ?? 25;
    final totalLoad = waitingForBarber.length + (activeQueue.isNotEmpty ? 1 : 0);
    final eta = (totalLoad * avg).round();
    return {
      ...s,
      'status': status,
      'current_client': currentClient,
      'eta_minutes': eta,
      'avg_minutes': avg,
      'waiting_count': waitingForBarber.length,
    };
  }).where((s) => s['status'] != 'fin_turno').toList();

  final bool isOpen = (data['is_open'] ?? false) as bool;

  // Global ETA: min ETA across available barbers, or fallback for unassigned
  int globalEta = 0;
  if (waiting.isNotEmpty) {
    final barberEtas = staffWithStatus
        .where((s) => s['status'] != 'descanso')
        .map((s) => s['eta_minutes'] as int)
        .toList();
    if (barberEtas.isNotEmpty) {
      globalEta = barberEtas.reduce((a, b) => a < b ? a : b);
    } else {
      globalEta = waiting.length * 25;
    }
  }

  return {
    'branch': branch,
    'queue_entries': queueEntries,
    'waiting': waiting,
    'in_progress': inProgress,
    'staff': staffWithStatus,
    'available_staff_count': staffWithStatus.where((s) => s['status'] == 'disponible').length,
    'total_staff_count': staffWithStatus.length,
    'is_open': isOpen,
    'eta_minutes': globalEta,
    'business_hours_open': branch['business_hours_open'] ??
        appSettings['business_hours_open'] ??
        '--:--',
    'business_hours_close': branch['business_hours_close'] ??
        appSettings['business_hours_close'] ??
        '--:--',
  };
});

/// Espejo de isBarberBlockedByShiftEnd de barber-utils.ts.
/// Devuelve true si el barbero está cerca del fin de su último bloque de horario
/// y no tiene otro bloque que comience después del margen.
bool _isBarberBlockedByShiftEnd(
  String barberId,
  List<Map<String, dynamic>> schedules,
  DateTime now,
  int marginMinutes,
) {
  final barberSchedules = schedules
      .where((s) => s['staff_id'] == barberId)
      .toList()
    ..sort((a, b) =>
        (a['start_time'] as String).compareTo(b['start_time'] as String));

  if (barberSchedules.isEmpty) return false;

  DateTime timeToDate(String timeStr) {
    final parts = timeStr.split(':');
    final h = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    return DateTime(now.year, now.month, now.day, h, m);
  }

  final lastBlock = barberSchedules.last;
  final lastEnd = timeToDate(lastBlock['end_time'] as String);

  if (!now.isBefore(lastEnd)) return true;

  for (int i = 0; i < barberSchedules.length; i++) {
    final blockEnd = timeToDate(barberSchedules[i]['end_time'] as String);
    final msToEnd = blockEnd.difference(now).inMilliseconds;

    if (msToEnd <= 0) continue;

    if (msToEnd <= marginMinutes * 60 * 1000) {
      if (i + 1 >= barberSchedules.length) return true;
      final nextStart =
          timeToDate(barberSchedules[i + 1]['start_time'] as String);
      final gapMinutes = nextStart.difference(blockEnd).inMinutes;
      if (gapMinutes > marginMinutes) return true;
    }

    return false;
  }

  return true;
}

/// Builds per-barber average service time from recent visits (mirrors barber-utils.ts)
Map<String, num> _buildBarberAvgMinutes(
    List<Map<String, dynamic>> visits, int fallback) {
  final groups = <String, List<double>>{};
  for (final v in visits) {
    final barberId = v['barber_id'] as String?;
    final startedAt = v['started_at'] as String?;
    final completedAt = v['completed_at'] as String?;
    if (barberId == null || startedAt == null || completedAt == null) continue;
    final start = DateTime.tryParse(startedAt);
    final end = DateTime.tryParse(completedAt);
    if (start == null || end == null) continue;
    final mins = end.difference(start).inSeconds / 60.0;
    if (mins < 5 || mins > 120) continue;
    (groups[barberId] ??= []).add(mins);
  }
  final result = <String, num>{};
  for (final entry in groups.entries) {
    final durations = entry.value;
    result[entry.key] =
        (durations.reduce((a, b) => a + b) / durations.length).round();
  }
  result['__fallback'] = fallback;
  return result;
}

// ── Attendance Realtime (para detectar clock_in/out en tiempo real) ────────

final branchAttendanceRealtimeProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>(
        (ref, branchId) {
  final supabase = ref.read(supabaseClientProvider);
  return supabase
      .from('attendance_logs')
      .stream(primaryKey: ['id'])
      .eq('branch_id', branchId)
      .map((rows) => rows.map((e) => Map<String, dynamic>.from(e)).toList());
});

// ── Branch Realtime Stream (for detail page) ───────────────────────────────

final branchQueueRealtimeProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>(
        (ref, branchId) {
  final supabase = ref.read(supabaseClientProvider);
  return supabase
      .from('queue_entries')
      .stream(primaryKey: ['id'])
      .eq('branch_id', branchId)
      .map((rows) => rows.map((e) => Map<String, dynamic>.from(e)).toList());
});
