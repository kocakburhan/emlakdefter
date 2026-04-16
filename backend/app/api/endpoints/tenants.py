from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from typing import List, Optional
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
    LandlordCreate, LandlordResponse, LandlordWithDetailsResponse,
    TenantTicketCreate, TenantTicketResponse, TenantTicketMessageResponse,
    TenantDocumentsResponse, TenantDocumentItem,
)
from app.schemas.finance import TenantFinanceSummary, PaymentScheduleResponse, TransactionResponse
from app.schemas.operations import TicketMessageResponse
from app.models.operations import SupportTicket, TicketMessage, TicketStatus, TicketPriority
from app.models.chat import ChatConversation, ChatMessage
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

    # Birimi "rented" olarak işaretle
    unit.status = "rented"
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


@router.post("/{tenant_id}/upload-contract")
async def upload_tenant_contract(
    tenant_id: str,
    contract_url: str,
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(get_db),
):
    """
    Kiracı sözleşmesini yükler/günceller (PRD §4.1.4-A).
    contract_document_url: Hetzner Object Storage URL.
    """
    stmt = select(Tenant).where(
        Tenant.id == UUID(tenant_id),
        Tenant.agency_id == agency_id,
    )
    result = await db.execute(stmt)
    tenant = result.scalar_one_or_none()

    if not tenant:
        raise HTTPException(status_code=404, detail="Kiracı bulunamadı.")

    tenant.contract_document_url = contract_url
    await db.commit()
    await db.refresh(tenant)

    return {
        "success": True,
        "message": "Sözleşme yüklendi",
        "contract_url": contract_url,
    }


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


# ==================== TENANT DOCUMENTS ENDPOINTS — PRD §4.2.3 ====================

@router.get("/me/documents", response_model=TenantDocumentsResponse)
async def get_current_tenant_documents(
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(get_db),
):
    """
    Kiracının tüm belgelerini döner (Kira Sözleşmesi, Demirbaş Tutanağı, Aidat Planı vb.)
    Salt okunur — PRD §4.2.3.
    """
    tenant_stmt = select(Tenant).where(
        Tenant.user_id == current_user.id,
        Tenant.is_active == True,
    )
    tenant_result = await db.execute(tenant_stmt)
    tenant = tenant_result.scalar_one_or_none()

    if not tenant:
        raise HTTPException(status_code=404, detail="Aktif kiracı kaydınız bulunamadı.")

    docs = []
    if tenant.documents:
        for d in (tenant.documents or []):
            docs.append(TenantDocumentItem(
                name=d.get('name', 'Belge'),
                doc_type=d.get('type', 'other'),
                url=d.get('url', ''),
                uploaded_at=None,
            ))

    return TenantDocumentsResponse(
        contract_document_url=tenant.contract_document_url,
        documents=docs,
    )


# ==================== TENANT SUPPORT TICKET ENDPOINTS — PRD §4.2.2 ====================

async def _get_tenant_and_unit(db, current_user, agency_id):
    """Kiracı ve bağlı birimi getir yardımcı."""
    stmt = (
        select(Tenant)
        .where(Tenant.user_id == current_user.id, Tenant.is_active == True)
        .options(selectinload(Tenant.unit).selectinload(PropertyUnit.property))
    )
    result = await db.execute(stmt)
    tenant = result.scalar_one_or_none()
    if not tenant:
        raise HTTPException(status_code=404, detail="Aktif kiracı kaydınız bulunamadı.")
    return tenant


@router.post("/me/tickets", response_model=TenantTicketResponse, status_code=status.HTTP_201_CREATED)
async def create_tenant_ticket(
    ticket_in: TenantTicketCreate,
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(get_db),
):
    """
    Kiracının yeni destek bileti açması — PRD §4.2.2-A.
    Bilet otomatik olarak kiracının birimine bağlanır.
    """
    tenant = await _get_tenant_and_unit(db, current_user, agency_id)

    db_ticket = SupportTicket(
        agency_id=agency_id,
        unit_id=tenant.unit_id,
        reporter_user_id=current_user.id,
        title=ticket_in.title,
        description=ticket_in.description,
        priority=ticket_in.priority,
        attachment_url=ticket_in.attachment_url,
        status=TicketStatus.open,
    )
    db.add(db_ticket)
    await db.flush()

    # İlk mesaj olarak açıklama varsa ekle
    if ticket_in.description:
        first_msg = TicketMessage(
            ticket_id=db_ticket.id,
            sender_user_id=current_user.id,
            message=ticket_in.description,
            attachment_url=ticket_in.attachment_url,
        )
        db.add(first_msg)

    await db.commit()
    await db.refresh(db_ticket)

    unit = tenant.unit
    property_ = unit.property if unit else None

    return TenantTicketResponse(
        id=db_ticket.id,
        title=db_ticket.title,
        description=db_ticket.description,
        priority=db_ticket.priority,
        status=db_ticket.status,
        created_at=db_ticket.created_at,
        updated_at=db_ticket.updated_at,
        unit_door=unit.door_number if unit else None,
        property_name=property_.name if property_ else None,
        message_count=1 if ticket_in.description else 0,
        last_message=ticket_in.description,
        last_message_at=db_ticket.created_at,
        messages=[],
    )


