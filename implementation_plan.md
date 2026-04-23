# EmlakDefteri Auth & Admin Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** EmlakDefteri platformu için yeni auth sistemi ve admin paneli inşa etmek

**Architecture:** Tek giriş ekranı (email/telefon), role-based routing, Firebase OTP ile şifre belirleme, superadmin admin paneli

**Tech Stack:** Python/FastAPI (backend), Flutter (frontend), Firebase Auth, PostgreSQL

---

## PHASE 1: Backend - Model ve Auth Endpoint'ler

### Task 1: User Model ve UserRole Enum Güncelleme

**Files:**
- Modify: `backend/app/models/users.py`
- Modify: `backend/app/models/__init__.py`

- [ ] **Step 1: Mevcut UserRole ve GlobalUserRole kontrol et**

```python
# backend/app/models/__init__.py içinde mevcut enum'ları kontrol et
# GlobalUserRole ve StaffRole var, bunları güncelleyeceğiz
```

- [ ] **Step 2: UserRole enum oluştur**

```python
# backend/app/models/users.py dosyasının başına ekle
class UserRole(str, Enum):
    superadmin = "superadmin"
    boss = "boss"
    employee = "employee"
    tenant = "tenant"
    landlord = "landlord"
```

- [ ] **Step 3: User tablosu alanlarını güncelle**

```python
# User class'ını güncelle:
class User(BaseModel):
    __tablename__ = "users"

    # Auth alanları
    email = Column(String, unique=True, index=True, nullable=True)
    phone_number = Column(String, unique=True, index=True, nullable=True)
    password_hash = Column(String, nullable=True)  # NULL = ilk giriş bekleniyor
    firebase_uid = Column(String, unique=True, nullable=True)

    # Profil
    full_name = Column(String, nullable=False)

    # Rol ve durum - Mevcut role ve status alanlarını UserRole enum kullanacak şekilde güncelle
    role = Column(Enum(UserRole), nullable=False)
    status = Column(String, default="active")  # active, inactive, pending_password_reset

    # Organizasyon - agency_id FK
    agency_id = Column(UUID(as_uuid=True), ForeignKey("agencies.id"), nullable=True)

    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    last_login_at = Column(DateTime, nullable=True)

    # Soft delete
    is_deleted = Column(Boolean, default=False)
    deleted_at = Column(DateTime, nullable=True)
```

- [ ] **Step 4: AgencyStaff tablosunu kaldır veya işaretle**

```python
# AgencyStaff tablosu mevcut kalacak ama agency_id User tablosuna taşınacak
# Bu tabloyu şimdilik bırak, sonra migrate edilecek
```

- [ ] **Step 5: Commit**

```bash
git add backend/app/models/users.py backend/app/models/__init__.py
git commit -m "feat: add UserRole enum and update User model for new auth system"
```

---

### Task 2: User Schemas Güncelleme

**Files:**
- Modify: `backend/app/schemas/users.py`

- [ ] **Step 1: Mevcut schemas'ları incele**

```python
# user role enum için schemas ekle
```

- [ ] **Step 2: UserCreate schema oluştur**

```python
# Boss/patron oluşturmak için admin paneli kullanacak
class UserCreate(BaseModel):
    email: Optional[str] = None
    phone_number: Optional[str] = None
    full_name: str
    role: UserRole
    agency_id: Optional[UUID] = None

    # Validation: en az biri (email veya phone) olmalı
```

- [ ] **Step 3: UserResponse schema oluştur**

```python
class UserResponse(BaseModel):
    id: UUID
    email: Optional[str]
    phone_number: Optional[str]
    full_name: str
    role: UserRole
    status: str
    agency_id: Optional[UUID]
    created_at: datetime
    last_login_at: Optional[datetime]
```

- [ ] **Step 4: LoginRequest schema oluştur**

```python
class LoginRequest(BaseModel):
    email_or_phone: str  # email veya telefon numarası
```

- [ ] **Step 5: LoginResponse schema oluştur**

```python
class LoginResponse(BaseModel):
    status: str  # "password_required" | "otp_required" | "success"
    user: Optional[UserResponse] = None
    message: Optional[str] = None
```

- [ ] **Step 6: Password ni görüntüle ve SetPasswordRequest schema oluştur**

```python
class SetPasswordRequest(BaseModel):
    password: str
    confirm_password: str
```

- [ ] **Step 7: Commit**

```bash
git add backend/app/schemas/users.py
git commit -m "feat: update user schemas for new auth flow"
```

---

### Task 3: Auth Endpoint'leri Yazma

