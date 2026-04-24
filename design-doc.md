# EmlakDefteri Auth & Admin Panel Tasarım Dokümanı

**Tarih:** 2026-04-23
**Versiyon:** 1.0
**Durum:** Tasarım tamamlandı, planlama aşamasında

---

## 1. Genel Bakış

### 1.1 Amaç
EmlakDefteri SaaS platformu için merkezi auth sistemi ve admin paneli inşa etmek.

### 1.2 Mevcut Durum
- Auth: Firebase Auth + Backend JWT hybrid (karışık bir yapı)
- Roller: `GlobalUserRole` (superadmin, standard) + `StaffRole` (boss, employee) — eksik kullanılıyor
- Giriş ekranı: 3 rol kartı (Emlakçı, Kiracı, Ev Sahibi) üzerinden email/password

### 1.3 Hedef Durum
- **Tek giriş ekranı**: Email veya telefon numarası ile evrensel giriş
- **Role-based routing**: Giriş yapan kullanıcının rolüne göre uygun arayüze yönlendirme
- **OTP-first flow**: Şifresi olmayan kullanıcılar için email/SMS OTP ile şifre belirleme
- **Admin paneli**: Superadmin'ler için kapsamlı yönetim paneli

---

## 2. Kullanıcı Rolleri ve Hiyerarşi

```
Superadmin (firebase console üretir)
    │
    └── Boss (superadmin oluşturur, ofise bağlar)
            │
            ├── Employee (boss oluşturur, ofise bağlanır)
            │
            ├── Tenant (boss/employee oluşturur, ofise/patrona bağlanır)
            │
            └── Landlord (boss/employee oluşturur, ofise/patrona bağlanır)
```

### Rol Tanımları

| Rol | Oluşturulma Kaynağı | Auth Yöntemi | UI |
|-----|---------------------|--------------|-----|
| `superadmin` | Firebase Console | Email/password (firebase) | Admin Panel |
| `boss` | Superadmin | Email veya telefon + OTP/şifre | Agent Dashboard |
| `employee` | Boss | Email veya telefon + OTP/şifre | Agent Dashboard |
| `tenant` | Boss/Employee | Email veya telefon + OTP/şifre | Tenant Dashboard |
| `landlord` | Boss/Employee | Email veya telefon + OTP/şifre | Landlord Dashboard |

**Not:** Boss ve employee şu aşamada aynı yetkilere sahip. Yetkilendirme (authorization) ileride eklenecek.

---

## 3. Veritabanı Modeli

### 3.1 User Tablosu (Unified)

```python
class UserRole(str, Enum):
    superadmin = "superadmin"
    boss = "boss"
    employee = "employee"
    tenant = "tenant"
    landlord = "landlord"

class User(BaseModel):
    __tablename__ = "users"

    # Auth alanları
    email = Column(String, unique=True, index=True, nullable=True)
    phone_number = Column(String, unique=True, index=True, nullable=True)
    password_hash = Column(String, nullable=True)  # NULL = ilk giriş bekleniyor (OTP ile şifre belirlenecek)
    firebase_uid = Column(String, unique=True, nullable=True)  # Firebase Auth UID

    # Profil alanları
    full_name = Column(String, nullable=False)

    # Rol ve durum
    role = Column(Enum(UserRole), nullable=False)
    status = Column(String, default="active")  # active, inactive, pending_password_reset

    # Organizasyon
    agency_id = Column(UUID(as_uuid=True), ForeignKey("agencies.id"), nullable=True)

    # Timestamp'ler
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    last_login_at = Column(DateTime, nullable=True)

    # Soft delete
    is_deleted = Column(Boolean, default=False)
    deleted_at = Column(DateTime, nullable=True)
```

### 3.2 Agency Tablosu (Mevcut - Korunacak)

```python
class Agency(BaseModel):
    __tablename__ = "agencies"

    name = Column(String, nullable=False)
    address = Column(String, nullable=True)
    subscription_status = Column(Enum(SubscriptionStatus), default=SubscriptionStatus.trial)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    is_deleted = Column(Boolean, default=False)
    deleted_at = Column(DateTime, nullable=True)
```

### 3.3 User-Agency İlişkisi

Boss ve employee için `User.agency_id` FK'si kullanılacak. Ayrı `AgencyStaff` tablosu kaldırılacak (mevcut yapı sadeleştirilecek).

