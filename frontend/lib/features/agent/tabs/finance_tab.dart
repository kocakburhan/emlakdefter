import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../providers/finance_provider.dart';
import '../screens/mali_rapor_screen.dart';

class FinanceTab extends ConsumerWidget {
  const FinanceTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Saniye saniye AI Taraması yapılıp yapılmadığını izleyen Riverpod izleyicilerimiz
    final financeState = ref.watch(financeProvider);
    final notifier = ref.read(financeProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Yapay Zeka (Gemini) Destekli", style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 14, color: AppColors.accent)),
                    const SizedBox(height: 4),
                    Text("Banka & Finans", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24)),
                  ],
                ),
                IconButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const MaliRaporScreen()));
                  },
                  icon: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.bar_chart_rounded, color: AppColors.accent, size: 22),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // "Ekstre Yükle" Alanı (Bulutumsu Dosya Upload Tasarımı)
            _buildUploadZone(context, financeState, notifier),
            const SizedBox(height: 24),

            // O Gelen İşlemlerin Göktuğ'dan Yağan Listesi
            Expanded(
              child: financeState.when(
                loading: () => const Center(
                   child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                         CircularProgressIndicator(color: AppColors.accent),
                         SizedBox(height: 24),
                         Text("Gemini 2.5 Flash Analiz Ediyor...", style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 16)),
                         SizedBox(height: 8),
                         Text("Bulanık mantık motoru çalıştırılıyor", style: TextStyle(color: AppColors.textBody, fontSize: 12))
                      ]
                   )
                ),
                error: (e, st) => Center(child: Text("Hata: $e", style: const TextStyle(color: AppColors.error))),
                data: (list) {
                  // İlk giriş (Bomboş Ekran)
                  if (list.isEmpty) {
                     return const Center(child: Text("Hiçbir banka ekstresi taranmadı.\nYukarıdaki panele basarak test işlemini başlatın.", textAlign: TextAlign.center, style: TextStyle(color: AppColors.textBody, height: 1.5)));
                  }

                  // Sarı(Onay Bekleyenler DİKKAT ÇEKSİN) en üstte Listelensin diye Sıralama Mantığı
                  final sortedList = List<TransactionModel>.from(list)..sort((a,b) {
                     if (a.status == MatchStatus.pending && b.status != MatchStatus.pending) return -1;
                     if (a.status != MatchStatus.pending && b.status == MatchStatus.pending) return 1;
                     return 0;
                  });

                  return ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: sortedList.length + 1,
                    separatorBuilder: (ctx, idx) => const SizedBox(height: 16),
                    itemBuilder: (ctx, idx) {
                       if (idx == sortedList.length) return const SizedBox(height: 120);
                       return _buildTransactionCard(context, sortedList[idx], notifier);
                    },
                  );
                }
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Yükleme Kutusu UI Parçası (Dashed - Cizgi çizgi kaplama)
  Widget _buildUploadZone(BuildContext context, AsyncValue<List<TransactionModel>> state, FinanceNotifier notifier) {
    final isLoading = state is AsyncLoading;
    final hasData = state.value?.isNotEmpty ?? false;

    return InkWell(
      onTap: isLoading ? null : () => notifier.uploadBankStatement(),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        height: hasData ? 120 : 200, // Eğer altı dolduysa üstü daralt ki PDF listesi rahat okunsun!
        decoration: BoxDecoration(
           color: isLoading ? AppColors.accent.withValues(alpha:0.1) : AppColors.surface.withValues(alpha:0.3),
           borderRadius: BorderRadius.circular(20),
           border: Border.all(color: AppColors.accent.withValues(alpha:0.5), width: 1.5, style: BorderStyle.solid), // Fazla uzatmamak için solid çizdim
        ),
        child: Column(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
              Icon(hasData ? Icons.refresh : Icons.cloud_upload_outlined, color: AppColors.accent, size: hasData ? 32 : 56),
              const SizedBox(height: 12),
              Text(
                 isLoading ? "Ekstre Sunucuya İletildi..." : (hasData ? "Yeni Ay Ekstresi Yükle" : "PDF Ekstresi Yükle veya Çek"),
                 style: TextStyle(color: isLoading ? AppColors.accent : AppColors.textHeader, fontSize: hasData ? 16 : 18, fontWeight: FontWeight.bold)
              ),
              if (!isLoading && !hasData)
                 const Padding(
                   padding: EdgeInsets.only(top: 8.0),
                   child: Text("Siz bırakın, Yapay Zeka (AI) kim kime ne kadar ödemiş eşleştirsin.", style: TextStyle(color: AppColors.textBody, fontSize: 13), textAlign: TextAlign.center),
                 )
           ]
        ),
      ),
    );
  }

  // Dekont Satırları Çizimi
  Widget _buildTransactionCard(BuildContext context, TransactionModel trx, FinanceNotifier notifier) {
     final bool isPending = trx.status == MatchStatus.pending;
     final Color cardColor = isPending ? AppColors.warning : AppColors.success;
     
     return Container(
       padding: const EdgeInsets.all(16),
       decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha:0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardColor.withValues(alpha:isPending ? 0.7 : 0.2), width: isPending ? 1.5 : 1.0),
       ),
       child: Column(
          children: [
             Row(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                  Container( // İkon yuvarlağı
                     padding: const EdgeInsets.all(12),
                     decoration: BoxDecoration(color: cardColor.withValues(alpha:0.15), shape: BoxShape.circle),
                     child: Icon(isPending ? Icons.warning_amber_rounded : Icons.check_circle_outline, color: cardColor),
                  ),
                  const SizedBox(width: 16),
                  Expanded( // Metin ve İsim (Kalın)
                     child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           Text(trx.senderName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16)),
                           const SizedBox(height: 4),
                           Text(trx.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textBody)),
                        ]
                     )
                  ),
                  const SizedBox(width: 12),
                  Column( // Miktar
                     crossAxisAlignment: CrossAxisAlignment.end,
                     children: [
                        Text("${trx.amount} ₺", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textHeader)),
                        const SizedBox(height: 4),
                        Text(trx.date, style: const TextStyle(fontSize: 12, color: AppColors.textBody)),
                     ]
                  )
               ],
             ),

             // Eğer Uyarı Yanmış Bir Dekontsa Altta Eklenti (Onay Barı) Çizilir
             if (isPending) ...[
                const SizedBox(height: 20),
                Container(
                   decoration: BoxDecoration(color: AppColors.warning.withValues(alpha:0.1), borderRadius: BorderRadius.circular(12)),
                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                   child: Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                        Row(
                          children: [
                            const Icon(Icons.psychology, color: AppColors.warning, size: 20),
                            const SizedBox(width: 8),
                            Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                  Text("AI Çelişkisi (%${trx.aiConfidence})", style: const TextStyle(color: AppColors.warning, fontSize: 14, fontWeight: FontWeight.bold)),
                                  const Text("Soyadı uyumlu değil.", style: TextStyle(color: AppColors.warning, fontSize: 11)),
                               ],
                            )
                          ]
                        ),
                        InkWell(
                           onTap: () => notifier.approveTransaction(trx.id),
                           child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(color: AppColors.warning.withValues(alpha:0.2), borderRadius: BorderRadius.circular(12)),
                              child: const Text("Teyit Et (Eşle)", style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold, fontSize: 13)),
                           ),
                        )
                     ],
                   ),
                )
             ]
          ],
       ),
     );
  }
}
