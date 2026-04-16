import os
from dotenv import load_dotenv

# .env yükle (DEV_MODE, DEV_AGENCY_ID vb. için) — import'tan ÖNCE olmalı
load_dotenv()

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import UUID
from dataclasses import dataclass
import enum

from app.database import get_db
from app.models.users import User, AgencyStaff, GlobalUserRole
from app.core.firebase import verify_firebase_token
from app.core.security import create_invitation_token, create_access_token
from app.core.firebase import verify_access_token
from app.core.rls import set_rls_context

# PRD: Firebase JWT tabanlı kimlik doğrulama (Bearer token)
security_scheme = HTTPBearer(auto_error=False)

FIREBASE_CREDENTIALS_PATH = os.getenv("FIREBASE_CREDENTIALS_PATH", "firebase-adminsdk.json")
DEV_MODE = os.getenv("DEV_MODE", "false").lower() == "true"
DEV_AGENCY_ID = os.getenv("DEV_AGENCY_ID", "00000000-0000-0000-0000-000000000001")


@dataclass
class DevUser:
    """Geliştirme modunda auth bypass için sahte kullanıcı."""
    id: UUID
    phone_number: str
    role: enum.Enum
    status: str


async def get_current_user(
    db: AsyncSession = Depends(get_db),
    credentials: HTTPAuthorizationCredentials = Depends(security_scheme)
) -> User:
    """
    Firebase ID Token → Kullanıcı Kimliği Çözümleyici.

    PRD Madde 4.1.4-C: Firebase tek kimlik otoritesidir. FastAPI sadece
    Firebase'den gelen JWT'yi okuyarak veriye erişim izni verir.

    Email/şifre ile üretilen basit access token'ları da kabul eder (DEV bypass değil,
    gerçek email/şifre auth için).

    Geliştirme modunda (firebase-adminsdk.json yoksa) mock bypass aktif olur.
    """
    # --- Token Kontrolü ---
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Yetkilendirme başlığı (Authorization header) eksik.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = credentials.credentials

    # --- DEV MODE BYPASS ---
    if DEV_MODE and token == "dev_token":
        return DevUser(
            id=UUID("00000000-0000-0000-0000-000000000001"),
            phone_number="+905551234567",
            role=GlobalUserRole.standard,
            status="active",
        )

    # --- Basit Access Token (Email/Şifre ile üretilen) Doğrulama ---
    # Önce access token olarak dene — başarırsa Firebase'e gitmeden kullanıcıyı bul
    try:
        claims = verify_access_token(token)
        user_id = claims.get("sub")
        if user_id:
            stmt = select(User).where(User.id == UUID(user_id))
            result = await db.execute(stmt)
            user = result.scalar_one_or_none()
            if user and user.status == "active":
                return user
    except (HTTPException, ValueError):
        pass  # Access token değilse Firebase ile dene

    # --- Firebase Token Doğrulama ---
    firebase_payload = await verify_firebase_token(token)
    phone_number = firebase_payload.get("phone_number")
    firebase_uid = firebase_payload.get("uid")

    if not firebase_uid:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Firebase kimliğinde UID bilgisi bulunamadı.",
        )

    # --- Veritabanında Kullanıcıyı Bul ---
    # firebase_uid ile kullanıcıyı bul (PRIMARY KEY)
    # firebase_uid henüz set edilmemisse phone_number ile ara (geriye uyumluluk)
    stmt = select(User).where(User.firebase_uid == firebase_uid)
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    # Geriye uyumluluk: firebase_uid set edilmemis kullanıcılar icin
    if user is None:
        stmt = select(User).where(User.phone_number == phone_number)
        result = await db.execute(stmt)
        user = result.scalar_one_or_none()

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Sisteme kayıtlı kullanıcı bulunamadı. Önce /auth/login ile giriş yapın.",
        )

    if user.status != "active":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Kullanıcı hesabı askıya alınmış (inactive).",
        )

    return user


async def get_current_user_agency_id(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
) -> UUID:
    """
    Oturumdaki kullanıcının bağlı olduğu emlak ofisinin (agency) ID'sini çözer.

    PRD Madde 1.3: Multi-Tenancy — Her isteğin agency_id'si kontrol altında olmalı.
    Kullanıcı birden fazla ofiste çalışabilir; ilk aktif bağlantısı kullanılır.

    NOT: Bu fonksiyon aynı zamanda PostgreSQL RLS context'ini set eder.
    Böylece veritabanı seviyesinde satır bazlı izolasyon sağlanır.
    """
    # DEV MODE BYPASS
    if DEV_MODE and isinstance(current_user, DevUser):
        agency_id = UUID(DEV_AGENCY_ID)
        await set_rls_context(db, agency_id)
        return agency_id

    stmt = select(AgencyStaff.agency_id).where(
        AgencyStaff.user_id == current_user.id
    )
    result = await db.execute(stmt)
    agency_id = result.scalar_one_or_none()

    if agency_id is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Bu kullanıcı herhangi bir emlak ofisine (ajansa) bağlı değil.",
        )

    # RLS context'ini set et — veritabanı seviyesinde izolasyonu aktif et
    await set_rls_context(db, agency_id)

    return agency_id


async def get_current_user_agency_role(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    agency_id: UUID = Depends(get_current_user_agency_id)
) -> str:
    """
    Oturumdaki kullanıcının ofis içindeki rolünü döner (admin / agent).
    PRD §4.1.10: BI Analytics'e sadece Admin rolü erişebilir.
    """
    # DEV MODE BYPASS — her zaman admin
    if DEV_MODE and isinstance(current_user, DevUser):
        return "admin"

    stmt = select(AgencyStaff.role).where(
        AgencyStaff.user_id == current_user.id,
        AgencyStaff.agency_id == agency_id,
    )
    result = await db.execute(stmt)
    role = result.scalar_one_or_none()
    return role if role else "agent"
