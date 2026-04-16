from pydantic import BaseModel, UUID4, Field
from typing import Optional, List
from datetime import date
from enum import Enum
from uuid import UUID

class TransactionTypeEnum(str, Enum):
    income = "income"
    expense = "expense"

class TransactionCategoryEnum(str, Enum):
    rent = "rent"
    dues = "dues"
    utility = "utility"
    maintenance = "maintenance"
    commission = "commission"
    other = "other"

class ExtractedTransaction(BaseModel):
    """(DTO) - Yapay Zeka JSON'undan dönen saf, güvencesiz veri"""
    sender_name: str
    date: str
    amount: float
    description: Optional[str] = None

class ParsedStatementResponse(BaseModel):
    """(DTO) - Emlakçının UI / Dashboard üzerinde (PDF bittiğinde) göreceği Rapor Paketi"""
    success: bool
    total_found: int
    matched_results: List[dict] # Kim eşleşti, kim kaçak vb.

class ManualTransactionCreate(BaseModel):
    """Emlakçının AI kullanmadan Eliyle faturayı sisteme girmek istemesi halinde kullanılacak paket"""
    property_id: Optional[UUID] = None
    unit_id: Optional[UUID] = None
    tenant_id: Optional[UUID] = None

    type: TransactionTypeEnum
    category: TransactionCategoryEnum
    amount: float
    transaction_date: date
    description: Optional[str] = None
    custom_category: Optional[str] = None

class TransactionResponse(BaseModel):
    id: UUID
    agency_id: UUID
    property_id: Optional[UUID] = None
    unit_id: Optional[UUID] = None
    tenant_id: Optional[UUID] = None
    type: TransactionTypeEnum
    category: TransactionCategoryEnum
    amount: float
    currency: str
    transaction_date: date
    description: Optional[str] = None
    custom_category: Optional[str] = None
    receipt_url: Optional[str] = None
    status: str = "completed"  # PRD §6.D: completed, pending_approval, partial
    ai_matched: bool = False  # PRD §6.D: Yapay zeka/PDF okuma işleminden mi geldi?

    class Config:
        from_attributes = True

class TransactionListResponse(BaseModel):
    transactions: List[TransactionResponse]
    total_income: float
    total_expense: float
    net_balance: float
    count: int

class PaymentScheduleResponse(BaseModel):
    id: UUID
    tenant_id: UUID
    amount: float
    paid_amount: float
    due_date: date
    category: TransactionCategoryEnum
    status: str
    transaction_id: Optional[UUID] = None  # PRD §6.D: Ödeme yapıldıysa financial_transactions referansı

    class Config:
        from_attributes = True


class TenantFinanceSummary(BaseModel):
    """Kiracının kendi finans özeti — borcu, son ödeme, yaklaşan takvim"""
    tenant_id: UUID
    current_debt: float
    next_due_date: Optional[date] = None
    next_due_amount: Optional[float] = None
    upcoming_schedules: List[PaymentScheduleResponse] = []
    recent_transactions: List[TransactionResponse] = []

    class Config:
        from_attributes = True
