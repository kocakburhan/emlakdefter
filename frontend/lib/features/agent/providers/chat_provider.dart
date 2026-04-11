import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../core/network/api_client.dart';

/// ──────────────────────────────────────────────
/// MODELS
/// ──────────────────────────────────────────────

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderUserId;
  final String? senderName;
  final String? message;
  final String? mediaUrl;
  final DateTime createdAt;
  final bool isDeleted;
  final bool isEdited;
  final String? editedAt;
  final bool isMine;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderUserId,
    this.senderName,
    this.message,
    this.mediaUrl,
    required this.createdAt,
    this.isDeleted = false,
    this.isEdited = false,
    this.editedAt,
    this.isMine = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json, String myUserId) {
    return ChatMessage(
      id: json['id'] ?? '',
      conversationId: json['conversation_id'] ?? '',
      senderUserId: json['sender_user_id'] ?? '',
      senderName: json['sender_name'],
      message: json['message'],
      mediaUrl: json['media_url'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
      isDeleted: json['is_deleted'] ?? false,
      isEdited: json['is_edited'] ?? false,
      editedAt: json['edited_at'],
      isMine: json['sender_user_id'] == myUserId,
    );
  }
}

class ChatConversation {
  final String id;
  final String agencyId;
  final String agentUserId;
  final String clientUserId;
  final String? clientName;
  final String? clientRole;
  final String? propertyName;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool isArchived;

  ChatConversation({
    required this.id,
    required this.agencyId,
    required this.agentUserId,
    required this.clientUserId,
    this.clientName,
    this.clientRole,
    this.propertyName,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.isArchived = false,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: json['id'] ?? '',
      agencyId: json['agency_id'] ?? '',
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
    );
  }
}

/// ──────────────────────────────────────────────
/// UNDO STACK
/// ──────────────────────────────────────────────

enum UndoType { messageDelete, conversationArchive }

class UndoItem {
  final UndoType type;
  final String id;
  final String conversationId;
  final DateTime timestamp;
  final dynamic originalData;

  UndoItem({
    required this.type,
    required this.id,
    required this.conversationId,
    required this.timestamp,
    this.originalData,
  });

  bool get isExpired => DateTime.now().difference(timestamp).inSeconds > 5;
}

class UndoState {
  final List<UndoItem> items;
  final String? lastUndoLabel;

  UndoState({this.items = const [], this.lastUndoLabel});
}

/// ──────────────────────────────────────────────
/// CHAT STATE
/// ──────────────────────────────────────────────

class ChatState {
  final List<ChatConversation> conversations;
  final ChatConversation? activeConversation;
  final List<ChatMessage> messages;
  final bool isLoadingConversations;
  final bool isLoadingMessages;
  final String? error;
  final bool showArchived;
  final String? typingUserId;

  ChatState({
    this.conversations = const [],
    this.activeConversation,
    this.messages = const [],
    this.isLoadingConversations = false,
    this.isLoadingMessages = false,
    this.error,
    this.showArchived = false,
    this.typingUserId,
  });

  ChatState copyWith({
    List<ChatConversation>? conversations,
    ChatConversation? activeConversation,
    bool clearActiveConversation = false,
    List<ChatMessage>? messages,
    bool? isLoadingConversations,
    bool? isLoadingMessages,
    String? error,
    bool clearError = false,
    bool? showArchived,
    String? typingUserId,
    bool clearTypingUserId = false,
  }) {
    return ChatState(
      conversations: conversations ?? this.conversations,
      activeConversation: clearActiveConversation ? null : (activeConversation ?? this.activeConversation),
      messages: messages ?? this.messages,
      isLoadingConversations: isLoadingConversations ?? this.isLoadingConversations,
      isLoadingMessages: isLoadingMessages ?? this.isLoadingMessages,
      error: clearError ? null : (error ?? this.error),
      showArchived: showArchived ?? this.showArchived,
      typingUserId: clearTypingUserId ? null : (typingUserId ?? this.typingUserId),
    );
  }
}

/// ──────────────────────────────────────────────
/// CHAT NOTIFIER
/// ──────────────────────────────────────────────

class ChatNotifier extends StateNotifier<ChatState> {
  Timer? _undoTimer;
  Timer? _wsPingTimer;
  final List<UndoItem> _undoStack = [];
  String? _myUserId;

  ChatNotifier() : super(ChatState());

  // ── Conversations ──

