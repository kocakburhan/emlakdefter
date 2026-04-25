import 'dart:io' show File;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/colors.dart';
import '../../../core/offline/offline_cache_provider.dart';
import '../providers/building_operations_provider.dart';
import '../providers/properties_provider.dart';
import '../../../core/network/api_client.dart';

/// Bina Operasyonları — Şeffaflık Modülü (PRD §4.1.9)
/// Tam premium dark tema + staggered animasyonlar + kategori sistemi + medya kanıt
class BuildingOperationsTab extends ConsumerStatefulWidget {
  const BuildingOperationsTab({Key? key}) : super(key: key);

  @override
  ConsumerState<BuildingOperationsTab> createState() => _BuildingOperationsTabState();
}

class _BuildingOperationsTabState extends ConsumerState<BuildingOperationsTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _headerAnim;
  String? _categoryFilter;
  DateTimeRange? _dateFilter;

  @override
  void initState() {
    super.initState();
    _headerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _headerAnim.dispose();
    super.dispose();
  }

  // ─── Kategori tanımları ─────────────────────────────────────────────────────
  static final List<Map<String, dynamic>> _catList = [
    {'key': 'temizlik',    'label': 'Temizlik',    'icon': Icons.cleaning_services_rounded, 'color': const Color(0xFF4ECDC4)},
    {'key': 'asansor',     'label': 'Asansör',     'icon': Icons.elevator_rounded,           'color': const Color(0xFFFF6B6B)},
    {'key': 'elektrik',    'label': 'Elektrik',    'icon': Icons.bolt_rounded,               'color': const Color(0xFFFFD93D)},
    {'key': 'su_tesisat',  'label': 'Su Tesisat',  'icon': Icons.water_drop_rounded,         'color': const Color(0xFF6BCB77)},
    {'key': 'boya_badana', 'label': 'Boya/Badana', 'icon': Icons.format_paint_rounded,       'color': const Color(0xFFC9B1FF)},
    {'key': 'guvenlik',    'label': 'Güvenlik',    'icon': Icons.security_rounded,           'color': const Color(0xFFFF9F43)},
    {'key': 'peyzaj',      'label': 'Peyzaj',      'icon': Icons.grass_rounded,             'color': const Color(0xFF26DE81)},
    {'key': 'diger',       'label': 'Diğer',       'icon': Icons.more_horiz_rounded,         'color': const Color(0xFF778CA3)},
  ];

  static const _catColorMap = {
    'temizlik':    Color(0xFF4ECDC4),
    'asansor':     Color(0xFFFF6B6B),
    'elektrik':    Color(0xFFFFD93D),
    'su_tesisat':  Color(0xFF6BCB77),
    'boya_badana': Color(0xFFC9B1FF),
    'guvenlik':    Color(0xFFFF9F43),
    'peyzaj':      Color(0xFF26DE81),
    'diger':       Color(0xFF778CA3),
  };

  static IconData _catIcon(String? key) {
    switch (key) {
      case 'temizlik':    return Icons.cleaning_services_rounded;
      case 'asansor':     return Icons.elevator_rounded;
      case 'elektrik':    return Icons.bolt_rounded;
      case 'su_tesisat':  return Icons.water_drop_rounded;
      case 'boya_badana': return Icons.format_paint_rounded;
      case 'guvenlik':    return Icons.security_rounded;
      case 'peyzaj':      return Icons.grass_rounded;
      default:            return Icons.more_horiz_rounded;
    }
  }

  static String _catLabel(String? key) {
    if (key == null || key.isEmpty) return 'Diğer';
    switch (key) {
      case 'temizlik':    return 'Temizlik';
      case 'asansor':     return 'Asansör';
      case 'elektrik':    return 'Elektrik';
      case 'su_tesisat':  return 'Su Tesisat';
      case 'boya_badana': return 'Boya/Badana';
      case 'guvenlik':    return 'Güvenlik';
      case 'peyzaj':      return 'Peyzaj';
      default:            return 'Diğer';
    }
  }

  static Color _catColor(String? key) =>
      _catColorMap[key] ?? const Color(0xFF778CA3);

  // ─── Filtreleme ─────────────────────────────────────────────────────────────
  List<BuildingOperationModel> _filteredOps(BuildingOperationsState state) {
    var ops = state.operations;
    if (state.propertyFilter != null) {
      ops = ops.where((op) => op.propertyId == state.propertyFilter).toList();
    }
    if (state.financeFilter != null) {
      ops = ops.where((op) => op.isReflectedToFinance == state.financeFilter).toList();
    }
    if (_categoryFilter != null) {
      ops = ops.where((op) => op.category == _categoryFilter).toList();
    }
    if (_dateFilter != null) {
      ops = ops.where((op) {
        final d = op.createdAt;
        return !d.isBefore(_dateFilter!.start) && !d.isAfter(_dateFilter!.end.add(const Duration(days: 1)));
      }).toList();
    }
    return ops;
  }

  // ─── Header animasyonu ──────────────────────────────────────────────────────
  Widget _headerAnimWidget(Widget child, {int delayMs = 0}) {
    return AnimatedBuilder(
      animation: _headerAnim,
      builder: (context, _) {
        final curved = CurvedAnimation(
          parent: _headerAnim,
          curve: Interval(delayMs / 800, 1.0, curve: Curves.easeOutCubic),
        );
        return Opacity(
          opacity: curved.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - curved.value)),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(buildingOperationsProvider);
    final propsState = ref.watch(propertiesProvider);
    final ops = _filteredOps(state);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _headerAnimWidget(
                    const Text('BİNA YÖNETİMİ',
                      style: TextStyle(
                        color: Color(0xFF8B8B9A), fontSize: 11,
                        fontWeight: FontWeight.w700, letterSpacing: 2.5,
                      )),
                    delayMs: 0,
                  ),
                  const SizedBox(height: 4),
                  _headerAnimWidget(
                    const Text('Operasyon Merkezi',
                      style: TextStyle(
                        color: AppColors.charcoal, fontSize: 26,
                        fontWeight: FontWeight.bold, letterSpacing: -0.5,
                      )),
                    delayMs: 80,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),

            // ── Özet kartları ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _headerAnimWidget(
                _buildSummaryRow(state),
                delayMs: 160,
              ),
            ),
            const SizedBox(height: 12),

            // §5.3 — Pending sync banner
            Builder(builder: (ctx) {
              final pending = ref.watch(pendingSyncCountProvider);
              if (pending == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4A574).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD4A574).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_upload_outlined, color: Color(0xFFD4A574), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$pending işlem senkronizasyon bekliyor',
                          style: const TextStyle(color: Color(0xFFD4A574), fontSize: 13),
                        ),
                      ),
                      const Icon(Icons.refresh, color: Color(0xFFD4A574), size: 18),
                    ],
                  ),
                ),
              );
            }),


            // ── Filtreler ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _headerAnimWidget(
                _buildFilterSection(propsState, state),
                delayMs: 240,
              ),
            ),
            const SizedBox(height: 16),

            // ── Operasyon listesi ───────────────────────────────────────────
            Expanded(
              child: state.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.charcoal, strokeWidth: 2,
                      ),
                    )
                  : ops.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(24, 4, 24, 120),
                          itemCount: ops.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (ctx, idx) =>
                              _staggerCard(ctx, idx, ops[idx]),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  // ─── Özet kartları ──────────────────────────────────────────────────────────
  Widget _buildSummaryRow(BuildingOperationsState state) {
    final total = state.operations.fold(0, (sum, op) => sum + op.cost);
    final reflected = state.operations
        .where((op) => op.isReflectedToFinance)
        .fold(0, (sum, op) => sum + op.cost);
    final pending = total - reflected;

    return Row(
      children: [
        Expanded(child: _summaryCard('Toplam Maliyet', '₺${_fmt(total)}', AppColors.charcoal)),
        const SizedBox(width: 10),
        Expanded(child: _summaryCard('Finansa Yansıyan', '₺${_fmt(reflected)}', AppColors.success)),
        const SizedBox(width: 10),
        Expanded(child: _summaryCard('Bekleyen', '₺${_fmt(pending)}', AppColors.warning)),
      ],
    );
  }

  Widget _summaryCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha:0.15), color.withValues(alpha:0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha:0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color, fontSize: 15, fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Filtre bölümü ─────────────────────────────────────────────────────────
  Widget _buildFilterSection(
    AsyncValue<List<PropertyModel>> propsState,
    BuildingOperationsState state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Kategori chips
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _filterChip(
                label: 'Tümü',
                isSelected: _categoryFilter == null,
                onTap: () => setState(() => _categoryFilter = null),
              ),
              const SizedBox(width: 8),
              ..._catList.map((cat) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _filterChip(
                  label: cat['label'] as String,
                  isSelected: _categoryFilter == cat['key'],
                  color: cat['color'] as Color,
                  icon: cat['icon'] as IconData,
                  onTap: () => setState(() =>
                    _categoryFilter = _categoryFilter == cat['key'] ? null : cat['key'],
                  ),
                ),
              )),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Bina + Finans + Tarih filter row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Tümü / Finans filtreleri
              _filterChip(
                label: 'Finansa Yansıyan',
                isSelected: state.financeFilter == true,
                color: AppColors.success,
                onTap: () => ref.read(buildingOperationsProvider.notifier).setFinanceFilter(
                  state.financeFilter == true ? null : true,
                ),
              ),
              const SizedBox(width: 8),
              _filterChip(
                label: 'Bekleyen',
                isSelected: state.financeFilter == false,
                color: AppColors.warning,
                onTap: () => ref.read(buildingOperationsProvider.notifier).setFinanceFilter(
                  state.financeFilter == false ? null : false,
                ),
              ),
              const SizedBox(width: 8),
              // Bina filtreleri
              if (propsState.value != null)
                ...propsState.value!.map((p) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _filterChip(
                    label: p.name,
                    isSelected: state.propertyFilter == p.id,
                    color: AppColors.charcoal,
                    onTap: () => ref.read(buildingOperationsProvider.notifier).setPropertyFilter(
                      state.propertyFilter == p.id ? null : p.id,
                    ),
                  ),
                )),
              const SizedBox(width: 8),
              // Tarih filtresi
              _filterChip(
                label: _dateFilter == null
                    ? 'Tarih'
                    : '${_shortDate(_dateFilter!.start)} - ${_shortDate(_dateFilter!.end)}',
                isSelected: _dateFilter != null,
                color: const Color(0xFF9B59B6),
                icon: Icons.calendar_today_rounded,
                onTap: () => _showDateRangePicker(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterChip({
    required String label,
    required bool isSelected,
    Color? color,
    IconData? icon,
    required VoidCallback onTap,
  }) {
    final chipColor = color ?? AppColors.charcoal;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : chipColor.withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: chipColor.withValues(alpha:isSelected ? 0 : 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: isSelected ? Colors.white : chipColor),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : chipColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _dateFilter,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.charcoal,
              surface: Color(0xFF1A1A2E),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dateFilter = picked);
    }
  }

  // ─── Boş durum ─────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, anim, child) => Opacity(
          opacity: anim,
          child: Transform.scale(scale: 0.8 + 0.2 * anim, child: child),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.charcoal.withValues(alpha:0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.engineering_outlined,
                size: 48,
                color: AppColors.charcoal.withValues(alpha:0.4),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Henüz operasyon yok',
              style: TextStyle(
                color: AppColors.charcoal, fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Yukarıdaki + ile ilk kaydı oluşturun',
              style: TextStyle(
                color: AppColors.textSecondary, fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Staggered kart girişi ──────────────────────────────────────────────────
  Widget _staggerCard(BuildContext context, int index, BuildingOperationModel op) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + (index * 60).clamp(0, 350)),
      curve: Curves.easeOutCubic,
      builder: (context, anim, child) => Opacity(
        opacity: anim,
        child: Transform.translate(offset: Offset(0, 24 * (1 - anim)), child: child),
      ),
      child: _OperationCard(op: op, onTap: () => _showDetailSheet(context, op)),
    );
  }

  // ─── Operasyon kartı ────────────────────────────────────────────────────────
  Widget _buildFAB() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.charcoal, AppColors.charcoal.withValues(alpha:0.65)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.charcoal.withValues(alpha:0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showCreateDialog(context),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, color: Colors.white, size: 22),
                SizedBox(width: 8),
                Text(
                  'Yeni Kayıt',
                  style: TextStyle(
                    color: AppColors.charcoal, fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Operation Card ───────────────────────────────────────────────────────────
class _OperationCard extends StatelessWidget {
  final BuildingOperationModel op;
  final VoidCallback onTap;

  const _OperationCard({required this.op, required this.onTap});

  static const _catColorMap = {
    'temizlik':    Color(0xFF4ECDC4),
    'asansor':     Color(0xFFFF6B6B),
    'elektrik':    Color(0xFFFFD93D),
    'su_tesisat':  Color(0xFF6BCB77),
    'boya_badana': Color(0xFFC9B1FF),
    'guvenlik':    Color(0xFFFF9F43),
    'peyzaj':      Color(0xFF26DE81),
    'diger':       Color(0xFF778CA3),
  };

  Color get _catColor => _catColorMap[op.category] ?? const Color(0xFF778CA3);

  IconData get _catIcon {
    switch (op.category) {
      case 'temizlik':    return Icons.cleaning_services_rounded;
      case 'asansor':     return Icons.elevator_rounded;
      case 'elektrik':    return Icons.bolt_rounded;
      case 'su_tesisat':  return Icons.water_drop_rounded;
      case 'boya_badana': return Icons.format_paint_rounded;
      case 'guvenlik':    return Icons.security_rounded;
      case 'peyzaj':      return Icons.grass_rounded;
      default:            return Icons.more_horiz_rounded;
    }
  }

  String get _catLabel {
    if (op.category == null || op.category!.isEmpty) return 'Diğer';
    switch (op.category) {
      case 'temizlik':    return 'Temizlik';
      case 'asansor':     return 'Asansör';
      case 'elektrik':    return 'Elektrik';
      case 'su_tesisat':  return 'Su Tesisat';
      case 'boya_badana': return 'Boya/Badana';
      case 'guvenlik':    return 'Güvenlik';
      case 'peyzaj':      return 'Peyzaj';
      default:            return 'Diğer';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReflected = op.isReflectedToFinance;
    final statusColor = isReflected ? AppColors.success : AppColors.warning;

    return Opacity(
      opacity: 0.98,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _catColor.withValues(alpha:0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _catColor.withValues(alpha:0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Üst satır: kategori badge + mülk + fiyat
                  Row(
                    children: [
                      // Kategori chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: _catColor.withValues(alpha:0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _catColor.withValues(alpha:0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_catIcon, size: 11, color: _catColor),
                            const SizedBox(width: 5),
                            Text(
                              _catLabel,
                              style: TextStyle(
                                color: _catColor, fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Mülk adı
                      if (op.propertyName != null) ...[
                        Icon(Icons.home_outlined, size: 12,
                            color: AppColors.textTertiary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            op.propertyName!,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        '₺${_fmt(op.cost)}',
                        style: const TextStyle(
                          color: AppColors.charcoal, fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Başlık
                  Text(
                    op.title,
                    style: const TextStyle(
                      color: AppColors.charcoal, fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Açıklama
                  if (op.description != null && op.description!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      op.description!,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 14),

                  // Alt satır: tarih + fatura + finanans durumu
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 11, color: AppColors.textTertiary),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(op.createdAt),
                        style: TextStyle(
                          color: AppColors.textTertiary, fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Fatura kanıtı
                      if (op.invoiceUrl != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha:0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_long_rounded,
                                  size: 10, color: AppColors.success),
                              const SizedBox(width: 4),
                              Text(
                                'Fatura',
                                style: TextStyle(
                                  color: AppColors.success, fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha:0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isReflected
                                  ? Icons.check_circle_rounded
                                  : Icons.hourglass_top_rounded,
                              size: 11,
                              color: statusColor,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isReflected ? 'Finansa Yansıdı' : 'Bekliyor',
                              style: TextStyle(
                                color: statusColor, fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            // §5.3 — Cloud upload icon for pending sync
                            if (op.isPendingSync) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.cloud_upload_outlined,
                                size: 12,
                                color: Color(0xFFD4A574),
                              ),
                            ],
                          ],
                        ),
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

  String _formatDate(DateTime dt) {
    final aylar = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
    return '${dt.day.toString().padLeft(2, '0')} ${aylar[dt.month - 1]} ${dt.year}';
  }
}

// ─── Yeni Operasyon Dialog ───────────────────────────────────────────────────
extension _BuildingOperationsTabStateExt on _BuildingOperationsTabState {
  Future<void> _showCreateDialog(BuildContext context) async {
    final propsState = ref.read(propertiesProvider);
    final props = propsState.value ?? [];
    if (props.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Önce bir mülk ekleyin'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    String? selectedPropertyId = props.first.id;
    String? selectedCategory;
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final costCtrl = TextEditingController(text: '0');
    bool reflectedToFinance = false;
    String? invoiceUrl;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          decoration: const BoxDecoration(
            color: Color(0xFF13131F),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Başlık
                const Text(
                  'Yeni Bina Operasyonu',
                  style: TextStyle(
                    color: AppColors.charcoal, fontSize: 20,
                    fontWeight: FontWeight.bold, letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Bakım, onarım ve diğer bina giderlerini kaydedin',
                  style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 12,
                  ),
                ),
                const SizedBox(height: 24),

                // Kategori seçimi
                const Text(
                  'Kategori',
                  style: TextStyle(
                    color: AppColors.charcoal, fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _BuildingOperationsTabState._catList.map((cat) {
                    final isSelected = selectedCategory == cat['key'];
                    final catColor = cat['color'] as Color;
                    return GestureDetector(
                      onTap: () => setSheetState(() =>
                        selectedCategory = isSelected ? null : cat['key'] as String?,
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? catColor
                              : catColor.withValues(alpha:0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? catColor
                                : catColor.withValues(alpha:0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(cat['icon'] as IconData,
                                size: 14,
                                color: isSelected
                                    ? Colors.white
                                    : catColor),
                            const SizedBox(width: 6),
                            Text(
                              cat['label'] as String,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : catColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Mülk seçimi
                const Text(
                  'Bina / Mülk',
                  style: TextStyle(
                    color: AppColors.charcoal, fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedPropertyId,
                      dropdownColor: AppColors.surface,
                      style: const TextStyle(color: AppColors.charcoal),
                      iconEnabledColor: AppColors.textSecondary,
                      items: props.map((p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(p.name,
                            style: const TextStyle(color: Colors.white)),
                      )).toList(),
                      onChanged: (v) => setSheetState(() => selectedPropertyId = v),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Başlık
                _textField(
                  controller: titleCtrl,
                  label: 'Başlık (örn: [Asansör] Yıllık Bakım)',
                  icon: Icons.title,
                ),
                const SizedBox(height: 14),

                // Açıklama
                _textField(
                  controller: descCtrl,
                  label: 'Açıklama (opsiyonel)',
                  icon: Icons.description_outlined,
                  maxLines: 2,
                ),
                const SizedBox(height: 14),

                // Maliyet
                _textField(
                  controller: costCtrl,
                  label: 'Maliyet (TL)',
                  icon: Icons.attach_money,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 14),

                // Fatura kanıtı — medya yükleme
                _InvoiceUploader(
                  onInvoiceUrlChanged: (url) {
                    setSheetState(() {
                      invoiceUrl = url;
                    });
                  },
                ),
                const SizedBox(height: 14),

                // Finansa yansıt toggle
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha:0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.account_balance_wallet_outlined,
                            color: AppColors.success, size: 18),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Finansa Yansıt',
                              style: TextStyle(
                                color: AppColors.charcoal, fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Maliyeti gelir/gider tablosuna ekle',
                              style: TextStyle(
                                color: Color(0xFF6B6B7B), fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: reflectedToFinance,
                        activeColor: AppColors.success,
                        onChanged: (v) =>
                            setSheetState(() => reflectedToFinance = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Kaydet butonu
                ElevatedButton(
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty) return;
                    final cost = int.tryParse(costCtrl.text.trim()) ?? 0;
                    final success = await ref
                        .read(buildingOperationsProvider.notifier)
                        .createOperation(
                          propertyId: selectedPropertyId!,
                          title: titleCtrl.text.trim(),
                          description: descCtrl.text.trim().isEmpty
                              ? null
                              : descCtrl.text.trim(),
                          cost: cost,
                          invoiceUrl: invoiceUrl,
                          category: selectedCategory,
                          isReflectedToFinance: reflectedToFinance,
                        );
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      if (success) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Kayıt oluşturuldu'),
                              backgroundColor: AppColors.success,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        }
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.charcoal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Kaydet',
                    style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withValues(alpha:0.35)),
          prefixIcon: Icon(icon, color: AppColors.charcoal, size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14,
          ),
        ),
      ),
    );
  }
}

// ─── Detay Sheet ──────────────────────────────────────────────────────────────
extension _DetailSheet on _BuildingOperationsTabState {
  void _showDetailSheet(BuildContext context, BuildingOperationModel op) {
    final isReflected = op.isReflectedToFinance;
    final statusColor = isReflected ? AppColors.success : AppColors.warning;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF13131F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header: kategori chip + başlık
            if (op.category != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (_BuildingOperationsTabState._catColorMap[op.category] ?? const Color(0xFF778CA3))
                          .withValues(alpha:0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _BuildingOperationsTabState._catIcon(op.category),
                      size: 12,
                      color: _BuildingOperationsTabState._catColor(op.category),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _BuildingOperationsTabState._catLabel(op.category),
                      style: TextStyle(
                        color: _BuildingOperationsTabState._catColor(op.category),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              op.title,
              style: const TextStyle(
                color: AppColors.charcoal, fontSize: 20,
                fontWeight: FontWeight.bold, letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            if (op.propertyName != null)
              Row(
                children: [
                  Icon(Icons.home_outlined,
                      size: 13, color: Colors.white.withValues(alpha:0.35)),
                  const SizedBox(width: 5),
                  Text(
                    op.propertyName!,
                    style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 20),

            // Açıklama
            if (op.description != null && op.description!.isNotEmpty) ...[
              Text(
                op.description!,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14, height: 1.6,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Maliyet kartı
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.charcoal.withValues(alpha:0.12),
                    AppColors.charcoal.withValues(alpha:0.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.charcoal.withValues(alpha:0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.charcoal.withValues(alpha:0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child:
                        Icon(Icons.payments_outlined, color: AppColors.charcoal),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Maliyet',
                      style: TextStyle(
                        color: Color(0xFF8B8B9A), fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    '₺${_fmt(op.cost)}',
                    style: const TextStyle(
                      color: AppColors.charcoal, fontSize: 22,
                      fontWeight: FontWeight.bold, letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Finans durumu
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha:0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: statusColor.withValues(alpha:0.15)),
              ),
              child: Row(
                children: [
                  Icon(
                    isReflected
                        ? Icons.check_circle_rounded
                        : Icons.hourglass_top_rounded,
                    color: statusColor, size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isReflected
                          ? 'Finansa Yansıdı'
                          : 'Finansa Yansıtılmadı',
                      style: TextStyle(
                        color: statusColor, fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    _formatDate(op.createdAt),
                    style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // Fatura kanıtı
            if (op.invoiceUrl != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha:0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.success.withValues(alpha:0.12)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.receipt_long_rounded,
                        color: AppColors.success, size: 20),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Fatura kanıtı mevcut',
                        style: TextStyle(
                          color: AppColors.charcoal, fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(Icons.open_in_new,
                        color: AppColors.textTertiary, size: 16),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Action buttons
            if (!isReflected)
              ElevatedButton(
                onPressed: () async {
                  final success = await ref
                      .read(buildingOperationsProvider.notifier)
                      .updateOperation(
                        id: op.id,
                        isReflectedToFinance: true,
                      );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (success && ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: const Text('Finansa yansıtıldı'),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Finansa Yansıt',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    title: const Text(
                      'Sil?',
                      style: TextStyle(color: Colors.white),
                    ),
                    content: const Text(
                      'Bu kaydı silmek istediğinize emin misiniz?',
                      style: TextStyle(color: Color(0xFF8B8B9A)),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('İptal'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          'Sil',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref
                      .read(buildingOperationsProvider.notifier)
                      .deleteOperation(op.id);
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text(
                'Kaydı Sil',
                style: TextStyle(color: AppColors.error),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── Yardımcı ─────────────────────────────────────────────────────────────────
String _shortDate(DateTime dt) {
  final aylar = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
  return '${dt.day} ${aylar[dt.month - 1]}';
}

String _fmt(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return value.toStringAsFixed(0);
}

String _formatDate(DateTime dt) {
  final aylar = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
  return '${dt.day.toString().padLeft(2, '0')} ${aylar[dt.month - 1]} ${dt.year}';
}

// ─── Fatura / Kanıt Yükleyici Widget ─────────────────────────────────────────
class _InvoiceUploader extends StatefulWidget {
  final void Function(String? url) onInvoiceUrlChanged;

  const _InvoiceUploader({required this.onInvoiceUrlChanged});

  @override
  State<_InvoiceUploader> createState() => _InvoiceUploaderState();
}

class _InvoiceUploaderState extends State<_InvoiceUploader> {
  String? _uploadedUrl;
  bool _isUploading = false;
  String? _fileName;

  Future<void> _pickAndUpload() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      );

      if (result == null || result.files.isEmpty) return;

      final platformFile = result.files.single;
      setState(() {
        _isUploading = true;
        _fileName = platformFile.name;
      });

      final multipartFile = platformFile.bytes != null
          ? MultipartFile.fromBytes(platformFile.bytes!, filename: platformFile.name)
          : (platformFile.path != null
              ? MultipartFile.fromBytes(await File(platformFile.path!).readAsBytes(), filename: platformFile.name)
              : null);

      if (multipartFile == null) return;

      final formData = FormData.fromMap({
        'file': multipartFile,
        'category': 'building_ops',
      });

      final resp = await ApiClient.dio.post('/upload/media', data: formData);

      if (resp.statusCode == 200 && resp.data['url'] != null) {
        setState(() {
          _uploadedUrl = resp.data['url'];
          _isUploading = false;
        });
        widget.onInvoiceUrlChanged(_uploadedUrl);
      } else {
        setState(() => _isUploading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Yükleme başarısız'), backgroundColor: AppColors.error),
          );
        }
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFile = _uploadedUrl != null || _isUploading;

    return GestureDetector(
      onTap: _isUploading ? null : _pickAndUpload,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasFile
                ? AppColors.success.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.charcoal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.charcoal),
                    )
                  : Icon(
                      hasFile ? Icons.check_circle : Icons.receipt_long_rounded,
                      color: hasFile ? AppColors.success : AppColors.charcoal,
                      size: 20,
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isUploading
                        ? 'Yükleniyor...'
                        : _uploadedUrl != null
                            ? 'Fatura yüklendi'
                            : 'Fatura / Kanıt Ekle',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _isUploading
                        ? _fileName ?? 'Dosya seçildi'
                        : _uploadedUrl != null
                            ? _fileName ?? 'Kaydedildi'
                            : 'Fotoğraf veya PDF — Hetzner\'a yüklenecek',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              hasFile ? Icons.check : Icons.add_photo_alternate_outlined,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
