from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from uuid import UUID
from typing import Optional, List

from app.api import deps
from app.database import get_db
from app.schemas.users import UserResponse, UserCreate, UserUpdate, AdminCreateAgencyBossRequest
from app.schemas.users import UserRole
from app.models.users import User, Agency, StaffRole, AgencyStaff, SubscriptionStatus


router = APIRouter()


def normalize_phone(phone: str) -> str:
    """Normalize phone number to +90 format"""
    digits = ''.join(filter(str.isdigit, phone))
    if digits.startswith('0'):
        digits = digits[1:]
    if not digits.startswith('90'):
        digits = '90' + digits
    return '+' + digits


def is_email(value: str) -> bool:
    return '@' in value and '.' in value.split('@')[-1]


async def require_superadmin(
    current_user: User = Depends(deps.get_current_user),
):
    """Superadmin rolü kontrolü"""
    if current_user.role != UserRole.superadmin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Superadmin erişimi gerekli"
        )
    return current_user


# ──────────────────────────────────────────────
# AGENCY ENDPOINTS
# ──────────────────────────────────────────────

@router.get("/agencies", response_model=List[dict])
async def list_agencies(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_superadmin),
):
    """Tüm emlak ofislerini listele"""
    stmt = select(Agency).where(Agency.is_deleted == False)
    result = await db.execute(stmt)
    agencies = result.scalars().all()

    return [
        {
            "id": str(agency.id),
            "name": agency.name,
            "address": agency.address,
            "subscription_status": agency.subscription_status.value if agency.subscription_status else "trial",
            "created_at": agency.created_at.isoformat() if agency.created_at else None,
        }
        for agency in agencies
    ]


@router.post("/agencies")
async def create_agency_and_boss(
    request: AdminCreateAgencyBossRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_superadmin),
):
    """Yeni emlak ofisi ve ona bağlı patron profili oluşturur"""

    # 1. Emlak Ofisi (Agency) oluştur
    agency = Agency(
        name=request.agency_name,
        address=request.agency_address,
        subscription_status=SubscriptionStatus.trial
    )
    db.add(agency)
    await db.flush()  # DB'de ID oluştursun diye flush atıyoruz

    result_data = {
        "id": str(agency.id),
        "name": agency.name,
        "address": agency.address,
        "subscription_status": agency.subscription_status.value if isinstance(agency.subscription_status, SubscriptionStatus) else str(agency.subscription_status),
        "created_at": agency.created_at.isoformat() if agency.created_at else None,
    }

    # 2. Eğer boss bilgileri varsa, patron profili oluştur
    if request.boss_full_name and (request.boss_email or request.boss_phone_number):
        boss_email = request.boss_email.strip().lower() if request.boss_email else None
        boss_phone = normalize_phone(request.boss_phone_number) if request.boss_phone_number else None

        # Check if email is unique
        if boss_email:
            stmt = select(User).where(User.email == boss_email, User.is_deleted == False)
            res = await db.execute(stmt)
            if res.scalar_one_or_none():
                await db.rollback()
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Bu email adresi sistemde zaten kayıtlı."
                )

        # Check if phone is unique
        if boss_phone:
            stmt = select(User).where(User.phone_number == boss_phone, User.is_deleted == False)
            res = await db.execute(stmt)
            if res.scalar_one_or_none():
                await db.rollback()
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Bu telefon numarası sistemde zaten kayıtlı."
                )

        # Patron (Boss) profili oluştur
        boss = User(
            email=boss_email,
            phone_number=boss_phone,
            full_name=request.boss_full_name,
            role=UserRole.boss,
            agency_id=agency.id,
            password_hash=None,
            status="active"
        )
        db.add(boss)
        await db.flush()

        # Patronun AgencyStaff yetki eşleştirmesini yapalım
        agency_staff = AgencyStaff(
            user_id=boss.id,
            agency_id=agency.id,
            role=StaffRole.boss
        )
        db.add(agency_staff)

        result_data["boss"] = {
            "id": str(boss.id),
            "full_name": boss.full_name,
            "email": boss.email,
            "phone_number": boss.phone_number,
        }

    await db.commit()
    return result_data


@router.get("/agencies/{agency_id}")
async def get_agency(
    agency_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_superadmin),
):
    """Ofis detayını getir"""
    stmt = select(Agency).where(Agency.id == agency_id, Agency.is_deleted == False)
    result = await db.execute(stmt)
    agency = result.scalar_one_or_none()

    if not agency:
        raise HTTPException(status_code=404, detail="Ofis bulunamadı")

    return {
        "id": str(agency.id),
        "name": agency.name,
        "address": agency.address,
        "subscription_status": agency.subscription_status.value if agency.subscription_status else "trial",
        "created_at": agency.created_at.isoformat() if agency.created_at else None,
    }


