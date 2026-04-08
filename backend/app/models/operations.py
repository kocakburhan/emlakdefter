import enum
from sqlalchemy import Column, String, ForeignKey, Enum, Text, Integer, Boolean
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from .base import BaseModel

class TicketPriority(str, enum.Enum):
    low = "low"
    medium = "medium"
    high = "high"
    urgent = "urgent"

class TicketStatus(str, enum.Enum):
    open = "open"
    in_progress = "in_progress"
    resolved = "resolved"
    closed = "closed"

class SupportTicket(BaseModel):
    """Kiracı arıza ve şikayet bildirimleri."""
    __tablename__ = "support_tickets"
    
    agency_id = Column(UUID(as_uuid=True), ForeignKey("agencies.id", ondelete="CASCADE"), nullable=False, index=True)
    unit_id = Column(UUID(as_uuid=True), ForeignKey("property_units.id", ondelete="CASCADE"), nullable=False, index=True)
    reporter_user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    
    title = Column(String, nullable=False)
    description = Column(Text, nullable=True)
    priority = Column(Enum(TicketPriority), default=TicketPriority.medium)
    status = Column(Enum(TicketStatus), default=TicketStatus.open)
    attachment_url = Column(String, nullable=True)
    
    messages = relationship("TicketMessage", back_populates="ticket")

class TicketMessage(BaseModel):
    __tablename__ = "ticket_messages"
    
    ticket_id = Column(UUID(as_uuid=True), ForeignKey("support_tickets.id", ondelete="CASCADE"), nullable=False, index=True)
    sender_user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    message = Column(Text, nullable=False)
    attachment_url = Column(String, nullable=True)
    
    ticket = relationship("SupportTicket", back_populates="messages")

class BuildingOperationLog(BaseModel):
    """Bina geneli bakım onarım kayıtları (Şeffaflık Modülü)"""
    __tablename__ = "building_operations_log"
    
    agency_id = Column(UUID(as_uuid=True), ForeignKey("agencies.id", ondelete="CASCADE"), nullable=False, index=True)
    property_id = Column(UUID(as_uuid=True), ForeignKey("properties.id", ondelete="CASCADE"), nullable=False, index=True)
    created_by_user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    
    title = Column(String, nullable=False)
    description = Column(Text, nullable=True)
    cost = Column(Integer, default=0)
    invoice_url = Column(String, nullable=True)
    is_reflected_to_finance = Column(Boolean, default=False)
