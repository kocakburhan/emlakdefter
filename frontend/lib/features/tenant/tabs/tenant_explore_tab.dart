import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../providers/tenant_provider.dart';

/// Yeni Ev Keşfi — Boş Portföy Vitrini (PRD §4.2.6)
class TenantExploreTab extends ConsumerStatefulWidget {
  const TenantExploreTab({Key? key}) : super(key: key);

  @override
  ConsumerState<TenantExploreTab> createState() => _TenantExploreTabState();
}

class _TenantExploreTabState extends ConsumerState<TenantExploreTab> {
  final _searchController = TextEditingController();
  RangeValues _priceRange = const RangeValues(0, 100000);
  bool _showFilters = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = _searchController.text;
    final unitsAsync = ref.watch(tenantVacantUnitsProvider(searchQuery.isEmpty ? null : searchQuery));

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: AppColors.textHeader, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Lokasyon, site adı...',
                          hintStyle: TextStyle(color: AppColors.textBody.withOpacity(0.4), fontSize: 13),
                          prefixIcon: Icon(Icons.search, color: AppColors.textBody.withOpacity(0.4), size: 20),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => setState(() => _showFilters = !_showFilters),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _showFilters ? AppColors.accent : AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _showFilters ? AppColors.accent.withOpacity(0.3) : Colors.white.withOpacity(0.05)),
                      ),
                      child: Icon(Icons.tune_rounded, color: _showFilters ? Colors.white : AppColors.textBody.withOpacity(0.5), size: 20),
                    ),
                  ),
                ],
              ),
              if (_showFilters) ...[
                const SizedBox(height: 12),
                _buildPriceFilter(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => setState(() {}),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Uygula', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _priceRange = const RangeValues(0, 100000);
                          _showFilters = false;
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textBody,
                        side: BorderSide(color: AppColors.textBody.withOpacity(0.2)),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Temizle', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Row(
            children: [
              const Text('Müsait Daireler', style: TextStyle(color: AppColors.textHeader, fontSize: 17, fontWeight: FontWeight.bold)),
              const Spacer(),
              unitsAsync.when(
                loading: () => const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
                error: (_, __) => Text('? sonuç', style: TextStyle(color: AppColors.textBody.withOpacity(0.5), fontSize: 12)),
                data: (units) {
                  final filtered = units.where((u) =>
                    u.rentPrice >= _priceRange.start && u.rentPrice <= _priceRange.end
                  ).toList();
                  return Text('${filtered.length} sonuç', style: TextStyle(color: AppColors.textBody.withOpacity(0.5), fontSize: 12));
                },
              ),
            ],
          ),
        ),

        // Grid
        Expanded(
          child: unitsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
            error: (e, _) => Center(child: Text('Yüklenemedi: $e', style: const TextStyle(color: AppColors.error))),
            data: (units) {
              final filtered = units.where((u) =>
                u.rentPrice >= _priceRange.start && u.rentPrice <= _priceRange.end
              ).toList();

              if (filtered.isEmpty) return _buildEmpty();
              return GridView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.72,
                ),
                itemCount: filtered.length,
                itemBuilder: (ctx, i) => _buildUnitCard(filtered[i], i),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPriceFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Kira Aralığı', style: TextStyle(color: AppColors.textBody.withOpacity(0.7), fontSize: 12)),
              Text('₺${_priceRange.start.round()} — ₺${_priceRange.end.round()}', style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          RangeSlider(
            values: _priceRange,
            min: 0,
            max: 100000,
            divisions: 100,
            activeColor: AppColors.accent,
            inactiveColor: AppColors.accent.withOpacity(0.15),
            onChanged: (v) => setState(() => _priceRange = v),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitCard(VacantUnitItem unit, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index % 7) * 80),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, 12 * (1 - value)), child: child),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accent.withOpacity(0.1)),
          boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 4))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _showUnitDetail(unit),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Kiralık', style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                        child: const Text('Boş', style: TextStyle(color: AppColors.accent, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.accent.withOpacity(0.2), AppColors.accent.withOpacity(0.08)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.home_outlined, color: AppColors.accent, size: 22),
                  ),
                  const SizedBox(height: 12),
                  Text(unit.propertyName, style: const TextStyle(color: AppColors.textHeader, fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(unit.address, style: TextStyle(color: AppColors.textBody.withOpacity(0.5), fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildChip('${unit.doorNumber}', const Color(0xFF8B5CF6)),
                      if (unit.floor != null) ...[
                        const SizedBox(width: 5),
                        _buildChip('${unit.floor}', const Color(0xFF3B82F6)),
                      ],
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '₺${_fmt(unit.rentPrice)}/ay',
                        style: const TextStyle(color: AppColors.accent, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text('₺${_fmt(unit.duesAmount)} aidat', style: TextStyle(color: AppColors.textBody.withOpacity(0.5), fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10)),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search_off_rounded, size: 36, color: AppColors.accent),
          ),
          const SizedBox(height: 20),
          const Text('Sonuç bulunamadı', style: TextStyle(color: AppColors.textHeader, fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text('Filtreleri değiştirerek tekrar deneyin', style: TextStyle(color: AppColors.textBody.withOpacity(0.5), fontSize: 13), textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  void _showUnitDetail(VacantUnitItem unit) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.55,
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.textBody.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [AppColors.accent.withOpacity(0.2), AppColors.accent.withOpacity(0.08)]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.home_outlined, color: AppColors.accent, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(unit.propertyName, style: const TextStyle(color: AppColors.textHeader, fontSize: 20, fontWeight: FontWeight.bold)),
                      Text(unit.address, style: TextStyle(color: AppColors.textBody.withOpacity(0.6), fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _buildInfoTile('Kapı', unit.doorNumber, const Color(0xFF8B5CF6))),
                const SizedBox(width: 10),
                Expanded(child: _buildInfoTile('Kat', unit.floor ?? '-', const Color(0xFF3B82F6))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildInfoTile('Kira', '₺${_fmt(unit.rentPrice)}', const Color(0xFFF59E0B))),
                const SizedBox(width: 10),
                Expanded(child: _buildInfoTile('Aidat', '₺${_fmt(unit.duesAmount)}', const Color(0xFFEF4444))),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${unit.propertyName} — hakkında emlakçınıza talep gönderildi.'),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.chat_bubble_outline, size: 20),
                label: const Text(
                  'Bu eve de bakabilir miyiz?',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: color.withOpacity(0.6), fontSize: 10)),
        ],
      ),
    );
  }

  String _fmt(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }
}