@router.get("/me/tickets", response_model=List[TenantTicketResponse])
async def list_tenant_tickets(
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(get_db),
):
    """
    Kiracının kendi destek biletlerini listeler — PRD §4.2.2.
    Sadece kiracının kendi birimine ait biletler gelir (RLS benzeri filtreme).
    """
    tenant = await _get_tenant_and_unit(db, current_user, agency_id)

    stmt = (
        select(SupportTicket)
        .where(
            SupportTicket.agency_id == agency_id,
            SupportTicket.unit_id == tenant.unit_id,
        )
        .options(selectinload(SupportTicket.messages))
        .order_by(desc(SupportTicket.created_at))
    )
    result = await db.execute(stmt)
    tickets = result.scalars().all()

    response = []
    for t in tickets:
        unit_stmt = select(PropertyUnit).where(PropertyUnit.id == t.unit_id)
        unit_result = await db.execute(unit_stmt)
        unit = unit_result.scalar_one_or_none()
        property_stmt = select(Property).where(Property.id == unit.property_id) if unit else None
        prop = None
        if property_stmt:
            prop_result = await db.execute(property_stmt)
            prop = prop_result.scalar_one_or_none()

        msgs = sorted(t.messages, key=lambda m: m.created_at) if t.messages else []
        last_msg = msgs[-1] if msgs else None

        response.append(TenantTicketResponse(
            id=t.id,
            title=t.title,
            description=t.description,
            priority=t.priority,
            status=t.status,
            created_at=t.created_at,
            updated_at=t.updated_at,
            unit_door=unit.door_number if unit else None,
            property_name=prop.name if prop else None,
            message_count=len(msgs),
            last_message=last_msg.message if last_msg else None,
            last_message_at=last_msg.created_at if last_msg else None,
            messages=[
                TenantTicketMessageResponse(
                    id=m.id,
                    sender_user_id=m.sender_user_id,
                    sender_name=None,
                    message=m.message,
                    attachment_url=m.attachment_url,
                    is_agent=False,
                    created_at=m.created_at,
                ) for m in msgs
            ],
        ))
    return response


@router.get("/me/tickets/{ticket_id}", response_model=TenantTicketResponse)
async def get_tenant_ticket(
    ticket_id: str,
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(get_db),
):
    """
    Kiracının kendi biletinin detayını getirir — PRD §4.2.2-C (zaman tüneli).
    """
    tenant = await _get_tenant_and_unit(db, current_user, agency_id)

    stmt = (
        select(SupportTicket)
        .where(
            SupportTicket.id == UUID(ticket_id),
            SupportTicket.agency_id == agency_id,
            SupportTicket.unit_id == tenant.unit_id,
        )
        .options(selectinload(SupportTicket.messages))
    )
    result = await db.execute(stmt)
    ticket = result.scalar_one_or_none()

    if not ticket:
        raise HTTPException(status_code=404, detail="Bilet bulunamadı.")

    unit_stmt = select(PropertyUnit).where(PropertyUnit.id == ticket.unit_id)
    unit_result = await db.execute(unit_stmt)
    unit = unit_result.scalar_one_or_none()
    prop = None
    if unit:
        prop_stmt = select(Property).where(Property.id == unit.property_id)
        prop_result = await db.execute(prop_stmt)
        prop = prop_result.scalar_one_or_none()

    msgs = sorted(ticket.messages, key=lambda m: m.created_at) if ticket.messages else []

    return TenantTicketResponse(
        id=ticket.id,
        title=ticket.title,
        description=ticket.description,
        priority=ticket.priority,
        status=ticket.status,
        created_at=ticket.created_at,
        updated_at=ticket.updated_at,
        unit_door=unit.door_number if unit else None,
        property_name=prop.name if prop else None,
        message_count=len(msgs),
        last_message=msgs[-1].message if msgs else None,
        last_message_at=msgs[-1].created_at if msgs else None,
        messages=[
            TenantTicketMessageResponse(
                id=m.id,
                sender_user_id=m.sender_user_id,
                sender_name=None,
                message=m.message,
                attachment_url=m.attachment_url,
                is_agent=False,
                created_at=m.created_at,
            ) for m in msgs
        ],
    )


