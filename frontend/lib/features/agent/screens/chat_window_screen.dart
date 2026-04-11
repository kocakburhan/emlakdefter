import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../providers/chat_provider.dart';

/// Sohbet Penceresi — WhatsApp tarzı mesaj balonları, düzenle, sil, 30 sn geri al
class ChatWindowScreen extends ConsumerStatefulWidget {
  final ChatConversation conversation;

  const ChatWindowScreen({Key? key, required this.conversation}) : super(key: key);

  @override
  ConsumerState<ChatWindowScreen> createState() => _ChatWindowScreenState();
}

class _ChatWindowScreenState extends ConsumerState<ChatWindowScreen>
    with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _isComposing = false;
  ChatMessage? _replyTo;
  ChatMessage? _editingMessage;
  ChatMessage? _pendingDelete;
  Timer? _deleteUndoTimer;
  String? _deleteUndoMessageId;
  late AnimationController _inputAnimController;
  late Animation<double> _inputHeightAnim;

  @override
  void initState() {
    super.initState();
    _inputAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _inputHeightAnim = CurvedAnimation(
      parent: _inputAnimController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _inputAnimController.dispose();
    _deleteUndoTimer?.cancel();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  void _onTextChanged(String text) {
    setState(() => _isComposing = text.trim().isNotEmpty);
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    // Düzenleme modundaysa
    if (_editingMessage != null) {
      await _confirmEdit(text);
      return;
    }

    final success = await ref.read(chatProvider.notifier).sendMessage(text);
    if (success) {
      _textController.clear();
      setState(() {
        _isComposing = false;
        _replyTo = null;
      });
      _scrollToBottom();
    }
  }

  Future<void> _confirmEdit(String text) async {
    if (_editingMessage == null) return;
    final success = await ref.read(chatProvider.notifier).editMessage(_editingMessage!.id, text);
    if (success) {
      _textController.clear();
      setState(() => _editingMessage = null);
    }
  }

  void _startEdit(ChatMessage msg) {
    setState(() {
      _editingMessage = msg;
      _textController.text = msg.message ?? '';
      _isComposing = true;
    });
    _focusNode.requestFocus();
  }

  void _cancelEdit() {
    setState(() {
      _editingMessage = null;
      _textController.clear();
      _isComposing = false;
    });
  }

  Future<void> _deleteMessage(ChatMessage msg) async {
    _deleteUndoTimer?.cancel();
    setState(() {
      _pendingDelete = msg;
      _deleteUndoMessageId = msg.id;
    });

    // Start 30-second undo timer
    _deleteUndoTimer = Timer(const Duration(seconds: 30), () {
      if (mounted && _pendingDelete?.id == msg.id) {
        ref.read(chatProvider.notifier).deleteMessage(msg.id);
        setState(() => _pendingDelete = null);
      }
    });

    // Show undo snackbar
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_editingMessage != null
              ? 'Mesaj silindi'
              : 'Mesaj silindi — 30 sn içinde geri alınabilir',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
          backgroundColor: AppColors.textHeader,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          duration: const Duration(seconds: 30),
          action: SnackBarAction(
            label: 'Geri Al',
            textColor: AppColors.accent,
            onPressed: _undoDelete,
          ),
        ),
      );
    }
  }

  void _undoDelete() {
    _deleteUndoTimer?.cancel();
    setState(() => _pendingDelete = null);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Silme işlemi geri alındı', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _confirmDelete() {
    if (_pendingDelete != null) {
      ref.read(chatProvider.notifier).deleteMessage(_pendingDelete!.id);
      setState(() => _pendingDelete = null);
    }
    ScaffoldMessenger.of(context).clearSnackBars();
  }

  void _setReplyTo(ChatMessage msg) {
    setState(() => _replyTo = msg);
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider);
    final messages = state.messages;

    // Don't show pending delete message
    final visibleMessages = _pendingDelete != null
        ? messages.where((m) => m.id != _pendingDelete!.id).toList()
        : messages;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Custom App Bar
            _buildAppBar(),

            // Reply/Edit indicator
            if (_editingMessage != null) _buildEditIndicator(),
            if (_replyTo != null && _editingMessage == null) _buildReplyIndicator(),

            // Messages
            Expanded(
              child: state.isLoadingMessages
                  ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                  : visibleMessages.isEmpty
                      ? _buildEmptyChat()
                      : ListView.builder(
                          controller: _scrollController,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                          itemCount: visibleMessages.length + 1,
                          itemBuilder: (ctx, i) {
                            if (i == visibleMessages.length) return const SizedBox(height: 60);
                            final msg = visibleMessages[i];
                            final prevMsg = i > 0 ? visibleMessages[i - 1] : null;
                            final isFirstInGroup = prevMsg == null || prevMsg.senderUserId != msg.senderUserId;
                            return _buildMessageBubble(msg, isFirstInGroup);
                          },
                        ),
            ),

            // Input Bar
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              ref.read(chatProvider.notifier).clearActiveConversation();
              context.pop();
            },
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back, size: 20, color: AppColors.textHeader),
            ),
          ),
          const SizedBox(width: 8),
          // Avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.accent.withOpacity(0.7), AppColors.accent.withOpacity(0.4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                (widget.conversation.clientName ?? '?')[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.conversation.clientName ?? 'Bilinmeyen',
                  style: const TextStyle(
                    color: AppColors.textHeader,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.conversation.clientRole != null)
                  Text(
                    widget.conversation.clientRole!,
                    style: TextStyle(
                      color: AppColors.textBody.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          if (widget.conversation.propertyName != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.conversation.propertyName!,
                style: const TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEditIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.warning.withOpacity(0.1),
      child: Row(
        children: [
          const Icon(Icons.edit_outlined, color: AppColors.warning, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Mesajı düzenliyorsunuz',
              style: TextStyle(color: AppColors.warning.withOpacity(0.8), fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: _cancelEdit,
            child: const Text('İptal', style: TextStyle(color: AppColors.warning, fontSize: 13)),
          ),
          ElevatedButton(
            onPressed: () => _confirmEdit(_textController.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Kaydet', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          left: BorderSide(color: AppColors.accent, width: 3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _replyTo!.senderName ?? 'Mesaj',
                  style: const TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  _replyTo!.message ?? '',
                  style: TextStyle(color: AppColors.textBody.withOpacity(0.7), fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _replyTo = null),
            icon: const Icon(Icons.close, size: 18, color: AppColors.textBody),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: AppColors.accent.withOpacity(0.3),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Henüz mesaj yok',
            style: TextStyle(color: AppColors.textHeader, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'İlk mesajı siz gönderin',
            style: TextStyle(color: AppColors.textBody.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isFirstInGroup) {
    final isMine = msg.isMine;
    final now = DateTime.now();
    final elapsed = now.difference(msg.createdAt);
    final canEdit = isMine && elapsed.inMinutes < 15;
    final canDelete = isMine && elapsed.inSeconds < 30;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, 10 * (1 - value)), child: child),
      ),
      child: Column(
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (isFirstInGroup)
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 4),
              child: Text(
                msg.senderName ?? (isMine ? 'Siz' : 'Karşı taraf'),
                style: TextStyle(
                  color: AppColors.textBody.withOpacity(0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Row(
            mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMine) const SizedBox(width: 36),
              if (isMine) const Spacer(flex: 1),

              // Bubble
              Flexible(
                flex: 5,
                child: GestureDetector(
                  onLongPress: () => _showMessageActions(msg, canEdit, canDelete),
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.72,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isMine
                          ? const Color(0xFF2D5A3D)
                          : AppColors.surface,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isMine ? 20 : 4),
                        bottomRight: Radius.circular(isMine ? 4 : 20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isMine ? Colors.black : Colors.black).withOpacity(0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_replyTo != null && _editingMessage?.id == msg.id) ...[
                          Container(
                            padding: const EdgeInsets.only(bottom: 8),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(color: AppColors.accent, width: 3),
                              ),
                            ),
                            child: Text(
                              _replyTo!.message ?? '',
                              style: TextStyle(
                                color: AppColors.textBody.withOpacity(0.5),
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        Text(
                          msg.message ?? '',
                          style: TextStyle(
                            color: isMine ? Colors.white : AppColors.textHeader,
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatTime(msg.createdAt),
                              style: TextStyle(
                                color: (isMine ? Colors.white : AppColors.textBody).withOpacity(0.5),
                                fontSize: 10,
                              ),
                            ),
                            if (msg.isEdited) ...[
                              const SizedBox(width: 4),
                              Text(
                                '(düzenlendi)',
                                style: TextStyle(
                                  color: (isMine ? Colors.white : AppColors.textBody).withOpacity(0.4),
                                  fontSize: 10,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              if (isMine) const Spacer(flex: 1),
              if (isMine) const SizedBox(width: 36),
            ],
          ),
        ],
      ),
    );
  }

  void _showMessageActions(ChatMessage msg, bool canEdit, bool canDelete) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.textBody.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            if (canEdit)
              _buildActionTile(
                Icons.edit_outlined,
                'Mesajı Düzenle',
                AppColors.warning,
                () {
                  Navigator.pop(ctx);
                  _startEdit(msg);
                },
              ),
            if (canDelete) ...[
              if (canEdit) const SizedBox(height: 12),
              _buildActionTile(
                Icons.delete_outline,
                'Mesajı Sil (30 sn geri alınabilir)',
                AppColors.error,
                () {
                  Navigator.pop(ctx);
                  _deleteMessage(msg);
                },
              ),
            ],
            const SizedBox(height: 12),
            _buildActionTile(
              Icons.reply_outlined,
              'Yanıtla',
              AppColors.accent,
              () {
                Navigator.pop(ctx);
                _setReplyTo(msg);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(IconData icon, String label, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Attachment button
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.attach_file, color: AppColors.textBody.withOpacity(0.5), size: 22),
          ),
          const SizedBox(width: 10),

          // Text field
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isComposing
                      ? AppColors.accent.withOpacity(0.4)
                      : Colors.white.withOpacity(0.05),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      onChanged: _onTextChanged,
                      onSubmitted: (_) => _sendMessage(),
                      maxLines: 4,
                      minLines: 1,
                      style: const TextStyle(color: AppColors.textHeader, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: _editingMessage != null
                            ? 'Mesajı düzenleyin...'
                            : 'Mesaj yazın...',
                        hintStyle: TextStyle(color: AppColors.textBody.withOpacity(0.4)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 8),
                    child: Icon(
                      Icons.emoji_emotions_outlined,
                      color: AppColors.textBody.withOpacity(0.4),
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Send button
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: _isComposing
                  ? LinearGradient(
                      colors: [AppColors.accent, AppColors.accent.withOpacity(0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: _isComposing ? null : AppColors.background,
              borderRadius: BorderRadius.circular(16),
              boxShadow: _isComposing
                  ? [BoxShadow(color: AppColors.accent.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _isComposing ? _sendMessage : null,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      _isComposing ? Icons.send_rounded : Icons.mic_rounded,
                      key: ValueKey(_isComposing),
                      color: _isComposing ? Colors.white : AppColors.textBody.withOpacity(0.3),
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
