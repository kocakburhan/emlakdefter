import enum
from sqlalchemy import Column, String, ForeignKey, Integer, Float, Enum, JSON, DateTime, ARRAY
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from .base import BaseModel

class PropertyType(str, enum.Enum):
    apartment_complex = "apartment_complex"  # Apartman / Site
    standalone_house = "standalone_house"    # Müstakil / Villa
    land = "land"                            # Arsa / Tarla
    commercial = "commercial"                 # Ticari / Dükkan

class Property(BaseModel):
    __tablename__ = "properties"

    agency_id = Column(UUID(as_uuid=True), ForeignKey("agencies.id", ondelete="CASCADE"), nullable=False, index=True)
    name = Column(String, nullable=False) # Örn: 'Güneş Apartmanı'
    type = Column(Enum(PropertyType), nullable=False)
    address = Column(String, nullable=True)
    total_units = Column(Integer, default=1)
    central_dues = Column(Integer, default=0) # Merkezi Aidat (opsiyonel miras için)
    features = Column(JSON, nullable=True) # {"has_elevator": true, "has_pool": false} vb.

    # YENİ ALANLAR
    floor_count = Column(Integer, nullable=True)        # Kat sayısı (apartman için)
    year_built = Column(Integer, nullable=True)         # Yapım yılı
    land_area = Column(Integer, nullable=True)          # Arsa alanı m² (land için)
    commercial_type = Column(String, nullable=True)     # Ticari tipi — "shop", "office", "warehouse" vs

    agency = relationship("Agency", back_populates="properties")
    units = relationship("PropertyUnit", back_populates="property")

class UnitStatus(str, enum.Enum):
    vacant = "vacant"       # Boş
    rented = "rented"       # Kiralanmış
    maintenance = "maintenance"  # Bakımda

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
    commission_rate = Column(Float, default=0.0) # Komisyon oranı % (PRD §4.1.3-A)
    youtube_video_link = Column(String, nullable=True) # Liste dışı video linki (PRD §4.1.3-C)
    media_links = Column(ARRAY(String), nullable=True) # Fotoğraf galerisi
    features = Column(JSON, nullable=True) # Birime özel özellikler

    # YENİ ALANLAR (Property.type'a göre anlamlı)
    area_sqm = Column(Integer, nullable=True)         # m² cinsinden alan (land, commercial, standalone_house)
    unit_identifier = Column(String, nullable=True)    # Arsa: "Parsel 123", Dükkan: "Mağaza No: A1"
    notes = Column(String, nullable=True)              # Ek notlar

    property = relationship("Property", back_populates="units")
    landlord_relations = relationship("LandlordUnit", back_populates="unit")
    tenant_contracts = relationship("Tenant", back_populates="unit")
