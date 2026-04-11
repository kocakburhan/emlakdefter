import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../providers/landlord_provider.dart';

/// Kiracı Performans — Ev Sahibinin kiracılarının ödeme takibi
class LandlordTenantPerformanceScreen extends ConsumerWidget {
  const LandlordTenantPerformanceScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(landlordProvider);

    if (state.isLoading && state.tenants.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFD4A574)));
    }

    if (state.tenants.isEmpty) {
      return _buildEmpty();
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(landlordProvider.notifier).fetchTenants(),
      color: const Color(0xFFD4A574),
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
        itemCount: state.tenants.length,
        itemBuilder: (ctx, i) => _buildTenantCard(state.tenants[i]),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 56, color: AppColors.textBody.withOpacity(0.2)),
          const SizedBox(height: 16),
          const Text('Kiracı bağlantısı yok', style: TextStyle(color: AppColors.textBody, fontSize: 16)),
          const SizedBox(height: 8),
          Text('Mülkünüze kiracı atandığında görünür', style: TextStyle(color: AppColors.textBody.withOpacity(0.5), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildTenantCard(TenantPerformance tenant) {
    final score = tenant.paymentScore;
    final scoreColor = score >= 80 ? const Color(0xFF6B8E6B) : (score >= 50 ? const Color(0xFFD4A574) : const Color(0xFFAD7B7B));
    final isActive = tenant.isActive;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (tenant.tenantId.hashCode % 400)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, 15 * (1 - value)), child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scoreColor.withOpacity(0.12)),
          boxShadow: [
            BoxShadow(color: scoreColor.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Score ring
                      _buildScoreRing(score, scoreColor),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    tenant.tenantName ?? 'Kiracı',
                                    style: const TextStyle(
                                      color: AppColors.textHeader,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? const Color(0xFF6B8E6B).withOpacity(0.12)
                                        : AppColors.textBody.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    isActive ? 'Aktif' : 'Pasif',
                                    style: TextStyle(
                                      color: isActive ? const Color(0xFF6B8E6B) : AppColors.textBody,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${tenant.propertyName} • ${tenant.doorNumber}',
                              style: TextStyle(color: AppColors.textBody.withOpacity(0.6), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoTile('Aylık Kira', '₺${_fmt(tenant.rentAmount)}', const Color(0xFF8B7355)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildInfoTile('Ödeme Günü', '${tenant.paymentDay}.', const Color(0xFF7B8EAD)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildInfoTile('Süre', '${tenant.monthsRented} ay', const Color(0xFFD4A574)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Contract dates
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Sözleşme',
                          style: TextStyle(color: AppColors.textBody.withOpacity(0.5), fontSize: 11),
                        ),
                        Text(
                          '${_formatDate(tenant.contractStart)} — ${_formatDate(tenant.contractEnd)}',
                          style: TextStyle(color: AppColors.textBody.withOpacity(0.7), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScoreRing(double score, Color color) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.1),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(width: 44, height: 44, child: CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 4,
            backgroundColor: color.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation(color),
          )),
          Text(
            '${score.toStringAsFixed(0)}',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: color.withOpacity(0.6), fontSize: 10)),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  String _fmt(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }
}