@router.put("/agencies/{agency_id}")
async def update_agency(
    agency_id: UUID,
    name: Optional[str] = None,
    address: Optional[str] = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_superadmin),
):
    """Ofis bilgilerini güncelle"""
    stmt = select(Agency).where(Agency.id == agency_id, Agency.is_deleted == False)
    result = await db.execute(stmt)
    agency = result.scalar_one_or_none()

    if not agency:
        raise HTTPException(status_code=404, detail="Ofis bulunamadı")

    if name is not None:
        agency.name = name
    if address is not None:
        agency.address = address

    await db.commit()
    await db.refresh(agency)

    return {
        "id": str(agency.id),
        "name": agency.name,
        "address": agency.address,
        "subscription_status": agency.subscription_status.value if agency.subscription_status else "trial",
        "created_at": agency.created_at.isoformat() if agency.created_at else None,
    }


@router.delete("/agencies/{agency_id}")
async def delete_agency(
    agency_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_superadmin),
):
    """Ofisi sil (soft delete)"""
    stmt = select(Agency).where(Agency.id == agency_id, Agency.is_deleted == False)
    result = await db.execute(stmt)
    agency = result.scalar_one_or_none()

    if not agency:
        raise HTTPException(status_code=404, detail="Ofis bulunamadı")

    agency.is_deleted = True
    agency.deleted_at = datetime.utcnow()
    await db.commit()

    return {"message": "Ofis silindi"}


# ──────────────────────────────────────────────
# USER ENDPOINTS (Admin - Boss/Patron oluşturma)
# ──────────────────────────────────────────────

@router.get("/users", response_model=List[UserResponse])
async def list_users(
    role: Optional[str] = None,
    agency_id: Optional[UUID] = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_superadmin),
):
    """Tüm kullanıcıları listele (filtreleme ile)"""
    stmt = select(User).where(User.is_deleted == False)

    if role:
        stmt = stmt.where(User.role == UserRole(role))
    if agency_id:
        stmt = stmt.where(User.agency_id == agency_id)

    stmt = stmt.order_by(User.created_at.desc())
    result = await db.execute(stmt)
    users = result.scalars().all()

    return [
        UserResponse(
            id=user.id,
            email=user.email,
            phone_number=user.phone_number,
            full_name=user.full_name,
            role=user.role,
            status=user.status,
            agency_id=user.agency_id,
            created_at=user.created_at,
            last_login_at=user.last_login_at,
        )
        for user in users
    ]


@router.post("/users", response_model=UserResponse)
async def create_user(
    user_in: UserCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_superadmin),
):
    """Yeni patron (boss) oluştur - Admin tarafından"""
    # Validation: en az email veya telefon gerekli
    if not user_in.email and not user_in.phone_number:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email veya telefon numarası en az biri girilmelidir"
        )

    # Email unique kontrolü
    if user_in.email:
        stmt = select(User).where(User.email == user_in.email.lower(), User.is_deleted == False)
        result = await db.execute(stmt)
        existing = result.scalar_one_or_none()
        if existing:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Bu email adresi sistemde zaten kayıtlı"
            )

    # Telefon unique kontrolü
    if user_in.phone_number:
        normalized_phone = normalize_phone(user_in.phone_number)
        stmt = select(User).where(User.phone_number == normalized_phone, User.is_deleted == False)
        result = await db.execute(stmt)
        existing = result.scalar_one_or_none()
        if existing:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Bu telefon numarası sistemde zaten kayıtlı"
            )

    # Boss veya employee rolü kontrolü
    if user_in.role not in [UserRole.boss, UserRole.employee]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Sadece boss veya employee rolü atanabilir"
        )

    # User oluştur
    user = User(
        email=user_in.email.lower() if user_in.email else None,
        phone_number=normalize_phone(user_in.phone_number) if user_in.phone_number else None,
        full_name=user_in.full_name,
        role=user_in.role,
        status="pending",  # İlk giriş bekleniyor
        agency_id=user_in.agency_id,
        password_hash=None,  # Şifre belirlenmemiş
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)

    # Eğer boss ise ve agency_id verildiyse AgencyStaff kaydı oluştur
    if user_in.role == UserRole.boss and user_in.agency_id:
        pass # Artık AgencyStaff kullanılmıyor, User tablosundaki agency_id yeterli

    return UserResponse(
        id=user.id,
        email=user.email,
        phone_number=user.phone_number,
        full_name=user.full_name,
        role=user.role,
        status=user.status,
        agency_id=user.agency_id,
        created_at=user.created_at,
        last_login_at=user.last_login_at,
    )


