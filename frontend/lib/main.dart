import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/router/router.dart';
import 'core/offline/offline_storage.dart';
import 'core/offline/connectivity_service.dart';
import 'core/offline/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase'i platform yapılandırmasıyla başlat
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    debugPrint('🔥 Firebase Motoru Başarıyla Bağlandı!');
  } catch (e) {
    debugPrint('⚠️ Firebase Başlatılamadı: $e');
  }

  // ── Offline Altyapı (§5) ──────────────────────────────────────
  // 1. Hive + Boxes açılır
  await OfflineStorage().initialize();
  debugPrint('[App] OfflineStorage initialized');

  // 2. Connectivity izlemeye başlar
  await ConnectivityService().initialize();
  debugPrint('[App] ConnectivityService initialized');

  // 3. SyncService wiring — bağlantı geldiğinde auto-sync tetiklenir
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
      theme: AppTheme.darkTheme,
      routerConfig: appRouter,
    );
  }
}