**Files:**
- Modify: `backend/app/api/endpoints/auth.py` (tamamen yeniden yazılacak)
- Modify: `backend/app/api/api.py` (router güncelleme)

- [ ] **Step 1: Mevcut auth.py dosyasını incele ve yeni yapıyı planla**

- [ ] **Step 2: POST /api/v1/auth/login endpoint oluştur**

```python
@router.post("/login")
async def login(request: LoginRequest, db: AsyncSession = Depends(deps.db)):
    # 1. Input validation (email format veya Türkiye telefon formatı)
    # 2. User tablosunda ara (email veya phone_number ile)
    # 3. User yok → "Bu bilgilerle kayıtlı hesap bulunamadı"
    # 4. User var, password_hash NULL → status: "otp_required"
    # 5. User var, password_hash var → status: "password_required"
```

- [ ] **Step 3: POST /api/v1/auth/send-otp endpoint oluştur**

```python
@router.post("/send-otp")
async def send_otp(request: LoginRequest, db: AsyncSession = Depends(deps.db)):
    # 1. User'ı bul
    # 2. Email ise → firebase_admin.auth.generate_email_verification_link()
    # 3. Telefon ise → Firebase SMS OTP (client-side yapılacak, backend sadece kayıt tutacak)
    # 4. OTP attempt kaydet (rate limiting için)
```

- [ ] **Step 4: POST /api/v1/auth/verify-otp endpoint oluştur**

```python
@router.post("/verify-otp")
async def verify_otp(request: VerifyOTPRequest, db: AsyncSession = Depends(deps.db)):
    # 1. OTP kodunu doğrula (email için link tıklama, telefon için Firebase SDK)
    # 2. Doğruysa → set-password akışına geç
    # 3. Yanlışsa → 3 yanlış deneme kontrolü
```

- [ ] **Step 5: POST /api/v1/auth/set-password endpoint oluştur**

```python
@router.post("/set-password")
async def set_password(request: SetPasswordRequest, user_id: UUID, db: AsyncSession = Depends(deps.db)):
    # 1. Password validation (8+ char, 1 uppercase, 1 number)
    # 2. Confirm password match kontrolü
    # 3. password_hash = bcrypt.hash(password)
    # 4. status = "active"
    # 5. JWT token oluştur ve döndür
```

- [ ] **Step 6: POST /api/v1/auth/password-login endpoint oluştur**

```python
@router.post("/password-login")
async def password_login(request: PasswordLoginRequest, db: AsyncSession = Depends(deps.db)):
    # 1. User'ı bul
    # 2. password_hash doğrula
    # 3. 5 yanlış deneme kontrolü (15 dakika kilit)
    # 4. Başarılı → JWT token döndür
    # 5. last_login_at güncelle
```

- [ ] **Step 7: GET /api/v1/auth/me endpoint güncelle**

```python
@router.get("/me")
async def get_me(current_user: User = Depends(deps.get_current_user)):
    # Mevcut user bilgilerini döndür (role, agency_id dahil)
```

- [ ] **Step 8: POST /api/v1/auth/forgot-password endpoint oluştur**

```python
@router.post("/forgot-password")
async def forgot_password(request: LoginRequest, db: AsyncSession = Depends(deps.db)):
    # 1. User'ı bul
    # 2. password_hash NULL ise OTP flow başlat
    # 3. password_hash varsa OTP gönder, kullanıcı yeni şifre belirleyecek
```

- [ ] **Step 9: Router'a auth endpoints ekle**

```python
# backend/app/api/api.py
from .endpoints import auth, admin, agency

api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
```

- [ ] **Step 10: Commit**

```bash
git add backend/app/api/endpoints/auth.py backend/app/api/api.py
git commit -m "feat: implement new auth endpoints (login, otp, password)"
```

---

### Task 4: Firebase Entegrasyonu Güncelleme

**Files:**
- Modify: `backend/app/core/firebase.py`

- [ ] **Step 1: Mevcut firebase.py'yi incele**

- [ ] **Step 2: generate_email_verification_link fonksiyonunu kontrol et**

```python
# Email verification link gönderme
def generate_email_verification_link(email: str) -> str:
    # firebase_admin.auth.generate_email_verification_link(email)
    link = auth.generate_email_verification_link(email)
    return link
```

- [ ] **Step 3: OTP için gerekli fonksiyonları ekle/yeniden düzenle**

```python
# Telefon OTP için Firebase'e ihtiyaç yok, client-side Firebase SDK kullanır
# Backend sadece OTP attempt kaydı tutacak
```

- [ ] **Step 4: Commit**

