import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../providers/auth_provider.dart';

/// OTP doğrulama ekranı - Email Link veya SMS OTP için
class OtpScreen extends ConsumerStatefulWidget {
  final String emailOrPhone;
  final String? userId;

  const OtpScreen({Key? key, required this.emailOrPhone, this.userId})
    : super(key: key);

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  String? _error;
  bool _isLoading = false;
  int _remainingSeconds = 180;
  Timer? _timer;
  int _failedAttempts = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();

    // Otomatik OTP gönderimi (Yalnızca SMS)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).sendOtp(widget.emailOrPhone);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _remainingSeconds = 180;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            timer.cancel();
          }
        });
      }
    });
  }

  String get _formattedTime {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  bool get _canResend => _remainingSeconds == 0;

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }

    // Check if all digits are filled
    final allFilled = _controllers.every((c) => c.text.isNotEmpty);
    if (allFilled) {
      _submit();
    }
  }

  void _onPaste(String text) {
    if (text.length >= 6) {
      for (int i = 0; i < 6; i++) {
        _controllers[i].text = text[i];
      }
      _submit();
    }
  }

  Future<void> _submit() async {
    final code = _controllers.map((c) => c.text).join();

    if (code.length != 6) {
      setState(() => _error = '6 haneli kod girin');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final userId = ref.read(authProvider).pendingUserId ?? widget.userId;
    if (userId == null) {
      setState(() {
        _isLoading = false;
        _error = 'Kullanıcı bilgisi bulunamadı';
      });
      return;
    }

    final result = await ref
        .read(authProvider.notifier)
        .verifyOtp(code, userId, widget.emailOrPhone);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result.success) {
      context.go(
        '/set-password',
        extra: {'userId': userId, 'emailOrPhone': widget.emailOrPhone},
      );
    } else {
      _failedAttempts++;
      setState(() => _error = result.error ?? 'Geçersiz doğrulama kodu');

      // 3 yanlış deneme sonrası blok
      if (_failedAttempts >= 3) {
        _showBlockedDialog();
      }
    }
  }

  void _showBlockedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Kod Bloke Edildi'),
        content: const Text(
          '3 kez yanlış kod girdiniz. Yeni bir kod talep etmeniz gerekiyor.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resendCode();
            },
            child: const Text('Kodu Tekrar Gönder'),
          ),
        ],
      ),
    );
  }

  Future<void> _resendCode() async {
    _timer?.cancel();
    _startTimer();
    _failedAttempts = 0;

    // Clear inputs
    for (var controller in _controllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();

    await ref.read(authProvider.notifier).sendOtp(widget.emailOrPhone);
  }

  @override
  Widget build(BuildContext context) {
    final isEmail = widget.emailOrPhone.contains('@');

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
            child: const Icon(
              Icons.arrow_back,
              size: 20,
              color: AppColors.charcoal,
            ),
          ),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),

              Text(
                    'Doğrulama Kodu',
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

              // Show message for both email and phone
              Text(
                isEmail
                    ? 'Email adresinize doğrulama kodu gönderdik'
                    : '${widget.emailOrPhone}\'a doğrulama kodu gönderdik',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.slateGray),
              ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

              const SizedBox(height: 48),

              // OTP Input boxes (same for both email and phone)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 48,
                    height: 56,
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: AppColors.charcoal,
                            fontWeight: FontWeight.bold,
                          ),
                      decoration: InputDecoration(
                        counterText: '',
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
                          borderSide: BorderSide(
                            color: AppColors.charcoal,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (value) => _onDigitChanged(index, value),
                    ),
                  );
                }),
              ).animate().fadeIn(delay: 200.ms, duration: 300.ms),

              const SizedBox(height: 24),

              // Error message
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
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
                ).animate().fadeIn(duration: 300.ms),

              const SizedBox(height: 24),

              // Timer
              Center(
                child: Text(
                  'Kalan süre: $_formattedTime',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _remainingSeconds < 30
                        ? AppColors.error
                        : AppColors.slateGray,
                  ),
                ),
              ).animate().fadeIn(delay: 300.ms, duration: 300.ms),

              const SizedBox(height: 16),

              // Resend button
              Center(
                child: TextButton(
                  onPressed: _canResend && !_isLoading ? _resendCode : null,
                  child: Text(
                    'Kodu Tekrar Gönder',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _canResend
                          ? AppColors.charcoal
                          : AppColors.slateGray,
                      decoration: _canResend
                          ? TextDecoration.underline
                          : null,
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 400.ms, duration: 300.ms),

              const Spacer(),

              // Submit button
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
                              'Doğrula',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  )
                  .animate()
                  .fadeIn(delay: 500.ms, duration: 300.ms)
                  .slideY(
                    begin: 0.1,
                    end: 0,
                    delay: 500.ms,
                    duration: 300.ms,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
