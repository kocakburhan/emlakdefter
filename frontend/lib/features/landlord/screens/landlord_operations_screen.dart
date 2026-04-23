import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../providers/landlord_provider.dart';

/// Bina Operasyonları — Ev Sahibinin mülklerindeki şeffaflık kayıtları
class LandlordOperationsScreen extends ConsumerWidget {
  const LandlordOperationsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(landlordProvider);

    if (state.isLoading && state.operations.isEmpty && state.tickets.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFD4A574)));
    }

    if (state.operations.isEmpty && state.tickets.isEmpty) {
      return _buildEmpty();
    }

    final totalCost = state.operations.fold(0, (sum, op) => sum + op.cost);
    final reflected = state.operations.where((op) => op.isReflectedToFinance).fold(0, (sum, op) => sum + op.cost);

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(landlordProvider.notifier).fetchOperations();
        await ref.read(landlordProvider.notifier).fetchTenantTickets();
      },
      color: const Color(0xFFD4A574),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Cards
            Row(
              children: [
                Expanded(child: _buildSummaryCard('Toplam', '₺${_fmt(totalCost)}', const Color(0xFFAD7B7B))),
                const SizedBox(width: 10),
                Expanded(child: _buildSummaryCard('Finansa Yansıyan', '₺${_fmt(reflected)}', const Color(0xFF6B8E6B))),
                const SizedBox(width: 10),
                Expanded(child: _buildSummaryCard('Bekleyen', '₺${_fmt(totalCost - reflected)}', const Color(0xFFD4A574))),
              ],
            ),
            const SizedBox(height: 24),

            // Info Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF8B7355).withValues(alpha:0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF8B7355).withValues(alpha:0.15)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.visibility_outlined, color: Color(0xFF8B7355), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Emlakçınızın yaptığı tüm harcamalar şeffaflık ilkesiyle burada görünür.',
                      style: TextStyle(color: const Color(0xFF8B7355).withValues(alpha:0.8), fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Operations List
            if (state.operations.isNotEmpty) ...[
              _buildSectionHeader('Bina Harcamaları', Icons.engineering_outlined, const Color(0xFFAD7B7B)),
              const SizedBox(height: 12),
              ...state.operations.map((op) => _buildOperationCard(op)),
            ],

            // §4.3.3 — Tenant Tickets Section
            if (state.tickets.isNotEmpty) ...[
              const SizedBox(height: 28),
              _buildSectionHeader('Kiracı Biletleri', Icons.support_agent_outlined, const Color(0xFF7B8FAD)),
              const SizedBox(height: 12),
              ...state.tickets.map((ticket) => _buildTicketCard(ticket)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.engineering_outlined, size: 56, color: AppColors.textSecondary.withValues(alpha:0.2)),
          const SizedBox(height: 16),
          const Text('Operasyon kaydı yok', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
          const SizedBox(height: 8),
          Text('Bina harcamaları burada şeffaf görünür', style: TextStyle(color: AppColors.textSecondary.withValues(alpha:0.5), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha:0.15)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: color.withValues(alpha:0.6), fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationCard(LandlordOperation op) {
    final isReflected = op.isReflectedToFinance;
    final dateStr = _formatDate(op.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isReflected
              ? const Color(0xFF6B8E6B).withValues(alpha:0.15)
              : const Color(0xFFD4A574).withValues(alpha:0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isReflected
                      ? const Color(0xFF6B8E6B).withValues(alpha:0.1)
                      : const Color(0xFFD4A574).withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isReflected ? Icons.check_circle_outline : Icons.pending_outlined,
                  color: isReflected ? const Color(0xFF6B8E6B) : const Color(0xFFD4A574),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      op.title,
                      style: const TextStyle(
                        color: AppColors.charcoal,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(op.propertyName, style: TextStyle(color: AppColors.textSecondary.withValues(alpha:0.6), fontSize: 11)),
                        const SizedBox(width: 8),
                        Text(dateStr, style: TextStyle(color: AppColors.textSecondary.withValues(alpha:0.5), fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₺${_fmt(op.cost)}',
                    style: const TextStyle(
                      color: AppColors.charcoal,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isReflected
                          ? const Color(0xFF6B8E6B).withValues(alpha:0.1)
                          : const Color(0xFFD4A574).withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isReflected ? 'Finansa Yansıdı' : 'Bekliyor',
                      style: TextStyle(
                        color: isReflected ? const Color(0xFF6B8E6B) : const Color(0xFFD4A574),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (op.description != null && op.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              op.description!,
              style: TextStyle(color: AppColors.textSecondary.withValues(alpha:0.7), fontSize: 13, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTicketCard(LandlordTenantTicket ticket) {
    final statusColor = _ticketStatusColor(ticket.status);
    final priorityColor = _ticketPriorityColor(ticket.priority);
    final dateStr = _formatDate(ticket.createdAt);

    return _ExpandableTicketCard(
      ticket: ticket,
      statusColor: statusColor,
      priorityColor: priorityColor,
      dateStr: dateStr,
    );
  }

  Color _ticketStatusColor(String status) {
    switch (status) {
      case 'open': return const Color(0xFFAD7B7B);
      case 'in_progress': return const Color(0xFF7B8FAD);
      case 'resolved': return const Color(0xFF6B8E6B);
      case 'closed': return const Color(0xFF8B7355);
      default: return const Color(0xFFD4A574);
    }
  }

  Color _ticketPriorityColor(String priority) {
    switch (priority) {
      case 'high': return const Color(0xFFAD7B7B);
      case 'medium': return const Color(0xFFD4A574);
      case 'low': return const Color(0xFF6B8E6B);
      default: return const Color(0xFF8B7355);
    }
  }

  String _formatDate(DateTime dt) {
    final aylar = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
    return '${dt.day.toString().padLeft(2, '0')} ${aylar[dt.month - 1]} ${dt.year}';
  }

  String _fmt(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }
}

// ─── Expandable Ticket Card — §4.3.3-A Tam Kronolojik Thread ─────────────────

class _ExpandableTicketCard extends StatefulWidget {
  final LandlordTenantTicket ticket;
  final Color statusColor;
  final Color priorityColor;
  final String dateStr;

  const _ExpandableTicketCard({
    required this.ticket,
    required this.statusColor,
    required this.priorityColor,
    required this.dateStr,
  });

  @override
  State<_ExpandableTicketCard> createState() => _ExpandableTicketCardState();
}

class _ExpandableTicketCardState extends State<_ExpandableTicketCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: widget.statusColor.withValues(alpha: 0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header — always visible
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: widget.priorityColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.headset_mic_outlined, color: widget.priorityColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.ticket.title,
                              style: const TextStyle(
                                color: AppColors.charcoal,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(widget.ticket.propertyName, style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.6), fontSize: 11)),
                                const SizedBox(width: 6),
                                Text('• Kapı ${widget.ticket.unitDoor}', style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5), fontSize: 11)),
                                const SizedBox(width: 6),
                                Text(widget.dateStr, style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5), fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        color: AppColors.textSecondary.withValues(alpha: 0.4),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: widget.statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _ticketStatusLabel(widget.ticket.status),
                          style: TextStyle(color: widget.statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.message_outlined, size: 12, color: AppColors.textSecondary.withValues(alpha: 0.4)),
                      const SizedBox(width: 3),
                      Text('${widget.ticket.messageCount}', style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5), fontSize: 11)),
                      if (widget.ticket.agentReplyCount > 0) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.verified_outlined, size: 12, color: AppColors.textSecondary.withValues(alpha: 0.4)),
                        const SizedBox(width: 3),
                        Text('${widget.ticket.agentReplyCount}', style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5), fontSize: 11)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Expanded Timeline — §4.3.3-A
          if (_expanded && widget.ticket.messages.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: AppColors.textSecondary.withValues(alpha: 0.08)),
                  const SizedBox(height: 8),
                  ...widget.ticket.messages.map((msg) => _buildTimelineMessage(msg)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimelineMessage(TicketMessageItem msg) {
    final isAgent = msg.isAgent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isAgent
                  ? const Color(0xFF6B8E6B).withValues(alpha: 0.15)
                  : const Color(0xFF7B8FAD).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isAgent ? Icons.support_agent : Icons.person,
              size: 12,
              color: isAgent ? const Color(0xFF6B8E6B) : const Color(0xFF7B8FAD),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        msg.senderName,
                        style: TextStyle(
                          color: isAgent ? const Color(0xFF6B8E6B) : const Color(0xFF7B8FAD),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatTime(msg.createdAt),
                        style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.4), fontSize: 10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    msg.content,
                    style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.8), fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _ticketStatusLabel(String status) {
    switch (status) {
      case 'open': return 'Açık';
      case 'in_progress': return 'İşlemde';
      case 'resolved': return 'Çözüldü';
      case 'closed': return 'Kapandı';
      default: return status;
    }
  }

  String _formatTime(DateTime dt) {
    final aylar = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
    return '${dt.day.toString().padLeft(2, '0')} ${aylar[dt.month - 1]} ${dt.year}';
  }
}
