from datetime import timedelta, datetime
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.api import deps
from app.database import get_db
from app.schemas.users import UserLogin, LoginResponse, UserResponse, InviteCreate, InviteResponse
from app.models.users import User, Invitation, AgencyStaff, GlobalUserRole
from app.core.firebase import verify_firebase_token
from app.core.security import create_invitation_token
from jose import jwt, JWTError
import uuid
import os

SECRET_KEY = os.getenv("SECRET_KEY", "b2c9a8db422e..._override_in_env_")
ALGORITHM = os.getenv("ALGORITHM", "HS256")

router = APIRouter()

@router.post("/invite", response_model=InviteResponse)
async def create_invite(
    invite_in: InviteCreate,
    current_user: User = Depends(deps.get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Emlakçının kiracı veya ev sahipleri için Akıllı Davet linki yaratması.
    Bu servis JWT kullanıp bunu 'invitations' tablosuna şifreli string (Token) olarak gömer.
    """
    
    # 72 saat geçerli JWT davet formu oluştur (Payload)
    raw_payload = {
        "agency_id": str(invite_in.agency_id),
        "target_role": invite_in.target_role,
        "related_entity_id": str(invite_in.related_entity_id) if invite_in.related_entity_id else None
    }
    jwt_token = create_invitation_token(raw_payload, timedelta(hours=72))
    
    # Veritabanına Kaydet (Eğer çalınırsa veritabanından kolayca silinip engellenebilir)
    db_invite = Invitation(
        agency_id=invite_in.agency_id,
        token=jwt_token,
        target_role=invite_in.target_role,
        related_entity_id=invite_in.related_entity_id,
        expires_at=datetime.utcnow() + timedelta(hours=72)
    )
    db.add(db_invite)
    await db.commit()
    
    # İstemcinin (Flutter) Web Platformuna fırlatılması için Link Üretimi
    FRONTEND_URL = os.getenv("FRONTEND_URL", "https://app.emlakdefteri.com")
    invite_url = f"{FRONTEND_URL}/register?t={jwt_token}"
    
    return InviteResponse(
        success=True,
        invite_url=invite_url,
        token=jwt_token,
        expires_at=db_invite.expires_at
    )

@router.post("/login", response_model=LoginResponse)
async def login_with_firebase(
    login_in: UserLogin,
    db: AsyncSession = Depends(get_db)
):
    """
    Firebase OTP doğrulamasını geçtikten sonra Mobil/Web uygulamasından atılan Login/Register isteği.
    
    PRD Madde 4.1.4-C: Firebase tek kimlik otoritesidir.
    Bu endpoint Firebase token'ı doğrular, kullanıcıyı bulur/oluşturur ve profil bilgisini döner.
    Backend artık kendi JWT üretmez — tüm sonraki isteklerde Firebase token kullanılır.
    """
    # 1. Firebase Sunucusunda Token'ı Güvenli Yoldan Doğrula
    firebase_payload = await verify_firebase_token(login_in.firebase_id_token)
    phone_number = firebase_payload.get("phone_number")
    firebase_uid = firebase_payload.get("uid")
    
    if not phone_number:
         raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Firebase kimliğinde Telefon Numarası eksik.")
         
    # 2. Kullanıcının sistemde (Global User olarak) olup olmadığını tespit et
    stmt = select(User).where(User.phone_number == phone_number)
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()
    
    # 3. Eğer kullanıcı yoksa YENİ HESAP AÇ.
    is_new_user = False
    if not user:
        is_new_user = True
        user = User(
             phone_number=phone_number,
             full_name=login_in.full_name,
             role=GlobalUserRole.standard
        )
        db.add(user)
        await db.flush()  # UID atamasını garantilemek için
        
        # Eğer davet JWT'si (t) parametresi varsa, bu kişiyi ajans/birim listesine ekle.
        if login_in.invitation_token:
             try:
                 inv_payload = jwt.decode(login_in.invitation_token, SECRET_KEY, algorithms=[ALGORITHM])
             except JWTError:
                 raise HTTPException(status_code=status.HTTP_406_NOT_ACCEPTABLE, detail="Bozulmuş veya süresi bitmiş davet linki.")
             
             inv_stmt = select(Invitation).where(
                 Invitation.token == login_in.invitation_token,
                 Invitation.is_used == False
             )
             inv_res = await db.execute(inv_stmt)
             db_invitation = inv_res.scalar_one_or_none()
             
             if not db_invitation:
                 raise HTTPException(status_code=400, detail="Davet linkinizin geçerlilik ömrü dolmuş ya da harcanmış.")
             
             # Davet kullanıldı olarak işaretle
             db_invitation.is_used = True
             
        await db.commit()
        await db.refresh(user)
    
    # 4. Kullanıcının agency bilgisini çöz
    staff_stmt = select(AgencyStaff).where(AgencyStaff.user_id == user.id)
    staff_result = await db.execute(staff_stmt)
    staff = staff_result.scalar_one_or_none()
    
    return LoginResponse(
        success=True,
        user=UserResponse(
            id=user.id,
            full_name=user.full_name,
            phone_number=user.phone_number,
            email=user.email,
            role=user.role.value if user.role else "standard",
        ),
        access_token=login_in.firebase_id_token,  # Firebase token'ı aynen geri gönder (client zaten biliyor ama tutarlılık için)
        message="Yeni hesap açıldı ve sisteme giriş yapıldı." if is_new_user else "var olan hesapla giriş yapıldı."
    )

@router.get("/me", response_model=UserResponse)
async def get_current_user_profile(
    current_user: User = Depends(deps.get_current_user),
):
    """
    Oturumdaki kullanıcının profil bilgisini döner.
    Bu endpoint her sayfa yüklemesinde auth durumunu kontrol etmek için kullanılır.
    """
    return UserResponse(
        id=current_user.id,
        full_name=current_user.full_name,
        phone_number=current_user.phone_number,
        email=current_user.email,
        role=current_user.role.value if current_user.role else "standard",
    )