**Not:** `AgencyStaff` tablosunda mevcut veri varsa migrate edilecek. Tenant ve Landlord için ayrı tablolar korunacak (mevcut yapı).

---

## 4. Auth Akışları

### 4.1 Giriş Ekranı (Frontend)

```
┌─────────────────────────────────────────────────────────────┐
│                    Hoş Geldiniz                            │
│                                                             │
│   ┌───────────────────────────────────────────────────┐    │
│   │  Email veya telefon numarası                      │    │
│   └───────────────────────────────────────────────────┘    │
│                                                             │
│                      [ Devam Et ]                           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Davranış:**
- Input placeholder: "Email veya telefon numarası"
- `@` karakteri varsa email olarak algıla
- Sadece rakam varsa telefon olarak algıla
- Telefon girildiğinde +90 prefix göster
- "Devam Et" butonu → format validation → backend isteği

### 4.2 Backend Kontrol Akışı

```
Kullanıcı email/telefon girer → "Devam Et"
         │
         ▼
    Format valid mi?
         │
    Yes ─┴─ No → "Geçerli bir email/telefon girin" hatası
         │
         ▼
    Backend: email veya phone_number ile User ara
         │
    ┌────┴────┐
    │         │
 User yok   User var
    │         │
    ▼         ▼
"Bu bilgilerle   password_hash var mı?
kayıtlı hesap        │
bulunamadı"      Yes ─┴─ No
                    │     │
                    ▼     ▼
              Şifre     OTP Flow
              ekranı    (4.4)
              (4.3)
```

### 4.3 Standart Giriş (Şifresi Var)

```
┌─────────────────────────────────────────────────────────────┐
│                    Tekrar Hoş Geldin                        │
│                                                             │
│   ┌───────────────────────────────────────────────────┐    │
│   │  •••••••••••• (şifre)                        👁    │    │
│   └───────────────────────────────────────────────────┘    │
│                                                             │
│              [ Giriş Yap ]                                  │
│                                                             │
│              ────────────────────────                       │
│              Şifremi unuttum                                │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Davranış:**
- Göz ikonu → şifreyi göster/gizle
- 5 yanlış deneme → 15 dakika kilit + "EmlakDefter danışmanı ile iletişime geçin"
- Şifremi unuttum → OTP flow'a git (backend'de email/phone zaten var, tekrar sorma)

### 4.4 OTP İlk Giriş Akışı (Şifresi Yok)

```
┌─────────────────────────────────────────────────────────────┐
│                    Doğrulama Kodu                            │
│                                                             │
│        [email/phone]'a doğrulama kodu gönderdik.            │
│                                                             │
│   ┌───┬───┬───┬───┬───┬───┐                              │
│   │ 1 │ 2 │ 3 │ 4 │ 5 │ 6 │                               │
│   └───┴───┴───┴───┴───┴───┘                              │
│                                                             │
│              Kalan süre: 02:45                              │
│                                                             │
│         [ Kodu Tekrar Gönder ] (3 yanlış后 aktif)          │
│                                                             │
│              [ Doğrula ]                                    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Davranış:**
- Email girdiyse → `sendEmailVerification()` Firebase fonksiyonu
- Telefon girdiyse → Firebase SMS OTP
- 6 haneli ayrı input kutuları
- 3 dakika geri sayım
- 3 yanlış deneme → blok, "Kodu tekrar gönder" aktif
- Doğru kod → Şifre belirleme ekranına git

### 4.5 Şifre Belirleme

```
┌─────────────────────────────────────────────────────────────┐
│                Yeni Şifrenizi Belirleyin                    │
│                                                             │
│   Şifre kuralları:                                          │
│   ☑ En az 8 karakter                                       │
│   ☑ En az bir büyük harf                                   │
│   ☑ En az bir rakam                                        │
│                                                             │
│   ┌───────────────────────────────────────────────────┐    │
│   │  Yeni şifre                                        │    │
│   └───────────────────────────────────────────────────┘    │
│   ┌───────────────────────────────────────────────────┐    │
│   │  Şifre tekrar                                       │    │
│   └───────────────────────────────────────────────────┘    │
│                                                             │
│              [ Kaydet ve Devam Et ]                        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Davranış:**
- Anlık ✓/✗ gösterimi (her kural için)
- İki alan eşleşmiyor → "Şifreler uyuşmuyor" hatası
- Tüm kurallar sağlandığında buton aktif
- Kaydet → password_hash kaydet → oturum aç → role'e göre yönlendir

