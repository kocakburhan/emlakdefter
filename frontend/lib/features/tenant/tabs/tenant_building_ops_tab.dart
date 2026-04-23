import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../providers/tenant_provider.dart';

// ──────────────────────────────────────────────
// "Transparency Ledger" — Tenant Building Ops
// Honest, clean, architectural blueprint feel
// PRD §4.2.4
// ──────────────────────────────────────────────

const _bg = AppColors.background;
const _surface = AppColors.surface;
const _surface2 = AppColors.surfaceVariant;
const _border = AppColors.border;
const _teal = AppColors.success;
const _coral = AppColors.error;
const _white = AppColors.textOnPrimary;
const _muted = AppColors.textSecondary;
const _dim = AppColors.textTertiary;

// Category definitions for building operations
final _catList = [
  {'key': 'all', 'label': 'Tümü', 'icon': Icons.dns_rounded, 'color': Color(0xFF64748B)},
  {'key': 'cleaning', 'label': 'Temizlik', 'icon': Icons.cleaning_services_rounded, 'color': Color(0xFF06B6D4)},
  {'key': 'repair', 'label': 'Tamirat', 'icon': Icons.build_rounded, 'color': Color(0xFFEF4444)},
  {'key': 'elevator', 'label': 'Asansör', 'icon': Icons.elevator_rounded, 'color': Color(0xFFF59E0B)},
  {'key': 'plumbing', 'label': 'Tesisat', 'icon': Icons.plumbing_rounded, 'color': Color(0xFF3B82F6)},
  {'key': 'electrical', 'label': 'Elektrik', 'icon': Icons.electrical_services_rounded, 'color': Color(0xFFFFC107)},
  {'key': 'painting', 'label': 'Boya', 'icon': Icons.format_paint_rounded, 'color': Color(0xFF8B5CF6)},
  {'key': 'garden', 'label': 'Bahçe', 'icon': Icons.grass_rounded, 'color': Color(0xFF22C55E)},
  {'key': 'security', 'label': 'Güvenlik', 'icon': Icons.security_rounded, 'color': Color(0xFFFF6B6B)},
  {'key': 'other', 'label': 'Diğer', 'icon': Icons.miscellaneous_services_rounded, 'color': Color(0xFF6B7280)},
];

Color _catColor(String title) {
  final t = title.toLowerCase();
  if (t.contains('temiz') || t.contains('clean')) return const Color(0xFF06B6D4);
  if (t.contains('asansör') || t.contains('elevator')) return const Color(0xFFF59E0B);
  if (t.contains('tamir') || t.contains('bakım') || t.contains('repair')) return const Color(0xFFEF4444);
  if (t.contains('tesisat') || t.contains('su') || t.contains('plumb')) return const Color(0xFF3B82F6);
  if (t.contains('elektrik') || t.contains('electric')) return const Color(0xFFFFC107);
  if (t.contains('boya') || t.contains('paint')) return const Color(0xFF8B5CF6);
  if (t.contains('bahçe') || t.contains('garden')) return const Color(0xFF22C55E);
  if (t.contains('güvenlik') || t.contains('security')) return const Color(0xFFFF6B6B);
  return const Color(0xFF6B7280);
}

IconData _catIcon(String title) {
  final t = title.toLowerCase();
  if (t.contains('temiz') || t.contains('clean')) return Icons.cleaning_services_rounded;
  if (t.contains('asansör') || t.contains('elevator')) return Icons.elevator_rounded;
  if (t.contains('tamir') || t.contains('bakım') || t.contains('repair')) return Icons.build_rounded;
  if (t.contains('tesisat') || t.contains('su') || t.contains('plumb')) return Icons.plumbing_rounded;
  if (t.contains('elektrik') || t.contains('electric')) return Icons.electrical_services_rounded;
  if (t.contains('boya') || t.contains('paint')) return Icons.format_paint_rounded;
  if (t.contains('bahçe') || t.contains('garden')) return Icons.grass_rounded;
  if (t.contains('güvenlik') || t.contains('security')) return Icons.security_rounded;
  return Icons.miscellaneous_services_rounded;
}

