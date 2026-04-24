import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/network/api_client.dart';

/// Kullanıcı profil bilgisi (Backend'den dönen yanıt)
class UserProfile {
  final String id;
  final String fullName;
  final String? phoneNumber;
  final String? email;
  final String role;
  final String? agencyId;
  final String? status;

  UserProfile({
    required this.id,
    required this.fullName,
    this.phoneNumber,
    this.email,
    required this.role,
    this.agencyId,
    this.status,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name'] ?? '',
      phoneNumber: json['phone_number'],
      email: json['email'],
      role: json['role'] ?? 'standard',
      agencyId: json['agency_id']?.toString(),
      status: json['status'],
    );
  }
}

/// Auth işlemlerinin sonucunu temsil eder
class AuthResult {
  final bool success;
  final String? error;
  final AuthFlowState? nextState;
  final String? pendingUserId;
  final UserProfile? user;
  final String? message;

  AuthResult({
    required this.success,
    this.error,
    this.nextState,
    this.pendingUserId,
    this.user,
    this.message,
  });

  factory AuthResult.success({
    AuthFlowState? nextState,
    String? pendingUserId,
    UserProfile? user,
    String? message,
  }) {
    return AuthResult(
      success: true,
      nextState: nextState,
      pendingUserId: pendingUserId,
      user: user,
      message: message,
    );
  }

  factory AuthResult.failure(String error) {
    return AuthResult(success: false, error: error);
  }
}

/// Auth akış durumları
enum AuthFlowState {
  login, // Email/telefon girişi
  password, // Şifre girişi
  otp, // OTP doğrulama
  setPassword, // Şifre belirleme
  dashboard, // Giriş başarılı, dashboard yönlendirmesi
}

class AuthState {
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;
  final UserProfile? user;
  final String? invitationToken;
  final String? pendingUserId;
  final String? pendingEmailOrPhone;
  final String? verificationId;
  final AuthFlowState flowState;

  AuthState({
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
    this.user,
    this.invitationToken,
    this.pendingUserId,
    this.pendingEmailOrPhone,
    this.verificationId,
    this.flowState = AuthFlowState.login,
  });

  AuthState copyWith({
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
    UserProfile? user,
    String? invitationToken,
    String? pendingUserId,
    String? pendingEmailOrPhone,
    String? verificationId,
    AuthFlowState? flowState,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      invitationToken: invitationToken ?? this.invitationToken,
      pendingUserId: pendingUserId ?? this.pendingUserId,
      pendingEmailOrPhone: pendingEmailOrPhone ?? this.pendingEmailOrPhone,
      verificationId: verificationId ?? this.verificationId,
      flowState: flowState ?? this.flowState,
    );
  }
}

