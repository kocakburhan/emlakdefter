from pydantic import BaseModel, UUID4, Field
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
    id: UUID4
    sender_user_id: Optional[UUID4]
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
    unit_id: UUID4

class TicketResponse(TicketBase):
    """Emlakçının bilet detayı veya listesi (Yanıt paketi)"""
    id: UUID4
    agency_id: UUID4
    unit_id: UUID4
    reporter_user_id: Optional[UUID4]
    status: TicketStatus
    created_at: datetime
    messages: List[TicketMessageResponse] = []
    
    class Config:
        from_attributes = True

class BuildingLogCreate(BaseModel):
    """Emlakçının Şeffaflık Modülü faturası veya notu"""
    property_id: UUID4
    title: str = Field(..., description="Bakım/Onarım türü veya şeffaflık faturası ismi.")
    description: Optional[str] = None
    cost: int = Field(0, description="Dökülen Masraf (Kuruş/Lira format)")
    invoice_url: Optional[str] = None
    is_reflected_to_finance: bool = False

class BuildingLogResponse(BuildingLogCreate):
    id: UUID4
    agency_id: UUID4
    created_by_user_id: Optional[UUID4]
    created_at: datetime
    
    class Config:
        from_attributes = True
