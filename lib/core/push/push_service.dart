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
  static Future<void> init(WidgetRef? ref) async {
    if (_initialized) return;
    _initialized = true;

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permissions (iOS)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }

    // Get FCM token
    final token = await _messaging.getToken();
    if (token != null) {
      await _saveToken(token);
    }

    // Listen for token refresh
    _messaging.onTokenRefresh.listen(_saveToken);
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
}

/// Provider to initialize push notifications after auth.
final pushInitProvider = FutureProvider<void>((ref) async {
  await PushService.init(null);
});
