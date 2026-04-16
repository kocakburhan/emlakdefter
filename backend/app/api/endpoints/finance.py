from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc, func, and_
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
    tx_type: Optional[str] = None,    # income / expense filtresi
    category: Optional[str] = None,   # rent / dues / commission / ...
    start_date: Optional[str] = None, # YYYY-MM-DD
    end_date: Optional[str] = None,    # YYYY-MM-DD
    limit: int = 200,
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
    if tx_type:
        query = query.where(FinancialTransaction.type == tx_type)
    if category:
        query = query.where(FinancialTransaction.category == category)

    # Tarih aralığı filtresi
    if start_date:
        try:
            start = date.fromisoformat(start_date)
            query = query.where(FinancialTransaction.transaction_date >= start)
        except ValueError:
            pass
    if end_date:
        try:
            end = date.fromisoformat(end_date)
            query = query.where(FinancialTransaction.transaction_date <= end)
        except ValueError:
            pass

    query = query.order_by(desc(FinancialTransaction.transaction_date)).offset(offset).limit(limit)

    result = await db.execute(query)
    transactions = result.scalars().all()

    # Toplam gelir/gider hesapla (filtrelenmiş)
    total_q = (
        select(FinancialTransaction)
        .where(
            FinancialTransaction.agency_id == agency_id,
            FinancialTransaction.is_deleted == False,
        )
    )
    if tx_type:
        total_q = total_q.where(FinancialTransaction.type == tx_type)
    if category:
        total_q = total_q.where(FinancialTransaction.category == category)
    if start_date:
        try:
            total_q = total_q.where(FinancialTransaction.transaction_date >= date.fromisoformat(start_date))
        except ValueError:
            pass
    if end_date:
        try:
            total_q = total_q.where(FinancialTransaction.transaction_date <= date.fromisoformat(end_date))
        except ValueError:
            pass

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


@router.get("/monthly-stats")
async def get_monthly_stats(
    year: Optional[int] = None,  # Hangi yıl (varsayılan: bu yıl)
    current_user: User = Depends(deps.get_current_user),
    agency_id: uuid.UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(deps.get_db),
):
    """Aylık gelir/gider istatistikleri — bar chart için."""
    if year is None:
        year = date.today().year

    from datetime import datetime
    start_of_year = date(year, 1, 1)
    end_of_year = date(year, 12, 31)

    # Aylık gruplama sorgusu
    monthly_data = []
    for month in range(1, 13):
        month_start = date(year, month, 1)
        if month == 12:
            month_end = date(year + 1, 1, 1)
        else:
            month_end = date(year, month + 1, 1)

        # Gelir
        income_q = select(func.sum(FinancialTransaction.amount)).where(
            and_(
                FinancialTransaction.agency_id == agency_id,
                FinancialTransaction.is_deleted == False,
                FinancialTransaction.type == TransactionType.income,
                FinancialTransaction.transaction_date >= month_start,
                FinancialTransaction.transaction_date < month_end,
            )
        )
        income_result = await db.execute(income_q)
        income = income_result.scalar() or 0

        # Gider
        expense_q = select(func.sum(FinancialTransaction.amount)).where(
            and_(
                FinancialTransaction.agency_id == agency_id,
                FinancialTransaction.is_deleted == False,
                FinancialTransaction.type == TransactionType.expense,
                FinancialTransaction.transaction_date >= month_start,
                FinancialTransaction.transaction_date < month_end,
            )
        )
        expense_result = await db.execute(expense_q)
        expense = expense_result.scalar() or 0

        monthly_data.append({
            "month": month,
            "month_name": _MONTH_NAMES[month - 1],
            "income": income,
            "expense": expense,
        })

    return {
        "year": year,
        "months": monthly_data,
    }


_MONTH_NAMES = [
    "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran",
    "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"
]


@router.get("/category-breakdown")
async def get_category_breakdown(
    tx_type: Optional[str] = None,  # income / expense
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    current_user: User = Depends(deps.get_current_user),
    agency_id: uuid.UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(deps.get_db),
):
    """Kategori bazlı gelir/gider dağılımı — pie chart için."""
    query = (
        select(
            FinancialTransaction.category,
            func.sum(FinancialTransaction.amount).label("total"),
            func.count(FinancialTransaction.id).label("count"),
        )
        .where(
            FinancialTransaction.agency_id == agency_id,
            FinancialTransaction.is_deleted == False,
        )
        .group_by(FinancialTransaction.category)
    )

    if tx_type:
        query = query.where(FinancialTransaction.type == tx_type)
    if start_date:
        try:
            query = query.where(FinancialTransaction.transaction_date >= date.fromisoformat(start_date))
        except ValueError:
            pass
    if end_date:
        try:
            query = query.where(FinancialTransaction.transaction_date <= date.fromisoformat(end_date))
        except ValueError:
            pass

    result = await db.execute(query)
    rows = result.all()

    # Enum'i stringe çevir
    breakdown = []
    for row in rows:
        cat_value = row.category.value if hasattr(row.category, 'value') else str(row.category)
        breakdown.append({
            "category": cat_value,
            "total": row.total,
            "count": row.count,
        })

    # Toplam hesapla
    grand_total = sum(b["total"] for b in breakdown)

    return {
        "type": tx_type,
        "breakdown": breakdown,
        "grand_total": grand_total,
    }


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
