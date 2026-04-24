from uuid import UUID
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
from enum import Enum
from app.models.operations import TicketPriority, TicketStatus

class TicketMessageBase(BaseModel):
    message: str
    attachment_url: Optional[str] = None

class TicketMessageCreate(TicketMessageBase):
    pass

class TicketMessageResponse(TicketMessageBase):
    id: UUID
    sender_user_id: Optional[UUID]
    created_at: datetime
    
    class Config:
        from_attributes = True

class TicketBase(BaseModel):
    title: str = Field(..., description="Müşterinin belirttiği arıza veya konunun ufak özeti")
    description: Optional[str] = None
    priority: TicketPriority = TicketPriority.medium
    attachment_url: Optional[str] = None

class TicketCreate(TicketBase):
    """Kiracının yeni bilet açarken vereceği form"""
    unit_id: UUID

class TicketResponse(TicketBase):
    """Emlakçının bilet detayı veya listesi (Yanıt paketi)"""
    id: UUID
    agency_id: UUID
    unit_id: UUID
    reporter_user_id: Optional[UUID]
    tenant_phone: Optional[str] = None  # Kiracı telefonu — WhatsApp entegrasyonu için
    status: TicketStatus
    created_at: datetime
    messages: List[TicketMessageResponse] = []

    class Config:
        from_attributes = True


class TicketListResponse(BaseModel):
    """Bilet listesi için özet yanıt"""
    id: UUID
    title: str
    priority: TicketPriority
    status: TicketStatus
    created_at: datetime
    unit_door: Optional[str] = None
    unit_property: Optional[str] = None
    reporter_name: Optional[str] = None
    message_count: int = 0
    last_message: Optional[str] = None

    class Config:
        from_attributes = True


class TicketStatusUpdate(BaseModel):
    status: str

class BuildingLogCreate(BaseModel):
    """Emlakçının Şeffaflık Modülü faturası veya notu"""
    property_id: UUID
    title: str = Field(..., description="Bakım/Onarım türü veya şeffaflık faturası ismi.")
    description: Optional[str] = None
    cost: int = Field(0, description="Dökülen Masraf (Kuruş/Lira format)")
    invoice_url: Optional[str] = None
    is_reflected_to_finance: bool = False
    category: Optional[str] = None  # PRD §4.1.9 — OperationCategory

class BuildingLogUpdate(BaseModel):
    """Maliyeti finansa yansıt veya not güncelle"""
    title: Optional[str] = None
    description: Optional[str] = None
    cost: Optional[int] = None
    invoice_url: Optional[str] = None
    is_reflected_to_finance: Optional[bool] = None

class BuildingLogResponse(BuildingLogCreate):
    id: UUID
    agency_id: UUID
    created_by_user_id: Optional[UUID]
    created_at: datetime

    class Config:
        from_attributes = True
