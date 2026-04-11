import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/colors.dart';
import '../../../core/network/api_client.dart';

// ──────────────────────────────────────────────
// PROVIDER
// ──────────────────────────────────────────────

class BIAnalyticsData {
  final Map<String, dynamic>? portfolio;
  final Map<String, dynamic>? tenantChurn;
  final Map<String, dynamic>? financial;
  final Map<String, dynamic>? collection;
  final bool isLoading;
  final String? error;

  BIAnalyticsData({
    this.portfolio,
    this.tenantChurn,
    this.financial,
    this.collection,
    this.isLoading = false,
    this.error,
  });

  factory BIAnalyticsData.fromJson(Map<String, dynamic> json) {
    return BIAnalyticsData(
      portfolio: json['portfolio'],
      tenantChurn: json['tenant_churn'],
      financial: json['financial'],
      collection: json['collection'],
    );
  }
}

class BIAnalyticsNotifier extends StateNotifier<AsyncValue<BIAnalyticsData>> {
  BIAnalyticsNotifier() : super(const AsyncValue.loading()) {
    fetch();
  }

  Future<void> fetch() async {
    state = const AsyncValue.loading();
    try {
      final resp = await ApiClient.dio.get('/analytics/bi-dashboard');
      if (resp.statusCode == 200 && resp.data != null) {
        state = AsyncValue.data(BIAnalyticsData.fromJson(resp.data));
      } else {
        state = AsyncValue.data(BIAnalyticsData());
      }
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> refresh() => fetch();
}

final biAnalyticsProvider = StateNotifierProvider<BIAnalyticsNotifier, AsyncValue<BIAnalyticsData>>((ref) {
  return BIAnalyticsNotifier();
});

// ──────────────────────────────────────────────
// SCREEN
// ──────────────────────────────────────────────

class BIAnalyticsScreen extends ConsumerStatefulWidget {
  const BIAnalyticsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<BIAnalyticsScreen> createState() => _BIAnalyticsScreenState();
}

class _BIAnalyticsScreenState extends ConsumerState<BIAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _startAnimation() {
    Future.microtask(() => _fadeController.forward());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(biAnalyticsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text("BI Raporlama", style: TextStyle(color: AppColors.textHeader, fontSize: 20, fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: AppColors.textHeader), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.accent),
            onPressed: () => ref.read(biAnalyticsProvider.notifier).refresh(),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        error: (e, _) => Center(child: Text("Hata: $e", style: const TextStyle(color: AppColors.error))),
        data: (data) {
          if (data.portfolio == null && data.tenantChurn == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.analytics_outlined, size: 80, color: AppColors.textBody.withValues(alpha: 0.2)),
                  const SizedBox(height: 16),
                  Text("Henüz yeterli veri yok", style: TextStyle(color: AppColors.textBody.withValues(alpha: 0.5), fontSize: 16)),
                  const SizedBox(height: 8),
                  Text("Finansal işlem ve kiracı verileri\ngirildikçe burası dolacak.", textAlign: TextAlign.center, style: TextStyle(color: AppColors.textBody.withValues(alpha: 0.3), fontSize: 13)),
                ],
              ),
            );
          }

