from pydantic import BaseModel, UUID4, Field
from typing import Optional
from datetime import date, datetime
from enum import Enum


class ContractStatusEnum(str, Enum):
    active = "active"
    past = "past"


class TenantBase(BaseModel):
    """Kiracı temel şeması"""
    unit_id: UUID4
    user_id: Optional[UUID4] = None
    temp_name: Optional[str] = None
    temp_phone: Optional[str] = None
    rent_amount: int = Field(..., description="Kira bedeli")
    payment_day: int = Field(1, description="Ayın kaçıncı günü ödenecek")
    start_date: date
    end_date: date


class TenantCreate(TenantBase):
    """Yeni kiracı oluşturma (PRD §4.1.4)"""
    pass


class TenantUpdate(BaseModel):
    """Kiracı güncelleme"""
    rent_amount: Optional[int] = None
    payment_day: Optional[int] = None
    end_date: Optional[date] = None


class TenantResponse(TenantBase):
    """Kiracı yanıt şeması"""
    id: UUID4
    agency_id: UUID4
    status: str
    actual_end_date: Optional[date] = None
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True


class TenantWithDetailsResponse(TenantResponse):
    """Kiracı + birim detayları ile birlikte"""
    unit_door_number: Optional[str] = None
    unit_floor: Optional[str] = None
    property_name: Optional[str] = None
    user_full_name: Optional[str] = None
    user_phone: Optional[str] = None


class LandlordBase(BaseModel):
    """Ev sahibi temel şeması"""
    pass


class LandlordCreate(BaseModel):
    """Yeni ev sahibi oluşturma (PRD §4.1.4)"""
    unit_ids: list[UUID4] = Field(..., description="Ev sahibine bağlanacak birim ID'leri")
    temp_name: Optional[str] = None
    temp_phone: Optional[str] = None
    ownership_share: int = Field(100, description="Mülkiyet payı (%)")


class LandlordResponse(BaseModel):
    """Ev sahibi yanıt şeması"""
    id: UUID4
    agency_id: UUID4
    unit_id: UUID4
    user_id: Optional[UUID4] = None
    temp_name: Optional[str] = None
    temp_phone: Optional[str] = None
    ownership_share: int
    created_at: datetime

    class Config:
        from_attributes = True


class LandlordWithDetailsResponse(LandlordResponse):
    """Ev sahibi + birim detayları ile birlikte"""
    unit_door_number: Optional[str] = None
    property_name: Optional[str] = None
    user_full_name: Optional[str] = None
    user_phone: Optional[str] = None
