import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:monaco_mobile/core/push/push_handler.dart';
import 'package:monaco_mobile/core/utils/constants.dart';
import 'notification_model.dart';

/// Acceso a `client_notifications` y `client_notification_preferences`.
///
/// Todo va directo por PostgREST con el JWT del cliente: las policies propias
/// (`cn_client_select` / `cn_client_update`, y las de preferencias por
/// `current_client_id()`) acotan a sus filas. No se filtra por org: el
/// cliente es de una sola.
class NotificationsRepository {
  final SupabaseClient _client;

  NotificationsRepository(this._client);

  static const int pageSize = 50;

  /// Bandeja en vivo: fetch inicial + Realtime (`postgres_changes` filtrado
  /// por `client_id`), ordenada por `created_at desc`, tope 50.
  Stream<List<ClientNotification>> watchInbox(String clientId) {
    return _client
        .from('client_notifications')
        .stream(primaryKey: ['id'])
        .eq('client_id', clientId)
        .order('created_at', ascending: false)
        .limit(pageSize)
        .map(
          (rows) => rows
              .map(
                (r) =>
                    ClientNotification.fromJson(Map<String, dynamic>.from(r)),
              )
              .toList(),
        );
  }

  /// Snapshot sin Realtime (pull-to-refresh / fallback).
  Future<List<ClientNotification>> fetchInbox(String clientId) async {
    final rows = await _client
        .from('client_notifications')
        .select()
        .eq('client_id', clientId)
        .order('created_at', ascending: false)
        .limit(pageSize);
    return (rows as List)
        .map((r) => ClientNotification.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<void> markRead(String notificationId) =>
      PushHandler.markNotificationRead(notificationId);

  /// Marca todas las no leídas del cliente. Tolera que `read_at` no exista
  /// todavía (mig 193 pendiente).
  Future<void> markAllRead(String clientId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    try {
      await _client
          .from('client_notifications')
          .update({'is_read': true, 'read_at': now})
          .eq('client_id', clientId)
          .eq('is_read', false);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST204' || e.code == '42703') {
        await _client
            .from('client_notifications')
            .update({'is_read': true})
            .eq('client_id', clientId)
            .eq('is_read', false);
      } else {
        rethrow;
      }
    }
  }

  /// Preferencias del cliente; si no hay fila todavía, defaults (todo en
  /// `true`, igual que los defaults de la tabla).
  Future<NotificationPreferences> getPreferences(String clientId) async {
    final row = await _client
        .from('client_notification_preferences')
        .select()
        .eq('client_id', clientId)
        .maybeSingle();
    if (row == null) return const NotificationPreferences();
    return NotificationPreferences.fromJson(Map<String, dynamic>.from(row));
  }

  /// Upsert por `client_id` con la org fija de la app.
  Future<void> savePreferences(
    String clientId,
    NotificationPreferences prefs,
  ) async {
    await _client.from('client_notification_preferences').upsert({
      'client_id': clientId,
      'organization_id': AppConstants.organizationId,
      ...prefs.toJson(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'client_id');
    debugPrint('[notifications] preferencias guardadas');
  }
}