@router.post("/me/tickets/{ticket_id}/reply", response_model=TenantTicketMessageResponse)
async def reply_to_tenant_ticket(
    ticket_id: str,
    message: str,
    attachment_url: Optional[str] = None,
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(get_db),
):
    """
    Kiracının kendi biletine yanıt vermesi — PRD §4.2.2-C.
    """
    tenant = await _get_tenant_and_unit(db, current_user, agency_id)

    stmt = select(SupportTicket).where(
        SupportTicket.id == UUID(ticket_id),
        SupportTicket.agency_id == agency_id,
        SupportTicket.unit_id == tenant.unit_id,
    )
    result = await db.execute(stmt)
    ticket = result.scalar_one_or_none()

    if not ticket:
        raise HTTPException(status_code=404, detail="Bilet bulunamadı.")

    # Status'ü in_progress'a güncelle (ilk yanıtta)
    if ticket.status == TicketStatus.open:
        ticket.status = TicketStatus.in_progress

    db_msg = TicketMessage(
        ticket_id=ticket.id,
        sender_user_id=current_user.id,
        message=message,
        attachment_url=attachment_url,
    )
    db.add(db_msg)
    await db.commit()
    await db.refresh(db_msg)

    return TenantTicketMessageResponse(
        id=db_msg.id,
        sender_user_id=db_msg.sender_user_id,
        sender_name=None,
        message=db_msg.message,
        attachment_url=db_msg.attachment_url,
        is_agent=False,
        created_at=db_msg.created_at,
    )


# ==================== TENANT CHAT CONVERSATIONS — PRD §4.2.5 ====================

@router.get("/me/conversations", response_model=List[dict])
async def get_tenant_conversations(
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(get_db),
):
    """
    Kiracının tüm sohbetlerini listeler — PRD §4.2.5.
    Yalnızca kiracının kendiclient_user_id ile eşleşen konuşmaları döner.
    """
    stmt = (
        select(ChatConversation)
        .where(
            ChatConversation.agency_id == agency_id,
            ChatConversation.client_user_id == current_user.id,
        )
        .options(selectinload(ChatConversation.messages))
        .order_by(desc(ChatConversation.updated_at))
    )
    result = await db.execute(stmt)
    conversations = result.scalars().all()

    from app.schemas.chat import ChatConversationResponse
    responses = []
    for conv in conversations:
        sorted_msgs = sorted(conv.messages, key=lambda m: m.created_at, reverse=True)
        last_msg = next((m for m in sorted_msgs if not m.is_deleted), None)

        # Agent (karşı taraf) bilgisini al
        agent_stmt = select(User).where(User.id == conv.agent_user_id)
        agent_res = await db.execute(agent_stmt)
        agent_user = agent_res.scalar_one_or_none()

        # Mülk bilgisi
        prop = None
        if conv.property_id:
            prop_stmt = select(Property).where(Property.id == conv.property_id)
            prop_res = await db.execute(prop_stmt)
            prop = prop_res.scalar_one_or_none()

        responses.append({
            "id": str(conv.id),
            "agency_id": str(conv.agency_id),
            "agent_user_id": str(conv.agent_user_id),
            "client_user_id": str(conv.client_user_id),
            "property_id": str(conv.property_id) if conv.property_id else None,
            "client_name": agent_user.full_name if agent_user else "Ofis Sistemi",
            "client_role": "Emlakçı",
            "property_name": prop.name if prop else None,
            "last_message": last_msg.content if last_msg else None,
            "last_message_at": last_msg.created_at.isoformat() if last_msg else conv.created_at.isoformat(),
            "unread_count": 0,
            "is_archived": conv.is_archived,
            "created_at": conv.created_at.isoformat(),
        })
    return responses


