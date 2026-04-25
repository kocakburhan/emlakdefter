from uuid import UUID
from pydantic import BaseModel, Field, EmailStr, field_validator
from typing import Optional
from datetime import datetime
from enum import Enum


class UserRole(str, Enum):
    superadmin = "superadmin"
    boss = "boss"
    employee = "employee"
    tenant = "tenant"
    landlord = "landlord"


# === Invitation Schemas ===
class InviteCreate(BaseModel):
    """Emlakçı bir malik/kiracı kaydetmek istediğinde Body'sinde yollayacağı veriler."""
    agency_id: UUID
    target_role: str = Field(..., description="Eklenecek hedef kitle: 'tenant', 'landlord', veya 'agent'")
    related_entity_id: Optional[UUID] = Field(None, description="İrtibatlanan PropertyUnit ID'si")

class InviteResponse(BaseModel):
    """Davet başarılı olunca emlakçıya dönülecek WhatsApp fırlatma linki referansları."""
    success: bool
    invite_url: str
    token: str
    expires_at: datetime


# === Auth Schemas ===

class LoginRequest(BaseModel):
    """Email veya telefon numarası ile giriş başlatma isteği"""
    email_or_phone: str = Field(..., min_length=1, description="Email veya telefon numarası")

    @field_validator('email_or_phone')
    @classmethod
    def validate_email_or_phone(cls, v):
        v = v.strip().lower()
        if '@' in v:
            # Email format validation
            if len(v) < 5 or '.' not in v:
                raise ValueError('Geçerli bir email adresi girin')
        else:
            # Phone format check (must contain only digits/symbols)
            digits = ''.join(filter(str.isdigit, v))
            # Just stripping down to digits. Turkish format typically starts with '0' -> '5' or just '5'
            if digits.startswith('0'):
                digits = digits[1:]
            if digits.startswith('90'):
                digits = '90' + digits[2:]  # leave it
            else:
                digits = '90' + digits
            # EmlakDefteri will store +905XXXXXXXXX format 
            if len(digits) != 12 or not digits.startswith('905'):
                raise ValueError('Geçerli bir Türkiye telefon numarası girin (5xx xxx xx xx)')
        return v


class AuthLoginResponse(BaseModel):
    """Giriş kontrolü sonrası dönecek yanıt"""
    status: str = Field(..., description="'password_required' | 'otp_required' | 'success'")
    user: Optional["UserResponse"] = None
    message: Optional[str] = None
    access_token: Optional[str] = None


class VerifyOTPRequest(BaseModel):
    """Email için 6 haneli OTP veya Telefon için Firebase SMS token doğrulaması"""
    email_or_phone: str
    code: Optional[str] = None  # Backend'den yollanan Email OTP için zorunlu
    firebase_id_token: Optional[str] = None  # Firebase SMS doğrulaması için zorunlu

class SetPasswordRequest(BaseModel):
    """Şifre belirleme isteği (OTP doğrulamasından sonra gelir veya Şifremi Unuttum)"""
    user_id: UUID
    new_password: str = Field(..., min_length=8, description="En az 8 karakter")
    confirm_password: str
    verification_token: Optional[str] = None # Yetkisiz şifre değiştirmeyi engellemek için

    @field_validator('new_password')
    @classmethod
    def validate_password(cls, v):
        if not any(c.isupper() for c in v):
            raise ValueError('Şifre en az bir büyük harf içermelidir')
        if not any(c.isdigit() for c in v):
            raise ValueError('Şifre en az bir rakam içermelidir')
        return v

    @field_validator('confirm_password')
    @classmethod
    def validate_match(cls, v, info):
        if 'new_password' in info.data and v != info.data['new_password']:
            raise ValueError('Şifreler uyuşmuyor')
        return v


class PasswordLoginRequest(BaseModel):
    """Şifre ile giriş isteği"""
    email_or_phone: str
    password: str