@router.get("/users/{user_id}", response_model=UserResponse)
async def get_user(
    user_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_superadmin),
):
    """Kullanıcı detayını getir"""
    stmt = select(User).where(User.id == user_id, User.is_deleted == False)
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(status_code=404, detail="Kullanıcı bulunamadı")

    return UserResponse(
        id=user.id,
        email=user.email,
        phone_number=user.phone_number,
        full_name=user.full_name,
        role=user.role,
        status=user.status,
        agency_id=user.agency_id,
        created_at=user.created_at,
        last_login_at=user.last_login_at,
    )


@router.put("/users/{user_id}", response_model=UserResponse)
async def update_user(
    user_id: UUID,
    user_in: UserUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_superadmin),
):
    """Kullanıcı bilgilerini güncelle"""
    stmt = select(User).where(User.id == user_id, User.is_deleted == False)
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(status_code=404, detail="Kullanıcı bulunamadı")

    # Email unique kontrolü
    if user_in.email is not None and user_in.email != user.email:
        stmt = select(User).where(User.email == user_in.email.lower(), User.is_deleted == False, User.id != user_id)
        result = await db.execute(stmt)
        existing = result.scalar_one_or_none()
        if existing:
            raise HTTPException(status_code=400, detail="Bu email adresi başka kullanıcıda kayıtlı")
        user.email = user_in.email.lower()

    # Telefon unique kontrolü
    if user_in.phone_number is not None and user_in.phone_number != user.phone_number:
        normalized_phone = normalize_phone(user_in.phone_number)
        stmt = select(User).where(User.phone_number == normalized_phone, User.is_deleted == False, User.id != user_id)
        result = await db.execute(stmt)
        existing = result.scalar_one_or_none()
        if existing:
            raise HTTPException(status_code=400, detail="Bu telefon numarası başka kullanıcıda kayıtlı")
        user.phone_number = normalized_phone

    if user_in.full_name is not None:
        user.full_name = user_in.full_name

    if user_in.status is not None:
        user.status = user_in.status

    await db.commit()
    await db.refresh(user)

    return UserResponse(
        id=user.id,
        email=user.email,
        phone_number=user.phone_number,
        full_name=user.full_name,
        role=user.role,
        status=user.status,
        agency_id=user.agency_id,
        created_at=user.created_at,
        last_login_at=user.last_login_at,
    )


@router.delete("/users/{user_id}")
async def delete_user(
    user_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_superadmin),
):
    """Kullanıcıyı sil (soft delete)"""
    stmt = select(User).where(User.id == user_id, User.is_deleted == False)
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(status_code=404, detail="Kullanıcı bulunamadı")

    user.is_deleted = True
    user.deleted_at = datetime.utcnow()
    await db.commit()

    return {"message": "Kullanıcı silindi"}


@router.post("/users/{user_id}/deactivate")
async def deactivate_user(
    user_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_superadmin),
):
    """Kullanıcıyı pasife al"""
    stmt = select(User).where(User.id == user_id, User.is_deleted == False)
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(status_code=404, detail="Kullanıcı bulunamadı")

    user.status = "inactive"
    await db.commit()

    return {"message": "Kullanıcı pasife alındı"}


# ──────────────────────────────────────────────
# AGENCY USERS (Boss + Employees) - İç içe listeleme
# ──────────────────────────────────────────────

@router.get("/agencies/{agency_id}/users", response_model=List[UserResponse])
async def get_agency_users(
    agency_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_superadmin),
):
    """Ofise bağlı tüm kullanıcıları listele"""
    stmt = select(User).where(
        User.agency_id == agency_id,
        User.is_deleted == False
    ).order_by(User.created_at.desc())
    result = await db.execute(stmt)
    users = result.scalars().all()

    return [
        UserResponse(
            id=user.id,
            email=user.email,
            phone_number=user.phone_number,
            full_name=user.full_name,
            role=user.role,
            status=user.status,
            agency_id=user.agency_id,
            created_at=user.created_at,
            last_login_at=user.last_login_at,
        )
        for user in users
    ]