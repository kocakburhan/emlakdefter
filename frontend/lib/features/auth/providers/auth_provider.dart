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

  UserProfile({
    required this.id,
    required this.fullName,
    this.phoneNumber,
    this.email,
    required this.role,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
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
  final bool isAuthenticated;
  final UserProfile? user;
  final String? invitationToken;

  AuthState({
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
    this.user,
    this.invitationToken,
  });

  AuthState copyWith({
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
    UserProfile? user,
    String? invitationToken,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      invitationToken: invitationToken ?? this.invitationToken,
    );
  }
}

/// Firebase Email/Password Auth motoru + Backend login köprüsü
class AuthNotifier extends StateNotifier<AuthState> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AuthNotifier() : super(AuthState());

  /// Email/password ile giriş
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

  /// Email/password ile kayıt
  Future<bool> signUpWithEmail(String email, String password, String fullName) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Firebase'e display name set et
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

  /// Firebase auth başarılı → Backend'e login isteği at
  Future<bool> _loginToBackend(User firebaseUser, {String? fullName}) async {
    try {
      final idToken = await firebaseUser.getIdToken();
      if (idToken == null) return false;

      final data = <String, dynamic>{
        'firebase_id_token': idToken,
        'full_name': fullName ?? firebaseUser.displayName ?? firebaseUser.email ?? 'Kullanıcı',
      };

      // Davet token varsa ekle
      if (state.invitationToken != null) {
        data['invitation_token'] = state.invitationToken;
      }

      final response = await ApiClient.dio.post('/auth/login', data: data);

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
      debugPrint("⚠️ Backend login hatası: $e");
      return false;
    }
  }

  /// Davet token'ını kaydet (register ekranına geçmeden önce)
  void setInvitationToken(String? token) {
    state = state.copyWith(invitationToken: token);
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