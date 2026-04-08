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