```bash
git add backend/app/core/firebase.py
git commit -m "feat: update firebase integration for email verification"
```

---

## PHASE 2: Frontend - Yeni Login Flow

### Task 5: Auth Provider Güncelleme

**Files:**
- Modify: `frontend/lib/features/auth/providers/auth_provider.dart`

- [ ] **Step 1: Mevcut auth_provider.dart'yı incele**

- [ ] **Step 2: AuthState yapısını güncelle**

```dart
class AuthState {
  bool isLoading;
  String? error;
  bool isAuthenticated;
  UserProfile? user;
  String? pendingUserId;  // OTP doğrulandıktan sonra şifre belirlemek için
}
```

- [ ] **Step 3: loginWithEmailOrPhone methodu ekle**

```dart
Future<AuthResult> loginWithEmailOrPhone(String emailOrPhone);
```

- [ ] **Step 4: sendOtp methodu ekle**

```dart
Future<AuthResult> sendOtp(String emailOrPhone);
```

- [ ] **Step 5: verifyOtp methodu ekle**

```dart
Future<AuthResult> verifyOtp(String code, String userId);
```

- [ ] **Step 6: setPassword methodu ekle**

```dart
Future<AuthResult> setPassword(String password, String confirmPassword, String userId);
```

- [ ] **Step 7: passwordLogin methodu ekle**

```dart
Future<AuthResult> passwordLogin(String emailOrPhone, String password);
```

- [ ] **Step 8: forgotPassword methodu ekle**

```dart
Future<AuthResult> forgotPassword(String emailOrPhone);
```

- [ ] **Step 9: Commit**

```bash
git add frontend/lib/features/auth/providers/auth_provider.dart
git commit -m "feat: update auth provider with new login methods"
```

---

### Task 6: Yeni Login Screen

**Files:**
- Create: `frontend/lib/features/auth/screens/login_screen.dart`
- Modify: `frontend/lib/features/auth/screens/role_selection_screen.dart` (kaldırılacak)
- Modify: `frontend/lib/core/router/router.dart`

- [ ] **Step 1: Yeni login_screen.dart oluştur**

```dart
// Email veya telefon input,
// Devam Et butonu
// Telefon ise +90 prefix göster
// @ karakteri varsa email olarak algıla
```

- [ ] **Step 2: password_screen.dart oluştur**

```dart
// Standart şifre girişi
// Göz ikonu ile show/hide
// "Şifremi unuttum" linki
```

- [ ] **Step 3: otp_screen.dart oluştur**

```dart
// 6 haneli ayrı input kutuları
// Geri sayım timer
// Kodu tekrar gönder butonu
```

- [ ] **Step 4: set_password_screen.dart oluştur**

```dart
// Şifre + şifre tekrar
// Real-time validation (8+ char, uppercase, number)
// Anlık ✓/✗ gösterimi
```

- [ ] **Step 5: Router güncelle**

```dart
// '/' → login_screen
// '/password' → password_screen (login sonrası)
// '/otp' → otp_screen
// '/set-password' → set_password_screen

// Auth state'e göre routing:
// superadmin → /admin
// boss/employee → /agent
// tenant → /tenant
// landlord → /landlord
```

- [ ] **Step 6: Eski role_selection_screen.dart ve email_login_screen.dart kaldır**

- [ ] **Step 7: Commit**

```bash
git add frontend/lib/features/auth/screens/
git commit -m "feat: implement new login flow UI screens"
```

---

## PHASE 3: Backend - Admin Endpoint'ler

### Task 7: Admin Endpoint'leri Yazma

**Files:**
- Create: `backend/app/api/endpoints/admin.py`
- Modify: `backend/app/api/api.py`
- Modify: `backend/app/api/deps.py`

- [ ] **Step 1: deps.py'ye superadmin kontrolü ekle**

```python
async def require_superadmin(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if current_user.role != UserRole.superadmin:
        raise HTTPException(status_code=403, detail="Superadmin erişimi gerekli")
    return current_user
```

- [ ] **Step 2: Agency CRUD endpoint'leri oluştur**

```python
# GET /api/v1/admin/agencies - Tüm ofisleri listele
# POST /api/v1/admin/agencies - Yeni ofis oluştur
# GET /api/v1/admin/agencies/{id} - Ofis detay
# PUT /api/v1/admin/agencies/{id} - Ofis güncelle
# DELETE /api/v1/admin/agencies/{id} - Ofis sil (soft delete)
```

- [ ] **Step 3: User CRUD endpoint'leri oluştur**

