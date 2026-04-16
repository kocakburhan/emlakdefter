from datetime import timedelta, datetime
from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from passlib.context import CryptContext
from pydantic import BaseModel

from app.api import deps
from app.database import get_db
from app.schemas.users import UserLogin, LoginResponse, UserResponse, InviteCreate, InviteResponse, FCMTokenRegister, FCMTokenResponse
from app.models.users import User, Invitation, AgencyStaff, GlobalUserRole, StaffRole, Agency, UserDeviceToken, DeviceType, PasswordResetAttempt
from app.models.tenants import Tenant, LandlordUnit
from app.models.properties import PropertyUnit
from app.core.firebase import verify_firebase_token, reset_user_password_by_phone
from app.core.security import create_invitation_token, create_access_token
from app.core.rate_limiter import limiter, AUTH_FCM_LIMIT, PASSWORD_RESET_LIMIT, AUTH_LIMIT
from jose import jwt, JWTError
import uuid
import os
import bcrypt

SECRET_KEY = os.getenv("SECRET_KEY", "b2c9a8db422e..._override_in_env_")
ALGORITHM = os.getenv("ALGORITHM", "HS256")
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

router = APIRouter()

# ──────────────────────────────────────────────
# BASIT TEST LOGIN/REGISTER (Firebase yok)
# ──────────────────────────────────────────────

class SimpleRegisterRequest(BaseModel):
    email: str
    password: str
    full_name: str
    role: str  # agent, tenant, landlord

class SimpleLoginRequest(BaseModel):
    email: str
    password: str
    role: str

