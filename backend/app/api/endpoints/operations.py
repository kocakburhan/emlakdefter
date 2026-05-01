from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc, func
from sqlalchemy.orm import selectinload
from uuid import UUID
from typing import List, Optional
from datetime import datetime, date

from app.api import deps
from app.models.users import User
from app.models.properties import Property, PropertyUnit, UnitStatus
from app.models.operations import SupportTicket, TicketMessage, BuildingOperationLog, TicketStatus, OperationCategory
from app.models.tenants import Tenant
from app.models.finance import FinancialTransaction, TransactionType, TransactionCategory
from app.schemas.operations import (
    TicketCreate, TicketResponse, TicketMessageCreate, TicketMessageResponse,
    BuildingLogCreate, BuildingLogUpdate, BuildingLogResponse,
    TicketListResponse, TicketStatusUpdate
)
from pydantic import BaseModel
from typing import Optional
from app.models.users import AgencyStaff

router = APIRouter()


# ──────────────────────────────────────────────
# DASHBOARD KPI (PRD §4.1.1)
# ──────────────────────────────────────────────

class AgentDashboardKPIs(BaseModel):
    total_properties: int
    total_units: int
    occupied_units: int
    vacant_units: int
    total_monthly_rent: int
    total_monthly_dues: int
    pending_tickets: int
    open_tickets: int
    monthly_collected: int
    monthly_expense: int
    collection_rate: float
    active_tenants: int
    staff_count: int

    class Config:
        from_attributes = True


class ActivityFeedItem(BaseModel):
    id: str
    type: str  # "payment", "ticket", "property", "tenant", "building_log"
    title: str
    subtitle: str
    icon: str
    color: str
    timestamp: str
    link: Optional[str] = None

    class Config:
        from_attributes = True


class ActivityFeedResponse(BaseModel):
    items: List[ActivityFeedItem]
    total: int
    has_more: bool


@router.get("/dashboard-kpi", response_model=AgentDashboardKPIs)
async def get_agent_dashboard_kpi(
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(deps.get_db),
):
    """
    Emlakçının ana dashboard KPI'larını döner.
    PRD §4.1.1 — Toplam bina, birim, doluluk, tahsilat, bekleyen bilet.
    """
    # Toplam mülk
    prop_stmt = select(func.count(Property.id)).where(
        Property.agency_id == agency_id, Property.is_deleted == False
    )
    prop_result = await db.execute(prop_stmt)
    total_properties = prop_result.scalar() or 0

    # Toplam birim
    unit_stmt = select(func.count(PropertyUnit.id)).where(
        PropertyUnit.agency_id == agency_id
    )
    unit_result = await db.execute(unit_stmt)
    total_units = unit_result.scalar() or 0

    # Dolu/Boş birimler
    occ_stmt = select(func.count(PropertyUnit.id)).where(
        PropertyUnit.agency_id == agency_id, PropertyUnit.status == UnitStatus.rented
    )
    occ_result = await db.execute(occ_stmt)
    occupied_units = occ_result.scalar() or 0
    vacant_units = total_units - occupied_units

    # Toplam kira + aidat (aylık)
    rent_stmt = select(func.coalesce(func.sum(PropertyUnit.rent_price), 0)).where(
        PropertyUnit.agency_id == agency_id, PropertyUnit.status == UnitStatus.rented
    )
    rent_result = await db.execute(rent_stmt)
    total_monthly_rent = rent_result.scalar() or 0

    dues_stmt = select(func.coalesce(func.sum(PropertyUnit.dues_amount), 0)).where(
        PropertyUnit.agency_id == agency_id
    )
    dues_result = await db.execute(dues_stmt)
    total_monthly_dues = dues_result.scalar() or 0

    # Bekleyen biletler (opsiyonel)
    ticket_stmt = select(func.count(SupportTicket.id)).where(
        SupportTicket.agency_id == agency_id,
        SupportTicket.status.in_([TicketStatus.open, TicketStatus.in_progress])
    )
    ticket_result = await db.execute(ticket_stmt)
    pending_tickets = ticket_result.scalar() or 0

    open_stmt = select(func.count(SupportTicket.id)).where(
        SupportTicket.agency_id == agency_id, SupportTicket.status == TicketStatus.open
    )
    open_result = await db.execute(open_stmt)
    open_tickets = open_result.scalar() or 0

    # Aktif kiracı sayısı
    tenant_stmt = select(func.count(Tenant.id)).where(
        Tenant.agency_id == agency_id,
        Tenant.status == "active"
    )
    tenant_result = await db.execute(tenant_stmt)
    active_tenants = tenant_result.scalar() or 0

    # Personel (çalışan) sayısı
    staff_stmt = select(func.count(AgencyStaff.id)).where(AgencyStaff.agency_id == agency_id)
    staff_result = await db.execute(staff_stmt)
    staff_count = staff_result.scalar() or 0

    # Basit tahsilat oranı (bu basit hesap backend'e bağlıyken gerçek tablo için finans modülü gerekir)
    collection_rate = round((occupied_units / total_units * 100), 1) if total_units > 0 else 0.0

    return AgentDashboardKPIs(
        total_properties=total_properties,
        total_units=total_units,
        occupied_units=occupied_units,
        vacant_units=vacant_units,
        total_monthly_rent=total_monthly_rent,
        total_monthly_dues=total_monthly_dues,
        pending_tickets=pending_tickets,
        open_tickets=open_tickets,
        monthly_collected=total_monthly_rent,
        monthly_expense=0,
        collection_rate=collection_rate,
        active_tenants=active_tenants,
        staff_count=staff_count,
    )

