from sqlalchemy import Column, String, ForeignKey, Text, Boolean
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from datetime import datetime
from .base import BaseModel

class ChatConversation(BaseModel):
    """Emlakçı ile kiracı/malik arasındaki birebir websocket sohbet bağlantıları."""
    __tablename__ = "chat_conversations"

    agency_id = Column(UUID(as_uuid=True), ForeignKey("agencies.id", ondelete="CASCADE"), nullable=False, index=True)
    agent_user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    client_user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    is_archived = Column(Boolean, default=False, nullable=False)
    archived_at = Column(String, nullable=True)

    messages = relationship("ChatMessage", back_populates="conversation", lazy="selectin")

class ChatMessage(BaseModel):
    __tablename__ = "chat_messages"

    conversation_id = Column(UUID(as_uuid=True), ForeignKey("chat_conversations.id", ondelete="CASCADE"), nullable=False, index=True)
    sender_user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    message = Column(Text, nullable=True)
    media_url = Column(String, nullable=True)
    is_deleted = Column(Boolean, default=False, nullable=False, index=True)
    deleted_at = Column(String, nullable=True)
    deleted_by = Column(UUID(as_uuid=True), nullable=True)
    is_edited = Column(Boolean, default=False, nullable=False)
    edited_at = Column(String, nullable=True)

    conversation = relationship("ChatConversation", back_populates="messages")
