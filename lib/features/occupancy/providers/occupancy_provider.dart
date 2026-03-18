import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:monaco_mobile/core/supabase/supabase_provider.dart';

// ── Branch Signals (one-shot) ──────────────────────────────────────────────

final branchSignalsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final res = await supabase.rpc('get_client_branch_signals');
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

  // Fetch branch info, queue entries, and staff in parallel
  final results = await Future.wait([
    supabase
        .from('branches')
        .select()
        .eq('id', branchId)
        .maybeSingle(),
    supabase
        .from('queue_entries')
        .select('*, staff:barber_id(id, full_name)')
        .eq('branch_id', branchId)
        .inFilter('status', ['waiting', 'in_progress'])
        .order('created_at'),
    supabase
        .from('staff')
        .select()
        .eq('branch_id', branchId)
        .eq('is_active', true),
    supabase.rpc('get_branch_open_status', params: {'p_branch_id': branchId}),
  ]);

  final branch =
      results[0] != null ? Map<String, dynamic>.from(results[0] as Map) : {};
  final queueEntries = (results[1] as List?)
          ?.map((e) => Map<String, dynamic>.from(e))
          .toList() ??
      [];
  final staffList = (results[2] as List?)
          ?.map((e) => Map<String, dynamic>.from(e))
          .toList() ??
      [];
  final openStatus = results[3];

  // Compute metrics
  final waiting =
      queueEntries.where((e) => e['status'] == 'waiting').toList();
  final inProgress =
      queueEntries.where((e) => e['status'] == 'in_progress').toList();
  final availableStaff =
      staffList.where((s) => !inProgress.any((q) => q['barber_id'] == s['id'])).toList();

  // Build staff with status
  final staffWithStatus = staffList.map((s) {
    final activeQueue =
        inProgress.where((q) => q['barber_id'] == s['id']).toList();
    String status;
    Map<String, dynamic>? currentClient;
    if (activeQueue.isNotEmpty) {
      status = 'ocupado';
      currentClient = activeQueue.first;
    } else if (s['on_break'] == true) {
      status = 'descanso';
    } else {
      status = 'disponible';
    }
    return {
      ...s,
      'status': status,
      'current_client': currentClient,
    };
  }).toList();

  return {
    'branch': branch,
    'queue_entries': queueEntries,
    'waiting': waiting,
    'in_progress': inProgress,
    'staff': staffWithStatus,
    'available_staff_count': availableStaff.length,
    'total_staff_count': staffList.length,
    'is_open': openStatus is bool ? openStatus : (openStatus == true),
  };
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
