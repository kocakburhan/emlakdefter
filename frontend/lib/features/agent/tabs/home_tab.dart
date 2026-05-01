import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/colors.dart';
import '../providers/dashboard_provider.dart';
import '../screens/activity_feed_screen.dart';
import '../screens/bi_analytics_screen.dart';
import '../screens/pending_operations_screen.dart';
import '../screens/scheduler_control_screen.dart';
import '../../../core/offline/offline_cache_provider.dart';

class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(dashboardProvider);

    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.charcoal,
        backgroundColor: AppColors.surface,
        onRefresh: () async {
          ref.read(dashboardProvider.notifier).refresh();
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // HEADER
            SliverToBoxAdapter(
              child: _buildHeader(context),
            ),

            // KPI CARDS
            SliverToBoxAdapter(
              child: dashboardState.when(
                loading: () => _buildLoadingKpis(),
                error: (_, __) => _buildEmptyState(),
                data: (m) => _buildKpiSection(m),
              ),
            ),

            // ACTIVITY FEED
            SliverToBoxAdapter(
              child: _buildActivitySection(),
            ),

            // Bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
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
                      "HOŞ GELDİNİZ",
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textTertiary,
                            letterSpacing: 1.5,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Emlakdefter",
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                  ],
                ),
              ),
              // Action buttons
              Row(
                children: [
                  _buildIconBtn(
                    context,
                    Icons.schedule_outlined,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SchedulerControlScreen()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildIconBtn(
                    context,
                    Icons.analytics_outlined,
                    () {
                      try {
                        debugPrint('DEBUG: BI Analytics icon tapped - pushing screen');
                        final route = MaterialPageRoute(builder: (_) => const BIAnalyticsScreen());
                        Navigator.push(context, route);
                        debugPrint('DEBUG: Navigation started');
                      } catch (e, st) {
                        debugPrint('DEBUG: Navigation error: $e\n$st');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('BI Ekranı açılamadı: $e')),
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildPendingBtn(context),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.1, end: 0, duration: 400.ms);
  }

  Widget _buildIconBtn(BuildContext context, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, color: AppColors.charcoal, size: 20),
      ),
    );
  }

  Widget _buildPendingBtn(BuildContext context) {
    final pending = ref.watch(pendingSyncCountProvider);
    if (pending == 0) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PendingOperationsScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warningLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_upload_outlined, color: AppColors.warning, size: 20),
            const SizedBox(width: 4),
            Text(
              pending.toString(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiSection(DashboardMetrics m) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  "TOPLAM DAİRE",
                  "${m.totalUnits}",
                  Icons.home_outlined,
                  AppColors.charcoal,
                  0,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  "AKTİF KİRACİ",
                  "${m.occupiedUnits}",
                  Icons.person_outline,
                  AppColors.slateGray,
                  1,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  "ÇALIŞANLARIM",
                  "${m.staffCount}",
                  Icons.badge_outlined,
                  AppColors.textTertiary,
                  2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Row 2
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  "TAHSİLAT",
                  "%${m.collectionRate.toStringAsFixed(0)}",
                  Icons.check_circle_outline,
                  m.collectionRate >= 80 ? AppColors.success : AppColors.warning,
                  3,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  "BEKLEYEN",
                  "${m.pendingTickets}",
                  Icons.warning_amber_outlined,
                  m.pendingTickets > 0 ? AppColors.error : AppColors.success,
                  4,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  "BOŞ DAİRE",
                  "${m.vacantUnits}",
                  Icons.door_back_door_outlined,
                  AppColors.slateGray,
                  5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Hero Card
          _buildHeroCard(m, 6),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, int index) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textTertiary,
                  letterSpacing: 0.5,
                ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: 50 * index),
          duration: 300.ms,
        )
        .slideY(
          begin: 0.1,
          end: 0,
          delay: Duration(milliseconds: 50 * index),
          duration: 300.ms,
          curve: Curves.easeOut,
        );
  }

  Widget _buildHeroCard(DashboardMetrics m, int index) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.charcoal,
            AppColors.charcoalLight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.charcoal.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "AYLIK TAHSİLAT",
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white70,
                          letterSpacing: 1,
                        ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "${m.monthlyCollected.toStringAsFixed(0)} ₺",
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${m.totalProperties} bina · ${m.occupiedUnits} dolu",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white60,
                      ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: m.collectionRate >= 80
                      ? AppColors.success.withValues(alpha: 0.3)
                      : AppColors.warning.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "%${m.collectionRate.toStringAsFixed(0)}",
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: 50 * index),
          duration: 400.ms,
        )
        .slideY(
          begin: 0.1,
          end: 0,
          delay: Duration(milliseconds: 50 * index),
          duration: 400.ms,
          curve: Curves.easeOut,
        );
  }

  Widget _buildLoadingKpis() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          for (int i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.charcoal,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
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
            const Icon(Icons.inbox_outlined, color: AppColors.textTertiary, size: 40),
            const SizedBox(height: 12),
            Text(
              "Henüz veri yok",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "SON İŞLEMLER",
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ActivityFeedScreen()),
                  );
                },
                child: Text(
                  "Tümünü Gör",
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.charcoal,
                      ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _ActivityFeedList(),
      ],
    );
  }
}

