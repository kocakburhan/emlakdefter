import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';
import 'connectivity_service.dart';
import 'offline_storage.dart';

// ─── Connection Status ─────────────────────────────────────────

final connectionStatusProvider = StreamProvider<ConnectionStatus>((ref) {
  return ConnectivityService().stream;
});

final isOnlineProvider = Provider<bool>((ref) {
  return ConnectivityService().isOnline;
});

final pendingSyncCountProvider = Provider<int>((ref) {
  return OfflineStorage().totalPendingCount;
});

// ─── Portfolio Cache  (§5.1) ─────────────────────────────────

class PortfolioCacheItem {
  final String id;
  final String name;
  final String? address;
  final int totalUnits;
  final int occupiedUnits;
  final int vacantUnits;
  final int monthlyIncome;
  final double occupancyRate;

  PortfolioCacheItem({
    required this.id,
    required this.name,
    this.address,
    required this.totalUnits,
    required this.occupiedUnits,
    required this.vacantUnits,
    required this.monthlyIncome,
    required this.occupancyRate,
  });

  factory PortfolioCacheItem.fromJson(Map<String, dynamic> json) {
    return PortfolioCacheItem(
      id: json['id'] ?? json['property_id'] ?? '',
      name: json['name'] ?? json['property_name'] ?? '',
      address: json['address'],
      totalUnits: json['total_units'] ?? 0,
      occupiedUnits: json['occupied_units'] ?? 0,
      vacantUnits: json['vacant_units'] ?? 0,
      monthlyIncome: json['monthly_income'] ?? 0,
      occupancyRate: (json['occupancy_rate'] ?? 0).toDouble(),
    );
  }
}

class PortfolioCacheNotifier extends Notifier<List<PortfolioCacheItem>> {
  @override
  List<PortfolioCacheItem> build() {
    _loadFromCache();
    return [];
  }

  OfflineStorage get _storage => OfflineStorage();
  ConnectivityService get _conn => ConnectivityService();

  void _loadFromCache() {
    final cached = _storage.getAllPortfolio();
    if (cached.isNotEmpty) {
      state = cached.map((e) => PortfolioCacheItem.fromJson(e)).toList();
    }
  }

  Future<void> refresh() async {
    if (!_conn.isOnline) return;
    try {
      final resp = await ApiClient.dio.get('/properties');
      if (resp.statusCode == 200 && resp.data != null) {
        final data = resp.data as List<dynamic>;
        final items = data.map((j) => PortfolioCacheItem.fromJson(j)).toList();
        for (final item in items) {
          await _storage.cachePortfolio(item.id, {
            'id': item.id,
            'name': item.name,
            'address': item.address,
            'total_units': item.totalUnits,
            'occupied_units': item.occupiedUnits,
            'vacant_units': item.vacantUnits,
            'monthly_income': item.monthlyIncome,
            'occupancy_rate': item.occupancyRate,
          });
        }
        state = items;
      }
    } catch (e) {
      debugPrint('[PortfolioCache] refresh failed: $e');
    }
  }

  DateTime? get cacheTime => _storage.getPortfolioCacheTime();
  bool get hasCache => state.isNotEmpty;
}

final portfolioCacheProvider =
    NotifierProvider<PortfolioCacheNotifier, List<PortfolioCacheItem>>(
        PortfolioCacheNotifier.new);

// ─── Contacts Cache  (§5.1) ─────────────────────────────────

class ContactCacheItem {
  final String id;
  final String name;
  final String role; // "tenant" | "landlord"
  final String? phone;
  final String? doorNumber;
  final String? propertyName;
  final bool isActive;

  ContactCacheItem({
    required this.id,
    required this.name,
    required this.role,
    this.phone,
    this.doorNumber,
    this.propertyName,
    required this.isActive,
  });

  factory ContactCacheItem.fromTenantJson(Map<String, dynamic> json) {
    return ContactCacheItem(
      id: json['id'] ?? '',
      name: json['tenant_name'] ?? '',
      role: 'tenant',
      phone: json['tenant_phone'],
      doorNumber: json['door_number'],
      propertyName: json['property_name'],
      isActive: json['is_active'] ?? false,
    );
  }

  factory ContactCacheItem.fromLandlordJson(Map<String, dynamic> json) {
    return ContactCacheItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      role: 'landlord',
      phone: json['phone'],
      doorNumber: null,
      propertyName: json['property_name'],
      isActive: json['is_active'] ?? false,
    );
  }
}

