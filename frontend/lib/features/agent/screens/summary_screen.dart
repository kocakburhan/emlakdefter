import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/colors.dart';
import '../../../core/network/api_client.dart';
import '../providers/dashboard_provider.dart';
import 'bi_analytics_screen.dart';

/// Activity Feed API Response Model
class ActivityItem {
  final String id;
  final String type;
  final String title;
  final String subtitle;
  final String icon;
  final String color;
  final DateTime timestamp;

  ActivityItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.timestamp,
  });

  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    final ts = json['timestamp'] as String?;
    DateTime parsedTime;
    if (ts != null) {
      // Backend sends UTC timestamps WITHOUT Z suffix
      // e.g., '2026-04-30T22:29:50.270655'
      //
      // DateTime.parse('2026-04-30T22:29:50') creates a LOCAL time DateTime
      // (Dart assumes naive datetime is local, not UTC!)
      //
      // WRONG: var dt = DateTime.parse(ts); // treats as 22:29 LOCAL
      //
      // CORRECT: Tell Dart this is UTC by appending Z, then convert to local:
      parsedTime = DateTime.parse('${ts}Z').toLocal();
    } else {
      parsedTime = DateTime.now();
    }
    return ActivityItem(
      id: json['id'] ?? '',
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      icon: json['icon'] ?? 'circle',
      color: json['color'] ?? 'textBody',
      timestamp: parsedTime,
    );
  }
}

/// Filter types for activity feed
enum ActivityFilter { all, payments, tickets, tenants, propertyOperations }

/// Özet Ekranı — Emlak Ofisi Genel Bakış ve Aktivite Feed'i
class SummaryScreen extends ConsumerStatefulWidget {
  const SummaryScreen({super.key});

  @override
  ConsumerState<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends ConsumerState<SummaryScreen> {
  final List<ActivityItem> _activities = [];
  bool _loading = false;
  bool _hasMore = true;
  int _offset = 0;
  ActivityFilter _selectedFilter = ActivityFilter.all;
  static const _limit = 15;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final resp = await ApiClient.dio.get(
        '/operations/activity-feed',
        queryParameters: {'limit': _limit, 'offset': _offset},
      );
      if (resp.statusCode == 200 && resp.data != null) {
        final data = resp.data;
        final items = (data['items'] as List?)
                ?.map((e) => ActivityItem.fromJson(e))
                .toList() ??
            [];
        if (mounted) {
          setState(() {
            _activities.addAll(items);
            _hasMore = data['has_more'] ?? false;
            _offset += items.length;
          });
        }
      } else {
        if (mounted) setState(() => _hasMore = false);
      }
    } catch (e) {
      // ignore on purpose - network errors show as empty list
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onRefresh() async {
    await ref.read(dashboardProvider.notifier).refresh();
    if (mounted) {
      setState(() {
        _activities.clear();
        _offset = 0;
        _hasMore = true;
      });
      await _loadActivities();
    }
  }

  List<ActivityItem> _filteredActivities() {
    if (_selectedFilter == ActivityFilter.all) return _activities;
    final typeMap = {
      ActivityFilter.payments: 'payment',
      ActivityFilter.tickets: 'ticket',
      ActivityFilter.tenants: 'tenant',
      ActivityFilter.propertyOperations: 'property_operation',
    };
    final targetType = typeMap[_selectedFilter] ?? '';
    return _activities.where((a) => a.type == targetType).toList();
  }

  void _onFilterChanged(ActivityFilter filter) {
    setState(() => _selectedFilter = filter);
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(dashboardProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.charcoal,
          backgroundColor: AppColors.surface,
          onRefresh: _onRefresh,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context)),
              SliverToBoxAdapter(child: dashboardState.when(
                loading: () => _buildLoadingAgencyInfo(),
                error: (_, __) => _buildAgencyInfo(DashboardMetrics()),
                data: (m) => _buildAgencyInfo(m),
              )),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(child: _buildBICard()),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(child: _buildFilterChips()),
              SliverToBoxAdapter(child: _buildActivityHeader(context)),
              SliverToBoxAdapter(child: _buildActivityList()),
              SliverToBoxAdapter(child: _buildLoadMore()),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  color: AppColors.charcoal, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ÖZET',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textTertiary,
                        letterSpacing: 1.5,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Emlak Ofisi Genel Bakış',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.charcoal,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: -0.1, end: 0, duration: 400.ms);
  }

