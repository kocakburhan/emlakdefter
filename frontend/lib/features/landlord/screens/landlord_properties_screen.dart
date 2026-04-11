import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../providers/landlord_provider.dart';

/// Mülklerim Listesi — Ev Sahibinin tüm mülkleri ve birim detayları
class LandlordPropertiesScreen extends ConsumerWidget {
  const LandlordPropertiesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(landlordProvider);

    if (state.isLoading && state.properties.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFD4A574)));
    }

    if (state.properties.isEmpty) {
      return _buildEmpty();
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(landlordProvider.notifier).fetchProperties(),
      color: const Color(0xFFD4A574),
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
        itemCount: state.properties.length,
        itemBuilder: (ctx, i) => _buildPropertyCard(context, ref, state.properties[i]),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.home_work_outlined, size: 56, color: AppColors.textBody.withOpacity(0.2)),
          const SizedBox(height: 16),
          const Text('Henüz mülk bağlantısı yok', style: TextStyle(color: AppColors.textBody, fontSize: 16)),
          const SizedBox(height: 8),
          Text('Emlakçınız sizi davet ettiğinde görünür', style: TextStyle(color: AppColors.textBody.withOpacity(0.5), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildPropertyCard(BuildContext context, WidgetRef ref, LandlordProperty prop) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (prop.propertyName.hashCode % 400)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, 15 * (1 - value)), child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(color: const Color(0xFF8B7355).withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => _showPropertyDetail(context, ref, prop),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [const Color(0xFF8B7355).withOpacity(0.15), const Color(0xFFD4A574).withOpacity(0.1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.home_work_outlined, color: Color(0xFF8B7355), size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              prop.propertyName,
                              style: const TextStyle(
                                color: AppColors.textHeader,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (prop.address != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                prop.address!,
                                style: TextStyle(color: AppColors.textBody.withOpacity(0.6), fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: AppColors.textBody.withOpacity(0.3)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      _buildStatChip('${prop.ownedUnits}', 'Birim', const Color(0xFF6B8E6B)),
                      const SizedBox(width: 8),
                      _buildStatChip('${prop.occupiedUnits}', 'Dolu', const Color(0xFF7A9E7A)),
                      const SizedBox(width: 8),
                      _buildStatChip('${prop.vacantUnits}', 'Boş', const Color(0xFFAD7B7B)),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₺${_fmt(prop.monthlyIncome)}',
                            style: const TextStyle(
                              color: Color(0xFF6B8E6B),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const Text('aylık gelir', style: TextStyle(color: AppColors.textBody, fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Occupancy bar
                  _buildOccupancyBar(prop.occupancyRate),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color.withOpacity(0.7), fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildOccupancyBar(double rate) {
    final color = rate >= 80 ? const Color(0xFF6B8E6B) : (rate >= 50 ? const Color(0xFFD4A574) : const Color(0xFFAD7B7B));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Doluluk', style: TextStyle(color: AppColors.textBody.withOpacity(0.6), fontSize: 11)),
            Text('${rate.toStringAsFixed(0)}%', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: rate / 100,
            backgroundColor: AppColors.textBody.withOpacity(0.08),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  void _showPropertyDetail(BuildContext context, WidgetRef ref, LandlordProperty prop) {
    final units = ref.read(landlordProvider).units.where((u) {
      // Mülke ait birimleri filtrele (unit'de property bilgisi yok, basitçe show all)
      return true;
    }).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(
                  color: AppColors.textBody.withOpacity(0.3), borderRadius: BorderRadius.circular(2),
                )),
              ),
              const SizedBox(height: 20),
              Text(prop.propertyName, style: const TextStyle(color: AppColors.textHeader, fontSize: 22, fontWeight: FontWeight.bold)),
              if (prop.address != null) Text(prop.address!, style: TextStyle(color: AppColors.textBody.withOpacity(0.6))),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: prop.ownedUnits,
                  itemBuilder: (_, i) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B7355).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.door_front_door, color: Color(0xFF8B7355), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Birim ${i + 1}', style: const TextStyle(color: AppColors.textHeader, fontWeight: FontWeight.bold)),
                              Text(prop.propertyName, style: TextStyle(color: AppColors.textBody.withOpacity(0.6), fontSize: 12)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6B8E6B).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Kiracılı', style: TextStyle(color: Color(0xFF6B8E6B), fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
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
