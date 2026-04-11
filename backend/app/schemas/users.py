from pydantic import BaseModel, UUID4, Field
from typing import Optional
from datetime import datetime

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

class UserLogin(BaseModel):
    """Müşteri iOS, Flutter veya Web'de Firebase OTP girişini tamamlayınca ulaşılan final paket."""
    firebase_id_token: str = Field(..., description="Flutter tarafından backend doğrulayıcısına sunulan Google id_token.")
    full_name: str = Field(..., description="Müşterinin manuel eklediği isim soyisim.")
    invitation_token: Optional[str] = Field(None, description="Kayıt Linkindeki benzersiz JWT jeton (Varsa)")

class UserResponse(BaseModel):
    """Dışarı çıkarılacak güvenli kullanıcı profil iskeleti"""
    id: UUID4
    full_name: str
    phone_number: Optional[str]
    email: Optional[str]
    role: str
    
    class Config:
        from_attributes = True

class LoginResponse(BaseModel):
    success: bool
    user: UserResponse
    access_token: str
    message: str


class FCMTokenRegister(BaseModel):
    """Kullanıcının cihaz FCM push notification token'ını kaydeder. PRD §3.3."""
    fcm_token: str = Field(..., description="Firebase Cloud Messaging cihaz token'ı")
    device_type: str = Field(..., description="Cihaz tipi: 'ios', 'android', 'web'")


class FCMTokenResponse(BaseModel):
    success: bool
    message: str
