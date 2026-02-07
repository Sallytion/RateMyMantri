import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_app_installations/firebase_app_installations.dart';
import 'package:flutter/foundation.dart';

/// Handles Firebase Cloud Messaging notifications
class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Initialize FCM and request permissions
  static Future<void> initialize() async {
    try {
      debugPrint('🔔 [NotificationService] Starting initialization...');
      
      // Request notification permissions
      debugPrint('🔔 [NotificationService] Requesting permissions...');
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      );

      debugPrint('🔔 [NotificationService] Permission status: ${settings.authorizationStatus}');
      
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ Notification permission granted');
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        debugPrint('⚠️ Provisional notification permission granted');
      } else {
        debugPrint('❌ Notification permission denied');
        return;
      }

      // Check Firebase Installations Service first
      debugPrint('🔔 [NotificationService] Checking Firebase Installation Service...');
      try {
        String installationId = await FirebaseInstallations.instance.getId();
        debugPrint('✅ Firebase Installation ID: $installationId');
        
        String installationToken = await FirebaseInstallations.instance.getToken();
        debugPrint('✅ Firebase Installation Token obtained (length: ${installationToken.length})');
      } catch (e) {
        debugPrint('❌ Firebase Installation Service Error: $e');
        debugPrint('⚠️ This may cause FCM token retrieval to fail');
      }

      // Wait for Firebase Installation Service to stabilize
      debugPrint('🔔 [NotificationService] Waiting 5 seconds for FIS to stabilize...');
      await Future.delayed(const Duration(seconds: 5));

      // Get FCM token first (this ensures FCM is ready)
      debugPrint('🔔 [NotificationService] Getting FCM token...');
      String? token = await _messaging.getToken();
      if (token != null) {
        debugPrint('📱 FCM Token: $token');
      } else {
        debugPrint('⚠️ Failed to get FCM token, waiting 3 seconds...');
        await Future.delayed(const Duration(seconds: 3));
        token = await _messaging.getToken();
        debugPrint('📱 FCM Token (retry): $token');
      }

      // Subscribe to 'general' topic so all users can receive notifications
      debugPrint('🔔 [NotificationService] Subscribing to general topic...');
      await subscribeToGeneralTopic();

      // Handle foreground messages
      debugPrint('🔔 [NotificationService] Setting up message handlers...');
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('📬 Foreground message received: ${message.notification?.title}');
        debugPrint('📬 Message body: ${message.notification?.body}');
        debugPrint('📬 Message data: ${message.data}');
        // FCM automatically shows notification on Android/iOS
      });

      // Handle when user taps notification (app opened from background)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('🔔 Notification tapped: ${message.notification?.title}');
        // App automatically opens - no extra routing needed
      });

      debugPrint('✅ Firebase Messaging initialized');
    } catch (e, stackTrace) {
      debugPrint('❌ Error initializing notifications: $e');
      debugPrint('❌ Stack trace: $stackTrace');
    }
  }

  /// Subscribe all users to the 'general' topic
  static Future<void> subscribeToGeneralTopic() async {
    try {
      debugPrint('🔔 [Topic] Attempting to subscribe to "general" topic...');
      await _messaging.subscribeToTopic('general');
      debugPrint('✅ Successfully subscribed to "general" topic!');
    } catch (e, stackTrace) {
      debugPrint('❌ Error subscribing to topic: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      
      // Retry once after 3 seconds
      debugPrint('🔔 [Topic] Retrying in 3 seconds...');
      await Future.delayed(const Duration(seconds: 3));
      try {
        await _messaging.subscribeToTopic('general');
        debugPrint('✅ Successfully subscribed to "general" topic (retry)!');
      } catch (retryError, retryStackTrace) {
        debugPrint('❌ Retry failed: $retryError');
        debugPrint('❌ Retry stack trace: $retryStackTrace');
      }
    }
  }

  /// Unsubscribe from 'general' topic (optional, for logout)
  static Future<void> unsubscribeFromGeneralTopic() async {
    try {
      await _messaging.unsubscribeFromTopic('general');
      debugPrint('✅ Unsubscribed from "general" topic');
    } catch (e) {
      debugPrint('❌ Error unsubscribing from topic: $e');
    }
  }

  /// Get the current FCM token
  static Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
      return null;
    }
  }
}
