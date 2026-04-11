from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc
from typing import List, Optional
from datetime import date
import uuid

from app.api import deps
from app.models.users import User
from app.models.finance import FinancialTransaction, PaymentSchedule, TransactionType, TransactionCategory, PaymentStatus
from app.schemas.finance import (
    ParsedStatementResponse,
    ManualTransactionCreate,
    TransactionResponse,
    TransactionListResponse,
    PaymentScheduleResponse,
)
from app.services.finance_service import process_and_match_statement

router = APIRouter()


# ──────────────────────────────────────────────
# 1. FİNANSAL İŞLEMLER (GELİR/GİDER HAVUZU)
# ──────────────────────────────────────────────

@router.get("/transactions", response_model=TransactionListResponse)
async def list_transactions(
    type: Optional[str] = None,       # income / expense filtresi
    category: Optional[str] = None,   # rent / dues / commission / ...
    limit: int = 50,
    offset: int = 0,
    current_user: User = Depends(deps.get_current_user),
    agency_id: uuid.UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(deps.get_db),
):
    """Ofisin tüm gelir/gider işlemlerini listeler (Mali Rapor Merkezi)."""
    query = (
        select(FinancialTransaction)
        .where(
            FinancialTransaction.agency_id == agency_id,
            FinancialTransaction.is_deleted == False,
        )
    )
    
    # Opsiyonel filtreler
    if type:
        query = query.where(FinancialTransaction.type == type)
    if category:
        query = query.where(FinancialTransaction.category == category)
    
    query = query.order_by(desc(FinancialTransaction.transaction_date)).offset(offset).limit(limit)
    
    result = await db.execute(query)
    transactions = result.scalars().all()
    
    # Toplam gelir/gider hesapla
    total_q = select(FinancialTransaction).where(
        FinancialTransaction.agency_id == agency_id,
        FinancialTransaction.is_deleted == False,
    )
    total_result = await db.execute(total_q)
    all_txs = total_result.scalars().all()
    
    total_income = sum(t.amount for t in all_txs if t.type == TransactionType.income)
    total_expense = sum(t.amount for t in all_txs if t.type == TransactionType.expense)
    
    return TransactionListResponse(
        transactions=[TransactionResponse.from_orm(t) for t in transactions],
        total_income=total_income,
        total_expense=total_expense,
        net_balance=total_income - total_expense,
        count=len(transactions),
    )


@router.post("/transactions", response_model=TransactionResponse, status_code=201)
async def create_transaction(
    data: ManualTransactionCreate,
    current_user: User = Depends(deps.get_current_user),
    agency_id: uuid.UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(deps.get_db),
):
    """Manuel gelir/gider kaydı ekler (PRD 4.1.6-B)."""
    new_tx = FinancialTransaction(
        agency_id=agency_id,
        property_id=data.property_id,
        unit_id=data.unit_id,
        tenant_id=data.tenant_id,
        type=data.type,
        category=data.category,
        amount=data.amount,
        currency="TRY",
        transaction_date=data.transaction_date,
        description=data.description,
    )
    db.add(new_tx)
    await db.commit()
    await db.refresh(new_tx)
    return TransactionResponse.from_orm(new_tx)


# ──────────────────────────────────────────────
# 2. ÖDEME TAKVİMİ (KİRACI BORÇLARI)
# ──────────────────────────────────────────────

@router.get("/payment-schedules", response_model=List[PaymentScheduleResponse])
async def list_payment_schedules(
    status_filter: Optional[str] = None,  # pending / completed / partial
    current_user: User = Depends(deps.get_current_user),
    agency_id: uuid.UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(deps.get_db),
):
    """Kiracıların ödeme takvimini listeler (Bekleyenler/Ödeyenler/Gecikenler)."""
    query = (
        select(PaymentSchedule)
        .where(
            PaymentSchedule.agency_id == agency_id,
            PaymentSchedule.is_deleted == False,
        )
    )
    
    if status_filter:
        query = query.where(PaymentSchedule.status == status_filter)
    
    query = query.order_by(desc(PaymentSchedule.due_date))
    
    result = await db.execute(query)
    schedules = result.scalars().all()
    return [PaymentScheduleResponse.from_orm(s) for s in schedules]


# ──────────────────────────────────────────────
# 3. PDF DEKONT YÜKLEME (AI TAHSİLAT)
# ──────────────────────────────────────────────

@router.post("/upload-statement", response_model=ParsedStatementResponse)
async def upload_bank_statement(
    file: UploadFile = File(...),
    current_user: User = Depends(deps.get_current_user),
    agency_id: uuid.UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(deps.get_db),
):
    """
    Sistemin Kalbi: Emlakçının Banka Dekontunu (PDF) yüklediği endpoint.
    pdfplumber → gemini-2.5-flash → Difflib eşleştirme → Otomatik borç kapama.
    """
    if file.content_type != "application/pdf":
        raise HTTPException(
            status_code=400,
            detail="Emlakdefter YZ Motoru şu an için sadece PDF (.pdf) formatındaki ekstremeleri çözebilmektedir."
        )
    
    file_bytes = await file.read()
    
    try:
        response_tree = await process_and_match_statement(db, str(agency_id), file_bytes)
        return response_tree
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"LLM Motorunda veya Veritabanı Tahsilat Eşitlemesinde Kritik Hata: {str(e)}"
        )
