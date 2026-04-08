import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/router/router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase'i platform yapılandırmasıyla başlat (flutterfire configure ile oluşturuldu)
  try {
     await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
     debugPrint("🔥 Firebase Motoru Başarıyla Bağlandı!");
  } catch (e) {
     debugPrint("⚠️ Firebase Başlatılamadı: $e");
  }

  // Tüm yazılımı "ProviderScope" ile sardık; bu sayede projenin HER YERİNDEN State değerlerine ulaşacağız.
  runApp(const ProviderScope(child: EmlakdefteriApp()));
}

class EmlakdefteriApp extends ConsumerWidget {
  const EmlakdefteriApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Emlakdefteri',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: appRouter,
    );
  }
}
