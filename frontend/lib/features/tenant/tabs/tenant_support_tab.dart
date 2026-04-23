import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/network/api_client.dart';
import '../providers/tenant_provider.dart';

// ──────────────────────────────────────────────
// "Workbench Warmth" — Tenant Support
// Warm amber, craftsman aesthetic
// PRD §4.2.2
// ──────────────────────────────────────────────

// Palette — mapped to AppColors Modern Minimalist
const _bg = AppColors.background;
const _surface = AppColors.surface;
const _surface2 = AppColors.surfaceVariant;
const _amber = AppColors.charcoal;
const _amberDim = AppColors.charcoalLight;
const _sage = AppColors.success;
const _coral = AppColors.error;
const _warmWhite = AppColors.textOnPrimary;
const _warmMuted = AppColors.textSecondary;
const _warmHint = AppColors.textTertiary;

Color _statusColor(TenantTicketStatus s) {
  switch (s) {
    case TenantTicketStatus.open: return _coral;
    case TenantTicketStatus.inProgress: return _amber;
    case TenantTicketStatus.resolved: return _sage;
    case TenantTicketStatus.closed: return _warmMuted;
  }
}

String _statusLabel(TenantTicketStatus s) {
  switch (s) {
    case TenantTicketStatus.open: return 'Açık';
    case TenantTicketStatus.inProgress: return 'İşlemde';
    case TenantTicketStatus.resolved: return 'Çözüldü';
    case TenantTicketStatus.closed: return 'Kapandı';
  }
}

IconData _statusIcon(TenantTicketStatus s) {
  switch (s) {
    case TenantTicketStatus.open: return Icons.radio_button_checked_rounded;
    case TenantTicketStatus.inProgress: return Icons.engineering_rounded;
    case TenantTicketStatus.resolved: return Icons.check_circle_rounded;
    case TenantTicketStatus.closed: return Icons.lock_rounded;
  }
}

class TenantSupportTab extends ConsumerStatefulWidget {
  const TenantSupportTab({super.key});

  @override
  ConsumerState<TenantSupportTab> createState() => _TenantSupportTabState();
}

