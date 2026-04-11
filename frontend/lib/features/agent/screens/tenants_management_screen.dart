import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/colors.dart';
import '../../../core/network/api_client.dart';

/// Kiracı ve Ev Sahibi Yönetim Ekranı - PRD §4.1.4
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
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _tenants = [];
  List<Map<String, dynamic>> _landlords = [];
  List<Map<String, dynamic>> _properties = [];
  Map<String, dynamic>? _selectedProperty;
  Map<String, dynamic>? _selectedUnit;

  bool _isLoading = true;
  bool _isCreatingTenant = false;
  bool _isCreatingLandlord = false;
  String? _error;

  // Form Controllers
  final _tenantNameController = TextEditingController();
  final _tenantPhoneController = TextEditingController();
  final _tenantRentController = TextEditingController();
  final _landlordNameController = TextEditingController();
  final _landlordPhoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch tenants
      final tenantsResponse = await ApiClient.dio.get('/tenants');
      // Fetch landlords
      final landlordsResponse = await ApiClient.dio.get('/tenants/landlords');
      // Fetch properties for dropdown
      final propertiesResponse = await ApiClient.dio.get('/properties');

      setState(() {
        _tenants = tenantsResponse.data ?? [];
        _landlords = landlordsResponse.data ?? [];
        _properties = propertiesResponse.data ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _createTenant() async {
    if (_selectedUnit == null) {
      _showError('Lütfen önce birim seçin');
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
        'end_date': DateTime.now().add(const Duration(days: 365)).toIso8601String().split('T')[0],
      });

      if (response.statusCode == 201) {
        _showSuccess('Kiracı başarıyla oluşturuldu');
        _tenantNameController.clear();
        _tenantPhoneController.clear();
        _tenantRentController.clear();
        Navigator.pop(context);
        await _fetchAll();
      }
    } catch (e) {
      _showError('Kiracı oluşturulamadı: $e');
    } finally {
      setState(() => _isCreatingTenant = false);
    }
  }

  Future<void> _createLandlord() async {
    if (_selectedProperty == null) {
      _showError('Lütfen önce mülk seçin');
      return;
    }

    setState(() => _isCreatingLandlord = true);

    try {
      // Get all units of selected property
      final propertyResponse = await ApiClient.dio.get('/properties/${_selectedProperty!['id']}');
      final units = propertyResponse.data['units'] ?? [];

      final unitIds = (units as List).map((u) => u['id']).toList();

      final response = await ApiClient.dio.post('/tenants/landlords', data: {
        'unit_ids': unitIds,
        'temp_name': _landlordNameController.text,
        'temp_phone': _landlordPhoneController.text,
        'ownership_share': 100,
      });

      if (response.statusCode == 201) {
        _showSuccess('Ev sahibi başarıyla oluşturuldu');
        _landlordNameController.clear();
        _landlordPhoneController.clear();
        Navigator.pop(context);
        await _fetchAll();
      }
    } catch (e) {
      _showError('Ev sahibi oluşturulamadı: $e');
    } finally {
      setState(() => _isCreatingLandlord = false);
    }
  }

  Future<void> _sendInvitation(String targetRole, String name, String phone, String? unitId) async {
    try {
      // Create invitation
      final response = await ApiClient.dio.post('/auth/invite', data: {
        'agency_id': '137c7e1d-f87d-47c9-9e20-3f60ad33abfe', // TODO: Get from auth
        'target_role': targetRole,
        'related_entity_id': unitId,
      });

      if (response.statusCode == 200) {
        final inviteUrl = response.data['invite_url'];
        final message = targetRole == 'tenant'
            ? 'Emlakdefter sistemine kaydınız açılmıştır. Kira takibinizi yapmak için tıklayın: $inviteUrl'
            : 'Değerli mülk sahibimiz, gayrimenkullerinizin finansal raporlarını ve bakım süreçlerini şeffafça takip etmek için tıklayın: $inviteUrl';

        // Copy to clipboard
        await Clipboard.setData(ClipboardData(text: message));

        if (mounted) {
          showModalBottomSheet(
            context: context,
            backgroundColor: AppColors.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (ctx) => Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Davet Bağlantısı Hazır', style: TextStyle(
                    color: AppColors.textHeader, fontSize: 18, fontWeight: FontWeight.bold,
                  )),
                  const SizedBox(height: 8),
                  Text(message, style: TextStyle(color: AppColors.textBody.withValues(alpha: 0.7), fontSize: 12)),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: message));
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Kopyalandı!'), backgroundColor: AppColors.success),
                            );
                          },
                          icon: const Icon(Icons.copy),
                          label: const Text('Kopyala'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.accent,
                            side: const BorderSide(color: AppColors.accent),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final encodedMsg = Uri.encodeComponent(message);
                            final waUrl = 'https://wa.me/?text=$encodedMsg';
                            if (await canLaunchUrl(Uri.parse(waUrl))) {
                              await launchUrl(Uri.parse(waUrl), mode: LaunchMode.externalApplication);
                            } else {
                              await Clipboard.setData(ClipboardData(text: message));
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('WhatsApp açılamadı, link kopyalandı'), backgroundColor: AppColors.warning),
                              );
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          icon: const Icon(Icons.send),
                          label: const Text('WhatsApp'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
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
      }
    } catch (e) {
      _showError('Davet oluşturulamadı: $e');
    }
  }

  Future<void> _deactivateTenant(String tenantId) async {
    try {
      final response = await ApiClient.dio.post('/tenants/$tenantId/deactivate');

      if (response.statusCode == 200) {
        _showSuccess('Kiracı pasif hale getirildi');
        await _fetchAll();
      }
    } catch (e) {
      _showError('İşlem başarısız: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tenantNameController.dispose();
    _tenantPhoneController.dispose();
    _tenantRentController.dispose();
    _landlordNameController.dispose();
    _landlordPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textHeader,
        title: const Text(
          'Kiracı & Ev Sahibi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.refresh, size: 20),
            ),
            onPressed: _fetchAll,
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textBody,
          tabs: const [
            Tab(text: 'Kiracılar', icon: Icon(Icons.person)),
            Tab(text: 'Ev Sahipleri', icon: Icon(Icons.person_outline)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text('Hata: $_error', style: TextStyle(color: AppColors.textBody)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchAll,
                        child: const Text('Tekrar dene'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTenantsList(),
                    _buildLandlordsList(),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Yeni Ekle'),
      ),
    );
  }

  Widget _buildTenantsList() {
    if (_tenants.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: AppColors.textBody),
            const SizedBox(height: 16),
            Text(
              'Henüz kiracı yok',
              style: TextStyle(color: AppColors.textBody, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchAll,
      color: AppColors.accent,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: _tenants.length + 1,
        itemBuilder: (context, index) {
          if (index == _tenants.length) return const SizedBox(height: 100);
          final tenant = _tenants[index];
          return _buildTenantCard(tenant);
        },
      ),
    );
  }

  Widget _buildTenantCard(Map<String, dynamic> tenant) {
    final isActive = tenant['is_active'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? AppColors.success.withOpacity(0.3) : AppColors.textBody.withOpacity(0.2),
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
                  color: (isActive ? AppColors.success : AppColors.textBody).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person,
                  color: isActive ? AppColors.success : AppColors.textBody,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tenant['temp_name'] ?? 'İsimsiz Kiracı',
                      style: TextStyle(
                        color: AppColors.textHeader,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${tenant['property_name'] ?? '-'} • Kapı ${tenant['unit_door_number'] ?? '-'}',
                      style: TextStyle(
                        color: AppColors.textBody,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isActive ? AppColors.success : AppColors.textBody).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isActive ? 'Aktif' : 'Pasif',
                  style: TextStyle(
                    color: isActive ? AppColors.success : AppColors.textBody,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildInfoChip(Icons.payments, '${tenant['rent_amount'] ?? 0} ₺'),
              const SizedBox(width: 8),
              _buildInfoChip(Icons.calendar_today, 'Ödeme günü: ${tenant['payment_day'] ?? 1}'),
            ],
          ),
          if (isActive) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _sendInvitation(
                      'tenant',
                      tenant['temp_name'] ?? '',
                      tenant['temp_phone'] ?? '',
                      tenant['unit_id'],
                    ),
                    icon: const Icon(Icons.send, size: 16),
                    label: const Text('Davet Gönder'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.success,
                      side: BorderSide(color: AppColors.success.withOpacity(0.5)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _deactivateTenant(tenant['id']),
                  icon: const Icon(Icons.person_off, size: 16),
                  label: const Text('Fesih'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(color: AppColors.error.withOpacity(0.5)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLandlordsList() {
    if (_landlords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off_outlined, size: 64, color: AppColors.textBody),
            const SizedBox(height: 16),
            Text(
              'Henüz ev sahibi yok',
              style: TextStyle(color: AppColors.textBody, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchAll,
      color: AppColors.accent,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: _landlords.length + 1,
        itemBuilder: (context, index) {
          if (index == _landlords.length) return const SizedBox(height: 100);
          final landlord = _landlords[index];
          return _buildLandlordCard(landlord);
        },
      ),
    );
  }

  Widget _buildLandlordCard(Map<String, dynamic> landlord) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_outline,
                  color: AppColors.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      landlord['temp_name'] ?? 'İsimsiz Ev Sahibi',
                      style: TextStyle(
                        color: AppColors.textHeader,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${landlord['property_name'] ?? '-'} • Kapı ${landlord['unit_door_number'] ?? '-'}',
                      style: TextStyle(
                        color: AppColors.textBody,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '%${landlord['ownership_share'] ?? 100}',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _sendInvitation(
              'landlord',
              landlord['temp_name'] ?? '',
              landlord['temp_phone'] ?? '',
              landlord['unit_id'],
            ),
            icon: const Icon(Icons.send, size: 16),
            label: const Text('Davet Gönder'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: BorderSide(color: AppColors.accent.withOpacity(0.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.accent),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(color: AppColors.accent, fontSize: 11),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textBody.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Yeni Kişi Ekle',
                    style: TextStyle(
                      color: AppColors.textHeader,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textBody),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Expanded(
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    const TabBar(
                      indicatorColor: AppColors.accent,
                      labelColor: AppColors.accent,
                      unselectedLabelColor: AppColors.textBody,
                      tabs: [
                        Tab(text: 'Kiracı'),
                        Tab(text: 'Ev Sahibi'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildTenantForm(ctx),
                          _buildLandlordForm(ctx),
                        ],
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

  Widget _buildTenantForm(BuildContext ctx) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mülk Seçin',
            style: TextStyle(color: AppColors.textBody, fontSize: 12),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<Map<String, dynamic>>(
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            dropdownColor: AppColors.surface,
            hint: Text('Mülk seçin', style: TextStyle(color: AppColors.textBody)),
            items: _properties.map((p) {
              return DropdownMenuItem(
                value: p,
                child: Text(p['name'], style: TextStyle(color: AppColors.textHeader)),
              );
            }).toList(),
            onChanged: (property) async {
              if (property != null) {
                setState(() {
                  _selectedProperty = property;
                  _selectedUnit = null;
                });
                // Fetch units for this property
                final response = await ApiClient.dio.get('/properties/${property['id']}');
                setState(() {
                  _selectedUnit = null;
                });
              }
            },
          ),
          const SizedBox(height: 20),
          Text(
            'Kiracı Bilgileri',
            style: TextStyle(color: AppColors.textBody, fontSize: 12),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _tenantNameController,
            style: TextStyle(color: AppColors.textHeader),
            decoration: InputDecoration(
              hintText: 'Ad Soyad',
              hintStyle: TextStyle(color: AppColors.textBody.withOpacity(0.5)),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tenantPhoneController,
            keyboardType: TextInputType.phone,
            style: TextStyle(color: AppColors.textHeader),
            decoration: InputDecoration(
              hintText: 'Telefon Numarası',
              hintStyle: TextStyle(color: AppColors.textBody.withOpacity(0.5)),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tenantRentController,
            keyboardType: TextInputType.number,
            style: TextStyle(color: AppColors.textHeader),
            decoration: InputDecoration(
              hintText: 'Kira Bedeli (₺)',
              hintStyle: TextStyle(color: AppColors.textBody.withOpacity(0.5)),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isCreatingTenant ? null : _createTenant,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isCreatingTenant
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Kiracı Oluştur', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLandlordForm(BuildContext ctx) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ev Sahibi Bilgileri',
            style: TextStyle(color: AppColors.textBody, fontSize: 12),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _landlordNameController,
            style: TextStyle(color: AppColors.textHeader),
            decoration: InputDecoration(
              hintText: 'Ad Soyad',
              hintStyle: TextStyle(color: AppColors.textBody.withOpacity(0.5)),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _landlordPhoneController,
            keyboardType: TextInputType.phone,
            style: TextStyle(color: AppColors.textHeader),
            decoration: InputDecoration(
              hintText: 'Telefon Numarası',
              hintStyle: TextStyle(color: AppColors.textBody.withOpacity(0.5)),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isCreatingLandlord ? null : _createLandlord,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isCreatingLandlord
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Ev Sahibi Oluştur', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
