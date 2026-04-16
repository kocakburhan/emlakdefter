import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/colors.dart';
import '../providers/dashboard_provider.dart';
import '../screens/bi_analytics_screen.dart';
import '../screens/scheduler_control_screen.dart';

class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> with TickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeSlide;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeSlide = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(dashboardProvider);

    return SafeArea(
      child: AnimatedBuilder(
        animation: _fadeSlide,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeSlide.value,
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - _fadeSlide.value)),
              child: child,
            ),
          );
        },
        child: RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: AppColors.surface,
          onRefresh: () async {
            ref.read(dashboardProvider.notifier).refresh();
          },
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── HEADER ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _buildHeader(context),
              ),

              // ── KPI CARDS ────────────────────────────────────────────
              SliverToBoxAdapter(
                child: dashboardState.when(
                  loading: () => _buildLoadingKpis(),
                  error: (_, __) => _buildEmptyState(),
                  data: (m) => _buildKpiSection(m),
                ),
              ),

              // ── ACTIVITY FEED ─────────────────────────────────────
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
      ),
    );
  }

  // ─── HEADER ────────────────────────────────────────────────────────────────

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
                      "Hoş Geldiniz",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textBody.withValues(alpha: 0.7),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Emlakdefter",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textHeader,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              // Action buttons row
              Row(
                children: [
                  _buildIconBtn(
                    Icons.schedule,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SchedulerControlScreen()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildIconBtn(
                    Icons.analytics_rounded,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BIAnalyticsScreen()),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _buildIconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Icon(icon, color: AppColors.accent, size: 20),
      ),
    );
  }

  // ─── KPI SECTION ────────────────────────────────────────────────────────────

  Widget _buildKpiSection(DashboardMetrics m) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Toplam Daire | Aktif Kiracı | Çalışanlarım
          Row(
            children: [
              Expanded(child: _buildStatCard("TOPLAM DAİRE", "${m.totalUnits}", Icons.home_outlined, AppColors.accent)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard("AKTİF KİRACİ", "${m.occupiedUnits}", Icons.person_outline, Colors.amber)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard("ÇALIŞANLARIM", "${m.staffCount}", Icons.badge_outlined, Colors.teal)),
            ],
          ),
          const SizedBox(height: 12),

          // Row 2: Tahsilat | Bekleyen Bilet | Boş Daire
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  "TAHSİLAT ORANI",
                  "%${m.collectionRate.toStringAsFixed(0)}",
                  Icons.check_circle_outline,
                  m.collectionRate >= 80 ? AppColors.success : AppColors.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  "BEKLEYEN BİLET",
                  "${m.pendingTickets}",
                  Icons.warning_amber_outlined,
                  m.pendingTickets > 0 ? AppColors.error : AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard("BOŞ DAİRE", "${m.vacantUnits}", Icons.door_back_door_outlined, AppColors.textBody)),
            ],
          ),
          const SizedBox(height: 24),

          // Hero: Aylık Toplanan
          _buildHeroCard(m),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: AppColors.textBody.withValues(alpha: 0.6),
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(DashboardMetrics m) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accent.withValues(alpha: 0.9),
            AppColors.accent.withValues(alpha: 0.6),
            const Color(0xFF1a3a6b),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        "AYLIK TAHSİLAT",
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  "${m.monthlyCollected.toStringAsFixed(0)} ₺",
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Tahsilat: ${m.totalProperties} bina · ${m.occupiedUnits} dolu",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.65),
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
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accent,
                    ),
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
          color: AppColors.surface.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Column(
          children: [
            Icon(Icons.inbox_outlined, color: AppColors.textBody, size: 40),
            SizedBox(height: 12),
            Text(
              "Henüz veri yok",
              style: TextStyle(color: AppColors.textBody, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  // ─── ACTIVITY FEED ────────────────────────────────────────────────────────

  Widget _buildActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "SON İŞLEMLER",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textBody,
                  letterSpacing: 1.5,
                ),
              ),
              TextButton(
                onPressed: () {
                  // Navigate to full activity feed
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  "Tümünü Gör",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ActivityFeedList(),
      ],
    );
  }
}

// ─── ACTIVITY FEED LIST (Stateful — own provider) ─────────────────────────

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
        setState(() {
          _items.addAll(items);
          _hasMore = data['has_more'] ?? false;
          _offset += items.length;
        });
      }
    } catch (e) {
      // Silently fail — show empty
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty && _loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
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
            color: AppColors.surface.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(
            child: Text(
              "Henüz işlem yapılmadı",
              style: TextStyle(color: AppColors.textBody, fontSize: 13),
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
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                    ),
                  )
                : GestureDetector(
                    onTap: _loadMore,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          "Daha Fazla Göster",
                          style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
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
      "accent": AppColors.accent,
      "textBody": AppColors.textBody,
    };
    final color = colors[item.color] ?? AppColors.textBody;

    final icons = {
      "payments": Icons.payments_outlined,
      "confirmation_number": Icons.confirmation_number_outlined,
      "engineering": Icons.engineering_outlined,
      "person_add": Icons.person_add_outlined,
    };
    final icon = icons[item.icon] ?? Icons.circle_outlined;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 60).clamp(0, 400)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
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
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textBody.withValues(alpha: 0.6),
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
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return "${diff.inMinutes}d";
      if (diff.inHours < 24) return "${diff.inHours}s";
      if (diff.inDays < 7) return "${diff.inDays}g";
      return "${dt.day}.${dt.month}";
    } catch (_) {
      return "";
    }
  }
}

// ─── MODELS ─────────────────────────────────────────────────────────────────

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

// ─── BACKWARD COMPATIBILITY ─────────────────────────────────────────────────