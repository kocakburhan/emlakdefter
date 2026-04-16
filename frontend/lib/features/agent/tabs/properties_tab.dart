import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../providers/properties_provider.dart';
import '../widgets/create_property_bottom_sheet.dart';
import '../screens/property_detail_screen.dart';

class PropertiesTab extends ConsumerStatefulWidget {
  const PropertiesTab({Key? key}) : super(key: key);

  @override
  ConsumerState<PropertiesTab> createState() => _PropertiesTabState();
}

class _PropertiesTabState extends ConsumerState<PropertiesTab>
    with TickerProviderStateMixin {
  late AnimationController _headerAnimController;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;

  @override
  void initState() {
    super.initState();
    _headerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _headerFade = CurvedAnimation(
      parent: _headerAnimController,
      curve: Curves.easeOutCubic,
    );
    _headerSlide = Tween<Offset>(
      begin: const Offset(-0.1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _headerAnimController,
      curve: Curves.easeOutCubic,
    ));
    _headerAnimController.forward();
  }

  @override
  void dispose() {
    _headerAnimController.dispose();
    super.dispose();
  }

  void _showCreateBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const CreatePropertyBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final propertiesState = ref.watch(propertiesProvider);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── HEADER ─────────────────────────────────────────────────
          SlideTransition(
            position: _headerSlide,
            child: FadeTransition(
              opacity: _headerFade,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "PORTFÖY",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accent.withValues(alpha: 0.8),
                                  letterSpacing: 2.0,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                "Gayrimenkul\nYönetimi",
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textHeader,
                                  height: 1.15,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                          ),
                          child: const Icon(
                            Icons.add_location_alt,
                            color: AppColors.accent,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),

          // ── CONTENT ────────────────────────────────────────────────
          Expanded(
            child: propertiesState.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
              error: (err, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.error_outline,
                        color: AppColors.error,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Portföy yüklenemedi",
                      style: const TextStyle(
                        color: AppColors.textHeader,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () =>
                          ref.read(propertiesProvider.notifier).refresh(),
                      child: const Text("Tekrar dene"),
                    ),
                  ],
                ),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return _buildEmptyState();
                }
                return _buildPropertyList(list);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.business_outlined,
                size: 48,
                color: AppColors.textBody,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Henüz mülk eklenmemiş",
              style: TextStyle(
                color: AppColors.textHeader,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Portföyünüze ilk binanızı ekleyerek başlayın",
              style: TextStyle(
                color: AppColors.textBody.withValues(alpha: 0.7),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _showCreateBottomSheet(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.add_business, size: 20),
              label: const Text(
                "İlk Mülkü Ekle",
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyList(List<PropertyModel> list) {
    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      onRefresh: () async {
        ref.read(propertiesProvider.notifier).refresh();
      },
      child: ListView.separated(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final prop = list[index];
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 400 + (index * 60).clamp(0, 500)),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: _buildPropertyCard(context, prop),
          );
        },
      ),
    );
  }

  Widget _buildPropertyCard(BuildContext context, PropertyModel prop) {
    final double occupancyRate = prop.totalUnits > 0
        ? ((prop.totalUnits - prop.emptyUnits) / prop.totalUnits) * 100
        : 0.0;
    final isHighOccupancy = occupancyRate >= 80;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => PropertyDetailScreen(
              propertyId: prop.id,
              propertyName: prop.name,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: icon + name + chevron
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _getPropertyIcon(prop.type),
                    color: AppColors.accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prop.name,
                        style: const TextStyle(
                          color: AppColors.textHeader,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getPropertyTypeLabel(prop.type),
                        style: TextStyle(
                          color: AppColors.textBody.withValues(alpha: 0.6),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: (isHighOccupancy
                            ? AppColors.success
                            : AppColors.warning)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "%${occupancyRate.toStringAsFixed(0)}",
                    style: TextStyle(
                      color: isHighOccupancy
                          ? AppColors.success
                          : AppColors.warning,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textBody,
                  size: 22,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Stats row
            Row(
              children: [
                _buildMiniStat(
                  Icons.door_front_door_outlined,
                  "${prop.totalUnits}",
                  "Kapı",
                  AppColors.accent,
                ),
                const SizedBox(width: 20),
                _buildMiniStat(
                  Icons.person_outline,
                  "${prop.totalUnits - prop.emptyUnits}",
                  "Kiracı",
                  AppColors.success,
                ),
                const SizedBox(width: 20),
                _buildMiniStat(
                  Icons.home_outlined,
                  "${prop.emptyUnits}",
                  "Boş",
                  prop.emptyUnits > 0
                      ? AppColors.warning
                      : AppColors.textBody,
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: occupancyRate / 100,
                backgroundColor: Colors.white.withValues(alpha: 0.05),
                color: isHighOccupancy ? AppColors.success : AppColors.warning,
                minHeight: 5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String value, String label, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 5),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textBody.withValues(alpha: 0.6),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  IconData _getPropertyIcon(String type) {
    switch (type) {
      case 'villa':
        return Icons.villa;
      case 'land':
        return Icons.landscape;
      case 'commercial':
        return Icons.storefront;
      default:
        return Icons.apartment;
    }
  }

  String _getPropertyTypeLabel(String type) {
    switch (type) {
      case 'villa':
        return "Müstakil Ev / Villa";
      case 'land':
        return "Arsa / Tarla";
      case 'commercial':
        return "Dükkan / Ticari";
      default:
        return "Apartman / Site";
    }
  }
}