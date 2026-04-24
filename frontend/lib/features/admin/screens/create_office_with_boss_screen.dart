import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../providers/admin_provider.dart';

/// Yeni Ofis + Patron Oluşturma Ekranı (Combined Form)
/// Admin panelde "Yeni Ofis Ekle" dediğinde hem ofis hem patron bilgileri birlikte girilir.
class CreateOfficeWithBossScreen extends ConsumerStatefulWidget {
  const CreateOfficeWithBossScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CreateOfficeWithBossScreen> createState() => _CreateOfficeWithBossScreenState();
}

class _CreateOfficeWithBossScreenState extends ConsumerState<CreateOfficeWithBossScreen> {
  final _formKey = GlobalKey<FormState>();

  // Office controllers
  final _officeNameController = TextEditingController();
  final _officeAddressController = TextEditingController();

  // Boss controllers
  final _bossNameController = TextEditingController();
  final _bossEmailController = TextEditingController();
  final _bossPhoneController = TextEditingController();

  bool _isPhoneMode = false;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _officeNameController.dispose();
    _officeAddressController.dispose();
    _bossNameController.dispose();
    _bossEmailController.dispose();
    _bossPhoneController.dispose();
    super.dispose();
  }

  void _onContactChanged(String value) {
    final trimmed = value.trim();
    setState(() {
      _isPhoneMode = !trimmed.contains('@') && RegExp(r'^[\d\s\-\(\)]+$').hasMatch(trimmed);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Email veya telefon en az biri gerekli
    final email = _bossEmailController.text.trim();
    final phone = _bossPhoneController.text.trim();
    if (email.isEmpty && phone.isEmpty) {
      setState(() => _error = 'Email veya telefon numarası en az biri girilmelidir');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Ofis ve patronu birlikte oluştur
      final agency = await ref.read(adminProvider.notifier).createAgencyWithBoss(
            agencyName: _officeNameController.text.trim(),
            agencyAddress: _officeAddressController.text.trim(),
            bossFullName: _bossNameController.text.trim(),
            bossEmail: email.isNotEmpty ? email : null,
            bossPhone: phone.isNotEmpty ? phone : null,
          );

      if (agency == null) {
        setState(() => _error = 'Ofis oluşturulamadı');
        return;
      }

      final agencyId = agency['id'] as String;

      if (!mounted) return;

      // Başarılı - agency detail sayfasına git
      context.go('/admin/agencies/$agencyId');

    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Yeni Ofis ve Patron'),
        backgroundColor: AppColors.charcoal,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/admin/agencies'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Error message
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.error,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ===== OFIS BILGILERI =====
              Text(
                'Ofis Bilgileri',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.charcoal,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),

              // Office Name
              Text(
                'Ofis Adı',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.charcoal,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _officeNameController,
                decoration: InputDecoration(
                  hintText: 'örn: EmlakDefter Kadıköy',
                  hintStyle: TextStyle(color: AppColors.slateGray.withValues(alpha: 0.6)),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.charcoal, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.error, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ofis adı gerekli';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Office Address
              Text(
                'Adres',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.charcoal,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _officeAddressController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'örn: İstanbul, Kadıköy, Caferağa Mah.',
                  hintStyle: TextStyle(color: AppColors.slateGray.withValues(alpha: 0.6)),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.charcoal, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Adres gerekli';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // ===== PATRON BILGILERI =====
              Text(
                'Patron Bilgileri',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.charcoal,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),

              // Boss Full Name
              Text(
                'Ad Soyad',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.charcoal,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _bossNameController,
                decoration: InputDecoration(
                  hintText: 'Patronun adı ve soyadı',
                  hintStyle: TextStyle(color: AppColors.slateGray.withValues(alpha: 0.6)),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.charcoal, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ad soyad gerekli';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Boss Email
              Text(
                'Email (opsiyonel)',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.charcoal,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _bossEmailController,
                keyboardType: TextInputType.emailAddress,
                onChanged: _onContactChanged,
                decoration: InputDecoration(
                  hintText: 'patron@ornek.com',
                  hintStyle: TextStyle(color: AppColors.slateGray.withValues(alpha: 0.6)),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.charcoal, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
              const SizedBox(height: 16),

              // Boss Phone (OR separator)
              Row(
                children: [
                  Expanded(child: Divider(color: AppColors.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'veya',
                      style: TextStyle(color: AppColors.slateGray),
                    ),
                  ),
                  Expanded(child: Divider(color: AppColors.border)),
                ],
              ),
              const SizedBox(height: 16),

              // Boss Phone
              Text(
                'Telefon (opsiyonel)',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.charcoal,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _bossPhoneController,
                keyboardType: TextInputType.phone,
                onChanged: _onContactChanged,
                decoration: InputDecoration(
                  hintText: '5xx xxx xx xx',
                  hintStyle: TextStyle(color: AppColors.slateGray.withValues(alpha: 0.6)),
                  prefixText: _isPhoneMode ? '+90 ' : null,
                  prefixStyle: const TextStyle(color: AppColors.charcoal),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.charcoal, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Email veya telefon en az biri girilmelidir',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.slateGray,
                    ),
              ),
              const SizedBox(height: 40),

              // Submit Button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.charcoal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Kaydet ve Devam Et',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}