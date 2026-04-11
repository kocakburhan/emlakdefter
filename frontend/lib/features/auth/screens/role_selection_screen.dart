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
                  Text("Emlakdefter.", style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 42, color: AppColors.textHeader, letterSpacing: -1)),
                  const SizedBox(height: 12),
                  Text("Mülk Portföyü Yönetiminde ve \nKiracı İletişiminde Yeni Standart.", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18, color: AppColors.textBody, height: 1.4)),
                  const Spacer(),
                  
                  // ----- Emlakçı B2B Paneli -----
                  _RoleCard(
                    title: "Emlakçı",
                    description: "Portföy yönet, fatura tarat, kiracı takip et.",
                    icon: Icons.business,
                    color: AppColors.accent,
                    onTap: () {
                      context.push('/login?role=agent');
                    },
                  ),
                  const SizedBox(height: 16),

                  // ----- Kiracı B2C Yüzü -----
                  _RoleCard(
                    title: "Kiracı",
                    description: "Aidat öde, arıza bildir, mesajlaş.",
                    icon: Icons.person,
                    color: AppColors.success,
                    onTap: () {
                      context.push('/login?role=tenant');
                    },
                  ),
                  const SizedBox(height: 16),

                  // ----- Ev Sahibi -----
                  _RoleCard(
                    title: "Ev Sahibi",
                    description: "Mülklerini takip et, gelir/gider raporlarına bak.",
                    icon: Icons.holiday_village,
                    color: AppColors.warning,
                    onTap: () {
                      context.push('/login?role=landlord');
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
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({Key? key, required this.title, required this.description, required this.icon, required this.color, required this.onTap}) : super(key: key);

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
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
             Container(
               padding: const EdgeInsets.all(14),
               decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
               child: Icon(icon, color: color, size: 28),
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
             Icon(Icons.arrow_forward_ios, color: color, size: 16),
          ],
        ),
      ),
    );
  }
}
