import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../core/network/api_client.dart';

// Kiracının Ana Bilgileri
class TenantInfo {
  final String id;
  final String name;
  final String propertyName;
  final String unitNumber;
  final String? unitFloor;
  final double currentDebt;
  final String? nextDueDate;
  final double? nextDueAmount;
  final DateTime? startDate;
  final String? endDate;
  final String status;

  TenantInfo({
    required this.id,
    required this.name,
    required this.propertyName,
    required this.unitNumber,
    this.unitFloor,
    required this.currentDebt,
    this.nextDueDate,
    this.nextDueAmount,
    this.startDate,
    this.endDate,
    required this.status,
  });

  factory TenantInfo.fromJson(Map<String, dynamic> json) {
    return TenantInfo(
      id: json['id'] ?? '',
      name: json['user_full_name'] ?? json['temp_name'] ?? 'Kiracı',
      propertyName: json['property_name'] ?? '',
      unitNumber: json['unit_door_number'] ?? '',
      unitFloor: json['unit_floor'],
      currentDebt: 0.0,
      nextDueDate: json['next_due_date'],
      nextDueAmount: json['next_due_amount']?.toDouble(),
      startDate: json['start_date'] != null ? DateTime.tryParse(json['start_date']) : null,
      endDate: json['end_date'],
      status: json['status'] ?? 'active',
    );
  }
}

// Kiracı Finans Özeti
class TenantFinanceSummary {
  final String tenantId;
  final double currentDebt;
  final String? nextDueDate;
  final double? nextDueAmount;
  final List<PaymentScheduleItem> upcomingSchedules;

  TenantFinanceSummary({
    required this.tenantId,
    required this.currentDebt,
    this.nextDueDate,
    this.nextDueAmount,
    this.upcomingSchedules = const [],
  });

  factory TenantFinanceSummary.fromJson(Map<String, dynamic> json) {
    return TenantFinanceSummary(
      tenantId: json['tenant_id'] ?? '',
      currentDebt: (json['current_debt'] ?? 0).toDouble(),
      nextDueDate: json['next_due_date'],
      nextDueAmount: json['next_due_amount']?.toDouble(),
      upcomingSchedules: (json['upcoming_schedules'] as List<dynamic>?)
              ?.map((s) => PaymentScheduleItem.fromJson(s))
              .toList() ?? [],
    );
  }
}

class PaymentScheduleItem {
  final String id;
  final String tenantId;
  final double amount;
  final double paidAmount;
  final DateTime dueDate;
  final String category;
  final String status;

  PaymentScheduleItem({
    required this.id,
    required this.tenantId,
    required this.amount,
    required this.paidAmount,
    required this.dueDate,
    required this.category,
    required this.status,
  });

  factory PaymentScheduleItem.fromJson(Map<String, dynamic> json) {
    return PaymentScheduleItem(
      id: json['id'] ?? '',
      tenantId: json['tenant_id'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      paidAmount: (json['paid_amount'] ?? 0).toDouble(),
      dueDate: DateTime.tryParse(json['due_date'] ?? '') ?? DateTime.now(),
      category: json['category'] ?? 'rent',
      status: json['status'] ?? 'pending',
    );
  }
}

// Bina Operasyon Kaydı
class BuildingLogItem {
  final String id;
  final String title;
  final String? description;
  final int cost;
  final DateTime createdAt;

  BuildingLogItem({
    required this.id,
    required this.title,
    this.description,
    required this.cost,
    required this.createdAt,
  });

