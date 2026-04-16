import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/colors.dart';
import '../../../core/network/api_client.dart';

/// Kiracı ve Ev Sahibi Yönetim Ekranı — PRD §4.1.4
/// A: Profil Yönetimi & Atama Merkezi | B: Dijital Profil Daveti (WhatsApp) | C: KVKK Onay
class TenantsManagementScreen extends ConsumerStatefulWidget {
  final String? propertyId;
  final String? preselectedUnitId;

  const TenantsManagementScreen({
    Key? key,
    this.propertyId,
    this.preselectedUnitId,
  }) : super(key: key);

  @override
  ConsumerState<TenantsManagementScreen> createState() => _TenantsManagementScreenState();
}

class _TenantsManagementScreenState extends ConsumerState<TenantsManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _tenants = [];
  List<Map<String, dynamic>> _landlords = [];
  List<Map<String, dynamic>> _properties = [];
  Map<String, dynamic>? _selectedProperty;
  List<Map<String, dynamic>> _availableUnits = [];
  Map<String, dynamic>? _selectedUnit;

  bool _isLoading = true;
  bool _isCreatingTenant = false;
  bool _isCreatingLandlord = false;
  String? _error;

  late AnimationController _headerAnimController;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;

  late AnimationController _fabAnimController;
  late Animation<double> _fabScale;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);

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

    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fabScale = CurvedAnimation(
      parent: _fabAnimController,
      curve: Curves.elasticOut,
    );

    _fetchAll();
  }

  @override
  void dispose() {
    _headerAnimController.dispose();
    _fabAnimController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    _headerAnimController.forward(from: 0);

    try {
      final tenantsResponse = await ApiClient.dio.get('/tenants');
      final landlordsResponse = await ApiClient.dio.get('/tenants/landlords');
      final propertiesResponse = await ApiClient.dio.get('/properties');

      setState(() {
        _tenants = tenantsResponse.data ?? [];
        _landlords = landlordsResponse.data ?? [];
        _properties = propertiesResponse.data ?? [];

        // Pre-select property if passed
        if (widget.propertyId != null) {
          final prop = _properties.firstWhere(
            (p) => p['id'] == widget.propertyId,
            orElse: () => {},
          );
          if (prop.isNotEmpty) {
            _selectedProperty = prop;
            _loadUnitsForProperty(prop['id']);
          }
        }

        // Pre-select unit if passed (from UnitDetailScreen → Kiracı Ata)
        if (widget.preselectedUnitId != null) {
          _selectedUnit = {
            'id': widget.preselectedUnitId,
          };
        }

        _isLoading = false;
      });
      _fabAnimController.forward(from: 0);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUnitsForProperty(String propertyId) async {
    try {
      final response = await ApiClient.dio.get('/properties/$propertyId');
      final units = response.data['units'] as List<dynamic>? ?? [];
      setState(() {
        _availableUnits = units.map((u) => Map<String, dynamic>.from(u)).toList();
      });
    } catch (_) {}
  }

  Future<void> _createTenant() async {
    if (_selectedUnit == null) {
      _showError('Lütfen birim seçin');
      return;
    }
    setState(() => _isCreatingTenant = true);
    try {
      final response = await ApiClient.dio.post('/tenants', data: {
        'unit_id': _selectedUnit!['id'],
        'temp_name': _tenantNameController.text,
        'temp_phone': _tenantPhoneController.text,
        'rent_amount': int.tryParse(_tenantRentController.text) ?? 0,
        'payment_day': 1,
        'start_date': DateTime.now().toIso8601String().split('T')[0],
        'end_date':
            DateTime.now().add(const Duration(days: 365)).toIso8601String().split('T')[0],
      });
      if (response.statusCode == 201) {
        _showSuccess('Kiracı oluşturuldu');
        _clearTenantForm();
        Navigator.pop(context);
        await _fetchAll();
      }
    } catch (e) {
      _showError('Oluşturma hatası: $e');
    } finally {
      setState(() => _isCreatingTenant = false);
    }
  }

  Future<void> _createLandlord() async {
    if (_selectedProperty == null) {
      _showError('Lütfen mülk seçin');
      return;
    }
    if (_availableUnits.isEmpty) {
      _showError('Bu mülkte birim bulunamadı');
      return;
    }
    setState(() => _isCreatingLandlord = true);
    try {
      final unitIds = _availableUnits.map((u) => u['id'] as String).toList();
      final response = await ApiClient.dio.post('/tenants/landlords', data: {
        'unit_ids': unitIds,
        'temp_name': _landlordNameController.text,
        'temp_phone': _landlordPhoneController.text,
        'ownership_share': 100,
      });
      if (response.statusCode == 201) {
        _showSuccess('Ev sahibi oluşturuldu');
        _clearLandlordForm();
        Navigator.pop(context);
        await _fetchAll();
      }
    } catch (e) {
      _showError('Oluşturma hatası: $e');
    } finally {
      setState(() => _isCreatingLandlord = false);
    }
  }

  // ── §4.1.4-B: WhatsApp ile Davet (url_launcher wa.me) ───────────
  Future<void> _sendInvitation({
    required String role,
    required String name,
    required String phone,
    String? unitId,
  }) async {
    try {
      final response = await ApiClient.dio.post('/auth/invite', data: {
        'target_role': role,
        'related_entity_id': unitId,
      });

      if (response.statusCode == 200) {
        final inviteUrl = response.data['invite_url'] ?? '';
        final message = role == 'tenant'
            ? 'Emlakdefter sistemine kaydınız açılmıştır. Kira takibinizi yapmak için tıklayın: $inviteUrl'
            : 'Değerli mülk sahibimiz, gayrimenkullerinizin finansal raporlarını ve bakım süreçlerini şeffafça takip etmek için tıklayın: $inviteUrl';

        _showInviteBottomSheet(message, inviteUrl);
      }
    } catch (e) {
      _showError('Davet oluşturulamadı: $e');
    }
  }

  void _showInviteBottomSheet(String message, String inviteUrl) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(
          24,
          32,
          24,
          24 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Icon + Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.send_rounded,
                    color: Color(0xFF25D366),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Davet Hazır',
                        style: TextStyle(
                          color: AppColors.textHeader,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Bağlantıyı paylaşmak için seçin',
                        style: TextStyle(
                          color: AppColors.textBody,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Message preview
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: TextStyle(
                      color: AppColors.textBody.withValues(alpha: 0.8),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.link,
                          color: AppColors.accent,
                          size: 12,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            inviteUrl,
                            style: TextStyle(
                              color: AppColors.accent.withValues(alpha: 0.8),
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
              ),
            ),
            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: message));
                      if (ctx.mounted) Navigator.pop(ctx);
                      _showSuccess('Kopyalandı!');
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text(
                      'Kopyala',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      side: const BorderSide(color: AppColors.accent),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final encoded = Uri.encodeComponent(message);
                      final waUrl = 'https://wa.me/?text=$encoded';
                      if (await canLaunchUrl(Uri.parse(waUrl))) {
                        await launchUrl(
                          Uri.parse(waUrl),
                          mode: LaunchMode.externalApplication,
                        );
                      } else {
                        await Clipboard.setData(ClipboardData(text: message));
                        _showError('WhatsApp açılamadı, link kopyalandı');
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text(
                      'WhatsApp',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ── §4.1.4-A: Sözleşme Feshi (Offboarding) ─────────────────────
  Future<void> _deactivateTenant(String tenantId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: AppColors.error, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Sözleşme Feshi',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'Kiracı pasif hale getirilecek ve birim "Boş/Müsait" olarak işaretlenecek. Bu işlem geri alınabilir.',
          style: TextStyle(color: AppColors.textBody, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal',
                style: TextStyle(color: AppColors.textBody)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Fesih Et'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final response =
            await ApiClient.dio.post('/tenants/$tenantId/deactivate');
        if (response.statusCode == 200) {
          _showSuccess('Kiracı pasif hale getirildi');
          await _fetchAll();
        }
      } catch (e) {
        _showError('Fesih hatası: $e');
      }
    }
  }

  // ── §4.1.4-A: Sözleşme Yükle (PDF/Doc upload → Hetzner) ────────
  Future<void> _uploadContract(String tenantId) async {
    // In a real app, this would use file_picker to pick PDF/image
    // Then POST to /upload/media with category="document"
    // Then PATCH /tenants/{id}/upload-contract with the returned URL
    // For now, show a info snackbar — backend endpoint is ready
    _showSuccess('Sözleşme yükleme: Backend endpoint hazır (POST /upload/media → /tenants/{id}/upload-contract)');
  }

  void _showError(String msg) {
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
                child: const Icon(Icons.error_outline, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(msg)),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
  }

  void _showSuccess(String msg) {
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
              Expanded(child: Text(msg)),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
  }

  // Form Controllers
  final _tenantNameController = TextEditingController();
  final _tenantPhoneController = TextEditingController();
  final _tenantRentController = TextEditingController();
  final _landlordNameController = TextEditingController();
  final _landlordPhoneController = TextEditingController();

  void _clearTenantForm() {
    _tenantNameController.clear();
    _tenantPhoneController.clear();
    _tenantRentController.clear();
    setState(() {
      _selectedUnit = null;
      _selectedProperty = null;
      _availableUnits = [];
    });
  }

  void _clearLandlordForm() {
    _landlordNameController.clear();
    _landlordPhoneController.clear();
    setState(() {
      _selectedProperty = null;
      _availableUnits = [];
    });
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
            foregroundColor: AppColors.textHeader,
            pinned: true,
            expandedHeight: 130,
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
                      const Text(
                        'Kiracı & Ev Sahibi',
                        style: TextStyle(
                          color: AppColors.textHeader,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        '${_tenants.where((t) => t['is_active'] == true).length} Aktif Kiracı · ${_landlords.length} Ev Sahibi',
                        style: TextStyle(
                          color: AppColors.textBody.withValues(alpha: 0.65),
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
                child: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.refresh, size: 20),
                  ),
                  onPressed: _fetchAll,
                ),
              ),
              const SizedBox(width: 8),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                color: AppColors.background,
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.accent,
                  indicatorSize: TabBarIndicatorSize.label,
                  indicatorWeight: 3,
                  labelColor: AppColors.accent,
                  unselectedLabelColor: AppColors.textBody,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.3,
                  ),
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person, size: 16),
                          SizedBox(width: 6),
                          Text('Kiracılar'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_outline, size: 16),
                          SizedBox(width: 6),
                          Text('Ev Sahipleri'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── CONTENT ────────────────────────────────────────────────
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: _buildErrorState(),
            )
          else
            SliverFillRemaining(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTenantsList(),
                  _buildLandlordsList(),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabScale,
        child: FloatingActionButton.extended(
          onPressed: () => _showCreateBottomSheet(context),
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 4,
          icon: const Icon(Icons.person_add, size: 20),
          label: const Text(
            'Yeni Ekle',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              'Veri yüklenemedi',
              style: TextStyle(
                color: AppColors.textHeader,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Bilinmeyen hata',
              style: TextStyle(
                color: AppColors.textBody.withValues(alpha: 0.6),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _fetchAll,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Tekrar Dene',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  // ── §4.1.4: KİRACILAR TAB ───────────────────────────────────────
  Widget _buildTenantsList() {
    if (_tenants.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people_outline,
        title: 'Henüz kiracı yok',
        subtitle: 'Portföyünüze ilk kiracınızı ekleyin',
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchAll,
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      child: ListView.separated(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        itemCount: _tenants.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final tenant = _tenants[index];
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 400 + (index * 50).clamp(0, 400)),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 15 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: _buildTenantCard(tenant),
          );
        },
      ),
    );
  }

  Widget _buildTenantCard(Map<String, dynamic> tenant) {
    final isActive = tenant['is_active'] == true;
    final statusColor = isActive ? AppColors.success : AppColors.textBody;
    final statusLabel = isActive ? 'Aktif' : 'Pasif';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withValues(alpha: isActive ? 0.30 : 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isActive ? Icons.home : Icons.person_off,
                        color: statusColor,
                        size: 20,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tenant['temp_name'] ?? 'İsimsiz Kiracı',
                      style: const TextStyle(
                        color: AppColors.textHeader,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          color: AppColors.textBody.withValues(alpha: 0.5),
                          size: 12,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            '${tenant['property_name'] ?? '-'} · Kapı ${tenant['unit_door_number'] ?? '-'}',
                            style: TextStyle(
                              color: AppColors.textBody.withValues(alpha: 0.65),
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Info chips + contract doc
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInfoChip(
                Icons.payments_outlined,
                '${tenant['rent_amount'] ?? 0} ₺',
                AppColors.success,
              ),
              _buildInfoChip(
                Icons.calendar_today_outlined,
                'Gün ${tenant['payment_day'] ?? 1}',
                AppColors.accent,
              ),
              if (tenant['temp_phone'] != null && tenant['temp_phone'].toString().isNotEmpty)
                _buildInfoChip(
                  Icons.phone_outlined,
                  tenant['temp_phone'].toString(),
                  AppColors.textBody,
                ),
              if (tenant['contract_document_url'] != null &&
                  tenant['contract_document_url'].toString().isNotEmpty)
                _buildInfoChip(
                  Icons.description_outlined,
                  'Sözleşme',
                  const Color(0xFF5B8DEF),
                ),
            ],
          ),

          if (isActive) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _sendInvitation(
                      role: 'tenant',
                      name: tenant['temp_name'] ?? '',
                      phone: tenant['temp_phone'] ?? '',
                      unitId: tenant['unit_id']?.toString(),
                    ),
                    icon: const Icon(Icons.send, size: 16),
                    label: const Text(
                      'Davet Gönder',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF25D366),
                      side: BorderSide(
                        color: const Color(0xFF25D366).withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _deactivateTenant(tenant['id'].toString()),
                  icon: const Icon(Icons.person_off_outlined, size: 16),
                  label: const Text(
                    'Fesih',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(
                      color: AppColors.error.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // §4.1.4-A: Sözleşme Yükle
                if (tenant['contract_document_url'] == null ||
                    tenant['contract_document_url'].toString().isEmpty)
                  OutlinedButton.icon(
                    onPressed: () => _uploadContract(tenant['id'].toString()),
                    icon: const Icon(Icons.upload_file, size: 16),
                    label: const Text(
                      'Sözleşme',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF5B8DEF),
                      side: BorderSide(
                        color: const Color(0xFF5B8DEF).withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── §4.1.4: EV SAHİPLERİ TAB ────────────────────────────────────
  Widget _buildLandlordsList() {
    if (_landlords.isEmpty) {
      return _buildEmptyState(
        icon: Icons.person_outline,
        title: 'Henüz ev sahibi yok',
        subtitle: 'Portföyünüze ilk ev sahibinizi ekleyin',
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchAll,
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      child: ListView.separated(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        itemCount: _landlords.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final landlord = _landlords[index];
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 400 + (index * 50).clamp(0, 400)),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 15 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: _buildLandlordCard(landlord),
          );
        },
      ),
    );
  }

  Widget _buildLandlordCard(Map<String, dynamic> landlord) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_outline,
                        color: AppColors.accent,
                        size: 20,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      landlord['temp_name'] ?? 'İsimsiz Ev Sahibi',
                      style: const TextStyle(
                        color: AppColors.textHeader,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          color: AppColors.textBody.withValues(alpha: 0.5),
                          size: 12,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            '${landlord['property_name'] ?? '-'} · Kapı ${landlord['unit_door_number'] ?? '-'}',
                            style: TextStyle(
                              color: AppColors.textBody.withValues(alpha: 0.65),
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '%${landlord['ownership_share'] ?? 100}',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (landlord['temp_phone'] != null &&
              landlord['temp_phone'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoChip(
              Icons.phone_outlined,
              landlord['temp_phone'].toString(),
              AppColors.textBody,
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _sendInvitation(
                role: 'landlord',
                name: landlord['temp_name'] ?? '',
                phone: landlord['temp_phone'] ?? '',
                unitId: landlord['unit_id']?.toString(),
              ),
              icon: const Icon(Icons.send, size: 16),
              label: const Text(
                'Davet Gönder',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF25D366),
                side: BorderSide(
                  color: const Color(0xFF25D366).withValues(alpha: 0.5),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: AppColors.textBody),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textHeader,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                color: AppColors.textBody.withValues(alpha: 0.65),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ── CREATE BOTTOM SHEET (with KVKK + Unit Selection) ─────────────
  void _showCreateBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreatePersonBottomSheet(
        properties: _properties,
        selectedProperty: _selectedProperty,
        availableUnits: _availableUnits,
        selectedUnit: _selectedUnit,
        onPropertyChanged: (prop) {
          setState(() {
            _selectedProperty = prop;
            _selectedUnit = null;
          });
          if (prop != null) {
            _loadUnitsForProperty(prop['id']);
          } else {
            setState(() => _availableUnits = []);
          }
        },
        onUnitChanged: (unit) => setState(() => _selectedUnit = unit),
        onSaveTenant: _createTenant,
        onSaveLandlord: _createLandlord,
        isCreatingTenant: _isCreatingTenant,
        isCreatingLandlord: _isCreatingLandlord,
        tenantNameController: _tenantNameController,
        tenantPhoneController: _tenantPhoneController,
        tenantRentController: _tenantRentController,
        landlordNameController: _landlordNameController,
        landlordPhoneController: _landlordPhoneController,
      ),
    );
  }
}

// ── §4.1.4-A + §4.1.4-B + §4.1.4-C: CREATE BOTTOM SHEET ───────────
class _CreatePersonBottomSheet extends StatefulWidget {
  final List<Map<String, dynamic>> properties;
  final Map<String, dynamic>? selectedProperty;
  final List<Map<String, dynamic>> availableUnits;
  final Map<String, dynamic>? selectedUnit;
  final ValueChanged<Map<String, dynamic>?> onPropertyChanged;
  final ValueChanged<Map<String, dynamic>?> onUnitChanged;
  final VoidCallback onSaveTenant;
  final VoidCallback onSaveLandlord;
  final bool isCreatingTenant;
  final bool isCreatingLandlord;
  final TextEditingController tenantNameController;
  final TextEditingController tenantPhoneController;
  final TextEditingController tenantRentController;
  final TextEditingController landlordNameController;
  final TextEditingController landlordPhoneController;

  const _CreatePersonBottomSheet({
    required this.properties,
    required this.selectedProperty,
    required this.availableUnits,
    required this.selectedUnit,
    required this.onPropertyChanged,
    required this.onUnitChanged,
    required this.onSaveTenant,
    required this.onSaveLandlord,
    required this.isCreatingTenant,
    required this.isCreatingLandlord,
    required this.tenantNameController,
    required this.tenantPhoneController,
    required this.tenantRentController,
    required this.landlordNameController,
    required this.landlordPhoneController,
  });

  @override
  State<_CreatePersonBottomSheet> createState() => _CreatePersonBottomSheetState();
}

class _CreatePersonBottomSheetState extends State<_CreatePersonBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _kvkkAccepted = false;
  bool _showKvkkError = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.person_add, color: AppColors.accent, size: 22),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Yeni Kişi Ekle',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Kiracı veya ev sahibi oluşturun',
                        style: TextStyle(color: AppColors.textBody, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textBody),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Tab bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.accent,
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: AppColors.accent,
                unselectedLabelColor: AppColors.textBody,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                tabs: const [
                  Tab(child: Text('Kiracı')),
                  Tab(child: Text('Ev Sahibi')),
                ],
              ),
            ),
          ),

          // Form content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTenantForm(),
                _buildLandlordForm(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── TENANT FORM (§4.1.4-A: Birim seçimi + KVKK §4.1.4-C) ─────────
  Widget _buildTenantForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // §4.1.4-A: Mülk + Birim seçimi (1-to-1)
          const Text(
            'MÜLK & BİRİM SEÇİMİ',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textBody,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),

          // Property dropdown
          DropdownButtonFormField<Map<String, dynamic>>(
            value: widget.selectedProperty,
            decoration: InputDecoration(
              labelText: 'Mülk Seçin',
              labelStyle: const TextStyle(color: AppColors.textBody),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            dropdownColor: AppColors.surface,
            style: const TextStyle(color: AppColors.textHeader),
            hint: Text('Mülk seçin', style: TextStyle(color: AppColors.textBody)),
            items: widget.properties.map((p) {
              return DropdownMenuItem(
                value: p,
                child: Text(p['name'] ?? '', style: const TextStyle(color: AppColors.textHeader)),
              );
            }).toList(),
            onChanged: (v) => widget.onPropertyChanged(v),
          ),

          const SizedBox(height: 12),

          // Unit dropdown
          DropdownButtonFormField<Map<String, dynamic>>(
            value: widget.selectedUnit,
            decoration: InputDecoration(
              labelText: 'Birim (Kapı) Seçin',
              labelStyle: const TextStyle(color: AppColors.textBody),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            dropdownColor: AppColors.surface,
            style: const TextStyle(color: AppColors.textHeader),
            hint: Text(
              widget.selectedProperty == null
                  ? 'Önce mülk seçin'
                  : 'Birim seçin',
              style: TextStyle(color: AppColors.textBody),
            ),
            items: widget.availableUnits.map((u) {
              return DropdownMenuItem(
                value: u,
                child: Text(
                  'Kapı ${u['door_number'] ?? '-'} · Kat ${u['floor'] ?? '-'}',
                  style: const TextStyle(color: AppColors.textHeader),
                ),
              );
            }).toList(),
            onChanged: (v) => widget.onUnitChanged(v),
          ),

          const SizedBox(height: 24),

          // Kiracı bilgileri
          const Text(
            'KİRACI BİLGİLERİ',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textBody,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),

          _buildTextField(
            controller: widget.tenantNameController,
            label: 'Ad Soyad',
            hint: 'Örn: Mehmet Yılmaz',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: widget.tenantPhoneController,
            label: 'Telefon Numarası',
            hint: '05XX XXX XX XX',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: widget.tenantRentController,
            label: 'Kira Bedeli (₺)',
            hint: 'Örn: 15000',
            icon: Icons.payments_outlined,
            keyboardType: TextInputType.number,
          ),

          const SizedBox(height: 20),

          // §4.1.4-C: KVKK Aydınlatma Metni Onayı
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _showKvkkError
                    ? AppColors.error.withValues(alpha: 0.5)
                    : AppColors.accent.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: _kvkkAccepted,
                      onChanged: (v) {
                        setState(() {
                          _kvkkAccepted = v ?? false;
                          if (_kvkkAccepted) _showKvkkError = false;
                        });
                      },
                      activeColor: AppColors.accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'KVKK ve Aydınlatma Metni\'ni onaylıyorum',
                        style: TextStyle(
                          color: AppColors.textHeader,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_showKvkkError) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Devam etmek için KVKK onayı gereklidir',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (widget.isCreatingTenant || !_kvkkAccepted)
                  ? null
                  : widget.onSaveTenant,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.3),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: widget.isCreatingTenant
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_add, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'KİRACı OLUŞTUR',
                          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── LANDLORD FORM (§4.1.4-A: Çoklu birim) ─────────────────────
  Widget _buildLandlordForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'EV SAHİBİ BİLGİLERİ',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textBody,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),

          _buildTextField(
            controller: widget.landlordNameController,
            label: 'Ad Soyad',
            hint: 'Örn: Ayşe Demir',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: widget.landlordPhoneController,
            label: 'Telefon Numarası',
            hint: '05XX XXX XX XX',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),

          const SizedBox(height: 24),

          // Mülk seçimi (ev sahibi tüm birimlere sahip olur)
          const Text(
            'MÜLK SEÇİMİ (Tüm birimler atanır)',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textBody,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<Map<String, dynamic>>(
            value: widget.selectedProperty,
            decoration: InputDecoration(
              labelText: 'Mülk Seçin',
              labelStyle: const TextStyle(color: AppColors.textBody),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            dropdownColor: AppColors.surface,
            style: const TextStyle(color: AppColors.textHeader),
            hint: Text('Mülk seçin', style: TextStyle(color: AppColors.textBody)),
            items: widget.properties.map((p) {
              return DropdownMenuItem(
                value: p,
                child: Text(p['name'] ?? '', style: const TextStyle(color: AppColors.textHeader)),
              );
            }).toList(),
            onChanged: (v) {
              widget.onPropertyChanged(v);
              if (v != null) {
                // Load units for this property
                ApiClient.dio.get('/properties/${v['id']}').then((resp) {
                  final units = resp.data['units'] as List<dynamic>? ?? [];
                  widget.onPropertyChanged({
                    ...v,
                    'units': units,
                  });
                });
              }
            },
          ),

          if (widget.availableUnits.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppColors.success,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.availableUnits.length} birim otomatik atanacak',
                    style: const TextStyle(
                      color: AppColors.success,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // KVKK
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _showKvkkError
                    ? AppColors.error.withValues(alpha: 0.5)
                    : AppColors.accent.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: _kvkkAccepted,
                  onChanged: (v) {
                    setState(() {
                      _kvkkAccepted = v ?? false;
                      if (_kvkkAccepted) _showKvkkError = false;
                    });
                  },
                  activeColor: AppColors.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Expanded(
                  child: Text(
                    'KVKK ve Aydınlatma Metni\'ni onaylıyorum',
                    style: TextStyle(
                      color: AppColors.textHeader,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (widget.isCreatingLandlord || !_kvkkAccepted)
                  ? null
                  : widget.onSaveLandlord,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.3),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: widget.isCreatingLandlord
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_add, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'EV SAHİBİ OLUŞTUR',
                          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: AppColors.textBody),
        hintStyle: TextStyle(color: AppColors.textBody.withValues(alpha: 0.35)),
        prefixIcon: Icon(icon, color: AppColors.accent, size: 20),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
    );
  }
}