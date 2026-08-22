import 'package:flutter/material.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/core/push/push_handler.dart';

/// Fila de `client_notifications` (bandeja in-app = historial de push).
///
/// Tolera el shape viejo (sin `read_at` / `deep_link` / `organization_id`,
/// que agrega la migración 193): `isRead` mira las dos columnas y `deepLink`
/// cae a `data.deep_link`.
class ClientNotification {
  final String id;
  final String clientId;
  final String type;
  final String title;
  final String? body;
  final Map<String, dynamic> data;
  final String? deepLink;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;

  const ClientNotification({
    required this.id,
    required this.clientId,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.deepLink,
    required this.isRead,
    required this.createdAt,
    required this.readAt,
  });

  factory ClientNotification.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final data = rawData is Map
        ? Map<String, dynamic>.from(rawData)
        : <String, dynamic>{};
    final readAtRaw = json['read_at'] as String?;
    final readAt = readAtRaw != null ? DateTime.tryParse(readAtRaw) : null;
    final deepLink =
        (json['deep_link'] as String?) ?? (data['deep_link'] as String?);
    return ClientNotification(
      id: json['id'] as String,
      clientId: json['client_id'] as String,
      type: (json['type'] as String?) ?? 'alert',
      title: (json['title'] as String?) ?? 'Monaco',
      body: json['body'] as String?,
      data: data,
      deepLink: deepLink,
      isRead: (json['is_read'] as bool? ?? false) || readAt != null,
      createdAt:
          DateTime.tryParse((json['created_at'] as String?) ?? '')?.toLocal() ??
          DateTime.now(),
      readAt: readAt?.toLocal(),
    );
  }

  ClientNotification copyWith({bool? isRead, DateTime? readAt}) {
    return ClientNotification(
      id: id,
      clientId: clientId,
      type: type,
      title: title,
      body: body,
      data: data,
      deepLink: deepLink,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
    );
  }

  /// A dónde lleva el tap (misma tabla de ruteo que el push del sistema).
  String get route => PushHandler.routeFor(
    deepLink: deepLink,
    type: type,
    value: _valueOf(data),
  );

  static String? _valueOf(Map<String, dynamic> data) {
    final v = data['value'] ?? data['token'];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// Ícono según el tipo.
  IconData get icon {
    switch (type) {
      case 'appointment_reminder':
        return Icons.alarm_rounded;
      case 'appointment_update':
      case 'appointment':
        return Icons.event_note_rounded;
      case 'reward':
        return Icons.card_giftcard_rounded;
      case 'points':
        return Icons.stars_rounded;
      case 'review_request':
      case 'review':
        return Icons.rate_review_rounded;
      case 'campaign':
      case 'promo':
        return Icons.campaign_rounded;
      case 'test':
        return Icons.science_rounded;
      case 'alert':
      default:
        return Icons.notifications_rounded;
    }
  }

  /// Color del ícono según el tipo (ámbar para turnos, verde para premios,
  /// azul para campañas, blanco para el resto).
  Color get accent {
    switch (type) {
      case 'appointment_reminder':
      case 'appointment_update':
      case 'appointment':
        return MonacoColors.warning;
      case 'reward':
      case 'points':
        return MonacoColors.monacoGreen;
      case 'campaign':
      case 'promo':
        return MonacoColors.info;
      case 'review_request':
      case 'review':
        return MonacoColors.starFilled;
      default:
        return Colors.white;
    }
  }
}

/// Preferencias de `client_notification_preferences` (una fila por cliente).
class NotificationPreferences {
  final bool campaigns;
  final bool appointmentReminders;
  final bool appointmentUpdates;
  final bool rewards;

  const NotificationPreferences({
    this.campaigns = true,
    this.appointmentReminders = true,
    this.appointmentUpdates = true,
    this.rewards = true,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      campaigns: json['campaigns'] as bool? ?? true,
      appointmentReminders: json['appointment_reminders'] as bool? ?? true,
      appointmentUpdates: json['appointment_updates'] as bool? ?? true,
      rewards: json['rewards'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'campaigns': campaigns,
    'appointment_reminders': appointmentReminders,
    'appointment_updates': appointmentUpdates,
    'rewards': rewards,
  };

  NotificationPreferences copyWith({
    bool? campaigns,
    bool? appointmentReminders,
    bool? appointmentUpdates,
    bool? rewards,
  }) {
    return NotificationPreferences(
      campaigns: campaigns ?? this.campaigns,
      appointmentReminders: appointmentReminders ?? this.appointmentReminders,
      appointmentUpdates: appointmentUpdates ?? this.appointmentUpdates,
      rewards: rewards ?? this.rewards,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NotificationPreferences &&
      other.campaigns == campaigns &&
      other.appointmentReminders == appointmentReminders &&
      other.appointmentUpdates == appointmentUpdates &&
      other.rewards == rewards;

  @override
  int get hashCode =>
      Object.hash(campaigns, appointmentReminders, appointmentUpdates, rewards);
}

/// Campo editable de [NotificationPreferences] (para el toggle genérico).
enum NotificationPreferenceField {
  campaigns,
  appointmentReminders,
  appointmentUpdates,
  rewards,
}
