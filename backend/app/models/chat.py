from sqlalchemy import Column, String, ForeignKey, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from .base import BaseModel

class ChatConversation(BaseModel):
    """Emlakçı ile kiracı/malik arasındaki birebir websocket sohbet bağlantıları."""
    __tablename__ = "chat_conversations"
    
    agency_id = Column(UUID(as_uuid=True), ForeignKey("agencies.id", ondelete="CASCADE"), nullable=False, index=True)
    agent_user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    client_user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    
    messages = relationship("ChatMessage", back_populates="conversation")

class ChatMessage(BaseModel):
    __tablename__ = "chat_messages"
    
    conversation_id = Column(UUID(as_uuid=True), ForeignKey("chat_conversations.id", ondelete="CASCADE"), nullable=False, index=True)
    sender_user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    message = Column(Text, nullable=True)
    media_url = Column(String, nullable=True) # Fotoğraf veya Belge paylaşımı
    
    conversation = relationship("ChatConversation", back_populates="messages")
