import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/colors.dart';
import '../providers/properties_provider.dart';
import '../widgets/create_property_bottom_sheet.dart';
import '../screens/property_detail_screen.dart';

class PropertiesTab extends ConsumerStatefulWidget {
  const PropertiesTab({Key? key}) : super(key: key);

  @override
  ConsumerState<PropertiesTab> createState() => _PropertiesTabState();
}

class _PropertiesTabState extends ConsumerState<PropertiesTab> {
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
          // HEADER
          Padding(
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
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppColors.slateGray,
                                  letterSpacing: 2,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Gayrimenkul\nYönetimi",
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showCreateBottomSheet(context),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.charcoal,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    )
                        .animate()
                        .scale(
                          begin: const Offset(0.8, 0.8),
                          end: const Offset(1.0, 1.0),
                          duration: 300.ms,
                          curve: Curves.easeOut,
                        ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          )
              .animate()
              .fadeIn(duration: 400.ms)
              .slideX(begin: -0.05, end: 0, duration: 400.ms),

          // CONTENT
          Expanded(
            child: propertiesState.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.charcoal),
              ),
              error: (err, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.errorLight,
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
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => ref.read(propertiesProvider.notifier).refresh(),
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
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.business_outlined,
                size: 48,
                color: AppColors.slateGray,
              ),
            )
                .animate()
                .scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1.0, 1.0),
                  duration: 400.ms,
                  curve: Curves.easeOut,
                )
                .fadeIn(duration: 400.ms),

            const SizedBox(height: 24),

            Text(
              "Henüz mülk eklenmemiş",
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            )
                .animate()
                .fadeIn(delay: 100.ms, duration: 400.ms)
                .slideY(begin: 0.2, end: 0, delay: 100.ms, duration: 400.ms),

            const SizedBox(height: 8),

            Text(
              "Portföyünüze ilk binanızı ekleyerek başlayın",
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            )
                .animate()
                .fadeIn(delay: 200.ms, duration: 400.ms),

            const SizedBox(height: 32),

            ElevatedButton.icon(
              onPressed: () => _showCreateBottomSheet(context),
              icon: const Icon(Icons.add_business, size: 20),
              label: const Text("İlk Mülkü Ekle"),
            )
                .animate()
                .fadeIn(delay: 300.ms, duration: 400.ms)
                .slideY(begin: 0.2, end: 0, delay: 300.ms, duration: 400.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyList(List<PropertyModel> list) {
    return RefreshIndicator(
      color: AppColors.charcoal,
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
          return _buildPropertyCard(context, prop, index);
        },
      ),
    );
  }

  Widget _buildPropertyCard(BuildContext context, PropertyModel prop, int index) {
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
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.charcoal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _getPropertyIcon(prop.type),
                    color: AppColors.charcoal,
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
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getPropertyTypeLabel(prop.type),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textTertiary,
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (isHighOccupancy ? AppColors.success : AppColors.warning)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "%${occupancyRate.toStringAsFixed(0)}",
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isHighOccupancy ? AppColors.success : AppColors.warning,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textTertiary,
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
                  AppColors.charcoal,
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
                  prop.emptyUnits > 0 ? AppColors.warning : AppColors.textTertiary,
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: occupancyRate / 100,
                backgroundColor: AppColors.lightGray,
                color: isHighOccupancy ? AppColors.success : AppColors.warning,
                minHeight: 5,
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: 50 * index),
          duration: 300.ms,
        )
        .slideX(
          begin: 0.05,
          end: 0,
          delay: Duration(milliseconds: 50 * index),
          duration: 300.ms,
          curve: Curves.easeOut,
        );
  }

  Widget _buildMiniStat(IconData icon, String value, String label, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 5),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary,
              ),
        ),
      ],
    );
  }

  IconData _getPropertyIcon(String type) {
    switch (type) {
      case 'standalone_house':  // Backend: standalone_house
        return Icons.villa;
      case 'land':
        return Icons.landscape;
      case 'commercial':
        return Icons.storefront;
      case 'apartment_complex':  // Backend: apartment_complex
      default:
        return Icons.apartment;
    }
  }

  String _getPropertyTypeLabel(String type) {
    switch (type) {
      case 'standalone_house':  // Backend: standalone_house
        return "Müstakil Ev / Villa";
      case 'land':
        return "Arsa / Tarla";
      case 'commercial':
        return "Dükkan / Ticari";
      case 'apartment_complex':  // Backend: apartment_complex
      default:
        return "Apartman / Site";
    }
  }
}
