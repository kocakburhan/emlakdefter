import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/colors.dart';
import '../providers/landlord_provider.dart';

/// Mülklerim Listesi — Ev Sahibinin tüm mülkleri ve birim detayları
class LandlordPropertiesScreen extends ConsumerStatefulWidget {
  const LandlordPropertiesScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<LandlordPropertiesScreen> createState() => _LandlordPropertiesScreenState();
}

class _LandlordPropertiesScreenState extends ConsumerState<LandlordPropertiesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _detailTabController;

  @override
  void dispose() {
    _detailTabController.dispose();
    super.dispose();
  }

  void _showPropertyDetail(BuildContext context, WidgetRef ref, LandlordProperty prop) {
    _detailTabController = TabController(length: 2, vsync: this);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle + Header
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Center(
                  child: Container(width: 40, height: 4, decoration: BoxDecoration(
                    color: AppColors.textSecondary.withValues(alpha:0.3), borderRadius: BorderRadius.circular(2),
                  )),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [const Color(0xFF8B7355).withValues(alpha:0.15), const Color(0xFFD4A574).withValues(alpha:0.1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.home_work_outlined, color: Color(0xFF8B7355), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(prop.propertyName, style: const TextStyle(color: AppColors.charcoal, fontSize: 18, fontWeight: FontWeight.bold)),
                          if (prop.address != null) Text(prop.address!, style: TextStyle(color: AppColors.textSecondary.withValues(alpha:0.6), fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textSecondary),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              // Tab bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _detailTabController,
                    indicatorColor: const Color(0xFFD4A574),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: const Color(0xFFD4A574),
                    unselectedLabelColor: AppColors.textSecondary,
                    dividerColor: Colors.transparent,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    tabs: const [
                      Tab(child: Text('Birimler')),
                      Tab(child: Text('Dijital Arşiv')),
                    ],
                  ),
                ),
              ),
              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _detailTabController,
                  children: [
                    // Birimler tab
                    _buildUnitsTab(prop, scrollController),
                    // Dijital Arşiv tab
                    _buildDigitalArchiveTab(prop, ctx),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnitsTab(LandlordProperty prop, ScrollController scrollController) {
    final state = ref.watch(landlordProvider);
    final propUnits = state.units.where((u) => u.propertyName == prop.propertyName).toList();

    if (propUnits.isEmpty) {
      return ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.all(24),
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
                  color: const Color(0xFF8B7355).withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.door_front_door, color: Color(0xFF8B7355), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Birim ${i + 1}', style: const TextStyle(color: AppColors.charcoal, fontWeight: FontWeight.bold)),
                    Text(prop.propertyName, style: TextStyle(color: AppColors.textSecondary.withValues(alpha:0.6), fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha:0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Bilinmiyor', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(24),
      itemCount: propUnits.length,
      itemBuilder: (_, i) {
        final unit = propUnits[i];
        final isOccupied = unit.isActive;

        return Container(
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
                  color: const Color(0xFF8B7355).withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.door_front_door, color: Color(0xFF8B7355), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${unit.doorNumber}${unit.floor != null ? ' • ${unit.floor}. kat' : ''}',
                      style: const TextStyle(color: AppColors.charcoal, fontWeight: FontWeight.bold)),
                    Text(unit.propertyName, style: TextStyle(color: AppColors.textSecondary.withValues(alpha:0.6), fontSize: 12)),
                  ],
                ),
              ),
              // Status badge (§4.3.1-B): 🟢 Kirada / 🔴 Boş
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isOccupied
                      ? const Color(0xFF6B8E6B).withValues(alpha:0.12)
                      : const Color(0xFFAD7B7B).withValues(alpha:0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isOccupied
                        ? const Color(0xFF6B8E6B).withValues(alpha:0.3)
                        : const Color(0xFFAD7B7B).withValues(alpha:0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isOccupied ? Icons.check_circle : Icons.cancel_outlined,
                      size: 12,
                      color: isOccupied ? const Color(0xFF6B8E6B) : const Color(0xFFAD7B7B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isOccupied ? 'Kirada' : 'Boş',
                      style: TextStyle(
                        color: isOccupied ? const Color(0xFF6B8E6B) : const Color(0xFFAD7B7B),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDigitalArchiveTab(LandlordProperty prop, BuildContext ctx) {
    // Fetch documents for each unit when tab opens
    final landlordUnits = ref.read(landlordProvider).units;
    final propUnits = landlordUnits.where((u) => u.propertyName == prop.propertyName).toList();

    if (propUnits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_off_outlined, size: 48, color: AppColors.textSecondary.withValues(alpha:0.2)),
            const SizedBox(height: 16),
            Text('Dijital arşiv mevcut değil', style: TextStyle(color: AppColors.textSecondary.withValues(alpha:0.5), fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: propUnits.length,
      itemBuilder: (_, i) {
        final unit = propUnits[i];
        final docs = ref.watch(landlordProvider).unitDocuments[unit.unitId];

        // Auto-fetch if not loaded
        if (docs == null) {
          Future.microtask(() => ref.read(landlordProvider.notifier).fetchUnitDocuments(unit.unitId));
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD4A574).withValues(alpha:0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Unit header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4A574).withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.door_front_door, color: Color(0xFFD4A574), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Kapı ${unit.doorNumber}',
                      style: const TextStyle(color: AppColors.charcoal, fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ),
                  const Icon(Icons.lock_outline, color: Color(0xFFD4A574), size: 16),
                  const SizedBox(width: 4),
                  const Text(
                    'Salt Okunur',
                    style: TextStyle(color: Color(0xFFD4A574), fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Contract document
              if (docs?.contractDocumentUrl != null && docs!.contractDocumentUrl!.isNotEmpty) ...[
                _buildDocTile(
                  icon: Icons.description_outlined,
                  name: 'Kira Sözleşmesi',
                  docType: 'Sözleşme',
                  url: docs.contractDocumentUrl!,
                  color: const Color(0xFF5B8DEF),
                  ctx: ctx,
                ),
                const SizedBox(height: 8),
              ],

              // Other documents
              if (docs != null) ...[
                for (final doc in docs.documents)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildDocTile(
                      icon: _docIcon(doc.docType),
                      name: doc.name,
                      docType: _docTypeLabel(doc.docType),
                      url: doc.url,
                      color: _docColor(doc.docType),
                      ctx: ctx,
                    ),
                  ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD4A574)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Belge bilgileri yükleniyor...',
                        style: TextStyle(color: AppColors.textSecondary.withValues(alpha:0.5), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],

              if (docs == null || (docs.contractDocumentUrl == null && docs.documents.isEmpty)) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.textSecondary.withValues(alpha:0.4), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Henüz arşivlenmiş belge yok',
                          style: TextStyle(color: AppColors.textSecondary.withValues(alpha:0.4), fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDocTile({
    required IconData icon,
    required String name,
    required String docType,
    required String url,
    required Color color,
    required BuildContext ctx,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha:0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha:0.15)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(color: AppColors.charcoal, fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(docType, style: TextStyle(color: color.withValues(alpha:0.7), fontSize: 10)),
                  ],
                ),
              ),
              Icon(Icons.open_in_new, color: color.withValues(alpha:0.6), size: 16),
              const SizedBox(width: 4),
              Text(
                'Aç / İndir',
                style: TextStyle(color: color.withValues(alpha:0.6), fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _docIcon(String docType) {
    switch (docType) {
      case 'contract': return Icons.description_outlined;
      case 'handover': return Icons.assignment_turned_in_outlined;
      case 'photo': return Icons.photo_library_outlined;
      default: return Icons.insert_drive_file_outlined;
    }
  }

  Color _docColor(String docType) {
    switch (docType) {
      case 'contract': return const Color(0xFF5B8DEF);
      case 'handover': return const Color(0xFF6B8E6B);
      case 'photo': return const Color(0xFFD4A574);
      default: return AppColors.textSecondary;
    }
  }

  String _docTypeLabel(String docType) {
    switch (docType) {
      case 'contract': return 'Sözleşme';
      case 'handover': return 'Demirbaş Tutanağı';
      case 'photo': return 'Fotoğraf';
      default: return 'Belge';
    }
  }

  @override
  Widget build(BuildContext context) {
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
          Icon(Icons.home_work_outlined, size: 56, color: AppColors.textSecondary.withValues(alpha:0.2)),
          const SizedBox(height: 16),
          const Text('Henüz mülk bağlantısı yok', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
          const SizedBox(height: 8),
          Text('Emlakçınız sizi davet ettiğinde görünür', style: TextStyle(color: AppColors.textSecondary.withValues(alpha:0.5), fontSize: 13)),
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
          border: Border.all(color: Colors.white.withValues(alpha:0.05)),
          boxShadow: [
            BoxShadow(color: const Color(0xFF8B7355).withValues(alpha:0.04), blurRadius: 12, offset: const Offset(0, 4)),
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
                            colors: [const Color(0xFF8B7355).withValues(alpha:0.15), const Color(0xFFD4A574).withValues(alpha:0.1)],
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
                                color: AppColors.charcoal,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (prop.address != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                prop.address!,
                                style: TextStyle(color: AppColors.textSecondary.withValues(alpha:0.6), fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: AppColors.textSecondary.withValues(alpha:0.3)),
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
                          const Text('aylık gelir', style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
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
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha:0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color.withValues(alpha:0.7), fontSize: 10)),
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
            Text('Doluluk', style: TextStyle(color: AppColors.textSecondary.withValues(alpha:0.6), fontSize: 11)),
            Text('${rate.toStringAsFixed(0)}%', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: rate / 100,
            backgroundColor: AppColors.textSecondary.withValues(alpha:0.08),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  String _fmt(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }
}
