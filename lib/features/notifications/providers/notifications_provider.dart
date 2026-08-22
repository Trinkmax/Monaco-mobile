import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:monaco_mobile/core/auth/auth_provider.dart';
import 'package:monaco_mobile/core/supabase/supabase_provider.dart';
import '../data/notification_model.dart';
import '../data/notifications_repository.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  ref,
) {
  return NotificationsRepository(ref.watch(supabaseClientProvider));
});

/// `client_id` del cliente logueado (o `null`): la bandeja y las preferencias
/// se re-crean cuando cambia.
final _clientIdProvider = Provider<String?>((ref) {
  return ref.watch(authProvider.select((s) => s.clientId));
});

/// Bandeja en vivo (fetch inicial + Realtime). Sin sesión emite lista vacía.
///
/// Es un `StreamProvider` sin autoDispose a propósito: el badge del header de
/// Home lo mantiene vivo y así hay UNA sola suscripción Realtime por app.
final notificationsStreamProvider = StreamProvider<List<ClientNotification>>((
  ref,
) {
  final clientId = ref.watch(_clientIdProvider);
  if (clientId == null) return Stream.value(const <ClientNotification>[]);
  return ref.watch(notificationsRepositoryProvider).watchInbox(clientId);
});

/// Cantidad de notificaciones no leídas — para el badge de la campana en el
/// header de Home. Nombre estable: lo consume el agente de Home.
final unreadNotificationsCountProvider = Provider<int>((ref) {
  final list = ref.watch(notificationsStreamProvider).valueOrNull;
  if (list == null) return 0;
  return list.where((n) => !n.isRead).length;
});

/// Acciones sobre la bandeja (marcar leída / todas). Los cambios llegan de
/// vuelta por Realtime; mientras tanto se aplica un parche optimista sobre la
/// lista para que la UI no "parpadee".
final notificationsActionsProvider = Provider<NotificationsActions>((ref) {
  return NotificationsActions(ref);
});

class NotificationsActions {
  final Ref _ref;
  NotificationsActions(this._ref);

  /// Ids marcados localmente como leídos a la espera del eco de Realtime.
  final Set<String> _optimisticRead = {};

  bool isOptimisticallyRead(String id) => _optimisticRead.contains(id);

  Future<void> markRead(ClientNotification n) async {
    if (n.isRead) return;
    _optimisticRead.add(n.id);
    _ref.read(_optimisticTickProvider.notifier).state++;
    try {
      await _ref.read(notificationsRepositoryProvider).markRead(n.id);
    } catch (e) {
      debugPrint('[notifications] markRead: $e');
    }
  }

  Future<void> markAllRead() async {
    final clientId = _ref.read(_clientIdProvider);
    if (clientId == null) return;
    final list = _ref.read(notificationsStreamProvider).valueOrNull ?? const [];
    for (final n in list) {
      if (!n.isRead) _optimisticRead.add(n.id);
    }
    _ref.read(_optimisticTickProvider.notifier).state++;
    await _ref.read(notificationsRepositoryProvider).markAllRead(clientId);
  }
}

/// Contador que fuerza re-evaluación de [inboxProvider] cuando cambia el set
/// optimista (no hay otra forma de "notificar" desde un `Provider` plano).
final _optimisticTickProvider = StateProvider<int>((ref) => 0);

/// Lista final que pinta la pantalla: stream + parche optimista.
final inboxProvider = Provider<AsyncValue<List<ClientNotification>>>((ref) {
  ref.watch(_optimisticTickProvider);
  final actions = ref.watch(notificationsActionsProvider);
  final async = ref.watch(notificationsStreamProvider);
  return async.whenData(
    (list) => list
        .map(
          (n) => !n.isRead && actions.isOptimisticallyRead(n.id)
              ? n.copyWith(isRead: true, readAt: DateTime.now())
              : n,
        )
        .toList(),
  );
});

/// Preferencias de notificaciones (toggles). Guarda con upsert y revierte si
/// el server rechaza.
final notificationPreferencesProvider =
    AsyncNotifierProvider<
      NotificationPreferencesNotifier,
      NotificationPreferences
    >(NotificationPreferencesNotifier.new);

class NotificationPreferencesNotifier
    extends AsyncNotifier<NotificationPreferences> {
  @override
  Future<NotificationPreferences> build() async {
    final clientId = ref.watch(_clientIdProvider);
    if (clientId == null) return const NotificationPreferences();
    return ref.read(notificationsRepositoryProvider).getPreferences(clientId);
  }

  /// Cambia un toggle. Optimista: la UI se actualiza al toque; si el upsert
  /// falla, vuelve al valor anterior y relanza (la pantalla muestra el toast).
  Future<void> toggle(NotificationPreferenceField field, bool value) async {
    final clientId = ref.read(_clientIdProvider);
    final current = state.valueOrNull ?? const NotificationPreferences();
    final next = switch (field) {
      NotificationPreferenceField.campaigns => current.copyWith(
        campaigns: value,
      ),
      NotificationPreferenceField.appointmentReminders => current.copyWith(
        appointmentReminders: value,
      ),
      NotificationPreferenceField.appointmentUpdates => current.copyWith(
        appointmentUpdates: value,
      ),
      NotificationPreferenceField.rewards => current.copyWith(rewards: value),
    };
    if (next == current) return;
    state = AsyncData(next);
    if (clientId == null) return;
    try {
      await ref
          .read(notificationsRepositoryProvider)
          .savePreferences(clientId, next);
    } catch (e) {
      debugPrint('[notifications] savePreferences: $e');
      state = AsyncData(current);
      rethrow;
    }
  }
}
