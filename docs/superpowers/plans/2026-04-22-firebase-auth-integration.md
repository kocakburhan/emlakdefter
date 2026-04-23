# Firebase Email/Password Auth Entegrasyonu - Uygulama Planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Firebase Email/Password Provider ile kayıt ve giriş işlemleri. Artık Phone OTP yok — sadece email + şifre.

**Architecture:** Flutter → Firebase Auth (email/password) → Firebase ID Token → Backend doğrulama → kullanıcı profili

**Tech Stack:** Firebase Auth (Email/Password), Firebase Admin SDK (Python), FastAPI, Flutter

---

## Durum Tespiti

### Mevcut:
- Backend: `/auth/login` endpoint'i Firebase token doğruluyor ✓
- Backend: `simple_register/simple_login` kaldırıldı ✓
- Frontend: Phone OTP login ekranları mevcut
- Firebase Console: Email/Password provider **aktif** ✓

### Hedef:
1. Frontend'de email/password ile giriş ve kayıt ekranı
2. Phone OTP ekranlarını kaldır
3. `auth_provider.dart`'ı email/password auth ile Güncelle

---

## Adım 1: Frontend - Auth Provider'ı Email/Password'e Güncelle

**Files:**
- Modify: `frontend/lib/features/auth/providers/auth_provider.dart`

**Değişiklikler:**
- `sendPhoneCode` yerine `signInWithEmail` fonksiyonu
- `verifyOtpCode` yerine `signUpWithEmail` fonksiyonu
- Firebase `createUserWithEmailAndPassword` ve `signInWithEmailAndPassword` kullanılacak
- Backend'e Firebase ID Token gönderilecek

- [ ] **Step 1: `AuthNotifier` sınıfını güncelle — email/password metodları ekle**

```dart
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
      );
      return true;
    }
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
      final backendSuccess = await _loginToBackend(credential.user!);
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: backendSuccess,
      );
      return true;
    }
    return false;
  } catch (e) {
    state = state.copyWith(isLoading: false, error: e.toString());
    return false;
  }
}
```

- [ ] **Step 2: `_loginToBackend` fonksiyonunu güncelle — invitation_token desteği ekle**
  - Kayıt olurken davet linkinden gelen token varsa backend'e gönder

---

## Adım 2: Frontend - Email/Password Login Ekranı Oluştur

**Files:**
- Create: `frontend/lib/features/auth/screens/email_login_screen.dart`
- Modify: `frontend/lib/features/auth/screens/role_selection_screen.dart`

**Açıklama:** Tek bir ekran hem login hem register modunu destekleyecek.

- [ ] **Step 1: `email_login_screen.dart` oluştur**

```dart
class EmailLoginScreen extends ConsumerStatefulWidget {
  final String role;
  final String? invitationToken; // Davet linkinden gelen token

  const EmailLoginScreen({
    Key? key,
    required this.role,
    this.invitationToken,
  }) : super(key: key);
}
```

- [ ] **Step 2: Role selection'dan email login'e yönlendir**
  - `/role` → `/email-login?role=agent` (agent için)
  - Davet linkinden gelen: `/email-login?role=tenant&token=xxx`

---

## Adım 3: Frontend - Gereksiz Ekranları Kaldır

**Files:**
- Delete: `frontend/lib/features/auth/screens/phone_login_screen.dart`
- Delete: `frontend/lib/features/auth/screens/otp_verification_screen.dart`
- Modify: Routing (router)

- [ ] **Step 1: `main.dart` veya router'dan phone ve otp route'larını kaldır**
- [ ] **Step 2: `simple_login_screen.dart`'ı da kaldır** (artık email login var)

---

## Adım 4: Backend - `/auth/login` Endpoint'i Zaten Hazır

**Files:**
- İyi haber: Backend'de `/auth/login` endpoint'i zaten Firebase token doğruluyor
- Sadece `invitation_token` desteğinin çalıştığından emin ol

**Mevcut akış:**
1. Flutter `signInWithEmailAndPassword` → Firebase ID Token alır
2. Flutter backend'e POST `/auth/login` with `firebase_id_token`
3. Backend `verify_firebase_token` ile token'ı doğrular
4. Backend kullanıcıyı DB'de bulur/yoksa oluşturur
5. Backend kullanıcı profili döner

---

## Adım 5: Sizin Yapmanız Gereken (Firebase Console)

**Zaten yapıldı:** Email/Password provider aktif ✓

---

## Dosya Yapısı (Summary)

| Dosya | Durum |
|---|---|
| `backend/app/api/endpoints/auth.py` | ✓ Zaten hazır |
| `frontend/lib/features/auth/providers/auth_provider.dart` | Güncellenecek |
| `frontend/lib/features/auth/screens/email_login_screen.dart` | Oluşturulacak |
| `frontend/lib/features/auth/screens/phone_login_screen.dart` | Silinecek |
| `frontend/lib/features/auth/screens/otp_verification_screen.dart` | Silinecek |
| `frontend/lib/features/auth/screens/simple_login_screen.dart` | Silinecek |

---

## Notlar

- Backend `/auth/login` endpoint'i zaten email/password ile gelen Firebase token'ları destekliyor
- Firebase Email/Password Auth'dan gelen ID Token, Phone OTP'den gelen token ile aynı formatta
- Tek fark: `phone_number` yerine `email` alanı geliyor (ama `verify_firebase_token` her ikisini de destekliyor)