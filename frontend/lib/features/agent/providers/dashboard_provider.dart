import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../core/network/api_client.dart';

class DashboardMetrics {
  final int totalProperties;
  final int totalUnits;
  final int occupiedUnits;
  final int vacantUnits;
  final int totalMonthlyRent;
  final int totalMonthlyDues;
  final int pendingTickets;
  final int openTickets;
  final int monthlyCollected;
  final int monthlyExpense;
  final double collectionRate;
  final int activeTenants;
  final int staffCount;

  DashboardMetrics({
    this.totalProperties = 0,
    this.totalUnits = 0,
    this.occupiedUnits = 0,
    this.vacantUnits = 0,
    this.totalMonthlyRent = 0,
    this.totalMonthlyDues = 0,
    this.pendingTickets = 0,
    this.openTickets = 0,
    this.monthlyCollected = 0,
    this.monthlyExpense = 0,
    this.collectionRate = 100,
    this.activeTenants = 0,
    this.staffCount = 0,
  });

  factory DashboardMetrics.fromJson(Map<String, dynamic> json) {
    return DashboardMetrics(
      totalProperties: json['total_properties'] ?? 0,
      totalUnits: json['total_units'] ?? 0,
      occupiedUnits: json['occupied_units'] ?? 0,
      vacantUnits: json['vacant_units'] ?? 0,
      totalMonthlyRent: json['total_monthly_rent'] ?? 0,
      totalMonthlyDues: json['total_monthly_dues'] ?? 0,
      pendingTickets: json['pending_tickets'] ?? 0,
      openTickets: json['open_tickets'] ?? 0,
      monthlyCollected: json['monthly_collected'] ?? 0,
      monthlyExpense: json['monthly_expense'] ?? 0,
      collectionRate: (json['collection_rate'] ?? 100).toDouble(),
      activeTenants: json['active_tenants'] ?? 0,
      staffCount: json['staff_count'] ?? 0,
    );
  }
}

class DashboardNotifier extends StateNotifier<AsyncValue<DashboardMetrics>> {
  DashboardNotifier() : super(const AsyncValue.loading()) {
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    state = const AsyncValue.loading();
    try {
      final resp = await ApiClient.dio.get('/operations/dashboard-kpi');
      if (resp.statusCode == 200 && resp.data != null) {
        final metrics = DashboardMetrics.fromJson(resp.data);
        state = AsyncValue.data(metrics);
      } else {
        state = AsyncValue.data(DashboardMetrics());
      }
    } catch (e) {
      // Network/server error — show empty metrics instead of hanging on loading
      state = AsyncValue.data(DashboardMetrics());
    }
  }

  Future<void> refresh() async {
    await _fetchDashboardData();
  }
}

final dashboardProvider = StateNotifierProvider<DashboardNotifier, AsyncValue<DashboardMetrics>>((ref) {
  return DashboardNotifier();
});
