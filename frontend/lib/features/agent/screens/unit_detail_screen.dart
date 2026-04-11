import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/network/api_client.dart';
import 'tenants_management_screen.dart';

/// Daire/Birim Detay Ekranı - PRD §4.1.3
/// Kira, aidat, kat, kapı numarası, durum ve medya yönetimi
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

class _UnitDetailScreenState extends ConsumerState<UnitDetailScreen> {
  Map<String, dynamic>? _unit;
  bool _isLoading = true;
  String? _error;

  final _rentController = TextEditingController();
  final _duesController = TextEditingController();
  final _floorController = TextEditingController();
  final _doorController = TextEditingController();

  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchUnit();
  }

  Future<void> _fetchUnit() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiClient.dio.get(
        '/properties/${widget.propertyId}/units/${widget.unitId}',
      );

      if (response.statusCode == 200 && response.data != null) {
        setState(() {
          _unit = response.data;
          _rentController.text = (_unit?['rent_price'] ?? 0).toString();
          _duesController.text = (_unit?['dues_amount'] ?? 0).toString();
          _floorController.text = (_unit?['floor'] ?? '').toString();
          _doorController.text = (_unit?['door_number'] ?? '').toString();
          _isLoading = false;
        });
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
              content: const Text('Değişiklikler kaydedildi'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
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
    if (_unit == null) return AppColors.textBody;
    switch (_unit!['status']) {
      case 'occupied':
        return AppColors.success;
      case 'vacant':
        return AppColors.warning;
      case 'maintenance':
        return AppColors.error;
      default:
        return AppColors.textBody;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Premium App Bar
          SliverAppBar(
            backgroundColor: AppColors.background,
            foregroundColor: AppColors.textHeader,
            pinned: true,
            expandedHeight: 120,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Daire Detay',
                    style: TextStyle(
                      color: AppColors.textHeader,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.propertyName,
                    style: TextStyle(
                      color: AppColors.textBody,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (_isEditing)
                TextButton(
                  onPressed: _isSaving ? null : _saveChanges,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accent,
                          ),
                        )
                      : const Text(
                          'Kaydet',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                )
              else
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.edit_outlined, size: 20),
                  ),
                  onPressed: () => setState(() => _isEditing = true),
                ),
              const SizedBox(width: 8),
            ],
          ),

          // Content
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text(
                      'Veri yüklenemedi',
                      style: TextStyle(color: AppColors.textHeader, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _fetchUnit,
                      child: const Text('Tekrar dene'),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Status Card
                  _buildStatusCard(),
                  const SizedBox(height: 20),

                  // Basic Info
                  _buildSectionTitle('Künye Bilgileri'),
                  const SizedBox(height: 12),
                  _buildInfoCard(),
                  const SizedBox(height: 24),

                  // Financial Info
                  _buildSectionTitle('Finansal Bilgiler'),
                  const SizedBox(height: 12),
                  _buildFinancialCard(),
                  const SizedBox(height: 24),

                  // Quick Actions
                  _buildSectionTitle('Hızlı İşlemler'),
                  const SizedBox(height: 12),
                  _buildActionsCard(),
                  const SizedBox(height: 100),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _statusColor.withOpacity(0.3),
            _statusColor.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _unit?['status'] == 'occupied'
                  ? Icons.home
                  : _unit?['status'] == 'vacant'
                      ? Icons.home_outlined
                      : Icons.build,
              color: _statusColor,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kapı No: ${_unit?['door_number'] ?? '-'}',
                  style: TextStyle(
                    color: AppColors.textHeader,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Kat: ${_unit?['floor'] ?? '-'}',
                  style: TextStyle(
                    color: AppColors.textBody,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _statusLabel,
              style: TextStyle(
                color: _statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: AppColors.textHeader,
        fontSize: 16,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          _buildEditableField(
            'Kat Numarası',
            _floorController,
            icon: Icons.layers_outlined,
            enabled: _isEditing,
          ),
          const Divider(color: Colors.white10, height: 32),
          _buildEditableField(
            'Kapı Numarası',
            _doorController,
            icon: Icons.door_front_door_outlined,
            enabled: _isEditing,
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          _buildEditableField(
            'Kira Bedeli (₺)',
            _rentController,
            icon: Icons.payments_outlined,
            prefix: '₺ ',
            keyboardType: TextInputType.number,
            enabled: _isEditing,
          ),
          const Divider(color: Colors.white10, height: 32),
          _buildEditableField(
            'Aidat Tutarı (₺)',
            _duesController,
            icon: Icons.receipt_long_outlined,
            prefix: '₺ ',
            keyboardType: TextInputType.number,
            enabled: _isEditing,
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField(
    String label,
    TextEditingController controller, {
    IconData? icon,
    String? prefix,
    TextInputType? keyboardType,
    bool enabled = true,
  }) {
    return Row(
      children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.accent, size: 20),
          ),
          const SizedBox(width: 16),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppColors.textBody,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              enabled
                  ? TextField(
                      controller: controller,
                      keyboardType: keyboardType,
                      style: TextStyle(
                        color: AppColors.textHeader,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        prefixText: prefix,
                        prefixStyle: TextStyle(
                          color: AppColors.textBody,
                          fontSize: 16,
                        ),
                      ),
                    )
                  : Text(
                      '${prefix ?? ''}${controller.text}',
                      style: TextStyle(
                        color: AppColors.textHeader,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          _buildActionTile(
            icon: Icons.person_add_outlined,
            title: 'Kiracı Ata',
            subtitle: 'Bu daireye yeni kiracı ekle',
            color: AppColors.accent,
            onTap: () {
              // Kiracı atama ekranına git
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TenantsManagementScreen(
                    propertyId: widget.propertyId,
                    preselectedUnitId: widget.unitId,
                  ),
                ),
              );
            },
          ),
          const Divider(color: Colors.white10, height: 24),
          _buildActionTile(
            icon: Icons.message_outlined,
            title: 'Kiracıya Mesaj Gönder',
            subtitle: 'WhatsApp veya uygulama içi mesaj',
            color: AppColors.success,
            onTap: () {
              // Mesaj ekranına git
            },
          ),
          const Divider(color: Colors.white10, height: 24),
          _buildActionTile(
            icon: Icons.history,
            title: 'Ödeme Geçmişi',
            subtitle: 'Bu dairenin tüm ödemelerini gör',
            color: AppColors.warning,
            onTap: () {
              // Ödeme geçmişi ekranına git
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppColors.textHeader,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppColors.textBody,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppColors.textBody,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _rentController.dispose();
    _duesController.dispose();
    _floorController.dispose();
    _doorController.dispose();
    super.dispose();
  }
}

// Placeholder for TenantsManagementScreen - will be created next
class TenantsManagementScreen extends StatelessWidget {
  final String? propertyId;
  final String? preselectedUnitId;

  const TenantsManagementScreen({
    Key? key,
    this.propertyId,
    this.preselectedUnitId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Kiracı Yönetimi'),
      ),
      body: const Center(
        child: Text(
          'Kiracı Yönetimi\n(Landlord CRUD + WhatsApp Davet)',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textBody),
        ),
      ),
    );
  }
}
