import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../providers/tenant_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// "Atlas" — Tenant Property Explorer
// Editorial luxury real estate magazine
// PRD §4.2.6
// ─────────────────────────────────────────────────────────────────────────────

// Palette — mapped to AppColors Modern Minimalist
const _bg = AppColors.background;
const _surface = AppColors.surface;
const _forest = AppColors.charcoal;
const _gold = AppColors.charcoalLight;
const _textDark = AppColors.charcoal;
const _textMid = AppColors.textSecondary;
const _textLight = AppColors.textTertiary;
const _divider = AppColors.border;
const _cardShadow = AppColors.shadow;

// Property type gradient palettes (used for image placeholders)
const _propertyGradients = [
  [AppColors.charcoal, AppColors.charcoalLight],
  [AppColors.slateGray, AppColors.slateGrayLight],
  [AppColors.charcoalDark, AppColors.charcoal],
  [AppColors.slateGrayDark, AppColors.charcoal],
  [AppColors.charcoalLight, AppColors.slateGray],
];

// Room count options
const _roomOptions = ['Stüdyo', '1+0', '1+1', '2+1', '3+1', '4+1', '5+2'];

// Feature options
const _featureOptions = [
  {'key': 'balcony', 'label': 'Balkon', 'icon': Icons.deck_rounded},
  {'key': 'parking', 'label': 'Otopark', 'icon': Icons.local_parking_rounded},
  {'key': 'furnished', 'label': 'Eşyalı', 'icon': Icons.king_bed_rounded},
  {'key': 'elevator', 'label': 'Asansör', 'icon': Icons.elevator_rounded},
  {'key': 'central', 'label': 'Merkezi', 'icon': Icons.location_city_rounded},
  {'key': 'security', 'label': 'Güvenlik', 'icon': Icons.security_rounded},
];

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────
class TenantExploreTab extends ConsumerStatefulWidget {
  const TenantExploreTab({super.key, this.onNavigateToTab});

  final void Function(int)? onNavigateToTab;

  @override
  ConsumerState<TenantExploreTab> createState() => _TenantExploreTabState();
}

