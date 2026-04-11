import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../providers/landlord_provider.dart';

/// Bina Operasyonları — Ev Sahibinin mülklerindeki şeffaflık kayıtları
class LandlordOperationsScreen extends ConsumerWidget {
  const LandlordOperationsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(landlordProvider);

    if (state.isLoading && state.operations.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFD4A574)));
    }

    if (state.operations.isEmpty) {
      return _buildEmpty();
    }

    final totalCost = state.operations.fold(0, (sum, op) => sum + op.cost);
    final reflected = state.operations.where((op) => op.isReflectedToFinance).fold(0, (sum, op) => sum + op.cost);

    return RefreshIndicator(
      onRefresh: () => ref.read(landlordProvider.notifier).fetchOperations(),
      color: const Color(0xFFD4A574),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Cards
            Row(
              children: [
                Expanded(child: _buildSummaryCard('Toplam', '₺${_fmt(totalCost)}', const Color(0xFFAD7B7B))),
                const SizedBox(width: 10),
                Expanded(child: _buildSummaryCard('Finansa Yansıyan', '₺${_fmt(reflected)}', const Color(0xFF6B8E6B))),
                const SizedBox(width: 10),
                Expanded(child: _buildSummaryCard('Bekleyen', '₺${_fmt(totalCost - reflected)}', const Color(0xFFD4A574))),
              ],
            ),
            const SizedBox(height: 24),

            // Info Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF8B7355).withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF8B7355).withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.visibility_outlined, color: Color(0xFF8B7355), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Emlakçınızın yaptığı tüm harcamalar şeffaflık ilkesiyle burada görünür.',
                      style: TextStyle(color: const Color(0xFF8B7355).withOpacity(0.8), fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Operations List
            ...state.operations.map((op) => _buildOperationCard(op)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.engineering_outlined, size: 56, color: AppColors.textBody.withOpacity(0.2)),
          const SizedBox(height: 16),
          const Text('Operasyon kaydı yok', style: TextStyle(color: AppColors.textBody, fontSize: 16)),
          const SizedBox(height: 8),
          Text('Bina harcamaları burada şeffaf görünür', style: TextStyle(color: AppColors.textBody.withOpacity(0.5), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: color.withOpacity(0.6), fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationCard(LandlordOperation op) {
    final isReflected = op.isReflectedToFinance;
    final dateStr = _formatDate(op.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isReflected
              ? const Color(0xFF6B8E6B).withOpacity(0.15)
              : const Color(0xFFD4A574).withOpacity(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isReflected
                      ? const Color(0xFF6B8E6B).withOpacity(0.1)
                      : const Color(0xFFD4A574).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isReflected ? Icons.check_circle_outline : Icons.pending_outlined,
                  color: isReflected ? const Color(0xFF6B8E6B) : const Color(0xFFD4A574),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      op.title,
                      style: const TextStyle(
                        color: AppColors.textHeader,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(op.propertyName, style: TextStyle(color: AppColors.textBody.withOpacity(0.6), fontSize: 11)),
                        const SizedBox(width: 8),
                        Text(dateStr, style: TextStyle(color: AppColors.textBody.withOpacity(0.5), fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₺${_fmt(op.cost)}',
                    style: const TextStyle(
                      color: AppColors.textHeader,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isReflected
                          ? const Color(0xFF6B8E6B).withOpacity(0.1)
                          : const Color(0xFFD4A574).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isReflected ? 'Finansa Yansıdı' : 'Bekliyor',
                      style: TextStyle(
                        color: isReflected ? const Color(0xFF6B8E6B) : const Color(0xFFD4A574),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (op.description != null && op.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              op.description!,
              style: TextStyle(color: AppColors.textBody.withOpacity(0.7), fontSize: 13, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final aylar = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
    return '${dt.day.toString().padLeft(2, '0')} ${aylar[dt.month - 1]} ${dt.year}';
  }

  String _fmt(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }
}
