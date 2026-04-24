from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import UUID
from typing import List

from app.api import deps
from app.database import get_db
from app.schemas.users import UserResponse, CreateEmployeeRequest, UserRole
from app.models.users import User, StaffRole, AgencyStaff


router = APIRouter()


def normalize_phone(phone: str) -> str:
    """Normalize phone number to +90 format"""
    digits = ''.join(filter(str.isdigit, phone))
    if digits.startswith('0'):
        digits = digits[1:]
    if not digits.startswith('90'):
        digits = '90' + digits
    return '+' + digits


async def require_boss_or_employee(
    current_user: User = Depends(deps.get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Boss veya employee rolü kontrolü"""
    # Superadmin her zaman erişebilir
    if current_user.role == UserRole.superadmin:
        return current_user

    # Boss veya employee kontrolü
    if current_user.role not in [UserRole.boss, UserRole.employee]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Bu işlem için boss veya employee yetkisi gerekli"
        )
    return current_user


@router.post("/employees", response_model=UserResponse)
async def create_employee(
    request: CreateEmployeeRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(deps.get_current_user),
):
    """
    Yeni çalışan ekle (Sadece Boss rolü erişebilir).
    Çalışan patronun agency_id'sine bağlanır.
    """
    
    if current_user.role != UserRole.boss and current_user.role != UserRole.superadmin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Sadece patron (boss) yeni çalışan ekleyebilir."
        )

    # Agency ID'yi current_user'dan al
    agency_id = current_user.agency_id
    if not agency_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Ofis bilgisi bulunamadı."
        )

    # Validation: en az email veya telefon gerekli
    if not request.email and not request.phone_number:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email veya telefon numarası en az biri girilmelidir."
        )

    # Email unique kontrolü
    if request.email:
        email = request.email.strip().lower()
        stmt = select(User).where(User.email == email, User.is_deleted == False)
        result = await db.execute(stmt)
        if result.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Bu email adresi sistemde zaten kayıtlı."
            )
    else:
        email = None

    # Telefon unique kontrolü
    if request.phone_number:
        normalized_phone = normalize_phone(request.phone_number)
        stmt = select(User).where(User.phone_number == normalized_phone, User.is_deleted == False)
        result = await db.execute(stmt)
        if result.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Bu telefon numarası sistemde zaten kayıtlı."
            )
    else:
        normalized_phone = None

    # User oluştur
    user = User(
        email=email,
        phone_number=normalized_phone,
        full_name=request.full_name.strip(),
        role=UserRole.employee,
        status="active",
        agency_id=agency_id,
        password_hash=None,  # İlk giriş bekleniyor
    )
    db.add(user)
    await db.flush()
    
    # AgencyStaff yetki tablosunda da tanımlayalım
    agency_staff = AgencyStaff(
        user_id=user.id,
        agency_id=agency_id,
        role=StaffRole.employee
    )
    db.add(agency_staff)
    
    await db.commit()
    await db.refresh(user)

    return UserResponse.model_validate(user)


@router.get("/employees", response_model=List[UserResponse])
async def list_employees(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_boss_or_employee),
):
    """
    Ofisteki tüm çalışanları listele (Boss ve employee erişebilir).
    Boss ve employee'leri gösterir.
    """
    agency_id = current_user.agency_id
    if not agency_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Ofis bilgisi bulunamadı"
        )

    stmt = select(User).where(
        User.agency_id == agency_id,
        User.is_deleted == False,
        User.role.in_([UserRole.boss, UserRole.employee])
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


@router.get("/employees/{user_id}", response_model=UserResponse)
async def get_employee(
    user_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_boss_or_employee),
):
    """Çalışan detayını getir"""
    agency_id = current_user.agency_id
    if not agency_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Ofis bilgisi bulunamadı"
        )

    stmt = select(User).where(
        User.id == user_id,
        User.agency_id == agency_id,
        User.is_deleted == False
    )
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(status_code=404, detail="Çalışan bulunamadı")

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


from pydantic import BaseModel

class UpdateEmployeeRequest(BaseModel):
    full_name: str | None = None
    email: str | None = None
    phone_number: str | None = None

@router.put("/employees/{user_id}", response_model=UserResponse)
async def update_employee(
    user_id: UUID,
    request: UpdateEmployeeRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_boss_or_employee),
):
    """Çalışan bilgilerini güncelle"""
    agency_id = current_user.agency_id
    if not agency_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Ofis bilgisi bulunamadı"
        )

    stmt = select(User).where(
        User.id == user_id,
        User.agency_id == agency_id,
        User.is_deleted == False
    )
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(status_code=404, detail="Çalışan bulunamadı")

    # Email unique kontrolü
    if request.email is not None and request.email != user.email:
        stmt = select(User).where(User.email == request.email.lower(), User.is_deleted == False, User.id != user_id)
        result = await db.execute(stmt)
        existing = result.scalar_one_or_none()
        if existing:
            raise HTTPException(status_code=400, detail="Bu email adresi başka kullanıcıda kayıtlı")
        user.email = request.email.lower()

    # Telefon unique kontrolü
    if request.phone_number is not None and request.phone_number != user.phone_number:
        normalized_phone = normalize_phone(request.phone_number)
        stmt = select(User).where(User.phone_number == normalized_phone, User.is_deleted == False, User.id != user_id)
        result = await db.execute(stmt)
        existing = result.scalar_one_or_none()
        if existing:
            raise HTTPException(status_code=400, detail="Bu telefon numarası başka kullanıcıda kayıtlı")
        user.phone_number = normalized_phone

    if request.full_name is not None:
        user.full_name = request.full_name

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


@router.post("/employees/{user_id}/deactivate")
async def deactivate_employee(
    user_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_boss_or_employee),
):
    """Çalışanı pasife al"""
    agency_id = current_user.agency_id
    if not agency_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Ofis bilgisi bulunamadı"
        )

    stmt = select(User).where(
        User.id == user_id,
        User.agency_id == agency_id,
        User.is_deleted == False
    )
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(status_code=404, detail="Çalışan bulunamadı")

    user.status = "inactive"
    await db.commit()

    return {"message": "Çalışan pasife alındı"}


@router.delete("/employees/{user_id}")
async def delete_employee(
    user_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_boss_or_employee),
):
    """Çalışanı sil (soft delete)"""
    agency_id = current_user.agency_id
    if not agency_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Ofis bilgisi bulunamadı"
        )

    stmt = select(User).where(
        User.id == user_id,
        User.agency_id == agency_id,
        User.is_deleted == False
    )
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(status_code=404, detail="Çalışan bulunamadı")

    # Boss kendini silemez
    if user.role == UserRole.boss:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Patron silinemez"
        )

    user.is_deleted = True
    user.deleted_at = datetime.utcnow()
    await db.commit()

    return {"message": "Çalışan silindi"}