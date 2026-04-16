import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../core/network/api_client.dart';

/// ──────────────────────────────────────────────
/// MODELS
/// ──────────────────────────────────────────────

class LandlordKPIs {
  final int totalProperties;
  final int totalUnits;
  final int occupiedUnits;
  final int vacantUnits;
  final int totalMonthlyIncome;
  final int totalPendingDues;
  final int activeTenants;
  final double occupancyRate;

  LandlordKPIs({
    required this.totalProperties,
    required this.totalUnits,
    required this.occupiedUnits,
    required this.vacantUnits,
    required this.totalMonthlyIncome,
    required this.totalPendingDues,
    required this.activeTenants,
    required this.occupancyRate,
  });

  factory LandlordKPIs.fromJson(Map<String, dynamic> json) {
    return LandlordKPIs(
      totalProperties: json['total_properties'] ?? 0,
      totalUnits: json['total_units'] ?? 0,
      occupiedUnits: json['occupied_units'] ?? 0,
      vacantUnits: json['vacant_units'] ?? 0,
      totalMonthlyIncome: json['total_monthly_income'] ?? 0,
      totalPendingDues: json['total_pending_dues'] ?? 0,
      activeTenants: json['active_tenants'] ?? 0,
      occupancyRate: (json['occupancy_rate'] ?? 0).toDouble(),
    );
  }
}

class LandlordProperty {
  final String propertyId;
  final String propertyName;
  final String? address;
  final int totalUnits;
  final int ownedUnits;
  final int occupiedUnits;
  final int vacantUnits;
  final int monthlyIncome;
  final double occupancyRate;

  LandlordProperty({
    required this.propertyId,
    required this.propertyName,
    this.address,
    required this.totalUnits,
    required this.ownedUnits,
    required this.occupiedUnits,
    required this.vacantUnits,
    required this.monthlyIncome,
    required this.occupancyRate,
  });

  factory LandlordProperty.fromJson(Map<String, dynamic> json) {
    return LandlordProperty(
      propertyId: json['property_id'] ?? '',
      propertyName: json['property_name'] ?? '',
      address: json['address'],
      totalUnits: json['total_units'] ?? 0,
      ownedUnits: json['owned_units'] ?? 0,
      occupiedUnits: json['occupied_units'] ?? 0,
      vacantUnits: json['vacant_units'] ?? 0,
      monthlyIncome: json['monthly_income'] ?? 0,
      occupancyRate: (json['occupancy_rate'] ?? 0).toDouble(),
    );
  }
}

class LandlordUnit {
  final String id;
  final String unitId;
  final String propertyName;
  final String doorNumber;
  final String? floor;
  final int ownershipShare;
  final int? rentAmount;
  final String? tenantName;
  final String? tenantPhone;
  final String contractStatus;
  final bool isActive;

  LandlordUnit({
    required this.id,
    required this.unitId,
    required this.propertyName,
    required this.doorNumber,
    this.floor,
    required this.ownershipShare,
    this.rentAmount,
    this.tenantName,
    this.tenantPhone,
    required this.contractStatus,
    required this.isActive,
  });

  factory LandlordUnit.fromJson(Map<String, dynamic> json) {
    return LandlordUnit(
      id: json['id'] ?? '',
      unitId: json['unit_id'] ?? '',
      propertyName: json['property_name'] ?? '',
      doorNumber: json['door_number'] ?? '',
      floor: json['floor'],
      ownershipShare: json['ownership_share'] ?? 100,
      rentAmount: json['rent_amount'],
      tenantName: json['tenant_name'],
      tenantPhone: json['tenant_phone'],
      contractStatus: json['contract_status'] ?? 'boş',
      isActive: json['is_active'] ?? false,
    );
  }
}

class PaymentMonthItem {
  final String monthLabel;
  final int year;
  final int month;
  final double amount;
  final double paidAmount;
  final String status; // "paid_on_time" | "paid_late" | "partial" | "pending"
  final int daysLate;
  final DateTime? paidAt;

