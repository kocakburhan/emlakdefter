from fastapi import APIRouter, Depends, HTTPException, status
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
