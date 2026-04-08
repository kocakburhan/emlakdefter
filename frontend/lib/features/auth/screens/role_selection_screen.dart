import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import '../../../core/theme/colors.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Sol Üstten Arka Plana Glow (Parlayan Şık Yuvarlaklar) Işıkları
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.accent.withOpacity(0.2)),
            ),
          ),
          // Alt Sağdan Parlayan Zümrüt Yeşili
          Positioned(
            bottom: -50,
            left: -150,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.success.withOpacity(0.1)),
            ),
          ),
          
          // Efsanevi Cam (Blur/Glassmorphism) Maskesi
          Positioned.fill(
            child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70), child: const SizedBox()),
          ),
          
          // Asıl Okunabilir Yüzey İçeriği
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 80),
                  Text("Emlakdefteri.", style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 42, color: AppColors.textHeader, letterSpacing: -1)),
                  const SizedBox(height: 12),
                  Text("Mülk Portföyü Yönetiminde ve \nKiracı İletişiminde Yeni Standart.", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18, color: AppColors.textBody, height: 1.4)),
                  const Spacer(),
                  
                  // ----- Emlakçı B2B Paneli -----
                  _RoleCard(
                    title: "Kurumsal Yönetici / Lort",
                    description: "Binaları tescilleyin, finans dekontlarını tarayın ve arızaları çözün.",
                    icon: Icons.business,
                    onTap: () {
                      context.push('/login?role=agent'); // Emlakçı olarak Telefon numarası sorma ekranı
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // ----- Kiracı B2C Yüzü -----
                  _RoleCard(
                    title: "Ev Sahibi / Kira Sürecindeki Sakin",
                    description: "Uygulama üzerinden aidatlarınızı ödeyin, daire arıza biletlerinizi (Şikayet) anında iletin.",
                    icon: Icons.holiday_village,
                    onTap: () {
                      context.push('/login?role=tenant'); // Kiracı olarak Telefon numarası sorma ekranı
                    },
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Kart Tasarımımız (Ekranda 2 Adet Çizdirilen Gövde)
class _RoleCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const _RoleCard({Key? key, required this.title, required this.description, required this.icon, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)), // Ince beyaz strok
        ),
        child: Row(
          children: [
             Container(
               padding: const EdgeInsets.all(14),
               decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.15), shape: BoxShape.circle),
               child: Icon(icon, color: AppColors.accent, size: 28),
             ),
             const SizedBox(width: 20),
             Expanded(
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18)),
                    const SizedBox(height: 6),
                    Text(description, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 13, height: 1.3)),
                 ],
               )
             ),
             const Icon(Icons.arrow_forward_ios, color: AppColors.textBody, size: 16),
          ],
        ),
      ),
    );
  }
}
