from fastapi import APIRouter, Body, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from typing import List
from uuid import UUID

from app.api import deps
from app.database import get_db
from app.models.users import User
from app.models.properties import Property, PropertyUnit
from app.schemas.properties import PropertyCreate, PropertyResponse, PropertyWithUnitsResponse, PropertyUnitResponse, PropertyUnitUpdate
from app.services.property_service import create_property_with_autonomous_units

router = APIRouter()

@router.post("/", response_model=PropertyResponse, status_code=status.HTTP_201_CREATED)
async def create_property(
    property_in: PropertyCreate,
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Sisteme yepyeni bir Apartman (veya Arsa/Müstakil) ekler.
    Tetiklenen Otonom üretim motoru; girilen Pydantic formundaki kat ve oda limitlerine göre 
    kalıtımsal/miras alınmış alt daireleri otomatik olarak asenkron basar.
    
    PRD Madde 4.1.2-B: Çoklu Birim Otonom Üretim Motoru
    Agency ID artık oturumdaki kullanıcıdan otomatik çözümleniyor.
    """
    new_prop = await create_property_with_autonomous_units(db, str(agency_id), property_in)
    return new_prop

@router.get("/", response_model=List[PropertyResponse])
async def list_properties(
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Emlakçının portföyündeki Apartman listesini güvenle, diğer ajansları görmeden filtreleyen endpoint.
    PRD Madde 1.3: Multi-Tenancy — agency_id artık oturumdaki kullanıcıdan otomatik çözümleniyor.
    """
    stmt = select(Property).where(
        Property.agency_id == agency_id,
        Property.is_deleted == False
    ).order_by(Property.created_at.desc())
    result = await db.execute(stmt)
    properties = result.scalars().all()
    return properties

@router.get("/{property_id}", response_model=PropertyWithUnitsResponse)
async def get_property_details(
    property_id: str,
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Otonom üretilmiş Apartmana tıklayıp detay sayfasına inildiğinde; 
    binadaki Boş/Dolu kapı numaralarının ve daire aidatlarının sıralandığı JSON dökümü.
    """
    stmt = (
        select(Property)
        .where(
            Property.id == UUID(property_id), 
            Property.agency_id == agency_id,
            Property.is_deleted == False
        )
        .options(selectinload(Property.units))
    )
    result = await db.execute(stmt)
    prop = result.scalar_one_or_none()
    
    if not prop:
        raise HTTPException(
            status_code=404,
            detail="Sistemde bu mülk bulunamadı veya bu ofis portföyüne ait değil."
        )

    return prop


@router.get("/{property_id}/units/{unit_id}", response_model=PropertyUnitResponse)
async def get_unit_details(
    property_id: str,
    unit_id: str,
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Daire detayını getirir (PRD §4.1.3).
    Kira bedeli, aidat, kat, kapı numarası, durum bilgisi döner.
    """
    # Önce property'nin bu agency'ye ait olduğunu doğrula
    prop_stmt = select(Property).where(
        Property.id == UUID(property_id),
        Property.agency_id == agency_id,
        Property.is_deleted == False
    )
    prop_result = await db.execute(prop_stmt)
    prop = prop_result.scalar_one_or_none()

    if not prop:
        raise HTTPException(status_code=404, detail="Mülk bulunamadı veya erişim yetkiniz yok.")

    # Şimdi birimi getir
    unit_stmt = select(PropertyUnit).where(
        PropertyUnit.id == UUID(unit_id),
        PropertyUnit.property_id == UUID(property_id),
        PropertyUnit.agency_id == agency_id
    )
    unit_result = await db.execute(unit_stmt)
    unit = unit_result.scalar_one_or_none()

    if not unit:
        raise HTTPException(status_code=404, detail="Birim bulunamadı.")

    return unit


@router.patch("/{property_id}/units/{unit_id}", response_model=PropertyUnitResponse)
async def update_unit(
    property_id: str,
    unit_id: str,
    unit_in: PropertyUnitUpdate,
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Daire bilgilerini günceller (PRD §4.1.3).
    Kira bedeli, aidat, kat, kapı numarası ve durum güncellenebilir.
    """
    # Önce property'nin bu agency'ye ait olduğunu doğrula
    prop_stmt = select(Property).where(
        Property.id == UUID(property_id),
        Property.agency_id == agency_id,
        Property.is_deleted == False
    )
    prop_result = await db.execute(prop_stmt)
    prop = prop_result.scalar_one_or_none()

    if not prop:
        raise HTTPException(status_code=404, detail="Mülk bulunamadı veya erişim yetkiniz yok.")

    # Birimi getir
    unit_stmt = select(PropertyUnit).where(
        PropertyUnit.id == UUID(unit_id),
        PropertyUnit.property_id == UUID(property_id),
        PropertyUnit.agency_id == agency_id
    )
    unit_result = await db.execute(unit_stmt)
    unit = unit_result.scalar_one_or_none()

    if not unit:
        raise HTTPException(status_code=404, detail="Birim bulunamadı.")

    # Güncelleme yapılacak alanları uygula
    update_data = unit_in.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(unit, field, value)

    await db.commit()
    await db.refresh(unit)

    return unit


@router.post("/{property_id}/units", status_code=status.HTTP_201_CREATED)
async def add_single_unit(
    property_id: str,
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(get_db),
    door_number: str = Body(...),
    floor: str = Body("0"),
    dues_amount: int = Body(0),
):
    """
    PRD §4.1.2-C: Tekil Daire Ekle — Otomatik üretim dışında kalan
    ekstra bölümlerin manuel eklenmesini sağlar.
    """
    # Property kontrolü
    prop_stmt = select(Property).where(
        Property.id == UUID(property_id),
        Property.agency_id == agency_id,
        Property.is_deleted == False
    )
    prop_result = await db.execute(prop_stmt)
    prop = prop_result.scalar_one_or_none()
    if not prop:
        raise HTTPException(status_code=404, detail="Mülk bulunamadı.")

    new_unit = PropertyUnit(
        agency_id=agency_id,
        property_id=UUID(property_id),
        door_number=door_number,
        floor=floor,
        status=UnitStatus.vacant,
        dues_amount=dues_amount,
    )
    db.add(new_unit)
    await db.commit()
    await db.refresh(new_unit)

    return {
        "id": str(new_unit.id),
        "door_number": new_unit.door_number,
        "floor": new_unit.floor,
        "status": new_unit.status.value,
        "dues_amount": new_unit.dues_amount,
    }


@router.post("/{property_id}/broadcast-notification")
async def send_property_notification(
    property_id: str,
    title: str,
    body: str,
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(get_db),
):
    """
    PRD §4.1.2-C: Toplu Bildirim Gönder.
    Apartmandaki tüm aktif kiracıların FCM token'larına
    Push Notification gönderir.
    """
    from app.models.tenants import Tenant, ContractStatus
    from app.models.users import UserDeviceToken
    from app.core.firebase import send_fcm_notification_to_tokens

    # Property kontrolü
    prop_stmt = select(Property).where(
        Property.id == UUID(property_id),
        Property.agency_id == agency_id,
        Property.is_deleted == False
    )
    prop_result = await db.execute(prop_stmt)
    prop = prop_result.scalar_one_or_none()
    if not prop:
        raise HTTPException(status_code=404, detail="Mülk bulunamadı.")

    # Bu mülke bağlı tüm aktif kiracıları bul
    tenant_stmt = (
        select(Tenant)
        .join(PropertyUnit, Tenant.unit_id == PropertyUnit.id)
        .where(
            PropertyUnit.property_id == UUID(property_id),
            Tenant.status == ContractStatus.active,
        )
    )
    tenant_result = await db.execute(tenant_stmt)
    tenants = tenant_result.scalars().all()

    sent = 0
    for tenant in tenants:
        token_stmt = select(UserDeviceToken.fcm_token).where(
            UserDeviceToken.user_id == tenant.user_id
        )
        token_result = await db.execute(token_stmt)
        tokens = [row[0] for row in token_result.fetchall()]
        if tokens:
            await send_fcm_notification_to_tokens(
                tokens,
                title,
                body,
                data={"type": "property_announcement", "property_id": property_id},
            )
            sent += 1

    return {
        "success": True,
        "message": f"Bildirim {sent} kiracıya gönderildi.",
        "sent_count": sent,
    }
