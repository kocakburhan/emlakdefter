import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/router/router.dart';
import 'core/offline/offline_storage.dart';
import 'core/offline/connectivity_service.dart';
import 'core/offline/sync_service.dart';
import 'core/notifications/fcm_service.dart';
import 'core/network/api_client.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('📩 Arka plan mesajı alındı: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool isFirebaseInitialized = false;

  // Firebase Başlatma
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    isFirebaseInitialized = true;
    debugPrint('🔥 Firebase Motoru Başarıyla Bağlandı!');
  } catch (e) {
    debugPrint('⚠️ Firebase Başlatılamadı: $e');
  }

  // ── Firebase'e Bağlı Servislerin Başlatılması ──────────────────
  if (isFirebaseInitialized) {
    // 2. APP CHECK GÜVENLİ BLOĞA TAŞINDI
    try {
      await FirebaseAppCheck.instance.activate(
        providerWeb: ReCaptchaEnterpriseProvider(
          '6LfHH8gsAAAAAD8ZZHaen-KpP0U2P4Hug4vrAY5e',
        ),
      );
      debugPrint('🛡️ App Check (reCAPTCHA) Başarıyla Aktifleştirildi!');
    } catch (e) {
      debugPrint('⚠️ App Check Başlatılamadı: $e');
    }

    // ── Token Geri Yükleme ───────────────────────────────────────
    await ApiClient.restoreToken();
    debugPrint('[App] Auth token restored');
    // ─────────────────────────────────────────────────────────────

    // FCM Push Bildirimleri
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await FCMService().initialize();
    debugPrint('[App] FCM Service initialized');
  } else {
    debugPrint(
      '[App] Firebase çalışmadığı için bağlı servisler (App Check, FCM) başlatılmadı.',
    );
  }
  // ─────────────────────────────────────────────────────────────

  // ── Offline Altyapı ──────────────────────────────────────────
  await OfflineStorage().initialize();
  debugPrint('[App] OfflineStorage initialized');

  await ConnectivityService().initialize();
  debugPrint('[App] ConnectivityService initialized');

  await SyncService().initialize();
  debugPrint('[App] SyncService initialized');
  // ─────────────────────────────────────────────────────────────

  runApp(const ProviderScope(child: EmlakdefterApp()));
}

class EmlakdefterApp extends ConsumerWidget {
  const EmlakdefterApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Emlakdefter',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
    );
  }
}