```python
# GET /api/v1/admin/users - Tüm kullanıcıları listele (filtreleme ile)
# POST /api/v1/admin/users - Yeni patron oluştur
# GET /api/v1/admin/users/{id} - Kullanıcı detay
# PUT /api/v1/admin/users/{id} - Kullanıcı güncelle
# DELETE /api/v1/admin/users/{id} - Kullanıcı sil (soft delete)
# POST /api/v1/admin/users/{id}/deactivate - Kullanıcı pasife al
```

- [ ] **Step 4: API router'a admin endpoints ekle**

```python
api_router.include_router(admin.router, prefix="/admin", tags=["admin"])
```

- [ ] **Step 5: Commit**

```bash
git add backend/app/api/endpoints/admin.py backend/app/api/api.py backend/app/api/deps.py
git commit -m "feat: implement admin endpoints for agency and user management"
```

---

### Task 8: Patron Çalışan Ekleme Endpoint'i

**Files:**
- Create: `backend/app/api/endpoints/agency.py`
- Modify: `backend/app/api/api.py`

- [ ] **Step 1: POST /api/v1/agency/employees endpoint oluştur**

```python
# Boss veya employee yeni çalışan ekleyebilir (her ikisi de aynı yetkiye sahip şimdilik)
# Email veya telefon validation
# Unique kontrol
# password_hash = NULL (çalışan ilk giriş yapacak)
# agency_id = current_user.agency_id
```

- [ ] **Step 2: GET /api/v1/agency/employees endpoint oluştur**

```python
# Ofisteki tüm çalışanları listele
# Boss ve employee'yi göster (role'e göre filtreleme yapılabilir)
```

- [ ] **Step 3: API router'a agency endpoints ekle**

- [ ] **Step 4: Commit**

```bash
git add backend/app/api/endpoints/agency.py backend/app/api/api.py
git commit -m "feat: implement agency endpoints for employee management"
```

---

## PHASE 4: Frontend - Admin Panel

### Task 9: Admin Provider ve API Servisleri

**Files:**
- Create: `frontend/lib/features/admin/providers/admin_provider.dart`
- Create: `frontend/lib/core/services/admin_service.dart`

- [ ] **Step 1: admin_service.dart oluştur**

```dart
// API call'ları için
class AdminService {
  // Agency CRUD
  Future<List<Agency>> getAgencies();
  Future<Agency> createAgency(AgencyCreate request);
  Future<Agency> updateAgency(String id, AgencyUpdate request);
  Future<void> deleteAgency(String id);

  // User CRUD
  Future<List<User>> getUsers({String? role, String? agencyId});
  Future<User> createUser(UserCreate request);
  Future<User> updateUser(String id, UserUpdate request);
  Future<void> deleteUser(String id);
  Future<void> deactivateUser(String id);
}
```

- [ ] **Step 2: admin_provider.dart oluştur**

```dart
// State management for admin panel
class AdminNotifier extends StateNotifier<AdminState> {
  final AdminService _service;

  // Methods for CRUD operations
}
```

- [ ] **Step 3: Commit**

```bash
git add frontend/lib/features/admin/providers/admin_provider.dart frontend/lib/core/services/admin_service.dart
git commit -m "feat: add admin service and provider"
```

---

### Task 10: Admin Panel UI Screens

**Files:**
- Create: `frontend/lib/features/admin/screens/admin_dashboard_screen.dart`
- Create: `frontend/lib/features/admin/screens/agencies_screen.dart`
- Create: `frontend/lib/features/admin/screens/agency_detail_screen.dart`
- Create: `frontend/lib/features/admin/screens/users_screen.dart`
- Create: `frontend/lib/features/admin/screens/user_detail_screen.dart`
- Create: `frontend/lib/features/admin/screens/create_boss_screen.dart`
- Create: `frontend/lib/features/admin/screens/create_agency_screen.dart`

- [ ] **Step 1: Admin Dashboard**

```dart
// Özet istatistikler
// Toplam ofis sayısı, kullanıcı sayısı, aktif/pasif oranları
```

- [ ] **Step 2: Agencies Screen**

```dart
// Tüm ofislerin listesi (DataTable)
// Ofis oluşturma dialoğu
// Düzenleme/Silme aksiyonları
```

- [ ] **Step 3: Agency Detail Screen**

```dart
// Ofis bilgileri
// Bu ofise bağlı kullanıcılar (patron + çalışanlar)
// Patron: "İlk giriş bekleniyor" veya "Aktif"
```

- [ ] **Step 4: Users Screen**

```dart
// Tüm kullanıcıların listesi (filtrelenebilir)
// Role, agency, status filtreleri
```

- [ ] **Step 5: User Detail Screen**

