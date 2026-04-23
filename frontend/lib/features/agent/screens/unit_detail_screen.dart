import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../../core/theme/colors.dart';
import '../../../core/network/api_client.dart';

/// UnitDetailScreen — PRD §4.1.3 Mülk Künyesi
/// A) Finansal & Temel Künye  B) Özellikler & Etiketler  C) Dijital Varlıklar (Medya)
class UnitDetailScreen extends ConsumerStatefulWidget {
  final String propertyId;
  final String unitId;
  final String propertyName;

  const UnitDetailScreen({
    Key? key,
    required this.propertyId,
    required this.unitId,
    required this.propertyName,
  }) : super(key: key);

  @override
  ConsumerState<UnitDetailScreen> createState() => _UnitDetailScreenState();
}

class _UnitDetailScreenState extends ConsumerState<UnitDetailScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _unit;
  bool _isLoading = true;
  String? _error;

  final _rentController = TextEditingController();
  final _duesController = TextEditingController();
  final _floorController = TextEditingController();
  final _doorController = TextEditingController();
  final _commissionController = TextEditingController();
  final _youtubeController = TextEditingController();

  bool _isEditing = false;
  bool _isSaving = false;

  // Section animation controllers
  late AnimationController _headerAnimController;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;

  late AnimationController _cardAnimController;
  late Animation<double> _cardFade;
  late Animation<Offset> _cardSlide;

  late AnimationController _mediaAnimController;

  @override
  void initState() {
    super.initState();
    _headerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _headerFade = CurvedAnimation(
      parent: _headerAnimController,
      curve: Curves.easeOutCubic,
    );
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _headerAnimController,
      curve: Curves.easeOutCubic,
    ));

    _cardAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _cardFade = CurvedAnimation(
      parent: _cardAnimController,
      curve: Curves.easeOutCubic,
    );
    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _cardAnimController,
      curve: Curves.easeOutCubic,
    ));

    _mediaAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fetchUnit();
  }

  @override
  void dispose() {
    _headerAnimController.dispose();
    _cardAnimController.dispose();
    _mediaAnimController.dispose();
    _rentController.dispose();
    _duesController.dispose();
    _floorController.dispose();
    _doorController.dispose();
    _commissionController.dispose();
    _youtubeController.dispose();
    super.dispose();
  }

  Future<void> _fetchUnit() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    _headerAnimController.forward(from: 0);

    try {
      final response = await ApiClient.dio.get(
        '/properties/${widget.propertyId}/units/${widget.unitId}',
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        setState(() {
          _unit = data;
          _rentController.text = (data['rent_price'] ?? 0).toString();
          _duesController.text = (data['dues_amount'] ?? 0).toString();
          _floorController.text = (data['floor'] ?? '').toString();
          _doorController.text = (data['door_number'] ?? '').toString();
          _commissionController.text =
              ((data['commission_rate'] ?? 0.0) as double).toStringAsFixed(2);
          _youtubeController.text = (data['youtube_video_link'] ?? '') as String;
          _isLoading = false;
        });
        _cardAnimController.forward(from: 0);
        _mediaAnimController.forward(from: 0);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);

    try {
      final response = await ApiClient.dio.patch(
        '/properties/${widget.propertyId}/units/${widget.unitId}',
        data: {
          'rent_price': int.tryParse(_rentController.text) ?? 0,
          'dues_amount': int.tryParse(_duesController.text) ?? 0,
          'floor': _floorController.text,
          'door_number': _doorController.text,
          'commission_rate':
              double.tryParse(_commissionController.text) ?? 0.0,
          'youtube_video_link': _youtubeController.text.trim().isEmpty
              ? null
              : _youtubeController.text.trim(),
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _unit = response.data;
          _isEditing = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  const Text('Değişiklikler kaydedildi'),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kaydetme hatası: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Color get _statusColor {
    if (_unit == null) return AppColors.textSecondary;
    switch (_unit!['status']) {
      case 'occupied':
        return AppColors.success;
      case 'vacant':
        return AppColors.warning;
      case 'maintenance':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  String get _statusLabel {
    if (_unit == null) return '';
    switch (_unit!['status']) {
      case 'occupied':
        return 'Kiracılı';
      case 'vacant':
        return 'Müsait';
      case 'maintenance':
        return 'Bakımda';
      default:
        return _unit!['status'];
    }
  }

  IconData get _statusIcon {
    if (_unit == null) return Icons.home_outlined;
    switch (_unit!['status']) {
      case 'occupied':
        return Icons.home;
      case 'vacant':
        return Icons.home_outlined;
      case 'maintenance':
        return Icons.build;
      default:
        return Icons.home_outlined;
    }
  }

  // PRD §4.1.3-B: Property features
  List<Map<String, dynamic>> get _propertyFeatures {
    if (_unit == null || _unit!['property'] == null) return [];
    final features = _unit!['property']['features'] as Map<String, dynamic>?;
    if (features == null) return [];

    final featureMap = [
      {'key': 'has_elevator', 'label': 'Asansör', 'icon': Icons.elevator},
      {'key': 'has_parking', 'label': 'Otopark', 'icon': Icons.local_parking},
      {'key': 'has_pool', 'label': 'Havuz', 'icon': Icons.pool},
      {'key': 'has_solar', 'label': 'Güneş Enerjisi', 'icon': Icons.solar_power},
      {'key': 'has_security', 'label': 'Güvenlik', 'icon': Icons.security},
      {'key': 'has_garden', 'label': 'Bahçe', 'icon': Icons.park},
      {'key': 'has_balcony', 'label': 'Balkon', 'icon': Icons.balcony},
      {'key': 'has_garage', 'label': 'Garaj', 'icon': Icons.garage},
    ];

    return featureMap
        .where((f) => features[f['key']] == true)
        .map((f) => {'label': f['label'], 'icon': f['icon']})
        .toList();
  }

  // PRD §4.1.3-C: Media items (mock, from unit data)
  List<Map<String, String>> get _mediaItems {
    final links = _unit?['media_links'] as List<dynamic>?;
    if (links == null || links.isEmpty) return [];
    return links.map((e) => Map<String, String>.from(e)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── SLIVER APP BAR ──────────────────────────────────────────
          SliverAppBar(
            backgroundColor: AppColors.background,
            foregroundColor: AppColors.charcoal,
            pinned: true,
            expandedHeight: 140,
            leading: SlideTransition(
              position: _headerSlide,
              child: FadeTransition(
                opacity: _headerFade,
                child: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.arrow_back, size: 20),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 20),
              title: SlideTransition(
                position: _headerSlide,
                child: FadeTransition(
                  opacity: _headerFade,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Kapı ${_unit?['door_number'] ?? '...'}',
                        style: const TextStyle(
                          color: AppColors.charcoal,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.propertyName,
                        style: TextStyle(
                          color: AppColors.textSecondary.withValues(alpha: 0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              FadeTransition(
                opacity: _headerFade,
                child: _isEditing
                    ? Row(
                        children: [
                          TextButton(
                            onPressed: () =>
                                setState(() => _isEditing = false),
                            child: Text(
                              'İptal',
                              style: TextStyle(
                                color: AppColors.textSecondary.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _saveChanges,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.charcoal,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check, size: 16),
                                        SizedBox(width: 4),
                                        Text(
                                          'Kaydet',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      )
                    : IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.edit_outlined, size: 20),
                        ),
                        onPressed: () => setState(() => _isEditing = true),
                      ),
              ),
              const SizedBox(width: 8),
            ],
          ),

          // ── CONTENT ────────────────────────────────────────────────
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.charcoal),
              ),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: _buildErrorState(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // §4.1.3-A STATUS CARD
                  SlideTransition(
                    position: _cardSlide,
                    child: FadeTransition(
                      opacity: _cardFade,
                      child: _buildStatusCard(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // §4.1.3-A: FİNANSAL & TEMEL KÜNYE
                  _buildSectionHeader('A', 'Finansal & Temel Künye'),
                  const SizedBox(height: 12),
                  SlideTransition(
                    position: _cardSlide,
                    child: FadeTransition(
                      opacity: _cardFade,
                      child: _buildFinancialSection(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // §4.1.3-B: ÖZELLİKLER & ETİKETLER
                  _buildSectionHeader('B', 'Özellikler & Etiketler'),
                  const SizedBox(height: 12),
                  SlideTransition(
                    position: _cardSlide,
                    child: FadeTransition(
                      opacity: _cardFade,
                      child: _buildFeaturesSection(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // §4.1.3-C: DİJİTAL VARLIKLAR (MEDYA)
                  _buildSectionHeader('C', 'Dijital Varlıklar'),
                  const SizedBox(height: 12),
                  SlideTransition(
                    position: _cardSlide,
                    child: FadeTransition(
                      opacity: _cardFade,
                      child: _buildMediaSection(),
                    ),
                  ),
                  const SizedBox(height: 100),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final door = _unit?['door_number'] ?? '-';
    final floor = _unit?['floor'] ?? '-';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _statusColor.withValues(alpha: 0.22),
            _statusColor.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _statusColor.withValues(alpha: 0.30),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Status icon
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _statusIcon,
                    color: _statusColor,
                    size: 30,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 18),

          // Door + Floor info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kapı $door · Kat $floor',
                  style: const TextStyle(
                    color: AppColors.charcoal,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.propertyName,
                  style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.65),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _statusColor.withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              _statusLabel,
              style: TextStyle(
                color: _statusColor,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String badge, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.charcoal.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            badge,
            style: const TextStyle(
              color: AppColors.charcoal,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.charcoal,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  // ── §4.1.3-A: FİNANSAL & TEMEL KÜNYE ─────────────────────────────
  Widget _buildFinancialSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        children: [
          // Row 1: Kapı + Kat
          Row(
            children: [
              Expanded(
                child: _buildEditableField(
                  label: 'Kapı Numarası',
                  controller: _doorController,
                  icon: Icons.door_front_door_outlined,
                  enabled: _isEditing,
                ),
              ),
              Container(
                width: 1,
                height: 48,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: Colors.white.withValues(alpha: 0.06),
              ),
              Expanded(
                child: _buildEditableField(
                  label: 'Kat',
                  controller: _floorController,
                  icon: Icons.layers_outlined,
                  enabled: _isEditing,
                ),
              ),
            ],
          ),
          Divider(
            color: Colors.white.withValues(alpha: 0.06),
            height: 28,
          ),

          // Row 2: Kira + Aidat
          Row(
            children: [
              Expanded(
                child: _buildEditableField(
                  label: 'Kira Bedeli',
                  controller: _rentController,
                  icon: Icons.payments_outlined,
                  prefix: '₺ ',
                  keyboardType: TextInputType.number,
                  enabled: _isEditing,
                  accentColor: AppColors.success,
                ),
              ),
              Container(
                width: 1,
                height: 48,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: Colors.white.withValues(alpha: 0.06),
              ),
              Expanded(
                child: _buildEditableField(
                  label: 'Aidat',
                  controller: _duesController,
                  icon: Icons.receipt_long_outlined,
                  prefix: '₺ ',
                  keyboardType: TextInputType.number,
                  enabled: _isEditing,
                  accentColor: AppColors.warning,
                ),
              ),
            ],
          ),
          Divider(
            color: Colors.white.withValues(alpha: 0.06),
            height: 28,
          ),

          // Row 3: Komisyon oranı (§4.1.3-A)
          _buildEditableField(
            label: 'Komisyon Oranı',
            controller: _commissionController,
            icon: Icons.percent,
            suffix: '%',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            enabled: _isEditing,
            accentColor: AppColors.charcoal,
          ),

          Divider(
            color: Colors.white.withValues(alpha: 0.06),
            height: 28,
          ),

          // Row 4: YouTube video link (§4.1.3-C)
          _buildEditableField(
            label: 'YouTube Video Linki',
            controller: _youtubeController,
            icon: Icons.video_library_outlined,
            hint: 'Liste dışı video bağlantısı',
            enabled: _isEditing,
            accentColor: const Color(0xFFFF0000),
          ),
        ],
      ),
    );
  }

  // ── §4.1.3-B: ÖZELLİKLER & ETİKETLER ────────────────────────────
  Widget _buildFeaturesSection() {
    final features = _propertyFeatures;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
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
                  color: AppColors.charcoal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.checklist_rounded,
                  color: AppColors.charcoal,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bina Özellikleri',
                      style: TextStyle(
                        color: AppColors.charcoal,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Mülk genelinde tanımlı teknik olanaklar',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.charcoal.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${features.length} özellik',
                  style: const TextStyle(
                    color: AppColors.charcoal,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (features.isEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.textSecondary.withValues(alpha: 0.4),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Bu mülkte henüz özellik tanımlanmamış',
                    style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: features.asMap().entries.map((entry) {
                final index = entry.key;
                final feature = entry.value;
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(
                    milliseconds: 400 + (index * 60).clamp(0, 300),
                  ),
                  curve: Curves.easeOutCubic,
                  builder: (context, animValue, child) {
                    return Opacity(
                      opacity: animValue,
                      child: Transform.translate(
                        offset: Offset(0, 10 * (1 - animValue)),
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.charcoal.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.charcoal.withValues(alpha: 0.20),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          feature['icon'] as IconData,
                          color: AppColors.charcoal,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          feature['label'] as String,
                          style: const TextStyle(
                            color: AppColors.charcoal,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ── §4.1.3-C: DİJİTAL VARLIKLAR ────────────────────────────────
  Widget _buildMediaSection() {
    final mediaItems = _mediaItems;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // YouTube dahili oynatıcı — §4.1.3-C
          if (_youtubeController.text.isNotEmpty) ...[
            _InlineYoutubePlayer(youtubeUrl: _youtubeController.text),
            const SizedBox(height: 20),
          ],

          // Fotoğraf galerisi
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.charcoal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.photo_library_outlined,
                  color: AppColors.charcoal,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fotoğraf Galerisi',
                      style: TextStyle(
                        color: AppColors.charcoal,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Kronolojik sırayla eklenmiş görseller',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.charcoal.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${mediaItems.length} görsel',
                  style: const TextStyle(
                    color: AppColors.charcoal,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (mediaItems.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add_photo_alternate_outlined,
                      color: AppColors.textSecondary.withValues(alpha: 0.4),
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Henüz fotoğraf eklenmemiş',
                    style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Fotoğraf yüklemek için medya upload kullanın',
                    style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: mediaItems.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final item = mediaItems[index];
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 300 + (index * 60)),
                    curve: Curves.easeOutCubic,
                    builder: (context, animValue, child) {
                      return Opacity(
                        opacity: animValue,
                        child: Transform.scale(
                          scale: 0.85 + (0.15 * animValue),
                          child: child,
                        ),
                      );
                    },
                    child: GestureDetector(
                      onTap: () => _showImagePreview(context, item['url'] ?? ''),
                      child: Container(
                        width: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Container(
                                color: AppColors.background,
                                child: Icon(
                                  Icons.image,
                                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                                  size: 32,
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withValues(alpha: 0.7),
                                      ],
                                    ),
                                  ),
                                  child: Text(
                                    item['caption'] ?? '',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _showImagePreview(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.image,
                      color: AppColors.textSecondary,
                      size: 64,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      'Kapat',
                      style: TextStyle(color: AppColors.textSecondary),
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

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline,
              color: AppColors.error,
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Veri yüklenemedi',
            style: TextStyle(
              color: AppColors.charcoal,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Bilinmeyen hata',
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.6),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _fetchUnit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.charcoal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text(
              'Tekrar Dene',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? prefix,
    String? suffix,
    String? hint,
    TextInputType? keyboardType,
    bool enabled = true,
    Color? accentColor,
  }) {
    final color = accentColor ?? AppColors.charcoal;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 4),
              enabled
                  ? TextField(
                      controller: controller,
                      keyboardType: keyboardType,
                      style: TextStyle(
                        color: AppColors.charcoal,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        hintText: hint,
                        hintStyle: TextStyle(
                          color: AppColors.textSecondary.withValues(alpha: 0.35),
                          fontSize: 15,
                        ),
                        prefixText: prefix,
                        prefixStyle: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        suffixText: suffix,
                        suffixStyle: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  : Text(
                      '${prefix ?? ''}${controller.text}${suffix ?? ''}',
                      style: TextStyle(
                        color: AppColors.charcoal,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ],
          ),
        ),
        if (enabled)
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.charcoal.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.edit,
              color: AppColors.charcoal.withValues(alpha: 0.7),
              size: 12,
            ),
          ),
      ],
    );
  }
}

// ─── YouTube Player Widgets — §4.1.3-C ────────────────────────────────────────

/// Inline YouTube thumbnail + play overlay — video dialog açar
class _InlineYoutubePlayer extends StatelessWidget {
  final String youtubeUrl;

  const _InlineYoutubePlayer({required this.youtubeUrl});

  @override
  Widget build(BuildContext context) {
    final videoId = YoutubePlayer.convertUrlToId(youtubeUrl);
    if (videoId == null) {
      return const SizedBox.shrink();
    }
    final thumbnailUrl = 'https://img.youtube.com/vi/$videoId/0.jpg';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Video Görüntüleyici',
          style: TextStyle(
            color: AppColors.charcoal,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showVideoDialog(context, videoId),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  thumbnailUrl,
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: double.infinity,
                    height: 180,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.video_library,
                      color: Color(0xFFFF0000),
                      size: 48,
                    ),
                  ),
                ),
              ),
              // Play button overlay
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // URL chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.link, size: 12, color: Color(0xFFFF0000)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  youtubeUrl,
                  style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showVideoDialog(BuildContext context, String videoId) {
    showDialog(
      context: context,
      builder: (ctx) => _VideoPreviewDialog(videoId: videoId),
    );
  }
}

/// Full video player dialog
class _VideoPreviewDialog extends StatelessWidget {
  final String videoId;

  const _VideoPreviewDialog({required this.videoId});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.play_circle_fill, color: Color(0xFFFF0000), size: 24),
          SizedBox(width: 10),
          Text(
            'Video Önizleme',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 220,
        child: YoutubePlayer(
          controller: YoutubePlayerController(
            initialVideoId: videoId,
            flags: const YoutubePlayerFlags(
              autoPlay: true,
              mute: false,
              enableCaption: false,
              hideControls: false,
            ),
          ),
          showVideoProgressIndicator: true,
          progressIndicatorColor: const Color(0xFFFF0000),
          progressColors: const ProgressBarColors(
            playedColor: Color(0xFFFF0000),
            handleColor: Color(0xFFFF0000),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Kapat',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}