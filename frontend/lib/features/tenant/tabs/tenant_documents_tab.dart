import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../providers/tenant_provider.dart';

/// Belgelerim — Salt-okunur dijital arşiv (PRD §4.2.3)
class TenantDocumentsTab extends ConsumerWidget {
  const TenantDocumentsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tenantProvider);
    final tenantName = state.value?.name ?? 'Kiracı';

    final documents = [
      _DocItem('Kira Sözleşmesi', 'Kira Sözleşmesi.pdf', Icons.description_outlined, const Color(0xFF3B82F6), DateTime(2025, 6, 1)),
      _DocItem('Demirbaş Teslim Tutanağı', 'Demirbas_Tutanagi.pdf', Icons.inventory_2_outlined, const Color(0xFF10B981), DateTime(2025, 6, 1)),
      _DocItem('Aidat Ödeme Planı', 'Aidat_Plani.pdf', Icons.table_chart_outlined, const Color(0xFFF59E0B), DateTime(2025, 9, 15)),
      _DocItem('Tahliye Taahhütnamesi', 'Tahliye_Taahhut.pdf', Icons.assignment_turned_in_outlined, const Color(0xFF8B5CF6), null),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.folder_special_outlined, color: Color(0xFF3B82F6), size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Belgelerim', style: TextStyle(color: AppColors.textHeader, fontSize: 22, fontWeight: FontWeight.bold)),
                      SizedBox(height: 2),
                      Text('Salt okunur dijital arşiv', style: TextStyle(color: AppColors.textBody, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Info banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF3B82F6), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Bu belgeleri yalnızca görüntüleyebilir veya indirebilirsiniz. Belge ekleme veya değiştirme yetkiniz yoktur.',
                      style: TextStyle(color: AppColors.textBody.withOpacity(0.7), fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Document list
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: documents.length,
                itemBuilder: (ctx, i) => _buildDocCard(documents[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocCard(_DocItem doc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: doc.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(doc.icon, color: doc.color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doc.title, style: const TextStyle(color: AppColors.textHeader, fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(doc.filename, style: TextStyle(color: AppColors.textBody.withOpacity(0.5), fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (doc.date != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: doc.color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_formatDate(doc.date!), style: TextStyle(color: doc.color, fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: AppColors.textBody.withOpacity(0.3)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }
}

class _DocItem {
  final String title;
  final String filename;
  final IconData icon;
  final Color color;
  final DateTime? date;

  _DocItem(this.title, this.filename, this.icon, this.color, this.date);
}
