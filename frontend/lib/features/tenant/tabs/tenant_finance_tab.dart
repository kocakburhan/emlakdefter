import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';

// Kiracı Tarafının (B2C) Banka Dekontu/PDF Yükleme "Upload Zone" ve Ekstre Kartları
class TenantFinanceTab extends ConsumerWidget {
  const TenantFinanceTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Text("Sonraki Adım: Banka Dekontunuzu İletin", style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 14)),
            const SizedBox(height: 4),
            Text("Ödemeler ve Makbuzlar", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24)),
            const SizedBox(height: 32),

            // Koca Dekont Yükleme 'Upload' Damla Kutusu (Dropzone)
            // Lort Tarafındaki AI Gemini sürecinin Kullanıcı/Kiracı versiyonudur.
            _buildUploadReceiptBox(context),
            const SizedBox(height: 32),
            
            // Önceki Ödemelerim Başlığı (Tarihçe)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                 const Text("Geçmiş Ekstreler", style: TextStyle(color: AppColors.textHeader, fontSize: 18, fontWeight: FontWeight.bold)),
                 Icon(Icons.history, color: AppColors.textBody.withOpacity(0.5)),
              ],
            ),
            const SizedBox(height: 16),
            
            Expanded(
               child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                     // Başarılı Mock Geçmiş Ay Verileri
                     _buildPastReceiptItem(context, "Mart Ayı Kirası / Aidatı", "17.500 ₺", "14 Mart 2026", true),
                     const SizedBox(height: 12),
                     _buildPastReceiptItem(context, "Şubat Kira + Yakıt", "16.800 ₺", "15 Şubat 2026", true),
                     const SizedBox(height: 12),
                     _buildPastReceiptItem(context, "Ocak (Yılbaşı Öncesi)", "15.000 ₺", "15 Ocak 2026", true),
                     const SizedBox(height: 100), // Bottom nav (Alt menü tepsisi) için ekstra Scroll payı
                  ],
               )
            )
          ],
        ),
      ),
    );
  }

  // Kiracı için Dekont Yükleme Buton/Hover Parçası
  Widget _buildUploadReceiptBox(BuildContext context) {
      return InkWell(
         onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: AppColors.accent, content: Text("Mobil Cihaz Dosya(PDF) Yöneticisi Açılıyor...")));
         },
         borderRadius: BorderRadius.circular(24),
         child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
               color: AppColors.accent.withOpacity(0.1), // Tüketiciyi içeriçeken (Call To Action) dikkat çekici mavi arka plan
               borderRadius: BorderRadius.circular(24),
               border: Border.all(color: AppColors.accent.withOpacity(0.4), width: 1.5), 
            ),
            child: Column(
               children: [
                  Container(
                     padding: const EdgeInsets.all(16),
                     decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                     child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 16),
                  const Text("Yeni Dekont / Makbuz Yükle", style: TextStyle(color: AppColors.accent, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text("EFT/Havale yaptıysanız makbuzu buradan yükleyin. Finans Yapay Zekamız (AI) onu okuyup Emlakçınıza iletecektir.", textAlign: TextAlign.center, style: TextStyle(color: AppColors.textBody, fontSize: 13, height: 1.4)),
               ]
            )
         ),
      );
  }

  // "Eskiden bu paraları ödemiştin ve makbuzu Lort tarafından onaylanmıştı" bilgisini veren Tarihçe satırları:
  Widget _buildPastReceiptItem(BuildContext context, String title, String amount, String date, bool isVerified) {
     return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface.withOpacity(0.5), borderRadius: BorderRadius.circular(16)),
        child: Row(
           children: [
              Container( // Yeşil Check veya Sarı Pending yuvarlağı
                 padding: const EdgeInsets.all(12),
                 decoration: BoxDecoration(color: isVerified ? AppColors.success.withOpacity(0.1) : AppColors.warning.withOpacity(0.1), shape: BoxShape.circle),
                 child: Icon(isVerified ? Icons.check_circle_outline : Icons.pending_actions, color: isVerified ? AppColors.success : AppColors.warning),
              ),
              const SizedBox(width: 16),
              Expanded(
                 child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                       const SizedBox(height: 4),
                       Text(date, style: const TextStyle(color: AppColors.textBody, fontSize: 12)),
                    ]
                 )
              ),
              Text(amount, style: const TextStyle(color: AppColors.textHeader, fontSize: 16, fontWeight: FontWeight.bold)),
           ]
        ),
     );
  }
}
