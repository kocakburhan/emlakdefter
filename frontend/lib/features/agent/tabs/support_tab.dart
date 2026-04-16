import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../providers/support_provider.dart';
import '../widgets/ticket_detail_sheet.dart';

/// Destek Yönetimi Tab — PRD §4.1.7
/// 3 sekme: Açık / İşlemde / Çözüldü
/// Premium dark tema + staggered animasyonlar
class SupportTab extends ConsumerStatefulWidget {
  const SupportTab({super.key});

  @override
  ConsumerState<SupportTab> createState() => _SupportTabState();
}

class _SupportTabState extends ConsumerState<SupportTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(supportProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      body: NestedScrollView(
        physics: const BouncingScrollPhysics(),
        headerSliverBuilder: (context, innerBoxScrolled) => [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              tabController: _tabController,
              tabCounts: _getTabCounts(state),
            ),
          ),
        ],
        body: state.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          ),
          error: (e, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                const SizedBox(height: 12),
                Text('Hata: $e', style: const TextStyle(color: AppColors.textBody)),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => ref.read(supportProvider.notifier).refresh(),
                  child: const Text('Tekrar dene'),
                ),
              ],
            ),
          ),
          data: (tickets) => TabBarView(
            controller: _tabController,
            physics: const BouncingScrollPhysics(),
            children: [
              _buildTicketList(tickets.where((t) => t.status == TicketStatus.open).toList(), 'open'),
              _buildTicketList(tickets.where((t) => t.status == TicketStatus.inProgress).toList(), 'inProgress'),
              _buildTicketList(tickets.where((t) => t.status == TicketStatus.resolved || t.status == TicketStatus.closed).toList(), 'resolved'),
            ],
          ),
        ),
      ),
    );
  }

  List<int> _getTabCounts(AsyncValue<List<TicketModel>> state) {
    return state.whenOrNull(
      data: (tickets) => [
        tickets.where((t) => t.status == TicketStatus.open).length,
        tickets.where((t) => t.status == TicketStatus.inProgress).length,
        tickets.where((t) => t.status == TicketStatus.resolved || t.status == TicketStatus.closed).length,
      ],
    ) ?? [0, 0, 0];
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, anim, child) => Opacity(
              opacity: anim,
              child: Transform.translate(offset: Offset(0, 10 * (1 - anim)), child: child),
            ),
            child: const Text('DESTEK',
                style: TextStyle(
                  color: Colors.white, fontSize: 11,
                  fontWeight: FontWeight.w700, letterSpacing: 2.5,
                )),
          ),
          const SizedBox(height: 4),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, anim, child) => Opacity(
              opacity: anim,
              child: Transform.translate(offset: Offset(0, 10 * (1 - anim)), child: child),
            ),
            child: const Text('Talep Yönetimi',
                style: TextStyle(
                  color: Colors.white, fontSize: 28,
                  fontWeight: FontWeight.bold, letterSpacing: -0.5,
                )),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTicketList(List<TicketModel> tickets, String tab) {
    if (tickets.isEmpty) {
      return _buildEmptyState(tab);
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      itemCount: tickets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _staggerCard(index, tickets[index]),
    );
  }

  Widget _staggerCard(int index, TicketModel ticket) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + (index * 50).clamp(0, 300)),
      curve: Curves.easeOutCubic,
      builder: (context, anim, child) => Opacity(
        opacity: anim,
        child: Transform.translate(offset: Offset(0, 20 * (1 - anim)), child: child),
      ),
      child: _TicketCard(ticket: ticket),
    );
  }

  Widget _buildEmptyState(String tab) {
    final configs = {
      'open': ('Hiç açık talep yok', 'Yeni talepler burada görünür', Icons.check_circle_outline, AppColors.success),
      'inProgress': ('İşlemde talep yok', 'Çözüme kavuşturulmayı bekleyen talep yok', Icons.hourglass_empty, AppColors.warning),
      'resolved': ('Henüz çözülen talep yok', 'Kapanan talepler burada görünür', Icons. archive_outlined, AppColors.textBody),
    };
    final cfg = configs[tab]!;
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, anim, child) => Opacity(
          opacity: anim,
          child: Transform.scale(scale: 0.8 + 0.2 * anim, child: child),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(cfg.$3, size: 64, color: cfg.$4.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(cfg.$1,
                style: const TextStyle(
                  color: Colors.white, fontSize: 18,
                  fontWeight: FontWeight.bold,
                )),
            const SizedBox(height: 6),
            Text(cfg.$2,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ─── Tab Bar Delegate ─────────────────────────────────────────────────────────
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController tabController;
  final List<int> tabCounts;

  _TabBarDelegate({required this.tabController, required this.tabCounts});

  @override
  double get minExtent => 56;

  @override
  double get maxExtent => 56;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFF0D0D14),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: TabBar(
          controller: tabController,
          indicator: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(12),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.4),
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          tabs: [
            _buildTab('Açık', AppColors.error, tabCounts.isNotEmpty ? tabCounts[0] : 0),
            _buildTab('İşlemde', AppColors.warning, tabCounts.length > 1 ? tabCounts[1] : 0),
            _buildTab('Çözüldü', AppColors.success, tabCounts.length > 2 ? tabCounts[2] : 0),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, Color color, int count) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count',
                  style: TextStyle(
                    color: color, fontSize: 10, fontWeight: FontWeight.bold,
                  )),
            ),
          ],
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) =>
      tabController != oldDelegate.tabController || tabCounts != oldDelegate.tabCounts;
}

