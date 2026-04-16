import enum
from sqlalchemy import Column, Integer, Date, ForeignKey, String, Boolean, Enum, JSON
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from .base import BaseModel

class ContractStatus(str, enum.Enum):
    """Kiracı sözleşme durumu — PRD §6.C"""
    active = "active"
    past = "past"

class LandlordUnit(BaseModel):
    __tablename__ = "landlords_units"
    
    agency_id = Column(UUID(as_uuid=True), ForeignKey("agencies.id", ondelete="CASCADE"), nullable=False, index=True)
    unit_id = Column(UUID(as_uuid=True), ForeignKey("property_units.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True) # Firebase bağlanınca dolacak
    temp_name = Column(String, nullable=True) # Kayıt olmadan önceki geçici adı
    temp_phone = Column(String, nullable=True)
    ownership_share = Column(Integer, default=100)
    
    unit = relationship("PropertyUnit", back_populates="landlord_relations")
    user = relationship("User")

class Tenant(BaseModel):
    __tablename__ = "tenants"
    
    agency_id = Column(UUID(as_uuid=True), ForeignKey("agencies.id", ondelete="CASCADE"), nullable=False, index=True)
    unit_id = Column(UUID(as_uuid=True), ForeignKey("property_units.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    temp_name = Column(String, nullable=True)
    temp_phone = Column(String, nullable=True)
    rent_amount = Column(Integer, nullable=False)
    currency = Column(String, default="TRY")
    payment_day = Column(Integer, nullable=False) # Her ayın kaçıncı günü (Örn: 15)
    start_date = Column(Date, nullable=False)
    end_date = Column(Date, nullable=False)
    actual_end_date = Column(Date, nullable=True) # Erken çıkış/sirkülasyon logu
    is_active = Column(Boolean, default=True)
    status = Column(Enum(ContractStatus), default=ContractStatus.active, nullable=False)
    contract_document_url = Column(String, nullable=True)  # Sözleşme PDF URL (Hetzner)
    documents = Column(JSON, nullable=True)  # [{"url": "...", "name": "...", "type": "contract"}]

    unit = relationship("PropertyUnit", back_populates="tenant_contracts")
    user = relationship("User")