### 4.6 Sonraki Girişler

Her zaman aynı flow:
1. Email/telefon gir → "Devam Et"
2. Backend şifresi olduğunu görür → Şifre ekranı
3. Şifre doğru → Dashboard

---

## 5. Admin Panel Kapsamı

### 5.1 Emlak Ofisi Yönetimi

| İşlem | Açıklama |
|-------|----------|
| Emlak Ofisi Oluşturma | Name, address ile yeni ofis yaratma |
| Emlak Ofisi Listeleme | Tüm ofisleri tablo olarak göster |
| Emlak Ofisi Düzenleme | Name, address güncelleme |
| Emlak Ofisi Silme | Soft delete (is_deleted = True) |
| Emlak Ofisi Detay | Ofise bağlı tüm kullanıcıları listele |

### 5.2 Kullanıcı Yönetimi

| İşlem | Açıklama |
|-------|----------|
| Kullanıcı Oluşturma | Patron: email/phone/name ile yeni boss oluştur |
| Kullanıcı Listeleme | Tüm kullanıcıları filtrelenebilir tablo olarak göster |
| Kullanıcı Düzenleme | Name, email, phone güncelleme |
| Kullanıcı Pasife Alma | status = "inactive", aktif oturumları sonlandır |
| Kullanıcı Silme | Soft delete |
| Kullanıcı Detay | Role, agency, status, son giriş tarihi |

### 5.3 Çalışan Ekleme (Patron Arayüzü)

**Patronun yeni çalışan ekleme akışı:**

1. Patron "Çalışanlar" bölümüne girer
2. "Yeni Çalışan Ekle" butonuna tıklar
3. Form: Ad Soyad (zorunlu), Email veya Telefon (zorunlu, en az biri)
4. Kaydet → Backend kontrol:
   - Format validation (email format / Türkiye telefon)
   - Unique kontrol (sistemde başka kullanıcıda var mı?)
5. Hata yoksa → employee oluştur, agency_id bağla, password_hash = NULL
6. Çalışan listesi güncellenir, "İlk giriş bekleniyor" status'u ile görünür

### 5.4 Sistem Ayarları (Gelecek)

- Subscription planları
- Sistem geneli bildirimler
- Log'lar, audit trail

---

## 6. Backend Değişiklikleri

### 6.1 Yeni veya Güncellenecek Dosyalar

| Dosya | Değişiklik |
|-------|-----------|
| `backend/app/models/users.py` | UserRole enum ekle, User modeli güncelle, AgencyStaff kaldır |
| `backend/app/schemas/users.py` | User schemas güncelle |
| `backend/app/api/endpoints/auth.py` | Tamamen yeniden yazılacak |
| `backend/app/api/endpoints/admin.py` | Admin panel endpoint'leri (yeni) |
| `backend/app/api/deps.py` | Superadmin kontrolü ekle |
| `backend/app/core/firebase.py` | sendEmailVerification, SMS OTP fonksiyonları kullanılacak |

### 6.2 Yeni Endpoint'ler

```
POST   /api/v1/auth/login               # Email veya telefon ile giriş
POST   /api/v1/auth/send-otp            # OTP gönder (email veya SMS)
POST   /api/v1/auth/verify-otp          # OTP doğrula
POST   /api/v1/auth/set-password         # Şifre belirle (OTP doğrulandıktan sonra)
GET    /api/v1/auth/me                  # Mevcut kullanıcı bilgisi

# Admin endpoint'leri (superadmin only)
GET    /api/v1/admin/agencies           # Tüm ofisleri listele
POST   /api/v1/admin/agencies           # Yeni ofis oluştur
GET    /api/v1/admin/agencies/{id}      # Ofis detay
PUT    /api/v1/admin/agencies/{id}      # Ofis güncelle
DELETE /api/v1/admin/agencies/{id}      # Ofis sil (soft delete)

GET    /api/v1/admin/users              # Tüm kullanıcıları listele
POST   /api/v1/admin/users              # Yeni kullanıcı (patron) oluştur
GET    /api/v1/admin/users/{id}         # Kullanıcı detay
PUT    /api/v1/admin/users/{id}         # Kullanıcı güncelle
DELETE /api/v1/admin/users/{id}         # Kullanıcı sil (soft delete)
POST   /api/v1/admin/users/{id}/deactivate  # Kullanıcı pasife al

# Patron: Çalışan ekleme (boss/employee)
POST   /api/v1/agency/employees         # Yeni çalışan ekle
GET    /api/v1/agency/employees         # Çalışanları listele
```

