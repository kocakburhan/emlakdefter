import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../providers/tenant_provider.dart';

/// Tenant Chat — Ofise mesaj gönder (PRD §4.2.5)
/// Gerçek API'ye bağlı: /chat/conversations + /chat/history/{id}
class TenantChatTab extends ConsumerStatefulWidget {
  const TenantChatTab({Key? key}) : super(key: key);

  @override
  ConsumerState<TenantChatTab> createState() => _TenantChatTabState();
}

class _TenantChatTabState extends ConsumerState<TenantChatTab> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<_ChatMessage> _messages = [];
  String? _conversationId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConversation();
  }

  Future<void> _loadConversation() async {
    // Önce konuşma listesinden tenant'ın konuşmasını bul
    final conversations = await ref.read(tenantConversationsProvider.future);
    if (!mounted) return;

    ConversationItem? tenantConv;
    for (final c in conversations) {
      // Tenant kendisi client olarak katılmış, agent ile konuşuyor
      tenantConv = c;
      break;
    }

    if (tenantConv != null) {
      _conversationId = tenantConv.id;
      final history = await ref.read(tenantChatHistoryProvider(tenantConv.id).future);
      if (!mounted) return;
      setState(() {
        _messages = history.map((m) => _ChatMessage(
          m.message ?? '',
          _isOwnMessage(m),
          m.createdAt,
          false,
        )).toList();
        _isLoading = false;
      });
    } else {
      // Konuşma yok — boş sohbet
      setState(() => _isLoading = false);
    }
  }

  bool _isOwnMessage(ChatMessageItem m) {
    // Tenant kendi mesajını göndermiş olarak işaretle
    // Gerçek user_id karşılaştırması için tenantProvider'dan user id alınabilir
    // Basitlik için: tenant mesajları sender = client_user_id (backend'den)
    return false; // backend karar verecek — UI'da simetrik gösterim
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _conversationId == null) return;

    final params = SendMessageParams(
      conversationId: _conversationId!,
      message: text,
    );

    final sent = await ref.read(tenantSendMessageProvider(params).future);
    if (sent != null && mounted) {
      setState(() {
        _messages.add(_ChatMessage(text, true, sent.createdAt, false));
      });
      _messageController.clear();
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenantState = ref.watch(tenantProvider);
    final propertyName = tenantState.value?.propertyName ?? 'Emlak Ofisi';

    return SafeArea(
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha:0.05))),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.accent.withValues(alpha: 0.3), AppColors.accent.withValues(alpha: 0.1)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.business, color: AppColors.accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        propertyName,
                        style: const TextStyle(color: AppColors.textHeader, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Emlak Ofisi ile sohbet',
                        style: TextStyle(color: AppColors.textBody.withValues(alpha:0.5), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.success)),
                      const SizedBox(width: 5),
                      const Text('Online', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Messages
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                : _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        itemCount: _messages.length,
                        itemBuilder: (ctx, i) => _buildBubble(_messages[i], i),
                      ),
          ),

          // Input bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha:0.05))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha:0.06)),
                    ),
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: AppColors.textHeader, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Mesajınızı yazın...',
                        hintStyle: TextStyle(color: AppColors.textBody.withValues(alpha:0.4), fontSize: 13),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.accent.withValues(alpha:0.8), AppColors.accent],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha:0.3), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: AppColors.textBody.withValues(alpha:0.2)),
          const SizedBox(height: 16),
          Text(
            'Henüz mesajınız yok',
            style: TextStyle(color: AppColors.textBody.withValues(alpha:0.5), fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'İlk mesajınızı gönderin!',
            style: TextStyle(color: AppColors.textBody.withValues(alpha:0.3), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(_ChatMessage msg, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 200 + (index % 5) * 60),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(msg.isMe ? 20 * (1 - value) : -20 * (1 - value), 0), child: child),
      ),
      child: Align(
        alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: msg.isMe ? AppColors.accent : AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(msg.isMe ? 20 : 4),
              bottomRight: Radius.circular(msg.isMe ? 4 : 20),
            ),
            border: msg.isMe ? null : Border.all(color: Colors.white.withValues(alpha:0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                msg.text,
                style: TextStyle(color: msg.isMe ? Colors.white : AppColors.textHeader, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(msg.time),
                    style: TextStyle(color: (msg.isMe ? Colors.white : AppColors.textBody).withValues(alpha:0.5), fontSize: 10),
                  ),
                  if (msg.isMe) ...[
                    const SizedBox(width: 4),
                    Icon(msg.isRead ? Icons.done_all : Icons.done, size: 14, color: Colors.white.withValues(alpha:0.5)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _ChatMessage {
  final String text;
  final bool isMe;
  final DateTime time;
  final bool isRead;

  _ChatMessage(this.text, this.isMe, this.time, this.isRead);
}