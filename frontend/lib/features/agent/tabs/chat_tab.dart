import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/network/api_client.dart';
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
        backgroundColor: AppColors.charcoal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Geri Al',
          textColor: AppColors.charcoal,
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
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
                      Text('Emlakdefter', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 14, color: AppColors.charcoal)),
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
                ? const Center(child: CircularProgressIndicator(color: AppColors.charcoal))
                : convs.isEmpty
                    ? _buildEmptyState()
                    : FadeTransition(
                        opacity: _listFadeAnim,
                        child: RefreshIndicator(
                          onRefresh: () => notifier.fetchConversations(),
                          color: AppColors.charcoal,
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
          color: _showArchived ? AppColors.charcoal.withValues(alpha:0.15) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _showArchived ? AppColors.charcoal : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _showArchived ? Icons.archive : Icons.archive_outlined,
              size: 18,
              color: _showArchived ? AppColors.charcoal : AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              _showArchived ? 'Arşiv' : '',
              style: TextStyle(
                color: _showArchived ? AppColors.charcoal : AppColors.textSecondary,
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
          colors: [AppColors.charcoal, AppColors.charcoal.withValues(alpha:0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: AppColors.charcoal.withValues(alpha:0.3), blurRadius: 8, offset: const Offset(0, 4)),
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
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        style: const TextStyle(color: AppColors.charcoal),
        decoration: InputDecoration(
          hintText: 'Sohbet ara...',
          hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha:0.5)),
          prefixIcon: Icon(Icons.search, color: AppColors.textSecondary.withValues(alpha:0.4)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: AppColors.textSecondary.withValues(alpha:0.4)),
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
              color: AppColors.charcoal.withValues(alpha:0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _showArchived ? Icons.archive_outlined : Icons.chat_bubble_outline,
              size: 56,
              color: AppColors.charcoal.withValues(alpha:0.4),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _showArchived ? 'Arşivlenmiş sohbet yok' : 'Henüz sohbet başlatılmamış',
            style: const TextStyle(color: AppColors.charcoal, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            _showArchived
                ? 'Arşivlenen sohbetler burada görünür'
                : 'Kiracınız veya ev sahibinizle sohbet başlatın',
            style: TextStyle(color: AppColors.textSecondary.withValues(alpha:0.6), fontSize: 14),
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
            color: AppColors.warning.withValues(alpha:0.15),
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
                  border: Border.all(color: AppColors.border),
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
                                    color: AppColors.charcoal,
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
                                    color: AppColors.textSecondary.withValues(alpha:0.5),
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
                                        ? AppColors.success.withValues(alpha:0.1)
                                        : AppColors.warning.withValues(alpha:0.1),
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
                                      color: AppColors.textSecondary.withValues(alpha:0.6),
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
                                color: AppColors.textSecondary.withValues(alpha:0.7),
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
                    // Okunmamış rozeti (§4.1.8-A)
                    if (conv.unreadCount > 0) ...[
                      Container(
                        constraints: const BoxConstraints(minWidth: 22),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: AppColors.error.withValues(alpha:0.4), blurRadius: 4)],
                        ),
                        child: Text(
                          conv.unreadCount > 99 ? '99+' : '${conv.unreadCount}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Icon(Icons.chevron_right, color: AppColors.textSecondary.withValues(alpha:0.3), size: 20),
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
      AppColors.charcoal,
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
          colors: [colors[colorIdx].withValues(alpha:0.8), colors[colorIdx].withValues(alpha:0.5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: colors[colorIdx].withValues(alpha:0.3), blurRadius: 8, offset: const Offset(0, 4))],
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
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NewChatSheet(
        onSelectConversation: (conv) {
          Navigator.pop(ctx);
          _openChatWindow(ctx, conv);
        },
      ),
    );
  }
}

// ─── Yeni Sohbet Sheet (§4.1.8-A: Yeni Sohbet Dialog) ───────────────────────
class _NewChatSheet extends ConsumerStatefulWidget {
  final void Function(ChatConversation) onSelectConversation;
  const _NewChatSheet({required this.onSelectConversation});

  @override
  ConsumerState<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends ConsumerState<_NewChatSheet> {
  List<dynamic> _tenants = [];
  List<dynamic> _landlords = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final responses = await Future.wait([
        ApiClient.dio.get('/tenants/', queryParameters: {'limit': 100}),
        ApiClient.dio.get('/tenants/landlords', queryParameters: {'limit': 100}),
      ]);
      if (mounted) {
        setState(() {
          _tenants = responses[0].data ?? [];
          _landlords = responses[1].data ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _startOrOpenChat(dynamic user, String role) async {
    try {
      final response = await ApiClient.dio.post('/chat/conversations', data: {
        'client_user_id': user['user_id'] ?? user['id'],
      });
      if (response.statusCode == 200 || response.statusCode == 201) {
        final conv = ChatConversation.fromJson(response.data);
        widget.onSelectConversation(conv);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sohbet başlatılamadı: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Yeni Sohbet',
                    style: TextStyle(color: AppColors.charcoal, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                // Search
                TextField(
                  onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                  style: const TextStyle(color: AppColors.charcoal),
                  decoration: InputDecoration(
                    hintText: 'Kiracı veya daire ara...',
                    hintStyle: TextStyle(color: AppColors.textTertiary),
                    prefixIcon: Icon(Icons.search, color: AppColors.textTertiary),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.charcoal))
                : _error != null
                    ? Center(child: Text('Hata: $_error', style: const TextStyle(color: AppColors.error)))
                    : _buildUserList(),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    final filteredTenants = _tenants.where((t) {
      final name = (t['temp_name'] ?? '').toString().toLowerCase();
      final unit = (t['unit_door'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) || unit.contains(_searchQuery);
    }).toList();

    final filteredLandlords = _landlords.where((l) {
      final name = (l['temp_name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery);
    }).toList();

    if (filteredTenants.isEmpty && filteredLandlords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text('Sonuç bulunamadı',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      children: [
        if (filteredTenants.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Text('KİRACILAR',
                style: TextStyle(color: AppColors.textSecondary,
                    fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
          ),
          ...filteredTenants.map((t) => _buildUserTile(
                icon: Icons.person,
                name: t['temp_name'] ?? 'Kiracı',
                subtitle: t['unit_door'] != null ? 'Daire: ${t['unit_door']}' : 'Kiracı',
                role: 'Kiracı',
                onTap: () => _startOrOpenChat(t, 'Kiracı'),
              )),
        ],
        if (filteredLandlords.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text('EV SAHİPLERİ',
                style: TextStyle(color: AppColors.textSecondary,
                    fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
          ),
          ...filteredLandlords.map((l) => _buildUserTile(
                icon: Icons.account_balance_wallet,
                name: l['temp_name'] ?? 'Ev Sahibi',
                subtitle: l['unit_id'] != null ? 'Mülk ID: ${l['unit_id']}' : 'Ev Sahibi',
                role: 'Ev Sahibi',
                onTap: () => _startOrOpenChat(l, 'Ev Sahibi'),
              )),
        ],
      ],
    );
  }

  Widget _buildUserTile({
    required IconData icon,
    required String name,
    required String subtitle,
    required String role,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.charcoal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppColors.charcoal, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: AppColors.charcoal, fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: role == 'Kiracı'
                    ? AppColors.success.withValues(alpha: 0.1)
                    : AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                role,
                style: TextStyle(
                  color: role == 'Kiracı' ? AppColors.success : AppColors.warning,
                  fontSize: 11, fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chat_bubble_outline, color: AppColors.charcoal.withValues(alpha: 0.5), size: 20),
          ],
        ),
      ),
    );
  }
}
