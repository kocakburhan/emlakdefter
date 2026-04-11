import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../providers/chat_provider.dart';
import '../screens/chat_window_screen.dart';

/// Sohbetler Listesi — WhatsApp tarzı, swipe-to-archive, 5 sn undo
class ChatTab extends ConsumerStatefulWidget {
  const ChatTab({Key? key}) : super(key: key);

  @override
  ConsumerState<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends ConsumerState<ChatTab> with SingleTickerProviderStateMixin {
  late AnimationController _listAnimController;
  late Animation<double> _listFadeAnim;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showArchived = false;
  ChatConversation? _lastArchived;

  @override
  void initState() {
    super.initState();
    _listAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _listFadeAnim = CurvedAnimation(
      parent: _listAnimController,
      curve: Curves.easeOutCubic,
    );

    // Fetch conversations on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatProvider.notifier).fetchConversations();
      _listAnimController.forward();
    });
  }

  @override
  void dispose() {
    _listAnimController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showUndoSnackbar(BuildContext context, String label, VoidCallback onUndo) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        backgroundColor: AppColors.textHeader,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Geri Al',
          textColor: AppColors.accent,
          onPressed: onUndo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider);
    final notifier = ref.read(chatProvider.notifier);

    // Filter conversations
    var convs = state.conversations;
    if (_searchQuery.isNotEmpty) {
      convs = convs.where((c) =>
        (c.clientName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
        (c.propertyName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
      ).toList();
    }
    if (!_showArchived) {
      convs = convs.where((c) => !c.isArchived).toList();
    }

    return SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Emlakdefter', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 14, color: AppColors.accent)),
                      const SizedBox(height: 2),
                      Text('Sohbetlerim', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24)),
                    ],
                  ),
                ),
                _buildArchivedToggle(),
                const SizedBox(width: 8),
                _buildNewChatButton(),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: _buildSearchBar(),
          ),

          // Conversation List
          Expanded(
            child: state.isLoadingConversations
                ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                : convs.isEmpty
                    ? _buildEmptyState()
                    : FadeTransition(
                        opacity: _listFadeAnim,
                        child: RefreshIndicator(
                          onRefresh: () => notifier.fetchConversations(),
                          color: AppColors.accent,
                          child: ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                            itemCount: convs.length,
                            itemBuilder: (ctx, i) => _buildConversationTile(ctx, convs[i], i),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildArchivedToggle() {
    return GestureDetector(
      onTap: () => setState(() => _showArchived = !_showArchived),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _showArchived ? AppColors.accent.withOpacity(0.15) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _showArchived ? AppColors.accent : Colors.white.withOpacity(0.05),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _showArchived ? Icons.archive : Icons.archive_outlined,
              size: 18,
              color: _showArchived ? AppColors.accent : AppColors.textBody,
            ),
            const SizedBox(width: 4),
            Text(
              _showArchived ? 'Arşiv' : '',
              style: TextStyle(
                color: _showArchived ? AppColors.accent : AppColors.textBody,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewChatButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.accent, AppColors.accent.withOpacity(0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: AppColors.accent.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showNewChatDialog(context),
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Icon(Icons.add_comment_outlined, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        style: const TextStyle(color: AppColors.textHeader),
        decoration: InputDecoration(
          hintText: 'Sohbet ara...',
          hintStyle: TextStyle(color: AppColors.textBody.withOpacity(0.5)),
          prefixIcon: Icon(Icons.search, color: AppColors.textBody.withOpacity(0.4)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: AppColors.textBody.withOpacity(0.4)),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
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
              _showArchived ? Icons.archive_outlined : Icons.chat_bubble_outline,
              size: 56,
              color: AppColors.accent.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _showArchived ? 'Arşivlenmiş sohbet yok' : 'Henüz sohbet başlatılmamış',
            style: const TextStyle(color: AppColors.textHeader, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            _showArchived
                ? 'Arşivlenen sohbetler burada görünür'
                : 'Kiracınız veya ev sahibinizle sohbet başlatın',
            style: TextStyle(color: AppColors.textBody.withOpacity(0.6), fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildConversationTile(BuildContext ctx, ChatConversation conv, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index * 60).clamp(0, 400)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, 20 * (1 - value)), child: child),
      ),
      child: Dismissible(
        key: Key(conv.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) async {
          setState(() => _lastArchived = conv);
          final success = await ref.read(chatProvider.notifier).archiveConversation(conv.id);
          if (success && mounted) {
            _showUndoSnackbar(
              context,
              '${conv.clientName ?? 'Sohbet'} arşivlendi',
              () => _undoArchive(),
            );
          }
          return success;
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.15),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(Icons.archive_outlined, color: AppColors.warning),
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _openChatWindow(ctx, conv),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Row(
                  children: [
                    // Avatar
                    _buildAvatar(conv),
                    const SizedBox(width: 14),

                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  conv.clientName ?? 'Bilinmeyen',
                                  style: const TextStyle(
                                    color: AppColors.textHeader,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (conv.lastMessageAt != null)
                                Text(
                                  _formatTime(conv.lastMessageAt!),
                                  style: TextStyle(
                                    color: AppColors.textBody.withOpacity(0.5),
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (conv.clientRole != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: conv.clientRole == 'Kiracı'
                                        ? AppColors.success.withOpacity(0.1)
                                        : AppColors.warning.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    conv.clientRole!,
                                    style: TextStyle(
                                      color: conv.clientRole == 'Kiracı' ? AppColors.success : AppColors.warning,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              if (conv.propertyName != null)
                                Expanded(
                                  child: Text(
                                    conv.propertyName!,
                                    style: TextStyle(
                                      color: AppColors.textBody.withOpacity(0.6),
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                          if (conv.lastMessage != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              conv.lastMessage!,
                              style: TextStyle(
                                color: AppColors.textBody.withOpacity(0.7),
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right, color: AppColors.textBody.withOpacity(0.3), size: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(ChatConversation conv) {
    final name = conv.clientName ?? '?';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final colors = [
      AppColors.accent,
      AppColors.success,
      AppColors.warning,
      const Color(0xFF7B61FF),
      const Color(0xFFFF6B6B),
    ];
    final colorIdx = name.hashCode.abs() % colors.length;

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors[colorIdx].withOpacity(0.8), colors[colorIdx].withOpacity(0.5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: colors[colorIdx].withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'şimdi';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk';
    if (diff.inHours < 24) return '${diff.inHours} s';
    if (diff.inDays < 7) return '${diff.inDays} g';
    return '${dt.day}/${dt.month}';
  }

  void _openChatWindow(BuildContext ctx, ChatConversation conv) {
    ref.read(chatProvider.notifier).selectConversation(conv);
    Navigator.push(
      ctx,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => ChatWindowScreen(conversation: conv),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  void _undoArchive() {
    // Re-fetch to restore the archived conversation
    ref.read(chatProvider.notifier).fetchConversations();
  }

  void _showNewChatDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(
              color: AppColors.textBody.withOpacity(0.3), borderRadius: BorderRadius.circular(2),
            )),
            const SizedBox(height: 20),
            const Text(
              'Yeni Sohbet',
              style: TextStyle(color: AppColors.textHeader, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Kiracı veya ev sahibi seçin',
              style: TextStyle(color: AppColors.textBody.withOpacity(0.7)),
            ),
            const SizedBox(height: 24),
            // Placeholder — gerçek kullanıcı listesi API'den çekilecek
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.textBody.withOpacity(0.5)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Kiracı/Ev Sahibi seçimi için kullanıcı listesi API\'si gerekli',
                      style: TextStyle(color: AppColors.textBody.withOpacity(0.7)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
