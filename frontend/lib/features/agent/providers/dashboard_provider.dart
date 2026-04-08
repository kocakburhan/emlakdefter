import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardMetrics {
  final double totalRevenue;
  final int activeProperties;
  final int emptyUnits;
  final int pendingTickets;
  final double collectionRate; // Yüzde (%)

  DashboardMetrics({
    this.totalRevenue = 0,
    this.activeProperties = 0,
    this.emptyUnits = 0,
    this.pendingTickets = 0,
    this.collectionRate = 100,
  });
}

// Şimdilik Backend'den geliyormuş gibi 3 saniye gecikmeyle Sahte Data fırlatır!
class DashboardNotifier extends StateNotifier<AsyncValue<DashboardMetrics>> {
  DashboardNotifier() : super(const AsyncValue.loading()) {
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    state = const AsyncValue.loading();
    try {
      // Mock API (FastAPI) Yanıt süresi simülasyonu
      await Future.delayed(const Duration(seconds: 2));
      
      final data = DashboardMetrics(
        totalRevenue: 245000.50, // 245 Bin TL Tahsilat (Bu ay)
        activeProperties: 12,    // 12 Bina (Site) yönetiliyor
        emptyUnits: 5,           // Kiracısız (Boş) Daire Sayısı
        pendingTickets: 3,       // Asansör/Boru arızası vs bekleyen bilet 
        collectionRate: 85.4,    // Aylık tahsilat performansı
      );

      state = AsyncValue.data(data);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

// UI tarafından izlenecek (watch) olan Riverpod Asistanımız
final dashboardProvider = StateNotifierProvider<DashboardNotifier, AsyncValue<DashboardMetrics>>((ref) {
  return DashboardNotifier();
});
