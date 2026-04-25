import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
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

  // ── Kiracı Ekle Form Controllers (§4.1.4) ────────────────────────
  final _tenantNameController = TextEditingController();
  final _tenantEmailController = TextEditingController();
  final _tenantPhoneController = TextEditingController();
  final _tenantPasswordController = TextEditingController();
  final _tenantRentController = TextEditingController();
  bool _isCreatingTenant = false;

  Future<void> _addPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final bytes = await image.readAsBytes();
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: 'photo.jpg'),
        'category': 'media',
      });
      final resp = await ApiClient.dio.post('/upload/media', data: formData);
      final url = resp.data['url'] as String;

      if (!mounted) return;
      Navigator.pop(context); // close loading

      setState(() {
        final current = List<Map<String, dynamic>>.from(_unit?['media_links'] ?? []);
        current.add({'url': url, 'caption': ''});
        _unit?['media_links'] = current;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fotoğraf eklendi")),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Yükleme hatası: $e")),
      );
    }
  }

  // PRD §4.1.4-A: Document upload
  Future<void> _addDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    // Use name/getName() for cross-platform compatibility; bytes is null on web when path is unavailable
    final fileName = file.name;
    final bytes = file.bytes;
    if (bytes == null) {
      // On web, bytes may be null if path access failed — try xFile approach
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bu dosya web'de seçilemiyor")),
      );
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: fileName),
        'category': 'document',
      });
      final resp = await ApiClient.dio.post('/upload/media', data: formData);
      final url = resp.data['url'] as String;

      if (!mounted) return;
      Navigator.pop(context); // close loading

      setState(() {
        final current = List<Map<String, dynamic>>.from(_unit?['documents'] ?? []);
        current.add({'url': url, 'name': fileName, 'type': file.extension ?? 'file'});
        _unit?['documents'] = current;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Belge eklendi: $fileName")),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Yükleme hatası: $e")),
      );
    }
  }

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
    _tenantNameController.dispose();
    _tenantEmailController.dispose();
    _tenantPhoneController.dispose();
    _tenantPasswordController.dispose();
    _tenantRentController.dispose();
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

  // ── Kiracı Ekle Bottom Sheet — PRD §4.1.4 ─────────────────────────
  Future<void> _showAddTenantSheet() async {
    // Pre-fill rent amount from unit data
    final rentFromUnit = _unit?['rent_price'] ?? '';
    _tenantRentController.text = rentFromUnit.toString();

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddTenantBottomSheet(
        unitId: widget.unitId,
        doorNumber: _unit?['door_number'] ?? '',
        propertyName: widget.propertyName,
        nameController: _tenantNameController,
        emailController: _tenantEmailController,
        phoneController: _tenantPhoneController,
        passwordController: _tenantPasswordController,
        rentController: _tenantRentController,
      ),
    );

    if (result != null) {
      // Tenant created successfully — refresh unit data
      _tenantNameController.clear();
      _tenantEmailController.clear();
      _tenantPhoneController.clear();
      _tenantPasswordController.clear();
      _tenantRentController.clear();
      await _fetchUnit();
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
                  child: const Icon(Icons.person_add, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                const Text('Kiracı oluşturuldu'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
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

  // PRD §4.1.4-A: Document items
  List<Map<String, dynamic>> get _documentItems {
    final docs = _unit?['documents'] as List<dynamic>?;
    if (docs == null || docs.isEmpty) return [];
    return docs.map((e) => Map<String, dynamic>.from(e)).toList();
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
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        widget.propertyName,
                        style: TextStyle(
                          color: AppColors.textSecondary.withValues(alpha: 0.7),
                          fontSize: 10,
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
              if (!_isEditing && _unit?['status'] == 'vacant')
                FadeTransition(
                  opacity: _headerFade,
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person_add, size: 20, color: AppColors.success),
                    ),
                    onPressed: _isCreatingTenant ? null : _showAddTenantSheet,
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
                  const SizedBox(height: 24),

                  // §4.1.4-A: DOKÜMANLAR
                  _buildSectionHeader('D', 'Dokümanlar'),
                  const SizedBox(height: 12),
                  SlideTransition(
                    position: _cardSlide,
                    child: FadeTransition(
                      opacity: _cardFade,
                      child: _buildDocumentSection(),
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
            GestureDetector(
              onTap: _addPhoto,
              child: Stack(
                children: [
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
                  ),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.charcoal,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 18,
                      ),
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

  // PRD §4.1.4-A: DOKÜMANLAR — lease contracts, delivery receipts, etc.
  Widget _buildDocumentSection() {
    final docs = _documentItems;

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
                  Icons.description_outlined,
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
                      'Dokümanlar',
                      style: TextStyle(
                        color: AppColors.charcoal,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Sözleşmeler, teslim tutanakları ve diğer belgeler',
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
                  '${docs.length} belge',
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

          if (docs.isEmpty)
            GestureDetector(
              onTap: _addDocument,
              child: Stack(
                children: [
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
                            Icons.upload_file,
                            color: AppColors.textSecondary.withValues(alpha: 0.4),
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Henüz belge eklenmemiş',
                          style: TextStyle(
                            color: AppColors.textSecondary.withValues(alpha: 0.6),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sözleşme, teslim tutanağı veya diğer belgeler ekleyin',
                          style: TextStyle(
                            color: AppColors.textSecondary.withValues(alpha: 0.4),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.charcoal,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final doc = docs[index];
                return _DocumentTile(
                  name: doc['name'] ?? 'Bilinmeyen',
                  type: doc['type'] ?? 'file',
                  url: doc['url'] ?? '',
                );
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _addDocument,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Yeni Belge Ekle'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.charcoal,
                  side: BorderSide(
                    color: AppColors.charcoal.withValues(alpha: 0.3),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
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

/// Document list tile — §4.1.4-A
class _DocumentTile extends StatelessWidget {
  final String name;
  final String type;
  final String url;

  const _DocumentTile({
    required this.name,
    required this.type,
    required this.url,
  });

  IconData get _icon {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color get _iconColor {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Colors.green;
      default:
        return AppColors.charcoal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_icon, color: _iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.charcoal,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  type.toUpperCase(),
                  style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              // Could open URL in browser - placeholder for now
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Belge: $name")),
              );
            },
            icon: Icon(
              Icons.open_in_new,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Kiracı Ekle Bottom Sheet — PRD §4.1.4 ─────────────────────────────────────

class _AddTenantBottomSheet extends StatefulWidget {
  final String unitId;
  final String doorNumber;
  final String propertyName;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController passwordController;
  final TextEditingController rentController;

  const _AddTenantBottomSheet({
    required this.unitId,
    required this.doorNumber,
    required this.propertyName,
    required this.nameController,
    required this.emailController,
    required this.phoneController,
    required this.passwordController,
    required this.rentController,
  });

  @override
  State<_AddTenantBottomSheet> createState() => _AddTenantBottomSheetState();
}

class _AddTenantBottomSheetState extends State<_AddTenantBottomSheet> {
  bool _isLoading = false;
  String? _error;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 365));
  int _paymentDay = 1;

  Future<void> _submit() async {
    if (widget.nameController.text.trim().isEmpty ||
        widget.emailController.text.trim().isEmpty ||
        widget.passwordController.text.trim().isEmpty ||
        widget.rentController.text.trim().isEmpty) {
      setState(() => _error = "Tüm alanları doldurun");
      return;
    }

    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(widget.emailController.text.trim())) {
      setState(() => _error = "Geçerli bir email adresi girin");
      return;
    }

    if (widget.passwordController.text.trim().length < 8) {
      setState(() => _error = "Şifre en az 8 karakter olmalıdır");
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    try {
      final resp = await ApiClient.dio.post(
        '/tenants/create-with-user',
        data: {
          'unit_id': widget.unitId,
          'name': widget.nameController.text.trim(),
          'email': widget.emailController.text.trim(),
          'phone': widget.phoneController.text.trim().isEmpty
              ? null
              : widget.phoneController.text.trim(),
          'password': widget.passwordController.text,
          'rent_amount': int.tryParse(widget.rentController.text) ?? 0,
          'payment_day': _paymentDay,
          'start_date': _startDate.toIso8601String().split('T')[0],
          'end_date': _endDate.toIso8601String().split('T')[0],
        },
      );

      if (resp.statusCode == 201) {
        if (!mounted) return;
        Navigator.pop(context, resp.data);
      }
    } on DioException catch (e) {
      final msg = e.response?.data?.get('detail') ?? e.message ?? 'Bilinmeyen hata';
      setState(() => _error = msg.toString());
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person_add, color: AppColors.success, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Kiracı Ekle',
                        style: TextStyle(
                          color: AppColors.charcoal,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${widget.propertyName} · Kapı ${widget.doorNumber}',
                        style: TextStyle(
                          color: AppColors.textSecondary.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                ),
              ],
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppColors.error, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Ad Soyad
            _buildField(
              label: 'Ad Soyad',
              controller: widget.nameController,
              icon: Icons.person_outline,
              hint: 'Kiracının tam adı',
            ),
            const SizedBox(height: 14),

            // Email
            _buildField(
              label: 'Email',
              controller: widget.emailController,
              icon: Icons.email_outlined,
              hint: 'ornek@mail.com',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 14),

            // Telefon
            _buildField(
              label: 'Telefon (Opsiyonel)',
              controller: widget.phoneController,
              icon: Icons.phone_outlined,
              hint: '+90 5XX XXX XX XX',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 14),

            // Şifre
            _buildField(
              label: 'Geçici Şifre',
              controller: widget.passwordController,
              icon: Icons.lock_outline,
              hint: 'En az 8 karakter',
              obscureText: true,
            ),
            const SizedBox(height: 14),

            // Kira Bedeli
            _buildField(
              label: 'Kira Bedeli (₺)',
              controller: widget.rentController,
              icon: Icons.payments_outlined,
              hint: 'Aylık kira',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 14),

            // Ödeme günü
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.charcoal.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.calendar_today, color: AppColors.charcoal, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ödeme Günü',
                        style: TextStyle(
                          color: AppColors.textSecondary.withValues(alpha: 0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      DropdownButton<int>(
                        value: _paymentDay,
                        dropdownColor: AppColors.surface,
                        underline: const SizedBox(),
                        isExpanded: true,
                        items: List.generate(28, (i) => i + 1)
                            .map((d) => DropdownMenuItem(value: d, child: Text('$d', style: const TextStyle(color: AppColors.charcoal))))
                            .toList(),
                        onChanged: (v) => setState(() => _paymentDay = v!),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Başlangıç — Bitiş tarih
            Row(
              children: [
                Expanded(
                  child: _buildDateField(
                    label: 'Başlangıç',
                    date: _startDate,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setState(() => _startDate = picked);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDateField(
                    label: 'Bitiş',
                    date: _endDate,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _endDate,
                        firstDate: _startDate,
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setState(() => _endDate = picked);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  disabledBackgroundColor: AppColors.success.withValues(alpha: 0.4),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_add, size: 20),
                          SizedBox(width: 8),
                          Text('Kiracı Oluştur', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    bool obscureText = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.charcoal.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.charcoal, size: 18),
        ),
        const SizedBox(width: 12),
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
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: controller,
                keyboardType: keyboardType,
                obscureText: obscureText,
                style: const TextStyle(color: AppColors.charcoal, fontSize: 15),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.4),
                    fontSize: 14,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                  border: InputBorder.none,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.charcoal.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: AppColors.charcoal, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.6),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
                    style: const TextStyle(color: AppColors.charcoal, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            Icon(Icons.edit, color: AppColors.textSecondary.withValues(alpha: 0.4), size: 14),
          ],
        ),
      ),
    );
  }
}