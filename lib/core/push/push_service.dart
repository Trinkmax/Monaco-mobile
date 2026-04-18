import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/secure_storage.dart';

/// Background message handler — must be top-level function.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Background messages are handled by push_handler when the app opens.
}

class PushService {
  PushService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static bool _initialized = false;

  /// Initialize FCM: request permissions, get token, save to Supabase.
  ///
  /// Safe para llamar aunque Firebase no esté configurado: devuelve sin hacer
  /// nada. Apple pide permiso de notificaciones solo cuando el usuario elige
  /// activarlas (ver NotificationsPermissionScreen), no en el primer launch.
  static Future<void> init(WidgetRef? ref) async {
    if (_initialized) return;
    if (Firebase.apps.isEmpty) return;
    _initialized = true;

    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied ||
          settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        return;
      }

      final token = await _messaging.getToken();
      if (token != null) {
        await _saveToken(token);
      }

      _messaging.onTokenRefresh.listen(_saveToken);
    } catch (_) {
      // Firebase mal configurado o APNs no disponible en simulador — ignorar.
    }
  }

  /// Save (upsert) the device token to Supabase `client_device_tokens`.
  static Future<void> _saveToken(String token) async {
    try {
      final clientId = await SecureStorageService.getClientId();
      if (clientId == null) return;

      final deviceId = await SecureStorageService.getOrCreateDeviceId();
      final supabase = Supabase.instance.client;

      await supabase.from('client_device_tokens').upsert(
        {
          'client_id': clientId,
          'device_id': deviceId,
          'token': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'client_id,device_id',
      );
    } catch (_) {
      // Silently fail — token will be retried on next refresh.
    }
  }

  /// Remove the device token on logout.
  static Future<void> removeToken() async {
    try {
      final clientId = await SecureStorageService.getClientId();
      final deviceId = await SecureStorageService.getOrCreateDeviceId();
      if (clientId == null) return;

      final supabase = Supabase.instance.client;
      await supabase
          .from('client_device_tokens')
          .delete()
          .eq('client_id', clientId)
          .eq('device_id', deviceId);
    } catch (_) {
      // Best-effort cleanup.
    }
  }

  /// Re-save token after login (client_id now available).
  static Future<void> refreshToken() async {
    final token = await _messaging.getToken();
    if (token != null) {
      await _saveToken(token);
    }
  }

  /// Estado actual del permiso de notificaciones en el sistema.
  /// Devuelve `null` si Firebase no está configurado.
  static Future<AuthorizationStatus?> currentAuthorizationStatus() async {
    if (Firebase.apps.isEmpty) return null;
    try {
      final settings = await _messaging.getNotificationSettings();
      return settings.authorizationStatus;
    } catch (_) {
      return null;
    }
  }

  /// Dispara el prompt nativo de iOS. Llamar SOLO después de haber mostrado
  /// un pre-prompt contextual explicando por qué pedimos el permiso
  /// (Apple Guideline 4.5.4). Devuelve el status resultante.
  static Future<AuthorizationStatus?> requestPermissionExplicitly() async {
    if (Firebase.apps.isEmpty) return null;
    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        final token = await _messaging.getToken();
        if (token != null) {
          await _saveToken(token);
        }
        _messaging.onTokenRefresh.listen(_saveToken);
        _initialized = true;
      }
      return settings.authorizationStatus;
    } catch (e) {
      // ignore: avoid_print
      print('[push] requestPermission error: $e');
      return null;
    }
  }
}

/// Provider to initialize push notifications after auth.
final pushInitProvider = FutureProvider<void>((ref) async {
  await PushService.init(null);
});
