import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/colors.dart';

/// Tüm etkinlik akışı — PRD §4.1.1-B
class ActivityFeedScreen extends ConsumerStatefulWidget {
  const ActivityFeedScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends ConsumerState<ActivityFeedScreen> {
  final List<_FeedItem> _items = [];
  bool _loading = false;
  bool _hasMore = true;
  int _offset = 0;
  static const _limit = 20;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final resp = await ApiClient.dio.get(
        '/operations/activity-feed',
        queryParameters: {'limit': _limit, 'offset': _offset},
      );
      if (resp.statusCode == 200 && resp.data != null) {
        final data = resp.data;
        final items = (data['items'] as List).map((e) => _FeedItem.fromJson(e)).toList();
        setState(() {
          _items.addAll(items);
          _hasMore = data['has_more'] ?? false;
          _offset += items.length;
        });
      }
    } catch (e) {
      // Silently fail
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textHeader, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Etkinlik Akışı',
          style: TextStyle(
            color: AppColors.textHeader,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _items.isEmpty && _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined, size: 56, color: AppColors.textBody.withValues(alpha: 0.2)),
                      const SizedBox(height: 16),
                      const Text(
                        'Henüz etkinlik yok',
                        style: TextStyle(color: AppColors.textBody, fontSize: 15),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    setState(() {
                      _items.clear();
                      _offset = 0;
                      _hasMore = true;
                    });
                    await _loadMore();
                  },
                  color: AppColors.accent,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
                    itemCount: _items.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _items.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: _loading
                              ? const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                                  ),
                                )
                              : GestureDetector(
                                  onTap: _loadMore,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'Daha Fazla Yükle',
                                        style: TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ),
                                ),
                        );
                      }
                      return _buildFeedItem(_items[index], index);
                    },
                  ),
                ),
    );
  }

  Widget _buildFeedItem(_FeedItem item, int index) {
    final colors = {
      'success': AppColors.success,
      'error': AppColors.error,
      'warning': AppColors.warning,
      'accent': AppColors.accent,
      'textBody': AppColors.textBody,
    };
    final color = colors[item.color] ?? AppColors.textBody;

    final icons = {
      'payments': Icons.payments_outlined,
      'confirmation_number': Icons.confirmation_number_outlined,
      'engineering': Icons.engineering_outlined,
      'person_add': Icons.person_add_outlined,
    };
    final icon = icons[item.icon] ?? Icons.circle_outlined;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 60).clamp(0, 400)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: AppColors.textHeader,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: TextStyle(
                      color: AppColors.textBody.withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _formatTime(item.timestamp),
              style: TextStyle(
                color: AppColors.textBody.withValues(alpha: 0.4),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'şimdi';
      if (diff.inMinutes < 60) return '${diff.inMinutes}d';
      if (diff.inHours < 24) return '${diff.inHours}s';
      if (diff.inDays < 7) return '${diff.inDays}g';
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return '';
    }
  }
}

/// Feed item model (same as home_tab.dart)
class _FeedItem {
  final String id;
  final String type;
  final String title;
  final String subtitle;
  final String icon;
  final String color;
  final String timestamp;

  _FeedItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.timestamp,
  });

  factory _FeedItem.fromJson(Map<String, dynamic> json) {
    return _FeedItem(
      id: json['id'] ?? '',
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      icon: json['icon'] ?? 'circle',
      color: json['color'] ?? 'textBody',
      timestamp: json['timestamp'] ?? DateTime.now().toIso8601String(),
    );
  }
}
