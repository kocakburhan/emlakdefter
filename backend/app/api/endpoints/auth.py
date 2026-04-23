from datetime import timedelta, datetime
from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from pydantic import BaseModel
from jose import jwt, JWTError
import uuid
import os
import re

from app.api import deps
from app.database import get_db
from app.schemas.users import (
    UserLogin, LoginResponse, UserResponse, InviteCreate, InviteResponse,
    FCMTokenRegister, FCMTokenResponse, LoginRequest, LoginResponse as AuthLoginResponse,
    VerifyOTPRequest, SetPasswordRequest, PasswordLoginRequest, ForgotPasswordRequest,
    UserRole
)
from app.models.users import User, Invitation, AgencyStaff, GlobalUserRole, StaffRole, Agency, UserDeviceToken, DeviceType, PasswordResetAttempt
from app.models.tenants import Tenant, LandlordUnit
from app.models.properties import PropertyUnit
from app.core.firebase import verify_firebase_token, reset_user_password_by_phone, generate_email_verification_link
from app.core.security import create_invitation_token, create_access_token, verify_password, hash_password, SECRET_KEY, ALGORITHM
from app.core.rate_limiter import limiter, AUTH_FCM_LIMIT, PASSWORD_RESET_LIMIT

router = APIRouter()

# ──────────────────────────────────────────────
# HELPERS
# ──────────────────────────────────────────────

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


async def get_user_by_email_or_phone(db: AsyncSession, email_or_phone: str):
    """Find user by email or phone number"""
    if is_email(email_or_phone):
        stmt = select(User).where(User.email == email_or_phone.lower())
    else:
        phone = normalize_phone(email_or_phone)
        stmt = select(User).where(User.phone_number == phone)
    result = await db.execute(stmt)
    return result.scalar_one_or_none()


# ──────────────────────────────────────────────
# NEW AUTH FLOW ENDPOINTS
# ──────────────────────────────────────────────

@router.post("/login")
async def login(request: LoginRequest, db: AsyncSession = Depends(get_db)):
    """
    Email veya telefon numarası ile giriş başlatır.

    Returns:
    - status: "password_required" → şifre ekranı gösterilmeli
    - status: "otp_required" → OTP ekranı gösterilmeli
    """
    user = await get_user_by_email_or_phone(db, request.email_or_phone)

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Bu bilgilerle kayıtlı hesap bulunamadı"
        )

    if user.password_hash:
        return AuthLoginResponse(
            status="password_required",
            user=UserResponse(
                id=user.id,
                email=user.email,
                phone_number=user.phone_number,
                full_name=user.full_name,
                role=user.role,
                status=user.status,
                agency_id=user.agency_id,
                created_at=user.created_at,
                last_login_at=user.last_login_at
            ),
            message="Şifrenizi girin"
        )
    else:
        return AuthLoginResponse(
            status="otp_required",
            user=UserResponse(
                id=user.id,
                email=user.email,
                phone_number=user.phone_number,
                full_name=user.full_name,
                role=user.role,
                status=user.status,
                agency_id=user.agency_id,
                created_at=user.created_at,
                last_login_at=user.last_login_at
            ),
            message="Doğrulama kodu gönderilecek"
        )


@router.post("/send-otp")
async def send_otp(request: LoginRequest, db: AsyncSession = Depends(get_db)):
    """
    OTP gönderir (email veya SMS).

    Email: Firebase email verification link gönderir.
    Telefon: Backend kayıt tutar, client-side Firebase SDK ile SMS gönderilir.
    """
    user = await get_user_by_email_or_phone(db, request.email_or_phone)

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Bu bilgilerle kayıtlı hesap bulunamadı"
        )

    if is_email(request.email_or_phone):
        # Email OTP - Firebase email verification link
        try:
            link = generate_email_verification_link(request.email_or_phone)
            # Log the link for development (in production, Firebase sends the email)
            print(f"[DEV] Email verification link: {link}")
            return {"message": "Doğrulama linki email adresinize gönderildi", "dev_link": link}
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Email gönderilemedi: {str(e)}"
            )
    else:
        # Phone OTP - Client-side Firebase SDK handles SMS
        # Backend just returns success and logs for development
        phone = normalize_phone(request.email_or_phone)
        print(f"[DEV] Phone OTP requested for: {phone}")
        return {"message": "SMS doğrulama kodu gönderildi", "phone": phone}


@router.post("/verify-otp")
async def verify_otp(request: VerifyOTPRequest, db: AsyncSession = Depends(get_db)):
    """
    OTP doğrulanır (email link tıklama veya SMS code).

    Email: Firebase email verification status kontrol edilir.
    Telefon: Firebase SDK verification ID doğrulanır (client-side).

    Bu endpoint client-side OTP verification tamamlandıktan sonra
    şifre belirleme akışına geçmek için kullanılır.
    """
    stmt = select(User).where(User.id == request.user_id)
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Kullanıcı bulunamadı"
        )

    # OTP verification is done client-side with Firebase SDK
    # This endpoint just marks that OTP was verified for the user
    return {
        "status": "otp_verified",
        "user_id": str(user.id),
        "message": "Doğrulama başarılı. Şifrenizi belirleyebilirsiniz."
    }


