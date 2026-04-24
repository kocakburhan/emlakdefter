import enum
from datetime import datetime
from sqlalchemy import Column, String, ForeignKey, Enum, Boolean, DateTime, Integer
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from .base import Base, BaseModel

class SubscriptionStatus(str, enum.Enum):
    trial = "trial"
    active = "active"
    suspended = "suspended"

class UserRole(str, enum.Enum):
    superadmin = "superadmin"
    boss = "boss"
    employee = "employee"
    tenant = "tenant"
    landlord = "landlord"

class GlobalUserRole(str, enum.Enum):
    superadmin = "superadmin"
    standard = "standard"

class StaffRole(str, enum.Enum):
    boss = "boss"          # Emlak ofisi sahibi/patron — tam yetki
    employee = "employee"  # Emlak ofisi çalışanı — standart yetki

class DeviceType(str, enum.Enum):
    ios = "ios"
    android = "android"
    web = "web"

class Agency(BaseModel):
    __tablename__ = "agencies"

    name = Column(String, nullable=False)
    address = Column(String, nullable=True)
    subscription_status = Column(Enum(SubscriptionStatus), default=SubscriptionStatus.trial, nullable=False)

    properties = relationship("Property", back_populates="agency")
    invitations = relationship("Invitation", back_populates="agency")

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

    # Brute-force & Lockout
    failed_login_attempts = Column(Integer, default=0, nullable=False)
    locked_until = Column(DateTime, nullable=True)

    # Soft delete
    is_deleted = Column(Boolean, default=False)
    deleted_at = Column(DateTime, nullable=True)

    device_tokens = relationship("UserDeviceToken", back_populates="user")

class Invitation(BaseModel):
    __tablename__ = "invitations"
    
    agency_id = Column(UUID(as_uuid=True), ForeignKey("agencies.id", ondelete="CASCADE"), nullable=False, index=True)
    token = Column(String, unique=True, index=True, nullable=False)
    target_role = Column(String, nullable=False) # 'tenant', 'landlord', 'agent'
    related_entity_id = Column(UUID(as_uuid=True), nullable=True) # UUID of the unit or property
    is_used = Column(Boolean, default=False, nullable=False)
    expires_at = Column(DateTime, nullable=False)
    
    agency = relationship("Agency", back_populates="invitations")

class UserDeviceToken(BaseModel):
    __tablename__ = "user_device_tokens"
    
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    fcm_token = Column(String, unique=True, nullable=False)
    device_type = Column(Enum(DeviceType), nullable=False)
    last_used_at = Column(DateTime, nullable=True)
    
    user = relationship("User", back_populates="device_tokens")


class AgencyStaff(BaseModel):
    __tablename__ = "agency_staff"

    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    agency_id = Column(UUID(as_uuid=True), ForeignKey("agencies.id", ondelete="CASCADE"), nullable=False, index=True)
    role = Column(Enum(StaffRole), nullable=False, default=StaffRole.employee)

    user = relationship("User")
    agency = relationship("Agency")


class PasswordResetAttempt(BaseModel):
    """OTP şifre sıfırlama talebi takibi — SMS Pumping koruması"""
    __tablename__ = "password_reset_attempts"

    phone_number = Column(String, nullable=False, index=True)
    attempted_at = Column(DateTime, nullable=False)
    ip_address = Column(String, nullable=True)


class EmailVerificationCode(BaseModel):
    """
    Email OTP doğrulama kodu takibi.
    Kullanıcı email giriş yaptığında, email'e gönderilen 6 haneli kodu saklar ve doğrular.
    """
    __tablename__ = "email_verification_codes"

    email = Column(String, nullable=False, index=True)
    code = Column(String, nullable=False)  # 6 haneli kod
    expires_at = Column(DateTime, nullable=False)
    attempts = Column(Integer, nullable=False, default=0)  # Yanlış deneme sayısı
    verified = Column(Boolean, nullable=False, default=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