### 6.3 Mevcut Endpoint Değişiklikleri

- `/auth/login` → kaldırılıp yeni auth flow ile değiştirilecek
- `/auth/register` → kaldırılacak (artık gerekli değil)
- Mevcut `AgencyStaff` kaldırılacak, yerine `User.agency_id` FK'si kullanılacak

---

## 7. Frontend Değişiklikleri

### 7.1 Giriş Ekranı Değişikliği

**Mevcut:** Role selection → Email/Password
**Yeni:** Direkt email/telefon input → OTP/Şifre → Role-based routing

```dart
// Yeni giriş akışı
App('/', redirects: {
  '/login': '/',
})

// '/' - LoginScreen
// 'email veya telefon' input
// Devam Et → backend verify → password_hash kontrol
//   - NULL → OTP ekranı
//   - Var → Şifre ekranı

// OTP Screen
// 6 haneli input
// Doğrulama → SetPasswordScreen

// SetPassword Screen
// Şifre + Şifre tekrar
// Kaydet → meydan dashboard

// Password Screen (standart giriş)
// Şifre input + göster/gizle
// Giriş yap → dashboard

// Forgot password → OTP flow
```

### 7.2 Admin Panel Arayüzü

Admin paneli Flutter'da ayrı bir route olarak:
- `/admin` → AdminDashboard
- Alt sayfalar: `/admin/agencies`, `/admin/agencies/:id`, `/admin/users`, `/admin/users/:id`

**Admin paneli sayfaları:**
1. Dashboard (özet istatistikler)
2. Emlak Ofisleri (liste, oluştur, düzenle, sil)
3. Kullanıcılar (tüm kullanıcıları listele, filtrele, patron/çalışan ekle)
4. Sistem ayarları (gelecek)

### 7.3 Auth Provider Değişikliği

```dart
class AuthState {
  bool isLoading;
  String? error;
  bool isAuthenticated;
  UserProfile? user;
  String? invitationToken;  // eski kalabilir
}

// Yeni method'lar
Future<AuthResult> loginWithEmailOrPhone(String emailOrPhone);
Future<AuthResult> sendOtp(String emailOrPhone);
Future<AuthResult> verifyOtp(String code);
Future<AuthResult> setPassword(String password, String confirmPassword);
Future<AuthResult> forgotPassword(String emailOrPhone);  // OTP flow başlat
```

### 7.4 Role-Based Routing

```dart
// Router'da
final userRole = authState.user?.role;

switch (userRole) {
  case 'superadmin':
    return '/admin';
  case 'boss':
  case 'employee':
    return '/agent';
  case 'tenant':
    return '/tenant';
  case 'landlord':
    return '/landlord';
  default:
    return '/';
}
```

---

## 8. Güvenlik ve Doğrulama

### 8.1 Input Validation

**Email:**
- RFC 5322 uyumlu format kontrolü
- lowercase normalize

**Telefon:**
- Türkiye +90 prefix
- 10 haneli (531xxxxxxx formatı)
- Başında 0 varsa kaldır, +90 ekle

### 8.2 Unique Constraint

- Email veya telefon sistemde benzersiz olmalı
- Aynı email veya telefon ile iki kayıt olamaz

### 8.3 Rate Limiting

- OTP isteği: 3 istek/dakika
- Şifre deneme: 5 yanlış → 15 dakika kilit
- Genel auth: 10 istek/dakika

### 8.4 OTP Güvenliği

- 6 haneli rastgele kod
- 3 dakika geçerlilik
- 3 yanlış deneme → kod bloke, yenisi gönderilmeli
- Redis veya DB ile token tracking

---

## 9. Firebase Entegrasyonu

### 9.1 Kullanılacak Firebase Fonksiyonları

```python
# Email OTP
firebase_admin.auth.generate_email_verification_link(email)
# → Kullanıcı email'deki linke tıkladığında Firebase email'i doğrulmuş olur

# Telefon OTP
# Firebase Auth'da phone number verification
# Backend'de değil, client-side Firebase SDK ile yapılır
# Ancak backend'de token doğrulaması yapılır
```

