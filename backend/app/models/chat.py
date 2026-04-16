from sqlalchemy import Column, String, ForeignKey, Text, Boolean, DateTime
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from .base import BaseModel

class ChatConversation(BaseModel):
    """Emlakçı ile kiracı/malik arasındaki birebir websocket sohbet bağlantıları."""
    __tablename__ = "chat_conversations"

    agency_id = Column(UUID(as_uuid=True), ForeignKey("agencies.id", ondelete="CASCADE"), nullable=False, index=True)
    agent_user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    client_user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    property_id = Column(UUID(as_uuid=True), ForeignKey("properties.id", ondelete="SET NULL"), nullable=True, index=True)
    last_message_at = Column(DateTime, nullable=True)  # PRD §6.F — Son mesaj zamanı
    is_archived = Column(Boolean, default=False, nullable=False)
    archived_at = Column(String, nullable=True)

    messages = relationship("ChatMessage", back_populates="conversation", lazy="selectin")

class ChatMessage(BaseModel):
    __tablename__ = "chat_messages"

    conversation_id = Column(UUID(as_uuid=True), ForeignKey("chat_conversations.id", ondelete="CASCADE"), nullable=False, index=True)
    sender_user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    content = Column(Text, nullable=True)  # PRD §6.F — content olarak yeniden adlandırıldı
    attachment_url = Column(String, nullable=True)  # PRD §6.F — attachment_url olarak yeniden adlandırıldı
    is_read = Column(Boolean, default=False, nullable=False, index=True)  # PRD §6.F — Okundu bilgisi
    is_deleted = Column(Boolean, default=False, nullable=False, index=True)
    deleted_at = Column(String, nullable=True)
    deleted_by = Column(UUID(as_uuid=True), nullable=True)
    is_edited = Column(Boolean, default=False, nullable=False)
    edited_at = Column(String, nullable=True)

    conversation = relationship("ChatConversation", back_populates="messages")
