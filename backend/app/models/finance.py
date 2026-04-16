import enum
from sqlalchemy import Column, Integer, Date, ForeignKey, String, Enum, Boolean, Float
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from .base import BaseModel

class TransactionType(str, enum.Enum):
    income = "income"
    expense = "expense"

class TransactionCategory(str, enum.Enum):
    rent = "rent"
    dues = "dues"
    utility = "utility"
    maintenance = "maintenance"
    commission = "commission"
    other = "other"

class TransactionStatus(str, enum.Enum):
    """İşlem onay durumu — PRD §6.D"""
    completed = "completed"
    pending_approval = "pending_approval"
    partial = "partial"

class FinancialTransaction(BaseModel):
    """Acentenin genel kasa ve işlem tablosu (Gelir/Gider)"""
    __tablename__ = "financial_transactions"

    agency_id = Column(UUID(as_uuid=True), ForeignKey("agencies.id", ondelete="CASCADE"), nullable=False, index=True)
    property_id = Column(UUID(as_uuid=True), ForeignKey("properties.id", ondelete="SET NULL"), nullable=True, index=True)
    unit_id = Column(UUID(as_uuid=True), ForeignKey("property_units.id", ondelete="SET NULL"), nullable=True, index=True)
    tenant_id = Column(UUID(as_uuid=True), ForeignKey("tenants.id", ondelete="SET NULL"), nullable=True, index=True)

    type = Column(Enum(TransactionType), nullable=False)
    category = Column(Enum(TransactionCategory), nullable=False)
    amount = Column(Integer, nullable=False)
    currency = Column(String, default="TRY")
    transaction_date = Column(Date, nullable=False)
    description = Column(String, nullable=True)
    custom_category = Column(String, nullable=True)  # Kullanıcı özel kategori adı
    receipt_url = Column(String, nullable=True)
    status = Column(Enum(TransactionStatus), default=TransactionStatus.completed, nullable=False)  # PRD §6.D
    ai_matched = Column(Boolean, default=False, nullable=False)  # Yapay zeka/PDF okuma işleminden mi geldi?
    ai_confidence = Column(Float, nullable=True)  # AI eşleşme güven skoru (0.0 - 100.0)

    property = relationship("Property")
    unit = relationship("PropertyUnit")
    tenant = relationship("Tenant")

class PaymentStatus(str, enum.Enum):
    pending = "pending"
    partial = "partial"
    completed = "completed"

class PaymentSchedule(BaseModel):
    """Otonom tahsilat motorunun (Gemini ve APScheduler) üzerine çalışacağı Ana Varlık tablosu."""
    __tablename__ = "payment_schedules"

    agency_id = Column(UUID(as_uuid=True), ForeignKey("agencies.id", ondelete="CASCADE"), nullable=False, index=True)
    tenant_id = Column(UUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True)

    amount = Column(Integer, nullable=False)
    paid_amount = Column(Integer, default=0)
    due_date = Column(Date, nullable=False)
    category = Column(Enum(TransactionCategory), nullable=False) # rent veya dues
    status = Column(Enum(PaymentStatus), default=PaymentStatus.pending, nullable=False)
    transaction_id = Column(UUID(as_uuid=True), ForeignKey("financial_transactions.id", ondelete="SET NULL"), nullable=True)  # PRD §6.D — Ödeme yapıldıysa referans

    tenant = relationship("Tenant")