/// Firebase Email/Password Auth motoru + Backend login köprüsü
class AuthNotifier extends StateNotifier<AuthState> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AuthNotifier() : super(AuthState());

  /// Email veya telefon ile giriş başlat
  /// Backend'e email veya phone gönderir, password_hash kontrolü yapar
  Future<AuthResult> loginWithEmailOrPhone(String emailOrPhone) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      pendingEmailOrPhone: emailOrPhone,
    );

    try {
      // Normalize input: email is lowercase, phone is cleaned
      final normalizedInput = _normalizeInput(emailOrPhone);

      final response = await ApiClient.dio.post(
        '/auth/login',
        data: {'email_or_phone': normalizedInput},
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final status = data['status'] as String?;

        if (status == 'password_required') {
          // Kullanıcının şifresi var, şifre ekranına git
          final userData = data['user'];
          String? userId;
          if (userData != null) {
            userId = userData['id']?.toString();
          }
          state = state.copyWith(
            isLoading: false,
            pendingUserId: userId,
            flowState: AuthFlowState.password,
          );
          return AuthResult.success(
            nextState: AuthFlowState.password,
            pendingUserId: userId,
          );
        } else if (status == 'otp_required') {
          // Şifresi yok, OTP gönder
          final userData = data['user'];
          String? userId;
          if (userData != null) {
            userId = userData['id']?.toString();
          }
          state = state.copyWith(
            isLoading: false,
            pendingUserId: userId,
            flowState: AuthFlowState.otp,
          );
          return AuthResult.success(
            nextState: AuthFlowState.otp,
            pendingUserId: userId,
          );
        } else if (status == 'success') {
          // Doğrudan giriş başarılı
          final userData = data['user'];
          if (userData != null) {
            final user = UserProfile.fromJson(userData);
            await _handlePostLogin(user);
          }
          return AuthResult.success(
            nextState: AuthFlowState.dashboard,
            user: state.user,
          );
        }

        state = state.copyWith(isLoading: false);
        return AuthResult.failure('Bilinmeyen sunucu yanıtı');
      }

      state = state.copyWith(isLoading: false, error: 'Sunucu yanıt vermedi');
      return AuthResult.failure('Sunucu yanıt vermedi');
    } catch (e) {
      String errorMessage = _extractErrorMessage(e);
      state = state.copyWith(isLoading: false, error: errorMessage);
      return AuthResult.failure(errorMessage);
    }
  }

  /// OTP gönder (email veya SMS)
  /// Email için Firebase Client SDK kullanarak email link gönderir
  Future<AuthResult> sendOtp(String emailOrPhone) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final normalizedInput = _normalizeInput(emailOrPhone);
      final isEmail = normalizedInput.contains('@');

      if (isEmail) {
        // Email için backend'e OTP isteğinde bulun
        final response = await ApiClient.dio.post(
          '/auth/send-otp',
          data: {'email_or_phone': normalizedInput},
        );

        if (response.statusCode == 200 && response.data != null) {
          final devCode = response.data['dev_code'];
          // DEV mode'da code döner, logla
          if (devCode != null) {
            debugPrint('[DEV] Email OTP: $devCode');
          }
          state = state.copyWith(isLoading: false);
          return AuthResult.success(
            message: 'Doğrulama kodu email adresinize gönderildi',
          );
        }

        state = state.copyWith(isLoading: false, error: 'Kod gönderilemedi');
        return AuthResult.failure('Kod gönderilemedi');
      } else {
        // Telefon için Firebase SMS Doğrulaması Başlat
        final completer = Completer<AuthResult>();

        // E.164 formatı yoksa +90 ekle
        String phoneInput = normalizedInput;
        if (!phoneInput.startsWith('+')) {
          if (phoneInput.startsWith('0')) {
            phoneInput = '+90${phoneInput.substring(1)}';
          } else {
            phoneInput = '+90$phoneInput';
          }
        }

        await _auth.verifyPhoneNumber(
          phoneNumber: phoneInput,
          verificationCompleted: (PhoneAuthCredential credential) async {
            state = state.copyWith(isLoading: false);
          },
          verificationFailed: (FirebaseAuthException e) {
            final error = e.message ?? 'Doğrulama başarısız oldu';
            state = state.copyWith(isLoading: false, error: error);
            if (!completer.isCompleted) {
              completer.complete(AuthResult.failure(error));
            }
          },
          codeSent: (String verId, int? resendToken) {
            state = state.copyWith(isLoading: false, verificationId: verId);
            if (!completer.isCompleted) {
              completer.complete(
                AuthResult.success(message: 'SMS doğrulama kodu gönderildi'),
              );
            }
          },
          codeAutoRetrievalTimeout: (String verId) {
            state = state.copyWith(verificationId: verId);
          },
        );

        return completer.future;
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'invalid-email':
          message = 'Geçersiz email adresi';
          break;
        case 'user-disabled':
          message = 'Bu hesap devre dışı bırakılmış';
          break;
        case 'too-many-requests':
          message = 'Çok fazla istek. Lütfen daha sonra tekrar deneyin';
          break;
        default:
          message = 'Email gönderilemedi: ${e.message}';
      }
      state = state.copyWith(isLoading: false, error: message);
      return AuthResult.failure(message);
    } catch (e) {
      String errorMessage = _extractErrorMessage(e);
      state = state.copyWith(isLoading: false, error: errorMessage);
      return AuthResult.failure(errorMessage);
    }
  }

  /// Email link ile giriş yapıldığında çağrılır
  Future<AuthResult> handleEmailLinkSignIn(String emailLink) async {
    try {
      // Email'i session'dan al (sendSignInLinkToEmail çağrılırken kaydedilmiş olmalı)
      final email = state.pendingEmailOrPhone;
      if (email == null) {
        return AuthResult.failure('Email bilgisi bulunamadı');
      }

      final credential = await _auth.signInWithEmailLink(
        email: email,
        emailLink: emailLink,
      );

      if (credential.user != null) {
        // Firebase email doğrulandı, Firebase ID token al
        final idToken = await credential.user!.getIdToken();

        // Backend'e Firebase ID token ile doğrula
        final response = await ApiClient.dio.post(
          '/auth/verify-otp',
          data: {'email_or_phone': email, 'firebase_id_token': idToken},
        );

        if (response.statusCode == 200 && response.data != null) {
          final data = response.data;

          final accessToken = data['access_token'];
          if (accessToken != null) {
            await ApiClient.setSimpleAuthToken(accessToken);
          }

          final requirePasswordSetup = data['require_password_setup'] == true;
          if (requirePasswordSetup) {
            final userId = data['user_id'];
            state = state.copyWith(
              isLoading: false,
              pendingUserId: userId,
              flowState: AuthFlowState.setPassword,
            );
            return AuthResult.success(
              nextState: AuthFlowState.setPassword,
              pendingUserId: userId,
            );
          }

          final userData = data['user'];
          if (userData != null) {
            final user = UserProfile.fromJson(userData);
            await _handlePostLogin(user);
            return AuthResult.success(
              nextState: AuthFlowState.dashboard,
              user: user,
            );
          }
        }

        return AuthResult.failure('Doğrulama başarısız');
      }

      return AuthResult.failure('Email link doğrulaması başarısız');
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'invalid-action-code':
          message = 'Geçersiz veya süresi dolmuş link';
          break;
        default:
          message = 'Doğrulama başarısız: ${e.message}';
      }
      return AuthResult.failure(message);
    } catch (e) {
      return AuthResult.failure('Beklenmeyen hata: $e');
    }
  }

  /// OTP doğrula
  Future<AuthResult> verifyOtp(
    String code,
    String userId,
    String emailOrPhone,
  ) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final isEmail = emailOrPhone.contains('@');
      String? firebaseIdToken;

      if (!isEmail) {
        // Telefon ise Firebase credential oluştur ve doğrula
        final verId = state.verificationId;
        if (verId == null) {
          state = state.copyWith(
            isLoading: false,
            error: 'Doğrulama ID bulunamadı.',
          );
          return AuthResult.failure(
            'Doğrulama ID bulunamadı. Lütfen tekrar kod talep edin.',
          );
        }

        try {
          AuthCredential credential = PhoneAuthProvider.credential(
            verificationId: verId,
            smsCode: code,
          );

          final userCredential = await _auth.signInWithCredential(credential);
          firebaseIdToken = await userCredential.user?.getIdToken();

          if (firebaseIdToken == null) {
            state = state.copyWith(
              isLoading: false,
              error: 'Firebase Token alınamadı.',
            );
            return AuthResult.failure('Firebase Token alınamadı.');
          }
        } on FirebaseAuthException catch (e) {
          String errStr = 'Doğrulama başarısız: ${e.message}';
          if (e.code == 'invalid-verification-code') {
            errStr = 'Hatalı doğrulama kodu, lütfen kontrol ediniz.';
          }
          state = state.copyWith(isLoading: false, error: errStr);
          return AuthResult.failure(errStr);
        }
      }

      // Backend verify-otp
      final Map<String, dynamic> data = {
        'user_id': userId,
        'email_or_phone': emailOrPhone,
        if (!isEmail) 'firebase_id_token': firebaseIdToken,
        if (isEmail) 'code': code, // Eğer Email OTP backend istiyorsa
      };

      final response = await ApiClient.dio.post('/auth/verify-otp', data: data);

      if (response.statusCode == 200 && response.data != null) {
        final respData = response.data;

        final accessToken = respData['access_token'];
        if (accessToken != null) {
          await ApiClient.setSimpleAuthToken(accessToken);
        }

        final requirePasswordSetup = respData['require_password_setup'] == true;

        if (requirePasswordSetup) {
          state = state.copyWith(
            isLoading: false,
            pendingUserId: userId,
            flowState: AuthFlowState.setPassword,
          );
          return AuthResult.success(
            nextState: AuthFlowState.setPassword,
            pendingUserId: userId,
          );
        } else {
          final userData = respData['user'];
          if (userData != null) {
            final user = UserProfile.fromJson(userData);
            await _handlePostLogin(user);
            return AuthResult.success(
              nextState: AuthFlowState.dashboard,
              user: user,
            );
          }
        }
      }

      state = state.copyWith(isLoading: false, error: 'Doğrulama başarısız');
      return AuthResult.failure('Doğrulama başarısız');
    } catch (e) {
      String errorMessage = _extractErrorMessage(e);
      state = state.copyWith(isLoading: false, error: errorMessage);
      return AuthResult.failure(errorMessage);
    }
  }

  /// Şifre belirle (OTP doğrulandıktan sonra)
  Future<AuthResult> setPassword(
    String password,
    String confirmPassword,
    String userId,
  ) async {
    state = state.copyWith(isLoading: true, error: null);

    // Client-side validation
    if (password != confirmPassword) {
      state = state.copyWith(isLoading: false, error: 'Şifreler uyuşmuyor');
      return AuthResult.failure('Şifreler uyuşmuyor');
    }

    if (!_validatePassword(password)) {
      state = state.copyWith(
        isLoading: false,
        error: 'Şifre gereksinimleri karşılamıyor',
      );
      return AuthResult.failure(
        'Şifre gereksinimleri karşılamıyor (en az 8 karakter, 1 büyük harf, 1 rakam)',
      );
    }

    try {
      final response = await ApiClient.dio.post(
        '/auth/set-password',
        data: {'user_id': userId, 'new_password': password},
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final userData = data['user'];

        final accessToken = data['access_token'];
        if (accessToken != null) {
          await ApiClient.setSimpleAuthToken(accessToken);
        }

        if (userData != null) {
          final user = UserProfile.fromJson(userData);
          await _handlePostLogin(user);
        }
        return AuthResult.success(
          nextState: AuthFlowState.dashboard,
          user: state.user,
        );
      }

      state = state.copyWith(isLoading: false, error: 'Şifre kaydedilemedi');
      return AuthResult.failure('Şifre kaydedilemedi');
    } catch (e) {
      String errorMessage = _extractErrorMessage(e);
      state = state.copyWith(isLoading: false, error: errorMessage);
      return AuthResult.failure(errorMessage);
    }
  }

  /// Standart şifre ile giriş
  Future<AuthResult> passwordLogin(String emailOrPhone, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final normalizedInput = _normalizeInput(emailOrPhone);

      final response = await ApiClient.dio.post(
        '/auth/password-login',
        data: {'email_or_phone': normalizedInput, 'password': password},
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;

        final accessToken = data['access_token'];
        if (accessToken != null) {
          await ApiClient.setSimpleAuthToken(accessToken);
        }

        final userData = data['user'];
        if (userData != null) {
          final user = UserProfile.fromJson(userData);
          await _handlePostLogin(user);
        }
        return AuthResult.success(
          nextState: AuthFlowState.dashboard,
          user: state.user,
        );
      }

      state = state.copyWith(isLoading: false, error: 'Giriş başarısız');
      return AuthResult.failure('Giriş başarısız');
    } catch (e) {
      String errorMessage = _extractErrorMessage(e);
      state = state.copyWith(isLoading: false, error: errorMessage);
      return AuthResult.failure(errorMessage);
    }
  }

  /// Şifremi unuttum - OTP flow başlat
  Future<AuthResult> forgotPassword(String emailOrPhone) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final normalizedInput = _normalizeInput(emailOrPhone);

      final response = await ApiClient.dio.post(
        '/auth/forgot-password',
        data: {'email_or_phone': normalizedInput},
      );

      if (response.statusCode == 200 && response.data != null) {
        state = state.copyWith(
          isLoading: false,
          pendingEmailOrPhone: emailOrPhone,
          flowState: AuthFlowState.otp,
        );
        return AuthResult.success(
          nextState: AuthFlowState.otp,
          message: 'Şifre sıfırlama kodu gönderildi',
        );
      }

      state = state.copyWith(isLoading: false, error: 'İşlem başarısız');
      return AuthResult.failure('İşlem başarısız');
    } catch (e) {
      String errorMessage = _extractErrorMessage(e);
      state = state.copyWith(isLoading: false, error: errorMessage);
      return AuthResult.failure(errorMessage);
    }
  }

  /// Eski email/password ile giriş (geriye uyum için)
  Future<bool> signInWithEmail(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        final backendSuccess = await _loginToBackend(credential.user!);
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: backendSuccess,
          error: backendSuccess ? null : "Backend bağlantısı kurulamadı",
        );
        return backendSuccess;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = "Bu email ile kayıtlı kullanıcı bulunamadı";
          break;
        case 'wrong-password':
          message = "Şifre yanlış";
          break;
        case 'invalid-email':
          message = "Geçersiz email formatı";
          break;
        case 'user-disabled':
          message = "Bu hesap devre dışı bırakılmış";
          break;
        default:
          message = "Giriş başarısız: ${e.message}";
      }
      state = state.copyWith(isLoading: false, error: message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Eski email/password ile kayıt (geriye uyum için)
  Future<bool> signUpWithEmail(
    String email,
    String password,
    String fullName,
  ) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        await credential.user!.updateDisplayName(fullName);

        final backendSuccess = await _loginToBackend(
          credential.user!,
          fullName: fullName,
        );

        state = state.copyWith(
          isLoading: false,
          isAuthenticated: backendSuccess,
          error: backendSuccess ? null : "Backend bağlantısı kurulamadı",
        );
        return backendSuccess;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = "Bu email zaten kullanımda";
          break;
        case 'invalid-email':
          message = "Geçersiz email formatı";
          break;
        case 'weak-password':
          message = "Şifre çok zayıf (en az 6 karakter gerekli)";
          break;
        default:
          message = "Kayıt başarısız: ${e.message}";
      }
      state = state.copyWith(isLoading: false, error: message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Giriş sonrası ortak işlemler
  Future<void> _handlePostLogin(UserProfile user) async {
    // Simple auth token'ı kaydet
    final token = ApiClient.simpleAuthToken;
    if (token != null) {
      await ApiClient.setSimpleAuthToken(token);
    }

    state = state.copyWith(
      isLoading: false,
      isAuthenticated: true,
      user: user,
      flowState: AuthFlowState.dashboard,
    );
  }

  /// Firebase auth başarılı → Backend'e login isteği at
  Future<bool> _loginToBackend(User firebaseUser, {String? fullName}) async {
    try {
      final idToken = await firebaseUser.getIdToken();
      if (idToken == null) return false;

      final data = <String, dynamic>{
        'firebase_id_token': idToken,
        'full_name':
            fullName ??
            firebaseUser.displayName ??
            firebaseUser.email ??
            'Kullanıcı',
      };

      if (state.invitationToken != null) {
        data['invitation_token'] = state.invitationToken;
      }

      final response = await ApiClient.dio.post('/auth/login', data: data);

      if (response.statusCode == 200 && response.data != null) {
        final userData = response.data['user'];
        if (userData != null) {
          state = state.copyWith(user: UserProfile.fromJson(userData));
        }
        debugPrint("🔗 Backend login başarılı: ${response.data['message']}");
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("⚠️ Backend login hatası: $e");
      return false;
    }
  }

  /// Input'u normalize et (email lowercase, telefon temiz)
  String _normalizeInput(String input) {
    final trimmed = input.trim();
    if (trimmed.contains('@')) {
      return trimmed.toLowerCase();
    }
    // Telefon numarasından boşluk ve tire temizle
    return trimmed.replaceAll(RegExp(r'[\s\-\(\)]'), '');
  }

  /// Şifre validasyonu
  bool _validatePassword(String password) {
    if (password.length < 8) return false;
    if (!password.contains(RegExp(r'[A-Z]'))) return false;
    if (!password.contains(RegExp(r'[0-9]'))) return false;
    return true;
  }

  /// Hata mesajını çıkar
  String _extractErrorMessage(dynamic e) {
    if (e is Exception) {
      final str = e.toString();
      // DioException'dan mesaj çıkar
      if (str.contains('DioException')) {
        final match = RegExp(r'"message":"([^"]+)"').firstMatch(str);
        if (match != null) return match.group(1) ?? str;
      }
      return str;
    }
    return 'Beklenmeyen hata oluştu';
  }

  /// Davet token'ını kaydet
  void setInvitationToken(String? token) {
    state = state.copyWith(invitationToken: token);
  }

  /// Auth akışını sıfırla (login ekranına dön)
  void resetFlow() {
    state = AuthState();
  }

  /// Mevcut Firebase kullanıcısının oturum durumunu kontrol et
  Future<void> checkAuthStatus() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser != null) {
      state = state.copyWith(isAuthenticated: true);
      try {
        final response = await ApiClient.dio.get('/auth/me');
        if (response.statusCode == 200 && response.data != null) {
          state = state.copyWith(user: UserProfile.fromJson(response.data));
        }
      } catch (e) {
        debugPrint("⚠️ Profil alınamadı: $e");
      }
    }
  }

  /// Oturum Kapatma
  Future<void> logOut() async {
    await _auth.signOut();
    await ApiClient.clearSimpleAuthToken();
    state = AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
