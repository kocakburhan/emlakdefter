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
    final resp = await ApiClient.dio.get('/tenants/me/vacant-units', queryParameters: params);
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
  final String? propertyId;
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
    this.propertyId,
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
      propertyId: json['property_id'],
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
    final resp = await ApiClient.dio.get('/tenants/me/conversations');
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
    final resp = await ApiClient.dio.get('/tenants/me/conversations/$conversationId/messages');
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
    // First create or get conversation with property context
    if (params.propertyId != null && params.conversationId.isEmpty) {
      // Create new conversation with property context
      final createResp = await ApiClient.dio.post('/tenants/me/conversations', data: {
        'property_id': params.propertyId,
        'initial_message': params.message,
      });
      if (createResp.statusCode == 201 && createResp.data != null) {
        return ChatMessageItem(
          id: '',
          conversationId: createResp.data['id'] ?? '',
          senderUserId: '',
          message: params.message,
          mediaUrl: params.mediaUrl,
          createdAt: DateTime.now(),
        );
      }
    }
    // Send to existing conversation
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
  final String? propertyId;
  final String? message;
  final String? mediaUrl;

  SendMessageParams({required this.conversationId, this.propertyId, this.message, this.mediaUrl});
}


// ──────────────────────────────────────────────
// Tenant Documents — PRD §4.2.3
// ──────────────────────────────────────────────

class TenantDocument {
  final String name;
  final String docType;
  final String url;
  final DateTime? uploadedAt;

  TenantDocument({
    required this.name,
    required this.docType,
    required this.url,
    this.uploadedAt,
  });

  factory TenantDocument.fromJson(Map<String, dynamic> json) {
    return TenantDocument(
      name: json['name'] ?? 'Belge',
      docType: json['doc_type'] ?? 'other',
      url: json['url'] ?? '',
      uploadedAt: json['uploaded_at'] != null
          ? DateTime.tryParse(json['uploaded_at'])
          : null,
    );
  }

  String get iconName {
    switch (docType) {
      case 'contract': return 'Kira Sözleşmesi';
      case 'handover': return 'Demirbaş Teslim Tutanağı';
      case 'aidat_plan': return 'Aidat Ödeme Planı';
      case 'eviction': return 'Tahliye Taahhütnamesi';
      default: return 'Diğer Belge';
    }
  }

  int get colorValue {
    switch (docType) {
      case 'contract': return 0xFF3B82F6;
      case 'handover': return 0xFF10B981;
      case 'aidat_plan': return 0xFFF59E0B;
      case 'eviction': return 0xFF8B5CF6;
      default: return 0xFF6B7280;
    }
  }
}

class TenantDocumentsPayload {
  final String? contractDocumentUrl;
  final List<TenantDocument> documents;

  TenantDocumentsPayload({
    this.contractDocumentUrl,
    this.documents = const [],
  });

  factory TenantDocumentsPayload.fromJson(Map<String, dynamic> json) {
    return TenantDocumentsPayload(
      contractDocumentUrl: json['contract_document_url'],
      documents: (json['documents'] as List<dynamic>?)
              ?.map((d) => TenantDocument.fromJson(d))
              .toList() ?? [],
    );
  }
}

final tenantDocumentsProvider = FutureProvider<TenantDocumentsPayload?>((ref) async {
  try {
    final resp = await ApiClient.dio.get('/tenants/me/documents');
    if (resp.statusCode == 200 && resp.data != null) {
      return TenantDocumentsPayload.fromJson(resp.data);
    }
    return null;
  } catch (e) {
    return null;
  }
});


// ──────────────────────────────────────────────
// Tenant Support Ticket — PRD §4.2.2
// ──────────────────────────────────────────────

enum TenantTicketStatus { open, inProgress, resolved, closed }

class TenantTicketMessage {
  final String id;
  final String? senderUserId;
  final String? senderName;
  final String message;
  final String? attachmentUrl;
  final bool isAgent;
  final DateTime createdAt;

  TenantTicketMessage({
    required this.id,
    this.senderUserId,
    this.senderName,
    required this.message,
    this.attachmentUrl,
    this.isAgent = false,
    required this.createdAt,
  });