class _TenantExploreTabState extends ConsumerState<TenantExploreTab>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  // Filters
  RangeValues _priceRange = const RangeValues(0, 100000);
  String? _selectedRoom;
  final Set<String> _selectedFeatures = {};
  bool _showFilters = false;

  // Animation
  late AnimationController _filterAnimController;
  late Animation<double> _filterHeight;

  @override
  void initState() {
    super.initState();
    _filterAnimController = AnimationController(
      duration: const Duration(milliseconds: 420),
      vsync: this,
    );
    _filterHeight = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _filterAnimController, curve: Curves.easeOutCubic),
    );
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    setState(() {});
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _filterAnimController.dispose();
    super.dispose();
  }

  void _toggleFilters() {
    setState(() => _showFilters = !_showFilters);
    if (_showFilters) {
      _filterAnimController.forward();
    } else {
      _filterAnimController.reverse();
    }
  }

  void _applyFilters() {
    _filterAnimController.reverse();
    setState(() => _showFilters = false);
  }

  void _clearFilters() {
    _searchCtrl.clear();
    setState(() {
      _priceRange = const RangeValues(0, 100000);
      _selectedRoom = null;
      _selectedFeatures.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text;
    final unitsAsync = ref.watch(tenantVacantUnitsProvider(
      query.isEmpty ? null : query,
    ));

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header + Search ────────────────────────────────────
            _ExploreHeader(
              searchCtrl: _searchCtrl,
              showFilters: _showFilters,
              onToggleFilters: _toggleFilters,
              onSearchChanged: (_) => setState(() {}),
            ),

            // ── Filters Panel ────────────────────────────────────
            SizeTransition(
              sizeFactor: _filterHeight,
              axisAlignment: -1.0,
              child: _FilterPanel(
                priceRange: _priceRange,
                selectedRoom: _selectedRoom,
                selectedFeatures: _selectedFeatures,
                onPriceChanged: (v) => setState(() => _priceRange = v),
                onRoomSelected: (r) => setState(() => _selectedRoom = r),
                onFeatureToggled: (f) {
                  setState(() {
                    if (_selectedFeatures.contains(f)) {
                      _selectedFeatures.remove(f);
                    } else {
                      _selectedFeatures.add(f);
                    }
                  });
                },
                onApply: _applyFilters,
                onClear: _clearFilters,
              ),
            ),

            // ── Result count ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(
                children: [
                  Text(
                    'Keşfet',
                    style: TextStyle(
                      color: _textDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  unitsAsync.when(
                    loading: () => const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _forest),
                    ),
                    error: (_, __) => Text('— sonuç',
                        style: TextStyle(color: _textLight, fontSize: 12)),
                    data: (units) {
                      final filtered = _applyFiltersToUnits(units);
                      return Text(
                        '${filtered.length} mülk',
                        style: TextStyle(
                          color: _textLight, fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const Divider(color: _divider, height: 1),

            // ── Property Grid ──────────────────────────────────────
            Expanded(
              child: unitsAsync.when(
                loading: () => _buildShimmerGrid(),
                error: (e, _) => _buildError(),
                data: (units) {
                  final filtered = _applyFiltersToUnits(units);
                  if (filtered.isEmpty) return _buildEmpty();
                  return _buildPropertyGrid(filtered);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<VacantUnitItem> _applyFiltersToUnits(List<VacantUnitItem> units) {
    return units.where((u) {
      if (u.rentPrice < _priceRange.start || u.rentPrice > _priceRange.end) {
        return false;
      }
      if (_selectedFeatures.isNotEmpty) {
        final hasAll = _selectedFeatures.every(
          (f) => u.features.any((uf) => uf.toLowerCase().contains(f)),
        );
        if (!hasAll) return false;
      }
      return true;
    }).toList();
  }

  Widget _buildPropertyGrid(List<VacantUnitItem> units) {
    return ListView.builder(
      controller: _scrollCtrl,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: units.length,
      itemBuilder: (context, index) {
        return _PropertyCard(
          unit: units[index],
          index: index,
          scrollOffset: _scrollCtrl.hasClients ? _scrollCtrl.offset : 0,
          onTap: () => _openDetail(units[index]),
          onChatTap: () => _sendChatInquiry(units[index]),
        );
      },
    );
  }

  Widget _buildShimmerGrid() {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: 4,
      itemBuilder: (_, i) => _ShimmerCard(index: i),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: _forest.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.home_work_outlined,
                color: _forest.withValues(alpha: 0.5), size: 52),
          ),
          const SizedBox(height: 20),
          const Text(
            'Eşleşen mülk bulunamadı',
            style: TextStyle(
              color: _textDark, fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Filtreleri genişleterek tekrar deneyin.',
            style: TextStyle(color: _textLight, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, color: _textLight, size: 48),
          const SizedBox(height: 12),
          Text('Yüklenemedi', style: TextStyle(color: _textLight)),
        ],
      ),
    );
  }

  void _openDetail(VacantUnitItem unit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PropertyDetailSheet(
        unit: unit,
        onChatTap: () => _sendChatInquiry(unit),
      ),
    );
  }

  void _sendChatInquiry(VacantUnitItem unit) {
    Navigator.pop(context);
    // Set pending chat launch context with property info
    ref.read(chatLaunchProvider.notifier).launchForProperty(
      unit.unitId,
      unit.propertyName,
    );
    // Navigate to chat tab (index 5)
    widget.onNavigateToTab?.call(5);
    // Show confirmation snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${unit.propertyName} hakkında talep gönderildi!',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: _forest,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ExploreHeader
// ─────────────────────────────────────────────────────────────────────────────
class _ExploreHeader extends StatelessWidget {
  final TextEditingController searchCtrl;
  final bool showFilters;
  final VoidCallback onToggleFilters;
  final ValueChanged<String> onSearchChanged;

  const _ExploreHeader({
    required this.searchCtrl,
    required this.showFilters,
    required this.onToggleFilters,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Yeni Ev Keşfet',
                      style: TextStyle(
                        color: _forest,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Portföyümüzde sizin için mülkler',
                      style: TextStyle(
                        color: _textLight,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Search + filter row
          Row(
            children: [
              // Search field
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _divider, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: _cardShadow.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: searchCtrl,
                    style: const TextStyle(color: _textDark, fontSize: 14),
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: 'Lokasyon veya mülk adı...',
                      hintStyle: TextStyle(color: _textLight, fontSize: 13),
                      prefixIcon: Icon(Icons.search_rounded,
                          color: _textLight, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    onChanged: onSearchChanged,
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Filter toggle
              GestureDetector(
                onTap: onToggleFilters,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: showFilters ? _forest : _surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: showFilters ? _forest : _divider,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: showFilters
                            ? _forest.withValues(alpha: 0.2)
                            : _cardShadow.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    color: showFilters ? _surface : _textMid,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _FilterPanel
// ─────────────────────────────────────────────────────────────────────────────
class _FilterPanel extends StatelessWidget {
  final RangeValues priceRange;
  final String? selectedRoom;
  final Set<String> selectedFeatures;
  final ValueChanged<RangeValues> onPriceChanged;
  final ValueChanged<String?> onRoomSelected;
  final void Function(String) onFeatureToggled;
  final VoidCallback onApply;
  final VoidCallback onClear;

  const _FilterPanel({
    required this.priceRange,
    required this.selectedRoom,
    required this.selectedFeatures,
    required this.onPriceChanged,
    required this.onRoomSelected,
    required this.onFeatureToggled,
    required this.onApply,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _divider, width: 1),
        boxShadow: [
          BoxShadow(
            color: _cardShadow.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Price range
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Kira Aralığı',
                style: TextStyle(
                  color: _textMid, fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '₺${_fmtPrice(priceRange.start.round())} — ₺${_fmtPrice(priceRange.end.round())}',
                style: TextStyle(
                  color: _forest, fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: _forest,
              inactiveTrackColor: _forest.withValues(alpha: 0.12),
              thumbColor: _forest,
              overlayColor: _forest.withValues(alpha: 0.1),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 8,
              ),
            ),
            child: RangeSlider(
              values: priceRange,
              min: 0,
              max: 100000,
              divisions: 200,
              onChanged: onPriceChanged,
            ),
          ),

          const SizedBox(height: 12),
          Divider(color: _divider, height: 1),
          const SizedBox(height: 12),

          // Room count
          Text(
            'Oda Sayısı',
            style: TextStyle(
              color: _textMid, fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _roomOptions.map((room) {
              final isSelected = selectedRoom == room;
              return GestureDetector(
                onTap: () => onRoomSelected(isSelected ? null : room),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _forest
                        : _bg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? _forest : _divider,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    room,
                    style: TextStyle(
                      color: isSelected ? _surface : _textMid,
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 12),
          Divider(color: _divider, height: 1),
          const SizedBox(height: 12),

          // Features
          Text(
            'Özellikler',
            style: TextStyle(
              color: _textMid, fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _featureOptions.map((feat) {
              final key = feat['key'] as String;
              final label = feat['label'] as String;
              final icon = feat['icon'] as IconData;
              final isSelected = selectedFeatures.contains(key);
              return GestureDetector(
                onTap: () => onFeatureToggled(key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _forest.withValues(alpha: 0.1)
                        : _bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? _forest.withValues(alpha: 0.4)
                          : _divider,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 14,
                        color: isSelected ? _forest : _textLight,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        label,
                        style: TextStyle(
                          color: isSelected ? _forest : _textMid,
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onClear,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _textMid,
                    side: BorderSide(color: _divider),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Temizle',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: onApply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _forest,
                    foregroundColor: _surface,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Uygula',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtPrice(int v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toString();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PropertyCard
// Editorial magazine-style card with parallax
// ─────────────────────────────────────────────────────────────────────────────
class _PropertyCard extends StatefulWidget {
  final VacantUnitItem unit;
  final int index;
  final double scrollOffset;
  final VoidCallback onTap;
  final VoidCallback onChatTap;

  const _PropertyCard({
    required this.unit,
    required this.index,
    required this.scrollOffset,
    required this.onTap,
    required this.onChatTap,
  });

  @override
  State<_PropertyCard> createState() => _PropertyCardState();
}

class _PropertyCardState extends State<_PropertyCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _anim;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _anim = CurvedAnimation(
      parent: _animController,
      curve: const _DampedSpring(),
    );
    Future.delayed(Duration(milliseconds: 60 * widget.index), () {
      if (mounted) _animController.forward();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unit = widget.unit;
    final gradientColors = _propertyGradients[
        unit.unitId.hashCode % _propertyGradients.length];

    // Parallax: image shifts based on scroll position
    final cardTop = widget.index * 200.0;
    final viewportCenter = widget.scrollOffset + 400;
    final parallaxShift = ((cardTop - viewportCenter) / 400).clamp(-1.0, 1.0) * 20;

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - _anim.value)),
          child: Opacity(
            opacity: _anim.value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Container(
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: _cardShadow.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Image area ──────────────────────────────────
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      child: SizedBox(
                        height: 180,
                        width: double.infinity,
                        child: Transform.translate(
                          offset: Offset(parallaxShift, 0),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: gradientColors,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Stack(
                              children: [
                                // Decorative geometric pattern
                                Positioned(
                                  right: -20,
                                  bottom: -20,
                                  child: Icon(
                                    Icons.home_rounded,
                                    size: 120,
                                    color: Colors.white.withValues(alpha: 0.05),
                                  ),
                                ),
                                Positioned(
                                  left: -10,
                                  top: -10,
                                  child: Container(
                                    width: 60, height: 60,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.08),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                                // Property name overlay
                                Positioned(
                                  bottom: 14, left: 16,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        unit.propertyName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(Icons.location_on_rounded,
                                              color: Colors.white.withValues(alpha: 0.7),
                                              size: 12),
                                          const SizedBox(width: 3),
                                          Text(
                                            unit.address,
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.7),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
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

                    // Status badge
                    Positioned(
                      top: 14, left: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6, height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF4ADE80),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              'Kiralık',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Feature chips (top right)
                    if (unit.features.isNotEmpty)
                      Positioned(
                        top: 14, right: 14,
                        child: Wrap(
                          spacing: 4,
                          children: unit.features.take(2).map((feat) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                feat,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),

                // ── Info area ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left: specs
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _SpecChip(
                                  icon: Icons.door_front_door_outlined,
                                  label: unit.doorNumber,
                                  color: const Color(0xFF8B5CF6),
                                ),
                                if (unit.floor != null) ...[
                                  const SizedBox(width: 6),
                                  _SpecChip(
                                    icon: Icons.layers_outlined,
                                    label: '${unit.floor}',
                                    color: const Color(0xFF3B82F6),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (unit.features.isNotEmpty)
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: unit.features.take(3).map((f) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _bg,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      f,
                                      style: TextStyle(
                                        color: _textLight,
                                        fontSize: 10,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),

                      // Right: price + chat
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₺${_fmt(unit.rentPrice)}',
                                style: TextStyle(
                                  color: _forest,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                '/ aylık',
                                style: TextStyle(
                                  color: _textLight,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: widget.onChatTap,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _gold.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.chat_bubble_outline_rounded,
                                color: _gold,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmt(int v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toString();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SpecChip
// ─────────────────────────────────────────────────────────────────────────────
class _SpecChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SpecChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PropertyDetailSheet
// ─────────────────────────────────────────────────────────────────────────────
class _PropertyDetailSheet extends StatefulWidget {
  final VacantUnitItem unit;
  final VoidCallback onChatTap;

  const _PropertyDetailSheet({
    required this.unit,
    required this.onChatTap,
  });

  @override
  State<_PropertyDetailSheet> createState() => _PropertyDetailSheetState();
}

class _PropertyDetailSheetState extends State<_PropertyDetailSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _sheetAnimController;
  late Animation<double> _sheetAnim;

  @override
  void initState() {
    super.initState();
    _sheetAnimController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _sheetAnim = CurvedAnimation(
      parent: _sheetAnimController,
      curve: const _DampedSpring(),
    );
    _sheetAnimController.forward();
  }

  @override
  void dispose() {
    _sheetAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unit = widget.unit;
    final gradientColors = _propertyGradients[
        unit.unitId.hashCode % _propertyGradients.length];

    return AnimatedBuilder(
      animation: _sheetAnim,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 60 * (1 - _sheetAnim.value)),
          child: Opacity(
            opacity: _sheetAnim.value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: Container(
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: const BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: _divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: SizedBox(
                        height: 220,
                        width: double.infinity,
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: gradientColors,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  Positioned(
                                    right: -30, bottom: -30,
                                    child: Icon(
                                      Icons.home_rounded,
                                      size: 180,
                                      color: Colors.white.withValues(alpha: 0.04),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              bottom: 16, left: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8, height: 8,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF4ADE80),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Kiralık — Müsait',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Property name + address
                    Text(
                      unit.propertyName,
                      style: const TextStyle(
                        color: _textDark,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded,
                            color: _textLight, size: 16),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            unit.address,
                            style: TextStyle(
                              color: _textLight, fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    Divider(color: _divider),
                    const SizedBox(height: 20),

                    // Specs grid
                    Row(
                      children: [
                        _DetailTile(
                          icon: Icons.door_front_door_outlined,
                          label: 'Kapı No',
                          value: unit.doorNumber,
                          color: const Color(0xFF8B5CF6),
                        ),
                        const SizedBox(width: 12),
                        _DetailTile(
                          icon: Icons.layers_outlined,
                          label: 'Kat',
                          value: unit.floor ?? '—',
                          color: const Color(0xFF3B82F6),
                        ),
                        const SizedBox(width: 12),
                        _DetailTile(
                          icon: Icons.attach_money_rounded,
                          label: 'Kira',
                          value: '₺${_fmt(unit.rentPrice)}',
                          color: _forest,
                        ),
                        const SizedBox(width: 12),
                        _DetailTile(
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'Aidat',
                          value: '₺${_fmt(unit.duesAmount)}',
                          color: const Color(0xFFF59E0B),
                        ),
                      ],
                    ),

                    if (unit.features.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Divider(color: _divider),
                      const SizedBox(height: 20),
                      Text(
                        'Özellikler',
                        style: TextStyle(
                          color: _textDark,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: unit.features.map((f) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: _forest.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _forest.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Text(
                              f,
                              style: TextStyle(
                                color: _forest,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),

            // CTA
            Container(
              padding: EdgeInsets.fromLTRB(
                24, 16, 24, 16 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: _surface,
                boxShadow: [
                  BoxShadow(
                    color: _cardShadow.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '₺${_fmt(unit.rentPrice)}',
                          style: TextStyle(
                            color: _forest,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'aylık kira + ₺${_fmt(unit.duesAmount)} aidat',
                          style: TextStyle(
                            color: _textLight, fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: widget.onChatTap,
                      child: Container(
                        height: 54,
                        decoration: BoxDecoration(
                          color: _forest,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: _forest.withValues(alpha: 0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_rounded,
                                color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Bu eve de bakabilir miyiz?',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(int v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toString();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DetailTile
// ─────────────────────────────────────────────────────────────────────────────
class _DetailTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: 0.6),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ShimmerCard
// ─────────────────────────────────────────────────────────────────────────────
class _ShimmerCard extends StatefulWidget {
  final int index;
  const _ShimmerCard({required this.index});

  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1300),
      vsync: this,
    )..repeat();
    _anim = Tween<double>(begin: -2.0, end: 2.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _cardShadow.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image placeholder
              Container(
                height: 180,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _divider.withValues(alpha: 0.4 + _anim.value * 0.1),
                      _divider.withValues(alpha: 0.2 + _anim.value * 0.05),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
              ),
              // Info area
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _shimmerBox(80, 12),
                        const SizedBox(width: 8),
                        _shimmerBox(60, 12),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _shimmerBox(120, 10),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _shimmerBox(50, 10),
                        const SizedBox(width: 6),
                        _shimmerBox(50, 10),
                      ],
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

  Widget _shimmerBox(double w, double h) {
    return Container(
      width: w, height: h,
      decoration: BoxDecoration(
        color: _divider.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DampedSpring — custom spring curve
// ─────────────────────────────────────────────────────────────────────────────
class _DampedSpring extends Curve {
  const _DampedSpring();

  @override
  double transformInternal(double t) {
    const c1 = 1.70158;
    const c3 = c1 + 1;
    return 1 + c3 * ((t - 1) * (t - 1) * (t - 1)) + c1 * ((t - 1) * (t - 1));
  }
}
