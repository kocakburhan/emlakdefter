import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/chat_websocket_service.dart';
import '../providers/tenant_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// "Crystal Chat" — Tenant Messaging
// iMessage-inspired, clean, spring-physics messaging
// PRD §4.2.5
// ─────────────────────────────────────────────────────────────────────────────

// ── Palette — mapped to AppColors Modern Minimalist ──────────────────────────
const _white = AppColors.textOnPrimary;
const _bg = AppColors.background;
const _surface = AppColors.surface;
const _surface2 = AppColors.surfaceVariant;
const _bubbleMe = AppColors.charcoal;
const _bubbleOther = AppColors.lightGray;
const _textDark = AppColors.charcoal;
const _textMid = AppColors.textSecondary;
const _textLight = AppColors.textTertiary;
const _accent = AppColors.charcoal;
const _danger = AppColors.error;

// ── Spring curves ─────────────────────────────────────────────────────────────
final _springFast = Curves.easeOutBack;
final _springBounce = Curves.elasticOut;

// ─────────────────────────────────────────────────────────────────────────────
// Main Tab
// ─────────────────────────────────────────────────────────────────────────────
class TenantChatTab extends ConsumerStatefulWidget {
  final void Function(int tabIndex)? onNavigateToTab;

  const TenantChatTab({super.key, this.onNavigateToTab});

  @override
  ConsumerState<TenantChatTab> createState() => _TenantChatTabState();
}

