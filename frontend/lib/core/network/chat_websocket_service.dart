import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_client.dart';

/// WebSocket olayları için callback türleri
typedef WsMessageCallback = void Function(Map<String, dynamic> data);
typedef WsConnectionCallback = void Function();

/// Chat WebSocket Servisi — Backend WebSocket endpoint'ine bağlanır.
///
/// Desteklenen olaylar:
/// - new_message      : Yeni mesaj geldi
/// - message_edited  : Mesaj düzenlendi
/// - message_deleted : Mesaj silindi (soft delete)
/// - message_read    : Mesaj okundu bilgisi (✓✓)
/// - conversation_read: Tüm mesajlar okundu
class ChatWebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  String? _currentConversationId;
  Timer? _reconnectTimer;
  bool _shouldReconnect = false;

  // Callbacks
  WsMessageCallback? onMessage;
  WsMessageCallback? onMessageEdited;
  WsMessageCallback? onMessageDeleted;
  WsMessageCallback? onMessageRead;
  WsMessageCallback? onConversationRead;
  WsConnectionCallback? onConnected;
  WsConnectionCallback? onDisconnected;
  WsConnectionCallback? onError;

  bool get isConnected => _channel != null;

  String? get currentConversationId => _currentConversationId;

  /// Belirtilen conversation'a WebSocket ile bağlan.
  /// Aynı conversation'a tekrar bağlanmaz (idempotent).
  Future<void> connect(String conversationId) async {
    if (isConnected && _currentConversationId == conversationId) return;

    await disconnect();

    _currentConversationId = conversationId;
    _shouldReconnect = true;

    await _doConnect(conversationId);
  }

  Future<void> _doConnect(String conversationId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        debugPrint('[WS] Token alınamadı, bağlantı kurulamadı');
        _scheduleReconnect(conversationId);
        return;
      }

      final wsBaseUrl = _wsBaseUrl;
      final uri = Uri.parse('$wsBaseUrl/chat/ws/$conversationId?token=$token');
      debugPrint('[WS] Bağlanıyor: $uri');

      _channel = WebSocketChannel.connect(uri);

      _subscription = _channel!.stream.listen(
        (data) {
          _handleMessage(data);
        },
        onError: (error) {
          debugPrint('[WS] Hata: $error');
          onError?.call();
        },
        onDone: () {
          debugPrint('[WS] Bağlantı kapandı');
          onDisconnected?.call();
          if (_shouldReconnect && _currentConversationId != null) {
            _scheduleReconnect(_currentConversationId!);
          }
        },
      );

      debugPrint('[WS] Bağlantı açıldı: $conversationId');
      onConnected?.call();
    } catch (e) {
      debugPrint('[WS] Bağlantı hatası: $e');
      onError?.call();
      _scheduleReconnect(conversationId);
    }
  }

  void _handleMessage(dynamic data) {
    try {
      final Map<String, dynamic> json;
      if (data is String) {
        json = jsonDecode(data) as Map<String, dynamic>;
      } else {
        json = Map<String, dynamic>.from(data as Map);
      }
      final type = json['type'] as String?;
      debugPrint('[WS] Mesaj alındı: $type');

      switch (type) {
        case 'new_message':
        case 'message':
          onMessage?.call(json);
          break;
        case 'message_edited':
          onMessageEdited?.call(json);
          break;
        case 'message_deleted':
          onMessageDeleted?.call(json);
          break;
        case 'message_read':
          onMessageRead?.call(json);
          break;
        case 'conversation_read':
          onConversationRead?.call(json);
          break;
        default:
          debugPrint('[WS] Bilinmeyen mesaj tipi: $type');
      }
    } catch (e) {
      debugPrint('[WS] Mesaj çözümleme hatası: $e');
    }
  }

  /// Sohbetteki tüm mesajları okundu olarak işaretle.
  void markConversationRead(String conversationId) {
    _send({'type': 'mark_read', 'conversation_id': conversationId});
  }

  /// Sunucuya ping gönder (bağlantı canlılığını korumak için).
  void sendPing() {
    _send({'type': 'ping'});
  }

  void _scheduleReconnect(String conversationId) {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (_shouldReconnect && _currentConversationId == conversationId) {
        debugPrint('[WS] Yeniden bağlanıyor: $conversationId');
        _doConnect(conversationId);
      }
    });
  }

  /// WebSocket bağlantısını kapat.
  /// [force] = true ise yeniden bağlanma denemesi yapma.
  Future<void> disconnect({bool force = false}) async {
    _shouldReconnect = !force;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    if (_channel != null) {
      await _subscription?.cancel();
      _subscription = null;
      try {
        await _channel?.sink.close();
      } catch (_) {}
      _channel = null;
    }
    _currentConversationId = null;
  }

  void _send(Map<String, dynamic> data) {
    if (isConnected) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  Future<String?> _getToken() async {
    // Önce simple auth token dene
    final simpleToken = ApiClient.simpleAuthToken;
    if (simpleToken != null) return simpleToken;

    // Firebase token dene
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        return await user.getIdToken();
      }
    } catch (e) {
      debugPrint('[WS] Token alma hatası: $e');
    }
    return null;
  }

  String get _wsBaseUrl {
    const port = '8001';
    if (kIsWeb) {
      return 'ws://127.0.0.1:$port/api/v1';
    }
    // Android emulator: 10.0.2.2 → host machine's localhost
    // iOS simulator / physical device: use configured server IP
    // The production URL should come from environment config
    return 'ws://10.0.2.2:$port/api/v1';
  }

  void dispose() {
    disconnect(force: true);
    _reconnectTimer?.cancel();
  }
}
