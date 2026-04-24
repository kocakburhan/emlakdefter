import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../providers/auth_provider.dart';

/// Standart şifre giriş ekranı
class PasswordScreen extends ConsumerStatefulWidget {
  final String emailOrPhone;

  const PasswordScreen({
    Key? key,
    required this.emailOrPhone,
  }) : super(key: key);

  @override
  ConsumerState<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends ConsumerState<PasswordScreen> {
  final _passwordController = TextEditingController();
  String? _error;
  bool _obscurePassword = true;
  int _failedAttempts = 0;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _passwordController.text;

    if (password.isEmpty) {
      setState(() => _error = 'Lütfen şifrenizi girin');
      return;
    }

    setState(() => _error = null);

    final result = await ref.read(authProvider.notifier).passwordLogin(
          widget.emailOrPhone,
          password,
        );

    if (!mounted) return;

    if (result.success) {
      _navigateToDashboard();
    } else {
      _failedAttempts++;
      setState(() => _error = result.error ?? 'Giriş başarısız');

      // 5 yanlış deneme sonrası 15 dakika kilit
      if (_failedAttempts >= 5) {
        _showLockoutDialog();
      }
    }
  }

  void _showLockoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Hesap Kilitlendi'),
        content: const Text(
          'Çok fazla yanlış deneme yaptınız. '
          '15 dakika içinde tekrar deneyebilirsiniz. '
          'veya EmlakDefter danışmanı ile iletişime geçin.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/');
            },
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  Future<void> _forgotPassword() async {
    final result = await ref.read(authProvider.notifier).forgotPassword(widget.emailOrPhone);

    if (!mounted) return;

    if (result.success) {
      context.go('/otp', extra: widget.emailOrPhone);
    } else {
      setState(() => _error = result.error ?? 'İşlem başarısız');
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
    final authState = ref.watch(authProvider);

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
                'Tekrar Hoş Geldin',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.charcoal,
                      fontWeight: FontWeight.bold,
                    ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.2, end: 0, duration: 400.ms),

              const SizedBox(height: 8),

              Text(
                'Şifrenizi girin',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.slateGray,
                    ),
              )
                  .animate()
                  .fadeIn(delay: 100.ms, duration: 400.ms),

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
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: 'Şifre',
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

              const SizedBox(height: 32),

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
                          'Giriş Yap',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              )
                  .animate()
                  .fadeIn(delay: 300.ms, duration: 300.ms)
                  .slideY(begin: 0.1, end: 0, delay: 300.ms, duration: 300.ms),

              const SizedBox(height: 16),

              // Forgot password link
              Center(
                child: TextButton(
                  onPressed: authState.isLoading ? null : _forgotPassword,
                  child: Text(
                    'Şifremi unuttum',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.charcoal,
                          decoration: TextDecoration.underline,
                        ),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: 400.ms, duration: 300.ms),
            ],
          ),
        ),
      ),
    );
  }
}