  factory TenantTicketMessage.fromJson(Map<String, dynamic> json) {
    return TenantTicketMessage(
      id: json['id'] ?? '',
      senderUserId: json['sender_user_id'],
      senderName: json['sender_name'],
      message: json['message'] ?? '',
      attachmentUrl: json['attachment_url'],
      isAgent: json['is_agent'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class TenantSupportTicket {
  final String id;
  final String title;
  final String? description;
  final String priority;
  final TenantTicketStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? unitDoor;
  final String? propertyName;
  final int messageCount;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final List<TenantTicketMessage> messages;

  TenantSupportTicket({
    required this.id,
    required this.title,
    this.description,
    required this.priority,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.unitDoor,
    this.propertyName,
    this.messageCount = 0,
    this.lastMessage,
    this.lastMessageAt,
    this.messages = const [],
  });

  TenantTicketStatus get displayStatus {
    if (messages.isNotEmpty && status == TenantTicketStatus.open) {
      return TenantTicketStatus.inProgress;
    }
    return status;
  }

  factory TenantSupportTicket.fromJson(Map<String, dynamic> json) {
    TenantTicketStatus parseStatus(String? s) {
      switch (s) {
        case 'open': return TenantTicketStatus.open;
        case 'in_progress': return TenantTicketStatus.inProgress;
        case 'resolved': return TenantTicketStatus.resolved;
        case 'closed': return TenantTicketStatus.closed;
        default: return TenantTicketStatus.open;
      }
    }

    return TenantSupportTicket(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      priority: json['priority'] ?? 'medium',
      status: parseStatus(json['status']),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at']) ?? DateTime.now()
          : DateTime.now(),
      unitDoor: json['unit_door'],
      propertyName: json['property_name'],
      messageCount: json['message_count'] ?? 0,
      lastMessage: json['last_message'],
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.tryParse(json['last_message_at'])
          : null,
      messages: (json['messages'] as List<dynamic>?)
              ?.map((m) => TenantTicketMessage.fromJson(m))
              .toList() ?? [],
    );
  }
}

class TenantSupportNotifier extends StateNotifier<AsyncValue<List<TenantSupportTicket>>> {
  TenantSupportNotifier() : super(const AsyncValue.loading()) {
    fetchTickets();
  }

  Future<void> fetchTickets() async {
    state = const AsyncValue.loading();
    try {
      final resp = await ApiClient.dio.get('/tenants/me/tickets');
      if (resp.statusCode == 200 && resp.data != null) {
        final list = (resp.data as List<dynamic>)
            .map((j) => TenantSupportTicket.fromJson(j))
            .toList();
        state = AsyncValue.data(list);
      } else {
        state = const AsyncValue.data([]);
      }
    } catch (e) {
      state = const AsyncValue.data([]);
    }
  }

  Future<bool> createTicket({
    required String title,
    String? description,
    String? attachmentUrl,
  }) async {
    try {
      await ApiClient.dio.post('/tenants/me/tickets', data: {
        'title': title,
        'description': description,
        'attachment_url': attachmentUrl,
        'priority': 'medium',
      });
      await fetchTickets();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<TenantSupportTicket?> fetchTicketDetail(String ticketId) async {
    try {
      final resp = await ApiClient.dio.get('/tenants/me/tickets/$ticketId');
      if (resp.statusCode == 200 && resp.data != null) {
        return TenantSupportTicket.fromJson(resp.data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> replyToTicket(String ticketId, String message, {String? attachmentUrl}) async {
    try {
      await ApiClient.dio.post(
        '/tenants/me/tickets/$ticketId/reply',
        data: {
          'message': message,
          if (attachmentUrl != null) 'attachment_url': attachmentUrl,
        },
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> refresh() async {
    await fetchTickets();
  }
}

final tenantSupportProvider =
    StateNotifierProvider<TenantSupportNotifier, AsyncValue<List<TenantSupportTicket>>>((ref) {
  return TenantSupportNotifier();
});


// ──────────────────────────────────────────────
// Tenant Chat — pending launch context from Explore (§4.2.6)
// ──────────────────────────────────────────────

class ChatLaunchContext {
  final String propertyId;
  final String propertyName;
  final String initialMessage;

  ChatLaunchContext({
    required this.propertyId,
    required this.propertyName,
    required this.initialMessage,
  });
}

class ChatLaunchNotifier extends StateNotifier<ChatLaunchContext?> {
  ChatLaunchNotifier() : super(null);

  void launchForProperty(String propertyId, String propertyName) {
    state = ChatLaunchContext(
      propertyId: propertyId,
      propertyName: propertyName,
      initialMessage: '$propertyName hakkında bilgi almak istiyorum.',
    );
  }

  void clear() {
    state = null;
  }
}

final chatLaunchProvider =
    StateNotifierProvider<ChatLaunchNotifier, ChatLaunchContext?>((ref) {
  return ChatLaunchNotifier();
});