  Widget _buildBICard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BIAnalyticsScreen()),
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF0066FF).withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00FFFF).withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF0066FF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.analytics_rounded,
                  color: Color(0xFF00FFFF),
                  size: 32,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'İş Zekası Paneli',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Doluluk, tahsilat, kiracı sirkülasyonu ve finansal analizler',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0066FF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Color(0xFF00FFFF),
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0, duration: 400.ms);
  }

  Widget _buildAgencyInfo(DashboardMetrics m) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.charcoal, AppColors.charcoalLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.charcoal.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text(
                          'E',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Emlakdefter',
                            style:
                                Theme.of(context).textTheme.titleLarge?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Aktif Ofis',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: Colors.white70,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    _buildStatItem('${m.totalProperties}', 'Bina', 0),
                    _buildStatItem('${m.totalUnits}', 'Daire', 1),
                    _buildStatItem('${m.occupiedUnits}', 'Doluluk', 2),
                    _buildStatItem(
                        '%${m.collectionRate.toStringAsFixed(0)}', 'Tahsilat', 3),
                  ],
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(duration: 500.ms, delay: 100.ms)
              .slideY(begin: 0.1, end: 0,
                  duration: 500.ms, delay: 100.ms, curve: Curves.easeOut),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _buildQuickStatCard(
                      'AKTİF KİRACILAR',
                      '${m.activeTenants}',
                      Icons.people_outline,
                      AppColors.success,
                      4)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildQuickStatCard(
                      'ÇALIŞANLAR',
                      '${m.staffCount}',
                      Icons.badge_outlined,
                      AppColors.slateGray,
                      5)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _buildQuickStatCard(
                      'BEKLEYEN TİCARET',
                      '${m.pendingTickets}',
                      Icons.warning_amber_outlined,
                      m.pendingTickets > 0
                          ? AppColors.error
                          : AppColors.success,
                      6)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildQuickStatCard(
                      'BOŞ DAİRELER',
                      '${m.vacantUnits}',
                      Icons.door_back_door_outlined,
                      AppColors.textTertiary,
                      7)),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, int index) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white60,
                  letterSpacing: 0.5,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatCard(
      String label, String value, IconData icon, Color color, int index) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.charcoal,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textTertiary,
                        letterSpacing: 0.5,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: 80 * index), duration: 300.ms)
        .slideX(begin: 0.05, end: 0,
            delay: Duration(milliseconds: 80 * index),
            duration: 300.ms, curve: Curves.easeOut);
  }

  Widget _buildLoadingAgencyInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.charcoal),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: Container(
                      height: 80,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border)))),
              Expanded(
                  child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border)))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      (ActivityFilter.all, 'Tümü'),
      (ActivityFilter.payments, 'Ödemeler'),
      (ActivityFilter.tickets, 'Biletler'),
      (ActivityFilter.tenants, 'Kiracılar'),
      (ActivityFilter.propertyOperations, 'Bina Operasyonları'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(f.$2),
              selected: isSelected,
              onSelected: (_) => _onFilterChanged(f.$1),
              backgroundColor: AppColors.surface,
              selectedColor: AppColors.charcoal.withValues(alpha: 0.15),
              labelStyle: TextStyle(
                color:
                    isSelected ? AppColors.charcoal : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              checkmarkColor: AppColors.charcoal,
              side: BorderSide(
                color: isSelected ? AppColors.charcoal : AppColors.border,
              ),
            ),
          );
        }).toList(),
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 300.ms);
  }

  Widget _buildActivityHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SON AKSİYONLAR',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Sistem activity\'si',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                    ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.charcoal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Canlı',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.charcoal,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 250.ms, duration: 300.ms);
  }

  Widget _buildActivityList() {
    final filtered = _filteredActivities();

    if (_loading && filtered.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.charcoal),
        ),
      );
    }

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              const Icon(Icons.inbox_outlined,
                  color: AppColors.textTertiary, size: 40),
              const SizedBox(height: 12),
              Text(
                'Henüz aksiyon yok',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: filtered.asMap().entries.map((entry) {
          final index = entry.key;
          final activity = entry.value;
          return _buildActivityItem(activity, index);
        }).toList(),
      ),
    );
  }

  Widget _buildActivityItem(ActivityItem activity, int index) {
    final colorMap = {
      'success': AppColors.success,
      'error': AppColors.error,
      'warning': AppColors.warning,
      'accent': AppColors.charcoal,
      'textBody': AppColors.textSecondary,
    };
    final color = colorMap[activity.color] ?? AppColors.textSecondary;

    final iconMap = {
      'payments': Icons.payments_rounded,
      'confirmation_number': Icons.confirmation_number_outlined,
      'engineering': Icons.engineering_outlined,
      'person_add': Icons.person_add_outlined,
      'home': Icons.home_outlined,
      'receipt': Icons.receipt_outlined,
    };
    final icon = iconMap[activity.icon] ?? Icons.circle_outlined;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.charcoal,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  activity.subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _formatTime(activity.timestamp),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: 60 * index), duration: 400.ms)
        .slideX(begin: 0.08, end: 0,
            delay: Duration(milliseconds: 60 * index),
            duration: 400.ms, curve: Curves.easeOut);
  }

  Widget _buildLoadMore() {
    if (!_hasMore) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.charcoal),
            )
          : GestureDetector(
              onTap: _loadActivities,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Center(
                  child: Text(
                    'Daha Fazla Göster',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.charcoal,
                        ),
                  ),
                ),
              ),
            ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Şimdi';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk';
    if (diff.inHours < 24) return '${diff.inHours} saat';
    if (diff.inDays < 7) return '${diff.inDays} gün';
    return '${dt.day}.${dt.month}';
  }
}