  PaymentMonthItem({
    required this.monthLabel,
    required this.year,
    required this.month,
    required this.amount,
    required this.paidAmount,
    required this.status,
    this.daysLate = 0,
    this.paidAt,
  });

  factory PaymentMonthItem.fromJson(Map<String, dynamic> json) {
    return PaymentMonthItem(
      monthLabel: json['month_label'] ?? '',
      year: json['year'] ?? 0,
      month: json['month'] ?? 0,
      amount: (json['amount'] ?? 0).toDouble(),
      paidAmount: (json['paid_amount'] ?? 0).toDouble(),
      status: json['status'] ?? 'pending',
      daysLate: json['days_late'] ?? 0,
      paidAt: json['paid_at'] != null ? DateTime.tryParse(json['paid_at']) : null,
    );
  }
}

class TenantPerformance {
  final String tenantId;
  final String unitId;
  final String propertyName;
  final String doorNumber;
  final String? tenantName;
  final String? tenantPhone;
  final int rentAmount;
  final int paymentDay;
  final DateTime contractStart;
  final DateTime contractEnd;
  final String status;
  final bool isActive;
  final int monthsRented;
  final int onTimePayments;
  final int latePayments;
  final int missedPayments;
  final double paymentScore;
  final List<PaymentMonthItem> paymentHistory;

  TenantPerformance({
    required this.tenantId,
    required this.unitId,
    required this.propertyName,
    required this.doorNumber,
    this.tenantName,
    this.tenantPhone,
    required this.rentAmount,
    required this.paymentDay,
    required this.contractStart,
    required this.contractEnd,
    required this.status,
    required this.isActive,
    required this.monthsRented,
    required this.onTimePayments,
    this.latePayments = 0,
    this.missedPayments = 0,
    this.paymentScore = 100.0,
    this.paymentHistory = const [],
  });

  factory TenantPerformance.fromJson(Map<String, dynamic> json) {
    return TenantPerformance(
      tenantId: json['tenant_id'] ?? '',
      unitId: json['unit_id'] ?? '',
      propertyName: json['property_name'] ?? '',
      doorNumber: json['door_number'] ?? '',
      tenantName: json['tenant_name'],
      tenantPhone: json['tenant_phone'],
      rentAmount: json['rent_amount'] ?? 0,
      paymentDay: json['payment_day'] ?? 1,
      contractStart: json['contract_start'] != null
          ? DateTime.tryParse(json['contract_start']) ?? DateTime.now()
          : DateTime.now(),
      contractEnd: json['contract_end'] != null
          ? DateTime.tryParse(json['contract_end']) ?? DateTime.now()
          : DateTime.now(),
      status: json['status'] ?? '',
      isActive: json['is_active'] ?? false,
      monthsRented: json['months_rented'] ?? 0,
      onTimePayments: json['on_time_payments'] ?? 0,
      latePayments: json['late_payments'] ?? 0,
      missedPayments: json['missed_payments'] ?? 0,
      paymentScore: (json['payment_score'] ?? 100.0).toDouble(),
      paymentHistory: (json['payment_history'] as List<dynamic>?)
              ?.map((e) => PaymentMonthItem.fromJson(e))
              .toList() ?? [],
    );
  }
}

class LandlordTenantTicket {
  final String id;
  final String title;
  final String? description;
  final String priority;
  final String status; // open, in_progress, resolved, closed
  final DateTime createdAt;
  final DateTime updatedAt;
  final String unitDoor;
  final String propertyName;
  final int messageCount;
  final int agentReplyCount;
  final String? lastMessage;
  final DateTime? lastMessageAt;

  LandlordTenantTicket({
    required this.id,
    required this.title,
    this.description,
    required this.priority,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.unitDoor,
    required this.propertyName,
    required this.messageCount,
    required this.agentReplyCount,
    this.lastMessage,
    this.lastMessageAt,
  });

