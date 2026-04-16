import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../providers/finance_provider.dart';
import '../screens/mali_rapor_screen.dart';
import '../screens/chat_window_screen.dart';
import '../providers/chat_provider.dart';

/// FinanceTab — PRD §4.1.5
/// A) Action Bar (Ekstre Yükle + Excel Export)
/// B) Uyarı Banner'ı (Manual Onay Bekleyen)
/// C) 4 Ana Sekme (Ödeyenler / Bekleyenler / Gecikenler / Kısmi Ödeyenler)
/// 🚀 Bank API bilgilendirmesi
class FinanceTab extends ConsumerStatefulWidget {
  const FinanceTab({Key? key}) : super(key: key);

  @override
  ConsumerState<FinanceTab> createState() => _FinanceTabState();
}

class _FinanceTabState extends ConsumerState<FinanceTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final financeState = ref.watch(financeProvider);
    final notifier = ref.read(financeProvider.notifier);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── §4.1.5-A: EYLEM ÇUBUĞU ─────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.auto_awesome,
                                      color: AppColors.accent,
                                      size: 12,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'GEMINI AI',
                                      style: TextStyle(
                                        color: AppColors.accent,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Tahsilat\nMerkezi',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textHeader,
                              height: 1.15,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Mali Rapor icon button
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MaliRaporScreen(),
                          ),
                        );
                      },
                      icon: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.bar_chart_rounded,
                          color: AppColors.accent,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // §4.1.5-A: Action buttons row
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.cloud_upload_outlined,
                        label: 'Ekstre Yükle',
                        color: AppColors.accent,
                        isLoading: financeState is AsyncLoading,
                        onTap: () => notifier.uploadBankStatement(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.download_rounded,
                        label: 'Excel Çıktı',
                        color: AppColors.success,
                        onTap: () => _showExcelExportInfo(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── §4.1.5-B: UYARI BANNER'I ───────────────────────────
          financeState.when(
            data: (transactions) {
              final pendingCount =
                  transactions.where((t) => t.status == MatchStatus.pending).length;
              if (pendingCount == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _WarningBanner(
                  count: pendingCount,
                  onTap: () {
                    _tabController.animateTo(3); // Go to pending tab
                  },
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          const SizedBox(height: 12),

          // ── §4.1.5-C: 4 SEKME ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: AppColors.accent,
                indicatorSize: TabBarIndicatorSize.label,
                indicatorWeight: 3,
                labelColor: AppColors.accent,
                unselectedLabelColor: AppColors.textBody,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 0.3,
                ),
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsets.all(4),
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 14),
                        SizedBox(width: 5),
                        Text('Ödeyenler'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule, size: 14),
                        SizedBox(width: 5),
                        Text('Bekleyenler'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber, size: 14),
                        SizedBox(width: 5),
                        Text('Gecikenler'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.percent, size: 14),
                        SizedBox(width: 5),
                        Text('Kısmi'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── TAB CONTENT ────────────────────────────────────────
          Expanded(
            child: financeState.when(
              loading: () => _buildLoadingState(),
              error: (err, _) => _buildErrorState(err),
              data: (transactions) {
                if (transactions.isEmpty) {
                  return _buildEmptyState(notifier);
                }

                // Categorize
                final paid = transactions.where((t) => t.status == MatchStatus.matched).toList();
                final pending = transactions.where((t) => t.status == MatchStatus.pending).toList();
                final overdue = transactions.where((t) => t.status == MatchStatus.overdue).toList();
                final partial = transactions.where((t) => t.status == MatchStatus.partial).toList();

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _TransactionList(
                      transactions: paid,
                      emptyMessage: 'Henüz tam ödenen işlem yok',
                      emptyIcon: Icons.check_circle_outline,
                      type: TransactionListType.paid,
                    ),
                    _TransactionList(
                      transactions: pending,
                      emptyMessage: 'Ödemesi bekleyen kiracı yok',
                      emptyIcon: Icons.schedule,
                      type: TransactionListType.pending,
                    ),
                    _TransactionList(
                      transactions: overdue,
                      emptyMessage: 'Geciken ödeme yok',
                      emptyIcon: Icons.warning_amber_rounded,
                      type: TransactionListType.overdue,
                    ),
                    _TransactionList(
                      transactions: partial,
                      emptyMessage: 'Kısmi ödeme yok',
                      emptyIcon: Icons.percent,
                      type: TransactionListType.partial,
                    ),
                  ],
                );
              },
            ),
          ),

          // ── 🚀 GELECEK PLANLAMASI BANNER ─────────────────────
          _FutureNoticeBanner(),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.8 + (0.2 * value),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: AppColors.accent,
                    size: 48,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          const Text(
            'Gemini 2.5 Flash Analiz Ediyor...',
            style: TextStyle(
              color: AppColors.textHeader,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bulanık mantık motoru çalıştırılıyor',
            style: TextStyle(
              color: AppColors.textBody.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object err) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              'Analiz hatası',
              style: TextStyle(
                color: AppColors.textHeader,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              err.toString(),
              style: TextStyle(
                color: AppColors.textBody.withValues(alpha: 0.6),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(FinanceNotifier notifier) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_upload_outlined,
                size: 48,
                color: AppColors.textBody,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Henüz banka ekstresi taranmadı',
              style: TextStyle(
                color: AppColors.textHeader,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Yukarıdaki "Ekstre Yükle" butonuna basarak\nPDF hesap dökümünü yükleyin',
              style: TextStyle(
                color: AppColors.textBody.withValues(alpha: 0.65),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => notifier.uploadBankStatement(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.add, size: 20),
              label: const Text(
                'İlk Ekstreyi Yükle',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExcelExportInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.download_rounded, color: AppColors.success, size: 22),
            SizedBox(width: 10),
            Text(
              'Excel Çıktısı',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'Aktif sekmedeki tüm kiracı ödeme verilerini (Ad, Daire, Bekleyen Tutar, Gecikme Günü) .xlsx formatında indirirsiniz.',
          style: TextStyle(color: AppColors.textBody, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Kapat',
              style: TextStyle(color: AppColors.textBody),
            ),
          ),
        ],
      ),
    );
  }
}

// ── §4.1.5-A: ACTION BUTTON ───────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isLoading;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: isLoading ? 0.10 : 0.25),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
              )
            else
              Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── §4.1.5-B: WARNING BANNER ──────────────────────────────────────
class _WarningBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _WarningBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.warning.withValues(alpha: 0.15),
              AppColors.warning.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.30),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.20),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.psychology,
                color: AppColors.warning,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ $count işlem onay bekliyor',
                    style: const TextStyle(
                      color: AppColors.warning,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'AI, kime ait olduğunu tam eşleştiremedi. İncelemek için tıklayın.',
                    style: TextStyle(
                      color: AppColors.warning.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.warning,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ── §4.1.5-C: TRANSACTION LIST ───────────────────────────────────
enum TransactionListType { paid, pending, overdue, partial }

class _TransactionList extends ConsumerWidget {
  final List<TransactionModel> transactions;
  final String emptyMessage;
  final IconData emptyIcon;
  final TransactionListType type;

  const _TransactionList({
    required this.transactions,
    required this.emptyMessage,
    required this.emptyIcon,
    required this.type,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(emptyIcon, size: 40, color: AppColors.textBody),
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(
                color: AppColors.textBody.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      itemCount: transactions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final trx = transactions[index];
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(
            milliseconds: 350 + (index * 50).clamp(0, 300),
          ),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 12 * (1 - value)),
                child: child,
              ),
            );
          },
          child: _TransactionCard(trx: trx, type: type),
        );
      },
    );
  }
}

