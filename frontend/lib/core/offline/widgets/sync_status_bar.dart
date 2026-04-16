import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../offline_cache_provider.dart';
import '../sync_service.dart';
import '../../../features/agent/screens/pending_operations_screen.dart';

/// Global sync status indicator — shows pending items count and sync progress.
/// Placed at the top of main screens (above AppBar).
class SyncStatusBar extends ConsumerStatefulWidget {
  const SyncStatusBar({super.key});

  @override
  ConsumerState<SyncStatusBar> createState() => _SyncStatusBarState();
}

class _SyncStatusBarState extends ConsumerState<SyncStatusBar> {
  bool _isSyncing = false;

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingSyncCountProvider);
    final isOnline = ref.watch(isOnlineProvider);

    // Don't show when online and no pending items
    if (isOnline && pending == 0) return const SizedBox.shrink();

    return GestureDetector(
      onTap: _openPendingScreen,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 50,
          left: 16,
          right: 16,
          bottom: 8,
        ),
        margin: const EdgeInsets.only(bottom: 0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: pending > 0
                ? [const Color(0xFFD4A574), const Color(0xFFB8865A)]
                : [Colors.green.shade600, Colors.green.shade700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          top: false,
          bottom: false,
          child: Row(
            children: [
              _isSyncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(
                      pending > 0 ? Icons.cloud_upload_outlined : Icons.cloud_done,
                      color: Colors.white,
                      size: 18,
                    ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _statusText(pending, isOnline),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (pending > 0 && isOnline)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Şimdi Senkronize Et',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              if (pending > 0 && !isOnline)
                const Icon(Icons.wifi_off, color: Colors.white70, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  String _statusText(int pending, bool isOnline) {
    if (!isOnline) {
      return pending > 0
          ? '$pending işlem çevrimdışı beklemede'
          : 'Çevrimdışı moddasın';
    }
    return pending > 0
        ? '$pending işlem senkronizasyon bekliyor'
        : 'Tüm veriler senkronize';
  }

  Future<void> _openPendingScreen() async {
    setState(() => _isSyncing = true);
    try {
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => const PendingOperationsScreen(),
        ),
      );
      if (result == true) {
        // Sync completed — trigger refresh
        ref.invalidate(pendingSyncCountProvider);
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }
}

/// Thin inline version for embedding inside existing screens.
class SyncStatusBanner extends ConsumerWidget {
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingSyncCountProvider);
    if (pending == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFD4A574).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFD4A574).withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_upload_outlined, color: Color(0xFFD4A574), size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$pending işlem senkronizasyon bekliyor',
                style: const TextStyle(color: Color(0xFFD4A574), fontSize: 12),
              ),
            ),
            GestureDetector(
              onTap: () => _triggerSync(ref),
              child: const Icon(Icons.refresh, color: Color(0xFFD4A574), size: 16),
            ),
          ],
        ),
      ),
    );
  }

  void _triggerSync(WidgetRef ref) {
    SyncService().syncAll();
  }
}
