from pydantic import BaseModel, UUID4, Field, NonNegativeInt
from typing import Optional, Dict, Any, List
from datetime import datetime

class PropertyUnitBase(BaseModel):
    """Ortak Daire/Birim iskeleti"""
    door_number: str
    floor: Optional[str] = None
    dues_amount: NonNegativeInt = Field(0, description="Motor tarafından binadan miras alınacak aidat")
    rent_price: Optional[int] = Field(None, description="Kira bedeli (PRD §4.1.3)")

class PropertyUnitCreate(PropertyUnitBase):
    pass

class PropertyUnitUpdate(BaseModel):
    """Daire güncelleme için (PRD §4.1.3)"""
    door_number: Optional[str] = None
    floor: Optional[str] = None
    dues_amount: Optional[int] = None
    rent_price: Optional[int] = None
    status: Optional[str] = None  # PRD §6.B: 'vacant', 'rented', 'maintenance'
    commission_rate: Optional[float] = Field(None, description="Komisyon oranı % (PRD §4.1.3-A)")
    youtube_video_link: Optional[str] = Field(None, description="Liste dışı video linki (PRD §4.1.3-C)")
    media_links: Optional[List[Dict[str, str]]] = Field(None, description="Fotoğraf galerisi")
    features: Optional[Dict[str, Any]] = Field(None, description="Birime özel özellikler")

class PropertyUnitResponse(PropertyUnitBase):
    id: UUID4
    agency_id: UUID4
    property_id: UUID4
    status: str
    vacant_since: Optional[datetime] = None
    created_at: datetime
    commission_rate: Optional[float] = None
    youtube_video_link: Optional[str] = None
    media_links: Optional[List[Dict[str, Any]]] = None

    class Config:
        from_attributes = True

class PropertyCreate(BaseModel):
    """Emlakçının UI formundan doldurup göndereceği paket"""
    name: str = Field(..., description="Mülk Adı (Örn: Güneş Sitesi veya Hobi Bahçesi)")
    type: str = Field(..., description="'apartment_complex', 'standalone_house', 'land' veya 'commercial'")
    address: Optional[str] = None
    central_dues: NonNegativeInt = Field(0, description="Dairelere miras bırakılacak varsayılan aidat")
    features: Optional[Dict[str, Any]] = Field(default_factory=dict, description="Asansör, Havuz gibi JSON miras özellikleri")

    # Sistemin can damarı: Otonom Generative Parameters (Asimetrik Üretim)
    start_floor: Optional[int] = Field(None, description="Başlangıç katı (Örn: -2 Otopark katları dahil)")
    end_floor: Optional[int] = Field(None, description="Bitiş katı (Örn: 10)")
    units_per_floor: Optional[int] = Field(None, description="Her kattaki daire kapasitesi (Örn: 4)")

class PropertyResponse(BaseModel):
    """Ana bina listeleme yanıt DTO'su"""
    id: UUID4
    agency_id: UUID4
    name: str
    type: str
    address: Optional[str]
    total_units: int
    central_dues: int
    features: Optional[Dict[str, Any]]
    created_at: datetime
    
    class Config:
        from_attributes = True

class PropertyWithUnitsResponse(PropertyResponse):
    """Bina detayına girildiğinde üretilen yüzlerce birimin de listelendiği şişkin DTO"""
    units: List[PropertyUnitResponse] = []