```dart
// Kullanıcı bilgileri
// Düzenleme formu
// Pasife alma/Silme aksiyonları
```

- [ ] **Step 6: Create Boss Screen (Admin panel içinde)**

```dart
// Ofis seçimi (dropdown)
// Ad Soyad, Email veya Telefon
// Form validation
```

- [ ] **Step 7: Create Agency Screen**

```dart
// Ofis adı, adres
// Form validation
```

- [ ] **Step 8: Router'a admin routes ekle**

```dart
// '/admin' → admin_dashboard
// '/admin/agencies' → agencies_screen
// '/admin/agencies/:id' → agency_detail_screen
// '/admin/users' → users_screen
// '/admin/users/:id' → user_detail_screen
```

- [ ] **Step 9: Commit**

```bash
git add frontend/lib/features/admin/screens/
git commit -m "feat: implement admin panel UI screens"
```

---

## PHASE 5: Frontend - Patron Çalışan Ekranı

### Task 11: Patron Çalışan Ekleme UI

**Files:**
- Modify: `frontend/lib/features/agent/screens/employees_screen.dart` (veya yeni oluştur)
- Modify: `frontend/lib/features/agent/providers/agent_provider.dart`

- [ ] **Step 1: Employees tab veya ekranı oluştur**

```dart
// Mevcut agent dashboard'unda "Çalışanlar" bölümü
// "Yeni Çalışan Ekle" butonu
// Çalışan listesi (şifresi belirlenmemiş vs aktif)
```

- [ ] **Step 2: Create Employee form**

```dart
// Ad Soyad (zorunlu)
// Email veya Telefon (zorunlu, en az biri)
// Validation
```

- [ ] **Step 3: API entegrasyonu**

```dart
// POST /api/v1/agency/employees
// GET /api/v1/agency/employees
```

- [ ] **Step 4: Agent provider güncelle**

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/features/agent/
git commit -m "feat: add employee management UI for boss"
```

---

## PHASE 6: Cleanup

### Task 12: Eski Kod Temizliği

**Files:**
- Modify: `backend/app/models/users.py` (AgencyStaff kaldırma)
- Modify: `backend/app/api/endpoints/auth.py` (eski register endpoint kaldırma)
- Modify: `frontend/lib/features/auth/` (eski screens kaldırma)

- [ ] **Step 1: Eski auth endpoint'lerini kaldır**

```python
# /auth/register, eski /auth/login endpoint'lerini kaldır
# Sadece yeni endpoint'leri tut
```

- [ ] **Step 2: Eski frontend screens kaldır**

```dart
// role_selection_screen.dart
// email_login_screen.dart
```

- [ ] **Step 3: AgencyStaff migration**

```python
# Eğer veri varsa, User.agency_id'ye taşı
# Sonra AgencyStaff tablosunu kaldır
```

- [ ] **Step 4: Commit**

```bash
git add backend/app/models/users.py frontend/lib/features/auth/
git commit -m "chore: remove old auth code and unused endpoints"
```

---

## Verification

### Backend Test

```bash
# Auth endpoint'lerini test et
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email_or_phone": "test@example.com"}'

# Admin endpoint'lerini test et (superadmin token ile)
curl -X GET http://localhost:8000/api/v1/admin/agencies \
  -H "Authorization: Bearer <superadmin_token>"
```

### Frontend Test

```bash
cd frontend
flutter run
```

1. Login ekranında email veya telefon gir → "Devam Et"
2. Şifresi yok → OTP ekranı açılır
3. Şifresi var → Şifre ekranı açılır
4. Şifre doğru → Role'e göre dashboard açılır
5. Superadmin login → Admin panel açılır

---

## Progress Tracking

- [x] Task 1: User Model ve UserRole Enum Güncelleme
- [x] Task 2: User Schemas Güncelleme
- [x] Task 3: Auth Endpoint'leri Yazma
- [x] Task 4: Firebase Entegrasyonu Güncelleme
- [ ] Task 5: Auth Provider Güncelleme
- [ ] Task 6: Yeni Login Screen
- [ ] Task 7: Admin Endpoint'leri Yazma
- [ ] Task 8: Patron Çalışan Ekleme Endpoint'i
- [ ] Task 9: Admin Provider ve API Servisleri
- [ ] Task 10: Admin Panel UI Screens
- [ ] Task 11: Patron Çalışan Ekleme UI
- [ ] Task 12: Eski Kod Temizliği

---

**Not:** Bu plan implementasyon ilerledikçe güncellenecektir. Her task tamamlandığında design-doc.md'ye notlar eklenecektir.