@router.post("/tickets", response_model=TicketResponse, status_code=status.HTTP_201_CREATED)
async def create_ticket(
    ticket_in: TicketCreate,
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(deps.get_db)
):
    """
    (PRD Destek Bölümü): Kiracının dairesindeki hasarı, bozuk asansörü vb. 'Priority' (Öncelik)
    ve opsiyonel Fotoğrafla (attachment_url) yetkili Emlakçıya kanıtladığı arıza biletini açar.
    """
    unit = await db.get(PropertyUnit, ticket_in.unit_id)
    if not unit or unit.agency_id != agency_id:
        raise HTTPException(status_code=404, detail="Ulaşmaya çalıştığınız mülk yetkiniz dahilinde değil.")

    db_ticket = SupportTicket(
        agency_id=agency_id,
        unit_id=ticket_in.unit_id,
        reporter_user_id=current_user.id,
        title=ticket_in.title,
        description=ticket_in.description,
        priority=ticket_in.priority,
        status=TicketStatus.open,
        attachment_url=ticket_in.attachment_url
    )
    db.add(db_ticket)
    await db.commit()
    await db.refresh(db_ticket)
    return db_ticket


@router.get("/tickets", response_model=List[TicketListResponse])
async def list_tickets(
    status_filter: Optional[str] = None,
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(deps.get_db),
):
    """Emlakçının tüm biletlerini listeler."""
    stmt = (
        select(SupportTicket)
        .where(SupportTicket.agency_id == agency_id)
        .options(selectinload(SupportTicket.messages), selectinload(SupportTicket.unit).selectinload(PropertyUnit.property), selectinload(SupportTicket.reporter))
        .order_by(desc(SupportTicket.created_at))
    )
    if status_filter:
        try:
            status_enum = TicketStatus(status_filter)
            stmt = stmt.where(SupportTicket.status == status_enum)
        except ValueError:
            pass

    result = await db.execute(stmt)
    tickets = result.scalars().all()

    responses = []
    for t in tickets:
        msg_count = len(t.messages) if t.messages else 0
        last_msg = t.messages[-1].message if t.messages else None
        unit_door = t.unit.door_number if t.unit else None
        unit_property = t.unit.property.name if t.unit and t.unit.property else None
        reporter_name = t.reporter.full_name if t.reporter else None
        responses.append(TicketListResponse(
            id=t.id,
            title=t.title,
            priority=t.priority,
            status=t.status,
            created_at=t.created_at,
            message_count=msg_count,
            last_message=last_msg,
            unit_door=unit_door,
            unit_property=unit_property,
            reporter_name=reporter_name,
        ))
    return responses


@router.patch("/tickets/{ticket_id}", response_model=TicketResponse)
async def update_ticket_status(
    ticket_id: str,
    status_in: TicketStatusUpdate,
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(deps.get_db),
):
    """Bilet durumunu günceller (resolved/closed vb)."""
    ticket = await db.get(SupportTicket, UUID(ticket_id))
    if not ticket or ticket.agency_id != agency_id:
        raise HTTPException(status_code=404, detail="Bilet bulunamadı.")

    try:
        ticket.status = TicketStatus(status_in.status)
    except ValueError:
        raise HTTPException(status_code=400, detail="Geçersiz bilet durumu.")

    await db.commit()
    await db.refresh(ticket)
    return ticket


