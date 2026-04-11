import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../providers/landlord_provider.dart';
import 'landlord_properties_screen.dart';
import 'landlord_tenant_performance_screen.dart';
import 'landlord_operations_screen.dart';
import 'landlord_investment_screen.dart';

/// Ev Sahibi Ana Dashboard — 5 sekmeli tab yapısı
class LandlordDashboardScreen extends ConsumerStatefulWidget {
  const LandlordDashboardScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<LandlordDashboardScreen> createState() => _LandlordDashboardScreenState();
}

class _LandlordDashboardScreenState extends ConsumerState<LandlordDashboardScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _currentIndex = _tabController.index);
      }
    });
    // Load data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(landlordProvider.notifier).fetchAll();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landlordProvider);
    final kpis = state.kpis;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Fixed Header
            _buildHeader(kpis),
            // Tab Bar
            _buildTabBar(),
            // Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const BouncingScrollPhysics(),
                children: [
                  _OverviewTab(kpis: kpis, state: state),
                  const LandlordPropertiesScreen(),
                  const LandlordTenantPerformanceScreen(),
                  const LandlordOperationsScreen(),
                  const LandlordInvestmentScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader(LandlordKPIs? kpis) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mülklerim',
                      style: TextStyle(
                        color: AppColors.textBody.withOpacity(0.6),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ev Sahibi Paneli',
                      style: TextStyle(
                        color: AppColors.textHeader,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFD4A574).withOpacity(0.8),
                      const Color(0xFFB8956A).withOpacity(0.9),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD4A574).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('E', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // KPI Summary Row
          if (kpis != null)
            Row(
              children: [
                _buildMiniKPIChip('${kpis.totalProperties}', 'Mülk', const Color(0xFF8B7355)),
                const SizedBox(width: 8),
                _buildMiniKPIChip('${kpis.totalUnits}', 'Birim', const Color(0xFF6B8E6B)),
                const SizedBox(width: 8),
                _buildMiniKPIChip('${kpis.occupancyRate.toStringAsFixed(0)}%', 'Doluluk', const Color(0xFF7A9E7A)),
                const SizedBox(width: 8),
                _buildMiniKPIChip('₺${_fmt(kpis.totalMonthlyIncome)}', 'Gelir', const Color(0xFFD4A574)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMiniKPIChip(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color.withOpacity(0.7),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    final tabs = ['Özet', 'Mülkler', 'Kiracılar', 'Operasyon', 'Yatırım'];
    final icons = [Icons.dashboard_outlined, Icons.home_work_outlined, Icons.people_outline, Icons.engineering_outlined, Icons.real_estate_agent_outlined];

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFFD4A574).withOpacity(0.3), const Color(0xFF8B7355).withOpacity(0.2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(4),
        dividerColor: Colors.transparent,
        labelColor: const Color(0xFFD4A574),
        unselectedLabelColor: AppColors.textBody.withOpacity(0.5),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
        tabs: List.generate(5, (i) => Tab(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icons[i], size: 16),
              const SizedBox(width: 5),
              Text(tabs[i]),
            ],
          ),
        )),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (idx) {
            setState(() => _currentIndex = idx);
            _tabController.animateTo(idx);
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: const Color(0xFFD4A574),
          unselectedItemColor: AppColors.textBody.withOpacity(0.4),
          showUnselectedLabels: false,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: "Özet"),
            BottomNavigationBarItem(icon: Icon(Icons.home_work_outlined), label: "Mülkler"),
            BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: "Kiracılar"),
            BottomNavigationBarItem(icon: Icon(Icons.engineering_outlined), label: "Operasyon"),
            BottomNavigationBarItem(icon: Icon(Icons.real_estate_agent_outlined), label: "Yatırım"),
          ],
        ),
      ),
    );
  }

  String _fmt(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }
}