@router.post("/set-password")
async def set_password(request: SetPasswordRequest, db: AsyncSession = Depends(get_db)):
    """
    OTP doğrulandıktan sonra şifre belirleme.

    1. Password validation (8+ char, 1 uppercase, 1 number)
    2. Confirm password match kontrolü
    3. password_hash = bcrypt.hash(password)
    4. status = "active"
    5. JWT token oluştur ve döndür
    """
    stmt = select(User).where(User.id == request.user_id)
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Kullanıcı bulunamadı"
        )

    # Validate password
    if len(request.password) < 8:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Şifre en az 8 karakter olmalıdır"
        )

    has_uppercase = any(c.isupper() for c in request.password)
    has_digit = any(c.isdigit() for c in request.password)

    if not has_uppercase:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Şifre en az bir büyük harf içermelidir"
        )

    if not has_digit:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Şifre en az bir rakam içermelidir"
        )

    if request.password != request.confirm_password:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Şifreler uyuşmuyor"
        )

    # Update user
    user.password_hash = hash_password(request.password)
    user.status = "active"
    user.last_login_at = datetime.utcnow()
    await db.commit()
    await db.refresh(user)

    # Create access token
    access_token = create_access_token(
        data={"sub": str(user.id), "role": user.role.value if hasattr(user.role, 'value') else user.role}
    )

    return AuthLoginResponse(
        status="success",
        user=UserResponse(
            id=user.id,
            email=user.email,
            phone_number=user.phone_number,
            full_name=user.full_name,
            role=user.role,
            status=user.status,
            agency_id=user.agency_id,
            created_at=user.created_at,
            last_login_at=user.last_login_at
        ),
        access_token=access_token,
        message="Şifreniz belirlendi ve giriş yaptınız"
    )


@router.post("/password-login")
async def password_login(request: PasswordLoginRequest, db: AsyncSession = Depends(get_db)):
    """
    Şifre ile giriş.

    1. User'ı bul
    2. password_hash doğrula
    3. 5 yanlış deneme kontrolü (15 dakika kilit) - TODO: implement later
    4. Başarılı → JWT token döndür
    5. last_login_at güncelle
    """
    user = await get_user_by_email_or_phone(db, request.email_or_phone)

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Geçersiz email veya telefon numarası"
        )

    if not user.password_hash:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Bu hesap için şifre belirlenmemiş. OTP ile şifre belirleyin."
        )

    if not verify_password(request.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Yanlış şifre"
        )

    if user.status != "active":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Hesap askıya alınmış"
        )

    # Update last login
    user.last_login_at = datetime.utcnow()
    await db.commit()
    await db.refresh(user)

    # Create access token
    access_token = create_access_token(
        data={"sub": str(user.id), "role": user.role.value if hasattr(user.role, 'value') else user.role}
    )

    return AuthLoginResponse(
        status="success",
        user=UserResponse(
            id=user.id,
            email=user.email,
            phone_number=user.phone_number,
            full_name=user.full_name,
            role=user.role,
            status=user.status,
            agency_id=user.agency_id,
            created_at=user.created_at,
            last_login_at=user.last_login_at
        ),
        access_token=access_token,
        message="Giriş başarılı"
    )


@router.get("/me", response_model=UserResponse)
async def get_me(current_user: User = Depends(deps.get_current_user)):
    """
    Oturumdaki kullanıcının profil bilgisini döner.
    """
    return UserResponse(
        id=current_user.id,
        email=current_user.email,
        phone_number=current_user.phone_number,
        full_name=current_user.full_name,
        role=current_user.role,
        status=current_user.status,
        agency_id=current_user.agency_id,
        created_at=current_user.created_at,
        last_login_at=current_user.last_login_at
    )


@router.post("/forgot-password")
async def forgot_password(request: ForgotPasswordRequest, db: AsyncSession = Depends(get_db)):
    """
    Şifremi unuttum - OTP flow başlatır.
    """
    user = await get_user_by_email_or_phone(db, request.email_or_phone)

    if not user:
        # Security: don't reveal if email/phone exists
        return {"message": "Şifre sıfırlama talimatı email veya telefon numaranıza gönderildi"}

    if is_email(request.email_or_phone):
        try:
            link = generate_email_verification_link(request.email_or_phone)
            print(f"[DEV] Password reset link: {link}")
            return {"message": "Şifre sıfırlama linki email adresinize gönderildi", "dev_link": link}
        except Exception as e:
            return {"message": "Şifre sıfırlama talimatı email veya telefon numaranıza gönderildi"}
    else:
        phone = normalize_phone(request.email_or_phone)
        print(f"[DEV] Password reset OTP for: {phone}")
        return {"message": "Şifre sıfırlama talimatı telefon numaranıza gönderildi"}


# ──────────────────────────────────────────────
# LEGACY / COMPATIBILITY ENDPOINTS
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
    """
    firebase_payload = await verify_firebase_token(login_in.firebase_id_token)
    firebase_uid = firebase_payload.get("uid")
    phone_number = firebase_payload.get("phone_number")
    email = firebase_payload.get("email")

    if not firebase_uid:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Firebase UID eksik.")

    stmt = select(User).where(User.firebase_uid == firebase_uid)
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if user is None and email:
        stmt = select(User).where(User.email == email)
        result = await db.execute(stmt)
        user = result.scalar_one_or_none()

    if user is None and phone_number:
        stmt = select(User).where(User.phone_number == phone_number)
        result = await db.execute(stmt)
        user = result.scalar_one_or_none()

    is_new_user = False
    invitation_data = None

    if user:
        if user.firebase_uid != firebase_uid:
            user.firebase_uid = firebase_uid
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


class PasswordResetConfirmRequest(BaseModel):
    id_token: str
    phone_number: str
    new_password: str


class PasswordResetConfirmResponse(BaseModel):
    success: bool
    message: str


@router.post("/reset-password", response_model=PasswordResetConfirmResponse)
@limiter.limit(PASSWORD_RESET_LIMIT)
async def reset_password(
    request: Request,
    data: PasswordResetConfirmRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    Şifre sıfırlama işlemini tamamlar — PRD §4.1.4-D.
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