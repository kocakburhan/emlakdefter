import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../providers/tenant_provider.dart';

class TenantHomeTab extends ConsumerWidget {
  const TenantHomeTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tenantProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, // Tam genişlik doldursun
          children: [
            // Emlakçı Profilinin Tersine - Müşteri (Hoş Geldiniz) Başlığı
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Merhaba, Ev Sakinimiz", style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 14)),
                    const SizedBox(height: 4),
                    // Eğer Veri yükleniyorsa Gizem Hanım diye beklet. Yüklendiyse ismini Riverpod'dan al.
                    state.maybeWhen(
                       data: (info) => Text(info.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24)),
                       orElse: () => Text("Yükleniyor...", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24)),
                    ),
                  ],
                ),
                // İkon farklılığı (Site, Apartman değil)
                const CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.surface,
                  child: Icon(Icons.holiday_village, color: AppColors.accent, size: 28),
                )
              ],
            ),
            const SizedBox(height: 32),

            // Borç/Ödeme Kartı - Ana Uygulamanın en odak noktası burasıdır (B2C'nin amacı müşteriden Parayı Tahsil Ettiğinde kırmızı/yeşil yanmasıydı!)
            Expanded(
               child: state.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
                  error: (e, st) => Center(child: Text("Sunucu Hatası: $e")),
                  data: (info) {
                     // Ekranda koca borç çıkacak mı hesabı:
                     final hasDebt = info.currentDebt > 0;
                     
                     return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                           crossAxisAlignment: CrossAxisAlignment.stretch,
                           children: [
                              // "Ben hangi Sitedeyim?" Eklemesi - Kapsül (Şeffaf)
                              Container(
                                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                 decoration: BoxDecoration(color: AppColors.surface.withOpacity(0.5), borderRadius: BorderRadius.circular(16)),
                                 child: Row(
                                    children: [
                                       const Icon(Icons.location_on, color: AppColors.textBody, size: 20),
                                       const SizedBox(width: 8),
                                       Text("${info.propertyName} - ${info.unitNumber}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                                    ],
                                 ),
                              ),
                              const SizedBox(height: 24),
                              
                              // "Apple Cüzdan" Tarzı Koca Borç Gösterge Kartı!
                              Container(
                                 padding: const EdgeInsets.all(32), // B2B kartlarına kıyasla tüketiciye daha ferah/büyük cizildi!
                                 decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                       colors: hasDebt 
                                          ? [AppColors.error.withOpacity(0.85), AppColors.error.withOpacity(0.4)]  // Faturası/Borcu varsa Uyarı Kırmızısı renk cümbüşü!
                                          : [AppColors.success.withOpacity(0.85), AppColors.success.withOpacity(0.4)], // Temize çıktıysa (Ödediyse) Tatlı yeşil bahar havası.
                                       begin: Alignment.topLeft,
                                       end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(36),
                                    boxShadow: [
                                       BoxShadow(
                                          color: (hasDebt ? AppColors.error : AppColors.success).withOpacity(0.35),
                                          blurRadius: 35, offset: const Offset(0, 15)
                                       )
                                    ]
                                 ),
                                 child: Column(
                                    children: [
                                       Icon(hasDebt ? Icons.warning_amber_rounded : Icons.check_circle_outline, color: Colors.white, size: 56),
                                       const SizedBox(height: 16),
                                       Text(hasDebt ? "Cari Dönem Borcunuz" : "Borcunuz Bulunmuyor!", style: const TextStyle(color: Colors.white70, fontSize: 14)),
                                       const SizedBox(height: 8),
                                       Text("${info.currentDebt.toStringAsFixed(2)} ₺", style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.bold, letterSpacing: -1.5)),
                                       const SizedBox(height: 12),
                                       Text(hasDebt ? "Son Ödeme: ${info.dueDate}" : "Sonraki Tahakkuk: ${info.dueDate}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                    ]
                                 ),
                              ),
                              const SizedBox(height: 32),

                              // Yalnızca borç ödenmemişse 'IBAN ile Öde' Butonu
                              if (hasDebt) ...[
                                 ElevatedButton.icon(
                                    onPressed: () {
                                      // TODO: B2C Ödeme akışına (Kopyalama veya Ekstre yükleme simülasyonuna gider)
                                      _showMockPaymentDialog(context, ref);
                                    },
                                    style: ElevatedButton.styleFrom(
                                       backgroundColor: AppColors.accent,
                                       padding: const EdgeInsets.symmetric(vertical: 20),
                                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    ),
                                    icon: const Icon(Icons.payment, color: Colors.white),
                                    label: const Text("IBAN İle Ödeme Yap", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                 ),
                                 const SizedBox(height: 16),
                                 const Text("Not: Havale yaptıktan sonra alttaki menüden 'Ödemeler' sekmesine girerek banka dekontunuzu yükleyebilirsiniz.", textAlign: TextAlign.center, style: TextStyle(color: AppColors.textBody, fontSize: 12, height: 1.5)),
                              ] else ...[
                                 // Tüketici borcunu ödediğinde ona bir teşekkür ve motivasyon cümlesi çizer (Yeşil Kalp Kutusu):
                                 Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.success.withOpacity(0.3))),
                                    child: const Row(
                                       children: [
                                          Icon(Icons.volunteer_activism, color: AppColors.success),
                                          SizedBox(width: 12),
                                          Expanded(child: Text("Düzenli ödemeleriniz sayesinde binamız çok daha güzel! Teşekkür ederiz.", style: TextStyle(color: AppColors.success, height: 1.4, fontSize: 13))),
                                       ]
                                    )
                                 )
                              ]
                           ]
                        )
                     );
                  }
               )
            )
          ],
        ),
      ),
    );
  }

  // Sırf 'Wow Effect' Yaşansın Diye Emlakçıya giden Yapay (Mock) Ödeme Ekranı Testi
  void _showMockPaymentDialog(BuildContext context, WidgetRef ref) {
     showDialog(
       context: context,
       builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text("Ödeme Yapıldı mı?"),
          content: const Text("Eğer IBAN numarasına ödeme yaptıysanız uygulamanın nasıl tepki vereceğini / yeşile nasıl döneceğini test etmek için 'Mock Dekont Yükle / Ödedim' butonuna tıklayın!"),
          actions: [
             TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal Et")),
             ElevatedButton(
                onPressed: () {
                   Navigator.pop(ctx);
                   // Riverpod Asistanına (Zeka'ya) emri fırlat: BORCU SIFIRLA!
                   ref.read(tenantProvider.notifier).payDebtMock();
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Test Başarılı! Yapay zeka onayladı; Borcunuz Animasyonla sıfırlandı."), backgroundColor: AppColors.success));
                },
                child: const Text("Evet Ödedim (Animasyonu Başlat)")
             )
          ]
       )
     );
  }
}