  Future<void> fetchConversations({bool includeArchived = false}) async {
    state = state.copyWith(isLoadingConversations: true, clearError: true);
    try {
      final uri = includeArchived
          ? '/chat/conversations?include_archived=true'
          : '/chat/conversations';
      final response = await ApiClient.dio.get(uri);
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data ?? [];
        final conversations = data.map((j) => ChatConversation.fromJson(j)).toList();
        state = state.copyWith(
          conversations: conversations,
          isLoadingConversations: false,
          showArchived: includeArchived,
        );
      }
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoadingConversations: false);
    }
  }

  Future<void> selectConversation(ChatConversation conv) async {
    state = state.copyWith(activeConversation: conv, messages: []);
    await fetchMessages(conv.id);
  }

  void clearActiveConversation() {
    state = state.copyWith(clearActiveConversation: true, messages: []);
  }

  // ── Messages ──

  Future<void> fetchMessages(String conversationId) async {
    state = state.copyWith(isLoadingMessages: true);
    try {
      final response = await ApiClient.dio.get('/chat/history/$conversationId');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data ?? [];
        final messages = data.map((j) => ChatMessage.fromJson(j, _myUserId ?? '')).toList();
        state = state.copyWith(messages: messages, isLoadingMessages: false);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoadingMessages: false);
    }
  }

  void addLocalMessage(ChatMessage msg) {
    state = state.copyWith(messages: [...state.messages, msg]);
  }

  void updateMessage(ChatMessage updated) {
    final msgs = state.messages.map((m) => m.id == updated.id ? updated : m).toList();
    state = state.copyWith(messages: msgs);
  }

  // ── Send Message ──

  Future<bool> sendMessage(String text) async {
    final conv = state.activeConversation;
    if (conv == null || text.trim().isEmpty) return false;
    try {
      final response = await ApiClient.dio.post('/chat/messages', data: {
        'type': 'message',
        'conversation_id': conv.id,
        'message': text.trim(),
      });
      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }
    } catch (e) {
      debugPrint('Send message error: $e');
    }
    return false;
  }

  // ── Edit Message (15 dk içinde) ──

  Future<bool> editMessage(String messageId, String newText) async {
    if (newText.trim().isEmpty) return false;
    try {
      final response = await ApiClient.dio.patch('/chat/messages/$messageId', data: {
        'message': newText.trim(),
      });
      if (response.statusCode == 200) {
        final updated = ChatMessage.fromJson(response.data, _myUserId ?? '');
        updateMessage(updated);
        return true;
      }
    } catch (e) {
      debugPrint('Edit message error: $e');
    }
    return false;
  }

  // ── Delete Message (30 sn geri alınabilir) ──

  Future<bool> deleteMessage(String messageId) async {
    try {
      final response = await ApiClient.dio.delete('/chat/messages/$messageId');
      if (response.statusCode == 200) {
        // Mesajı listeden kaldır (geri alma değil, gerçek silme)
        final msgs = state.messages.where((m) => m.id != messageId).toList();
        state = state.copyWith(messages: msgs);
        return true;
      }
    } catch (e) {
      debugPrint('Delete message error: $e');
    }
    return false;
  }

  // ── Archive / Unarchive Conversation ──

  Future<bool> archiveConversation(String conversationId) async {
    try {
      final response = await ApiClient.dio.patch('/chat/conversations/$conversationId/archive');
      if (response.statusCode == 200) {
        // Listeden kaldır
        final convs = state.conversations.where((c) => c.id != conversationId).toList();
        state = state.copyWith(conversations: convs);
        if (state.activeConversation?.id == conversationId) {
          state = state.copyWith(clearActiveConversation: true, messages: []);
        }
        return true;
      }
    } catch (e) {
      debugPrint('Archive error: $e');
    }
    return false;
  }

  // ── Undo Stack ──

  void _startUndoTimer() {
    _undoTimer?.cancel();
    _undoTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _purgeExpiredUndo();
    });
  }

  void _purgeExpiredUndo() {
    final before = _undoStack.length;
    _undoStack.removeWhere((item) => item.isExpired);
    if (_undoStack.length != before) {
      // Force UI refresh if needed
    }
  }

  void addUndo(UndoItem item) {
    _undoStack.add(item);
    _startUndoTimer();
  }

  List<UndoItem> get undoItems => List.unmodifiable(_undoStack);

  void clearUndo(String id) {
    _undoStack.removeWhere((item) => item.id == id);
  }

  // ── WebSocket (stub — can be wired later) ──

  void setMyUserId(String id) {
    _myUserId = id;
  }

  @override
  void dispose() {
    _undoTimer?.cancel();
    _wsPingTimer?.cancel();
    super.dispose();
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier();
});
