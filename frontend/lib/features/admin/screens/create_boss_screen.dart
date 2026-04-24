import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../providers/admin_provider.dart';

/// Yeni Patron Oluşturma Ekranı
class CreateBossScreen extends ConsumerStatefulWidget {
  const CreateBossScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CreateBossScreen> createState() => _CreateBossScreenState();
}

class _CreateBossScreenState extends ConsumerState<CreateBossScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _generalError;

  // Field-specific errors for real-time validation
  String? _emailError;
  String? _phoneError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _validateEmail(String value) {
    setState(() {
      if (value.isEmpty) {
        _emailError = null;
        return;
      }
      if (!value.contains('@') || !value.contains('.')) {
        _emailError = 'Geçerli bir email adresi girin';
      } else {
        _emailError = null;
      }
    });
  }

  void _validatePhone(String value) {
    setState(() {
      if (value.isEmpty) {
        _phoneError = null;
        return;
      }
      final digits = value.replaceAll(RegExp(r'\D'), '');
      if (digits.length != 10 || !digits.startsWith('5')) {
        _phoneError = 'Geçerli bir telefon numarası girin (5xx xxx xx xx)';
      } else {
        _phoneError = null;
      }
    });
  }

  bool _validateForm() {
    bool isValid = true;

    // Name validation
    if (_nameController.text.trim().isEmpty) {
      isValid = false;
    }

    // Email validation
    final email = _emailController.text.trim();
    if (email.isNotEmpty) {
      if (!email.contains('@') || !email.contains('.')) {
        setState(() => _emailError = 'Geçerli bir email adresi girin');
        isValid = false;
      }
    }

    // Phone validation
    final phone = _phoneController.text.trim();
    if (phone.isNotEmpty) {
      final digits = phone.replaceAll(RegExp(r'\D'), '');
      if (digits.length != 10 || !digits.startsWith('5')) {
        setState(() => _phoneError = 'Geçerli bir telefon numarası girin (5xx xxx xx xx)');
        isValid = false;
      }
    }

    // At least one contact required
    if (email.isEmpty && phone.isEmpty) {
      setState(() {
        _emailError = 'Email veya telefon gerekli';
        _phoneError = 'Email veya telefon gerekli';
      });
      isValid = false;
    }

    return isValid;
  }

  Future<void> _submit() async {
    if (!_validateForm()) return;

    setState(() {
      _isLoading = true;
      _generalError = null;
    });

    try {
      // Get selected agency from admin state
      final adminState = ref.read(adminProvider);
      final agencies = adminState.agencies;
      if (agencies.isEmpty) {
        setState(() => _generalError = 'Önce bir ofis oluşturmalısınız');
        return;
      }

      final user = await ref.read(adminProvider.notifier).createUser(
            fullName: _nameController.text.trim(),
            email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
            phoneNumber: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
            role: 'boss',
            agencyId: agencies.first['id'],
          );

      if (!mounted) return;

      if (user != null) {
        context.go('/admin/users/${user['id']}');
      } else {
        // Check if it's a duplicate error
        final error = adminState.error;
        if (error != null && error.toString().contains('unique')) {
          setState(() {
            if (_emailController.text.isNotEmpty) {
              _emailError = 'Bu email adresi sistemde zaten kayıtlı';
            }
            if (_phoneController.text.isNotEmpty) {
              _phoneError = 'Bu telefon numarası sistemde zaten kayıtlı';
            }
            _generalError = null;
          });
        } else {
          setState(() => _generalError = 'Patron oluşturulamadı');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _generalError = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminState = ref.watch(adminProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Yeni Patron Ekle'),
        backgroundColor: AppColors.charcoal,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/admin/users'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.infoLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.info, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Patron, seçili ofise bağlanacaktır.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.info,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // General Error
              if (_generalError != null)
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
                          _generalError!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.error,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Full Name
              Text(
                'Ad Soyad *',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.charcoal,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Patronun adı soyadı',
                  hintStyle: TextStyle(color: AppColors.slateGray.withValues(alpha: 0.6)),
                  prefixIcon: const Icon(Icons.person_outline, color: AppColors.slateGray),
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
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 24),

              // Email
              Text(
                'Email (en az biri gerekli)',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.charcoal,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                onChanged: _validateEmail,
                decoration: InputDecoration(
                  hintText: 'ornek@mail.com',
                  hintStyle: TextStyle(color: AppColors.slateGray.withValues(alpha: 0.6)),
                  prefixIcon: const Icon(Icons.email_outlined, color: AppColors.slateGray),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: _emailError != null
                        ? const BorderSide(color: AppColors.error, width: 2)
                        : BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.charcoal, width: 2),
                  ),
                  errorText: _emailError,
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.error, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
              const SizedBox(height: 24),

              // Phone
              Text(
                'Telefon (en az biri gerekli)',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.charcoal,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _PhoneNumberFormatter(),
                ],
                onChanged: _validatePhone,
                decoration: InputDecoration(
                  hintText: '5xx xxx xx xx',
                  hintStyle: TextStyle(color: AppColors.slateGray.withValues(alpha: 0.6)),
                  prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.slateGray),
                  prefixText: '+90 ',
                  prefixStyle: const TextStyle(color: AppColors.charcoal, fontSize: 16),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: _phoneError != null
                        ? const BorderSide(color: AppColors.error, width: 2)
                        : BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.charcoal, width: 2),
                  ),
                  errorText: _phoneError,
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.error, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
              const SizedBox(height: 24),

              // Agency (auto-selected)
              if (adminState.agencies.isNotEmpty) ...[
                Text(
                  'Ofis (otomatik)',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.charcoal,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.business, color: AppColors.charcoal),
                      const SizedBox(width: 12),
                      Text(
                        adminState.agencies.first['name'] ?? '',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.charcoal,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Yeni patron bu ofise bağlanacaktır.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.slateGray,
                      ),
                ),
                const SizedBox(height: 24),
              ],

              const SizedBox(height: 16),

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
                          'Patron Oluştur',
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

/// Phone number formatter for Turkish phone numbers
class _PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    if (text.length > 13) {
      return oldValue;
    }

    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 3) {
      return TextEditingValue(text: digits, selection: TextSelection.collapsed(offset: digits.length));
    } else if (digits.length <= 6) {
      return TextEditingValue(
        text: '${digits.substring(0, 3)} ${digits.substring(3)}',
        selection: TextSelection.collapsed(offset: digits.length + 1),
      );
    } else if (digits.length <= 8) {
      return TextEditingValue(
        text: '${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6)}',
        selection: TextSelection.collapsed(offset: digits.length + 2),
      );
    } else {
      return TextEditingValue(
        text: '${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6, 8)} ${digits.substring(8)}',
        selection: TextSelection.collapsed(offset: digits.length + 3),
      );
    }
  }
}