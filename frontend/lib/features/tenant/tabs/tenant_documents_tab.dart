import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/colors.dart';
import '../providers/tenant_provider.dart';

// ──────────────────────────────────────────────
// "Archival Navy" — Tenant Documents
// Blueprint, architectural, clean premium
// PRD §4.2.3
// ──────────────────────────────────────────────

const _bg = AppColors.background;
const _surface = AppColors.surface;
const _surface2 = AppColors.surfaceVariant;
const _border = AppColors.border;
const _cyan = AppColors.charcoal;
const _white = AppColors.textOnPrimary;
const _muted = AppColors.textSecondary;

Color _docColor(String docType) {
  switch (docType) {
    case 'contract': return const Color(0xFF3B82F6);
    case 'handover': return const Color(0xFF10B981);
    case 'aidat_plan': return const Color(0xFFF59E0B);
    case 'eviction': return const Color(0xFF8B5CF6);
    default: return const Color(0xFF6B7280);
  }
}

IconData _docIcon(String docType) {
  switch (docType) {
    case 'contract': return Icons.article_outlined;
    case 'handover': return Icons.inventory_2_outlined;
    case 'aidat_plan': return Icons.table_chart_outlined;
    case 'eviction': return Icons.assignment_turned_in_outlined;
    default: return Icons.description_outlined;
  }
}

String _docLabel(String docType) {
  switch (docType) {
    case 'contract': return 'Kira Sözleşmesi';
    case 'handover': return 'Demirbaş Teslim Tutanağı';
    case 'aidat_plan': return 'Aidat Ödeme Planı';
    case 'eviction': return 'Tahliye Taahhütnamesi';
    default: return 'Diğer Belge';
  }
}

class TenantDocumentsTab extends ConsumerStatefulWidget {
  const TenantDocumentsTab({super.key});

  @override
  ConsumerState<TenantDocumentsTab> createState() => _TenantDocumentsTabState();
}

class _TenantDocumentsTabState extends ConsumerState<TenantDocumentsTab> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tenantDocumentsProvider);

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _cyan.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _cyan.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: const Icon(Icons.folder_special_outlined,
                            color: _cyan, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Belgelerim',
                              style: TextStyle(
                                color: _white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Salt okunur dijital arşiv',
                              style: TextStyle(
                                  color: _muted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _surface2,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: _border, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_outline,
                                color: _muted, size: 12),
                            const SizedBox(width: 4),
                            Text('Salt Okunur',
                                style:
                                    TextStyle(color: _muted, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Info banner ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _cyan.withValues(alpha: 0.08),
                      _cyan.withValues(alpha: 0.03),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _cyan.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: _cyan, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Belgeleri görüntüleyebilir veya cihazınıza indirebilirsiniz. Değiştirme veya silme yetkiniz yoktur.',
                        style: TextStyle(
                            color: _muted, fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Document list ────────────────────────────────────────
            Expanded(
              child: state.when(
                loading: () => _buildShimmerList(),
                error: (_, __) => _buildError(),
                data: (payload) {
                  final allDocs = payload?.documents ?? [];
                  final contractUrl = payload?.contractDocumentUrl;

                  // Add contract as a special document if present
                  final docs = <_DocumentEntry>[];
                  if (contractUrl != null && contractUrl.isNotEmpty) {
                    docs.add(_DocumentEntry(
                      name: 'Kira Sözleşmesi',
                      docType: 'contract',
                      url: contractUrl,
                    ));
                  }
                  for (final d in allDocs) {
                    docs.add(_DocumentEntry(
                      name: d.name,
                      docType: d.docType,
                      url: d.url,
                    ));
                  }

                  if (docs.isEmpty) {
                    return _buildEmptyState();
                  }
                  return _buildDocList(docs);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: 4,
      itemBuilder: (_, __) => _ShimmerDocCard(),
    );
  }

  Widget _buildDocList(List<_DocumentEntry> docs) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        return _DocCard(
          entry: docs[index],
          index: index,
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _surface,
              shape: BoxShape.circle,
              border: Border.all(color: _border, width: 1),
            ),
            child: Icon(Icons.folder_open_outlined,
                color: _muted, size: 48),
          ),
          const SizedBox(height: 16),
          const Text(
            'Henüz belgeniz yok',
            style: TextStyle(
                color: _white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Ofis belgelerinizi sisteme eklediğinde\nburada görünecek.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 13, height: 1.5),
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
          Icon(Icons.error_outline, color: _muted, size: 48),
          const SizedBox(height: 12),
          Text('Belger yüklenemedi',
              style: TextStyle(color: _muted)),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// _DocumentEntry (local model for display)
// ──────────────────────────────────────────────
class _DocumentEntry {
  final String name;
  final String docType;
  final String url;

  _DocumentEntry({
    required this.name,
    required this.docType,
    required this.url,
  });
}

// ──────────────────────────────────────────────
// _DocCard
// ──────────────────────────────────────────────
class _DocCard extends StatefulWidget {
  final _DocumentEntry entry;
  final int index;

  const _DocCard({required this.entry, required this.index});

  @override
  State<_DocCard> createState() => _DocCardState();
}

class _DocCardState extends State<_DocCard> {
  bool _isPressed = false;

  Future<void> _openDoc() async {
    final uri = Uri.parse(widget.entry.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _docColor(widget.entry.docType);
    final icon = _docIcon(widget.entry.docType);
    final label = _docLabel(widget.entry.docType);
    final isPdf = widget.entry.url.toLowerCase().contains('.pdf');

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 350 + (widget.index * 70)),
      curve: Curves.easeOutCubic,
      builder: (context, anim, child) {
        return Opacity(
          opacity: anim,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - anim)),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: _openDoc,
        child: AnimatedScale(
          scale: _isPressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _border.withValues(alpha: 0.6),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Document type icon with colored bg
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: color.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Icon(icon, color: color, size: 26),
                      ),
                      const SizedBox(width: 14),

                      // Name + type
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.entry.name,
                              style: const TextStyle(
                                color: _white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (isPdf) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'PDF',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Action buttons
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // View button
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _cyan.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.open_in_new_rounded,
                              color: _cyan,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Download button
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _surface2,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.download_rounded,
                              color: _muted,
                              size: 18,
                            ),
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
}

// ──────────────────────────────────────────────
// _ShimmerDocCard
// ──────────────────────────────────────────────
class _ShimmerDocCard extends StatefulWidget {
  @override
  State<_ShimmerDocCard> createState() => _ShimmerDocCardState();
}

class _ShimmerDocCardState extends State<_ShimmerDocCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
    _anim = Tween<double>(begin: -1.0, end: 2.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: _surface2,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 120, height: 14,
                      decoration: BoxDecoration(
                        color: _surface2,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 80, height: 10,
                      decoration: BoxDecoration(
                        color: _surface2,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
