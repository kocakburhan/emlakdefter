import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../providers/landlord_provider.dart';

/// Yatırım Fırsatları — Portföy Vitrini (PRD §4.3.4)
class LandlordInvestmentScreen extends ConsumerStatefulWidget {
  const LandlordInvestmentScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<LandlordInvestmentScreen> createState() => _LandlordInvestmentScreenState();
}

class _LandlordInvestmentScreenState extends ConsumerState<LandlordInvestmentScreen> {
  final _searchController = TextEditingController();
  RangeValues _priceRange = const RangeValues(0, 50000);
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(landlordProvider.notifier).fetchVacantUnits();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landlordProvider);
    final vacantUnits = state.vacantUnits;

    if (state.isLoading && vacantUnits.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFD4A574)));
    }

    return Column(
      children: [
        // Search + Filter Bar
        _buildSearchBar(),
        // Expanded content
        Expanded(
          child: vacantUnits.isEmpty
              ? _buildEmpty()
              : _buildUnitGrid(vacantUnits),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
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
                      hintText: 'Lokasyon, mülk adı...',
                      hintStyle: TextStyle(color: AppColors.textBody.withOpacity(0.4), fontSize: 13),
                      prefixIcon: Icon(Icons.search, color: AppColors.textBody.withOpacity(0.4), size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onSubmitted: (_) => _applyFilters(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => setState(() => _showFilters = !_showFilters),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _showFilters ? const Color(0xFFD4A574) : AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _showFilters
                        ? const Color(0xFFD4A574).withOpacity(0.3)
                        : Colors.white.withOpacity(0.05)),
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    color: _showFilters ? Colors.white : AppColors.textBody.withOpacity(0.5),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          if (_showFilters) ...[
            const SizedBox(height: 14),
            _buildPriceFilter(),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _applyFilters,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4A574),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Uygula', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: _clearFilters,
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
              Text(
                '₺${_priceRange.start.round()} — ₺${_priceRange.end.round()}',
                style: const TextStyle(color: Color(0xFFD4A574), fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RangeSlider(
            values: _priceRange,
            min: 0,
            max: 50000,
            divisions: 100,
            activeColor: const Color(0xFFD4A574),
            inactiveColor: const Color(0xFFD4A574).withOpacity(0.15),
            onChanged: (v) => setState(() => _priceRange = v),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitGrid(List<LandlordVacantUnit> units) {
    return RefreshIndicator(
      onRefresh: () => ref.read(landlordProvider.notifier).fetchVacantUnits(),
      color: const Color(0xFFD4A574),
      child: GridView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.78,
        ),
        itemCount: units.length,
        itemBuilder: (ctx, i) => _buildUnitCard(units[i], i),
      ),
    );
  }

  Widget _buildUnitCard(LandlordVacantUnit unit, int index) {
    final features = unit.features as Map<String, dynamic>?;
    final featureTags = <String>[];
    if (features != null) {
      if (features['elevator'] == true) featureTags.add('Asansör');
      if (features['pool'] == true) featureTags.add('Havuz');
      if (features['parking'] == true) featureTags.add('Otopark');
      if (features['security'] == true) featureTags.add('Güvenlik');
    }

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
          border: Border.all(color: const Color(0xFFD4A574).withOpacity(0.1)),
          boxShadow: [
            BoxShadow(color: const Color(0xFFD4A574).withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 4)),
          ],
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
                  // Icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFFD4A574).withOpacity(0.2), const Color(0xFF8B7355).withOpacity(0.1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.home_outlined, color: Color(0xFFD4A574), size: 22),
                  ),
                  const SizedBox(height: 12),
                  // Property name
                  Text(
                    unit.propertyName,
                    style: const TextStyle(
                      color: AppColors.textHeader,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // Address
                  if (unit.address != null)
                    Text(
                      unit.address!,
                      style: TextStyle(color: AppColors.textBody.withOpacity(0.5), fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 8),
                  // Door + Floor
                  Row(
                    children: [
                      _buildChip('🚪 ${unit.doorNumber}', const Color(0xFF7B8EAD)),
                      if (unit.floor != null) ...[
                        const SizedBox(width: 5),
                        _buildChip('🏢 ${unit.floor}', const Color(0xFF8B7355)),
                      ],
                    ],
                  ),
                  const Spacer(),
                  // Price
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (unit.rentPrice != null)
                        Text(
                          '₺${_fmt(unit.rentPrice!)}/ay',
                          style: const TextStyle(
                            color: Color(0xFFD4A574),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        '₺${_fmt(unit.duesAmount)} aidat',
                        style: TextStyle(color: AppColors.textBody.withOpacity(0.5), fontSize: 10),
                      ),
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
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
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
              color: const Color(0xFFD4A574).withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.real_estate_agent_outlined, size: 36, color: Color(0xFFD4A574)),
          ),
          const SizedBox(height: 20),
          const Text(
            'Portföy vitrini boş',
            style: TextStyle(color: AppColors.textHeader, fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Emlak ofisinin uygun mülkleri burada görünür',
              style: TextStyle(color: AppColors.textBody.withOpacity(0.5), fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  void _showUnitDetail(LandlordVacantUnit unit) {
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
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(
                color: AppColors.textBody.withOpacity(0.3), borderRadius: BorderRadius.circular(2),
              )),
            ),
            const SizedBox(height: 20),
            // Header
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [const Color(0xFFD4A574).withOpacity(0.2), const Color(0xFF8B7355).withOpacity(0.1)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.home_outlined, color: Color(0xFFD4A574), size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(unit.propertyName, style: const TextStyle(color: AppColors.textHeader, fontSize: 20, fontWeight: FontWeight.bold)),
                      if (unit.address != null)
                        Text(unit.address!, style: TextStyle(color: AppColors.textBody.withOpacity(0.6), fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Info grid
            Row(
              children: [
                Expanded(child: _buildInfoTile('Kapı', unit.doorNumber, const Color(0xFF7B8EAD))),
                const SizedBox(width: 10),
                Expanded(child: _buildInfoTile('Kat', unit.floor ?? '—', const Color(0xFF8B7355))),
                const SizedBox(width: 10),
                Expanded(child: _buildInfoTile('Kira', unit.rentPrice != null ? '₺${_fmt(unit.rentPrice!)}' : '—', const Color(0xFF6B8E6B))),
                const SizedBox(width: 10),
                Expanded(child: _buildInfoTile('Aidat', '₺${_fmt(unit.duesAmount)}', const Color(0xFFAD7B7B))),
              ],
            ),
            const SizedBox(height: 24),
            // Interest button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _sendInterestMessage(unit),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B8E6B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.chat_bubble_outline, size: 20),
                label: const Text(
                  'Bu portföyle ilgileniyorum, detayları görüşelim',
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
          Text(value, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: color.withOpacity(0.6), fontSize: 10)),
        ],
      ),
    );
  }

  void _sendInterestMessage(LandlordVacantUnit unit) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${unit.propertyName} — ${unit.doorNumber} için emlakçınıza istek gönderildi.'),
        backgroundColor: const Color(0xFF6B8E6B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _applyFilters() {
    ref.read(landlordProvider.notifier).fetchVacantUnits(
      propertyName: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      minPrice: _priceRange.start.round(),
      maxPrice: _priceRange.end.round(),
    );
    setState(() => _showFilters = false);
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _priceRange = const RangeValues(0, 50000);
      _showFilters = false;
    });
    ref.read(landlordProvider.notifier).fetchVacantUnits();
  }

  String _fmt(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }
}