import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../providers/tenant_provider.dart';

/// Bina Operasyonları — Şeffaflık Panosu (PRD §4.2.4)
class TenantBuildingOpsTab extends ConsumerWidget {
  const TenantBuildingOpsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantState = ref.watch(tenantProvider);
    final logsState = ref.watch(tenantBuildingLogsProvider);
    final propertyName = tenantState.value?.propertyName ?? 'Binamız';

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.visibility_outlined, color: Color(0xFF10B981), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bina Operasyonları', style: TextStyle(color: AppColors.textHeader, fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(propertyName, style: TextStyle(color: AppColors.textBody.withOpacity(0.6), fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                logsState.when(
                  loading: () => const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(color: AppColors.accent))),
                  error: (e, _) => Text('Yüklenemedi: $e', style: const TextStyle(color: AppColors.error)),
                  data: (logs) {
                    final totalCost = logs.fold(0, (sum, l) => sum + l.cost);
                    final reflectedCost = logs.where((l) => l.cost > 0).fold(0, (sum, l) => sum + l.cost);
                    return Row(
                      children: [
                        Expanded(child: _buildSummaryCard('Toplam Harcama', '₺${_fmt(totalCost)}', const Color(0xFFEF4444))),
                        const SizedBox(width: 10),
                        Expanded(child: _buildSummaryCard('Finansa Yansıyan', '₺${_fmt(reflectedCost)}', const Color(0xFF10B981))),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.12)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Color(0xFF10B981), size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Verdiğiniz aidatların nereye harcandığını şeffafça takip edin.',
                      style: TextStyle(color: AppColors.textBody, fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: logsState.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
              error: (e, _) => Center(child: Text('Yüklenemedi: $e')),
              data: (logs) {
                if (logs.isEmpty) {
                  return const Center(
                    child: Text('Henüz hiç bina operasyonu kaydedilmedi.',
                      style: TextStyle(color: AppColors.textBody)),
                  );
                }
                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                  itemCount: logs.length,
                  itemBuilder: (ctx, i) => _buildOpCard(logs[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: color.withOpacity(0.6), fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildOpCard(BuildingLogItem log) {
    final colors = [
      const Color(0xFF3B82F6), const Color(0xFFEF4444),
      const Color(0xFF10B981), const Color(0xFFF59E0B), const Color(0xFF8B5CF6),
    ];
    final color = colors[log.id.hashCode % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.build_outlined, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(log.title, style: const TextStyle(color: AppColors.textHeader, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(log.description ?? '', style: TextStyle(color: AppColors.textBody.withOpacity(0.6), fontSize: 12, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('₺${_fmt(log.cost)}', style: const TextStyle(color: AppColors.textHeader, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Kaydedildi',
                    style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }
}
