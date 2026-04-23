import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/colors.dart';
import '../providers/support_provider.dart';
import '../widgets/ticket_detail_sheet.dart';

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
      backgroundColor: AppColors.background,
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
            child: CircularProgressIndicator(color: AppColors.charcoal),
          ),
          error: (e, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                const SizedBox(height: 12),
                Text('Hata: $e', style: Theme.of(context).textTheme.bodyMedium),
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
          Text(
            'DESTEK',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.slateGray,
                  letterSpacing: 2,
                ),
          )
              .animate()
              .fadeIn(duration: 400.ms),
          const SizedBox(height: 4),
          Text(
            'Talep Yönetimi',
            style: Theme.of(context).textTheme.headlineLarge,
          )
              .animate()
              .fadeIn(delay: 100.ms, duration: 400.ms)
              .slideX(begin: -0.05, end: 0, delay: 100.ms, duration: 400.ms),
          const SizedBox(height: 16),
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
      itemBuilder: (context, index) => _TicketCard(ticket: tickets[index], index: index),
    );
  }

  Widget _buildEmptyState(String tab) {
    final configs = {
      'open': ('Hiç açık talep yok', 'Yeni talepler burada görünür', Icons.check_circle_outline, AppColors.success),
      'inProgress': ('İşlemde talep yok', 'Bekleyen talep yok', Icons.hourglass_empty, AppColors.warning),
      'resolved': ('Henüz çözülen talep yok', 'Kapanan talepler burada görünür', Icons.archive_outlined, AppColors.textTertiary),
    };
    final cfg = configs[tab]!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Icon(cfg.$3, size: 48, color: cfg.$4),
          )
              .animate()
              .scale(
                begin: const Offset(0.8, 0.8),
                end: const Offset(1.0, 1.0),
                duration: 400.ms,
              )
              .fadeIn(duration: 400.ms),
          const SizedBox(height: 16),
          Text(
            cfg.$1,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          )
              .animate()
              .fadeIn(delay: 100.ms, duration: 400.ms),
          const SizedBox(height: 6),
          Text(
            cfg.$2,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                ),
            textAlign: TextAlign.center,
          )
              .animate()
              .fadeIn(delay: 200.ms, duration: 400.ms),
        ],
      ),
    );
  }
}

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
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: TabBar(
          controller: tabController,
          indicator: BoxDecoration(
            color: AppColors.charcoal,
            borderRadius: BorderRadius.circular(12),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
          unselectedLabelStyle: Theme.of(context).textTheme.labelMedium,
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
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
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

class _TicketCard extends StatelessWidget {
  final TicketModel ticket;
  final int index;

  const _TicketCard({required this.ticket, required this.index});

  Color get _statusColor {
    switch (ticket.status) {
      case TicketStatus.open:
        return AppColors.error;
      case TicketStatus.inProgress:
        return AppColors.warning;
      case TicketStatus.resolved:
        return AppColors.success;
      case TicketStatus.closed:
        return AppColors.textTertiary;
    }
  }

  IconData get _statusIcon {
    switch (ticket.status) {
      case TicketStatus.open:
        return Icons.warning_rounded;
      case TicketStatus.inProgress:
        return Icons.hourglass_top_rounded;
      case TicketStatus.resolved:
        return Icons.check_circle_rounded;
      case TicketStatus.closed:
        return Icons.check_circle_outline_rounded;
    }
  }

  String get _statusLabel {
    switch (ticket.status) {
      case TicketStatus.open:
        return 'Açık';
      case TicketStatus.inProgress:
        return 'İşlemde';
      case TicketStatus.resolved:
        return 'Çözüldü';
      case TicketStatus.closed:
        return 'Kapalı';
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _statusColor.withValues(alpha: ticket.status == TicketStatus.open ? 0.3 : 0.15),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.1),
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
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _timeAgo(ticket.createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textTertiary,
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _statusLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: _statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.person, size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 5),
                Text(
                  ticket.tenantName ?? 'Kiracı',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                if (ticket.location != null) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.home, size: 14, color: AppColors.textTertiary),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      ticket.location!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.charcoal,
                            fontWeight: FontWeight.w500,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            if (ticket.messages.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 12, color: AppColors.textTertiary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        ticket.messages.last.text,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _timeAgo(ticket.messages.last.time),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textTertiary,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: 50 * index),
          duration: 300.ms,
        )
        .slideX(
          begin: 0.05,
          end: 0,
          delay: Duration(milliseconds: 50 * index),
          duration: 300.ms,
          curve: Curves.easeOut,
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
