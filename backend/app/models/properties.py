import enum
from sqlalchemy import Column, String, ForeignKey, Integer, Enum, JSON, DateTime
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from .base import BaseModel

class PropertyType(str, enum.Enum):
    building = "building" # Apartman / Site
    single = "single"     # Müstakil / Arsa

class Property(BaseModel):
    __tablename__ = "properties"
    
    agency_id = Column(UUID(as_uuid=True), ForeignKey("agencies.id", ondelete="CASCADE"), nullable=False, index=True)
    name = Column(String, nullable=False) # Örn: 'Güneş Apartmanı'
    type = Column(Enum(PropertyType), nullable=False)
    address = Column(String, nullable=True)
    total_units = Column(Integer, default=1)
    central_dues = Column(Integer, default=0) # Merkezi Aidat (opsiyonel miras için)
    features = Column(JSON, nullable=True) # {"has_elevator": true, "has_pool": false} vb.
    
    agency = relationship("Agency", back_populates="properties")
    units = relationship("PropertyUnit", back_populates="property")

class UnitStatus(str, enum.Enum):
    vacant = "vacant"
    occupied = "occupied"

class PropertyUnit(BaseModel):
    __tablename__ = "property_units"

    agency_id = Column(UUID(as_uuid=True), ForeignKey("agencies.id", ondelete="CASCADE"), nullable=False, index=True)
    property_id = Column(UUID(as_uuid=True), ForeignKey("properties.id", ondelete="CASCADE"), nullable=False, index=True)
    door_number = Column(String, nullable=False)
    floor = Column(String, nullable=True)
    status = Column(Enum(UnitStatus), default=UnitStatus.vacant, nullable=False)
    vacant_since = Column(DateTime, nullable=True) # Boş kalma süresi analitiği için
    dues_amount = Column(Integer, default=0) # Aidat bedeli
    rent_price = Column(Integer, nullable=True) # Kira bedeli (PRD §4.1.3)
    
    property = relationship("Property", back_populates="units")
    landlord_relations = relationship("LandlordUnit", back_populates="unit")
    tenant_contracts = relationship("Tenant", back_populates="unit")
