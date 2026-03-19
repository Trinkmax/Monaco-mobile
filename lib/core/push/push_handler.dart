import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Handles incoming push notification taps and routes to the correct screen.
class PushHandler {
  PushHandler._();

  static GlobalKey<NavigatorState>? _navigatorKey;

  /// Call once from main app to set the navigator key.
  static void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  /// Set up foreground and tap handlers. Call after Firebase.initializeApp().
  static void init() {
    // Handle notification taps when app is in background/terminated
    FirebaseMessaging.instance
        .getInitialMessage()
        .then((message) {
      if (message != null) {
        _handleMessage(message);
      }
    });

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

    // Handle foreground messages (show local notification or in-app banner)
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
  }

  /// Route to the correct screen based on the notification payload.
  static void _handleMessage(RemoteMessage message) {
    final data = message.data;
    final context = _navigatorKey?.currentContext;
    if (context == null) return;

    final type = data['type'] as String?;
    final value = data['value'] as String?;

    switch (type) {
      case 'review':
        // Navigate to review flow with token
        if (value != null) {
          context.push('/review/$value');
        } else {
          context.push('/reviews');
        }
        break;

      case 'reward':
        // Navigate to rewards screen
        context.push('/rewards');
        break;

      case 'points':
        // Navigate to points screen
        context.push('/points');
        break;

      case 'branch':
        // Navigate to branch detail
        if (value != null) {
          context.push('/branch/$value');
        } else {
          context.go('/occupancy');
        }
        break;

      case 'billboard':
        context.push('/billboard');
        break;

      default:
        // Default: go home
        context.go('/home');
        break;
    }
  }

  /// Handle messages received while the app is in the foreground.
  /// Shows an in-app snackbar rather than a system notification.
  static void _handleForegroundMessage(RemoteMessage message) {
    final context = _navigatorKey?.currentContext;
    if (context == null) return;

    final notification = message.notification;
    if (notification == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (notification.title != null)
              Text(
                notification.title!,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            if (notification.body != null)
              Text(notification.body!),
          ],
        ),
        backgroundColor: const Color(0xFF333333),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Ver',
          textColor: const Color(0xFFF3F3F3),
          onPressed: () => _handleMessage(message),
        ),
      ),
    );
  }
}
