import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/chat_websocket_service.dart';
import '../../../core/offline/connectivity_service.dart';
import '../../../core/offline/offline_storage.dart';

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
  final bool isPending; // §5.2 — clock icon for queued messages
  final bool isRead; // §4.1.8-B

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
    this.isPending = false,
    this.isRead = false,
  });

  /// Create a local pending message (for outbox queue).
  factory ChatMessage.pending({
    required String conversationId,
    String? message,
    required String senderUserId,
    String? senderName,
  }) {
    return ChatMessage(
      id: const Uuid().v4(),
      conversationId: conversationId,
      senderUserId: senderUserId,
      senderName: senderName,
      message: message,
      createdAt: DateTime.now(),
      isMine: true,
      isPending: true,
      isRead: false,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json, String myUserId) {
    return ChatMessage(
      id: json['id'] ?? json['message_id'] ?? '',
      conversationId: json['conversation_id'] ?? '',
      senderUserId: json['sender_user_id'] ?? '',
      senderName: json['sender_name'],
      message: json['message'] ?? json['content'],
      mediaUrl: json['media_url'] ?? json['attachment_url'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isDeleted: json['is_deleted'] ?? false,
      isEdited: json['is_edited'] ?? false,
      editedAt: json['edited_at'],
      isMine: json['sender_user_id'] == myUserId,
      isRead: json['is_read'] ?? false,
    );
  }

  ChatMessage copyWith({
    String? id,
    String? conversationId,
    String? senderUserId,
    String? senderName,
    String? message,
    String? mediaUrl,
    DateTime? createdAt,
    bool? isDeleted,
    bool? isEdited,
    String? editedAt,
    bool? isMine,
    bool? isPending,
    bool? isRead,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderUserId: senderUserId ?? this.senderUserId,
      senderName: senderName ?? this.senderName,
      message: message ?? this.message,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      createdAt: createdAt ?? this.createdAt,
      isDeleted: isDeleted ?? this.isDeleted,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      isMine: isMine ?? this.isMine,
      isPending: isPending ?? this.isPending,
      isRead: isRead ?? this.isRead,
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
/// CHAT NOTIFIER — WebSocket Entegre
/// ──────────────────────────────────────────────

class ChatNotifier extends StateNotifier<ChatState> {
  final ChatWebSocketService _ws = ChatWebSocketService();
  String? _myUserId;
  final _offlineStorage = OfflineStorage();
  final _connService = ConnectivityService();

  ChatNotifier() : super(ChatState()) {
    _setupWebSocketCallbacks();
  }

  // ── WebSocket Callbacks ──────────────────────────────────────────────

  void _setupWebSocketCallbacks() {
    _ws.onMessage = _handleNewMessage;
    _ws.onMessageEdited = _handleMessageEdited;
    _ws.onMessageDeleted = _handleMessageDeleted;
    _ws.onMessageRead = _handleMessageRead;
    _ws.onConversationRead = _handleConversationRead;
  }

  void _handleNewMessage(Map<String, dynamic> data) {
    // Sadece aktif konuşmaya gelen mesajları işle
    if (state.activeConversation == null) return;
    final convId = data['conversation_id'];
    if (convId != state.activeConversation!.id) return;

    final msg = ChatMessage.fromJson(data, _myUserId ?? '');
    if (msg.senderUserId != _myUserId) {
      // Gelen mesaj: listeye ekle ve okundu bildir
      state = state.copyWith(messages: [...state.messages, msg]);
      _ws.markConversationRead(convId);
      // Ayrıca bu mesajı okundu olarak işaretle (§4.1.8-B)
      markMessageRead(msg.id);
    }
  }

  void _handleMessageEdited(Map<String, dynamic> data) {
    final id = data['id'] ?? data['message_id'];
    if (id == null) return;
    final updated = state.messages.map((m) {
      if (m.id == id) {
        return m.copyWith(
          message: data['content'] ?? m.message,
          isEdited: true,
          editedAt: data['edited_at'],
        );
      }
      return m;
    }).toList();
    state = state.copyWith(messages: updated);
  }

  void _handleMessageDeleted(Map<String, dynamic> data) {
    final id = data['id'] ?? data['message_id'];
    if (id == null) return;
    final updated = state.messages.where((m) => m.id != id).toList();
    state = state.copyWith(messages: updated);
  }

  void _handleMessageRead(Map<String, dynamic> data) {
    final id = data['message_id'];
    if (id == null) return;
    final updated = state.messages.map((m) {
      if (m.id == id) return m.copyWith(isRead: true);
      return m;
    }).toList();
    state = state.copyWith(messages: updated);
  }

  void _handleConversationRead(Map<String, dynamic> data) {
    // Tüm mesajları okundu olarak işaretle
    final updated = state.messages
        .map((m) => m.isMine ? m : m.copyWith(isRead: true))
        .toList();
    state = state.copyWith(messages: updated);
  }

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

    // REST ile geçmiş mesajları yükle
    await fetchMessages(conv.id);

    // WebSocket'e bağlan (gerçek zamanlı mesajlar için)
    await _ws.connect(conv.id);
  }

  void clearActiveConversation() {
    _ws.disconnect();
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

        // Gelen mesajları okundu olarak işaretle (§4.1.8-B)
        _markConversationReadApi(conversationId);
        // Ayrıca her okunmamış mesajı tek tek işaretle
        for (final msg in messages) {
          if (!msg.isMine && !msg.isRead) {
            markMessageRead(msg.id);
          }
        }
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

  /// Sends a text message. Optionally attaches a media URL as an attachment.
  Future<bool> sendMessage(String text, {String? attachmentUrl}) async {
    final conv = state.activeConversation;
    final hasAttachment = attachmentUrl != null && attachmentUrl.isNotEmpty;
    if (conv == null || (!hasAttachment && text.trim().isEmpty)) return false;

    if (_connService.isOnline) {
      try {
        final data = {
          'type': 'message',
          'conversation_id': conv.id,
          'message': hasAttachment ? null : text.trim(),
          if (hasAttachment) 'attachment_url': attachmentUrl,
        };
        final response = await ApiClient.dio.post('/chat/messages', data: data);
        if (response.statusCode == 200 || response.statusCode == 201) {
          return true;
        }
      } catch (e) {
        debugPrint('Send message error: $e — falling back to outbox');
        await _queueToOutbox(conv.id, text.trim(), attachmentUrl: attachmentUrl);
        return true;
      }
    } else {
      await _queueToOutbox(conv.id, text.trim(), attachmentUrl: attachmentUrl);
      return true;
    }
    return false;
  }

  Future<void> _queueToOutbox(String conversationId, String text, {String? attachmentUrl}) async {
    final hasAttachment = attachmentUrl != null && attachmentUrl.isNotEmpty;
    final pendingMsg = ChatMessage.pending(
      conversationId: conversationId,
      message: hasAttachment ? null : text,
      senderUserId: _myUserId ?? '',
    );
    addLocalMessage(pendingMsg);
    await _offlineStorage.addToOutbox(pendingMsg.id, {
      'local_id': pendingMsg.id,
      'conversation_id': conversationId,
      'message': hasAttachment ? null : text,
      'attachment_url': attachmentUrl,
      'created_at': pendingMsg.createdAt.toIso8601String(),
    });
  }

  /// Called by SyncService after reconnect — replaces pending msg with server msg.
  void confirmMessage(String localId, String serverId) {
    final msgs = state.messages.map((m) {
      if (m.id == localId) {
        return ChatMessage(
          id: serverId,
          conversationId: m.conversationId,
          senderUserId: m.senderUserId,
          senderName: m.senderName,
          message: m.message,
          mediaUrl: m.mediaUrl,
          createdAt: m.createdAt,
          isDeleted: false,
          isEdited: false,
          isMine: true,
          isPending: false,
          isRead: false,
        );
      }
      return m;
    }).toList();
    state = state.copyWith(messages: msgs);
  }

  void removePendingMessage(String localId) {
    final msgs = state.messages.where((m) => m.id != localId).toList();
    state = state.copyWith(messages: msgs);
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
        final convs = state.conversations.where((c) => c.id != conversationId).toList();
        state = state.copyWith(conversations: convs);
        if (state.activeConversation?.id == conversationId) {
          clearActiveConversation();
        }
        return true;
      }
    } catch (e) {
      debugPrint('Archive error: $e');
    }
    return false;
  }

  // ── Okundu Bildirimi (§4.1.8-B) ──

  Future<void> _markConversationReadApi(String conversationId) async {
    try {
      await ApiClient.dio.patch('/chat/conversations/$conversationId/read-all');
    } catch (e) {
      debugPrint('Mark read error: $e');
    }
  }

  void markMessageRead(String messageId) {
    ApiClient.dio.patch('/chat/messages/$messageId/read').then((_) {
      // OK
    }).catchError((e) {
      debugPrint('Mark message read error: $e');
    });
  }

  // ── User ID ──

  void setMyUserId(String id) {
    _myUserId = id;
  }

  @override
  void dispose() {
    _ws.dispose();
    super.dispose();
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier();
});
