from pydantic import BaseModel, UUID4
from typing import Optional, List
from datetime import datetime

class ChatMessageBase(BaseModel):
    """WebSocket aracılığıyla UI'dan veya REST üzerinden gelecek ham JSON paketi"""
    content: Optional[str] = None  # PRD §6.F — attachment_url yerine content
    attachment_url: Optional[str] = None  # PRD §6.F

class MessageEditRequest(BaseModel):
    """Mesaj düzenleme isteği"""
    content: str

class MessageCreate(BaseModel):
    """Mesaj gönderme isteği"""
    type: str = "message"
    conversation_id: UUID4
    content: Optional[str] = None
    attachment_url: Optional[str] = None

class ChatMessageResponse(ChatMessageBase):
    """Veritabanından çıkartılıp odaya veya offline tarihe yansıtılacak olan mesaj"""
    id: UUID4
    conversation_id: UUID4
    sender_user_id: UUID4
    is_read: bool = False  # PRD §6.F
    created_at: datetime
    is_deleted: bool = False
    deleted_at: Optional[str] = None
    is_edited: bool = False
    edited_at: Optional[str] = None

    class Config:
        from_attributes = True

class ConversationCreate(BaseModel):
    """Yeni sohbet başlatma isteği"""
    client_user_id: UUID4
    property_id: Optional[UUID4] = None

class ChatConversationResponse(BaseModel):
    """WhatsApp listesinde (Sohbetlerim) görünecek olan odaların kapak fotoğrafları / başlıkları"""
    id: UUID4
    agency_id: UUID4
    agent_user_id: UUID4
    client_user_id: UUID4
    property_id: Optional[UUID4] = None
    client_name: Optional[str] = None
    client_role: Optional[str] = None
    property_name: Optional[str] = None
    last_message: Optional[str] = None
    last_message_at: Optional[datetime] = None
    unread_count: int = 0
    is_archived: bool = False
    created_at: datetime

    class Config:
        from_attributes = True
