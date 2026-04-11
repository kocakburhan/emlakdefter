from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from typing import List, Optional
from uuid import UUID
from datetime import datetime, date
import uuid

from app.api import deps
from app.models.users import User
from app.models.tenants import Tenant, LandlordUnit, ContractStatus
from app.models.properties import Property, PropertyUnit, UnitStatus
from app.models.operations import BuildingOperationLog
from app.schemas.landlord import (
    LandlordDashboardKPIs, LandlordPropertySummary, LandlordUnitResponse,
    LandlordTenantPerformance, LandlordOperationItem, LandlordVacantUnit
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

    return LandlordDashboardKPIs(
        total_properties=len(set(lu.unit.property_id for lu in landlord_units)),
        total_units=total_units,
        occupied_units=occupied,
        vacant_units=vacant,
        total_monthly_income=total_income,
        total_pending_dues=total_dues,
        active_tenants=len(active_tenants),
        occupancy_rate=round(rate, 1),
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

    # Ödeme geçmişi ve performans puanı (basit: sözleşme süresi boyunca aktif = iyi)
    responses = []
    for t in tenants:
        months = 0
        if t.start_date:
            delta = (date.today() - t.start_date).days
            months = max(1, delta // 30)

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
            on_time_payments=months,  # Basit: tüm aylar tam ödenmiş varsay
        ))

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
# PORTFÖY VITRINI — YATIRIM FIRSATLARI (PRD §4.3.4)
# ──────────────────────────────────────────────

@router.get("/vacant-units", response_model=List[LandlordVacantUnit])
async def landlord_vacant_units(
    property_name: Optional[str] = None,
    min_price: Optional[int] = None,
    max_price: Optional[int] = None,
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(deps.get_db),
):
    """
    Emlak ofisinin portföyündeki BOŞ birimleri listeler.
    Ev Sahibi ( landlord ) yeni yatırım fırsatlarını burada görür.
    Filtreleme: mülk adı (içeren), min/max kira bedeli.
    """
    stmt = (
        select(PropertyUnit)
        .where(
            PropertyUnit.agency_id == agency_id,
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
