import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../providers/tenant_provider.dart';

class TenantHomeTab extends ConsumerWidget {
  const TenantHomeTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tenantProvider);
    final financeAsync = ref.watch(tenantFinanceProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Merhaba, Ev Sakinimiz", style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 14)),
                    const SizedBox(height: 4),
                    state.maybeWhen(
                       data: (info) => Text(info?.name ?? 'Kiracı', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24)),
                       orElse: () => Text("Yükleniyor...", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24)),
                    ),
                  ],
                ),
                const CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.surface,
                  child: Icon(Icons.holiday_village, color: AppColors.accent, size: 28),
                )
              ],
            ),
            const SizedBox(height: 32),

            Expanded(
               child: state.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
                  error: (e, st) => Center(child: Text("Sunucu Hatası: $e")),
                  data: (info) {
                     // API'den gelen finans özetini dinle
                     final finance = financeAsync.value;
                     final hasDebt = (finance?.currentDebt ?? 0) > 0;
                     final debt = finance?.currentDebt ?? 0;
                     final nextDue = finance?.nextDueDate;
                     final nextAmount = finance?.nextDueAmount;

                     return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                           crossAxisAlignment: CrossAxisAlignment.stretch,
                           children: [
                              // Konum bilgisi
                              Container(
                                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                 decoration: BoxDecoration(
                                    color: AppColors.surface.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(16)
                                 ),
                                 child: Row(
                                    children: [
                                       const Icon(Icons.location_on, color: AppColors.textBody, size: 20),
                                       const SizedBox(width: 8),
                                       Expanded(
                                         child: Text(
                                           "${info?.propertyName ?? ''} ${info?.unitNumber ?? ''}",
                                           style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)
                                         ),
                                       ),
                                    ],
                                 ),
                              ),
                              const SizedBox(height: 24),

                              // Apple Cüzdan Tarzı Borç Kartı
                              Container(
                                 padding: const EdgeInsets.all(32),
                                 decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                       colors: hasDebt
                                          ? [AppColors.error.withOpacity(0.85), AppColors.error.withOpacity(0.4)]
                                          : [AppColors.success.withOpacity(0.85), AppColors.success.withOpacity(0.4)],
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
                                       Text("${debt.toStringAsFixed(2)} ₺", style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.bold, letterSpacing: -1.5)),
                                       const SizedBox(height: 12),
                                       Text(
                                         hasDebt
                                            ? (nextDue != null ? "Son Ödeme: $nextDue" : "Ödeme bekleniyor")
                                            : (nextAmount != null ? "Sonraki Tahakkuk: $nextAmount ₺" : "Her şey tertemiz!"),
                                         style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)
                                       ),
                                    ]
                                 ),
                              ),
                              const SizedBox(height: 32),

                              if (hasDebt) ...[
                                 ElevatedButton.icon(
                                    onPressed: () => _showMockPaymentDialog(context),
                                    style: ElevatedButton.styleFrom(
                                       backgroundColor: AppColors.accent,
                                       padding: const EdgeInsets.symmetric(vertical: 20),
                                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    ),
                                    icon: const Icon(Icons.payment, color: Colors.white),
                                    label: const Text("IBAN İle Ödeme Yap", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                 ),
                                 const SizedBox(height: 16),
                                 const Text(
                                   "Not: Havale yaptıktan sonra 'Ödemeler' sekmesinden banka dekontunuzu yükleyebilirsiniz.",
                                   textAlign: TextAlign.center,
                                   style: TextStyle(color: AppColors.textBody, fontSize: 12, height: 1.5)
                                 ),
                              ] else ...[
                                 Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                       color: AppColors.success.withOpacity(0.1),
                                       borderRadius: BorderRadius.circular(16),
                                       border: Border.all(color: AppColors.success.withOpacity(0.3))
                                    ),
                                    child: const Row(
                                       children: [
                                          Icon(Icons.volunteer_activism, color: AppColors.success),
                                          SizedBox(width: 12),
                                          Expanded(child: Text(
                                            "Düzenli ödemeleriniz sayesinde binamız çok daha güzel! Teşekkür ederiz.",
                                            style: TextStyle(color: AppColors.success, height: 1.4, fontSize: 13)
                                          )),
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

  void _showMockPaymentDialog(BuildContext context) {
     showDialog(
       context: context,
       builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text("Ödeme Bildirimi"),
          content: const Text("Banka havalesi yaptıysanız, dekont yüklemek için 'Ödemeler' sekmesine gidiniz. Tahsilat onaylandığında borcunuz otomatik güncellenecektir."),
          actions: [
             TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Tamam")),
          ]
       )
     );
  }
}
