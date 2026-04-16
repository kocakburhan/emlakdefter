from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from typing import List, Optional
from uuid import UUID
from datetime import datetime, date
import uuid

from app.api import deps
from app.models.users import User, AgencyStaff
from app.models.tenants import Tenant, LandlordUnit, ContractStatus
from app.models.properties import Property, PropertyUnit, UnitStatus
from app.models.operations import BuildingOperationLog
from app.models.chat import ChatConversation, ChatMessage
from app.models.finance import FinancialTransaction, PaymentSchedule, PaymentStatus, TransactionType
from app.schemas.landlord import (
    LandlordDashboardKPIs, LandlordPropertySummary, LandlordUnitResponse,
    LandlordTenantPerformance, LandlordOperationItem, LandlordVacantUnit,
    PaymentMonthItem, LandlordInterestRequest, UnitDocumentsResponse,
    UnitDocumentItem,
)

router = APIRouter()


def _build_landlord_units_query(user_id: uuid.UUID, db: AsyncSession):
    """Ev sahibinin tüm birimlerini getirir (join'li)"""
    stmt = (
        select(LandlordUnit)
        .where(LandlordUnit.user_id == user_id)
        .options(
            selectinload(LandlordUnit.unit)
            .selectinload(PropertyUnit.property),
        )
    )
    return stmt


async def _get_landlord_units(user_id: uuid.UUID, db: AsyncSession):
    stmt = _build_landlord_units_query(user_id, db)
    result = await db.execute(stmt)
    return result.scalars().all()


async def _get_tenants_for_units(unit_ids: List[uuid.UUID], db: AsyncSession):
    """Birim ID'lerine göre aktif kiracıları getirir"""
    if not unit_ids:
        return []
    stmt = select(Tenant).where(
        Tenant.unit_id.in_(unit_ids),
        Tenant.is_active == True,
    ).options(selectinload(Tenant.unit).selectinload(PropertyUnit.property))
    result = await db.execute(stmt)
    return result.scalars().all()


# ──────────────────────────────────────────────
# DASHBOARD KPI
# ──────────────────────────────────────────────

@router.get("/dashboard", response_model=LandlordDashboardKPIs)
async def landlord_dashboard(
    current_user: User = Depends(deps.get_current_user),
    db: AsyncSession = Depends(deps.get_db),
):
    """Ev Sahibinin ana paneli — tüm mülklerinin özeti."""
    landlord_units = await _get_landlord_units(current_user.id, db)
    unit_ids = [lu.unit_id for lu in landlord_units]

    # Aktif kiracıları çek
    tenants = await _get_tenants_for_units(unit_ids, db)
    active_tenants = [t for t in tenants if t.is_active]

    occupied = sum(1 for lu in landlord_units if lu.unit.status == UnitStatus.occupied)
    vacant = sum(1 for lu in landlord_units if lu.unit.status == UnitStatus.vacant)
    total_income = sum(t.rent_amount for t in active_tenants if t.rent_amount)
    total_dues = sum(lu.unit.dues_amount for lu in landlord_units if lu.unit.dues_amount)
    total_units = len(landlord_units)
    rate = (occupied / total_units * 100) if total_units > 0 else 0.0

    # §4.3.1-A — Finansal özet: beklenen kira, tahsil edilen, gecikmeli bakiye
    # Bu ayın başı ve sonu
    now = datetime.utcnow()
    month_start = date(now.year, now.month, 1)
    if now.month == 12:
        month_end = date(now.year + 1, 1, 1)
    else:
        month_end = date(now.year, now.month + 1, 1)

    # Beklenen kira: aktif kiracıların aylık kira toplamı
    expected_rent = total_income

    # Tahsil edilen: bu ay işlenmiş ödemeler
    collected_rent = 0
    delayed_balance = 0

    if unit_ids:
        # payment_schedules üzerinden bu ayın tahsilatlarını bul
        ps_stmt = select(PaymentSchedule).where(
            PaymentSchedule.tenant_id.in_([t.id for t in active_tenants]),
            PaymentSchedule.due_date >= month_start,
            PaymentSchedule.due_date < month_end,
        )
        ps_result = await db.execute(ps_stmt)
        schedules = ps_result.scalars().all()

        for ps in schedules:
            if ps.status == PaymentStatus.paid:
                collected_rent += ps.paid_amount if ps.paid_amount else ps.amount
            elif ps.status == PaymentStatus.overdue:
                delayed_balance += ps.amount

    return LandlordDashboardKPIs(
        total_properties=len(set(lu.unit.property_id for lu in landlord_units)),
        total_units=total_units,
        occupied_units=occupied,
        vacant_units=vacant,
        total_monthly_income=total_income,
        total_pending_dues=total_dues,
        active_tenants=len(active_tenants),
        occupancy_rate=round(rate, 1),
        expected_rent=expected_rent,
        collected_rent=collected_rent,
        delayed_balance=delayed_balance,
    )


