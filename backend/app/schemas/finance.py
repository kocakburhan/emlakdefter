from pydantic import BaseModel, UUID4, Field
from typing import Optional, List
from datetime import date
from enum import Enum

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
    property_id: Optional[UUID4] = None
    unit_id: Optional[UUID4] = None
    tenant_id: Optional[UUID4] = None
    
    type: TransactionTypeEnum
    category: TransactionCategoryEnum
    amount: float
    transaction_date: date
    description: Optional[str] = None

class TransactionResponse(BaseModel):
    id: UUID4
    agency_id: UUID4
    property_id: Optional[UUID4] = None
    unit_id: Optional[UUID4] = None
    tenant_id: Optional[UUID4] = None
    type: TransactionTypeEnum
    category: TransactionCategoryEnum
    amount: float
    currency: str
    transaction_date: date
    description: Optional[str] = None
    receipt_url: Optional[str] = None

    class Config:
        from_attributes = True

class TransactionListResponse(BaseModel):
    transactions: List[TransactionResponse]
    total_income: float
    total_expense: float
    net_balance: float
    count: int

class PaymentScheduleResponse(BaseModel):
    id: UUID4
    tenant_id: UUID4
    amount: float
    paid_amount: float
    due_date: date
    category: TransactionCategoryEnum
    status: str

    class Config:
        from_attributes = True