class TenantBuildingOpsTab extends ConsumerStatefulWidget {
  const TenantBuildingOpsTab({super.key});

  @override
  ConsumerState<TenantBuildingOpsTab> createState() => _TenantBuildingOpsTabState();
}

class _TenantBuildingOpsTabState extends ConsumerState<TenantBuildingOpsTab> {
  String _selectedCat = 'all';

  @override
  Widget build(BuildContext context) {
    final tenantState = ref.watch(tenantProvider);
    final logsState = ref.watch(tenantBuildingLogsProvider);
    final propertyName = tenantState.value?.propertyName ?? 'Binamız';

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _teal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _teal.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: const Icon(Icons.account_balance_rounded,
                            color: _teal, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Şeffaflık Panosu',
                              style: TextStyle(
                                color: _white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              propertyName,
                              style: TextStyle(color: _muted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Summary cards ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: logsState.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (logs) {
                  final totalCost = logs.fold(0, (sum, l) => sum + l.cost);
                  final totalLog = logs.length;
                  return Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          label: 'Toplam Harcama',
                          value: '₺${_fmt(totalCost)}',
                          icon: Icons.account_balance_wallet_outlined,
                          color: _coral,
                          index: 0,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SummaryCard(
                          label: 'Kayıtlı İşlem',
                          value: '$totalLog',
                          icon: Icons.receipt_long_outlined,
                          color: _teal,
                          index: 1,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // ── Info banner ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _teal.withValues(alpha: 0.07),
                      _teal.withValues(alpha: 0.02),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _teal.withValues(alpha: 0.12),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.visibility_outlined,
                        color: _teal, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Verdiğiniz aidatların nereye harcandığını şeffafça takip edin.',
                        style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ── Category filter chips ────────────────────────────────
            SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _catList.length,
                itemBuilder: (context, index) {
                  final cat = _catList[index];
                  final isSelected = _selectedCat == cat['key'];
                  final catColor = cat['color'] as Color;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedCat = cat['key'] as String),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? catColor.withValues(alpha: 0.2)
                              : _surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? catColor.withValues(alpha: 0.5)
                                : _border,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              cat['icon'] as IconData,
                              color: isSelected ? catColor : _dim,
                              size: 14,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              cat['label'] as String,
                              style: TextStyle(
                                color: isSelected ? catColor : _muted,
                                fontSize: 12,
                                fontWeight:
                                    isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            // ── Timeline / Log list ─────────────────────────────────
            Expanded(
              child: logsState.when(
                loading: () => _buildShimmerTimeline(),
                error: (e, _) => _buildError(),
                data: (logs) {
                  // Filter by category
                  final filtered = _selectedCat == 'all'
                      ? logs
                      : logs.where((log) {
                          final t = log.title.toLowerCase();
                          final catKey = _selectedCat;
                          if (catKey == 'cleaning') return t.contains('temiz') || t.contains('clean');
                          if (catKey == 'repair') return t.contains('tamir') || t.contains('bakım') || t.contains('repair');
                          if (catKey == 'elevator') return t.contains('asansör') || t.contains('elevator');
                          if (catKey == 'plumbing') return t.contains('tesisat') || t.contains('su') || t.contains('plumb');
                          if (catKey == 'electrical') return t.contains('elektrik') || t.contains('electric');
                          if (catKey == 'painting') return t.contains('boya') || t.contains('paint');
                          if (catKey == 'garden') return t.contains('bahçe') || t.contains('garden');
                          if (catKey == 'security') return t.contains('güvenlik') || t.contains('security');
                          return true;
                        }).toList();

                  if (filtered.isEmpty) {
                    return _buildEmptyState();
                  }
                  return _buildTimeline(filtered);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline(List<BuildingLogItem> logs) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        return _TimelineEntry(
          log: logs[index],
          isLast: index == logs.length - 1,
          index: index,
        );
      },
    );
  }

  Widget _buildShimmerTimeline() {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: 5,
      itemBuilder: (_, __) => _ShimmerEntry(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _surface,
              shape: BoxShape.circle,
              border: Border.all(color: _border, width: 1),
            ),
            child: Icon(Icons.check_circle_outline_rounded,
                color: _teal, size: 48),
          ),
          const SizedBox(height: 16),
          Text(
            _selectedCat == 'all'
                ? 'Henüz işlem kaydedilmedi'
                : 'Bu kategoride işlem yok',
            style: TextStyle(
                color: _white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Ofis ilk harcama kaydını girdiğinde\nburada şeffafça görünecek.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 13, height: 1.5),
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
          Icon(Icons.cloud_off_rounded, color: _muted, size: 48),
          const SizedBox(height: 12),
          Text('Veriler yüklenemedi', style: TextStyle(color: _muted)),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// _SummaryCard
// ──────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final int index;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 100)),
      curve: Curves.easeOutCubic,
      builder: (context, anim, child) {
        return Opacity(
          opacity: anim,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - anim)),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(color: _muted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// _TimelineEntry
// Vertical timeline card
// ──────────────────────────────────────────────
class _TimelineEntry extends StatelessWidget {
  final BuildingLogItem log;
  final bool isLast;
  final int index;

  const _TimelineEntry({
    required this.log,
    required this.isLast,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final catColor = _catColor(log.title);
    final catIcon = _catIcon(log.title);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 350 + (index * 60)),
      curve: Curves.easeOutCubic,
      builder: (context, anim, child) {
        return Opacity(
          opacity: anim,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - anim)),
            child: child,
          ),
        );
      },
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Timeline line + dot
            SizedBox(
              width: 48,
              child: Column(
                children: [
                  // Top line
                  Container(
                    width: 2,
                    height: 12,
                    color: isLast ? Colors.transparent : _border,
                  ),
                  // Dot
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: catColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: catColor.withValues(alpha: 0.4),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  // Remaining line
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isLast ? Colors.transparent : _border,
                    ),
                  ),
                ],
              ),
            ),

            // Card
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: catColor.withValues(alpha: 0.12),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Category icon
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(catIcon, color: catColor, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                log.title,
                                style: const TextStyle(
                                  color: _white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatDate(log.createdAt),
                                style: TextStyle(color: _dim, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        // Cost badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _coral.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _coral.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '₺${_fmt(log.cost)}',
                            style: const TextStyle(
                              color: _coral,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (log.description != null &&
                        log.description!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _surface2,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          log.description!,
                          style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Bugün';
    if (diff.inDays == 1) return 'Dün';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }
}

// ──────────────────────────────────────────────
// _ShimmerEntry
// ──────────────────────────────────────────────
class _ShimmerEntry extends StatefulWidget {
  @override
  State<_ShimmerEntry> createState() => _ShimmerEntryState();
}

class _ShimmerEntryState extends State<_ShimmerEntry>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
    _anim = Tween<double>(begin: -1.0, end: 2.0).animate(_ctrl);
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
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline
              SizedBox(
                width: 48,
                child: Column(
                  children: [
                    Container(width: 2, height: 12, color: Colors.transparent),
                    Container(width: 14, height: 14,
                        decoration: BoxDecoration(
                          color: _surface2,
                          shape: BoxShape.circle,
                        )),
                    Expanded(child: Container(width: 2, color: _border)),
                  ],
                ),
              ),
              // Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _border, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: _surface2,
                                borderRadius: BorderRadius.circular(10),
                              )),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 120, height: 13,
                                  decoration: BoxDecoration(
                                    color: _surface2,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  width: 80, height: 10,
                                  decoration: BoxDecoration(
                                    color: _surface2,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _fmt(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return value.toString();
}