### 9.2 Auth Flow Detayı

**Email OTP:**
1. Backend `generate_email_verification_link()` çağırır
2. Firebase email'e link gönderir
3. Kullanıcı linke tıklar → Firebase email'i doğrulanmış olarak işaretler
4. Backend polling veya client bildirimi ile durumu öğrenir
5. Email doğrulandı → şifre belirleme ekranı

**Telefon OTP:**
1. Client-side Firebase SDK ile `signInWithPhoneNumber()` çağırılır
2. SMS gelir, kullanıcı kodu girer
3. Client `verificationComplete` callback alır
4. Backend'e verification ID + code gönderilir
5. Backend Firebase'i doğrular → şifre belirleme

---

## 10. Geçiş Stratejisi

### 10.1 Migration Planı

1. **Phase 1: Backend**
   - UserRole enum ekle
   - User modeli güncelle (yeni alanlar, password_hash nullable)
   - Yeni auth endpoint'leri yaz
   - Admin endpoint'leri yaz
   - Mevcut auth endpoint'leri koru (geriye uyumluluk için, sonra kaldırılacak)

2. **Phase 2: Frontend - Yeni Auth Flow**
   - Login screen'i değiştir
   - OTP flow ekle
   - Password set screen ekle
   - Role-based routing ekle

3. **Phase 3: Frontend - Admin Panel**
   - Admin dashboard oluştur
   - Ofis yönetimi sayfaları
   - Kullanıcı yönetimi sayfaları

4. **Phase 4: Cleanup**
   - Eski auth endpoint'lerini kaldır
   - AgencyStaff tablosunu kaldır (veri migrate edildikten sonra)
   - Role selection screen'i kaldır

### 10.2 Geriye Uyumluluk

- Eski auth endpoint'leri belirli bir süre duracak
- Eski Firebase Auth token'ları geçerli kalacak
- Migration sırasında kullanıcılar etkilenmeyecek

---

## 11. Dosya Listesi

### Backend

```
backend/app/
├── models/
│   └── users.py           # UserRole enum, User model güncelleme
├── schemas/
│   └── users.py           # User schemas güncelleme
├── api/
│   └── endpoints/
│       ├── auth.py        # Yeniden yazılacak
│       ├── admin.py       # Yeni - admin panel endpoint'leri
│       └── agency.py      # Yeni - patron/employee endpoint'leri (çalışan ekleme)
├── core/
│   └── firebase.py        # Email verification, OTP fonksiyonları
└── main.py                # Router güncellemeleri
```

### Frontend

```
frontend/lib/
├── features/
│   ├── auth/
│   │   ├── screens/
│   │   │   ├── login_screen.dart         # Yeni - tek input
│   │   │   ├── otp_screen.dart           # Yeni - 6 haneli OTP
│   │   │   ├── set_password_screen.dart  # Yeni - şifre belirleme
│   │   │   ├── password_screen.dart      # Yeni - standart şifre girişi
│   │   │   └── (eski roller kaldırılacak)
│   │   └── providers/
│   │       └── auth_provider.dart        # Güncellenecek
│   └── admin/
│       ├── screens/
│       │   ├── admin_dashboard.dart      # Yeni
│       │   ├── agencies_screen.dart      # Yeni
│       │   ├── agency_detail_screen.dart # Yeni
│       │   ├── users_screen.dart         # Yeni
│       │   └── user_detail_screen.dart   # Yeni
│       └── providers/
│           └── admin_provider.dart       # Yeni
├── core/
│   └── router/
│       └── router.dart                  # Güncellenecek - role-based routing
```

---

## 12. Sonraki Adımlar

1. ✅ Tasarım tamamlandı
2. ⬜ Implementation plan hazırlanacak (writing-plans skill)
3. ⬜ Backend Phase 1: Model ve auth endpoint'ler
4. ⬜ Frontend Phase 1: Yeni login flow
5. ⬜ Backend Phase 2: Admin endpoint'ler
6. ⬜ Frontend Phase 2: Admin panel
7. ⬜ Test ve debug
8. ⬜ Cleanup

---

**Not:** Bu doküman implementasyon ilerledikçe güncellenecektir. Her phase tamamlandığında yapılan değişiklikler buraya not edilecektir.