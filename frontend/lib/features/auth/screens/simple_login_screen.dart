import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/network/api_client.dart';

enum AuthMode { login, register }

class SimpleLoginScreen extends ConsumerStatefulWidget {
  final String role;

  const SimpleLoginScreen({Key? key, required this.role}) : super(key: key);

  @override
  ConsumerState<SimpleLoginScreen> createState() => _SimpleLoginScreenState();
}

class _SimpleLoginScreenState extends ConsumerState<SimpleLoginScreen> {
  AuthMode _mode = AuthMode.login;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  String get _roleLabel {
    switch (widget.role) {
      case 'agent': return 'Emlakçı';
      case 'tenant': return 'Kiracı';
      case 'landlord': return 'Ev Sahibi';
      default: return 'Kullanıcı';
    }
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

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (_mode == AuthMode.login) {
        final response = await ApiClient.dio.post('/auth/login-simple', data: {
          'email': email,
          'password': password,
          'role': widget.role,
        });

        if (response.statusCode == 200) {
          final token = response.data['access_token'];
          if (token != null) {
            ApiClient.setSimpleAuthToken(token);
          }
          _navigateToDashboard();
        }
      } else {
        final response = await ApiClient.dio.post('/auth/register-simple', data: {
          'email': email,
          'password': password,
          'full_name': name,
          'role': widget.role,
        });

        if (response.statusCode == 200 || response.statusCode == 201) {
          final loginResp = await ApiClient.dio.post('/auth/login-simple', data: {
            'email': email,
            'password': password,
            'role': widget.role,
          });
          if (loginResp.statusCode == 200) {
            final token = loginResp.data['access_token'];
            if (token != null) {
              ApiClient.setSimpleAuthToken(token);
            }
            _navigateToDashboard();
          }
        }
      }
    } catch (e) {
      setState(() => _error = 'Hata: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
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
    final isRegister = _mode == AuthMode.register;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back, size: 20),
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
                  color: AppColors.accent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.role == 'agent' ? Icons.business
                    : widget.role == 'tenant' ? Icons.person
                    : Icons.holiday_village,
                  color: AppColors.accent,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '$_roleLabel Girişi',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textHeader,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isRegister ? 'Hesap oluşturun' : 'Email ve şifrenizle giriş yapın',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textBody, fontSize: 14),
              ),
              const SizedBox(height: 40),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: AppColors.error, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (isRegister) ...[
                _buildTextField(controller: _nameController, label: 'Ad Soyad', icon: Icons.person_outline),
                const SizedBox(height: 16),
              ],
              _buildTextField(
                controller: _emailController,
                label: 'Email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _passwordController,
                label: 'Şifre',
                icon: Icons.lock_outline,
                obscureText: true,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(isRegister ? 'Kayıt Ol' : 'Giriş Yap', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                  isRegister ? 'Zaten hesabınız var mı? Giriş yapın' : 'Hesabınız yok mu? Kayıt olun',
                  style: TextStyle(color: AppColors.accent),
                ),
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
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        style: TextStyle(color: AppColors.textHeader),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AppColors.textBody),
          prefixIcon: Icon(icon, color: AppColors.accent),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }
}