import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/colors.dart';
import '../../../core/network/api_client.dart';
import '../providers/tenant_provider.dart';

class TenantFinanceTab extends ConsumerStatefulWidget {
  const TenantFinanceTab({Key? key}) : super(key: key);

  @override
  ConsumerState<TenantFinanceTab> createState() => _TenantFinanceTabState();
}

class _TenantFinanceTabState extends ConsumerState<TenantFinanceTab> {
  @override
  Widget build(BuildContext context) {
    final txAsync = ref.watch(tenantTransactionsProvider);
    final financeAsync = ref.watch(tenantFinanceProvider);

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

            // AI Dekont Yükleme Dropzone
            _buildUploadReceiptBox(context),
            const SizedBox(height: 32),

            // Borç durumu
            financeAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (finance) {
                if (finance == null || finance.currentDebt <= 0) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha:0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.error.withValues(alpha:0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Ödenmemiş borcunuz: ${finance.currentDebt.toStringAsFixed(2)} ₺",
                          style: const TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Geçmiş Ekstreler başlığı
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                 const Text("Geçmiş Ekstreler", style: TextStyle(color: AppColors.textHeader, fontSize: 18, fontWeight: FontWeight.bold)),
                 Icon(Icons.history, color: AppColors.textBody.withValues(alpha:0.5)),
              ],
            ),
            const SizedBox(height: 16),

            Expanded(
               child: txAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
                  error: (e, _) => Center(child: Text('Yüklenemedi: $e', style: const TextStyle(color: AppColors.error))),
                  data: (transactions) {
                    if (transactions.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_rounded, color: AppColors.textBody.withValues(alpha:0.3), size: 64),
                            const SizedBox(height: 16),
                            Text(
                              'Henüz işlem kaydınız bulunmuyor.\nDekont yükleyerek başlayın.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textBody.withValues(alpha:0.5), fontSize: 14, height: 1.5),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: transactions.length + 1,
                      itemBuilder: (ctx, i) {
                        if (i == transactions.length) return const SizedBox(height: 100);
                        return _buildTransactionItem(transactions[i]);
                      },
                    );
                  },
               ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildUploadReceiptBox(BuildContext context) {
      return InkWell(
         onTap: () => _pickAndUploadReceipt(context),
         borderRadius: BorderRadius.circular(24),
         child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
               color: AppColors.accent.withValues(alpha:0.1),
               borderRadius: BorderRadius.circular(24),
               border: Border.all(color: AppColors.accent.withValues(alpha:0.4), width: 1.5),
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
                  const Text("EFT/Havale yaptıysanız makbuzu buradan yükleyin. AI sistemimiz onu okuyup Emlakçınıza iletecektir.", textAlign: TextAlign.center, style: TextStyle(color: AppColors.textBody, fontSize: 13, height: 1.4)),
               ]
            )
         ),
      );
  }

  Future<void> _pickAndUploadReceipt(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dosya seçilemedi'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Dekont yükleniyor...'),
        backgroundColor: AppColors.accent,
        duration: Duration(seconds: 1),
      ),
    );

    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path!),
      });
      final resp = await ApiClient.dio.post(
        '/finance/upload-statement',
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 60),
        ),
      );
      if (resp.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Dekont başarıyla yüklendi! Emlakçınız inceleyecek.'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Yükleme hatası: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildTransactionItem(TransactionItem tx) {
    final isIncome = tx.type == 'income';
    final color = isIncome ? AppColors.success : AppColors.error;
    final icon = isIncome ? Icons.arrow_downward : Icons.arrow_upward;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha:0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha:0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _categoryLabel(tx.category),
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '${tx.transactionDate.day.toString().padLeft(2, '0')}.${tx.transactionDate.month.toString().padLeft(2, '0')}.${tx.transactionDate.year}',
                  style: const TextStyle(color: AppColors.textBody, fontSize: 12),
                ),
                if (tx.description != null && tx.description!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(tx.description!, style: TextStyle(color: AppColors.textBody.withValues(alpha:0.6), fontSize: 11)),
                ],
              ],
            ),
          ),
          Text(
            '${isIncome ? '+' : '-'}${tx.amount.toStringAsFixed(2)} ₺',
            style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _categoryLabel(String category) {
    switch (category) {
      case 'rent': return 'Kira Ödemesi';
      case 'dues': return 'Aidat Ödemesi';
      case 'utility': return 'Fatura / Utilities';
      case 'maintenance': return 'Bakım / Onarım';
      case 'commission': return 'Komisyon';
      case 'expense': return 'Gider';
      default: return 'İşlem';
    }
  }
}