class _ActivityFeedList extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ActivityFeedList> createState() => _ActivityFeedListState();
}

class _ActivityFeedListState extends ConsumerState<_ActivityFeedList> {
  final List<_FeedItem> _items = [];
  bool _loading = false;
  bool _hasMore = true;
  int _offset = 0;
  static const _limit = 10;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final resp = await ApiClient.dio.get(
        '/operations/activity-feed',
        queryParameters: {'limit': _limit, 'offset': _offset},
      );
      if (resp.statusCode == 200 && resp.data != null) {
        final data = resp.data;
        final items = (data['items'] as List).map((e) => _FeedItem.fromJson(e)).toList();
        if (mounted) {
          setState(() {
            _items.addAll(items);
            _hasMore = data['has_more'] ?? false;
            _offset += items.length;
          });
        }
      } else {
        if (mounted) {
          setState(() => _hasMore = false);
        }
      }
    } catch (e) {
      // Network error — stop pagination, show empty list
      if (mounted) {
        setState(() {
          _hasMore = false;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty && _loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.charcoal,
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Center(
            child: Text(
              "Henüz işlem yapılmadı",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        ...List.generate(_items.length, (i) => _buildFeedItem(_items[i], i)),
        if (_hasMore)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.charcoal,
                    ),
                  )
                : GestureDetector(
                    onTap: _loadMore,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Center(
                        child: Text(
                          "Daha Fazla Göster",
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: AppColors.charcoal,
                              ),
                        ),
                      ),
                    ),
                  ),
          ),
      ],
    );
  }

  Widget _buildFeedItem(_FeedItem item, int index) {
    final colors = {
      "success": AppColors.success,
      "error": AppColors.error,
      "warning": AppColors.warning,
      "accent": AppColors.charcoal,
      "textBody": AppColors.textSecondary,
    };
    final color = colors[item.color] ?? AppColors.textSecondary;

    final icons = {
      "payments": Icons.payments_outlined,
      "confirmation_number": Icons.confirmation_number_outlined,
      "engineering": Icons.engineering_outlined,
      "person_add": Icons.person_add_outlined,
    };
    final icon = icons[item.icon] ?? Icons.circle_outlined;

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _formatTime(item.timestamp),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
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

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return "${diff.inMinutes}dk";
      if (diff.inHours < 24) return "${diff.inHours}s";
      if (diff.inDays < 7) return "${diff.inDays}g";
      return "${dt.day}.${dt.month}";
    } catch (_) {
      return "";
    }
  }
}

class _FeedItem {
  final String id;
  final String type;
  final String title;
  final String subtitle;
  final String icon;
  final String color;
  final String timestamp;

  _FeedItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.timestamp,
  });

  factory _FeedItem.fromJson(Map<String, dynamic> json) {
    return _FeedItem(
      id: json['id'] ?? '',
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      icon: json['icon'] ?? 'circle',
      color: json['color'] ?? 'textBody',
      timestamp: json['timestamp'] ?? DateTime.now().toIso8601String(),
    );
  }
}