class _TenantChatTabState extends ConsumerState<TenantChatTab>
    with TickerProviderStateMixin {

  // Conversation list animation
  late AnimationController _listSlideController;
  late Animation<Offset> _listSlide;

  // Screen transitions
  bool _showChat = false;
  String? _activeConversationId;
  String? _activeConversationTitle;

  // Pending property context from Explore tab (§4.2.6)
  String? _pendingPropertyId;
  String? _pendingInitialMessage;

  @override
  void initState() {
    super.initState();
    _listSlideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _listSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _listSlideController,
      curve: _springFast,
    ));
    _listSlideController.forward();

    // Check for pending property inquiry from Explore tab
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final launchCtx = ref.read(chatLaunchProvider);
      if (launchCtx != null) {
        ref.read(chatLaunchProvider.notifier).clear();
        setState(() {
          _pendingPropertyId = launchCtx.propertyId;
          _pendingInitialMessage = launchCtx.initialMessage;
          _showChat = true;
          _activeConversationId = null; // new conversation
          _activeConversationTitle = launchCtx.propertyName;
        });
      }
    });
  }

  @override
  void dispose() {
    _listSlideController.dispose();
    super.dispose();
  }

  void _openChat(String convId, String title) {
    setState(() {
      _showChat = true;
      _activeConversationId = convId;
      _activeConversationTitle = title;
    });
  }

  void _closeChat() {
    setState(() => _showChat = false);
    ref.invalidate(tenantConversationsProvider);
  }

  @override
  Widget build(BuildContext context) {
    if (_showChat) {
      return _ChatScreen(
        conversationId: _activeConversationId,
        title: _activeConversationTitle ?? 'Emlak Ofisi',
        onBack: _closeChat,
        propertyId: _pendingPropertyId,
        initialMessage: _pendingInitialMessage,
      );
    }
    return _ConversationList(
      onSelectConversation: _openChat,
      slideAnimation: _listSlide,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ConversationList
// WhatsApp-style conversation list
// ─────────────────────────────────────────────────────────────────────────────
class _ConversationList extends ConsumerWidget {
  final void Function(String convId, String title) onSelectConversation;
  final Animation<Offset> slideAnimation;

  const _ConversationList({
    required this.onSelectConversation,
    required this.slideAnimation,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(tenantConversationsProvider);
    final tenantInfo = ref.watch(tenantProvider);

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: SlideTransition(
                position: slideAnimation,
                child: Row(
                  children: [
                    // Office avatar
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _accent,
                            _accent.withValues(alpha: 0.7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _accent.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.business_rounded,
                          color: _white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tenantInfo.value?.propertyName ?? 'Emlak Ofisi',
                            style: const TextStyle(
                              color: _textDark,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Resmi iletişim kanalı',
                            style: TextStyle(
                              color: _textLight, fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Compose button
                    _SpringButton(
                      onTap: () async {
                        // Create or find conversation
                        final convs = await ref.read(
                            tenantConversationsProvider.future);
                        if (convs.isNotEmpty) {
                          final c = convs.first;
                          onSelectConversation(
                            c.id,
                            c.propertyName ?? 'Emlak Ofisi',
                          );
                        }
                      },
                      child: Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          color: _accent,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: _accent.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.chat_bubble_rounded,
                            color: _white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Conversation list ────────────────────────────────
            Expanded(
              child: conversationsAsync.when(
                loading: () => const Center(
                  child: _TypingDots(),
                ),
                error: (_, __) => _buildError(),
                data: (convs) {
                  if (convs.isEmpty) {
                    return _buildEmptyState(onSelectConversation);
                  }
                  return SlideTransition(
                    position: slideAnimation,
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      itemCount: convs.length,
                      itemBuilder: (context, index) {
                        final conv = convs[index];
                        return _ConversationTile(
                          conversation: conv,
                          onTap: () => onSelectConversation(
                            conv.id,
                            conv.propertyName ?? 'Emlak Ofisi',
                          ),
                          index: index,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(void Function(String, String) onSelect) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: _surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(Icons.forum_outlined,
                color: _accent.withValues(alpha: 0.6), size: 52),
          ),
          const SizedBox(height: 20),
          const Text(
            'Henüz konuşma yok',
            style: TextStyle(
              color: _textDark, fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Emlak ofisi ile yazışmaya başlamak için\naşağıdaki butona tıklayın.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textMid, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: () async {
              // Get conversations and open first
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: _accent.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_rounded,
                      color: _white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Sohbete Başla',
                    style: TextStyle(
                      color: _white, fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded,
              color: _textLight, size: 48),
          const SizedBox(height: 12),
          Text('Bağlantı kurulamadı',
              style: TextStyle(color: _textMid)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ConversationTile
// ─────────────────────────────────────────────────────────────────────────────
class _ConversationTile extends StatefulWidget {
  final ConversationItem conversation;
  final VoidCallback onTap;
  final int index;

  const _ConversationTile({
    required this.conversation,
    required this.onTap,
    required this.index,
  });

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: _springFast),
    );
    Future.delayed(Duration(milliseconds: 50 * widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conv = widget.conversation;
    final hasUnread = conv.unreadCount > 0;

    return ScaleTransition(
      scale: _scale,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _controller, curve: _springFast)),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Avatar
                Stack(
                  children: [
                    Container(
                      width: 54, height: 54,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _accent,
                            _accent.withValues(alpha: 0.7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.business_rounded,
                          color: _white, size: 24),
                    ),
                    if (hasUnread)
                      Positioned(
                        bottom: 0, right: 0,
                        child: Container(
                          width: 18, height: 18,
                          decoration: BoxDecoration(
                            color: _danger,
                            shape: BoxShape.circle,
                            border: Border.all(color: _surface, width: 2),
                          ),
                          child: Center(
                            child: Text(
                              conv.unreadCount > 9
                                  ? '9+'
                                  : conv.unreadCount.toString(),
                              style: const TextStyle(
                                color: _white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),

                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conv.propertyName ?? 'Emlak Ofisi',
                              style: const TextStyle(
                                color: _textDark,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (conv.lastMessageAt != null)
                            Text(
                              _convTime(conv.lastMessageAt!),
                              style: TextStyle(
                                color: hasUnread ? _accent : _textLight,
                                fontSize: 11,
                                fontWeight:
                                    hasUnread ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conv.lastMessage ?? 'Henüz mesaj yok',
                              style: TextStyle(
                                color: hasUnread ? _textMid : _textLight,
                                fontSize: 13,
                                fontWeight:
                                    hasUnread ? FontWeight.w600 : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: _textLight,
                            size: 20,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _convTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Şimdi';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk';
    if (diff.inHours < 24) return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (diff.inDays == 1) return 'Dün';
    return '${dt.day}/${dt.month}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ChatScreen
// Full messaging screen with spring animations
// ─────────────────────────────────────────────────────────────────────────────
class _ChatScreen extends ConsumerStatefulWidget {
  final String? conversationId; // null = new conversation
  final String title;
  final VoidCallback onBack;
  final String? propertyId;
  final String? initialMessage;

  const _ChatScreen({
    this.conversationId,
    required this.title,
    required this.onBack,
    this.propertyId,
    this.initialMessage,
  });

  @override
  ConsumerState<_ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<_ChatScreen>
    with TickerProviderStateMixin {

  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();

  late AnimationController _headerAnimController;
  late Animation<double> _headerOpacity;

  late AnimationController _inputAnimController;
  late Animation<double> _inputScale;

  bool _isLoadingHistory = true;
  List<ChatMessageItem> _messages = [];
  bool _isSending = false;
  bool _showAttachPicker = false;
  Uint8List? _attachedBytes;
  String? _attachedFileName;

  // Spring animation for message bubbles
  final Map<String, AnimationController> _bubbleControllers = {};

  // WebSocket for real-time messaging
  final ChatWebSocketService _ws = ChatWebSocketService();

  @override
  void initState() {
    super.initState();

    _headerAnimController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _headerOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _headerAnimController, curve: _springFast),
    );

    _inputAnimController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _inputScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _inputAnimController, curve: _springBounce),
    );

    // Pre-fill initial message from Explore tab property inquiry
    if (widget.initialMessage != null) {
      _textCtrl.text = widget.initialMessage!;
    }

    _headerAnimController.forward();
    _inputAnimController.forward();

    if (widget.conversationId != null) {
      _loadHistory();
      _connectWebSocket(widget.conversationId!);
    } else {
      _isLoadingHistory = false;
    }
  }

  @override
  void dispose() {
    _ws.dispose();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    _headerAnimController.dispose();
    _inputAnimController.dispose();
    for (final c in _bubbleControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _connectWebSocket(String conversationId) {
    _ws.onMessage = (data) {
      if (!mounted) return;
      final msg = ChatMessageItem(
        id: data['id'] ?? '',
        conversationId: data['conversation_id'] ?? conversationId,
        senderUserId: data['sender_user_id'] ?? '',
        message: data['content'] ?? data['message'] ?? '',
        mediaUrl: data['attachment_url'] ?? data['media_url'],
        createdAt: DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now(),
        isDeleted: false,
        isEdited: false,
      );
      setState(() {
        _messages = [..._messages, msg];
      });
      _scrollToBottom();
    };

    _ws.onMessageRead = (data) {
      // Tenant chat doesn't track individual read receipts — just mark all as read
      if (!mounted) return;
      setState(() {
        _messages = _messages.map((m) => ChatMessageItem(
          id: m.id,
          conversationId: m.conversationId,
          senderUserId: m.senderUserId,
          message: m.message,
          mediaUrl: m.mediaUrl,
          createdAt: m.createdAt,
          isDeleted: m.isDeleted,
          isEdited: m.isEdited,
        )).toList();
      });
    };

    _ws.connect(conversationId);
  }

  Future<void> _loadHistory() async {
    if (widget.conversationId == null) return;
    final history = await ref
        .read(tenantChatHistoryProvider(widget.conversationId!).future);
    if (!mounted) return;
    setState(() {
      _messages = history;
      _isLoadingHistory = false;
    });
    _scrollToBottom(immediate: true);
  }

  Future<void> _refreshHistory() async {
    if (widget.conversationId == null) return;
    ref.invalidate(tenantChatHistoryProvider(widget.conversationId!));
    await _loadHistory();
  }

  void _scrollToBottom({bool immediate = false}) {
    if (!_scrollCtrl.hasClients) return;
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: immediate
              ? const Duration(milliseconds: 100)
              : const Duration(milliseconds: 340),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  AnimationController _getBubbleController(String messageId) {
    if (!_bubbleControllers.containsKey(messageId)) {
      _bubbleControllers[messageId] = AnimationController(
        duration: const Duration(milliseconds: 500),
        vsync: this,
      )..forward();
    }
    return _bubbleControllers[messageId]!;
  }

  Future<void> _sendMessage() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty && _attachedBytes == null) return;

    setState(() => _isSending = true);

    String? mediaUrl;

    // Upload attachment first if present
    if (_attachedBytes != null) {
      try {
        final formData = FormData.fromMap({
          'file': MultipartFile.fromBytes(
            _attachedBytes!,
            filename: _attachedFileName ?? 'attachment',
          ),
          'category': 'chat',
        });
        final resp = await ApiClient.dio.post(
          '/media/upload',
          data: formData,
        );
        if (resp.statusCode == 200 && resp.data != null) {
          mediaUrl = resp.data['url'];
        }
      } catch (_) {
        // Continue without attachment
      }
    }

    final params = SendMessageParams(
      conversationId: widget.conversationId ?? '',
      propertyId: widget.propertyId,
      message: text.isNotEmpty ? text : null,
      mediaUrl: mediaUrl,
    );

    final sent = await ref.read(tenantSendMessageProvider(params).future);

    if (!mounted) return;

    setState(() {
      _isSending = false;
      if (sent != null) {
        _messages = [..._messages, sent];
        _textCtrl.clear();
        _attachedBytes = null;
        _attachedFileName = null;
        _showAttachPicker = false;
      }
    });

    if (sent != null) {
      _scrollToBottom();
    }
  }

  Future<void> _pickAttachment(String source) async {
    setState(() => _showAttachPicker = false);

    FilePickerResult? result;
    if (source == 'camera') {
      result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
    } else if (source == 'gallery') {
      result = await FilePicker.platform.pickFiles(
        type: FileType.media,
        allowMultiple: false,
        withData: true,
      );
    } else {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        allowMultiple: false,
        withData: true,
      );
    }

    if (result != null && result.files.isNotEmpty && mounted) {
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes != null) {
        setState(() {
          _attachedBytes = bytes;
          _attachedFileName = file.name;
        });
      }
    }
  }

  void _removeAttachment() {
    setState(() {
      _attachedBytes = null;
      _attachedFileName = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Animated Header ──────────────────────────────────
            FadeTransition(
              opacity: _headerOpacity,
              child: _ChatHeader(
                title: widget.title,
                onBack: widget.onBack,
              ),
            ),

            // ── Messages ─────────────────────────────────────────
            Expanded(
              child: _isLoadingHistory
                  ? const Center(
                      child: _TypingDots(),
                    )
                  : _messages.isEmpty
                      ? _buildEmptyChat()
                      : RefreshIndicator(
                          color: _accent,
                          onRefresh: _refreshHistory,
                          child: ListView.builder(
                            controller: _scrollCtrl,
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final msg = _messages[index];
                              final isMe = _isOwnMessage(msg);
                              final showDate = index == 0 ||
                                  !_isSameDay(
                                    _messages[index - 1].createdAt,
                                    msg.createdAt,
                                  );
                              return Column(
                                children: [
                                  if (showDate)
                                    _DateSeparator(date: msg.createdAt),
                                  _MessageBubble(
                                    message: msg,
                                    isMe: isMe,
                                    controller:
                                        _getBubbleController(msg.id),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
            ),

            // ── Attachment Preview ───────────────────────────────
            if (_attachedBytes != null)
              _AttachmentPreview(
                bytes: _attachedBytes!,
                fileName: _attachedFileName,
                onRemove: _removeAttachment,
              ),

            // ── Input Bar ─────────────────────────────────────────
            ScaleTransition(
              scale: _inputScale,
              child: _ChatInputBar(
                controller: _textCtrl,
                focusNode: _focusNode,
                isSending: _isSending,
                showAttachPicker: _showAttachPicker,
                onAttachToggle: () =>
                    setState(() => _showAttachPicker = !_showAttachPicker),
                onPickAttachment: _pickAttachment,
                onSend: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isOwnMessage(ChatMessageItem msg) {
    // Compare with tenant user ID
    final tenant = ref.read(tenantProvider).value;
    if (tenant == null) return false;
    return msg.senderUserId == tenant.id;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _accent.withValues(alpha: 0.15),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(Icons.chat_bubble_outline_rounded,
                color: _accent, size: 40),
          ),
          const SizedBox(height: 16),
          const Text(
            'Yazışmaya başlayın',
            style: TextStyle(
              color: _textDark, fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Emlak ofisi mesajlarınıza yanıt verecek.',
            style: TextStyle(color: _textMid, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ChatHeader
// ─────────────────────────────────────────────────────────────────────────────
class _ChatHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _ChatHeader({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      decoration: BoxDecoration(
        color: _surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            onPressed: onBack,
            icon: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.arrow_back_rounded,
                  color: _textDark, size: 20),
            ),
          ),

          // Avatar
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_accent, _accent.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.business_rounded,
                color: _white, size: 20),
          ),
          const SizedBox(width: 12),

          // Title + status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: _accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Çevrimiçi',
                      style: TextStyle(
                        color: _accent, fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Call button
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.phone_rounded,
                color: _accent, size: 20),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MessageBubble
// Spring-animated message bubble
// ─────────────────────────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final ChatMessageItem message;
  final bool isMe;
  final AnimationController? controller;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    // Use existing controller or create a default animation
    final anim = controller != null
        ? Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: controller!,
              curve: const _SpringCurve(),
            ),
          )
        : null;

    Widget bubble = Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.76,
        ),
        margin: const EdgeInsets.only(bottom: 4),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Bubble
            Container(
              padding: message.mediaUrl != null
                  ? const EdgeInsets.all(4)
                  : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? _bubbleMe : _bubbleOther,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isMe ? 20 : 5),
                  bottomRight: Radius.circular(isMe ? 5 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isMe ? _bubbleMe : Colors.black)
                        .withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Media attachment
                  if (message.mediaUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        message.mediaUrl!,
                        height: 200,
                        width: 220,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 100,
                          width: double.infinity,
                          color: _surface2,
                          child: Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: _textLight,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Text
                  if (message.message != null &&
                      message.message!.isNotEmpty)
                    Padding(
                      padding: message.mediaUrl != null
                          ? const EdgeInsets.only(top: 8, left: 8, right: 8)
                          : EdgeInsets.zero,
                      child: Text(
                        message.message!,
                        style: TextStyle(
                          color: isMe ? _white : _textDark,
                          fontSize: 15,
                          height: 1.35,
                        ),
                      ),
                    ),

                  const SizedBox(height: 4),

                  // Time + read receipt
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.createdAt),
                        style: TextStyle(
                          color: (isMe ? _white : _textMid)
                              .withValues(alpha: 0.7),
                          fontSize: 10,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.done_all_rounded,
                          size: 14,
                          color: _white.withValues(alpha: 0.7),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (anim != null) {
      return AnimatedBuilder(
        animation: anim,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(
              isMe ? 24 * (1 - anim.value) : -24 * (1 - anim.value),
              0,
            ),
            child: Opacity(
              opacity: anim.value.clamp(0.0, 1.0),
              child: child,
            ),
          );
        },
        child: bubble,
      );
    }

    return bubble;
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DateSeparator
// ─────────────────────────────────────────────────────────────────────────────
class _DateSeparator extends StatelessWidget {
  final DateTime date;

  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: _textLight.withValues(alpha: 0.2))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _dateLabel(date),
              style: TextStyle(
                color: _textLight,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Divider(color: _textLight.withValues(alpha: 0.2))),
        ],
      ),
    );
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDate = DateTime(date.year, date.month, date.day);
    final diff = today.difference(msgDate).inDays;
    if (diff == 0) return 'Bugün';
    if (diff == 1) return 'Dün';
    if (diff < 7) return '${date.day} ${_monthName(date.month)}';
    return '${date.day} ${_monthName(date.month)} ${date.year}';
  }

  String _monthName(int m) {
    const months = [
      'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
      'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'
    ];
    return months[m - 1];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ChatInputBar
// ─────────────────────────────────────────────────────────────────────────────
class _ChatInputBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final bool showAttachPicker;
  final VoidCallback onAttachToggle;
  final void Function(String source) onPickAttachment;
  final VoidCallback onSend;

  const _ChatInputBar({
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.showAttachPicker,
    required this.onAttachToggle,
    required this.onPickAttachment,
    required this.onSend,
  });

  @override
  State<_ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<_ChatInputBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        8 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: _surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Attachment picker
          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            height: widget.showAttachPicker ? 80 : 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: widget.showAttachPicker ? 1.0 : 0.0,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _AttachOption(
                      icon: Icons.camera_alt_rounded,
                      label: 'Kamera',
                      color: const Color(0xFFFF6B6B),
                      onTap: () => widget.onPickAttachment('camera'),
                    ),
                    _AttachOption(
                      icon: Icons.photo_library_rounded,
                      label: 'Galeri',
                      color: const Color(0xFF34B7F1),
                      onTap: () => widget.onPickAttachment('gallery'),
                    ),
                    _AttachOption(
                      icon: Icons.insert_drive_file_rounded,
                      label: 'Belge',
                      color: const Color(0xFF8B5CF6),
                      onTap: () => widget.onPickAttachment('document'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 4),

          // Main input row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Attach button
              _SpringButton(
                onTap: widget.onAttachToggle,
                child: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: widget.showAttachPicker
                        ? _accent.withValues(alpha: 0.1)
                        : _bg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    color: widget.showAttachPicker
                        ? _accent
                        : _textMid,
                    size: 24,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Text input
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 140),
                  decoration: BoxDecoration(
                    color: _bg,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: _hasText
                          ? _accent.withValues(alpha: 0.4)
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: widget.controller,
                          focusNode: widget.focusNode,
                          style: const TextStyle(
                            color: _textDark,
                            fontSize: 15,
                          ),
                          maxLines: null,
                          minLines: 1,
                          textCapitalization: TextCapitalization.sentences,
                          keyboardType: TextInputType.multiline,
                          decoration: InputDecoration(
                            hintText: 'Mesajınızı yazın...',
                            hintStyle: TextStyle(
                              color: _textLight, fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.fromLTRB(
                              16, 12, 12, 12,
                            ),
                          ),
                          onTap: () {
                            if (widget.showAttachPicker) {
                              // Keep closed on tap
                            }
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(
                            right: 8, bottom: 8),
                        child: Icon(
                          Icons.emoji_emotions_outlined,
                          color: _textLight,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Send button (spring animation)
              _SpringButton(
                onTap: widget.isSending
                    ? () {}
                    : () {
                        HapticFeedback.lightImpact();
                        widget.onSend();
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    gradient: (_hasText || widget.isSending)
                        ? LinearGradient(
                            colors: [_accent, _accent.withValues(alpha: 0.85)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: (_hasText || widget.isSending)
                        ? null
                        : _bg,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: (_hasText || widget.isSending)
                        ? [
                            BoxShadow(
                              color: _accent.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: widget.isSending
                      ? const Padding(
                          padding: EdgeInsets.all(13),
                          child: CircularProgressIndicator(
                            color: _white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Icon(
                          Icons.send_rounded,
                          color: _hasText
                              ? _white
                              : _textLight,
                          size: 22,
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AttachOption
// ─────────────────────────────────────────────────────────────────────────────
class _AttachOption extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_AttachOption> createState() => _AttachOptionState();
}

class _AttachOptionState extends State<_AttachOption> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(widget.icon, color: widget.color, size: 24),
            ),
            const SizedBox(height: 5),
            Text(
              widget.label,
              style: TextStyle(
                color: _textMid, fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AttachmentPreview
// ─────────────────────────────────────────────────────────────────────────────
class _AttachmentPreview extends StatelessWidget {
  final Uint8List bytes;
  final String? fileName;
  final VoidCallback onRemove;

  const _AttachmentPreview({
    required this.bytes,
    this.fileName,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isImage = fileName != null &&
        fileName!.toLowerCase().contains(RegExp(r'\.(jpg|jpeg|png|gif|webp)'));

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _accent.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          if (isImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                bytes,
                width: 48, height: 48,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.insert_drive_file_rounded,
                  color: Color(0xFF8B5CF6), size: 24),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              fileName ?? 'attachment',
              style: const TextStyle(
                color: _textDark, fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: _danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.close_rounded,
                  color: _danger, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SpringButton
// Reusable spring-animated button wrapper
// ─────────────────────────────────────────────────────────────────────────────
class _SpringButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _SpringButton({required this.child, required this.onTap});

  @override
  State<_SpringButton> createState() => _SpringButtonState();
}

class _SpringButtonState extends State<_SpringButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TypingDots
// Animated typing indicator
// ─────────────────────────────────────────────────────────────────────────────
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with TickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final phase = (_ctrl.value - delay).clamp(0.0, 1.0);
            final opacity = (phase < 0.5
                    ? phase * 2
                    : 2 - phase * 2)
                .clamp(0.2, 1.0);
            final yOffset = (1 - (phase - 0.5).abs() * 2) * -6;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Transform.translate(
                offset: Offset(0, yOffset),
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: _accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SpringCurve
// Custom spring curve for bouncy message entrance
// ─────────────────────────────────────────────────────────────────────────────
class _SpringCurve extends Curve {
  const _SpringCurve();

  @override
  double transformInternal(double t) {
    // Critically damped spring approximation
    const c1 = 1.70158;
    const c3 = c1 + 1;
    return 1 + c3 * ((t - 1) * (t - 1) * (t - 1)) + c1 * ((t - 1) * (t - 1));
  }
}