  factory BuildingLogItem.fromJson(Map<String, dynamic> json) {
    return BuildingLogItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      cost: json['cost'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

// Kiracı (B2C) — kendi verilerini API'den çeken Riverpod StateNotifier
class TenantNotifier extends StateNotifier<AsyncValue<TenantInfo?>> {
  TenantNotifier() : super(const AsyncValue.loading()) {
    _fetchTenantData();
  }

  Future<void> _fetchTenantData() async {
    state = const AsyncValue.loading();
    try {
      final resp = await ApiClient.dio.get('/tenants/me');
      if (resp.statusCode == 200 && resp.data != null) {
        state = AsyncValue.data(TenantInfo.fromJson(resp.data));
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e) {
      state = const AsyncValue.data(null);
    }
  }

  Future<void> refresh() async {
    await _fetchTenantData();
  }
}

final tenantProvider = StateNotifierProvider<TenantNotifier, AsyncValue<TenantInfo?>>((ref) {
  return TenantNotifier();
});

// Finans özeti provider'ı
final tenantFinanceProvider = FutureProvider<TenantFinanceSummary?>((ref) async {
  try {
    final resp = await ApiClient.dio.get('/tenants/me/finance');
    if (resp.statusCode == 200 && resp.data != null) {
      return TenantFinanceSummary.fromJson(resp.data);
    }
    return null;
  } catch (e) {
    return null;
  }
});

// Bina operasyon logları provider'ı
final tenantBuildingLogsProvider = FutureProvider<List<BuildingLogItem>>((ref) async {
  try {
    final resp = await ApiClient.dio.get('/tenants/me/building-logs', queryParameters: {'limit': 20});
    if (resp.statusCode == 200 && resp.data != null) {
      return (resp.data as List<dynamic>)
          .map((j) => BuildingLogItem.fromJson(j))
          .toList();
    }
    return [];
  } catch (e) {
    return [];
  }
});

// İşlem geçmişi provider'ı
class TransactionItem {
  final String id;
  final String type;
  final String category;
  final double amount;
  final DateTime transactionDate;
  final String? description;

  TransactionItem({
    required this.id,
    required this.type,
    required this.category,
    required this.amount,
    required this.transactionDate,
    this.description,
  });

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    return TransactionItem(
      id: json['id'] ?? '',
      type: json['type'] ?? 'income',
      category: json['category'] ?? 'rent',
      amount: (json['amount'] ?? 0).toDouble(),
      transactionDate: json['transaction_date'] != null
          ? DateTime.tryParse(json['transaction_date']) ?? DateTime.now()
          : DateTime.now(),
      description: json['description'],
    );
  }
}

final tenantTransactionsProvider = FutureProvider<List<TransactionItem>>((ref) async {
  try {
    final resp = await ApiClient.dio.get('/tenants/me/transactions');
    if (resp.statusCode == 200 && resp.data != null) {
      return (resp.data as List<dynamic>)
          .map((j) => TransactionItem.fromJson(j))
          .toList();
    }
    return [];
  } catch (e) {
    return [];
  }
});

// Müsait daireler (portföy vitrini) — API'den gelen boş birimler
class VacantUnitItem {
  final String unitId;
  final String propertyId;
  final String propertyName;
  final String address;
  final String doorNumber;
  final String? floor;
  final int rentPrice;
  final int duesAmount;
  final List<String> features;

  VacantUnitItem({
    required this.unitId,
    required this.propertyId,
    required this.propertyName,
    required this.address,
    required this.doorNumber,
    this.floor,
    required this.rentPrice,
    required this.duesAmount,
    this.features = const [],
  });

  factory VacantUnitItem.fromJson(Map<String, dynamic> json) {
    return VacantUnitItem(
      unitId: json['unit_id'] ?? '',
      propertyId: json['property_id'] ?? '',
      propertyName: json['property_name'] ?? '',
      address: json['address'] ?? '',
      doorNumber: json['door_number'] ?? '',
      floor: json['floor'],
      rentPrice: json['rent_price'] ?? 0,
      duesAmount: json['dues_amount'] ?? 0,
      features: (json['features'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

final tenantVacantUnitsProvider = FutureProvider.family<List<VacantUnitItem>, String?>((ref, propertyName) async {
  try {
    final params = <String, dynamic>{};
    if (propertyName != null && propertyName.isNotEmpty) {
      params['property_name'] = propertyName;
    }
    final resp = await ApiClient.dio.get('/landlord/vacant-units', queryParameters: params);
    if (resp.statusCode == 200 && resp.data != null) {
      return (resp.data as List<dynamic>)
          .map((j) => VacantUnitItem.fromJson(j))
          .toList();
    }
    return [];
  } catch (e) {
    return [];
  }
});

// Tenant sohbet — API'den gelen konuşmalar
class ConversationItem {
  final String id;
  final String agentUserId;
  final String clientUserId;
  final String? clientName;
  final String? clientRole;
  final String? propertyName;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool isArchived;
  final DateTime createdAt;

  ConversationItem({
    required this.id,
    required this.agentUserId,
    required this.clientUserId,
    this.clientName,
    this.clientRole,
    this.propertyName,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.isArchived = false,
    required this.createdAt,
  });

  factory ConversationItem.fromJson(Map<String, dynamic> json) {
    return ConversationItem(
      id: json['id'] ?? '',
      agentUserId: json['agent_user_id'] ?? '',
      clientUserId: json['client_user_id'] ?? '',
      clientName: json['client_name'],
      clientRole: json['client_role'],
      propertyName: json['property_name'],
      lastMessage: json['last_message'],
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.tryParse(json['last_message_at'])
          : null,
      unreadCount: json['unread_count'] ?? 0,
      isArchived: json['is_archived'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

final tenantConversationsProvider = FutureProvider<List<ConversationItem>>((ref) async {
  try {
    final resp = await ApiClient.dio.get('/chat/conversations');
    if (resp.statusCode == 200 && resp.data != null) {
      return (resp.data as List<dynamic>)
          .map((j) => ConversationItem.fromJson(j))
          .toList();
    }
    return [];
  } catch (e) {
    return [];
  }
});

// Mesaj öğesi
class ChatMessageItem {
  final String id;
  final String conversationId;
  final String senderUserId;
  final String? message;
  final String? mediaUrl;
  final DateTime createdAt;
  final bool isDeleted;
  final bool isEdited;

  ChatMessageItem({
    required this.id,
    required this.conversationId,
    required this.senderUserId,
    this.message,
    this.mediaUrl,
    required this.createdAt,
    this.isDeleted = false,
    this.isEdited = false,
  });

  factory ChatMessageItem.fromJson(Map<String, dynamic> json) {
    return ChatMessageItem(
      id: json['id'] ?? '',
      conversationId: json['conversation_id'] ?? '',
      senderUserId: json['sender_user_id'] ?? '',
      message: json['message'],
      mediaUrl: json['media_url'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
      isDeleted: json['is_deleted'] ?? false,
      isEdited: json['is_edited'] ?? false,
    );
  }
}

final tenantChatHistoryProvider = FutureProvider.family<List<ChatMessageItem>, String>((ref, conversationId) async {
  try {
    final resp = await ApiClient.dio.get('/chat/history/$conversationId');
    if (resp.statusCode == 200 && resp.data != null) {
      return (resp.data as List<dynamic>)
          .map((j) => ChatMessageItem.fromJson(j))
          .toList();
    }
    return [];
  } catch (e) {
    return [];
  }
});

// Mesaj gönder — REST API üzerinden
final tenantSendMessageProvider = FutureProvider.family<ChatMessageItem?, SendMessageParams>((ref, params) async {
  try {
    final resp = await ApiClient.dio.post('/chat/messages', data: {
      'type': 'message',
      'conversation_id': params.conversationId,
      'message': params.message,
      'media_url': params.mediaUrl,
    });
    if (resp.statusCode == 201 && resp.data != null) {
      return ChatMessageItem.fromJson(resp.data);
    }
    return null;
  } catch (e) {
    return null;
  }
});

class SendMessageParams {
  final String conversationId;
  final String? message;
  final String? mediaUrl;

  SendMessageParams({required this.conversationId, this.message, this.mediaUrl});
}
