import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import '../../../core/theme/colors.dart';
import '../../../core/network/api_client.dart';
import '../providers/support_provider.dart';
import '../screens/chat_window_screen.dart';
import '../providers/chat_provider.dart' hide ChatMessage;

/// PRD §4.1.7-B Talep Detay Görünümü + §4.1.7-C Action Bar
class TicketDetailSheet extends ConsumerStatefulWidget {
  final TicketModel ticket;
  const TicketDetailSheet({super.key, required this.ticket});

  @override
  ConsumerState<TicketDetailSheet> createState() => _TicketDetailSheetState();
}

class _TicketDetailSheetState extends ConsumerState<TicketDetailSheet> {
  final _msgController = TextEditingController();
  bool _isReplying = false;

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  Color get _statusColor {
    switch (widget.ticket.status) {
      case TicketStatus.open: return AppColors.error;
      case TicketStatus.inProgress: return AppColors.warning;
      case TicketStatus.resolved: return AppColors.success;
      case TicketStatus.closed: return AppColors.textSecondary;
    }
  }

  String get _statusLabel {
    switch (widget.ticket.status) {
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
    if (diff.inMinutes > 0) return '${diff.inMinutes}dk';
    return 'az önce';
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  // ─── Action Bar ────────────────────────────────────────────────────────────
  void _openChat() {
    Navigator.pop(context);
    // Chat ekranına git — mevcut _TicketChatInlineSheet yerine ChatWindowScreen aç (§4.1.7-C)
    _openChatWindowForTicket();
  }

  Future<void> _openChatWindowForTicket() async {
    // ticket'tan tenant user_id'yi çek
    final ticket = widget.ticket;
    String? tenantUserId;

    // ticket detail'dan reporter_user_id'yi al (async)
    try {
      final resp = await ApiClient.dio.get('/operations/tickets/${ticket.id}');
      if (resp.statusCode == 200 && resp.data != null) {
        tenantUserId = resp.data['reporter_user_id']?.toString();
      }
    } catch (e) {
      // fallback: tenant user id bulunamadı
    }

    if (tenantUserId == null || tenantUserId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kiracı kullanıcı ID\'si bulunamadı'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }

    // Chat conversation oluştur veya mevcut olanı al
    try {
      final convResp = await ApiClient.dio.post('/chat/conversations', data: {
        'client_user_id': tenantUserId,
      });
      if (convResp.statusCode == 200 || convResp.statusCode == 201) {
        final convData = convResp.data;
        final conversation = ChatConversation(
          id: convData['id'] ?? '',
          agencyId: convData['agency_id'] ?? '',
          agentUserId: convData['agent_user_id'] ?? '',
          clientUserId: convData['client_user_id'] ?? '',
          clientName: ticket.tenantName ?? 'Kiracı',
          clientRole: 'Kiracı',
          propertyName: ticket.location,
          lastMessage: null,
          lastMessageAt: null,
          unreadCount: 0,
          isArchived: convData['is_archived'] ?? false,
        );

        if (mounted) {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => ChatWindowScreen(conversation: conversation),
              transitionsBuilder: (_, anim, __, child) => SlideTransition(
                position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                    .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                child: child,
              ),
              transitionDuration: const Duration(milliseconds: 350),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sohbet açılamadı: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _sendReply() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    setState(() => _isReplying = true);
    try {
      await ref.read(supportProvider.notifier).replyToTicket(widget.ticket.id, text);
      _msgController.clear();
    } finally {
      if (mounted) setState(() => _isReplying = false);
    }
  }

  Future<void> _closeTicket() async {
    await ref.read(supportProvider.notifier).closeTicket(widget.ticket.id);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Talep çözüldü olarak işaretlendi'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _addToBuildingOps() async {
    Navigator.pop(context);

    final propertyId = widget.ticket.propertyId;
    if (propertyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bu talebe mülk bilgisi bağlı değil'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Kategori seçtir — §4.1.9 OperationCategory
    final selectedCategory = await _showCategorySheet();
    if (selectedCategory == null) return; // İptal edildi

    try {
      final resp = await ApiClient.dio.post('/building-logs', data: {
        'property_id': propertyId,
        'title': '[Destek Ticket] ${widget.ticket.title}',
        'description': widget.ticket.description,
        'is_reflected_to_finance': false,
        'category': selectedCategory,
      });

      if (resp.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Bina Operasyonlarına eklendi: ${widget.ticket.title}'),
              backgroundColor: AppColors.charcoal,
              action: SnackBarAction(
                label: 'Mali Rapor',
                textColor: Colors.white,
                onPressed: () {
                  // Mali Rapor ekranına yönlendir (opsiyonel)
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// §4.1.9 — Kategori seçim sheet'i
  static const _opCategories = [
    ('cleaning', 'Temizlik', Icons.cleaning_services_rounded, Color(0xFF4ECDC4)),
    ('elevator', 'Asansör', Icons.elevator_rounded, Color(0xFF9575CD)),
    ('electrical', 'Elektrik', Icons.electrical_services_rounded, Color(0xFFFFB800)),
    ('plumbing', 'Tesisat', Icons.plumbing_rounded, Color(0xFF5C6BC0)),
    ('painting', 'Boya / Tadilat', Icons.format_paint_rounded, Color(0xFFFF8A65)),
    ('landscaping', 'Bahçe / Peyzaj', Icons.grass_rounded, Color(0xFF66BB6A)),
    ('security', 'Güvenlik', Icons.security_rounded, Color(0xFFEF5350)),
    ('other', 'Diğer', Icons.build_rounded, Color(0xFF78909C)),
  ];

  Future<String?> _showCategorySheet() async {
    String? selected;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          height: MediaQuery.of(ctx).size.height * 0.55,
          decoration: const BoxDecoration(
            color: Color(0xFF0F0F18),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('İşlem Kategorisi',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Bu tamiratı hangi kategoride işlemek istiyorsunuz?',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13)),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 2.8,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _opCategories.length,
                  itemBuilder: (ctx, i) {
                    final (value, label, icon, color) = _opCategories[i];
                    final isSelected = selected == value;
                    return GestureDetector(
                      onTap: () => setSheetState(() => selected = value),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color.withValues(alpha: 0.18)
                              : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? color.withValues(alpha: 0.5)
                                : Colors.white.withValues(alpha: 0.06),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(icon, color: isSelected ? color : Colors.white.withValues(alpha: 0.4), size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                label,
                                style: TextStyle(
                                  color: isSelected ? color : Colors.white.withValues(alpha: 0.6),
                                  fontSize: 13, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                            ),
                            if (isSelected)
                              Icon(Icons.check_circle, color: color, size: 18),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Seç / İptal
              Container(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(ctx).viewInsets.bottom),
                decoration: BoxDecoration(
                  color: const Color(0xFF13131E),
                  border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: Text('İptal', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx, selected),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: selected != null
                                  ? [AppColors.charcoal, AppColors.charcoal.withValues(alpha: 0.8)]
                                  : [Colors.grey, Colors.grey],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              'Ekle',
                              style: TextStyle(
                                color: selected != null ? Colors.white : Colors.white.withValues(alpha: 0.4),
                                fontSize: 15, fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return selected;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final state = ref.watch(supportProvider);

    // Canlı ticket verisini al
    final liveTicket = (state.value ?? []).cast<TicketModel?>().firstWhere(
      (t) => t?.id == widget.ticket.id,
      orElse: () => widget.ticket,
    );

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F18),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Column(
          children: [
            // Handle bar
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // ─── Talep Künyesi (Header) ─────────────────────────────────────
                  SliverToBoxAdapter(
                    child: _buildTicketHeader(liveTicket ?? widget.ticket),
                  ),

                  // ─── Action Bar (PRD §4.1.7-C) ──────────────────────────────────
                  SliverToBoxAdapter(
                    child: _buildActionBar(liveTicket ?? widget.ticket),
                  ),

                  // ─── Açıklama + Medya (PRD §4.1.7-B) ────────────────────────────
                  if (widget.ticket.description != null && widget.ticket.description!.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _buildDescription(liveTicket ?? widget.ticket),
                    ),

                  // ─── Timeline (PRD §4.1.7-B) ─────────────────────────────────────
                  SliverToBoxAdapter(
                    child: _buildTimeline(liveTicket ?? widget.ticket),
                  ),

                  SliverToBoxAdapter(child: SizedBox(height: bottomInset + 100)),
                ],
              ),
            ),

            // ─── Yanıt Yaz Alanı (PRD §4.1.7-C) ────────────────────────────────────
            if (liveTicket?.status != TicketStatus.resolved &&
                liveTicket?.status != TicketStatus.closed)
              _buildReplyInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketHeader(TicketModel ticket) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_statusIcon, color: _statusColor, size: 14),
                    const SizedBox(width: 5),
                    Text(_statusLabel,
                        style: TextStyle(color: _statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                _timeAgo(ticket.createdAt),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            ticket.title,
            style: const TextStyle(
              color: Colors.white, fontSize: 20,
              fontWeight: FontWeight.bold, letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildHeaderChip(Icons.person_outline, ticket.tenantName ?? 'Kiracı'),
              if (ticket.location != null) ...[
                const SizedBox(width: 10),
                _buildHeaderChip(Icons.home_outlined, ticket.location!),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.access_time, size: 13, color: Colors.white.withValues(alpha: 0.3)),
              const SizedBox(width: 5),
              Text(
                'Açılış: ${_formatDate(ticket.createdAt)}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData get _statusIcon {
    switch (widget.ticket.status) {
      case TicketStatus.open: return Icons.warning_rounded;
      case TicketStatus.inProgress: return Icons.hourglass_top_rounded;
      case TicketStatus.resolved: return Icons.check_circle_rounded;
      case TicketStatus.closed: return Icons.check_circle_outline_rounded;
    }
  }

  Widget _buildHeaderChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.5)),
          const SizedBox(width: 5),
          Text(text,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12)),
        ],
      ),
    );
  }

  // ─── Action Bar (§4.1.7-C) ────────────────────────────────────────────────
  Widget _buildActionBar(TicketModel ticket) {
    final isResolved = ticket.status == TicketStatus.resolved || ticket.status == TicketStatus.closed;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action bar label
          Text('EYLEM VE İLETİŞİM',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 10, fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
              )),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _ActionButton(
                icon: Icons.chat_bubble_outline,
                label: 'Yanıt Yaz',
                color: AppColors.charcoal,
                onTap: _openChat,
              )),
              const SizedBox(width: 10),
              Expanded(child: _ActionButton(
                icon: Icons.check_circle_outline,
                label: 'Giderildi',
                color: AppColors.success,
                onTap: isResolved ? null : _closeTicket,
                enabled: !isResolved,
              )),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _ActionButton(
                icon: Icons.person,
                label: 'Direkt Mesaj',
                color: const Color(0xFF25D366),
                onTap: _openChatWindowForTicket,  // ✅ Düzeltildi — §4.1.7-C: uygulama içi sohbet açılır
              )),
              const SizedBox(width: 10),
              Expanded(child: _ActionButton(
                icon: Icons.build_outlined,
                label: 'Bina Operasyonu',
                color: AppColors.warning,
                onTap: _addToBuildingOps,
              )),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Açıklama ─────────────────────────────────────────────────────────────
  Widget _buildDescription(TicketModel ticket) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TALEP DETAYI',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 10, fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
              )),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Text(
              ticket.description ?? '',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 14, height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Timeline (§4.1.7-B) ──────────────────────────────────────────────────
  Widget _buildTimeline(TicketModel ticket) {
    final messages = ticket.messages;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AKSİYON GEÇMİŞİ',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 10, fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
              )),
          const SizedBox(height: 12),
          if (messages.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  'Henüz mesaj yok',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
                ),
              ),
            )
          else
            ...List.generate(messages.length, (i) => _buildTimelineItem(messages[i], i, messages.length)),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(ChatMessage msg, int index, int total) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + index * 60),
      curve: Curves.easeOutCubic,
      builder: (context, anim, child) => Opacity(
        opacity: anim,
        child: Transform.translate(offset: Offset(-8 * (1 - anim), 0), child: child),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline dot + line
          Column(
            children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  color: msg.isMe ? AppColors.charcoal : AppColors.warning,
                  shape: BoxShape.circle,
                ),
              ),
              if (index < total - 1)
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: (msg.isMe ? AppColors.charcoal : AppColors.warning).withValues(alpha: 0.12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        msg.isMe ? 'Emlakçı Yanıtı' : (widget.ticket.tenantName ?? 'Kiracı'),
                        style: TextStyle(
                          color: msg.isMe ? AppColors.charcoal : AppColors.warning,
                          fontSize: 11, fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _formatDate(msg.time),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.25),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(msg.text,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13, height: 1.5,
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Reply Input ──────────────────────────────────────────────────────────
  Widget _buildReplyInput() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: const Color(0xFF13131E),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Talebe yanıt yazın...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _isReplying ? null : _sendReply,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isReplying
                      ? [Colors.grey, Colors.grey]
                      : [AppColors.charcoal.withValues(alpha: 0.85), AppColors.charcoal],
                ),
                shape: BoxShape.circle,
                boxShadow: _isReplying
                    ? null
                    : [BoxShadow(color: AppColors.charcoal.withValues(alpha: 0.3), blurRadius: 8)],
              ),
              child: _isReplying
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Action Button Widget ─────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool enabled;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: enabled
              ? color.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: enabled
                ? color.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon, size: 18,
              color: enabled
                  ? color
                  : Colors.white.withValues(alpha: 0.2),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: enabled
                    ? color
                    : Colors.white.withValues(alpha: 0.2),
                fontSize: 12, fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Inline Chat Sheet (WhatsApp-style) ───────────────────────────────────────
class _TicketChatInlineSheet extends ConsumerStatefulWidget {
  final TicketModel ticket;
  const _TicketChatInlineSheet({required this.ticket});

  @override
  ConsumerState<_TicketChatInlineSheet> createState() => _TicketChatInlineSheetState();
}

class _TicketChatInlineSheetState extends ConsumerState<_TicketChatInlineSheet> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMsg() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    ref.read(supportProvider.notifier).replyToTicket(widget.ticket.id, text);
    _msgController.clear();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(supportProvider);
    final ticket = (state.value ?? []).cast<TicketModel?>().firstWhere(
      (t) => t?.id == widget.ticket.id,
      orElse: () => widget.ticket,
    );

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F18),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.charcoal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.chat_bubble_outline, color: AppColors.charcoal, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.ticket.title,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          widget.ticket.tenantName ?? 'Kiracı',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            // Messages
            Expanded(
              child: (ticket?.messages ?? widget.ticket.messages).isEmpty
                  ? Center(
                      child: Text(
                        'Henüz mesaj yok.\nİlk mesajı siz başlatın!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
                      ),
                    )
                  : ListView.separated(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: (ticket?.messages ?? widget.ticket.messages).length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, idx) {
                        final msg = (ticket?.messages ?? widget.ticket.messages)[idx];
                        return Align(
                          alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.72,
                            ),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: msg.isMe
                                  ? AppColors.charcoal.withValues(alpha: 0.18)
                                  : Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: msg.isMe ? const Radius.circular(16) : const Radius.circular(4),
                                bottomRight: msg.isMe ? const Radius.circular(4) : const Radius.circular(16),
                              ),
                              border: Border.all(
                                color: msg.isMe
                                    ? AppColors.charcoal.withValues(alpha: 0.3)
                                    : Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!msg.isMe)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      widget.ticket.tenantName ?? 'Kiracı',
                                      style: const TextStyle(
                                        color: AppColors.charcoal, fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                Text(msg.text, style: const TextStyle(color: Colors.white, fontSize: 14)),
                                const SizedBox(height: 5),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    '${msg.time.hour.toString().padLeft(2, '0')}:${msg.time.minute.toString().padLeft(2, '0')}',
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            // Input
            Container(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.of(context).viewInsets.bottom),
              decoration: BoxDecoration(
                color: const Color(0xFF13131E),
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Mesaj yazın...',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _sendMsg,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.charcoal.withValues(alpha: 0.85), AppColors.charcoal],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: AppColors.charcoal.withValues(alpha: 0.3), blurRadius: 8)],
                      ),
                      child: const Icon(Icons.send, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
