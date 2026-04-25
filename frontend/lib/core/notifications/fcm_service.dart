import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../network/api_client.dart';

/// FCM Push Bildirim Servisi — PRD §4.2.2-F, §5
///
/// Şunları yönetir:
/// 1. Bildirim izni alma
/// 2. FCM token alma ve backend'e kaydetme
/// 3. Ön plan bildirimlerini işleme
/// 4. Arka plan bildirimleri için callback
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // Bildirim callback'leri
  void Function(RemoteMessage)? onMessageReceived;
  void Function(String? token)? onTokenRefreshed;

  /// Sadece token'ı backend'e kaydet (initialize'dan bağımsız)
  Future<void> registerToken() async {
    await _registerToken();
  }

  /// Uygulama başlatıldığında çağrılmalı.
  /// Bildirim iznini alır, token'ı backend'e kaydeder.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // ── Local notifications (Android) ──────────────────────────
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    _local.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // ── Bildirim izni ──────────────────────────────────────────
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[FCM] Bildirim izni reddedildi');
      return;
    }
    debugPrint('[FCM] Bildirim izni: ${settings.authorizationStatus}');

    // ── Token al ve backend'e kaydet ──────────────────────────
    await _registerToken();

    // ── Token yenileme dinle ────────────────────────────────────
    _messaging.onTokenRefresh.listen((token) {
      debugPrint('[FCM] Token yenilendi: ${token.substring(0, 20)}...');
      _registerToken();
      onTokenRefreshed?.call(token);
    });

    // ── Ön plan bildirimlerini dinle ─────────────────────────
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // ── Arka plan / terminated bildirimler için ────────────────
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Uygulama terminate edilmişken açıldığında bildirim var mı kontrol et
    final initialMsg = await _messaging.getInitialMessage();
    if (initialMsg != null) {
      _handleMessageOpenedApp(initialMsg);
    }
  }

  Future<void> _registerToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[FCM] Token alınamadı');
        return;
      }

      debugPrint('[FCM] Token: ${token.substring(0, 20)}...');

      // 🛑 Kullanıcı giriş yapmış mı kontrol et
      final hasValidToken = ApiClient.dio.options.headers.containsKey('Authorization') ||
                            ApiClient.dio.options.headers['Authorization'] != null;

      if (hasValidToken) {
        await ApiClient.dio.post('/auth/fcm-token', data: {
          'fcm_token': token,
          'device_type': _deviceType,
        });
        debugPrint('[FCM] Token backend\'e kaydedildi');
      } else {
        debugPrint('[FCM] Kullanıcı misafir (giriş yapmamış), token backend\'e gönderilmedi.');
      }

    } catch (e) {
      debugPrint('[FCM] Token kayıt hatası: $e');
    }
  }

  String get _deviceType {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  }

  void _handleForegroundMessage(RemoteMessage msg) {
    debugPrint('[FCM] Ön plan mesajı: ${msg.notification?.title}');
    _showLocalNotification(msg);
    onMessageReceived?.call(msg);
  }

  void _handleMessageOpenedApp(RemoteMessage msg) {
    debugPrint('[FCM] Bildirimden açıldı: ${msg.data}');
    onMessageReceived?.call(msg);
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    debugPrint('[FCM] Local bildirim tap: ${response.payload}');
  }

  Future<void> _showLocalNotification(RemoteMessage msg) async {
    const androidDetails = AndroidNotificationDetails(
      'emlakdefter_alerts',
      'Emlakdefter Bildirimleri',
      channelDescription: 'Emlakdefter uygulama bildirimleri',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _local.show(
      msg.hashCode,
      msg.notification?.title ?? '',
      msg.notification?.body ?? '',
      details,
      payload: msg.data['ticket_id'] ?? msg.data['conversation_id'],
    );
  }

  /// Bildirim open durumunu temizle (uygulama açıldığında)
  Future<void> clearBadge() async {
    await _local.cancelAll();
  }
}

/// ──────────────────────────────────────────────
/// Arka plan mesaj handler (main.dart'da kullanılır)
/// ──────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[FCM] Background handler tetiklendi: ${message.messageId}');
}