  factory LandlordTenantTicket.fromJson(Map<String, dynamic> json) {
    return LandlordTenantTicket(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      priority: json['priority'] ?? 'medium',
      status: json['status'] ?? 'open',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at']) ?? DateTime.now()
          : DateTime.now(),
      unitDoor: json['unit_door'] ?? '?',
      propertyName: json['property_name'] ?? '',
      messageCount: json['message_count'] ?? 0,
      agentReplyCount: json['agent_reply_count'] ?? 0,
      lastMessage: json['last_message'],
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.tryParse(json['last_message_at'])
          : null,
    );
  }
}

class LandlordOperation {
  final String id;
  final String propertyId;
  final String propertyName;
  final String title;
  final String? description;
  final int cost;
  final bool isReflectedToFinance;
  final DateTime createdAt;

  LandlordOperation({
    required this.id,
    required this.propertyId,
    required this.propertyName,
    required this.title,
    this.description,
    required this.cost,
    required this.isReflectedToFinance,
    required this.createdAt,
  });

  factory LandlordOperation.fromJson(Map<String, dynamic> json) {
    return LandlordOperation(
      id: json['id'] ?? '',
      propertyId: json['property_id'] ?? '',
      propertyName: json['property_name'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      cost: json['cost'] ?? 0,
      isReflectedToFinance: json['is_reflected_to_finance'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class LandlordVacantUnit {
  final String unitId;
  final String propertyId;
  final String propertyName;
  final String? address;
  final String doorNumber;
  final String? floor;
  final int? rentPrice;
  final int duesAmount;
  final Map<String, dynamic>? features;

  LandlordVacantUnit({
    required this.unitId,
    required this.propertyId,
    required this.propertyName,
    this.address,
    required this.doorNumber,
    this.floor,
    this.rentPrice,
    required this.duesAmount,
    this.features,
  });

  factory LandlordVacantUnit.fromJson(Map<String, dynamic> json) {
    return LandlordVacantUnit(
      unitId: json['unit_id'] ?? '',
      propertyId: json['property_id'] ?? '',
      propertyName: json['property_name'] ?? '',
      address: json['address'],
      doorNumber: json['door_number'] ?? '',
      floor: json['floor'],
      rentPrice: json['rent_price'],
      duesAmount: json['dues_amount'] ?? 0,
      features: json['features'],
    );
  }
}

/// ──────────────────────────────────────────────
/// LANDLORD STATE
/// ──────────────────────────────────────────────

class LandlordState {
  final LandlordKPIs? kpis;
  final List<LandlordProperty> properties;
  final List<LandlordUnit> units;
  final List<TenantPerformance> tenants;
  final List<LandlordOperation> operations;
  final List<LandlordVacantUnit> vacantUnits;
  final List<LandlordTenantTicket> tickets;
  final bool isLoading;
  final String? error;

  LandlordState({
    this.kpis,
    this.properties = const [],
    this.units = const [],
    this.tenants = const [],
    this.operations = const [],
    this.vacantUnits = const [],
    this.tickets = const [],
    this.isLoading = false,
    this.error,
  });

  LandlordState copyWith({
    LandlordKPIs? kpis,
    List<LandlordProperty>? properties,
    List<LandlordUnit>? units,
    List<TenantPerformance>? tenants,
    List<LandlordOperation>? operations,
    List<LandlordVacantUnit>? vacantUnits,
    List<LandlordTenantTicket>? tickets,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return LandlordState(
      kpis: kpis ?? this.kpis,
      properties: properties ?? this.properties,
      units: units ?? this.units,
      tenants: tenants ?? this.tenants,
      operations: operations ?? this.operations,
      vacantUnits: vacantUnits ?? this.vacantUnits,
      tickets: tickets ?? this.tickets,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// ──────────────────────────────────────────────
/// LANDLORD NOTIFIER
/// ──────────────────────────────────────────────

class LandlordNotifier extends StateNotifier<LandlordState> {
  LandlordNotifier() : super(LandlordState());

  Future<void> fetchDashboard() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final resp = await ApiClient.dio.get('/landlord/dashboard');
      if (resp.statusCode == 200 && resp.data != null) {
        final kpis = LandlordKPIs.fromJson(resp.data);
        state = state.copyWith(kpis: kpis, isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> fetchProperties() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final resp = await ApiClient.dio.get('/landlord/properties');
      if (resp.statusCode == 200) {
        final data = resp.data as List<dynamic>;
        final props = data.map((j) => LandlordProperty.fromJson(j)).toList();
        state = state.copyWith(properties: props, isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> fetchUnits() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final resp = await ApiClient.dio.get('/landlord/units');
      if (resp.statusCode == 200) {
        final data = resp.data as List<dynamic>;
        final units = data.map((j) => LandlordUnit.fromJson(j)).toList();
        state = state.copyWith(units: units, isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> fetchTenants() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final resp = await ApiClient.dio.get('/landlord/tenants');
      if (resp.statusCode == 200) {
        final data = resp.data as List<dynamic>;
        final tenants = data.map((j) => TenantPerformance.fromJson(j)).toList();
        state = state.copyWith(tenants: tenants, isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> fetchOperations() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final resp = await ApiClient.dio.get('/landlord/operations');
      if (resp.statusCode == 200) {
        final data = resp.data as List<dynamic>;
        final ops = data.map((j) => LandlordOperation.fromJson(j)).toList();
        state = state.copyWith(operations: ops, isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> fetchTenantTickets() async {
    await _fetchTenantTickets();
  }

  Future<void> fetchVacantUnits({String? propertyName, int? minPrice, int? maxPrice}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final params = <String, dynamic>{};
      if (propertyName != null && propertyName.isNotEmpty) params['property_name'] = propertyName;
      if (minPrice != null) params['min_price'] = minPrice;
      if (maxPrice != null) params['max_price'] = maxPrice;
      final resp = await ApiClient.dio.get('/landlord/vacant-units', queryParameters: params);
      if (resp.statusCode == 200) {
        final data = resp.data as List<dynamic>;
        final units = data.map((j) => LandlordVacantUnit.fromJson(j)).toList();
        state = state.copyWith(vacantUnits: units, isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> fetchAll() async {
    state = state.copyWith(isLoading: true, clearError: true);
    await Future.wait([
      _fetchKPIs(),
      _fetchProperties(),
      _fetchUnits(),
      _fetchTenantTickets(),
    ]);
    state = state.copyWith(isLoading: false);
  }

  Future<void> _fetchTenantTickets() async {
    try {
      final resp = await ApiClient.dio.get('/landlord/tenant-tickets');
      if (resp.statusCode == 200) {
        final data = resp.data as List<dynamic>;
        state = state.copyWith(tickets: data.map((j) => LandlordTenantTicket.fromJson(j)).toList());
      }
    } catch (e) {
      debugPrint('Tenant tickets fetch error: $e');
    }
  }

  Future<void> _fetchKPIs() async {
    try {
      final resp = await ApiClient.dio.get('/landlord/dashboard');
      if (resp.statusCode == 200 && resp.data != null) {
        final kpis = LandlordKPIs.fromJson(resp.data);
        state = state.copyWith(kpis: kpis);
      }
    } catch (e) {
      debugPrint('KPI fetch error: $e');
    }
  }

  Future<void> _fetchProperties() async {
    try {
      final resp = await ApiClient.dio.get('/landlord/properties');
      if (resp.statusCode == 200) {
        final data = resp.data as List<dynamic>;
        state = state.copyWith(properties: data.map((j) => LandlordProperty.fromJson(j)).toList());
      }
    } catch (e) {
      debugPrint('Properties fetch error: $e');
    }
  }

  Future<void> _fetchUnits() async {
    try {
      final resp = await ApiClient.dio.get('/landlord/units');
      if (resp.statusCode == 200) {
        final data = resp.data as List<dynamic>;
        state = state.copyWith(units: data.map((j) => LandlordUnit.fromJson(j)).toList());
      }
    } catch (e) {
      debugPrint('Units fetch error: $e');
    }
  }
}

final landlordProvider = StateNotifierProvider<LandlordNotifier, LandlordState>((ref) {
  return LandlordNotifier();
});
