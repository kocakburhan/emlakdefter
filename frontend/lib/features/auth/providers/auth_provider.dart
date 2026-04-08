import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/network/api_client.dart';

/// Kullanıcı profil bilgisi (Backend'den dönen yanıt)
class UserProfile {
  final String id;
  final String fullName;
  final String? phoneNumber;
  final String? email;
  final String role;

  UserProfile({
    required this.id,
    required this.fullName,
    this.phoneNumber,
    this.email,
    required this.role,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? '',
      fullName: json['full_name'] ?? '',
      phoneNumber: json['phone_number'],
      email: json['email'],
      role: json['role'] ?? 'standard',
    );
  }
}

class AuthState {
  final bool isLoading;
  final String? error;
  final bool isCodeSent;
  final bool isAuthenticated;
  final String? verificationId;
  final UserProfile? user;

  AuthState({
    this.isLoading = false,
    this.error,
    this.isCodeSent = false,
    this.isAuthenticated = false,
    this.verificationId,
    this.user,
  });

  AuthState copyWith({
    bool? isLoading,
    String? error,
    bool? isCodeSent,
    bool? isAuthenticated,
    String? verificationId,
    UserProfile? user,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isCodeSent: isCodeSent ?? this.isCodeSent,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      verificationId: verificationId ?? this.verificationId,
      user: user ?? this.user,
    );
  }
}

/// Uygulamanın Firebase Auth motoru + Backend login köprüsü
class AuthNotifier extends StateNotifier<AuthState> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AuthNotifier() : super(AuthState());

  /// 1. Kullanıcı numarasını yazdığında Firebase'e gidip cihaza SMS atması
  Future<bool> sendPhoneCode(String phoneNumber) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        // Android: Eğer cihaz PIN'i otonom okursa, input ekranına bile geçmeden giriş yap
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
          state = state.copyWith(isLoading: false, isCodeSent: true, isAuthenticated: true);
          debugPrint("✅ Google SMS'i otonom (Arka Plandan) okudu ve içeri aldı!");
        },
        // Numara formatı bozuksa veya banlıysa
        verificationFailed: (FirebaseAuthException e) {
          state = state.copyWith(isLoading: false, error: "Firebase Reddedildi: ${e.message}");
        },
        // SMS gerçekten cihaza düştüğünde dönen doğrulama anahtarı
        codeSent: (String verificationId, int? resendToken) {
          state = state.copyWith(isLoading: false, isCodeSent: true, verificationId: verificationId);
          debugPrint("📩 Firebase Başarıyla SMS Yolladı. Verification ID kilitlendi.");
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          state = state.copyWith(verificationId: verificationId);
        },
      );
      
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// 2. Kullanıcı PIN ekranında şifreyi yazdı → Firebase doğrulama + Backend login
  Future<bool> verifyOtpCode(String smsCode, String role) async {
    if (state.verificationId == null) {
       state = state.copyWith(error: "Firebase SMS Kilit Anahtarı eksik, baştan gönderin.");
       return false;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
       // Firebase'de PIN doğrulama
       PhoneAuthCredential credential = PhoneAuthProvider.credential(
          verificationId: state.verificationId!,
          smsCode: smsCode,
       );
       UserCredential userCredential = await _auth.signInWithCredential(credential);
       
       if (userCredential.user != null) {
          // Firebase tarafında Authentication başarılı!
          // Şimdi Backend'e login isteği at
          final backendSuccess = await _loginToBackend(userCredential.user!);
          
          state = state.copyWith(
            isLoading: false, 
            isAuthenticated: backendSuccess,
            error: backendSuccess ? null : "Backend bağlantısı kurulamadı ama Firebase girişi başarılı.",
          );
          
          return true; // Firebase auth başarılı olduğu sürece devam et
       } else {
          state = state.copyWith(isLoading: false, error: "Firebase Giriş İşlemini Onaylamadı.");
          return false;
       }
    } on FirebaseAuthException catch (e) {
       state = state.copyWith(isLoading: false, error: "Girdiğiniz PİN Hatalı: ${e.message}");
       return false;
    } catch (e) {
       state = state.copyWith(isLoading: false, error: e.toString());
       return false;
    }
  }

  /// 3. Firebase auth başarılı → Backend'e login isteği at
  Future<bool> _loginToBackend(User firebaseUser) async {
    try {
      final idToken = await firebaseUser.getIdToken();
      if (idToken == null) return false;

      final response = await ApiClient.dio.post('/auth/login', data: {
        'firebase_id_token': idToken,
        'full_name': firebaseUser.displayName ?? firebaseUser.phoneNumber ?? 'Kullanıcı',
      });

      if (response.statusCode == 200 && response.data != null) {
        final userData = response.data['user'];
        if (userData != null) {
          state = state.copyWith(
            user: UserProfile.fromJson(userData),
          );
        }
        debugPrint("🔗 Backend login başarılı: ${response.data['message']}");
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("⚠️ Backend login hatası (Firebase auth devam ediyor): $e");
      // Backend'e bağlanamazsa bile Firebase auth başarılıysa devam et
      return false;
    }
  }

  /// Mevcut Firebase kullanıcısının oturum durumunu kontrol et
  Future<void> checkAuthStatus() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser != null) {
      state = state.copyWith(isAuthenticated: true);
      // Backend'den profili al
      try {
        final response = await ApiClient.dio.get('/auth/me');
        if (response.statusCode == 200 && response.data != null) {
          state = state.copyWith(
            user: UserProfile.fromJson(response.data),
          );
        }
      } catch (e) {
        debugPrint("⚠️ Profil alınamadı: $e");
      }
    }
  }
  
  /// Gerçek Oturum Kapatma İşlemi
  Future<void> logOut() async {
    await _auth.signOut();
    state = AuthState(); // Tüm State hafızasını sil
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
