import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../providers/dashboard_provider.dart';

class HomeTab extends ConsumerWidget {
  const HomeTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Merkezi Riverpod Kamerasını Dashboard verilerine (Para, Arıza vb.) dikiyoruz!
    final dashboardState = ref.watch(dashboardProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sağ üstte Profil, Solda Merhaba yazısı
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Merhaba, Sayın Yönetici", style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 14)),
                    const SizedBox(height: 4),
                    Text("Finansal Özetiniz", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24)),
                  ],
                ),
                const CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.surface,
                  child: Icon(Icons.apartment, color: AppColors.accent, size: 28),
                )
              ],
            ),
            const SizedBox(height: 32),
            
            // Eğer Veri yükleniyorsa spinner, geldiyse Harika KPI kartları çizdir!
            dashboardState.when(
              loading: () => const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.accent))),
              error: (err, stack) => Expanded(child: Center(child: Text('Hata: $err', style: const TextStyle(color: AppColors.error)))),
              data: (metrics) => Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                       // Büyük "Wow Effect" Tahsilat Kartı (Apple Wallet Tarzı)
                       _buildHeroCard(
                         context, 
                         title: "Aylık Toplanan Aidat / Kira", 
                         value: "${metrics.totalRevenue.toStringAsFixed(2)} ₺", 
                         subtitle: "Mükemmel Tahsilat Oranı: %${metrics.collectionRate}"
                       ),
                       const SizedBox(height: 16),
                       
                       // Bina (Properties) ve Boş Daire Kartı
                       Row(
                         children: [
                            Expanded(child: _buildMiniKpiCard(context, icon: Icons.business, title: "Siteniz / Binanız", value: "${metrics.activeProperties}", color: AppColors.accent)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildMiniKpiCard(context, icon: Icons.door_back_door, title: "Boştaki Daire", value: "${metrics.emptyUnits}", color: AppColors.warning)),
                         ],
                       ),
                       const SizedBox(height: 16),
                       
                       // Çözüm Bekleyen Acil (Arıza/Tickets) Kartı
                       Container(
                         padding: const EdgeInsets.all(20),
                         decoration: BoxDecoration(
                           color: AppColors.surface.withOpacity(0.4),
                           borderRadius: BorderRadius.circular(20),
                           border: Border.all(color: AppColors.error.withOpacity(0.3)),
                         ),
                         child: Row(
                           children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: AppColors.error.withOpacity(0.15), shape: BoxShape.circle),
                                child: const Icon(Icons.warning_rounded, color: AppColors.error),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                     Text("Çözüm Bekleyen", style: Theme.of(context).textTheme.bodyLarge),
                                     Text("${metrics.pendingTickets} Arıza/Bilet", style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.error, fontSize: 18)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: AppColors.textBody),
                           ],
                         ),
                       ),
                       
                       // Alt navigasyon barı üst kapatmasın diye boşluk
                       const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, {required String title, required String value, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.accent.withOpacity(0.8), AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
           BoxShadow(color: AppColors.accent.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
               const Icon(Icons.account_balance_wallet, color: Colors.white70),
               const SizedBox(width: 8),
               Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 16),
          Text(value, style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 36, color: Colors.white)),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMiniKpiCard(BuildContext context, {required IconData icon, required String title, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Icon(icon, color: color, size: 28),
           const SizedBox(height: 12),
           Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24, color: Colors.white)),
           const SizedBox(height: 4),
           Text(title, style: const TextStyle(color: AppColors.textBody)),
        ],
      ),
    );
  }
}