// ─── Ticket Card ──────────────────────────────────────────────────────────────
class _TicketCard extends StatelessWidget {
  final TicketModel ticket;

  const _TicketCard({required this.ticket});

  Color get _statusColor {
    switch (ticket.status) {
      case TicketStatus.open: return AppColors.error;
      case TicketStatus.inProgress: return AppColors.warning;
      case TicketStatus.resolved: return AppColors.success;
      case TicketStatus.closed: return AppColors.textBody;
    }
  }

  IconData get _statusIcon {
    switch (ticket.status) {
      case TicketStatus.open: return Icons.warning_rounded;
      case TicketStatus.inProgress: return Icons.hourglass_top_rounded;
      case TicketStatus.resolved: return Icons.check_circle_rounded;
      case TicketStatus.closed: return Icons.check_circle_outline_rounded;
    }
  }

  String get _statusLabel {
    switch (ticket.status) {
      case TicketStatus.open: return 'Açık';
      case TicketStatus.inProgress: return 'İşlemde';
      case TicketStatus.resolved: return 'Çözüldü';
      case TicketStatus.closed: return 'Kapalı';
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}gün önce';
    if (diff.inHours > 0) return '${diff.inHours}saat önce';
    if (diff.inMinutes > 0) return '${diff.inMinutes}dk önce';
    return 'az önce';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openDetailSheet(context, ticket),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _statusColor.withValues(alpha: ticket.status == TicketStatus.open ? 0.35 : 0.12),
            width: ticket.status == TicketStatus.open ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst satır: ikon + başlık + badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_statusIcon, color: _statusColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ticket.title,
                        style: const TextStyle(
                          color: Colors.white, fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _timeAgo(ticket.createdAt),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _statusLabel,
                    style: TextStyle(color: _statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Kiracı + Daire satırı
            Row(
              children: [
                Icon(Icons.person, size: 14, color: Colors.white.withValues(alpha: 0.4)),
                const SizedBox(width: 5),
                Text(
                  ticket.tenantName ?? 'Kiracı',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12),
                ),
                if (ticket.location != null) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.home, size: 14, color: Colors.white.withValues(alpha: 0.4)),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      ticket.location!,
                      style: TextStyle(color: AppColors.accent.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),

            // Son mesaj özeti (varsa)
            if (ticket.messages.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 12,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        ticket.messages.last.text,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 11,
                        ),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _timeAgo(ticket.messages.last.time),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openDetailSheet(BuildContext context, TicketModel ticket) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TicketDetailSheet(ticket: ticket),
    );
  }
}