@router.get("/tickets/{ticket_id}", response_model=TicketResponse)
async def get_ticket(
    ticket_id: str,
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(deps.get_db),
):
    """Bilet detayını mesajlarla birlikte getirir."""
    stmt = (
        select(SupportTicket)
        .where(SupportTicket.id == UUID(ticket_id), SupportTicket.agency_id == agency_id)
        .options(
            selectinload(SupportTicket.messages),
            selectinload(SupportTicket.unit).selectinload(PropertyUnit.tenant_contracts),
        )
    )
    result = await db.execute(stmt)
    ticket = result.scalar_one_or_none()
    if not ticket:
        raise HTTPException(status_code=404, detail="Bilet bulunamadı.")

    # Kiracı telefonunu çözümle (Tenant üzerinden)
    tenant_phone = None
    if ticket.unit and ticket.unit.tenant_contracts:
        for tc in ticket.unit.tenant_contracts:
            if tc.is_active and tc.user_id:
                # User tablosundan telefon numarasını al
                user_stmt = select(User.phone_number).where(User.id == tc.user_id)
                user_result = await db.execute(user_stmt)
                tenant_phone = user_result.scalar_one_or_none()
                if tenant_phone:
                    break
            elif tc.is_active and tc.temp_phone:
                tenant_phone = tc.temp_phone
                break

    # Telefonu TicketResponse'a ekle
    response_data = TicketResponse.model_validate(ticket).model_dump()
    response_data['tenant_phone'] = tenant_phone
    return TicketResponse(**response_data)


@router.post("/tickets/{ticket_id}/reply", response_model=TicketMessageResponse)
async def reply_to_ticket(
    ticket_id: str,
    reply_in: TicketMessageCreate,
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(deps.get_db)
):
    """Emlakçı acente personelinin veya Kiracının mevcut açık bilete yazdığı mesajın (Örn: 'Usta yola çıktı') log tablosudur."""
    ticket = await db.get(SupportTicket, UUID(ticket_id))
    if not ticket or ticket.agency_id != agency_id:
        raise HTTPException(status_code=404, detail="Bilet (Arıza kaydı) bulunamadı.")

    db_message = TicketMessage(
        ticket_id=UUID(ticket_id),
        sender_user_id=current_user.id,
        message=reply_in.message,
        attachment_url=reply_in.attachment_url
    )
    db.add(db_message)

    # Yeni bir mesaj eklendiyse ve bilet geçmişse; 'İşleme Alındı'ya oturt
    if ticket.status == TicketStatus.closed or ticket.status == TicketStatus.open:
        ticket.status = TicketStatus.in_progress

    await db.commit()
    await db.refresh(db_message)

    # §4.2.2-F — Ticket yanıtında kiracıya FCM push bildirim gönder
    if ticket.reporter_user_id:
        from app.core.firebase import send_fcm_notification
        from app.models.users import UserDeviceToken
        # Kiracının FCM token'larını bul
        token_stmt = select(UserDeviceToken).where(
            UserDeviceToken.user_id == ticket.reporter_user_id
        )
        token_result = await db.execute(token_stmt)
        tokens = [t.fcm_token for t in token_result.scalars().all() if t.fcm_token]
        if tokens:
            # Bildirim gönder (asenkron — cevabı bekleme)
            await send_fcm_notification(
                fcm_token=tokens[0],  # İlk token'a gönder
                title=f"📩 Destek Talebinize Yanıt Geldi",
                body=f"{current_user.full_name}: {reply_in.message[:80]}",
                data={
                    "type": "ticket_reply",
                    "ticket_id": ticket_id,
                    "conversation_id": str(ticket_id),
                },
            )

    return db_message

@router.post("/building-logs", response_model=BuildingLogResponse, status_code=status.HTTP_201_CREATED)
async def create_building_log(
    log_in: BuildingLogCreate,
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(deps.get_db),
):
    """
    PRD Şeffaflık Modülü: Ev Lortlarının (Mülk sahiplerinin) ortak görebileceği;
    'Çatı Tamiratı 25.000 TL Tutmuştur, faturası ektedir' şeklinde binalara astığımız sanal şeffaf pano!
    """
    db_log = BuildingOperationLog(
        agency_id=agency_id,
        property_id=log_in.property_id,
        created_by_user_id=current_user.id,
        title=log_in.title,
        description=log_in.description,
        cost=log_in.cost,
        invoice_url=log_in.invoice_url,
        is_reflected_to_finance=log_in.is_reflected_to_finance,
        category=OperationCategory(log_in.category) if log_in.category else OperationCategory.other,
    )
    db.add(db_log)
    await db.flush()  # Get the log ID before committing

    # Eğer mali rapora gider olarak işaretlendiyse, financial_transaction oluştur
    if log_in.is_reflected_to_finance and log_in.cost > 0:
        tx = FinancialTransaction(
            agency_id=agency_id,
            property_id=log_in.property_id,
            type=TransactionType.expense,
            category=TransactionCategory.maintenance,
            amount=log_in.cost,
            currency="TRY",
            transaction_date=datetime.utcnow().date(),
            description=f"[Bina Operasyonu] {log_in.title}",
        )
        db.add(tx)

    await db.commit()
    await db.refresh(db_log)
    return db_log