class _TenantSupportTabState extends ConsumerState<TenantSupportTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _fabAnimController;
  late Animation<double> _fabScale;

  @override
  void initState() {
    super.initState();
    _fabAnimController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabAnimController, curve: Curves.elasticOut),
    );
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _fabAnimController.forward();
    });
  }

  @override
  void dispose() {
    _fabAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tenantSupportProvider);

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
                          color: _amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.handyman_rounded,
                            color: _amber, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Destek Merkezi',
                              style: TextStyle(
                                color: _warmWhite,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Arıza ve sorun bildirimleriniz',
                              style: TextStyle(
                                color: _warmMuted, fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Content ─────────────────────────────────────────────
            Expanded(
              child: state.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: _amber),
                ),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, color: _coral, size: 48),
                      const SizedBox(height: 12),
                      Text('Veriler yüklenemedi',
                          style: TextStyle(color: _warmMuted)),
                    ],
                  ),
                ),
                data: (tickets) {
                  if (tickets.isEmpty) {
                    return _buildEmptyState();
                  }
                  return _buildTicketList(tickets);
                },
              ),
            ),
          ],
        ),
      ),

      // ── FAB ───────────────────────────────────────────────────────
      floatingActionButton: ScaleTransition(
        scale: _fabScale,
        alignment: Alignment.bottomRight,
        child: FloatingActionButton.extended(
          onPressed: () => _openCreateSheet(context),
          backgroundColor: _amber,
          foregroundColor: Colors.white,
          elevation: 4,
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'Destek İstiyorum',  // ✅ DÜZELTILDI — PRD §4.2.2 ile uyumlu
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
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
            ),
            child: Icon(Icons.check_circle_outline_rounded,
                color: _sage, size: 56),
          ),
          const SizedBox(height: 20),
          const Text(
            'Her şey yolunda!',
            style: TextStyle(
              color: _warmWhite, fontSize: 20, fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Açık destek talebiniz bulunmuyor.',
            style: TextStyle(color: _warmMuted, fontSize: 14),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTicketList(List<TenantSupportTicket> tickets) {
    return RefreshIndicator(
      color: _amber,
      backgroundColor: _surface,
      onRefresh: () => ref.read(tenantSupportProvider.notifier).refresh(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        itemCount: tickets.length,
        itemBuilder: (context, index) {
          return _TicketCard(
            ticket: tickets[index],
            index: index,
            onTap: () => _openDetailSheet(context, tickets[index]),
          );
        },
      ),
    );
  }

  void _openCreateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateTicketSheet(
        onCreated: () {
          ref.read(tenantSupportProvider.notifier).refresh();
        },
      ),
    );
  }

  void _openDetailSheet(BuildContext context, TenantSupportTicket ticket) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TicketDetailSheet(
        ticketId: ticket.id,
        onUpdated: () => ref.read(tenantSupportProvider.notifier).refresh(),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// _TicketCard
// ──────────────────────────────────────────────
class _TicketCard extends StatelessWidget {
  final TenantSupportTicket ticket;
  final int index;
  final VoidCallback onTap;

  const _TicketCard({required this.ticket, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sColor = _statusColor(ticket.status);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 60)),
      curve: Curves.easeOutCubic,
      builder: (context, anim, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - anim)),
          child: Opacity(opacity: anim, child: child),
        );
      },
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: sColor.withValues(alpha: 0.25),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: sColor.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
                child: Row(
                  children: [
                    // Status chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: sColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: sColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_statusIcon(ticket.status),
                              color: sColor, size: 12),
                          const SizedBox(width: 5),
                          Text(
                            _statusLabel(ticket.status),
                            style: TextStyle(
                              color: sColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (ticket.priority == 'high' || ticket.priority == 'urgent')
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _coral.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Öncelikli',
                          style: TextStyle(
                            color: _coral, fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right, color: _warmHint, size: 20),
                  ],
                ),
              ),

              // Title + location
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.title,
                      style: const TextStyle(
                        color: _warmWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (ticket.propertyName != null || ticket.unitDoor != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                color: _warmMuted, size: 12),
                            const SizedBox(width: 3),
                            Text(
                              [ticket.propertyName, ticket.unitDoor]
                                  .whereType<String>()
                                  .join(' – '),
                              style: const TextStyle(
                                  color: _warmMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // Last message preview
              if (ticket.lastMessage != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _surface2,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded,
                            color: _warmHint, size: 12),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            ticket.lastMessage!,
                            style: const TextStyle(
                              color: _warmMuted,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Bottom: date + message count
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: Row(
                  children: [
                    Icon(Icons.access_time_rounded,
                        color: _warmHint, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      _shortDate(ticket.createdAt),
                      style: const TextStyle(color: _warmHint, fontSize: 11),
                    ),
                    const Spacer(),
                    Icon(Icons.comment_outlined,
                        color: _warmHint, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      '${ticket.messageCount} mesaj',
                      style: const TextStyle(color: _warmHint, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _shortDate(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inDays == 0) {
    if (diff.inHours == 0) return '${diff.inMinutes} dk önce';
    return '${diff.inHours} s önce';
  }
  if (diff.inDays == 1) return 'Dün';
  if (diff.inDays < 7) return '${diff.inDays} gün önce';
  return '${dt.day}/${dt.month}/${dt.year}';
}

// ──────────────────────────────────────────────
// _CreateTicketSheet — §4.2.2-A + §4.2.2-B
// ──────────────────────────────────────────────
class _CreateTicketSheet extends ConsumerStatefulWidget {
  final VoidCallback onCreated;

  const _CreateTicketSheet({required this.onCreated});

  @override
  ConsumerState<_CreateTicketSheet> createState() => _CreateTicketSheetState();
}

class _CreateTicketSheetState extends ConsumerState<_CreateTicketSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _titleFocus = FocusNode();
  bool _isLoading = false;
  String? _attachmentPath;
  String? _attachmentUrl;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  Future<void> _pickAndStampImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;

    final path = result.files.single.path;
    if (path == null) return;

    // ✅ EKLENDI — Görsel üzerine timestamp bas (PRD §4.2.2-B)
    final stampedPath = await _stampImageWithTimestamp(path);
    if (stampedPath != null) {
      setState(() => _attachmentPath = stampedPath);
    } else {
      // Timestamp basılamazsa orijinal dosyayı kullan
      setState(() => _attachmentPath = path);
    }
  }

  Future<String?> _stampImageWithTimestamp(String imagePath) async {
    try {
      // Görseli oku
      final bytes = await File(imagePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      // Canvas oluştur
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final size = Size(image.width.toDouble(), image.height.toDouble());

      // Orijinal görseli çiz
      canvas.drawImage(image, Offset.zero, Paint());

      // Timestamp metni oluştur
      final timestamp = _timestampNow();
      final textStyle = TextStyle(
        color: Colors.white,
        fontSize: size.width * 0.03,
        fontWeight: FontWeight.bold,
        shadows: const [
          Shadow(
            offset: Offset(1, 1),
            blurRadius: 3,
            color: Colors.black54,
          ),
        ],
      );

      // Sağ alt köşeye timestamp bas
      final textSpan = TextSpan(text: timestamp, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      // Padding
      final padding = size.width * 0.02;
      final offset = Offset(
        size.width - textPainter.width - padding,
        size.height - textPainter.height - padding,
      );

      // Arka plan kutusu çiz (okunakarlık için)
      final bgRect = Rect.fromLTWH(
        offset.dx - 4,
        offset.dy - 2,
        textPainter.width + 8,
        textPainter.height + 4,
      );
      canvas.drawRect(bgRect, Paint()..color = Colors.black38);

      textPainter.paint(canvas, offset);

      // Kaydet
      final picture = recorder.endRecording();
      final stampedImage = await picture.toImage(
        image.width,
        image.height,
      );
      final pngBytes = await stampedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (pngBytes == null) return null;

      // Geçici dosyaya yaz
      final dir = await getTemporaryDirectory();
      final stampedFile = File(
        '${dir.path}/stamped_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await stampedFile.writeAsBytes(pngBytes.buffer.asUint8List());

      return stampedFile.path;
    } catch (e) {
      debugPrint('Timestamp basma hatası: $e');
      return null;
    }
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen bir başlık yazın'),
          backgroundColor: _coral,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Upload media if attached
    if (_attachmentPath != null) {
      try {
        final formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(
            _attachmentPath!,
            filename: _attachmentPath!.split('/').last,
          ),
          'category': 'support',
        });
        final resp = await ApiClient.dio.post(
          '/media/upload',
          data: formData,
        );
        if (resp.statusCode == 200 && resp.data != null) {
          _attachmentUrl = resp.data['url'];
        }
      } catch (_) {
        // Continue without attachment URL
      }
    }

    final ok = await ref.read(tenantSupportProvider.notifier).createTicket(
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          attachmentUrl: _attachmentUrl,
        );

    if (mounted) {
      setState(() => _isLoading = false);
      if (ok) {
        widget.onCreated();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Talebiniz oluşturuldu'),
            backgroundColor: _sage,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Talep oluşturulamadı'),
            backgroundColor: _coral,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomPad),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: _warmHint, borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            const Row(
              children: [
                Icon(Icons.add_circle_outline_rounded, color: _amber, size: 22),
                SizedBox(width: 8),
                Text(
                  'Yeni Destek Talebi',
                  style: TextStyle(
                    color: _warmWhite, fontSize: 18, fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Arızayı detaylıca açıklayın, fotoğraf ekleyin.',
              style: TextStyle(color: _warmMuted, fontSize: 13),
            ),
            const SizedBox(height: 24),

            // Title field
            const Text('Başlık *',
                style: TextStyle(color: _warmMuted, fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: _titleCtrl,
              focusNode: _titleFocus,
              style: const TextStyle(color: _warmWhite),
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Örn: Kombi sıcak su vermiyor',
                hintStyle: TextStyle(color: _warmHint),
                filled: true,
                fillColor: _surface2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _amber, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 16),

            // Description field
            const Text('Detaylı Açıklama',
                style: TextStyle(color: _warmMuted, fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: _descCtrl,
              style: const TextStyle(color: _warmWhite),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Sorunu daha detaylı açıklayın...',
                hintStyle: TextStyle(color: _warmHint),
                filled: true,
                fillColor: _surface2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _amber, width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 20),

            // §4.2.2-B — Media attachment with timestamp stamp
            const Text('Kanıt / Fotoğraf Ekle',
                style: TextStyle(color: _warmMuted, fontSize: 12)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickAndStampImage,
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  color: _surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _warmHint.withValues(alpha: 0.3),
                    width: 1,
                    style: BorderStyle.solid,
                  ),
                ),
                child: _attachmentPath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(
                              File(_attachmentPath!),
                              fit: BoxFit.cover,
                            ),
                            // Timestamp overlay
                            Positioned(
                              bottom: 0, left: 0, right: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.7),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                                child: Text(
                                  '📅 ${_timestampNow()}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            // Remove button
                            Positioned(
                              top: 4, right: 4,
                              child: GestureDetector(
                                onTap: () => setState(() => _attachmentPath = null),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: _coral.withValues(alpha: 0.9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close,
                                      color: Colors.white, size: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_outlined,
                              color: _warmMuted, size: 28),
                          const SizedBox(height: 6),
                          Text(
                            'Fotoğraf çek veya galeriden seç',
                            style: TextStyle(
                                color: _warmMuted, fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tarih/Saat otomatik eklenir',
                            style: TextStyle(
                                color: _warmHint, fontSize: 11),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _amber,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send_rounded, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Talebi Gönder',
                            style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timestampNow() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }
}

// ──────────────────────────────────────────────
// _TicketDetailSheet — §4.2.2-C Timeline + Reply
// ──────────────────────────────────────────────
class _TicketDetailSheet extends ConsumerStatefulWidget {
  final String ticketId;
  final VoidCallback onUpdated;

  const _TicketDetailSheet({
    required this.ticketId,
    required this.onUpdated,
  });

  @override
  ConsumerState<_TicketDetailSheet> createState() => _TicketDetailSheetState();
}

class _TicketDetailSheetState extends ConsumerState<_TicketDetailSheet> {
  TenantSupportTicket? _ticket;
  bool _isLoading = true;
  bool _isReplying = false;
  final _replyCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final ticket = await ref
        .read(tenantSupportProvider.notifier)
        .fetchTicketDetail(widget.ticketId);
    if (mounted) {
      setState(() {
        _ticket = ticket;
        _isLoading = false;
      });
    }
  }

  Future<void> _sendReply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _isReplying = true);
    final ok = await ref.read(tenantSupportProvider.notifier).replyToTicket(
          widget.ticketId,
          text,
        );
    if (mounted) {
      setState(() => _isReplying = false);
      if (ok) {
        _replyCtrl.clear();
        await _load();
        widget.onUpdated();
        // Scroll to bottom
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.animateTo(
              _scrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    final sColor = _ticket != null
        ? _statusColor(_ticket!.status)
        : _warmMuted;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle + header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: _warmHint, borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: sColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_statusIcon(_ticket?.status ?? TenantTicketStatus.open),
                          color: sColor, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_ticket != null)
                            Text(
                              _ticket!.title,
                              style: const TextStyle(
                                color: _warmWhite, fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          else
                            Container(
                              width: 120, height: 16,
                              decoration: BoxDecoration(
                                color: _surface2, borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          const SizedBox(height: 2),
                          if (_ticket != null)
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: sColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _statusLabel(_ticket!.status),
                                    style: TextStyle(
                                        color: sColor, fontSize: 11,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if (_ticket!.propertyName != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '${_ticket!.propertyName} ${_ticket!.unitDoor ?? ''}',
                                    style: const TextStyle(
                                        color: _warmMuted, fontSize: 11),
                                  ),
                                ],
                              ],
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: _warmMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(color: _surface2, height: 1),

          // Timeline / messages
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _amber))
                : _ticket == null
                    ? const Center(
                        child: Text('Bilet yüklenemedi',
                            style: TextStyle(color: _warmMuted)))
                    : _ticket!.messages.isEmpty
                        ? _buildEmptyTimeline()
                        : _buildTimeline(),
          ),

          // Reply bar
          Container(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottomPad),
            decoration: BoxDecoration(
              color: _surface,
              border: Border(top: BorderSide(color: _surface2, width: 1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyCtrl,
                    style: const TextStyle(color: _warmWhite, fontSize: 14),
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 3,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: 'Yanıtınızı yazın...',
                      hintStyle: TextStyle(color: _warmHint),
                      filled: true,
                      fillColor: _surface2,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _isReplying ? null : _sendReply,
                  child: Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      color: _isReplying ? _amberDim : _amber,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: _isReplying
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5,
                            ),
                          )
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTimeline() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, color: _warmHint, size: 48),
          const SizedBox(height: 12),
          const Text(
            'Henüz mesaj yok',
            style: TextStyle(color: _warmMuted, fontSize: 14),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ofis yanıt bekliyor...',
            style: TextStyle(color: _warmHint, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    return ListView.builder(
      controller: _scrollCtrl,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _ticket!.messages.length,
      itemBuilder: (context, index) {
        final msg = _ticket!.messages[index];
        final isAgent = msg.isAgent;
        return _TimelineItem(
          message: msg.message,
          senderName: msg.senderName ?? (isAgent ? 'Emlak Ofisi' : 'Siz'),
          timestamp: msg.createdAt,
          isAgent: isAgent,
          hasAttachment: msg.attachmentUrl != null,
          attachmentUrl: msg.attachmentUrl,
          index: index,
        );
      },
    );
  }
}

// ──────────────────────────────────────────────
// _TimelineItem
// ──────────────────────────────────────────────
class _TimelineItem extends StatelessWidget {
  final String message;
  final String senderName;
  final DateTime timestamp;
  final bool isAgent;
  final bool hasAttachment;
  final String? attachmentUrl;
  final int index;

  const _TimelineItem({
    required this.message,
    required this.senderName,
    required this.timestamp,
    required this.isAgent,
    required this.hasAttachment,
    this.attachmentUrl,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOutCubic,
      builder: (context, anim, child) {
        return Opacity(
          opacity: anim,
          child: Transform.translate(
            offset: Offset(isAgent ? -12.0 : 12.0, 0),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment:
              isAgent ? MainAxisAlignment.start : MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isAgent) ...[
              CircleAvatar(
                radius: 14,
                backgroundColor: _amber.withValues(alpha: 0.2),
                child: const Icon(Icons.support_agent_rounded,
                    color: _amber, size: 16),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment:
                    isAgent ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                children: [
                  // Sender name + time
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 4, right: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          senderName,
                          style: TextStyle(
                            color: isAgent ? _amber : _warmMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _shortTime(timestamp),
                          style: const TextStyle(color: _warmHint, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  // Bubble
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.65,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isAgent
                          ? _amber.withValues(alpha: 0.12)
                          : _surface2,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft:
                            Radius.circular(isAgent ? 4 : 16),
                        bottomRight:
                            Radius.circular(isAgent ? 16 : 4),
                      ),
                      border: isAgent
                          ? Border.all(
                              color: _amber.withValues(alpha: 0.2), width: 1)
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message,
                          style: const TextStyle(
                            color: _warmWhite, fontSize: 14,
                          ),
                        ),
                        if (hasAttachment && attachmentUrl != null) ...[
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              attachmentUrl!,
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 80,
                                color: _surface,
                                child: const Center(
                                  child: Icon(Icons.broken_image_outlined,
                                      color: _warmHint),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (!isAgent) ...[
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 14,
                backgroundColor: _surface2,
                child: const Icon(Icons.person_rounded,
                    color: _warmMuted, size: 16),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _shortTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