@router.post("/register-simple")
async def simple_register(
    data: SimpleRegisterRequest,
    db: AsyncSession = Depends(get_db)
):
    """Test için email/şifre ile basit kayıt"""
    # Email zaten var mı kontrol et
    stmt = select(User).where(User.email == data.email)
    result = await db.execute(stmt)
    existing = result.scalar_one_or_none()

    if existing:
        raise HTTPException(status_code=400, detail="Bu email zaten kayıtlı")

    # Yeni user oluştur
    hashed = bcrypt.hashpw(data.password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
    # Agent = superadmin (full access), tenant/landlord = standard
    role_map = {
        "agent": GlobalUserRole.superadmin,
        "tenant": GlobalUserRole.standard,
        "landlord": GlobalUserRole.standard,
    }

    user = User(
        email=data.email,
        password_hash=hashed,
        full_name=data.full_name,
        role=role_map.get(data.role, GlobalUserRole.standard),
        phone_number=f"+test-{data.email}",  # placeholder
    )
    db.add(user)
    await db.flush()

    # Agent için AgencyStaff oluştur
    if data.role == "agent":
        agency_stmt = select(Agency).limit(1)
        agency_result = await db.execute(agency_stmt)
        agency = agency_result.scalar_one_or_none()

        if not agency:
            agency = Agency(name="Test Agency", phone="+905551234567")
            db.add(agency)
            await db.flush()

        staff = AgencyStaff(
            agency_id=agency.id,
            user_id=user.id,
            role=StaffRole.agent,
        )
        db.add(staff)

    await db.commit()
    await db.refresh(user)

    return {
        "success": True,
        "user_id": str(user.id),
        "message": "Kayıt başarılı"
    }

@router.post("/login-simple")
async def simple_login(
    data: SimpleLoginRequest,
    db: AsyncSession = Depends(get_db)
):
    """Test için email/şifre ile basit giriş"""
    stmt = select(User).where(User.email == data.email)
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if not user or not user.password_hash:
        raise HTTPException(status_code=401, detail="Geçersiz email veya şifre")

    if not bcrypt.checkpw(data.password.encode('utf-8'), user.password_hash.encode('utf-8')):
        raise HTTPException(status_code=401, detail="Geçersiz email veya şifre")

    # Basit bir token üret (test için)
    token_data = {
        "sub": str(user.id),
        "email": user.email,
        "role": data.role,
    }
    access_token = create_access_token(token_data, expires_delta=timedelta(hours=24))

    return {
        "success": True,
        "access_token": str(access_token),
        "user": {
            "id": str(user.id),
            "email": str(user.email),
            "full_name": str(user.full_name),
            "role": str(user.role.value if user.role else "standard"),
        }
    }

# ──────────────────────────────────────────────
# FIREBASE + DAVET LOGIN
# ──────────────────────────────────────────────

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
    FRONTEND_URL = os.getenv("FRONTEND_URL", "https://app.emlakdefter.com")
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

    Akış:
    1. Firebase token doğrula
    2. Kullanıcı yoksa oluştur
    3. Davet token varsa: Tenant veya LandlordUnit kaydı oluştur
    4. Agent için: AgencyStaff kaydı kontrol et/yoksa oluştur
    """
    # 1. Firebase Sunucusunda Token'ı Güvenli Yoldan Doğrula
    firebase_payload = await verify_firebase_token(login_in.firebase_id_token)
    phone_number = firebase_payload.get("phone_number")
    firebase_uid = firebase_payload.get("uid")

    if not phone_number:
         raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Firebase kimliğinde Telefon Numarası eksik.")

    # 2. Kullanıcının sistemde (Global User olarak) olup olmadığını tespit et
    stmt = select(User).where(User.firebase_uid == firebase_uid)
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    # Geriye uyumluluk: firebase_uid set edilmemis kullanıcılar icin phone_number ile kontrol et
    if user is None:
        stmt = select(User).where(User.phone_number == phone_number)
        result = await db.execute(stmt)
        user = result.scalar_one_or_none()
        # Mevcut kullanıcıya firebase_uid ataması yap
        if user and user.firebase_uid is None:
            user.firebase_uid = firebase_uid
            await db.commit()

    # 3. Eğer kullanıcı yoksa YENİ HESAP AÇ.
    is_new_user = False
    invitation_data = None

    if not user:
        is_new_user = True
        user = User(
             firebase_uid=firebase_uid,
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

             invitation_data = db_invitation
             # Davet kullanıldı olarak işaretle
             db_invitation.is_used = True

        await db.commit()
        await db.refresh(user)

    # 4. Davet ile gelen kullanıcı için Tenant veya LandlordUnit kaydı oluştur
    if invitation_data and invitation_data.related_entity_id:
        target_role = invitation_data.target_role
        unit_id = invitation_data.related_entity_id
        agency_id = invitation_data.agency_id

        # Birim gerçekten var mı kontrol et
        unit_stmt = select(PropertyUnit).where(PropertyUnit.id == unit_id)
        unit_res = await db.execute(unit_stmt)
        unit = unit_res.scalar_one_or_none()

        if not unit:
            raise HTTPException(status_code=400, detail="Davet edilen birim bulunamadı.")

        if target_role == "tenant":
            # Tenant kaydı oluştur (varsa oluşturma, çünkü aynı birime tekrar davet atılabilir)
            existing_tenant_stmt = select(Tenant).where(
                Tenant.user_id == user.id,
                Tenant.unit_id == unit_id,
                Tenant.is_active == True
            )
            existing_tenant_res = await db.execute(existing_tenant_stmt)
            existing_tenant = existing_tenant_res.scalar_one_or_none()

            if not existing_tenant:
                tenant = Tenant(
                    agency_id=agency_id,
                    unit_id=unit_id,
                    user_id=user.id,
                    rent_amount=unit.rent_price or 0,
                    payment_day=1,
                    start_date=datetime.utcnow().date(),
                    end_date=datetime.utcnow().date(),
                    status="active"
                )
                db.add(tenant)

        elif target_role == "landlord":
            # LandlordUnit kaydı oluştur
            existing_landlord_stmt = select(LandlordUnit).where(
                LandlordUnit.user_id == user.id,
                LandlordUnit.unit_id == unit_id
            )
            existing_landlord_res = await db.execute(existing_landlord_stmt)
            existing_landlord = existing_landlord_res.scalar_one_or_none()

            if not existing_landlord:
                landlord_unit = LandlordUnit(
                    agency_id=agency_id,
                    unit_id=unit_id,
                    user_id=user.id,
                    ownership_share=100
                )
                db.add(landlord_unit)

        await db.commit()

    # 5. Kullanıcının agency bilgisini çöz (sadece agent için zorunlu)
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


@router.post("/fcm-token", response_model=FCMTokenResponse)
@limiter.limit(AUTH_FCM_LIMIT)
async def register_fcm_token(
    request: Request,
    token_in: FCMTokenRegister,
    current_user: User = Depends(deps.get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Kullanıcının cihaz FCM push notification token'ını kaydeder.
    PRD §3.3 — APScheduler + FCM Bildirimleri.

    Aynı token varsa güncellenir, yoksa yeni kayıt oluşturulur.
    """
    # device_type enum'a çevir
    try:
        device_type = DeviceType(token_in.device_type)
    except ValueError:
        raise HTTPException(status_code=400, detail="Geçersiz cihaz tipi. Değerler: ios, android, web")

    # Token zaten var mı kontrol et
    stmt = select(UserDeviceToken).where(
        UserDeviceToken.fcm_token == token_in.fcm_token,
        UserDeviceToken.user_id == current_user.id,
    )
    result = await db.execute(stmt)
    existing = result.scalar_one_or_none()

    if existing:
        # Güncelle
        existing.device_type = device_type
        existing.last_used_at = datetime.utcnow()
        await db.commit()
        return FCMTokenResponse(success=True, message="FCM token güncellendi.")
    else:
        # Yeni kayıt oluştur
        new_token = UserDeviceToken(
            user_id=current_user.id,
            fcm_token=token_in.fcm_token,
            device_type=device_type,
            last_used_at=datetime.utcnow(),
        )
        db.add(new_token)
        await db.commit()
        return FCMTokenResponse(success=True, message="FCM token kaydedildi.")


# ──────────────────────────────────────────────
# PASSWORD RESET OTP — SMS PUMPING KORUMASI
# PRD §4.1.4-D
# ──────────────────────────────────────────────

MONTHLY_OTP_LIMIT = 15


class RequestPasswordResetRequest(BaseModel):
    phone_number: str


@router.post("/request-password-reset-otp")
@limiter.limit(PASSWORD_RESET_LIMIT)
async def request_password_reset_otp(
    request: Request,
    data: RequestPasswordResetRequest,
    current_user: User = Depends(deps.get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Şifre sıfırlama OTP'si talep eder.
    PRD §4.1.4-D: Aylık 15 limit kontrolü.
    """
    # 1) Limit kontrolü — bu ay içinde kaç talep var?
    first_of_month = datetime.utcnow().replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    stmt = select(func.count(PasswordResetAttempt.id)).where(
        PasswordResetAttempt.phone_number == data.phone_number,
        PasswordResetAttempt.attempted_at >= first_of_month,
    )
    result = await db.execute(stmt)
    count = result.scalar() or 0

    if count >= MONTHLY_OTP_LIMIT:
        raise HTTPException(
            status_code=429,
            detail=(
                "Bu ay için şifre sıfırlama limitine ulaşıldı (15/ay). "
                "Lütfen emlakçınızla iletişime geçin."
            ),
        )

    # 2) Meşru talep — kaydı tut
    attempt = PasswordResetAttempt(
        phone_number=data.phone_number,
        attempted_at=datetime.utcnow(),
    )
    db.add(attempt)
    await db.commit()

    # 3) Firebase OTP gönder (Firebase Admin SDK flow)
    # Firebase verifyPhoneNumber otomatik olarak çalışır
    return {"message": "Doğrulama kodu gönderildi."}


# ──────────────────────────────────────────────
# PASSWORD RESET SCHEMAS
# ──────────────────────────────────────────────

class PasswordResetConfirmRequest(BaseModel):
    """Şifre sıfırlama doğrulama isteği — PRD §4.1.4-D"""
    id_token: str          # Firebase ID token (OTP doğrulandıktan sonra client'dan)
    phone_number: str      # Doğrulanan telefon numarası
    new_password: str      # Yeni şifre (Firebase'e gönderilecek)


class PasswordResetConfirmResponse(BaseModel):
    success: bool
    message: str


# ──────────────────────────────────────────────
# PASSWORD RESET ENDPOINT
# ──────────────────────────────────────────────

@router.post("/reset-password", response_model=PasswordResetConfirmResponse)
@limiter.limit(PASSWORD_RESET_LIMIT)
async def reset_password(
    request: Request,
    data: PasswordResetConfirmRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    Şifre sıfırlama işlemini tamamlar — PRD §4.1.4-D.

    Akış:
    1. İstemci (Flutter) Firebase OTP'yi doğrular → Firebase ID token alır
    2. İstemci bu endpoint'e ID token + yeni şifre gönderir
    3. Backend ID token'ı doğrular
    4. Backend Firebase Admin SDK ile şifreyi günceller

    NOT: OTP doğrulaması Firebase SDK'da client-side yapılır.
    Backend sadece Firebase ID token doğrulaması yapar.
    """
    # 1) Firebase ID token doğrula
    try:
        decoded = await verify_firebase_token(data.id_token)
        token_phone = decoded.get("phone_number", "")
        # Telefon numarasının eşleştiğinden emin ol
        if token_phone and token_phone != data.phone_number:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Telefon numarası token ile eşleşmiyor."
            )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Token doğrulama başarısız: {str(e)}"
        )

    # 2) Şifre uzunluk kontrolü
    if len(data.new_password) < 6:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Şifre en az 6 karakter olmalıdır."
        )

    # 3) Firebase Admin SDK ile şifreyi güncelle
    reset_user_password_by_phone(data.phone_number, data.new_password)

    # 4) Başarılı yanıt
    return PasswordResetConfirmResponse(
        success=True,
        message="Şifreniz başarıyla güncellendi."
    )