class ForgotPasswordRequest(BaseModel):
    """Şifremi unuttum isteği"""
    email_or_phone: str


class AdminCreateAgencyBossRequest(BaseModel):
    """Admin panelinden yeni Emlak Ofisi ve Patron oluşturma isteği"""
    agency_name: str = Field(..., min_length=1, description="Ofis adı (zorunlu)")
    agency_address: str = Field(..., min_length=1, description="Adres (zorunlu)")

    boss_full_name: Optional[str] = Field(None, description="Patron Ad Soyad (zorunlu)")
    boss_email: Optional[str] = None
    boss_phone_number: Optional[str] = Field(None, description="Telefon numarası (email veya telefon en az biri gerekli)")
    boss_password: Optional[str] = Field(None, description="Patronun şifresi (direct login için)")

class CreateEmployeeRequest(BaseModel):
    """Patron tarafından yeni Çalışan (Employee) oluşturma isteği"""
    full_name: str = Field(..., min_length=1, description="Çalışan Ad Soyad (zorunlu)")
    email: Optional[str] = None
    phone_number: Optional[str] = Field(None, description="Telefon numarası (email veya telefon en az biri gerekli)")
    password: Optional[str] = Field(None, description="Çalışanın şifresi (direct login için)")

# === User Schemas ===

class UserCreate(BaseModel):
    """Admin panel veya patron tarafından kullanıcı oluşturma"""
    email: Optional[str] = None
    phone_number: Optional[str] = None
    full_name: str = Field(..., min_length=1)
    role: UserRole
    agency_id: Optional[UUID] = None
    password: Optional[str] = Field(None, description="Kullanıcının şifresi (direct login için)")

    @field_validator('email')
    @classmethod
    def validate_email(cls, v):
        if v is not None and ('@' not in v or '.' not in v):
            raise ValueError('Geçerli bir email adresi girin')
        return v

    @field_validator('phone_number')
    @classmethod
    def validate_phone(cls, v):
        if v is not None:
            digits = ''.join(filter(str.isdigit, v))
            if len(digits) != 10 or not digits.startswith('5'):
                raise ValueError('Geçerli bir telefon numarası girin')
        return v


class UserUpdate(BaseModel):
    """Kullanıcı güncelleme"""
    email: Optional[str] = None
    phone_number: Optional[str] = None
    full_name: Optional[str] = None
    status: Optional[str] = None  # active, inactive


class UserResponse(BaseModel):
    """Dışarı çıkarılacak güvenli kullanıcı profil iskeleti"""
    id: UUID
    email: Optional[str]
    phone_number: Optional[str]
    full_name: str
    role: UserRole
    status: str
    agency_id: Optional[UUID]
    created_at: datetime
    last_login_at: Optional[datetime]

    model_config = {"from_attributes": True}


class UserLogin(BaseModel):
    """Müşteri iOS, Flutter veya Web'de Firebase OTP girişini tamamlayınca ulaşılan final paket."""
    firebase_id_token: str = Field(..., description="Flutter tarafından backend doğrulayıcısına sunulan Google id_token.")
    full_name: str = Field(..., description="Müşterinin manuel eklediği isim soyisim.")
    invitation_token: Optional[str] = Field(None, description="Kayıt Linkindeki benzersiz JWT jeton (Varsa)")

    model_config = {"from_attributes": True}


class LoginResponse(BaseModel):
    success: bool
    user: UserResponse
    access_token: str
    message: str


# === FCM Token Schemas ===

class FCMTokenRegister(BaseModel):
    """Kullanıcının cihaz FCM push notification token'ını kaydeder. PRD §3.3."""
    fcm_token: str = Field(..., description="Firebase Cloud Messaging cihaz token'ı")
    device_type: str = Field(..., description="Cihaz tipi: 'ios', 'android', 'web'")


class FCMTokenResponse(BaseModel):
    success: bool
    message: str


# Update forward references
LoginResponse.model_rebuild()