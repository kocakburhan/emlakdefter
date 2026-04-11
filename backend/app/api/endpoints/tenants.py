from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from typing import List
from uuid import UUID
from datetime import datetime

from app.api import deps
from app.database import get_db
from app.models.users import User
from app.models.properties import Property, PropertyUnit
from app.models.tenants import Tenant, LandlordUnit
from app.models.finance import PaymentSchedule, FinancialTransaction
from app.schemas.tenants import (
    TenantCreate, TenantUpdate, TenantResponse, TenantWithDetailsResponse,
    LandlordCreate, LandlordResponse, LandlordWithDetailsResponse
)
from app.schemas.finance import TenantFinanceSummary, PaymentScheduleResponse, TransactionResponse
from sqlalchemy import desc

router = APIRouter()


# ==================== TENANT ENDPOINTS ====================

@router.get("/me/transactions", response_model=List[TransactionResponse])
async def get_current_tenant_transactions(
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Oturum açmış kiracının kendi işlem geçmişini listeler.
    """
    tenant_stmt = select(Tenant).where(
        Tenant.user_id == current_user.id, Tenant.is_active == True
    )
    tenant_result = await db.execute(tenant_stmt)
    tenant = tenant_result.scalar_one_or_none()

    if not tenant:
        raise HTTPException(status_code=404, detail="Aktif kiracı kaydınız bulunamadı.")

    stmt = select(FinancialTransaction).where(
        FinancialTransaction.tenant_id == tenant.id
    ).order_by(desc(FinancialTransaction.transaction_date))
    result = await db.execute(stmt)
    transactions = result.scalars().all()

    return [
        TransactionResponse(
            id=t.id, agency_id=t.agency_id, property_id=t.property_id,
            unit_id=t.unit_id, tenant_id=t.tenant_id,
            type=t.type, category=t.category, amount=float(t.amount),
            currency=t.currency, transaction_date=t.transaction_date,
            description=t.description, receipt_url=t.receipt_url
        ) for t in transactions
    ]


@router.get("/me/building-logs", response_model=list)
async def get_current_tenant_building_logs(
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(get_db),
    limit: int = 20
):
    """
    Kiracının şeffaflık panosu — kendi sitesindeki bina operasyonlarını görür (PRD §4.2.4).
    """
    # Kiracının hangi mülkte oturduğunu bul
    tenant_stmt = select(Tenant).where(
        Tenant.user_id == current_user.id, Tenant.is_active == True
    ).options(selectinload(Tenant.unit))
    tenant_result = await db.execute(tenant_stmt)
    tenant = tenant_result.scalar_one_or_none()

    if not tenant or not tenant.unit:
        raise HTTPException(status_code=404, detail="Kiralama bilginiz bulunamadı.")

    property_id = tenant.unit.property_id

    # O mülkün tüm operasyon loglarını getir
    from app.models.operations import BuildingOperationLog
    stmt = select(BuildingOperationLog).where(
        BuildingOperationLog.agency_id == agency_id,
        BuildingOperationLog.property_id == property_id,
        BuildingOperationLog.is_deleted == False
    ).order_by(desc(BuildingOperationLog.created_at)).limit(limit)
    result = await db.execute(stmt)
    logs = result.scalars().all()

    from app.schemas.operations import BuildingLogResponse
    return [BuildingLogResponse.model_validate(log) for log in logs]


@router.get("/me", response_model=TenantWithDetailsResponse)
async def get_current_tenant(
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Oturum açmış kiracının kendi bilgilerini döner (PRD §4.2).
    Tenant role ile giriş yapan kullanıcı bu endpoint üzerinden kendi dairesini görür.
    """
    stmt = (
        select(Tenant)
        .where(Tenant.user_id == current_user.id, Tenant.is_active == True)
        .options(selectinload(Tenant.unit).selectinload(PropertyUnit.property))
    )
    result = await db.execute(stmt)
    tenant = result.scalar_one_or_none()

    if not tenant:
        raise HTTPException(status_code=404, detail="Aktif kiracı kaydınız bulunamadı.")

    unit = tenant.unit
    property_ = unit.property if unit else None
    return TenantWithDetailsResponse(
        id=tenant.id,
        agency_id=tenant.agency_id,
        unit_id=tenant.unit_id,
        user_id=tenant.user_id,
        temp_name=tenant.temp_name,
        temp_phone=tenant.temp_phone,
        rent_amount=tenant.rent_amount,
        payment_day=tenant.payment_day,
        start_date=tenant.start_date,
        end_date=tenant.end_date,
        status=tenant.status.value if hasattr(tenant.status, 'value') else tenant.status,
        actual_end_date=tenant.actual_end_date,
        is_active=tenant.is_active,
        created_at=tenant.created_at,
        unit_door_number=unit.door_number if unit else None,
        unit_floor=unit.floor if unit else None,
        property_name=property_.name if property_ else None,
        user_full_name=current_user.full_name,
        user_phone=current_user.phone_number
    )


@router.get("/me/finance", response_model=TenantFinanceSummary)
async def get_current_tenant_finance(
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Oturum açmış kiracının kendi finans özetini döner.
    Borç, son ödeme tarihi, yaklaşan takvim, son işlemler.
    """
    # Aktif kiracıyı bul
    tenant_stmt = (
        select(Tenant)
        .where(Tenant.user_id == current_user.id, Tenant.is_active == True)
    )
    tenant_result = await db.execute(tenant_stmt)
    tenant = tenant_result.scalar_one_or_none()

    if not tenant:
        raise HTTPException(status_code=404, detail="Aktif kiracı kaydınız bulunamadı.")

    # Borç hesapla (pending/partial ödemeler)
    debt_stmt = select(PaymentSchedule).where(
        PaymentSchedule.tenant_id == tenant.id,
        PaymentSchedule.status.in_(["pending", "partial"])
    )
    debt_result = await db.execute(debt_stmt)
    schedules = debt_result.scalars().all()
    current_debt = sum(s.amount - s.paid_amount for s in schedules)

    # Yaklaşan ödeme takvimi (gelecek 30 gün)
    from datetime import date, timedelta
    upcoming_stmt = select(PaymentSchedule).where(
        PaymentSchedule.tenant_id == tenant.id,
        PaymentSchedule.due_date >= date.today(),
        PaymentSchedule.due_date <= date.today() + timedelta(days=30),
        PaymentSchedule.status.in_(["pending", "partial"])
    ).order_by(PaymentSchedule.due_date)
    upcoming_result = await db.execute(upcoming_stmt)
    upcoming = upcoming_result.scalars().all()
    next_due = upcoming[0] if upcoming else None

    # Son işlemler (son 5)
    tx_stmt = select(FinancialTransaction).where(
        FinancialTransaction.tenant_id == tenant.id
    ).order_by(desc(FinancialTransaction.transaction_date)).limit(5)
    tx_result = await db.execute(tx_stmt)
    transactions = tx_result.scalars().all()

    return TenantFinanceSummary(
        tenant_id=tenant.id,
        current_debt=max(current_debt, 0),
        next_due_date=next_due.due_date if next_due else None,
        next_due_amount=next_due.amount - next_due.paid_amount if next_due else None,
        upcoming_schedules=[
            PaymentScheduleResponse(
                id=s.id,
                tenant_id=s.tenant_id,
                amount=float(s.amount),
                paid_amount=float(s.paid_amount),
                due_date=s.due_date,
                category=s.category,
                status=s.status.value if hasattr(s.status, 'value') else s.status
            ) for s in upcoming
        ],
        recent_transactions=[
            TransactionResponse(
                id=t.id,
                agency_id=t.agency_id,
                property_id=t.property_id,
                unit_id=t.unit_id,
                tenant_id=t.tenant_id,
                type=t.type,
                category=t.category,
                amount=float(t.amount),
                currency=t.currency,
                transaction_date=t.transaction_date,
                description=t.description,
                receipt_url=t.receipt_url
            ) for t in transactions
        ]
    )


@router.get("/", response_model=List[TenantWithDetailsResponse])
async def list_tenants(
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Bu ajansa ait tüm kiracıları listeler (PRD §4.1.4).
    Aktif ve pasif kiracılar dahil.
    """
    stmt = (
        select(Tenant)
        .where(Tenant.agency_id == agency_id)
        .options(selectinload(Tenant.unit).selectinload(PropertyUnit.property))
    ).order_by(Tenant.created_at.desc())
    result = await db.execute(stmt)
    tenants = result.scalars().all()

    # Detaylı yanıt oluştur
    response = []
    for t in tenants:
        unit = t.unit
        property_ = unit.property if unit else None
        response.append(TenantWithDetailsResponse(
            id=t.id,
            agency_id=t.agency_id,
            unit_id=t.unit_id,
            user_id=t.user_id,
            temp_name=t.temp_name,
            temp_phone=t.temp_phone,
            rent_amount=t.rent_amount,
            payment_day=t.payment_day,
            start_date=t.start_date,
            end_date=t.end_date,
            status=t.status.value if hasattr(t.status, 'value') else t.status,
            actual_end_date=t.actual_end_date,
            is_active=t.is_active,
            created_at=t.created_at,
            unit_door_number=unit.door_number if unit else None,
            unit_floor=unit.floor if unit else None,
            property_name=property_.name if property_ else None,
            user_full_name=None,  # User tablosu ayrı sorgulanabilir
            user_phone=None
        ))

    return response


@router.post("/", response_model=TenantResponse, status_code=status.HTTP_201_CREATED)
async def create_tenant(
    tenant_in: TenantCreate,
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Yeni kiracı oluşturur ve birime atar (PRD §4.1.4).
    Birim daha önce başka kiracılya kiralanmışsa hata verir.
    """
    # Birimin bu agency'ye ait olduğunu kontrol et
    unit_stmt = select(PropertyUnit).where(
        PropertyUnit.id == tenant_in.unit_id,
        PropertyUnit.agency_id == agency_id
    )
    unit_result = await db.execute(unit_stmt)
    unit = unit_result.scalar_one_or_none()

    if not unit:
        raise HTTPException(status_code=404, detail="Birim bulunamadı veya erişim yetkiniz yok.")

    # Birim başka kiracılya kiralanmış mı kontrol et
    active_tenant_stmt = select(Tenant).where(
        Tenant.unit_id == tenant_in.unit_id,
        Tenant.is_active == True
    )
    active_result = await db.execute(active_tenant_stmt)
    active_tenant = active_result.scalar_one_or_none()

    if active_tenant:
        raise HTTPException(status_code=400, detail="Bu birimde aktif kiracı bulunuyor.")

    # Yeni kiracı oluştur
    tenant = Tenant(
        agency_id=agency_id,
        unit_id=tenant_in.unit_id,
        user_id=tenant_in.user_id,
        temp_name=tenant_in.temp_name,
        temp_phone=tenant_in.temp_phone,
        rent_amount=tenant_in.rent_amount,
        payment_day=tenant_in.payment_day,
        start_date=tenant_in.start_date,
        end_date=tenant_in.end_date,
        status="active"
    )
    db.add(tenant)

    # Birimi "occupied" olarak işaretle
    unit.status = "occupied"
    unit.vacant_since = None

    await db.commit()
    await db.refresh(tenant)

    return tenant


@router.patch("/{tenant_id}", response_model=TenantResponse)
async def update_tenant(
    tenant_id: str,
    tenant_in: TenantUpdate,
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(get_db)
):
    """Kiracı bilgilerini günceller (PRD §4.1.4)."""
    stmt = select(Tenant).where(
        Tenant.id == UUID(tenant_id),
        Tenant.agency_id == agency_id
    )
    result = await db.execute(stmt)
    tenant = result.scalar_one_or_none()

    if not tenant:
        raise HTTPException(status_code=404, detail="Kiracı bulunamadı.")

    update_data = tenant_in.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(tenant, field, value)

    await db.commit()
    await db.refresh(tenant)

    return tenant


@router.post("/{tenant_id}/deactivate", response_model=TenantResponse)
async def deactivate_tenant(
    tenant_id: str,
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Kiracı sözleşmesini sonlandırır (Offboarding - PRD §4.1.4-A).
    Kiracı "Pasif/Eski Kiracı" statüsüne alınır ve birim "Boş" olarak işaretlenir.
    """
    stmt = select(Tenant).where(
        Tenant.id == UUID(tenant_id),
        Tenant.agency_id == agency_id
    )
    result = await db.execute(stmt)
    tenant = result.scalar_one_or_none()

    if not tenant:
        raise HTTPException(status_code=404, detail="Kiracı bulunamadı.")

    if not tenant.is_active:
        raise HTTPException(status_code=400, detail="Bu kiracı zaten pasif durumda.")

    # Kiracıyı pasif yap
    tenant.is_active = False
    tenant.status = "past"
    tenant.actual_end_date = datetime.utcnow().date()

    # Birimi boş olarak işaretle
    unit_stmt = select(PropertyUnit).where(PropertyUnit.id == tenant.unit_id)
    unit_result = await db.execute(unit_stmt)
    unit = unit_result.scalar_one_or_none()
    if unit:
        unit.status = "vacant"
        unit.vacant_since = datetime.utcnow()

    await db.commit()
    await db.refresh(tenant)

    return tenant


@router.get("/{tenant_id}", response_model=TenantWithDetailsResponse)
async def get_tenant(
    tenant_id: str,
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(get_db)
):
    """Kiracı detayını getirir."""
    stmt = (
        select(Tenant)
        .where(Tenant.id == UUID(tenant_id), Tenant.agency_id == agency_id)
        .options(selectinload(Tenant.unit).selectinload(PropertyUnit.property))
    )
    result = await db.execute(stmt)
    tenant = result.scalar_one_or_none()

    if not tenant:
        raise HTTPException(status_code=404, detail="Kiracı bulunamadı.")

    unit = tenant.unit
    property_ = unit.property if unit else None

    return TenantWithDetailsResponse(
        id=tenant.id,
        agency_id=tenant.agency_id,
        unit_id=tenant.unit_id,
        user_id=tenant.user_id,
        temp_name=tenant.temp_name,
        temp_phone=tenant.temp_phone,
        rent_amount=tenant.rent_amount,
        payment_day=tenant.payment_day,
        start_date=tenant.start_date,
        end_date=tenant.end_date,
        status=tenant.status.value if hasattr(tenant.status, 'value') else tenant.status,
        actual_end_date=tenant.actual_end_date,
        is_active=tenant.is_active,
        created_at=tenant.created_at,
        unit_door_number=unit.door_number if unit else None,
        unit_floor=unit.floor if unit else None,
        property_name=property_.name if property_ else None,
        user_full_name=None,
        user_phone=None
    )


# ==================== LANDLORD ENDPOINTS ====================

@router.get("/landlords", response_model=List[LandlordWithDetailsResponse])
async def list_landlords(
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Bu ajansa ait tüm ev sahiplerini listeler (PRD §4.1.4).
    """
    stmt = (
        select(LandlordUnit)
        .where(LandlordUnit.agency_id == agency_id)
        .options(selectinload(LandlordUnit.unit).selectinload(PropertyUnit.property))
    ).order_by(LandlordUnit.created_at.desc())
    result = await db.execute(stmt)
    landlords = result.scalars().all()

    response = []
    for l in landlords:
        unit = l.unit
        property_ = unit.property if unit else None
        response.append(LandlordWithDetailsResponse(
            id=l.id,
            agency_id=l.agency_id,
            unit_id=l.unit_id,
            user_id=l.user_id,
            temp_name=l.temp_name,
            temp_phone=l.temp_phone,
            ownership_share=l.ownership_share,
            created_at=l.created_at,
            unit_door_number=unit.door_number if unit else None,
            property_name=property_.name if property_ else None,
            user_full_name=None,
            user_phone=None
        ))

    return response


@router.post("/landlords", response_model=List[LandlordResponse], status_code=status.HTTP_201_CREATED)
async def create_landlord(
    landlord_in: LandlordCreate,
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Yeni ev sahibi oluşturur ve birden fazla birime bağlar (PRD §4.1.4).
    1-to-Many ilişki: Bir ev sahibi birden fazla birime sahip olabilir.
    """
    created_landlords = []

    for unit_id in landlord_in.unit_ids:
        # Birimin bu agency'ye ait olduğunu kontrol et
        unit_stmt = select(PropertyUnit).where(
            PropertyUnit.id == unit_id,
            PropertyUnit.agency_id == agency_id
        )
        unit_result = await db.execute(unit_stmt)
        unit = unit_result.scalar_one_or_none()

        if not unit:
            continue  # Bu birimi atla

        # Aynı kullanıcı + birim kombinasyonu var mı kontrol et
        existing_stmt = select(LandlordUnit).where(
            LandlordUnit.unit_id == unit_id,
            LandlordUnit.user_id == landlord_in.user_id
        )
        existing_result = await db.execute(existing_stmt)
        existing = existing_result.scalar_one_or_none()

        if existing:
            continue  # Zaten varsa ekleme

        landlord = LandlordUnit(
            agency_id=agency_id,
            unit_id=unit_id,
            user_id=landlord_in.user_id,
            temp_name=landlord_in.temp_name,
            temp_phone=landlord_in.temp_phone,
            ownership_share=landlord_in.ownership_share
        )
        db.add(landlord)
        created_landlords.append(landlord)

    await db.commit()

    # Refresh all created
    for l in created_landlords:
        await db.refresh(l)

    return created_landlords


@router.get("/landlords/{landlord_id}", response_model=LandlordWithDetailsResponse)
async def get_landlord(
    landlord_id: str,
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(get_db)
):
    """Ev sahibi detayını getirir."""
    stmt = (
        select(LandlordUnit)
        .where(LandlordUnit.id == UUID(landlord_id), LandlordUnit.agency_id == agency_id)
        .options(selectinload(LandlordUnit.unit).selectinload(PropertyUnit.property))
    )
    result = await db.execute(stmt)
    landlord = result.scalar_one_or_none()

    if not landlord:
        raise HTTPException(status_code=404, detail="Ev sahibi bulunamadı.")

    unit = landlord.unit
    property_ = unit.property if unit else None

    return LandlordWithDetailsResponse(
        id=landlord.id,
        agency_id=landlord.agency_id,
        unit_id=landlord.unit_id,
        user_id=landlord.user_id,
        temp_name=landlord.temp_name,
        temp_phone=landlord.temp_phone,
        ownership_share=landlord.ownership_share,
        created_at=landlord.created_at,
        unit_door_number=unit.door_number if unit else None,
        property_name=property_.name if property_ else None,
        user_full_name=None,
        user_phone=None
    )
