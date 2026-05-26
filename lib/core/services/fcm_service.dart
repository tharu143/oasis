import 'dart:io';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import '../api/api_client.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Top-level background message handler (must NOT be inside a class)
// ─────────────────────────────────────────────────────────────────────────────
Future<void> updateNotificationStatus(String logName, String status) async {
  try {
    final apiClient = ApiClient();
    await apiClient.post('oasis_mobile.api.fcm.update_notification_status', {
      'log_name': logName,
      'status': status,
    });
    debugPrint('✅ [FCM] Notification $logName marked as $status');
  } catch (e) {
    debugPrint('❌ [FCM] Failed to update notification status: $e');
  }
}

@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHandler(RemoteMessage message) async {
  debugPrint('🔔 [FCM Background] ${message.notification?.title}: ${message.notification?.body}');
  if (message.data.containsKey('log_name')) {
    await updateNotificationStatus(message.data['log_name'], 'Delivered');
  }
}

// Android high-importance notification channel
const AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
  'oasis_high_importance_channel',
  'Oasis ERP Alerts',
  description: 'Workflow approvals, rejections and status updates from Oasis ERP.',
  importance: Importance.max,
);

/// Singleton FCM service for oasis-erp.
///
/// Usage:
///   1. Call [initialize(navigatorKey)] once in main() after Firebase.initializeApp()
///   2. Call [register()] after successful login
///   3. Call [unregister()] before logout
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  final _apiClient = ApiClient();

  /// Navigation key — set in main.dart so FcmService can deep-link on tap
  GlobalKey<NavigatorState>? navigatorKey;

  // ───────────────────────────────────────────────────────────────────────────
  // Initialize — call once in main() AFTER Firebase.initializeApp()
  // ───────────────────────────────────────────────────────────────────────────
  Future<void> initialize({GlobalKey<NavigatorState>? navKey}) async {
    navigatorKey = navKey;

    // 1. Request OS permission (Android 13+ / iOS)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('🔔 [FCM] Permission: ${settings.authorizationStatus}');

    // 2. iOS — present notifications in foreground
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 3. Set up background handler
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessageHandler);

    // 4. Create Android notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    // 5. Initialize flutter_local_notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (response) {
        // Foreground tap — payload is JSON with doctype + docname
        if (response.payload != null) {
          _handleDeepLink(response.payload!);
        }
      },
    );

    // 6. Foreground message → show local heads-up banner
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('🔔 [FCM Foreground] ${message.notification?.title}');
      if (message.data.containsKey('log_name')) {
        updateNotificationStatus(message.data['log_name'], 'Delivered');
      }
      _showLocalNotification(message);
    });

    // 7. Background tap (app was in background, user tapped notification)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('🔔 [FCM Tap-Background] ${message.data}');
      if (message.data.containsKey('log_name')) {
        updateNotificationStatus(message.data['log_name'], 'Read');
      }
      _handleDeepLink(jsonEncode(message.data));
    });

    // 8. Terminated state tap (app was fully closed, user tapped notification)
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('🔔 [FCM Tap-Terminated] ${initialMessage.data}');
      if (initialMessage.data.containsKey('log_name')) {
        updateNotificationStatus(initialMessage.data['log_name'], 'Read');
      }
      // Small delay to ensure navigator is ready
      Future.delayed(const Duration(milliseconds: 500), () {
        _handleDeepLink(jsonEncode(initialMessage.data));
      });
    }

    // 9. Token refresh → re-register with ERPNext
    _messaging.onTokenRefresh.listen((newToken) async {
      debugPrint('🔄 [FCM] Token refreshed — re-registering...');
      await _registerToken(newToken);
    });
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Register — call after successful login
  // ───────────────────────────────────────────────────────────────────────────
  Future<void> register() async {
    try {
      // iOS requires APNs token before FCM token — wait up to 5s
      if (Platform.isIOS) {
        String? apnsToken;
        for (int i = 0; i < 5; i++) {
          apnsToken = await _messaging.getAPNSToken();
          if (apnsToken != null) break;
          debugPrint('⏳ [FCM] Waiting for APNs token... attempt ${i + 1}/5');
          await Future.delayed(const Duration(seconds: 1));
        }
        if (apnsToken == null) {
          debugPrint('⚠️ [FCM] APNs token unavailable (Simulator?). Skipping registration.');
          return;
        }
        debugPrint('✅ [FCM] APNs token ready.');
      }

      final token = await _messaging.getToken();
      if (token == null) {
        debugPrint('⚠️ [FCM] FCM token is null — skipping registration');
        return;
      }
      await _registerToken(token);
    } catch (e) {
      debugPrint('❌ [FCM] Registration failed: $e');
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Unregister — call before logout
  // ───────────────────────────────────────────────────────────────────────────
  Future<void> unregister() async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      await _apiClient.post('oasis_mobile.api.fcm.unregister_device', {
        'fcm_token': token,
      });
      debugPrint('✅ [FCM] Token unregistered from ERPNext');
    } catch (e) {
      debugPrint('❌ [FCM] Unregister failed: $e');
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Internal: POST token + device info to ERPNext
  // ───────────────────────────────────────────────────────────────────────────
  Future<void> _registerToken(String token) async {
    String model = 'Unknown Device';
    final String os = Platform.isAndroid ? 'Android' : 'iOS';

    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        model = '${info.brand} ${info.model}';
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        model = info.name;
      }
    } catch (_) {}

    await _apiClient.post('oasis_mobile.api.fcm.register_device', {
      'fcm_token': token,
      'device_os': os,
      'device_model': model,
      'app_version': '1.0.0',
    });

    debugPrint('✅ [FCM] Token registered — OS: $os | Model: $model');
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Internal: Show local heads-up banner for foreground messages
  // ───────────────────────────────────────────────────────────────────────────
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          icon: '@mipmap/ic_launcher',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Internal: Deep-link router — navigate based on doctype from ERPNext payload
  //
  // ERPNext sends: { "doctype": "Quotation", "docname": "QTN-0001", ... }
  // ───────────────────────────────────────────────────────────────────────────
  void _handleDeepLink(String rawPayload) {
    try {
      final data = jsonDecode(rawPayload) as Map<String, dynamic>;
      final doctype = data['doctype'] as String?;
      final docname = data['docname'] as String?;

      debugPrint('🔗 [FCM DeepLink] doctype=$doctype docname=$docname');

      if (navigatorKey?.currentState == null || docname == null || docname.isEmpty) return;

      // Route based on doctype sent by ERPNext workflow hook
      switch (doctype) {
        case 'Quotation':
          navigatorKey!.currentState!.pushNamed(
            '/quotation-detail',
            arguments: docname,
          );
          break;
        case 'Sales Order':
          navigatorKey!.currentState!.pushNamed(
            '/sales-order-detail',
            arguments: docname,
          );
          break;
        case 'Delivery Note':
          navigatorKey!.currentState!.pushNamed(
            '/delivery-note-detail',
            arguments: docname,
          );
          break;
        case 'Purchase Order':
          navigatorKey!.currentState!.pushNamed(
            '/purchase-order-detail',
            arguments: docname,
          );
          break;
        case 'Material Request':
          navigatorKey!.currentState!.pushNamed(
            '/material-request-detail',
            arguments: docname,
          );
          break;
        case 'Journal Entry':
          navigatorKey!.currentState!.pushNamed(
            '/journal-entry-detail',
            arguments: docname,
          );
          break;
        case 'Payment Entry':
          navigatorKey!.currentState!.pushNamed(
            '/payment-entry-detail',
            arguments: docname,
          );
          break;
        case 'Sales Invoice':
          navigatorKey!.currentState!.pushNamed(
            '/sales-invoice-detail',
            arguments: docname,
          );
          break;
        default:
          // Fallback: go to dashboard
          navigatorKey!.currentState!.pushNamed('/dashboard');
      }
    } catch (e) {
      debugPrint('⚠️ [FCM DeepLink] Failed to parse payload: $e');
    }
  }
}
