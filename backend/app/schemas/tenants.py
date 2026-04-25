from uuid import UUID
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import date, datetime
from enum import Enum
from app.models.operations import TicketPriority, TicketStatus


class TenantDocumentItem(BaseModel):
    """Kiracının tek bir belgesi — PRD §4.2.3"""
    name: str
    doc_type: str  # "contract" | "handover" | "aidat_plan" | "other"
    url: str
    uploaded_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class TenantDocumentsResponse(BaseModel):
    """Kiracının tüm belgeleri — PRD §4.2.3"""
    contract_document_url: Optional[str] = None
    documents: List[TenantDocumentItem] = []

    class Config:
        from_attributes = True


class ContractStatusEnum(str, Enum):
    active = "active"
    past = "past"


class TenantBase(BaseModel):
    """Kiracı temel şeması"""
    unit_id: UUID
    user_id: Optional[UUID] = None
    temp_name: Optional[str] = None
    temp_phone: Optional[str] = None
    rent_amount: int = Field(..., description="Kira bedeli")
    payment_day: int = Field(1, description="Ayın kaçıncı günü ödenecek")
    start_date: date
    end_date: date


class TenantCreate(TenantBase):
    """Yeni kiracı oluşturma (PRD §4.1.4)"""
    pass


class TenantCreateWithUser(BaseModel):
    """
    Kiracı + Firebase kullanıcısı birlikte oluşturma (PRD §4.1.4).
    Emlakçı formu doldurur → backend Firebase user + User + Tenant oluşturur.
    """
    unit_id: UUID
    name: str = Field(..., min_length=2, max_length=200, description="Kiracının adı soyadı")
    email: str = Field(..., description="Kiracının email adresi")
    phone: Optional[str] = Field(None, description="Kiracının telefon numarası")
    password: str = Field(..., min_length=8, description="Geçici şifre (kiracı ilk girişte değiştirecek)")
    rent_amount: int = Field(..., description="Kira bedeli")
    payment_day: int = Field(1, description="Ayın kaçıncı günü ödenecek")
    start_date: date
    end_date: date

    class Config:
        from_attributes = True


class TenantUpdate(BaseModel):
    """Kiracı güncelleme"""
    rent_amount: Optional[int] = None
    payment_day: Optional[int] = None
    end_date: Optional[date] = None
    contract_document_url: Optional[str] = None
    documents: Optional[list] = None


class TenantResponse(TenantBase):
    """Kiracı yanıt şeması"""
    id: UUID
    agency_id: UUID
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
    unit_ids: list[UUID] = Field(..., description="Ev sahibine bağlanacak birim ID'leri")
    temp_name: Optional[str] = None
    temp_phone: Optional[str] = None
    ownership_share: int = Field(100, description="Mülkiyet payı (%)")


class LandlordResponse(BaseModel):
    """Ev sahibi yanıt şeması"""
    id: UUID
    agency_id: UUID
    unit_id: UUID
    user_id: Optional[UUID] = None
    temp_name: Optional[str] = None
    temp_phone: Optional[str] = None
    ownership_share: int
    created_at: datetime

    class Config:
        from_attributes = True


class LandlordUpdate(BaseModel):
    """Ev sahibi güncelleme — PRD §4.1.4"""
    temp_name: Optional[str] = None
    temp_phone: Optional[str] = None
    ownership_share: Optional[int] = None


class LandlordWithDetailsResponse(LandlordResponse):
    """Ev sahibi + birim detayları ile birlikte"""
    unit_door_number: Optional[str] = None
    property_name: Optional[str] = None
    user_full_name: Optional[str] = None
    user_phone: Optional[str] = None


# ──────────────────────────────────────────────
# Tenant Support Ticket Schemas — PRD §4.2.2
# ──────────────────────────────────────────────

class TenantTicketMessageResponse(BaseModel):
    id: UUID
    sender_user_id: Optional[UUID]
    sender_name: Optional[str] = None
    message: str
    attachment_url: Optional[str] = None
    is_agent: bool = False
    created_at: datetime

    class Config:
        from_attributes = True


class TenantTicketCreate(BaseModel):
    """Kiracının yeni destek bileti açması için form — PRD §4.2.2-A"""
    title: str = Field(..., max_length=200, description="Sorunun başlığı")
    description: Optional[str] = Field(None, description="Detaylı açıklama")
    priority: TicketPriority = TicketPriority.medium
    attachment_url: Optional[str] = None


class TenantTicketResponse(BaseModel):
    """Kiracının kendi bileti — PRD §4.2.2"""
    id: UUID
    title: str
    description: Optional[str]
    priority: TicketPriority
    status: TicketStatus
    created_at: datetime
    updated_at: datetime
    unit_door: Optional[str] = None
    property_name: Optional[str] = None
    message_count: int = 0
    last_message: Optional[str] = None
    last_message_at: Optional[datetime] = None
    messages: List[TenantTicketMessageResponse] = []

    class Config:
        from_attributes = True
