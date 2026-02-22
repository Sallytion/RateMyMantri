import 'package:firebase_messaging/firebase_messaging.dart';

/// Handles Firebase Cloud Messaging notifications
class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Initialize FCM and request permissions
  static Future<void> initialize() async {
    try {
      // Request notification permissions
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      );

      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        return;
      }

      // Brief wait for Firebase services to stabilize
      await Future.delayed(const Duration(seconds: 1));

      // Get FCM token (this ensures FCM is ready)
      String? token = await _messaging.getToken();
      if (token == null) {
        await Future.delayed(const Duration(seconds: 1));
        await _messaging.getToken();
      }

      // Subscribe to 'general' topic so all users can receive notifications
      await subscribeToGeneralTopic();

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        // FCM automatically shows notification on Android/iOS
      });

      // Handle when user taps notification (app opened from background)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        // App automatically opens - no extra routing needed
      });
    } catch (_) {
      // App will continue without push notifications
    }
  }

  /// Subscribe all users to the 'general' topic
  static Future<void> subscribeToGeneralTopic() async {
    try {
      await _messaging.subscribeToTopic('general');
    } catch (_) {
      // Retry once after 1 second
      await Future.delayed(const Duration(seconds: 1));
      try {
        await _messaging.subscribeToTopic('general');
      } catch (_) {}
    }
  }

  /// Unsubscribe from 'general' topic (optional, for logout)
  static Future<void> unsubscribeFromGeneralTopic() async {
    try {
      await _messaging.unsubscribeFromTopic('general');
    } catch (_) {}
  }

  /// Get the current FCM token
  static Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (_) {
      return null;
    }
  }
}