          WidgetsBinding.instance.addPostFrameCallback((_) => _startAnimation());
          return _buildContent(data);
        },
      ),
    );
  }

  Widget _buildContent(BIAnalyticsData data) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("📊 Portföy Performansı"),
            const SizedBox(height: 12),
            _buildPortfolioSection(data.portfolio),
            const SizedBox(height: 28),
            _buildSectionTitle("👥 Kiracı Sirkülasyonu"),
            const SizedBox(height: 12),
            _buildTenantChurnSection(data.tenantChurn),
            const SizedBox(height: 28),
            _buildSectionTitle("💰 Yıllık Finansal Rapor"),
            const SizedBox(height: 12),
            _buildFinancialSection(data.financial),
            const SizedBox(height: 28),
            _buildSectionTitle("📈 Tahsilat Performansı"),
            const SizedBox(height: 12),
            _buildCollectionSection(data.collection),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(color: AppColors.textHeader, fontSize: 18, fontWeight: FontWeight.bold));
  }

  // ── A. PORTFÖY ──────────────────────────────────

  Widget _buildPortfolioSection(Map<String, dynamic>? p) {
    if (p == null) return _emptyCard("Portföy verisi yok");

    final rate = (p['overall_occupancy_rate'] ?? 0).toDouble();
    final byProp = (p['by_property'] as List<dynamic>? ?? []);

    return Column(
      children: [
        // Donut chart
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 0,
                        centerSpaceRadius: 50,
                        sections: [
                          PieChartSectionData(value: rate, color: AppColors.accent, radius: 18, showTitle: false),
                          PieChartSectionData(value: 100.0 - rate, color: AppColors.surface, radius: 18, showTitle: false),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("${rate.toStringAsFixed(1)}%", style: const TextStyle(color: AppColors.textHeader, fontSize: 22, fontWeight: FontWeight.bold)),
                        const Text("Dolu", style: TextStyle(color: AppColors.textBody, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _kpiRow("Toplam Mülk", "${p['total_properties'] ?? 0}", Icons.home),
                    _kpiRow("Toplam Daire", "${p['total_units'] ?? 0}", Icons.door_front_door_outlined),
                    _kpiRow("Doluluk", "${p['occupied_units'] ?? 0}", Icons.check_circle_outline),
                    _kpiRow("Boş", "${p['vacant_units'] ?? 0}", Icons.cancel_outlined),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Mülk bazlı doluluk listesi
        ...byProp.take(5).map((item) => _buildPropertyOccupancyRow(item)),
        // Boş daire yaşlandırma
        _buildVacantAgingList(p['vacant_aging']),
      ],
    );
  }

  Widget _kpiRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accent, size: 16),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: AppColors.textBody.withValues(alpha: 0.7), fontSize: 13)),
          const Spacer(),
          Text(value, style: const TextStyle(color: AppColors.textHeader, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPropertyOccupancyRow(Map<String, dynamic> item) {
    final rate = (item['occupancy_rate'] ?? 0).toDouble();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['property_name'] ?? '', style: const TextStyle(color: AppColors.textHeader, fontSize: 14, fontWeight: FontWeight.w500)),
                Text("${item['occupied_units']}/${item['total_units']} dolu", style: TextStyle(color: AppColors.textBody.withValues(alpha: 0.5), fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: rate >= 80 ? AppColors.success.withValues(alpha: 0.1) : AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text("${rate.toStringAsFixed(0)}%", style: TextStyle(color: rate >= 80 ? AppColors.success : AppColors.error, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildVacantAgingList(List<dynamic>? vacantList) {
    if (vacantList == null || vacantList.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("⚠️ Boş Daire Yaşlandırma", style: TextStyle(color: AppColors.textHeader, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...vacantList.take(5).map((v) {
          final days = v['vacant_since_days'] ?? 0;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: days > 60 ? AppColors.error.withValues(alpha: 0.08) : AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Text("${v['property_name']} - ${v['door_number']}", style: const TextStyle(color: AppColors.textHeader, fontSize: 12)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: days > 60 ? AppColors.error.withValues(alpha: 0.2) : AppColors.warning.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text("$days gündür boş", style: TextStyle(color: days > 60 ? AppColors.error : AppColors.warning, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ── B. KİRACI SİRKÜLASYONU ─────────────────────

  Widget _buildTenantChurnSection(Map<String, dynamic>? t) {
    if (t == null) return _emptyCard("Kiracı verisi yok");

    final monthlyFlow = (t['monthly_flow'] as List<dynamic>? ?? []);
    if (monthlyFlow.isEmpty) return _emptyCard("Kiracı akış verisi yok");

    final maxVal = monthlyFlow.fold<double>(1, (max, m) {
      final v = ((m['new_tenants'] ?? 0) + (m['departed_tenants'] ?? 0)).toDouble();
      return v > max ? v : max;
    });

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _statChip("Aktif Kiracı", "${t['total_active_tenants'] ?? 0}", Icons.person),
              const SizedBox(width: 12),
              _statChip("Ortalama Kalış", "${t['avg_tenancy_months'] ?? 0} ay", Icons.calendar_today),
              const SizedBox(width: 12),
              _statChip("Churn Rate", "${t['churn_rate_percent'] ?? 0}%", Icons.trending_down),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal * 1.2,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, _) {
                        if (val.toInt() >= monthlyFlow.length) return const Text('', style: TextStyle(fontSize: 9));
                        return Text(
                          monthlyFlow[val.toInt()]['month'].toString().substring(5),
                          style: TextStyle(color: AppColors.textBody.withValues(alpha: 0.5), fontSize: 9),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: false),
                barGroups: List.generate(monthlyFlow.length, (i) {
                  final m = monthlyFlow[i];
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: (m['new_tenants'] ?? 0).toDouble(),
                        color: AppColors.success,
                        width: 8,
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                      ),
                      BarChartRodData(
                        toY: (m['departed_tenants'] ?? 0).toDouble(),
                        color: AppColors.error,
                        width: 8,
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot("Yeni Kiracı", AppColors.success),
              const SizedBox(width: 20),
              _legendDot("Ayrılan", AppColors.error),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.accent, size: 20),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: AppColors.textHeader, fontSize: 16, fontWeight: FontWeight.bold)),
            Text(label, style: TextStyle(color: AppColors.textBody.withValues(alpha: 0.5), fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(String label, Color color) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: AppColors.textBody.withValues(alpha: 0.6), fontSize: 12)),
      ],
    );
  }

  // ── C. FİNANSAL YILLIK ──────────────────────────

  Widget _buildFinancialSection(Map<String, dynamic>? f) {
    if (f == null) return _emptyCard("Finansal veri yok");

    final monthly = (f['monthly_breakdown'] as List<dynamic>? ?? []);

    // Son 6 ay
    final last6 = monthly.length > 6 ? monthly.sublist(monthly.length - 6) : monthly;

    final maxVal = last6.fold<double>(1, (max, m) {
      final v = ((m['total_income'] ?? 0) + (m['total_expense'] ?? 0)).toDouble();
      return v > max ? v : max;
    });

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          // Yıl karşılaştırma özet kartları
          Row(
            children: [
              Expanded(
                child: _finCard("Cari Yıl Gelir", "₺${_fmt(f['current_year_income'] ?? 0)}", AppColors.success),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _finCard("Cari Yıl Gider", "₺${_fmt(f['current_year_expense'] ?? 0)}", AppColors.error),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _finCard("Net Bakiye", "₺${_fmt(f['current_year_net'] ?? 0)}", AppColors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _finCard("Gelir Büyüme", "${f['income_growth_percent'] ?? 0}%", AppColors.success),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Aylık bar chart
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal * 1.2,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, _) {
                        if (val.toInt() >= last6.length) return const Text('', style: TextStyle(fontSize: 9));
                        return Text(
                          last6[val.toInt()]['month'].toString().substring(5),
                          style: TextStyle(color: AppColors.textBody.withValues(alpha: 0.5), fontSize: 9),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: false),
                barGroups: List.generate(last6.length, (i) {
                  final m = last6[i];
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: (m['total_income'] ?? 0).toDouble(),
                        color: AppColors.success,
                        width: 10,
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                      ),
                      BarChartRodData(
                        toY: (m['total_expense'] ?? 0).toDouble(),
                        color: AppColors.error,
                        width: 10,
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot("Gelir", AppColors.success),
              const SizedBox(width: 20),
              _legendDot("Gider", AppColors.error),
            ],
          ),
        ],
      ),
    );
  }

  Widget _finCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: AppColors.textBody.withValues(alpha: 0.6), fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ── D. TAHSİLAT PERFORMANSI ────────────────────

  Widget _buildCollectionSection(Map<String, dynamic>? c) {
    if (c == null) return _emptyCard("Tahsilat verisi yok");

    final monthly = (c['monthly_rates'] as List<dynamic>? ?? []);
    final last6 = monthly.length > 6 ? monthly.sublist(monthly.length - 6) : monthly;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _statChip("Tahsilat Oranı", "${c['overall_collection_rate'] ?? 0}%", Icons.percent)),
              const SizedBox(width: 12),
              Expanded(child: _statChip("Ortalama Gecikme", "${c['avg_delay_days'] ?? 0} gün", Icons.schedule)),
              const SizedBox(width: 12),
              Expanded(child: _statChip("Bekleyen", "₺${_fmt(c['total_outstanding'] ?? 0)}", Icons.pending_actions)),
            ],
          ),
          const SizedBox(height: 20),
          if (last6.isNotEmpty) ...[
            SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, _) {
                          if (val.toInt() >= last6.length) return const Text('', style: TextStyle(fontSize: 9));
                          return Text(
                            last6[val.toInt()]['month'].toString().substring(5),
                            style: TextStyle(color: AppColors.textBody.withValues(alpha: 0.5), fontSize: 9),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(last6.length, (i) {
                        return FlSpot(i.toDouble(), (last6[i]['collection_rate_percent'] ?? 0).toDouble());
                      }),
                      isCurved: true,
                      color: AppColors.accent,
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.accent.withValues(alpha: 0.15),
                      ),
                    ),
                  ],
                  minY: 0,
                  maxY: 100,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: _legendDot("Tahsilat Oranı %", AppColors.accent),
            ),
          ],
        ],
      ),
    );
  }

  // ── HELPERS ────────────────────────────────────

  Widget _emptyCard(String msg) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Center(
        child: Text(msg, style: TextStyle(color: AppColors.textBody.withValues(alpha: 0.4), fontSize: 14)),
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return "${(n / 1000000).toStringAsFixed(1)}M";
    if (n >= 1000) return "${(n / 1000).toStringAsFixed(0)}K";
    return n.toString();
  }
}