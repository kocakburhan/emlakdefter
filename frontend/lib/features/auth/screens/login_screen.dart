import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../providers/auth_provider.dart';

/// Yeni login ekranı - email veya telefon ile giriş
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _inputController = TextEditingController();
  String? _error;
  bool _isPhoneMode = false;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _onInputChanged(String value) {
    // Detect if input is email or phone
    final trimmed = value.trim();
    setState(() {
      _isPhoneMode =
          !trimmed.contains('@') &&
          RegExp(r'^[\d\s\-\(\)]+$').hasMatch(trimmed);
      _error = null;
    });
  }

  Future<void> _submit() async {
    final input = _inputController.text.trim();

    if (input.isEmpty) {
      setState(() => _error = 'Lütfen email veya telefon numarası girin');
      return;
    }

    // Basic validation
    if (_isPhoneMode) {
      // Turkish phone validation - 10 digits after +90 or 0
      final cleaned = input.replaceAll(RegExp(r'[\s\-\(\)]'), '');
      if (cleaned.length < 10 || cleaned.length > 13) {
        setState(() => _error = 'Geçersiz telefon numarası');
        return;
      }
    } else {
      // Email validation
      if (!input.contains('@') || !input.contains('.')) {
        setState(() => _error = 'Geçersiz email adresi');
        return;
      }
    }

    setState(() => _error = null);

    final result = await ref
        .read(authProvider.notifier)
        .loginWithEmailOrPhone(input);

    if (!mounted) return;

    if (result.success) {
      // Navigate based on result.nextState
      switch (result.nextState) {
        case AuthFlowState.password:
          context.go('/password', extra: input);
          break;
        case AuthFlowState.otp:
          if (_isPhoneMode) {
            context.go('/otp', extra: input);
          } else {
            // Show generic Email Sent success message according to PRD
            _showEmailSentDialog(input);
          }
          break;
        case AuthFlowState.dashboard:
          _navigateToDashboard();
          break;
        default:
          context.go('/password', extra: input);
      }
    } else {
      setState(() => _error = result.error ?? 'Giriş başarısız');
    }
  }

  void _showEmailSentDialog(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Email Gönderildi'),
        content: Text(
          '$email adresinize doğrulama linki gönderdik, lütfen e-postanızı kontrol edip linke tıklayın.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  void _navigateToDashboard() {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    switch (user.role) {
      case 'superadmin':
        context.go('/admin');
        break;
      case 'boss':
      case 'employee':
        context.go('/agent');
        break;
      case 'tenant':
        context.go('/tenant');
        break;
      case 'landlord':
        context.go('/landlord');
        break;
      default:
        context.go('/agent');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),

              // Logo / Title area
              Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.charcoal.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.home_work_outlined,
                      color: AppColors.charcoal,
                      size: 48,
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1.0, 1.0),
                    duration: 400.ms,
                    curve: Curves.easeOut,
                  ),

              const SizedBox(height: 32),

              Text(
                    'Hoş Geldiniz',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.charcoal,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                  .animate()
                  .fadeIn(delay: 100.ms, duration: 400.ms)
                  .slideY(begin: 0.2, end: 0, delay: 100.ms, duration: 400.ms),

              const SizedBox(height: 8),

              Text(
                'Email veya telefon numaranızla devam edin',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.slateGray),
              ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

              const SizedBox(height: 48),

              // Error message
              if (_error != null)
                Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.errorLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppColors.error,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 300.ms)
                    .slideY(begin: 0.1, end: 0, duration: 300.ms),

              // Input field
              Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _error != null
                            ? AppColors.error
                            : AppColors.border,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadowLight,
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _inputController,
                      keyboardType: _isPhoneMode
                          ? TextInputType.phone
                          : TextInputType.emailAddress,
                      inputFormatters: _isPhoneMode
                          ? [
                              FilteringTextInputFormatter.digitsOnly,
                              _PhoneNumberFormatter(),
                            ]
                          : null,
                      style: Theme.of(context).textTheme.bodyLarge,
                      onChanged: _onInputChanged,
                      decoration: InputDecoration(
                        hintText: 'Email veya telefon numarası',
                        prefixIcon: Icon(
                          _isPhoneMode
                              ? Icons.phone_outlined
                              : Icons.email_outlined,
                          color: AppColors.slateGray,
                        ),
                        prefixText: _isPhoneMode ? '+90 ' : null,
                        prefixStyle: const TextStyle(
                          color: AppColors.charcoal,
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(delay: 300.ms, duration: 300.ms)
                  .slideY(begin: 0.1, end: 0, delay: 300.ms, duration: 300.ms),

              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: authState.isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.charcoal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: authState.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Devam Et',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  )
                  .animate()
                  .fadeIn(delay: 400.ms, duration: 300.ms)
                  .slideY(begin: 0.1, end: 0, delay: 400.ms, duration: 300.ms),

              const Spacer(flex: 3),
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

    // Limit to 10 digits after +90
    if (text.length > 13) {
      return oldValue;
    }

    // Format as (xxx) xxx xx xx
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 3) {
      return TextEditingValue(
        text: digits,
        selection: TextSelection.collapsed(offset: digits.length),
      );
    } else if (digits.length <= 6) {
      return TextEditingValue(
        text: '${digits.substring(0, 3)} ${digits.substring(3)}',
        selection: TextSelection.collapsed(offset: digits.length + 1),
      );
    } else if (digits.length <= 8) {
      return TextEditingValue(
        text:
            '${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6)}',
        selection: TextSelection.collapsed(offset: digits.length + 2),
      );
    } else {
      return TextEditingValue(
        text:
            '${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6, 8)} ${digits.substring(8)}',
        selection: TextSelection.collapsed(offset: digits.length + 3),
      );
    }
  }
}
