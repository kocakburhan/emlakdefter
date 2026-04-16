import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';
import '../../../core/network/api_client.dart';
import '../../../core/offline/connectivity_service.dart';
import '../../../core/offline/offline_storage.dart';

/// Bina Operasyon Log — Backend BuildingOperationLog karşılığı
class BuildingOperationModel {
  final String id;
  final String agencyId;
  final String propertyId;
  final String? propertyName;
  final String? createdByUserId;
  final String title;
  final String? description;
  final int cost;
  final String? invoiceUrl;
  final bool isReflectedToFinance;
  final DateTime createdAt;
  final String? category;
  final bool isPendingSync; // §5.3 — cloud upload bekleyen

  BuildingOperationModel({
    required this.id,
    required this.agencyId,
    required this.propertyId,
    this.propertyName,
    this.createdByUserId,
    required this.title,
    this.description,
    this.cost = 0,
    this.invoiceUrl,
    this.isReflectedToFinance = false,
    required this.createdAt,
    this.category,
    this.isPendingSync = false,
  });

  factory BuildingOperationModel.fromJson(Map<String, dynamic> json) {
    return BuildingOperationModel(
      id: json['id'] ?? '',
      agencyId: json['agency_id'] ?? '',
      propertyId: json['property_id'] ?? '',
      propertyName: json['property_name'],
      createdByUserId: json['created_by_user_id'],
      title: json['title'] ?? '',
      description: json['description'],
      cost: json['cost'] ?? 0,
      invoiceUrl: json['invoice_url'],
      isReflectedToFinance: json['is_reflected_to_finance'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      category: json['category'],
    );
  }

  /// Local pending operation (queued for sync).
  factory BuildingOperationModel.pending({
    required String propertyId,
    required String title,
    String? description,
    int cost = 0,
    String? invoiceUrl,
    bool isReflectedToFinance = false,
    String? category,
  }) {
    return BuildingOperationModel(
      id: const Uuid().v4(),
      agencyId: '',
      propertyId: propertyId,
      title: title,
      description: description,
      cost: cost,
      invoiceUrl: invoiceUrl,
      isReflectedToFinance: isReflectedToFinance,
      createdAt: DateTime.now(),
      category: category,
      isPendingSync: true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'agency_id': agencyId,
    'property_id': propertyId,
    'title': title,
    'description': description,
    'cost': cost,
    'invoice_url': invoiceUrl,
    'is_reflected_to_finance': isReflectedToFinance,
  };
}

/// Bina operasyon durumu (Filtreleme + Liste)
class BuildingOperationsState {
  final List<BuildingOperationModel> operations;
  final bool isLoading;
  final String? error;
  final String? propertyFilter; // null = hepsi
  final bool? financeFilter; // null = hepsi, true = yansıtılan, false = yansıtılmayan

  BuildingOperationsState({
    this.operations = const [],
    this.isLoading = false,
    this.error,
    this.propertyFilter,
    this.financeFilter,
  });

  BuildingOperationsState copyWith({
    List<BuildingOperationModel>? operations,
    bool? isLoading,
    String? error,
    String? propertyFilter,
    bool? financeFilter,
    bool clearError = false,
    bool clearPropertyFilter = false,
    bool clearFinanceFilter = false,
  }) {
    return BuildingOperationsState(
      operations: operations ?? this.operations,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      propertyFilter: clearPropertyFilter ? null : (propertyFilter ?? this.propertyFilter),
      financeFilter: clearFinanceFilter ? null : (financeFilter ?? this.financeFilter),
    );
  }

  List<BuildingOperationModel> get filtered {
    return operations;
  }

  int get totalCost => operations.fold(0, (sum, op) => sum + op.cost);
  int get reflectedCost => operations.where((op) => op.isReflectedToFinance).fold(0, (sum, op) => sum + op.cost);
}

class BuildingOperationsNotifier extends StateNotifier<BuildingOperationsState> {
  final _offlineStorage = OfflineStorage();
  final _connService = ConnectivityService();

  BuildingOperationsNotifier() : super(BuildingOperationsState()) {
    fetchOperations();
  }

  Future<void> fetchOperations() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await ApiClient.dio.get('/operations/building-logs');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data ?? [];
        final operations = data.map((json) => BuildingOperationModel.fromJson(json)).toList();
        state = state.copyWith(operations: operations, isLoading: false);
        debugPrint('🏗️ ${operations.length} bina operasyonu yüklendi.');
      }
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      debugPrint('⚠️ Bina operasyonları yüklenemedi: $e');
    }
  }

  Future<bool> createOperation({
    required String propertyId,
    required String title,
    String? description,
    int cost = 0,
    String? invoiceUrl,
    bool isReflectedToFinance = false,
    String? category,
  }) async {
    // §5.3 — offline: queue locally with cloud-upload icon
    if (!_connService.isOnline) {
      final pending = BuildingOperationModel.pending(
        propertyId: propertyId,
        title: title,
        description: description,
        cost: cost,
        invoiceUrl: invoiceUrl,
        isReflectedToFinance: isReflectedToFinance,
        category: category,
      );
      state = state.copyWith(operations: [pending, ...state.operations]);
      await _offlineStorage.addToOpQueue(pending.id, {
        'local_id': pending.id,
        'property_id': propertyId,
        'title': title,
        'description': description,
        'cost': cost,
        'invoice_url': invoiceUrl,
        'is_reflected_to_finance': isReflectedToFinance,
        'category': category,
      });
      return true;
    }

    try {
      final response = await ApiClient.dio.post('/operations/building-logs', data: {
        'property_id': propertyId,
        'title': title,
        'description': description,
        'cost': cost,
        'invoice_url': invoiceUrl,
        'is_reflected_to_finance': isReflectedToFinance,
        if (category != null) 'category': category,
      });
      if (response.statusCode == 201) {
        final newOp = BuildingOperationModel.fromJson(response.data);
        state = state.copyWith(operations: [newOp, ...state.operations]);
        return true;
      }
    } catch (e) {
      // §5.3 fallback — network error, queue locally
      final pending = BuildingOperationModel.pending(
        propertyId: propertyId,
        title: title,
        description: description,
        cost: cost,
        invoiceUrl: invoiceUrl,
        isReflectedToFinance: isReflectedToFinance,
        category: category,
      );
      state = state.copyWith(operations: [pending, ...state.operations]);
      await _offlineStorage.addToOpQueue(pending.id, {
        'local_id': pending.id,
        'property_id': propertyId,
        'title': title,
        'description': description,
        'cost': cost,
        'invoice_url': invoiceUrl,
        'is_reflected_to_finance': isReflectedToFinance,
        'category': category,
      });
      debugPrint('⚠️ Bina operasyonu offline kuyruğa eklendi: $e');
      return true;
    }
    return false;
  }

  Future<bool> updateOperation({
    required String id,
    String? title,
    String? description,
    int? cost,
    String? invoiceUrl,
    bool? isReflectedToFinance,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (title != null) data['title'] = title;
      if (description != null) data['description'] = description;
      if (cost != null) data['cost'] = cost;
      if (invoiceUrl != null) data['invoice_url'] = invoiceUrl;
      if (isReflectedToFinance != null) data['is_reflected_to_finance'] = isReflectedToFinance;

      final response = await ApiClient.dio.patch('/operations/building-logs/$id', data: data);
      if (response.statusCode == 200) {
        final updated = BuildingOperationModel.fromJson(response.data);
        final updatedList = state.operations.map((op) => op.id == id ? updated : op).toList();
        state = state.copyWith(operations: updatedList);
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ Bina operasyonu güncelleme hatası: $e');
    }
    return false;
  }

  Future<bool> deleteOperation(String id) async {
    try {
      final response = await ApiClient.dio.delete('/operations/building-logs/$id');
      if (response.statusCode == 204) {
        final updatedList = state.operations.where((op) => op.id != id).toList();
        state = state.copyWith(operations: updatedList);
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ Bina operasyonu silme hatası: $e');
    }
    return false;
  }

  void setPropertyFilter(String? propertyId) {
    if (propertyId == null) {
      state = state.copyWith(clearPropertyFilter: true);
    } else {
      state = state.copyWith(propertyFilter: propertyId);
    }
  }

  void setFinanceFilter(bool? value) {
    if (value == null) {
      state = state.copyWith(clearFinanceFilter: true);
    } else {
      state = state.copyWith(financeFilter: value);
    }
  }

  List<BuildingOperationModel> get filteredOps {
    var ops = state.operations;
    if (state.propertyFilter != null) {
      ops = ops.where((op) => op.propertyId == state.propertyFilter).toList();
    }
    if (state.financeFilter != null) {
      ops = ops.where((op) => op.isReflectedToFinance == state.financeFilter).toList();
    }
    return ops;
  }
}

final buildingOperationsProvider =
    StateNotifierProvider<BuildingOperationsNotifier, BuildingOperationsState>((ref) {
  return BuildingOperationsNotifier();
});