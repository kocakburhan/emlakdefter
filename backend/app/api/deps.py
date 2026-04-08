import os
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import UUID

from app.database import get_db
from app.models.users import User, AgencyStaff
from app.core.firebase import verify_firebase_token

# PRD: Firebase JWT tabanlı kimlik doğrulama (Bearer token)
security_scheme = HTTPBearer(auto_error=False)

FIREBASE_CREDENTIALS_PATH = os.getenv("FIREBASE_CREDENTIALS_PATH", "firebase-adminsdk.json")


async def get_current_user(
    db: AsyncSession = Depends(get_db),
    credentials: HTTPAuthorizationCredentials = Depends(security_scheme)
) -> User:
    """
    Firebase ID Token → Kullanıcı Kimliği Çözümleyici.
    
    PRD Madde 4.1.4-C: Firebase tek kimlik otoritesidir. FastAPI sadece
    Firebase'den gelen JWT'yi okuyarak veriye erişim izni verir.
    
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
    # Önce firebase_uid ile, bulunamazsa phone_number ile ara
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
    """
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
    
    return agency_id
