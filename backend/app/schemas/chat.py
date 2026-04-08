from pydantic import BaseModel, UUID4
from typing import Optional, List
from datetime import datetime

class ChatMessageBase(BaseModel):
    """WebSocket aracılığıyla UI'dan veya REST üzerinden gelecek ham JSON paketi"""
    message: Optional[str] = None
    media_url: Optional[str] = None

class ChatMessageResponse(ChatMessageBase):
    """Veritabanından çıkartılıp odaya veya offline tarihe yansıtılacak olan mesaj"""
    id: UUID4
    conversation_id: UUID4
    sender_user_id: UUID4
    created_at: datetime
    
    class Config:
        from_attributes = True

class ChatConversationResponse(BaseModel):
    """WhatsApp listesinde (Sohbetlerim) görünecek olan odaların kapak fotoğrafları / başlıkları"""
    id: UUID4
    agency_id: UUID4
    agent_user_id: UUID4
    client_user_id: UUID4
    created_at: datetime
    messages: List[ChatMessageResponse] = []
    
    class Config:
        from_attributes = True