/// ──────────────────────────────────────────────
/// OVERVIEW TAB — KPI Cards + Activity
/// ──────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final LandlordKPIs? kpis;
  final LandlordState state;

  const _OverviewTab({required this.kpis, required this.state});

  @override
  Widget build(BuildContext context) {
    if (kpis == null) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFD4A574)));
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI Cards
          _buildKPIGrid(kpis!),
          const SizedBox(height: 24),

          // Properties Preview
          if (state.properties.isNotEmpty) ...[
            _buildSectionTitle('Mülklerim'),
            const SizedBox(height: 12),
            ...state.properties.take(3).map((p) => _buildPropertyCard(p)),
            const SizedBox(height: 24),
          ],

          // Recent Tenants
          if (state.tenants.isNotEmpty) ...[
            _buildSectionTitle('Kiracılarım'),
            const SizedBox(height: 12),
            ...state.tenants.take(3).map((t) => _buildTenantRow(t)),
          ],

          if (state.properties.isEmpty && state.tenants.isEmpty && !state.isLoading)
            _buildEmptyState(),
        ],
      ),
    );
  }

  Widget _buildKPIGrid(LandlordKPIs kpis) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildKPICard('Toplam Mülk', '${kpis.totalProperties}', Icons.home_work, const Color(0xFF8B7355))),
            const SizedBox(width: 12),
            Expanded(child: _buildKPICard('Toplam Birim', '${kpis.totalUnits}', Icons.door_front_door, const Color(0xFF6B8E6B))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildKPICard('Aylık Gelir', '₺${_fmt(kpis.totalMonthlyIncome)}', Icons.trending_up, const Color(0xFFD4A574))),
            const SizedBox(width: 12),
            Expanded(child: _buildKPICard('Doluluk', '%${kpis.occupancyRate.toStringAsFixed(0)}', Icons.pie_chart, const Color(0xFF7A9E7A))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildKPICard('Aktif Kiracı', '${kpis.activeTenants}', Icons.people, const Color(0xFF7B8EAD))),
            const SizedBox(width: 12),
            Expanded(child: _buildKPICard('Bekleyen Aidat', '₺${_fmt(kpis.totalPendingDues)}', Icons.pending_actions, const Color(0xFFAD7B7B))),
          ],
        ),
      ],
    );
  }

  Widget _buildKPICard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: AppColors.textBody.withOpacity(0.6), fontSize: 11)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: AppColors.textHeader,
        fontSize: 17,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildPropertyCard(LandlordProperty prop) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF8B7355).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.home_work_outlined, color: Color(0xFF8B7355), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(prop.propertyName, style: const TextStyle(color: AppColors.textHeader, fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  '${prop.ownedUnits} birim • ${prop.occupancyRate.toStringAsFixed(0)}% dolu',
                  style: TextStyle(color: AppColors.textBody.withOpacity(0.6), fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '₺${_fmt(prop.monthlyIncome)}',
            style: const TextStyle(color: Color(0xFF6B8E6B), fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildTenantRow(TenantPerformance tenant) {
    final score = tenant.paymentScore;
    final scoreColor = score >= 80 ? const Color(0xFF6B8E6B) : (score >= 50 ? const Color(0xFFD4A574) : const Color(0xFFAD7B7B));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: scoreColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${score.toStringAsFixed(0)}',
                style: TextStyle(
                  color: scoreColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tenant.tenantName ?? 'Kiracı', style: const TextStyle(color: AppColors.textHeader, fontSize: 14, fontWeight: FontWeight.w600)),
                Text('${tenant.propertyName} • ${tenant.doorNumber}', style: TextStyle(color: AppColors.textBody.withOpacity(0.6), fontSize: 12)),
              ],
            ),
          ),
          Text('₺${_fmt(tenant.rentAmount)}', style: const TextStyle(color: AppColors.textHeader, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Icon(Icons.home_work_outlined, size: 56, color: AppColors.textBody.withOpacity(0.2)),
          const SizedBox(height: 16),
          const Text('Henüz mülk bağlantısı yok', style: TextStyle(color: AppColors.textBody, fontSize: 15)),
          const SizedBox(height: 8),
          Text('Emlakçınız sizi mülkünüze davet ettiğinde burada görünür', style: TextStyle(color: AppColors.textBody.withOpacity(0.5), fontSize: 12), textAlign: TextAlign.center),
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
