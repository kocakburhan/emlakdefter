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
import 'core/utils/web_back_button_handler.dart';
import 'features/auth/providers/auth_provider.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('📩 Arka plan mesajı alındı: ${message.messageId}');
}

/// Uygulama başlatılırken restore edilmiş token ile user profilini alır
Future<UserProfile?> _restoreUserProfile() async {
  // Token restore edilmiş mi kontrol et
  final token = ApiClient.simpleAuthToken;
  if (token == null) return null;

  try {
    final response = await ApiClient.dio.get('/auth/me');
    if (response.statusCode == 200 && response.data != null) {
      return UserProfile.fromJson(response.data);
    }
  } catch (e) {
    debugPrint('⚠️ User profile restore edilemedi: $e');
  }
  return null;
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

    // Token restore edildikten sonra user profilini al (chat'te isMine için gerekli)
    final user = await _restoreUserProfile();
    if (user != null) {
      debugPrint('[App] User profile restored: ${user.id}');
    }
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

  // ── Web Browser Back Button Handler ──────────────────────────
  WebBackButtonHandler.initialize();
  debugPrint('[App] WebBackButtonHandler initialized');
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
