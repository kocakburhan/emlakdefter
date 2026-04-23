from pydantic import BaseModel, UUID4, Field, EmailStr, field_validator
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
    agency_id: UUID4
    target_role: str = Field(..., description="Eklenecek hedef kitle: 'tenant', 'landlord', veya 'agent'")
    related_entity_id: Optional[UUID4] = Field(None, description="İrtibatlanan PropertyUnit ID'si")

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
        v = v.strip()
        if '@' in v:
            # Email format validation
            if len(v) < 5 or '.' not in v:
                raise ValueError('Geçerli bir email adresi girin')
        else:
            # Phone format - Turkish phone (10 digits, starting with 5)
            digits = ''.join(filter(str.isdigit, v))
            if len(digits) != 10 or not digits.startswith('5'):
                raise ValueError('Geçerli bir telefon numarası girin (5xx xxx xx xx)')
        return v


class LoginResponse(BaseModel):
    """Giriş kontrolü sonrası dönecek yanıt"""
    status: str = Field(..., description="'password_required' | 'otp_required' | 'success'")
    user: Optional["UserResponse"] = None
    message: Optional[str] = None
    access_token: Optional[str] = None


class VerifyOTPRequest(BaseModel):
    """OTP doğrulama isteği"""
    user_id: UUID4
    code: str = Field(..., min_length=6, max_length=6)


class SetPasswordRequest(BaseModel):
    """Şifre belirleme isteği"""
    user_id: UUID4
    password: str = Field(..., min_length=8, description="En az 8 karakter")
    confirm_password: str

    @field_validator('password')
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
        if 'password' in info.data and v != info.data['password']:
            raise ValueError('Şifreler uyuşmuyor')
        return v


class PasswordLoginRequest(BaseModel):
    """Şifre ile giriş isteği"""
    email_or_phone: str
    password: str


class ForgotPasswordRequest(BaseModel):
    """Şifremi unuttum isteği"""
    email_or_phone: str


# === User Schemas ===

class UserCreate(BaseModel):
    """Admin panel veya patron tarafından kullanıcı oluşturma"""
    email: Optional[str] = None
    phone_number: Optional[str] = None
    full_name: str = Field(..., min_length=1)
    role: UserRole
    agency_id: Optional[UUID4] = None

    @field_validator('email', 'phone_number')
    @classmethod
    def at_least_one_contact(cls, v, info):
        # At least email or phone must be provided
        return v

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
    id: UUID4
    email: Optional[str]
    phone_number: Optional[str]
    full_name: str
    role: UserRole
    status: str
    agency_id: Optional[UUID4]
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