// ── TRANSACTION CARD ─────────────────────────────────────────────
class _TransactionCard extends ConsumerWidget {
  final TransactionModel trx;
  final TransactionListType type;

  const _TransactionCard({required this.trx, required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(financeProvider.notifier);

    // Color coding by type
    final (accentColor, bgColor, borderColor) = _getColors(type, trx.status);
    final statusIcon = _getStatusIcon(type, trx.status);
    final statusLabel = _getStatusLabel(type, trx.status);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor.withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              // Status icon
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(statusIcon, color: accentColor, size: 18),
                    ),
                  );
                },
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trx.senderName,
                      style: const TextStyle(
                        color: AppColors.textHeader,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      trx.description,
                      style: TextStyle(
                        color: AppColors.textBody.withValues(alpha: 0.65),
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₺${trx.amount.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // AI confidence badge (if pending/manual)
          if (trx.status == MatchStatus.pending) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    color: AppColors.warning,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '🤖 AI Eşleşti (%${trx.aiConfidence.toStringAsFixed(0)})',
                    style: const TextStyle(
                      color: AppColors.warning,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => notifier.approveTransaction(trx.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Teyit Et',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Type-specific action buttons
          if (type == TransactionListType.pending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (trx.daysUntilDue != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Ödemeye ${trx.daysUntilDue} gün var',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                const Spacer(),
                _SmallActionButton(
                  icon: Icons.notifications_outlined,
                  label: 'Hatırlat',
                  color: AppColors.accent,
                  onTap: () => notifier.sendReminder(trx.id),
                ),
              ],
            ),
          ],

          if (type == TransactionListType.overdue) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (trx.overdueDays != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${trx.overdueDays} gün gecikti',
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                const Spacer(),
                _SmallActionButton(
                  icon: Icons.warning_amber_outlined,
                  label: 'İhtar',
                  color: AppColors.error,
                  onTap: () => notifier.sendWarning(trx.id),
                ),
                const SizedBox(width: 8),
                _SmallActionButton(
                  icon: Icons.chat_bubble_outline,
                  label: 'Mesaj',
                  color: AppColors.success,
                  onTap: () => _openChatWithTenant(context, ref, trx),
                ),
              ],
            ),
          ],

          if (type == TransactionListType.partial) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Beklenen',
                          style: TextStyle(
                            color: AppColors.textBody,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          '₺${(trx.expectedAmount ?? 0).toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: AppColors.textHeader,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Yatan',
                            style: TextStyle(color: AppColors.success, fontSize: 10),
                          ),
                          Text(
                            '₺${trx.amount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: AppColors.success,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Kalan',
                            style: TextStyle(color: AppColors.error, fontSize: 10),
                          ),
                          Text(
                            '₺${((trx.expectedAmount ?? 0) - trx.amount).toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textBody,
                      side: BorderSide(
                        color: AppColors.textBody.withValues(alpha: 0.2),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Aya Devret',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => notifier.markAsReceived(trx.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Elden Alındı',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  (Color, Color, Color) _getColors(
      TransactionListType type, MatchStatus status) {
    switch (type) {
      case TransactionListType.paid:
        return (AppColors.success, AppColors.success, AppColors.success);
      case TransactionListType.pending:
        return (AppColors.accent, AppColors.accent, AppColors.accent);
      case TransactionListType.overdue:
        return (AppColors.error, AppColors.error, AppColors.error);
      case TransactionListType.partial:
        return (const Color(0xFF5B8DEF), const Color(0xFF5B8DEF), const Color(0xFF5B8DEF));
    }
  }

  IconData _getStatusIcon(TransactionListType type, MatchStatus status) {
    switch (type) {
      case TransactionListType.paid:
        return Icons.check_circle;
      case TransactionListType.pending:
        return Icons.schedule;
      case TransactionListType.overdue:
        return Icons.warning_amber_rounded;
      case TransactionListType.partial:
        return Icons.percent;
    }
  }

  String _getStatusLabel(TransactionListType type, MatchStatus status) {
    switch (type) {
      case TransactionListType.paid:
        return 'Ödendi';
      case TransactionListType.pending:
        return 'Bekliyor';
      case TransactionListType.overdue:
        return 'Gecikti';
      case TransactionListType.partial:
        return 'Kısmi';
    }
  }

  /// Geciken kiracıyla sohbet başlatır — PRD §4.1.5
  Future<void> _openChatWithTenant(BuildContext context, WidgetRef ref, TransactionModel trx) async {
    if (trx.tenantUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kiracı bilgisi bulunamadı'), backgroundColor: AppColors.warning),
      );
      return;
    }

    final notifier = ref.read(financeProvider.notifier);
    final conversationId = await notifier.openChatWithTenant(trx.tenantUserId!);
    if (conversationId != null && context.mounted) {
      // Mevcut conversation objesi oluştur
      final conversation = ChatConversation(
        id: conversationId,
        agencyId: '',
        agentUserId: '',
        clientUserId: trx.tenantUserId!,
        clientName: trx.senderName,
        lastMessage: null,
        lastMessageAt: null,
        unreadCount: 0,
        isArchived: false,
      );
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ChatWindowScreen(conversation: conversation),
      ));
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sohbet başlatılamadı'), backgroundColor: AppColors.error),
      );
    }
  }
}

class _SmallActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SmallActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 🚀 GELECEK PLANLAMASI BANNER ──────────────────────────────────
class _FutureNoticeBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.rocket_launch,
              color: AppColors.accent,
              size: 14,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🚀 Yakında: Otomatik Banka Entegrasyonu',
                  style: TextStyle(
                    color: AppColors.textHeader,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Banka API ile manuel PDF yüklemeye gerek kalmadan anlık veri çekimi',
                  style: TextStyle(
                    color: AppColors.textBody.withValues(alpha: 0.55),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}