class ContactsCacheNotifier extends Notifier<List<ContactCacheItem>> {
  @override
  List<ContactCacheItem> build() {
    _loadFromCache();
    return [];
  }

  OfflineStorage get _storage => OfflineStorage();
  ConnectivityService get _conn => ConnectivityService();

  void _loadFromCache() {
    final cached = _storage.getAllContacts();
    if (cached.isNotEmpty) {
      state = cached.map((e) {
        if (e['role'] == 'tenant') {
          return ContactCacheItem.fromTenantJson(e);
        }
        return ContactCacheItem.fromLandlordJson(e);
      }).toList();
    }
  }

  Future<void> refresh() async {
    if (!_conn.isOnline) return;
    try {
      final results = <ContactCacheItem>[];

      final tResp = await ApiClient.dio.get('/tenants');
      if (tResp.statusCode == 200 && tResp.data != null) {
        final tData = tResp.data as List<dynamic>;
        for (final j in tData) {
          final item = ContactCacheItem.fromTenantJson(j);
          results.add(item);
          await _storage.cacheContact('tenant_${item.id}', {...j, 'role': 'tenant'});
        }
      }

      final lResp = await ApiClient.dio.get('/landlords');
      if (lResp.statusCode == 200 && lResp.data != null) {
        final lData = lResp.data as List<dynamic>;
        for (final j in lData) {
          final item = ContactCacheItem.fromLandlordJson(j);
          results.add(item);
          await _storage.cacheContact('landlord_${item.id}', {...j, 'role': 'landlord'});
        }
      }

      state = results;
    } catch (e) {
      debugPrint('[ContactsCache] refresh failed: $e');
    }
  }

  DateTime? get cacheTime => _storage.getContactsCacheTime();
  bool get hasCache => state.isNotEmpty;
}

final contactsCacheProvider =
    NotifierProvider<ContactsCacheNotifier, List<ContactCacheItem>>(
        ContactsCacheNotifier.new);

// ─── Reports Cache  (§5.1) ─────────────────────────────────

class ReportCacheItem {
  final String id;
  final String title;
  final String period;
  final double totalIncome;
  final double totalExpense;
  final double netBalance;
  final DateTime cachedAt;

  ReportCacheItem({
    required this.id,
    required this.title,
    required this.period,
    required this.totalIncome,
    required this.totalExpense,
    required this.netBalance,
    required this.cachedAt,
  });

  factory ReportCacheItem.fromJson(Map<String, dynamic> json) {
    return ReportCacheItem(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] ?? 'Rapor',
      period: json['period'] ?? '',
      totalIncome: (json['total_income'] ?? 0).toDouble(),
      totalExpense: (json['total_expense'] ?? 0).toDouble(),
      netBalance: (json['net_balance'] ?? 0).toDouble(),
      cachedAt: json['cached_at'] != null
          ? DateTime.tryParse(json['cached_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class ReportsCacheNotifier extends Notifier<List<ReportCacheItem>> {
  @override
  List<ReportCacheItem> build() {
    _loadFromCache();
    return [];
  }

  OfflineStorage get _storage => OfflineStorage();
  ConnectivityService get _conn => ConnectivityService();

  void _loadFromCache() {
    final cached = _storage.getAllReports();
    if (cached.isNotEmpty) {
      state = cached.map((e) => ReportCacheItem.fromJson(e)).toList();
    }
  }

  Future<void> refresh() async {
    if (!_conn.isOnline) return;
    try {
      final resp = await ApiClient.dio.get('/finance/summary');
      if (resp.statusCode == 200 && resp.data != null) {
        final data = resp.data as Map<String, dynamic>;
        final item = ReportCacheItem.fromJson({
          ...data,
          'cached_at': DateTime.now().toIso8601String(),
        });
        await _storage.cacheReport(item.id, {
          ...data,
          'id': item.id,
          'cached_at': item.cachedAt.toIso8601String(),
        });
        final updated = [item, ...state].take(12).toList();
        state = updated;
      }
    } catch (e) {
      debugPrint('[ReportsCache] refresh failed: $e');
    }
  }

  DateTime? get cacheTime => _storage.getReportsCacheTime();
  bool get hasCache => state.isNotEmpty;
}

final reportsCacheProvider =
    NotifierProvider<ReportsCacheNotifier, List<ReportCacheItem>>(
        ReportsCacheNotifier.new);