# ──────────────────────────────────────────────
# PROPERTIES / UNITS
# ──────────────────────────────────────────────

@router.get("/properties", response_model=List[LandlordPropertySummary])
async def landlord_properties(
    current_user: User = Depends(deps.get_current_user),
    db: AsyncSession = Depends(deps.get_db),
):
    """Ev Sahibinin mülklerini ve her mülkteki birim durumlarını listeler."""
    landlord_units = await _get_landlord_units(current_user.id, db)

    # Mülk bazında grupla
    prop_map = {}
    for lu in landlord_units:
        pid = lu.unit.property_id
        if pid not in prop_map:
            prop_map[pid] = {
                'property': lu.unit.property,
                'units': [],
            }
        prop_map[pid]['units'].append(lu)

    summaries = []
    for pid, data in prop_map.items():
        prop: Property = data['property']
        units = data['units']
        owned = len(units)
        occupied = sum(1 for u in units if u.unit.status == UnitStatus.occupied)
        vacant = owned - occupied
        income = sum(
            t.rent_amount for t in (await _get_tenants_for_units([u.unit_id for u in units], db))
            if t.is_active and t.rent_amount
        )
        rate = (occupied / owned * 100) if owned > 0 else 0.0

        summaries.append(LandlordPropertySummary(
            property_id=pid,
            property_name=prop.name,
            address=prop.address,
            total_units=prop.total_units,
            owned_units=owned,
            occupied_units=occupied,
            vacant_units=vacant,
            monthly_income=income,
            occupancy_rate=round(rate, 1),
        ))

    return summaries


@router.get("/units", response_model=List[LandlordUnitResponse])
async def landlord_units(
    current_user: User = Depends(deps.get_current_user),
    db: AsyncSession = Depends(deps.get_db),
):
    """Ev Sahibinin tüm birimlerini detaylı listeler."""
    landlord_units = await _get_landlord_units(current_user.id, db)
    unit_ids = [lu.unit_id for lu in landlord_units]
    tenants = await _get_tenants_for_units(unit_ids, db)
    tenant_map = {t.unit_id: t for t in tenants}

    responses = []
    for lu in landlord_units:
        tenant = tenant_map.get(lu.unit_id)
        responses.append(LandlordUnitResponse(
            id=lu.id,
            unit_id=lu.unit_id,
            property_name=lu.unit.property.name,
            door_number=lu.unit.door_number,
            floor=lu.unit.floor,
            ownership_share=lu.ownership_share,
            rent_amount=tenant.rent_amount if tenant else None,
            tenant_name=tenant.user.full_name if tenant and tenant.user else (tenant.temp_name if tenant else None),
            tenant_phone=tenant.user.phone_number if tenant and tenant.user else (tenant.temp_phone if tenant else None),
            contract_status=tenant.status.value if tenant else "boş",
            is_active=tenant.is_active if tenant else False,
        ))

    return responses


# ──────────────────────────────────────────────
# TENANT PERFORMANCE
# ──────────────────────────────────────────────

