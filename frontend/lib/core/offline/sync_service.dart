import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../network/api_client.dart';
import 'connectivity_service.dart';
import 'offline_storage.dart';

/// HTTP 409 — item was already synced (conflict). Safe to remove from queue.
class ConflictException implements Exception {
  final String itemId;
  ConflictException(this.itemId);
  @override
  String toString() => 'ConflictException($itemId)';
}

/// Handles auto-sync of pending queue items when connectivity returns.
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final OfflineStorage _storage = OfflineStorage();
  final ConnectivityService _conn = ConnectivityService();

  bool _syncing = false;

  /// ✅ EKLENDI — Merkezi UUID üretimi (§5.3 — çakışma önleme)
  String generateUuid() => const Uuid().v4();

  /// Initialize — wires up connectivity → sync trigger.
  Future<void> initialize() async {
    await _storage.initialize();
    _conn.onReconnect = _onConnectivityRestored;
    _conn.onReconnectRefresh = _onConnectivityRestored;
  }

  void _onConnectivityRestored() {
    debugPrint('[SyncService] Connectivity restored — triggering sync and cache refresh');
    // Invalidate portfolio cache so next fetch gets fresh data
    _storage.invalidatePortfolio();
    syncAll();
  }

  /// Manually trigger full sync of all queues.
  Future<void> syncAll() async {
    if (_syncing) return;
    _syncing = true;

    try {
      await Future.wait([
        _syncChatOutbox(),
        _syncOperationQueue(),
        _syncTransactionQueue(),
      ]);
    } finally {
      _syncing = false;
    }
  }

  // ─── Chat Outbox Sync ────────────────────────────────────────

  Future<void> _syncChatOutbox() async {
    final pending = _storage.getAllOutboxMessages();
    if (pending.isEmpty) return;

    debugPrint('[SyncService] Syncing ${pending.length} chat messages from outbox');

    for (final msg in pending) {
      final id = msg['local_id'] as String;
      final conversationId = msg['conversation_id'] as String?;
      final message = msg['message'] as String? ?? '';
      final createdAtStr = msg['created_at'] as String?;

      try {
        if (conversationId != null && conversationId.isNotEmpty) {
          final requestData = {
            'conversation_id': conversationId,
            'message': message,
            'type': 'message',
          };

          // ✅ EKLENDI — Orijinal timestamp'i koru (PRD §5.2)
          if (createdAtStr != null) {
            requestData['client_created_at'] = createdAtStr;
          }

          final resp = await ApiClient.dio.post('/chat/messages', data: requestData);

          if (resp.statusCode == 200 || resp.statusCode == 201) {
            await _storage.removeFromOutbox(id);
            debugPrint('[SyncService] Chat message $id synced successfully');
          } else if (resp.statusCode == 409) {
            // Already synced — safe to remove from queue (§5.3 conflict resolution)
            await _storage.removeFromOutbox(id);
            debugPrint('[SyncService] Chat message $id conflict (already synced), removed from queue');
          }
        }
      } on ConflictException {
        // UUID conflict — already synced
        await _storage.removeFromOutbox(id);
        debugPrint('[SyncService] Chat message $id conflict exception, removed from queue');
      } catch (e) {
        debugPrint('[SyncService] Chat message $id sync failed: $e');
        // Keep in queue for next sync attempt
      }
    }
  }

  // ─── Operation Queue Sync ───────────────────────────────────

  Future<void> _syncOperationQueue() async {
    final pending = _storage.getAllOpQueue();
    if (pending.isEmpty) return;

    debugPrint('[SyncService] Syncing ${pending.length} operations from queue');

    for (final op in pending) {
      final id = op['local_id'] as String;
      try {
        final resp = await ApiClient.dio.post('/operations/building-logs', data: {
          'property_id': op['property_id'],
          'title': op['title'],
          'description': op['description'],
          'cost': op['cost'],
          'category': op['category'] ?? 'Diğer',
          'is_reflected_to_finance': op['is_reflected_to_finance'] ?? false,
        });

        if (resp.statusCode == 200 || resp.statusCode == 201) {
          await _storage.removeFromOpQueue(id);
          debugPrint('[SyncService] Operation $id synced successfully');
        }
      } catch (e) {
        debugPrint('[SyncService] Operation $id sync failed: $e');
      }
    }
  }

  // ─── Transaction Queue Sync ─────────────────────────────────

  Future<void> _syncTransactionQueue() async {
    final pending = _storage.getAllTxQueue();
    if (pending.isEmpty) return;

    debugPrint('[SyncService] Syncing ${pending.length} transactions from queue');

    for (final tx in pending) {
      final id = tx['local_id'] as String;
      try {
        final resp = await ApiClient.dio.post('/finance/transactions', data: {
          'property_id': tx['property_id'],
          'type': tx['type'],
          'category': tx['category'],
          'amount': tx['amount'],
          'description': tx['description'],
          'transaction_date': tx['transaction_date'],
        });

        if (resp.statusCode == 200 || resp.statusCode == 201) {
          await _storage.removeFromTxQueue(id);
          debugPrint('[SyncService] Transaction $id synced successfully');
        }
      } catch (e) {
        debugPrint('[SyncService] Transaction $id sync failed: $e');
      }
    }
  }

  int get pendingCount => _storage.totalPendingCount;
  int get outboxCount => _storage.outboxCount;
  int get opQueueCount => _storage.opQueueCount;
  int get txQueueCount => _storage.txQueueCount;
}

/// ─── Sync Status Provider — UI'da "Senkronizasyon Bekliyor" gösterimi için (§5.3)
final syncServiceProvider = Provider<SyncService>((ref) => SyncService());
