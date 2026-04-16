import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import '../../../core/theme/colors.dart';
import '../providers/auth_provider.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String role;
  final String phone;
  final String? inviteToken; // KVKK + invitation akışı için

  const OtpVerificationScreen({
    Key? key,
    required this.role,
    required this.phone,
    this.inviteToken,
  }) : super(key: key);

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _otpController = TextEditingController();

  void _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("SMS kodunu tamı tamına 6 harfli olarak giriniz.")));
      return;
    }

    // Telefon yollama butonu, Provider'ı (Backend'i) arayarak kendini kitler:
    final success = await ref.read(authProvider.notifier).verifyOtpCode(code, widget.role);
    
    if (success && mounted) {
      // KVKK onay kontrolü — tenant/landlord ve invite token varsa
      if (widget.inviteToken != null && widget.role != 'agent') {
        _showKvkkConsent();
      } else {
        _navigateToRole();
      }
    }
  }

  void _showKvkkConsent() {
    bool agreed = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("KVKK Aydınlatma Metni", style: TextStyle(color: AppColors.textHeader, fontSize: 18, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "6698 sayılı Kişisel Verilerin Korunması Kanunu (KVKK) uyarınca, "
                  "kişisel verilerinizin işlenmesi ve saklanması hakkında bilgilendirilmektesiniz.\n\n"
                  "Verileriniz:\n"
                  "• Kira takibi ve finansal işlemler için kullanılacaktır.\n"
                  "• Emlak ofisi ile iletişim kurmak için saklanacaktır.\n"
                  "• Üçüncü kişilerle paylaşılmayacaktır.\n\n"
                  "Haklarınız:\n"
                  "• Verilerinize erişim talep edebilirsiniz.\n"
                  "• Verilerinizin silinmesini isteyebilirsiniz.\n"
                  "• İşlenme sürecine itiraz edebilirsiniz.",
                  style: TextStyle(color: AppColors.textBody.withValues(alpha: 0.8), fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: agreed,
                      onChanged: (v) => setDialogState(() => agreed = v ?? false),
                      activeColor: AppColors.accent,
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setDialogState(() => agreed = !agreed),
                        child: Text(
                          "KVKK Aydınlatma Metni'ni okudum ve kabul ediyorum.",
                          style: TextStyle(color: AppColors.textHeader.withValues(alpha: 0.85), fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: agreed
                  ? () {
                      Navigator.pop(ctx);
                      _navigateToRole();
                    }
                  : null,
              child: Text(
                'Devam Et',
                style: TextStyle(color: agreed ? AppColors.accent : AppColors.textBody.withValues(alpha: 0.4), fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToRole() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(backgroundColor: AppColors.success, content: Text("Sisteme Başarıyla Girildi!")),
    );
    if (widget.role == 'agent') {
      context.go('/agent');
    } else if (widget.role == 'tenant') {
      context.go('/tenant');
    } else {
      context.go('/landlord');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Statüye göre (Yükleniyor mu? Hata mı var?) bu sayfayı baştan aşağı tekrar çizen (Reactive) zeka motoru.
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
          // Onay Sayfası olduğu için ışıkları (Glow) Zümrüt Yeşili tonuna alıyoruz:
          Positioned(top: -100, right: -50, child: Container(width: 200, height: 200, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.success.withValues(alpha:0.15)))),
          Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70), child: const SizedBox())),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  Text("SMS Şifresi\nElinizde mi?", style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 36, color: AppColors.textHeader, height: 1.2)),
                  const SizedBox(height: 12),
                  Text("+90 ${widget.phone} cihazınıza az önce bir güvenlik kodu fırlattık. (Test için '123456' yazın).", style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16)),
                  const SizedBox(height: 40),
                  
                  // Klasik telefon girdi kutusunu Pin Kutularına benzettik!
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha:0.4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.accent.withValues(alpha:0.5), width: 1.5),
                    ),
                    child: TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center, // Kod ortada duracak
                      maxLength: 6, // 6 taneden fazla basılamaz
                      style: const TextStyle(color: Colors.white, fontSize: 32, letterSpacing: 12, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        counterText: "", // Altındaki sayacı gizler
                        border: InputBorder.none, 
                        hintText: "******", 
                        hintStyle: TextStyle(letterSpacing: 12)
                      ),
                      onChanged: (val) {
                         // Eğer 6'ya ulaşırsa ve uygulama hali hazırda meşgul değilse MÜŞTERİYİ BEKLETMEDEN otomatik butona TIKLA (Wow Effect):
                         if (val.length == 6 && !authState.isLoading) {
                             _verifyOtp(); 
                         }
                      },
                    ),
                  ),

                  // Şifre yanlış girildiğinde animasyonlu olarak araya sızan Kırmızı (Error) Göstergesi
                  if (authState.error != null) ...[
                    const SizedBox(height: 16),
                    Text(authState.error!, style: const TextStyle(color: AppColors.error), textAlign: TextAlign.center),
                  ],

                  const Spacer(),
                  
                  ElevatedButton(
                    onPressed: authState.isLoading ? null : _verifyOtp,
                    child: authState.isLoading 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) // Spin Animasyonu
                        : const Text("Teyit Et ve Uygulamaya Gir"),
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
