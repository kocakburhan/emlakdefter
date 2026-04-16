import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../core/network/api_client.dart';

enum TicketStatus { open, inProgress, resolved, closed }

class ChatMessage {
  final String id;
  final String text;
  final bool isMe;
  final DateTime time;

  ChatMessage({required this.id, required this.text, required this.isMe, required this.time});

  factory ChatMessage.fromJson(Map<String, dynamic> json, String? currentUserId) {
    return ChatMessage(
      id: json['id'] ?? '',
      text: json['message'] ?? '',
      isMe: false,
      time: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class TicketModel {
  final String id;
  final String title;
  final String? description;
  final String? tenantName;
  final String? location;
  final String? propertyId;
  final String priority;
  final TicketStatus status;
  final DateTime createdAt;
  final List<ChatMessage> messages;

  TicketModel({
    required this.id,
    required this.title,
    this.description,
    this.tenantName,
    this.location,
    this.propertyId,
    required this.priority,
    required this.status,
    required this.createdAt,
    this.messages = const [],
  });

  factory TicketModel.fromJson(Map<String, dynamic> json) {
    TicketStatus parseStatus(String? s) {
      switch (s) {
        case 'open': return TicketStatus.open;
        case 'in_progress': return TicketStatus.inProgress;
        case 'resolved': return TicketStatus.resolved;
        case 'closed': return TicketStatus.closed;
        default: return TicketStatus.open;
      }
    }

    List<ChatMessage> parseMessages(List<dynamic>? msgs) {
      if (msgs == null) return [];
      return msgs.map((m) => ChatMessage.fromJson(m, null)).toList();
    }

    return TicketModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      tenantName: json['reporter_name'],
      location: json['unit_door'] != null ? '${json['unit_property'] ?? ''} ${json['unit_door']}' : null,
      propertyId: json['property_id']?.toString(),
      priority: json['priority'] ?? 'medium',
      status: parseStatus(json['status']),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
      messages: parseMessages(json['messages']),
    );
  }

  TicketStatus get displayStatus {
    if (messages.isNotEmpty && status == TicketStatus.open) {
      return TicketStatus.inProgress;
    }
    return status;
  }
}

class SupportNotifier extends StateNotifier<AsyncValue<List<TicketModel>>> {
  SupportNotifier() : super(const AsyncValue.loading()) {
    _fetchTickets();
  }

  Future<void> _fetchTickets() async {
    state = const AsyncValue.loading();
    try {
      final resp = await ApiClient.dio.get('/operations/tickets');
      if (resp.statusCode == 200) {
        final data = resp.data as List<dynamic>;
        final tickets = data.map((j) => TicketModel.fromJson(j)).toList();
        state = AsyncValue.data(tickets);
      } else {
        state = const AsyncValue.data([]);
      }
    } catch (e) {
      state = const AsyncValue.data([]);
    }
  }

  Future<void> fetchTicketDetail(String ticketId) async {
    try {
      final resp = await ApiClient.dio.get('/operations/tickets/$ticketId');
      if (resp.statusCode == 200 && resp.data != null) {
        final detail = TicketModel.fromJson(resp.data);
        if (state.value != null) {
          final updated = state.value!.map((t) => t.id == ticketId ? detail : t).toList();
          state = AsyncValue.data(updated);
        }
      }
    } catch (e) {
      // ignore error
    }
  }

  Future<void> replyToTicket(String ticketId, String messageText) async {
    try {
      await ApiClient.dio.post(
        '/operations/tickets/$ticketId/reply',
        data: {'message': messageText},
      );
      await fetchTicketDetail(ticketId);
    } catch (e) {
      // ignore error
    }
  }

  Future<void> closeTicket(String ticketId) async {
    try {
      await ApiClient.dio.patch(
        '/operations/tickets/$ticketId',
        data: {'status': 'resolved'},
      );
      await fetchTicketDetail(ticketId);
    } catch (e) {
      // ignore error
    }
  }

  Future<void> refresh() async {
    await _fetchTickets();
  }
}

final supportProvider = StateNotifierProvider<SupportNotifier, AsyncValue<List<TicketModel>>>((ref) {
  return SupportNotifier();
});