@router.get("/building-logs", response_model=list[BuildingLogResponse])
async def list_building_logs(
    property_id: UUID | None = None,
    finance_reflected: bool | None = None,
    start_date: date | None = None,  # PRD §4.1.9 — Tarih aralığı filtresi
    end_date: date | None = None,
    limit: int = 50,
    offset: int = 0,
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(deps.get_db),
):
    """Bina operasyon kayıtlarını listeler (Şeffaflık Modülü). Tarih aralığı ve kategori ile filtreleme yapılabilir."""
    query = (
        select(BuildingOperationLog)
        .where(
            BuildingOperationLog.agency_id == agency_id,
            BuildingOperationLog.is_deleted == False,
        )
    )
    if property_id:
        query = query.where(BuildingOperationLog.property_id == property_id)
    if finance_reflected is not None:
        query = query.where(BuildingOperationLog.is_reflected_to_finance == finance_reflected)
    if start_date:
        query = query.where(BuildingOperationLog.operation_date >= start_date)
    if end_date:
        query = query.where(BuildingOperationLog.operation_date <= end_date)

    query = query.order_by(desc(BuildingOperationLog.created_at)).offset(offset).limit(limit)
    result = await db.execute(query)
    logs = result.scalars().all()
    return [BuildingLogResponse.model_validate(log) for log in logs]


@router.get("/building-logs/{log_id}", response_model=BuildingLogResponse)
async def get_building_log(
    log_id: UUID,
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(deps.get_db),
):
    """Tek bina operasyon kaydını getirir."""
    log = await db.get(BuildingOperationLog, log_id)
    if not log or log.agency_id != agency_id or log.is_deleted:
        raise HTTPException(status_code=404, detail="Kayıt bulunamadı")
    return BuildingLogResponse.model_validate(log)


@router.patch("/building-logs/{log_id}", response_model=BuildingLogResponse)
async def update_building_log(
    log_id: UUID,
    update_in: BuildingLogUpdate,
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(deps.get_db),
):
    """Bina operasyon kaydını günceller (maliyeti finansa yansıt vb.)."""
    log = await db.get(BuildingOperationLog, log_id)
    if not log or log.agency_id != agency_id or log.is_deleted:
        raise HTTPException(status_code=404, detail="Kayıt bulunamadı")

    update_data = update_in.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(log, field, value)

    await db.commit()
    await db.refresh(log)
    return BuildingLogResponse.model_validate(log)


@router.delete("/building-logs/{log_id}", status_code=204)
async def delete_building_log(
    log_id: UUID,
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(deps.get_db),
):
    """Bina operasyon kaydını soft-delete olarak siler."""
    log = await db.get(BuildingOperationLog, log_id)
    if not log or log.agency_id != agency_id or log.is_deleted:
        raise HTTPException(status_code=404, detail="Kayıt bulunamadı")
    log.is_deleted = True
    await db.commit()
    return None


# ──────────────────────────────────────────────
# ACTIVITY FEED (PRD §4.1.1-B) — Son İşlemler
# ──────────────────────────────────────────────

