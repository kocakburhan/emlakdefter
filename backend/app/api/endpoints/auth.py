from datetime import timedelta, datetime
from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from pydantic import BaseModel
from jose import jwt, JWTError
import uuid
import os

from app.api import deps
from app.database import get_db
from app.schemas.users import UserLogin, LoginResponse, UserResponse, InviteCreate, InviteResponse, FCMTokenRegister, FCMTokenResponse
from app.models.users import User, Invitation, AgencyStaff, GlobalUserRole, StaffRole, Agency, UserDeviceToken, DeviceType, PasswordResetAttempt
from app.models.tenants import Tenant, LandlordUnit
from app.models.properties import PropertyUnit
from app.core.firebase import verify_firebase_token, reset_user_password_by_phone
from app.core.security import create_invitation_token, SECRET_KEY, ALGORITHM
from app.core.rate_limiter import limiter, AUTH_FCM_LIMIT, PASSWORD_RESET_LIMIT

router = APIRouter()

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
    Firebase Email/Password veya Phone OTP doğrulamasından sonra backend'e gelen login isteği.

    PRD Madde 4.1.4-C: Firebase tek kimlik otoritesidir.
    Bu endpoint Firebase token'ı doğrular, kullanıcıyı bulur/oluşturur ve profil bilgisini döner.

    Akış:
    1. Firebase token doğrula
    2. Kullanıcıyı firebase_uid ile bul
    3. Yoksa oluştur (email ve/veya phone_number ile)
    4. Davet token varsa: Tenant veya LandlordUnit kaydı oluştur
    """
    # 1. Firebase Sunucusunda Token'ı Güvenli Yoldan Doğrula
    firebase_payload = await verify_firebase_token(login_in.firebase_id_token)
    firebase_uid = firebase_payload.get("uid")
    phone_number = firebase_payload.get("phone_number")  # Phone auth için gelir, email/pass için None olabilir
    email = firebase_payload.get("email")  # Email/password auth için gelir

    if not firebase_uid:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Firebase UID eksik.")

    # 2. Kullanıcıyı firebase_uid ile bul
    stmt = select(User).where(User.firebase_uid == firebase_uid)
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    # 2b. firebase_uid ile bulunamazsa email veya phone ile dene
    # Bu durum şunlardan kaynaklanabilir:
    #   - Kullanıcı daha önce kaydolmuş ama firebase_uid atanmamış (seed data / eski kayıt)
    #   - Firebase tarafında kullanıcı yeniden oluşturulmuş (farklı UID)
    if user is None and email:
        stmt = select(User).where(User.email == email)
        result = await db.execute(stmt)
        user = result.scalar_one_or_none()

    if user is None and phone_number:
        stmt = select(User).where(User.phone_number == phone_number)
        result = await db.execute(stmt)
        user = result.scalar_one_or_none()

    # 3. Kullanıcıyı oluştur veya güncelle
    is_new_user = False
    invitation_data = None

    if user:
        # Mevcut kullanıcının firebase_uid'sini güncelle (farklıysa veya null'sa)
        if user.firebase_uid != firebase_uid:
            user.firebase_uid = firebase_uid
        # Eksik bilgileri tamamla
        if not user.email and email:
            user.email = email
        if not user.phone_number and phone_number:
            user.phone_number = phone_number
        if login_in.full_name and (not user.full_name or user.full_name == 'Kullanıcı'):
            user.full_name = login_in.full_name
        await db.commit()
        await db.refresh(user)
    else:
        is_new_user = True
        user = User(
            firebase_uid=firebase_uid,
            phone_number=phone_number,
            email=email,
            full_name=login_in.full_name,
            role=GlobalUserRole.standard
        )
        db.add(user)
        await db.flush()

        # Davet JWT'si varsa, kullanıcıyı ajans/birim listesine ekle
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
            db_invitation.is_used = True

        await db.commit()
        await db.refresh(user)

    # 4. Davet ile gelen kullanıcı için Tenant veya LandlordUnit kaydı oluştur
    if invitation_data and invitation_data.related_entity_id:
        target_role = invitation_data.target_role
        unit_id = invitation_data.related_entity_id
        agency_id = invitation_data.agency_id

        unit_stmt = select(PropertyUnit).where(PropertyUnit.id == unit_id)
        unit_res = await db.execute(unit_stmt)
        unit = unit_res.scalar_one_or_none()

        if not unit:
            raise HTTPException(status_code=400, detail="Davet edilen birim bulunamadı.")

        if target_role == "tenant":
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

    return LoginResponse(
        success=True,
        user=UserResponse(
            id=user.id,
            full_name=user.full_name,
            phone_number=user.phone_number,
            email=user.email,
            role=user.role.value if user.role else "standard",
        ),
        access_token=login_in.firebase_id_token,
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
    try:
        device_type = DeviceType(token_in.device_type)
    except ValueError:
        raise HTTPException(status_code=400, detail="Geçersiz cihaz tipi. Değerler: ios, android, web")

    stmt = select(UserDeviceToken).where(
        UserDeviceToken.fcm_token == token_in.fcm_token,
        UserDeviceToken.user_id == current_user.id,
    )
    result = await db.execute(stmt)
    existing = result.scalar_one_or_none()

    if existing:
        existing.device_type = device_type
        existing.last_used_at = datetime.utcnow()
        await db.commit()
        return FCMTokenResponse(success=True, message="FCM token güncellendi.")
    else:
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

    attempt = PasswordResetAttempt(
        phone_number=data.phone_number,
        attempted_at=datetime.utcnow(),
    )
    db.add(attempt)
    await db.commit()

    return {"message": "Doğrulama kodu gönderildi."}


# ──────────────────────────────────────────────
# PASSWORD RESET SCHEMAS
# ──────────────────────────────────────────────

class PasswordResetConfirmRequest(BaseModel):
    id_token: str
    phone_number: str
    new_password: str


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
    """
    try:
        decoded = await verify_firebase_token(data.id_token)
        token_phone = decoded.get("phone_number", "")
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

    if len(data.new_password) < 6:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Şifre en az 6 karakter olmalıdır."
        )

    reset_user_password_by_phone(data.phone_number, data.new_password)

    return PasswordResetConfirmResponse(
        success=True,
        message="Şifreniz başarıyla güncellendi."
    )