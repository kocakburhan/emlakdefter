import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../providers/auth_provider.dart';

/// Şifre belirleme ekranı
class SetPasswordScreen extends ConsumerStatefulWidget {
  final String userId;
  final String emailOrPhone;

  const SetPasswordScreen({
    Key? key,
    required this.userId,
    required this.emailOrPhone,
  }) : super(key: key);

  @override
  ConsumerState<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends ConsumerState<SetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  // Password validation states
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasDigit = false;
  bool _hasMatch = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onPasswordChanged);
    _confirmController.addListener(_onConfirmChanged);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _onPasswordChanged() {
    final password = _passwordController.text;
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasDigit = password.contains(RegExp(r'[0-9]'));
      _hasMatch = password.isNotEmpty && password == _confirmController.text;
    });
  }

  void _onConfirmChanged() {
    setState(() {
      _hasMatch = _passwordController.text.isNotEmpty &&
          _passwordController.text == _confirmController.text;
    });
  }

  bool get _isValid {
    return _hasMinLength && _hasUppercase && _hasDigit && _hasMatch;
  }

  Future<void> _submit() async {
    if (!_isValid) {
      setState(() => _error = 'Şifre gereksinimlerini karşılamıyor');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await ref.read(authProvider.notifier).setPassword(
          _passwordController.text,
          _confirmController.text,
          widget.userId,
        );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result.success) {
      _navigateToDashboard();
    } else {
      setState(() => _error = result.error ?? 'Şifre kaydedilemedi');
    }
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back, size: 20, color: AppColors.charcoal),
          ),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),

              Text(
                'Yeni Şifrenizi Belirleyin',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.charcoal,
                      fontWeight: FontWeight.bold,
                    ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.2, end: 0, duration: 400.ms),

              const SizedBox(height: 16),

              Text(
                'Şifre kuralları:',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.slateGray,
                    ),
              )
                  .animate()
                  .fadeIn(delay: 100.ms, duration: 400.ms),

              const SizedBox(height: 24),

              // Validation indicators
              _ValidationRow(
                label: 'En az 8 karakter',
                isValid: _hasMinLength,
              ),
              _ValidationRow(
                label: 'En az bir büyük harf',
                isValid: _hasUppercase,
              ),
              _ValidationRow(
                label: 'En az bir rakam',
                isValid: _hasDigit,
              ),
              _ValidationRow(
                label: 'Şifreler eşleşiyor',
                isValid: _hasMatch && _confirmController.text.isNotEmpty,
              ),

              const SizedBox(height: 32),

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
                )
                    .animate()
                    .fadeIn(duration: 300.ms)
                    .slideY(begin: 0.1, end: 0, duration: 300.ms),

              // Password field
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowLight,
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: Theme.of(context).textTheme.bodyLarge,
                  onSubmitted: (_) => _isValid ? _submit() : null,
                  decoration: InputDecoration(
                    hintText: 'Yeni şifre',
                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.slateGray),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: AppColors.slateGray,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: 200.ms, duration: 300.ms)
                  .slideY(begin: 0.1, end: 0, delay: 200.ms, duration: 300.ms),

              const SizedBox(height: 16),

              // Confirm password field
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowLight,
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _confirmController,
                  obscureText: _obscureConfirm,
                  style: Theme.of(context).textTheme.bodyLarge,
                  onSubmitted: (_) => _isValid ? _submit() : null,
                  decoration: InputDecoration(
                    hintText: 'Şifre tekrar',
                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.slateGray),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: AppColors.slateGray,
                      ),
                      onPressed: () {
                        setState(() => _obscureConfirm = !_obscureConfirm);
                      },
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: 300.ms, duration: 300.ms)
                  .slideY(begin: 0.1, end: 0, delay: 300.ms, duration: 300.ms),

              const SizedBox(height: 32),

              // Submit button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isValid && !_isLoading ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isValid ? AppColors.charcoal : AppColors.slateGray,
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
              )
                  .animate()
                  .fadeIn(delay: 400.ms, duration: 300.ms)
                  .slideY(begin: 0.1, end: 0, delay: 400.ms, duration: 300.ms),
            ],
          ),
        ),
      ),
    );
  }
}

class _ValidationRow extends StatelessWidget {
  final String label;
  final bool isValid;

  const _ValidationRow({
    required this.label,
    required this.isValid,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.circle_outlined,
            color: isValid ? AppColors.success : AppColors.slateGray,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isValid ? AppColors.charcoal : AppColors.slateGray,
                ),
          ),
        ],
      ),
    );
  }
}