@router.get("/activity-feed", response_model=ActivityFeedResponse)
async def get_activity_feed(
    limit: int = 10,
    offset: int = 0,
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(deps.get_db),
):
    """
    PRD §4.1.1-B: Son işlemler kronolojik zaman tüneli.
    Ödeme alındı, destek talebi açıldı, ev sahibi eklendi, yeni daire oluşturuldu vb.
    10'ar paketler halinde pagination ile döner.
    """
    items: List[ActivityFeedItem] = []
    now = datetime.utcnow()

    # 1) Son ödemeler (FinancialTransaction — son 30 gün)
    tx_stmt = (
        select(FinancialTransaction)
        .where(
            FinancialTransaction.agency_id == agency_id,
            FinancialTransaction.is_deleted == False,
        )
        .order_by(desc(FinancialTransaction.transaction_date))
        .limit(20)
    )
    tx_result = await db.execute(tx_stmt)
    transactions = tx_result.scalars().all()
    for tx in transactions:
        cat_label = {
            "rent": "Kira Ödemesi",
            "dues": "Aidat Ödemesi",
            "utility": "Fatura",
            "commission": "Komisyon",
            "maintenance": "Bakım/Gider",
            "other": "Diğer",
        }.get(tx.category.value if hasattr(tx.category, 'value') else str(tx.category), "İşlem")
        items.append(ActivityFeedItem(
            id=str(tx.id),
            type="payment",
            title=cat_label,
            subtitle=f"{tx.amount:,.0f} ₺ — {tx.transaction_date.strftime('%d.%m.%Y')}",
            icon="payments",
            color="success",
            timestamp=tx.transaction_date.isoformat(),
        ))

    # 2) Son açılan biletler
    ticket_stmt = (
        select(SupportTicket)
        .where(SupportTicket.agency_id == agency_id)
        .order_by(desc(SupportTicket.created_at))
        .limit(10)
    )
    ticket_result = await db.execute(ticket_stmt)
    tickets = ticket_result.scalars().all()
    for t in tickets:
        priority_colors = {"high": "error", "medium": "warning", "low": "textBody"}
        items.append(ActivityFeedItem(
            id=str(t.id),
            type="ticket",
            title=f"Bilet: {t.title[:40]}",
            subtitle=t.created_at.strftime('%d.%m.%Y %H:%M'),
            icon="confirmation_number",
            color=priority_colors.get(t.priority.value if hasattr(t.priority, 'value') else "medium", "textBody"),
            timestamp=t.created_at.isoformat(),
        ))

    # 3) Son bina operasyonları
    log_stmt = (
        select(BuildingOperationLog)
        .where(
            BuildingOperationLog.agency_id == agency_id,
            BuildingOperationLog.is_deleted == False,
        )
        .order_by(desc(BuildingOperationLog.created_at))
        .limit(10)
    )
    log_result = await db.execute(log_stmt)
    logs = log_result.scalars().all()
    for log in logs:
        items.append(ActivityFeedItem(
            id=str(log.id),
            type="building_log",
            title=log.title[:40],
            subtitle=f"Maliyet: {log.cost:,.0f} ₺" if log.cost else "Kayıt oluşturuldu",
            icon="engineering",
            color="accent",
            timestamp=log.created_at.isoformat(),
        ))

    # 4) Yeni kiracılar (son eklenen aktif kiracılar)
    tenant_stmt = (
        select(Tenant)
        .options(selectinload(Tenant.user))
        .where(Tenant.agency_id == agency_id, Tenant.status == "active")
        .order_by(desc(Tenant.created_at))
        .limit(10)
    )
    tenant_result = await db.execute(tenant_stmt)
    tenants = tenant_result.scalars().all()
    for t in tenants:
        # Kiracı adı: user.full_name > temp_name > 'İsimsiz'
        tenant_name = 'İsimsiz'
        if t.user and hasattr(t.user, 'full_name') and t.user.full_name:
            tenant_name = t.user.full_name
        elif t.temp_name:
            tenant_name = t.temp_name
        items.append(ActivityFeedItem(
            id=str(t.id),
            type="tenant",
            title=f"Yeni Kiracı: {tenant_name}",
            subtitle=t.created_at.strftime('%d.%m.%Y') if hasattr(t, 'created_at') and t.created_at else "",
            icon="person_add",
            color="success",
            timestamp=t.created_at.isoformat() if hasattr(t, 'created_at') and t.created_at else now.isoformat(),
        ))

    # 5) Son eklenen mülkler (arsa, bina, apartman, müstakil ev, ticari)
    prop_stmt = (
        select(Property)
        .where(
            Property.agency_id == agency_id,
            Property.is_deleted == False,
        )
        .order_by(desc(Property.created_at))
        .limit(10)
    )
    prop_result = await db.execute(prop_stmt)
    props = prop_result.scalars().all()
    type_labels = {
        "apartment_complex": "Apartman",
        "standalone_house": "Müstakil Ev",
        "land": "Arsa",
        "commercial": "Ticari",
    }
    for p in props:
        prop_type = p.type.value if hasattr(p.type, 'value') else str(p.type)
        items.append(ActivityFeedItem(
            id=str(p.id),
            type="property",
            title=f"Yeni Mülk: {p.name or 'İsimsiz'}",
            subtitle=type_labels.get(prop_type, "Mülk"),
            icon="home",
            color="accent",
            timestamp=p.created_at.isoformat() if hasattr(p, 'created_at') and p.created_at else now.isoformat(),
        ))

    # Zamanına göre sırala (en yen üstte)
    items.sort(key=lambda x: x.timestamp, reverse=True)

    # Pagination
    total = len(items)
    paginated = items[offset:offset + limit]

    return ActivityFeedResponse(
        items=paginated,
        total=total,
        has_more=(offset + limit) < total,
    )
