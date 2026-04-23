import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../providers/auth_provider.dart';

enum AuthMode { login, register }

class EmailLoginScreen extends ConsumerStatefulWidget {
  final String role;
  final String? invitationToken;

  const EmailLoginScreen({
    Key? key,
    required this.role,
    this.invitationToken,
  }) : super(key: key);

  @override
  ConsumerState<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends ConsumerState<EmailLoginScreen> {
  AuthMode _mode = AuthMode.login;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  String? _error;

  String get _roleLabel {
    switch (widget.role) {
      case 'agent':
        return 'Emlakçı';
      case 'tenant':
        return 'Kiracı';
      case 'landlord':
        return 'Ev Sahibi';
      default:
        return 'Kullanıcı';
    }
  }

  IconData get _roleIcon {
    switch (widget.role) {
      case 'agent':
        return Icons.business;
      case 'tenant':
        return Icons.person;
      case 'landlord':
        return Icons.holiday_village;
      default:
        return Icons.person;
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.invitationToken != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(authProvider.notifier).setInvitationToken(widget.invitationToken);
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Email ve şifre gerekli');
      return;
    }

    if (_mode == AuthMode.register && name.isEmpty) {
      setState(() => _error = 'Ad soyad gerekli');
      return;
    }

    setState(() => _error = null);

    bool success;
    if (_mode == AuthMode.login) {
      success = await ref.read(authProvider.notifier).signInWithEmail(email, password);
    } else {
      success = await ref.read(authProvider.notifier).signUpWithEmail(email, password, name);
    }

    if (success && mounted) {
      _navigateToDashboard();
    } else {
      final authState = ref.read(authProvider);
      if (authState.error != null) {
        setState(() => _error = authState.error);
      }
    }
  }

  void _navigateToDashboard() {
    if (!mounted) return;
    switch (widget.role) {
      case 'agent':
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
    final isRegister = _mode == AuthMode.register;

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
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.charcoal.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _roleIcon,
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

              const SizedBox(height: 24),

              Text(
                '$_roleLabel ${isRegister ? "Kayıt" : "Giriş"}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              )
                  .animate()
                  .fadeIn(delay: 100.ms, duration: 400.ms)
                  .slideY(begin: 0.2, end: 0, delay: 100.ms, duration: 400.ms),

              const SizedBox(height: 8),

              Text(
                isRegister ? 'Hesap oluşturun' : 'Email ve şifrenizle giriş yapın',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              )
                  .animate()
                  .fadeIn(delay: 200.ms, duration: 400.ms),

              const SizedBox(height: 32),

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

              if (isRegister) ...[
                _buildTextField(
                  controller: _nameController,
                  label: 'Ad Soyad',
                  icon: Icons.person_outline,
                )
                    .animate()
                    .fadeIn(delay: 250.ms, duration: 300.ms)
                    .slideY(begin: 0.1, end: 0, delay: 250.ms, duration: 300.ms),
                const SizedBox(height: 16),
              ],

              _buildTextField(
                controller: _emailController,
                label: 'Email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              )
                  .animate()
                  .fadeIn(
                    delay: isRegister ? 300.ms : 250.ms,
                    duration: 300.ms,
                  )
                  .slideY(
                    begin: 0.1,
                    end: 0,
                    delay: isRegister ? 300.ms : 250.ms,
                    duration: 300.ms,
                  ),

              const SizedBox(height: 16),

              _buildTextField(
                controller: _passwordController,
                label: 'Şifre',
                icon: Icons.lock_outline,
                obscureText: true,
              )
                  .animate()
                  .fadeIn(
                    delay: isRegister ? 350.ms : 300.ms,
                    duration: 300.ms,
                  )
                  .slideY(
                    begin: 0.1,
                    end: 0,
                    delay: isRegister ? 350.ms : 300.ms,
                    duration: 300.ms,
                  ),

              const SizedBox(height: 32),

              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: authState.isLoading ? null : _submit,
                  child: authState.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(isRegister ? 'Kayıt Ol' : 'Giriş Yap'),
                ),
              )
                  .animate()
                  .fadeIn(
                    delay: isRegister ? 400.ms : 350.ms,
                    duration: 300.ms,
                  )
                  .slideY(
                    begin: 0.1,
                    end: 0,
                    delay: isRegister ? 400.ms : 350.ms,
                    duration: 300.ms,
                  ),

              const SizedBox(height: 16),

              TextButton(
                onPressed: () {
                  setState(() {
                    _mode = isRegister ? AuthMode.login : AuthMode.register;
                    _error = null;
                  });
                },
                child: Text(
                  isRegister
                      ? 'Zaten hesabınız var mı? Giriş yapın'
                      : 'Hesabınız yok mu? Kayıt olun',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.charcoal,
                      ),
                ),
              )
                  .animate()
                  .fadeIn(
                    delay: isRegister ? 450.ms : 400.ms,
                    duration: 300.ms,
                  ),

              const SizedBox(height: 8),

              TextButton(
                onPressed: () => context.go('/'),
                child: Text(
                  'Rol Seçimine Dön',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.slateGray,
                      ),
                ),
              )
                  .animate()
                  .fadeIn(
                    delay: isRegister ? 500.ms : 450.ms,
                    duration: 300.ms,
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
  }) {
    return Container(
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
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.slateGray),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}