@router.get("/tenants", response_model=List[LandlordTenantPerformance])
async def landlord_tenants(
    current_user: User = Depends(deps.get_current_user),
    db: AsyncSession = Depends(deps.get_db),
):
    """Ev Sahibinin kiracılarının performansını listeler."""
    landlord_units = await _get_landlord_units(current_user.id, db)
    unit_ids = [lu.unit_id for lu in landlord_units]
    tenants = await _get_tenants_for_units(unit_ids, db)

    from app.models.finance import FinancialTransaction, PaymentSchedule
    from app.models.operations import TicketStatus

    responses = []
    for t in tenants:
        months = 0
        if t.start_date:
            delta = (date.today() - t.start_date).days
            months = max(1, delta // 30)

        # Gerçek ödeme geçmişini çek
        tx_stmt = select(FinancialTransaction).where(
            FinancialTransaction.tenant_id == t.id,
            FinancialTransaction.type == "income",
        ).order_by(FinancialTransaction.transaction_date)
        tx_res = await db.execute(tx_stmt)
        transactions = tx_res.scalars().all()

        # Son 12 ay için aylık durum oluştur
        today = date.today()
        payment_history = []
        on_time = 0
        late = 0
        missed = 0

        for i in range(min(12, months)):
            target_month = today.month - i
            target_year = today.year
            while target_month <= 0:
                target_month += 12
                target_year -= 1

            # O ay için ödeme takvimini bul
            sched_stmt = select(PaymentSchedule).where(
                PaymentSchedule.tenant_id == t.id,
            )
            sched_res = await db.execute(sched_stmt)
            schedules = sched_res.scalars().all()

            sched_for_month = None
            for s in schedules:
                if s.due_date.month == target_month and s.due_date.year == target_year:
                    sched_for_month = s
                    break

            # İlgili işlem
            tx_for_month = next(
                (tx for tx in transactions
                 if tx.transaction_date.month == target_month
                 and tx.transaction_date.year == target_year),
                None
            )

            paid = tx_for_month.amount if tx_for_month else 0.0
            due = sched_for_month.amount if sched_for_month else float(t.rent_amount or 0)
            due_date = sched_for_month.due_date if sched_for_month else date(target_year, target_month, t.payment_day or 1)
            paid_date = tx_for_month.transaction_date if tx_for_month else None

            if paid >= due:
                if paid_date and paid_date <= due_date:
                    status = "paid_on_time"
                    on_time += 1
                elif paid_date:
                    days_late = (paid_date - due_date).days
                    status = "paid_late"
                    late += 1
                else:
                    status = "paid_on_time"
                    on_time += 1
            elif paid > 0:
                status = "partial"
                late += 1
            else:
                status = "pending"
                missed += 1

            ay_adi = ["Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"]
            payment_history.append(PaymentMonthItem(
                month_label=f"{ay_adi[target_month - 1]} {target_year}",
                year=target_year,
                month=target_month,
                amount=due,
                paid_amount=paid,
                status=status,
                days_late=max(0, (paid_date - due_date).days) if paid_date and paid_date > due_date else 0,
                paid_at=paid_date,
            ))

        payment_history.reverse()  # En eski aydan başla
        score = ((on_time / months) * 100) if months > 0 else 100.0

        responses.append(LandlordTenantPerformance(
            tenant_id=t.id,
            unit_id=t.unit_id,
            property_name=t.unit.property.name if t.unit else "Bilinmeyen",
            door_number=t.unit.door_number if t.unit else "?",
            tenant_name=t.user.full_name if t.user else t.temp_name,
            tenant_phone=t.user.phone_number if t.user else t.temp_phone,
            rent_amount=t.rent_amount,
            payment_day=t.payment_day,
            contract_start=t.start_date,
            contract_end=t.end_date,
            status=t.status.value,
            is_active=t.is_active,
            months_rented=months,
            on_time_payments=on_time,
            late_payments=late,
            missed_payments=missed,
            payment_score=round(score, 1),
            payment_history=payment_history,
            documents=t.documents if t.documents else [],  # ✅ EKLENDI — Sözleşme belgeleri (PRD §4.3.2-C)
        ))

    return responses


# ──────────────────────────────────────────────
# §4.3.3 — Ev Sahibinin Kiracı Biletleri (Ticket Yansıması)
# ──────────────────────────────────────────────

@router.get("/tenant-tickets", response_model=List[dict])
async def landlord_tenant_tickets(
    current_user: User = Depends(deps.get_current_user),
    limit: int = 20,
    db: AsyncSession = Depends(deps.get_db),
):
    """
    Ev Sahibinin mülklerindeki kiracı destek biletlerini getirir — PRD §4.3.3 §A.
    Kiracıların açtığı biletler (Açık / İşlemde / Çözüldü) zaman tünelinde görünür.
    """
    landlord_units = await _get_landlord_units(current_user.id, db)
    unit_ids = [lu.unit_id for lu in landlord_units]
    property_ids = list(set(lu.unit.property_id for lu in landlord_units))

    if not unit_ids:
        return []

    # Tüm kiracıların birimlerini al
    from app.models.operations import SupportTicket, TicketMessage
    stmt = (
        select(SupportTicket)
        .where(
            SupportTicket.unit_id.in_(unit_ids),
        )
        .options(selectinload(SupportTicket.messages))
        .order_by(SupportTicket.created_at.desc())
        .limit(limit)
    )
    result = await db.execute(stmt)
    tickets = result.scalars().all()

    # Mülk isimlerini çöz
    prop_stmt = select(Property).where(Property.id.in_(property_ids))
    prop_res = await db.execute(prop_stmt)
    props = {p.id: p.name for p in prop_res.scalars().all()}

    # Birim numaralarını çöz
    unit_stmt = select(PropertyUnit).where(PropertyUnit.id.in_(unit_ids))
    unit_res = await db.execute(unit_stmt)
    units_map = {u.id: u.door_number for u in unit_res.scalars().all()}

    responses = []
    for t in tickets:
        sorted_msgs = sorted(t.messages, key=lambda m: m.created_at) if t.messages else []
        last_msg = sorted_msgs[-1] if sorted_msgs else None

        # Agent yanıt sayısı
        agent_msgs = [m for m in sorted_msgs if m.sender_user_id != t.reporter_user_id]

        unit_obj = t.unit if hasattr(t, 'unit') and t.unit else None
        prop_name = unit_obj.property.name if unit_obj and unit_obj.property else "Bilinmeyen"
        door_num = units_map.get(t.unit_id, "?")

        responses.append({
            "id": str(t.id),
            "title": t.title,
            "description": t.description,
            "priority": t.priority.value if hasattr(t.priority, 'value') else str(t.priority),
            "status": t.status.value if hasattr(t.status, 'value') else str(t.status),
            "created_at": t.created_at.isoformat(),
            "updated_at": t.updated_at.isoformat(),
            "unit_door": door_num,
            "property_name": prop_name,
            "message_count": len(sorted_msgs),
            "agent_reply_count": len(agent_msgs),
            "last_message": last_msg.content if last_msg else None,
            "last_message_at": last_msg.created_at.isoformat() if last_msg else t.created_at.isoformat(),
            # ✅ EKLENDI — §4.3.3-A: Tam kronolojik thread
            "messages": [
                {
                    "content": m.content,
                    "sender_name": m.sender_name or "Kiracı",
                    "is_agent": m.sender_user_id != t.reporter_user_id,
                    "created_at": m.created_at.isoformat(),
                }
                for m in sorted_msgs[-10:]  # son 10 mesaj (özet)
            ],
        })

    return responses


# ──────────────────────────────────────────────
# OPERATIONS (ŞEFFAFLIK)
# ──────────────────────────────────────────────

@router.get("/operations", response_model=List[LandlordOperationItem])
async def landlord_operations(
    current_user: User = Depends(deps.get_current_user),
    limit: int = 20,
    db: AsyncSession = Depends(deps.get_db),
):
    """Ev Sahibinin mülklerindeki bina operasyonlarını (şeffaflık modülü) getirir."""
    landlord_units = await _get_landlord_units(current_user.id, db)
    property_ids = list(set(lu.unit.property_id for lu in landlord_units))

    if not property_ids:
        return []

    stmt = (
        select(BuildingOperationLog)
        .where(
            BuildingOperationLog.property_id.in_(property_ids),
            BuildingOperationLog.is_deleted == False,
        )
        .order_by(BuildingOperationLog.created_at.desc())
        .limit(limit)
    )
    result = await db.execute(stmt)
    ops = result.scalars().all()

    # Mülk isimlerini çöz
    prop_stmt = select(Property).where(Property.id.in_(property_ids))
    prop_res = await db.execute(prop_stmt)
    props = {p.id: p.name for p in prop_res.scalars().all()}

    return [
        LandlordOperationItem(
            id=op.id,
            property_id=op.property_id,
            property_name=props.get(op.property_id, "Bilinmeyen"),
            title=op.title,
            description=op.description,
            cost=op.cost,
            is_reflected_to_finance=op.is_reflected_to_finance,
            created_at=op.created_at,
        )
        for op in ops
    ]


# ──────────────────────────────────────────────
# §4.3.2-C — DİJİTAL ARŞIV (Salt Okunur Belgeler ve Medya)
# ──────────────────────────────────────────────

@router.get("/units/{unit_id}/documents", response_model=UnitDocumentsResponse)
async def landlord_unit_documents(
    unit_id: UUID,
    current_user: User = Depends(deps.get_current_user),
    db: AsyncSession = Depends(deps.get_db),
):
    """
    Birime ait tüm dijital arşiv belgelerini döner — PRD §4.3.2-C.
    Sözleşme PDF, demirbaş teslim tutanağı ve varsa fotoğraflar.
    Ev Sahibi salt-okunur erişimdedir.
    """
    # Ev sahibinin bu birime erişim yetkisini doğrula
    landlord_units = await _get_landlord_units(current_user.id, db)
    unit_ids = [lu.unit_id for lu in landlord_units]

    if unit_id not in unit_ids:
        raise HTTPException(status_code=403, detail="Bu birime erişim yetkiniz yok.")

    # Birim bilgisi
    lu = next((lu for lu in landlord_units if lu.unit_id == unit_id), None)
    if not lu or not lu.unit:
        raise HTTPException(status_code=404, detail="Birim bulunamadı.")

    unit = lu.unit
    property_name = unit.property.name if unit.property else "Bilinmeyen"
    door_number = unit.door_number

    # Birime ait kiracının belgelerini al
    tenant_stmt = select(Tenant).where(
        Tenant.unit_id == unit_id,
        Tenant.is_active == True,
    )
    tenant_res = await db.execute(tenant_stmt)
    tenant = tenant_res.scalar_one_or_none()

    documents: List[UnitDocumentItem] = []
    contract_url = None

    if tenant:
        contract_url = tenant.contract_document_url

        # documents JSON alanını parse et
        raw_docs = tenant.documents if tenant.documents else []
        for d in raw_docs:
            if isinstance(d, dict):
                documents.append(UnitDocumentItem(
                    name=d.get("name", "Bilinmeyen Belge"),
                    doc_type=d.get("type", "other"),
                    url=d.get("url", ""),
                    uploaded_at=d.get("uploaded_at"),
                ))

    return UnitDocumentsResponse(
        unit_id=unit_id,
        property_name=property_name,
        door_number=door_number,
        contract_document_url=contract_url,
        documents=documents,
    )


# ──────────────────────────────────────────────
# PORTFÖY VITRINI — YATIRIM FIRSATLARI (PRD §4.3.4)
# ──────────────────────────────────────────────

@router.get("/vacant-units", response_model=List[LandlordVacantUnit])
async def landlord_vacant_units(
    property_name: Optional[str] = None,
    min_price: Optional[int] = None,
    max_price: Optional[int] = None,
    current_user: User = Depends(deps.get_current_user),
    db: AsyncSession = Depends(deps.get_db),
):
    """
    Ev Sahibinin kendi mülklerindeki BOŞ birimleri listeler.
    Ev Sahibi ( landlord ) yeni yatırım fırsatlarını burada görür.
    Filtreleme: mülk adı (içeren), min/max kira bedeli.

    NOT: landlord kullanıcılar agency_staff tablosunda değil bu endpoint
    agency_id'yi kendi mülklerinden (landlord_units → property_units → property) alır.
    PRD §4.3.4 — #3 kritik hata düzeltmesi.
    """
    # Ev sahibinin birimlerini getir (bu sorgu agency_staff değil, landlords_units üzerinden çalışır)
    landlord_units = await _get_landlord_units(current_user.id, db)
    if not landlord_units:
        return []

    unit_ids = [lu.unit_id for lu in landlord_units]

    # Boş birimleri getir (sadece bu landlord'un birimleri)
    stmt = (
        select(PropertyUnit)
        .where(
            PropertyUnit.id.in_(unit_ids),
            PropertyUnit.status == UnitStatus.vacant,
        )
        .options(selectinload(PropertyUnit.property))
    )

    # Filtreler
    if property_name:
        stmt = stmt.where(PropertyUnit.property.has(Property.name.ilike(f"%{property_name}%")))
    if min_price is not None:
        stmt = stmt.where(PropertyUnit.rent_price >= min_price)
    if max_price is not None:
        stmt = stmt.where(PropertyUnit.rent_price <= max_price)

    stmt = stmt.order_by(PropertyUnit.vacant_since.desc().nullslast())
    result = await db.execute(stmt)
    units = result.scalars().all()

    return [
        LandlordVacantUnit(
            unit_id=u.id,
            property_id=u.property_id,
            property_name=u.property.name,
            address=u.property.address,
            door_number=u.door_number,
            floor=u.floor,
            rent_price=u.rent_price,
            dues_amount=u.dues_amount,
            features=u.property.features,
        )
        for u in units
    ]


# ──────────────────────────────────────────────
# §4.3.4 — YATIRIM İLGİSİ / BİLGİ AL (Landlord → Agent Chat)
# ──────────────────────────────────────────────

@router.post("/conversations", status_code=201)
async def landlord_send_interest(
    body: LandlordInterestRequest,
    current_user: User = Depends(deps.get_current_user),
    db: AsyncSession = Depends(deps.get_db),
):
    """
    Ev Sahibinin yatırım ilgisi bildirmesi — §4.3.4.
    Emlakçıyla sohbet başlatır ve ilk mesajı gönderir.
    """
    # Ev sahibinin kendi mülk birimlerini al
    landlord_units = await _get_landlord_units(current_user.id, db)
    if not landlord_units:
        raise HTTPException(status_code=403, detail="Bu kullanıcı herhangi bir mülke sahip değil.")

    # İlk mülkün agency_id'sini al
    first_unit = landlord_units[0].unit
    agency_id = first_unit.agency_id

    # agency's first agent user as recipient
    agent_stmt = (
        select(User)
        .join(AgencyStaff, User.id == AgencyStaff.user_id)
        .where(
            AgencyStaff.agency_id == agency_id,
        )
        .limit(1)
    )
    agent_res = await db.execute(agent_stmt)
    agent_user = agent_res.scalar_one_or_none()

    if not agent_user:
        raise HTTPException(status_code=404, detail="Bu emlak ofisinde aktif bir emlakçı bulunamadı.")

    conv_id = uuid.uuid4()
    conversation = ChatConversation(
        id=conv_id,
        agency_id=agency_id,
        agent_user_id=agent_user.id,
        client_user_id=current_user.id,
        property_id=body.property_id,
    )
    db.add(conversation)

    msg_id = uuid.uuid4()
    message = ChatMessage(
        id=msg_id,
        conversation_id=conv_id,
        sender_user_id=current_user.id,
        message=body.initial_message,
    )
    db.add(message)
    await db.commit()

    return {"conversation_id": str(conv_id), "message": "İlginiz emlakçınıza iletildi. En kısa sürede dönüş yapacaktır."}

