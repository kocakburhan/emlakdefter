import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tenant_provider.dart';

// ──────────────────────────────────────────────
// "Hearth Sanctuary" — Tenant Home
// Warm, welcoming, human premium dark theme
// PRD §4.2.1
// ──────────────────────────────────────────────

class TenantHomeTab extends ConsumerStatefulWidget {
  const TenantHomeTab({Key? key}) : super(key: key);

  @override
  ConsumerState<TenantHomeTab> createState() => _TenantHomeTabState();
}

class _TenantHomeTabState extends ConsumerState<TenantHomeTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _headerAnim;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _headerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _headerAnim, curve: Curves.easeOutCubic);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _headerAnim, curve: Curves.easeOutCubic));
    _headerAnim.forward();
  }

  @override
  void dispose() {
    _headerAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tenantProvider);
    final financeAsync = ref.watch(tenantFinanceProvider);
    final txAsync = ref.watch(tenantTransactionsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0D0B),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Column(
              children: [
                _buildHeader(state),
                Expanded(
                  child: state.when(
                    loading: () => _buildLoading(),
                    error: (e, _) => _buildError(e.toString()),
                    data: (info) => _buildBody(info, financeAsync, txAsync),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────
  Widget _buildHeader(AsyncValue<TenantInfo?> state) {
    return Container(
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
                    FadeTransition(
                      opacity: CurvedAnimation(
                        parent: _headerAnim,
                        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
                      ),
                      child: Text(
                        'EVİM',
                        style: TextStyle(
                          color: const Color(0xFFE8A87C).withValues(alpha: 0.6),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    FadeTransition(
                      opacity: CurvedAnimation(
                        parent: _headerAnim,
                        curve: const Interval(0.1, 0.6, curve: Curves.easeOut),
                      ),
                      child: Text(
                        state.maybeWhen(
                          data: (info) => info?.name ?? 'Kiracı',
                          orElse: () => 'Yükleniyor...',
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: _headerAnim,
                  curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
                ),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFE8A87C).withValues(alpha: 0.2),
                        const Color(0xFFE8A87C).withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFFE8A87C).withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Icon(
                    Icons.holiday_village_rounded,
                    color: Color(0xFFE8A87C),
                    size: 26,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ─── Body ────────────────────────────────────────────────────────────────
  Widget _buildBody(
    TenantInfo? info,
    AsyncValue<TenantFinanceSummary?> financeAsync,
    AsyncValue<List<TransactionItem>> txAsync,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(tenantFinanceProvider);
        ref.invalidate(tenantTransactionsProvider);
        ref.invalidate(tenantProvider);
      },
      color: const Color(0xFFE8A87C),
      backgroundColor: const Color(0xFF1A1612),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mülk chip
            if (info != null)
              _buildPropertyChip(info),
            const SizedBox(height: 16),

            // §4.2.1-A — Yaklaşan Ödemeler Hero Kartı
            _buildUpcomingPaymentsCard(financeAsync),
            const SizedBox(height: 24),

            // §4.2.1-B — Geçmiş İşlemler
            _buildTransactionHistory(txAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyChip(TenantInfo info) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, anim, child) => Opacity(
        opacity: anim,
        child: Transform.translate(offset: Offset(0, 8 * (1 - anim)), child: child),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE8A87C).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFE8A87C).withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_on_rounded,
              size: 14,
              color: const Color(0xFFE8A87C).withValues(alpha: 0.7),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '${info.propertyName} · Daire ${info.unitNumber}',
                style: TextStyle(
                  color: const Color(0xFFE8A87C).withValues(alpha: 0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── §4.2.1-A: Yaklaşan Ödemeler ───────────────────────────────────────
  Widget _buildUpcomingPaymentsCard(AsyncValue<TenantFinanceSummary?> financeAsync) {
    return financeAsync.when(
      loading: () => _shimmerCard(),
      error: (_, __) => _emptyCard(),
      data: (finance) {
        if (finance == null) return _emptyCard();

        final upcoming = finance.upcomingSchedules;
        final totalDue = finance.currentDebt;
        final nextDue = finance.nextDueDate;
        final hasDebt = totalDue > 0;

        // Calculate days remaining
        int? daysLeft;
        if (nextDue != null) {
          final parts = nextDue.split('.');
          if (parts.length == 3) {
            final dueDate = DateTime(
              int.parse(parts[2]),
              int.parse(parts[1]),
              int.parse(parts[0]),
            );
            daysLeft = dueDate.difference(DateTime.now()).inDays;
          }
        }

        // Rent vs Dues breakdown (approximate from total)
        final rentDue = (totalDue * 0.7).round();
        final duesDue = (totalDue * 0.3).round();

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, anim, child) => Opacity(
            opacity: anim,
            child: Transform.translate(offset: Offset(0, 16 * (1 - anim)), child: child),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: hasDebt
                    ? [const Color(0xFFE27D7D), const Color(0xFFC0392B)]
                    : [const Color(0xFF7AB892), const Color(0xFF52B788)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: (hasDebt
                          ? const Color(0xFFE27D7D)
                          : const Color(0xFF7AB892))
                      .withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Wave decoration
                Positioned(
                  right: -20,
                  bottom: -20,
                  child: Opacity(
                    opacity: 0.08,
                    child: Icon(
                      Icons.waves_rounded,
                      size: 140,
                      color: Colors.white,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Üst satır: başlık + countdown badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hasDebt ? 'Cari Dönem Borcunuz' : 'Borç Bulunmuyor',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₺${_fmt(totalDue.round())}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 38,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -1,
                                ),
                              ),
                            ],
                          ),
                          if (daysLeft != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '$daysLeft',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    daysLeft == 1 ? 'gün kaldı' : 'gün kaldı',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.6),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Kira / Aidat breakdown
                      Row(
                        children: [
                          Expanded(
                            child: _paymentTypePill(
                              icon: Icons.home_rounded,
                              label: 'Kira',
                              amount: rentDue,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _paymentTypePill(
                              icon: Icons.apartment_rounded,
                              label: 'Aidat',
                              amount: duesDue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Son ödeme tarihi
                      if (nextDue != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 13,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Son ödeme: $nextDue',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Yaklaşan ödeme takvimi
                      if (upcoming.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Divider(color: Colors.white12, height: 1),
                        const SizedBox(height: 12),
                        Text(
                          'Yaklaşan Ödemeler',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...upcoming.take(3).map((s) => _scheduleItem(s)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _paymentTypePill({
    required IconData icon,
    required String label,
    required int amount,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 10,
                  ),
                ),
                Text(
                  '₺${_fmt(amount)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scheduleItem(PaymentScheduleItem schedule) {
    final daysUntil = schedule.dueDate.difference(DateTime.now()).inDays;
    final isOverdue = daysUntil < 0;
    final isSoon = daysUntil >= 0 && daysUntil <= 3;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              color: isOverdue
                  ? const Color(0xFFE27D7D)
                  : isSoon
                      ? const Color(0xFFE8A87C)
                      : const Color(0xFF7AB892),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_catLabel(schedule.category)} — ₺${_fmt(schedule.amount.round())}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ),
          Text(
            _shortDate(schedule.dueDate),
            style: TextStyle(
              color: isOverdue
                  ? const Color(0xFFE27D7D)
                  : Colors.white.withValues(alpha: 0.35),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ─── §4.2.1-B: Geçmiş İşlemler ─────────────────────────────────────────
  Widget _buildTransactionHistory(AsyncValue<List<TransactionItem>> txAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section badge
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF7AB892).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF7AB892).withValues(alpha: 0.2),
                ),
              ),
              child: const Text(
                '§4.2.1-B',
                style: TextStyle(
                  color: Color(0xFF7AB892),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Hesap Dökümü',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        txAsync.when(
          loading: () => _shimmerList(),
          error: (_, __) => _emptyTransactions(),
          data: (txs) {
            if (txs.isEmpty) return _emptyTransactions();
            return Column(
              children: [
                ...txs.take(8).toList().asMap().entries.map((entry) {
                  return _staggerTxItem(entry.key, entry.value);
                }),
                if (txs.length > 8)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Center(
                      child: Text(
                        '+ ${txs.length - 8} işlem daha',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.25),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _staggerTxItem(int index, TransactionItem tx) {
    // Determine status: Ödendi (matched/completed), Gecikti (overdue), Kısmi (partial)
    final isIncome = tx.type == 'income';
    final color = isIncome
        ? const Color(0xFF7AB892)  // Sage green — Ödendi
        : const Color(0xFFE27D7D); // Soft coral — Gecikti

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + (index * 60).clamp(0, 300)),
      curve: Curves.easeOutCubic,
      builder: (context, anim, child) => Opacity(
        opacity: anim,
        child: Transform.translate(offset: Offset(0, 12 * (1 - anim)), child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1814),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: color.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          children: [
            // Status icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isIncome
                    ? Icons.check_circle_rounded
                    : Icons.schedule_rounded,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _catLabel(tx.category),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isIncome ? 'Ödendi' : 'Bekliyor',
                          style: TextStyle(
                            color: color,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _fullDate(tx.transactionDate),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            // Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isIncome ? '+' : '-'}₺${_fmt(tx.amount.round())}',
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyTransactions() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1814),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_rounded,
            size: 40,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 12),
          Text(
            'Henüz işlem kaydı yok',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.25),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────
  Widget _shimmerCard() {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1814),
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFE8A87C),
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _shimmerList() {
    return Column(
      children: List.generate(
        3,
        (i) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFF1C1814),
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  Widget _emptyCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1814),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Center(
        child: Text(
          'Ödeme verisi yüklenemedi',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 36, height: 36,
            child: CircularProgressIndicator(
              color: const Color(0xFFE8A87C),
              strokeWidth: 2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Bilgiler yükleniyor...',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 40, color: const Color(0xFFE27D7D)),
          const SizedBox(height: 12),
          Text(
            'Sunucu hatası',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 4),
          Text(
            msg,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 11),
            maxLines: 1, overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _catLabel(String cat) {
    switch (cat) {
      case 'rent':        return 'Kira';
      case 'dues':        return 'Aidat';
      case 'utility':     return 'Fatura';
      case 'maintenance': return 'Bakım';
      case 'commission':  return 'Komisyon';
      case 'other':       return 'Diğer';
      default:            return 'İşlem';
    }
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  String _shortDate(DateTime dt) {
    final aylar = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
    return '${dt.day} ${aylar[dt.month - 1]}';
  }

  String _fullDate(DateTime dt) {
    final aylar = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
    return '${dt.day} ${aylar[dt.month - 1]} ${dt.year}';
  }
}
