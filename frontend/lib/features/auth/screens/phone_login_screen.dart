import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import '../../../core/theme/colors.dart';
import '../providers/auth_provider.dart';

class PhoneLoginScreen extends ConsumerStatefulWidget {
  final String role; // 'agent' (Emlakçı) veya 'tenant' (Kiracı)
  
  const PhoneLoginScreen({Key? key, required this.role}) : super(key: key);

  @override
  ConsumerState<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends ConsumerState<PhoneLoginScreen> {
  final _phoneController = TextEditingController();

  void _submitPhone() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen geçerli bir telefon numarası giriniz.", style: TextStyle(color: Colors.white))));
      return;
    }

    // Telefon yolla butonuna basıldığında Provider'daki 'sendPhoneCode' tetiklenir:
    final success = await ref.read(authProvider.notifier).sendPhoneCode(phone);
    
    // Eğer başarılı yanıt döndüyse pürüzsüzce OTP SMS ONAY sayfamıza ışınlanırız!
    if (success && mounted) {
        context.push('/otp?role=${widget.role}&phone=$phone');
    }
  }

  @override
  Widget build(BuildContext context) {
    // provider.isLoading statüsünü buraya bağlar, build yeniden tetiklenir (Animasyon değişir)
    final authState = ref.watch(authProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textHeader),
      ),
      body: Stack(
        children: [
          // Arkadaki Klasik Cam Glow'umuz
          Positioned(top: -50, left: -50, child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.accent.withValues(alpha:0.15)))),
          Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70), child: const SizedBox())),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  Text(
                    widget.role == 'agent' ? "Emlakçı Portalına\nGiriş" : "Kiracı Arayüzüne\nGiriş Sistemi",
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 36, color: AppColors.textHeader, height: 1.2),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Şifresiz bir süreç! Hesabınızı onaylamak için sadece telefon numaranızı girin.", 
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16)
                  ),
                  const SizedBox(height: 40),
                  
                  // Akıllı Telefon Girdi Kutusu (+90)
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha:0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha:0.1)),
                    ),
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 2), // Rakamlar harika yayılacak
                      decoration: InputDecoration(
                        prefixIcon: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [Text("+90", style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold))],
                          ),
                        ),
                        hintText: "5XX XXX XX XX",
                        hintStyle: TextStyle(color: AppColors.textBody.withValues(alpha:0.5)),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  
                  // Firebase'ten vs hata dönerse ekrana altta kırmızı kusan gösterge:
                  if (authState.error != null) ...[
                    const SizedBox(height: 16),
                    Text(authState.error!, style: const TextStyle(color: AppColors.error)),
                  ],
                  const Spacer(),
                  
                  // Animasyonlu Devam Butonu (Eğer isLoading true ise yuvarlak spinner çizer)
                  ElevatedButton(
                    onPressed: authState.isLoading ? null : _submitPhone,
                    child: authState.isLoading 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text("SMS Kodu İste"),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