@router.post("/me/conversations", response_model=dict, status_code=status.HTTP_201_CREATED)
async def create_tenant_conversation(
    property_id: Optional[UUID] = None,
    initial_message: Optional[str] = None,
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(get_db),
):
    """
    Kiracının yeni sohbet başlatması — PRD §4.2.5 + §4.2.6.
    Mülk ID'si verilirse o mülk hakkında bilgi isteyen bir konuşma açar.
    """
    # Ofis sistemi için bir agent user bul (ilk active agent)
    agent_stmt = (
        select(User)
        .where(User.agency_id == agency_id, User.role == "agent")
        .limit(1)
    )
    agent_res = await db.execute(agent_stmt)
    agent_user = agent_res.scalar_one_or_none()

    if not agent_user:
        raise HTTPException(status_code=400, detail="Ofis sisteminde aktif emlakçı bulunamadı.")

    # Varolan sohbeti kontrol et
    existing_stmt = select(ChatConversation).where(
        ChatConversation.agency_id == agency_id,
        ChatConversation.client_user_id == current_user.id,
        ChatConversation.is_archived == False,
    )
    existing_res = await db.execute(existing_stmt)
    existing = existing_res.scalar_one_or_none()

    if existing:
        # Mülk bilgisi güncelle
        if property_id and not existing.property_id:
            existing.property_id = property_id
            await db.commit()
        conv = existing
    else:
        conv = ChatConversation(
            agency_id=agency_id,
            agent_user_id=agent_user.id,
            client_user_id=current_user.id,
            property_id=property_id,
        )
        db.add(conv)
        await db.flush()

    # İlk mesaj varsa ekle
    msg_id = None
    if initial_message:
        chat_msg = ChatMessage(
            conversation_id=conv.id,
            sender_user_id=current_user.id,
            message=initial_message,
        )
        db.add(chat_msg)
        await db.flush()
        msg_id = str(chat_msg.id)

    await db.commit()
    await db.refresh(conv)

    prop = None
    if conv.property_id:
        prop_stmt = select(Property).where(Property.id == conv.property_id)
        prop_res = await db.execute(prop_stmt)
        prop = prop_res.scalar_one_or_none()

    return {
        "id": str(conv.id),
        "agency_id": str(conv.agency_id),
        "agent_user_id": str(conv.agent_user_id),
        "client_user_id": str(conv.client_user_id),
        "property_id": str(conv.property_id) if conv.property_id else None,
        "client_name": agent_user.full_name if agent_user else "Ofis Sistemi",
        "property_name": prop.name if prop else None,
        "last_message": initial_message,
        "last_message_at": conv.updated_at.isoformat(),
        "unread_count": 0,
        "is_archived": conv.is_archived,
        "created_at": conv.created_at.isoformat(),
    }


@router.get("/me/conversations/{conversation_id}/messages", response_model=List[dict])
async def get_tenant_conversation_messages(
    conversation_id: str,
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(get_db),
):
    """
    Kiracının belirli bir sohbetindeki mesajları listeler — PRD §4.2.5.
    """
    stmt = (
        select(ChatConversation)
        .where(
            ChatConversation.id == UUID(conversation_id),
            ChatConversation.agency_id == agency_id,
            ChatConversation.client_user_id == current_user.id,
        )
        .options(selectinload(ChatConversation.messages))
    )
    result = await db.execute(stmt)
    conv = result.scalar_one_or_none()

    if not conv:
        raise HTTPException(status_code=404, detail="Sohbet bulunamadı.")

    from app.schemas.chat import ChatMessageResponse
    messages = sorted(conv.messages, key=lambda m: m.created_at)
    return [
        {
            "id": str(m.id),
            "conversation_id": str(m.conversation_id),
            "sender_user_id": str(m.sender_user_id),
            "content": m.content,
            "attachment_url": m.attachment_url,
            "created_at": m.created_at.isoformat(),
            "is_deleted": m.is_deleted,
            "is_edited": m.is_edited,
        }
        for m in messages
        if not m.is_deleted
    ]


# ==================== TENANT VACANT UNITS (PORTFÖY VİTRİNİ) — PRD §4.2.6 ====================

@router.get("/me/vacant-units", response_model=List[dict])
async def get_tenant_vacant_units(
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(get_db),
    property_name: Optional[str] = None,
):
    """
    Kiracının portföy vitrinindeki boş daireleri listeler — PRD §4.2.6.
    Ofisin tüm boş birimlerini görür (kiracının kendi birimi hariç).
    """
    # Kiracının kendi birimini bul (hariç tutmak için)
    tenant_stmt = select(Tenant).where(
        Tenant.user_id == current_user.id, Tenant.is_active == True
    )
    tenant_res = await db.execute(tenant_stmt)
    current_tenant = tenant_res.scalar_one_or_none()
    my_unit_id = current_tenant.unit_id if current_tenant else None

    query = (
        select(PropertyUnit)
        .where(
            PropertyUnit.agency_id == agency_id,
            PropertyUnit.status == "vacant",
        )
        .options(selectinload(PropertyUnit.property))
    )
    if my_unit_id:
        query = query.where(PropertyUnit.id != my_unit_id)
    if property_name:
        query = query.where(PropertyUnit.property.has(Property.name.ilike(f"%{property_name}%")))
    query = query.order_by(PropertyUnit.vacant_since.desc())

    result = await db.execute(query)
    units = result.scalars().all()

    return [
        {
            "unit_id": str(u.id),
            "property_id": str(u.property_id),
            "property_name": u.property.name if u.property else "",
            "address": u.property.address if u.property else "",
            "door_number": u.door_number,
            "floor": u.floor,
            "rent_price": u.rent_price or 0,
            "dues_amount": u.dues_amount or 0,
            "features": [],
        }
        for u in units
    ]


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
