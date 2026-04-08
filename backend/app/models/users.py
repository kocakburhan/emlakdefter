import enum
from sqlalchemy import Column, String, ForeignKey, Enum, Boolean, DateTime
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from .base import BaseModel

class SubscriptionStatus(str, enum.Enum):
    trial = "trial"
    active = "active"
    suspended = "suspended"

class GlobalUserRole(str, enum.Enum):
    superadmin = "superadmin"
    standard = "standard"

class StaffRole(str, enum.Enum):
    admin = "admin"
    agent = "agent"

class DeviceType(str, enum.Enum):
    ios = "ios"
    android = "android"
    web = "web"

class Agency(BaseModel):
    __tablename__ = "agencies"
    
    name = Column(String, nullable=False)
    subscription_status = Column(Enum(SubscriptionStatus), default=SubscriptionStatus.trial, nullable=False)
    
    staff = relationship("AgencyStaff", back_populates="agency")
    properties = relationship("Property", back_populates="agency")
    invitations = relationship("Invitation", back_populates="agency")

class User(BaseModel):
    __tablename__ = "users"
    
    phone_number = Column(String, unique=True, index=True, nullable=True)
    email = Column(String, unique=True, index=True, nullable=True)
    full_name = Column(String, nullable=False)
    role = Column(Enum(GlobalUserRole), default=GlobalUserRole.standard, nullable=False)
    status = Column(String, default="active") # active, inactive
    
    staff_profiles = relationship("AgencyStaff", back_populates="user")
    device_tokens = relationship("UserDeviceToken", back_populates="user")

class AgencyStaff(BaseModel):
    __tablename__ = "agency_staff"
    
    agency_id = Column(UUID(as_uuid=True), ForeignKey("agencies.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    role = Column(Enum(StaffRole), default=StaffRole.agent, nullable=False)
    
    agency = relationship("Agency", back_populates="staff")
    user = relationship("User", back_populates="staff_profiles")

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
