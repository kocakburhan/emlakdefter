import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/offline/offline_cache_provider.dart';
import '../../../core/offline/offline_storage.dart';
import '../../../core/offline/sync_service.dart';

/// §5.3 — Pending Operations Screen
/// Shows all queued offline items and allows manual sync trigger.
class PendingOperationsScreen extends ConsumerStatefulWidget {
  const PendingOperationsScreen({super.key});

  @override
  ConsumerState<PendingOperationsScreen> createState() => _PendingOperationsScreenState();
}

class _PendingOperationsScreenState extends ConsumerState<PendingOperationsScreen> {
  bool _isSyncing = false;

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingSyncCountProvider);
    final storage = OfflineStorage();

    final outboxMessages = storage.getAllOutboxMessages();
    final outboxCount = storage.outboxCount;

    final opQueue = storage.getAllOpQueue();
    final opCount = storage.opQueueCount;

    final txQueue = storage.getAllTxQueue();
    final txCount = storage.txQueueCount;

    final hasPending = pending > 0;

    return Scaffold(
      backgroundColor: const Color(0xFF141210),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1917),
        foregroundColor: Colors.white,
        title: const Text(
          'Bekleyen İşlemler',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (hasPending)
            TextButton.icon(
              onPressed: _isSyncing ? null : _triggerSync,
              icon: _isSyncing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.sync, size: 18),
              label: Text(_isSyncing ? 'Senkronize ediliyor...' : 'Şimdi Senkronize Et'),
            ),
        ],
      ),
      body: !hasPending
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_done, size: 64, color: Colors.green.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'Tüm veriler senkronize',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Bekleyen işlem yok',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Summary Card ──────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4A574).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFD4A574).withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _countBadge('Mesajlar', outboxCount, Icons.chat_bubble_outline),
                          _countBadge('Operasyonlar', opCount, Icons.build_outlined),
                          _countBadge('İşlemler', txCount, Icons.account_balance_wallet_outlined),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSyncing ? null : _triggerSync,
                          icon: _isSyncing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF141210),
                                  ),
                                )
                              : const Icon(Icons.sync, size: 18),
                          label: Text(
                            _isSyncing
                                ? 'Senkronize Ediliyor...'
                                : 'Tümünü Senkronize Et',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD4A574),
                            foregroundColor: const Color(0xFF141210),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Chat Messages ───────────────────────────────────────────────
                if (outboxMessages.isNotEmpty) ...[
                  _sectionHeader('Mesaj Kutusu', outboxCount, Icons.chat_bubble_outline),
                  const SizedBox(height: 8),
                  ...outboxMessages.map((msg) => _outboxMessageCard(msg)),
                  const SizedBox(height: 16),
                ],

                // ── Operation Queue ────────────────────────────────────────────
                if (opQueue.isNotEmpty) ...[
                  _sectionHeader('Bina Operasyonları', opCount, Icons.build_outlined),
                  const SizedBox(height: 8),
                  ...opQueue.map((op) => _operationCard(op)),
                  const SizedBox(height: 16),
                ],

                // ── Transaction Queue ─────────────────────────────────────────
                if (txQueue.isNotEmpty) ...[
                  _sectionHeader('Finansal İşlemler', txCount, Icons.account_balance_wallet_outlined),
                  const SizedBox(height: 8),
                  ...txQueue.map((tx) => _transactionCard(tx)),
                ],

                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _countBadge(String label, int count, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFD4A574).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFFD4A574), size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title, int count, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFD4A574), size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFD4A574).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            count.toString(),
            style: const TextStyle(color: Color(0xFFD4A574), fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _outboxMessageCard(Map<String, dynamic> msg) {
    final localId = msg['local_id'] as String? ?? '—';
    final conversationId = msg['conversation_id'] as String? ?? '';
    final message = msg['message'] as String? ?? '';
    final createdAt = msg['created_at'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1917),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule, color: Colors.orange, size: 14),
              const SizedBox(width: 6),
              const Text(
                'Gönderilmeyi bekliyor',
                style: TextStyle(color: Colors.orange, fontSize: 12),
              ),
              const Spacer(),
              Text(
                localId.substring(0, 8),
                style: const TextStyle(color: Colors.white24, fontSize: 11, fontFamily: 'monospace'),
              ),
            ],
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Konuşma: ${conversationId.isNotEmpty ? conversationId.substring(0, 8) : '—'} • $createdAt',
            style: const TextStyle(color: Colors.white24, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _operationCard(Map<String, dynamic> op) {
    final localId = op['local_id'] as String? ?? '—';
    final title = op['title'] as String? ?? '—';
    final category = op['category'] as String? ?? 'Diğer';
    final cost = op['cost'] as num? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1917),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.build_outlined, color: Colors.blue, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  '$category • ₺$cost',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            localId.substring(0, 8),
            style: const TextStyle(color: Colors.white24, fontSize: 10, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Widget _transactionCard(Map<String, dynamic> tx) {
    final localId = tx['local_id'] as String? ?? '—';
    final type = tx['type'] as String? ?? '—';
    final category = tx['category'] as String? ?? '';
    final amount = tx['amount'] as num? ?? 0;
    final description = tx['description'] as String? ?? '';

    final isIncome = type == 'income';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1917),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isIncome ? Colors.green : Colors.red).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isIncome ? Icons.arrow_downward : Icons.arrow_upward,
              color: isIncome ? Colors.green : Colors.red,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$category • ₺$amount',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Text(
            localId.substring(0, 8),
            style: const TextStyle(color: Colors.white24, fontSize: 10, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Future<void> _triggerSync() async {
    setState(() => _isSyncing = true);
    try {
      await SyncService().syncAll();
      ref.invalidate(pendingSyncCountProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Senkronizasyon tamamlandı'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Senkronizasyon hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }
}
