# Emlakdefteri Auth & Admin Panel - Tam Uyum Planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** yapılacaklar.txt akışına %100 uyumlu auth + admin panel sistemi

**Architecture:** FastAPI backend (PostgreSQL + Firebase Auth), Flutter frontend, JWT token auth

**Tech Stack:** Python/FastAPI, PostgreSQL, Firebase (Email Verification + Phone SMS OTP), Flutter

---

## AUDIT ÖZETİ

Mevcut durum vs yapılacaklar.txt:

| Gereksinim | Backend | Frontend | Durum |
|------------|---------|----------|-------|
| Admin ofis+patron oluşturma | ✅ `/admin/agencies` (POST) | ✅ `create_office_with_boss_screen.dart` | Çalışıyor |
| Login (email/phone) | ✅ `/auth/login` | ✅ `login_screen.dart` | Çalışıyor |
| Şifresiz → OTP gönder | ⚠️ `/auth/send-otp` ayrı çağrılıyor | ✅ `sendOtp()` methodu var | Akış farklı |
| 5 başarısız → 15dk kilit | ✅ `/password-login` | N/A | Çalışıyor |
| 3 yanlış OTP → blok | ❌ `EmailVerificationCode` tablo var ama kullanılmıyor | ❌ OTP ekranında yok | Eksik |
| OTP 3dk timeout | ❌ Backend'de yok | ⚠️ UI'da var ama backend'e bağlı değil | Eksik |
| Şifre belirleme | ✅ `/auth/set-password` | ✅ `set_password_screen.dart` | Çalışıyor |
| Patron çalışan ekleme | ✅ `/agency/employees` (POST) | ⚠️ Agency tab içinde | Kısmi |
| Çalışan pasif → engelle | ⚠️ Sadece status kontrolü | ❌ UI yok | Eksik |
| Superadmin girişi | ✅ Firebase email/pass + DB role kontrolü | ✅ `/admin` route | Çalışıyor |

---

## STEP 1: Backend - OTP Attempt Tracking Ekle

**Problem:** 3 yanlış OTP denemesinde blokaj ve 3 dakika timeout backend'de kontrol edilmiyor. `EmailVerificationCode` tablo var ama kullanılmıyor.

**Files:**
- Modify: `backend/app/api/endpoints/auth.py`

- [ ] **Step 1: EmailVerificationCode tablosunu kontrol et**

Mevcut `EmailVerificationCode` modelinde `attempts` ve `verified` alanları var. Bu tabloyu OTP doğrulama için kullanacağız.

- [ ] **Step 2: verify-otp endpoint'ini güncelle**

Mevcut `/auth/verify-otp` sadece Firebase token doğruluyor. Email OTP için backend-side code verification eklememiz gerekiyor.

**Yeni flow (email OTP için):**
1. `/send-otp` → 6 haneli kod üret, DB'ye kaydet, email'e gönder (Firebase Email Verification Link değil, custom 6-digit kod)
2. `/verify-otp` → kodu DB'den kontrol et, attempts++ yap, 3 yanlışsa blok

**NOT:** Firebase Email Verification Link kullanılacaksa (design-doc.md'de var), o zaman mevcut flow doğru - link tıklayınca Firebase email'i doğruluyor. Ancak yapılacaklar.txt'de "6 haneli OTP" ve "3 yanlış deneme" var, bu custom code gerektirir.

yapılacaklar.txt'ye göre:
- Email → Firebase `sendEmailVerification` → email link yerine 6 haneli kod gönderilsin? Hayır, email için de 6 haneli kod olmalı.

**Karar:** Email için Firebase Email Verification Link yerine backend'de 6 haneli kod üretip email olarak gönderelim. Telefon için Firebase SMS OTP kullanılacak.

- [ ] **Step 3: send-otp endpoint'ini güncelle (email için 6-digit kod)**

```python
@router.post("/send-otp")
async def send_otp(request: Request, login_request: LoginRequest, db: AsyncSession = Depends(get_db)):
    user = await get_user_by_email_or_phone(db, login_request.email_or_phone)
    if not user:
        raise HTTPException(status_code=404, detail="Bu bilgilerle kayıtlı hesap bulunamadı")

    # Kilit kontrolü
    if user.locked_until and user.locked_until > datetime.utcnow():
        raise HTTPException(status_code=403, detail="Hesap kilitli")

    # Email için 6 haneli kod üret ve DB'ye kaydet
    if is_email(login_request.email_or_phone):
        code = f"{random.randint(0, 999999):06d}"
        expires_at = datetime.utcnow() + timedelta(minutes=3)

        # Eski kodları sil (aynı email için)
        await db.execute(
            delete(EmailVerificationCode).where(
                EmailVerificationCode.email == login_request.email_or_phone.lower()
            )
        )

        # Yeni kod ekle
        evc = EmailVerificationCode(
            email=login_request.email_or_phone.lower(),
            code=code,
            expires_at=expires_at,
            attempts=0,
            verified=False
        )
        db.add(evc)
        await db.commit()

        # Email gönder (console'a logla veya SMTP ile)
        print(f"[DEV] Email verification code for {login_request.email_or_phone}: {code}")

        return {"message": "Doğrulama kodu email adresinize gönderildi", "dev_code": code}  # DEV mode'da code döner

    # Telefon için Firebase SMS OTP başlat (client-side)
    else:
        phone = normalize_phone(login_request.email_or_phone)
        return {"message": "SMS doğrulama kodu gönderildi", "phone": phone}
```

- [ ] **Step 4: verify-otp endpoint'ini güncelle (email code verification)**

```python
@router.post("/verify-otp")
async def verify_otp(request: Request, verify_request: VerifyOTPRequest, db: AsyncSession = Depends(get_db)):
    user = await get_user_by_email_or_phone(db, verify_request.email_or_phone)
    if not user:
        raise HTTPException(status_code=404, detail="Kullanıcı bulunamadı")

    is_email_input = is_email(verify_request.email_or_phone)

    # Email için backend-side code verification
    if is_email_input:
        evc_stmt = select(EmailVerificationCode).where(
            EmailVerificationCode.email == verify_request.email_or_phone.lower(),
            EmailVerificationCode.verified == False
        ).order_by(EmailVerificationCode.created_at.desc())
        result = await db.execute(evc_stmt)
        evc = result.scalar_one_or_none()

        if not evc:
            raise HTTPException(status_code=400, detail="Doğrulama kodu bulunamadı, lütfen yeni kod isteyin")

        # Timeout kontrolü
        if evc.expires_at < datetime.utcnow():
            raise HTTPException(status_code=400, detail="Doğrulama kodunun süresi dolmuş, lütfen yeni kod isteyin")

        # Kod doğru mu?
        if evc.code != verify_request.code:
            evc.attempts += 1
            await db.commit()

            if evc.attempts >= 3:
                raise HTTPException(
                    status_code=429,
                    detail="3 kez yanlış kod girdiniz. Lütfen yeni kod isteyin."
                )

            remaining = 3 - evc.attempts
            raise HTTPException(
                status_code=400,
                detail=f"Hatalı kod. {remaining} hakkınız kaldı."
            )

        # Kod doğru - verified işaretle
        evc.verified = True
        user.firebase_uid = verify_request.firebase_id_token  # Firebase UID eşleştirme
        await db.commit()

        return {
            "success": True,
            "user_id": str(user.id),
            "require_password_setup": user.password_hash is None
        }

    # Telefon için Firebase SMS OTP verification (client-side)
    else:
        # Telefon OTP Firebase client-side doğrulanır, backend sadece Firebase token kontrol eder
        if not verify_request.firebase_id_token:
            raise HTTPException(status_code=400, detail="Firebase ID token gerekli")

        try:
            decoded = await verify_firebase_token(verify_request.firebase_id_token)
            firebase_uid = decoded.get("uid")

            if not user.firebase_uid:
                user.firebase_uid = firebase_uid
            elif user.firebase_uid != firebase_uid:
                raise HTTPException(status_code=401, detail="Firebase token kullanıcıyla eşleşmiyor")

            await db.commit()

            return {
                "success": True,
                "user_id": str(user.id),
                "require_password_setup": user.password_hash is None
            }
        except Exception as e:
            raise HTTPException(status_code=401, detail=f"Doğrulama başarısız: {str(e)}")
```

---

## STEP 2: Backend - Çalışan Pasif Engelleme

**Problem:** Çalışan pasife alınınca mevcut oturumu sonlandırılmıyor ve bir sonraki girişte "Hesabınız devre dışı bırakılmıştır" mesajı gösterilmiyor.

**Files:**
- Modify: `backend/app/api/endpoints/auth.py`
- Modify: `backend/app/api/endpoints/agency.py`

- [ ] **Step 1: password-login'de status kontrolünü güncelle**

Mevcut kod zaten `user.status` kontrolü yapıyor ama "inactive" için özel mesaj yok.

```python
# password-login'de:
if user.status == "inactive":
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Hesabınız devre dışı bırakılmıştır. Lütfen yöneticinizle iletişime geçin."
    )
```

- [ ] **Step 2: login endpoint'inde de aynı kontrol**

```python
# login endpoint'inde (otp_required ve password_required dönmeden önce):
if user.status == "inactive":
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Hesabınız devre dışı bırakılmıştır. Lütfen yöneticinizle iletişime geçin."
    )
```

- [ ] **Step 3: verify-otp ve set-password'te de status kontrolü ekle**

---

## STEP 3: Backend - Şifre Belirleme Validation

**Files:**
- Modify: `backend/app/schemas/users.py`

- [ ] **Step 1: SetPasswordRequest validator'ını kontrol et**

Mevcut validator:
```python
@field_validator('new_password')
@classmethod
def validate_password(cls, v):
    if not any(c.isupper() for c in v):
        raise ValueError('Şifre en az bir büyük harf içermelidir')
    if not any(c.isdigit() for c in v):
        raise ValueError('Şifre en az bir rakam içermelidir')
    return v
```

Bu yeterli. Ama `confirm_password` validator'ı `new_password` ile karşılaştırma yapıyor.

---

## STEP 4: Frontend - OTP Ekranı Güncellemeleri

**Problem:** 3 yanlış deneme sonrası blok ve "Kodu tekrar gönder" aktifleşmeli. 3 dakika geri sayım gösterilmeli.

**Files:**
- Modify: `frontend/lib/features/auth/screens/otp_screen.dart`

- [ ] **Step 1: 3 yanlış deneme sonrası blok mantığı**

Frontend'de `verifyOtp` fonksiyonu backend'den gelen hatayı gösteriyor. Backend 429 döndüğünde "Kodu tekrar gönder" butonunu aktif et.

```dart
// 429 status code geldiğinde:
if (response.statusCode == 429) {
  // "3 kez yanlış kod girdiniz" - blok
  // "Kodu tekrar gönder" aktif
}
```

- [ ] **Step 2: 3 dakika geri sayım**

Mevcut UI'da var ama backend timeout'u ile senkronize değil. Backend'de 3 dakika TTL olduğundan frontend de 3 dakika geri sayım yapmalı.

---

## STEP 5: Frontend - Çalışan Pasif Mesajı

**Problem:** Hesap devre dışı mesajı gösterilmiyor.

**Files:**
- Modify: `frontend/lib/features/auth/providers/auth_provider.dart`

- [ ] **Step 1: Hata mesajlarını kontrol et**

Mevcut `passwordLogin` ve `loginWithEmailOrPhone` fonksiyonlarında backend'den gelen 403 status code'u yakalanıp `error` state'ine atılıyor. Bu doğru çalışıyor olmalı.

Eğer çalışmıyorsa, error mesajı UI'da gösterilmiyor demektir.

---

## STEP 6: Admin Panel UI - Kontrol

**Files:**
- Check: `frontend/lib/features/admin/screens/`

- [ ] **Step 1: Admin panel ekranlarını kontrol et**

Design-doc.md'ye göre admin panel:
- Dashboard (özet istatistikler)
- Emlak Ofisleri (liste, oluştur, düzenle, sil)
- Kullanıcılar (tüm kullanıcıları listele, filtrele, patron/çalışan ekle)

Frontend-design skilli ile kontrol et ve eksiklikleri tespit et.

---

## VERIFICATION PLANI

- [ ] Backend'e `test@test.com` ile kayıtsız kullanıcı denemesi → 404
- [ ] Backend'e `kocakkburhann@gmail.com` ile giriş → OTP veya password status dönmeli
- [ ] OTP kodu gönder → emailVerificationCodes tablosuna kayıt
- [ ] Yanlış OTP 3 kez → 429 error
- [ ] Doğru OTP → password setup veya login
- [ ] 5 yanlış password → 15dk kilit
- [ ] Pasif kullanıcı girişi → "Hesabınız devre dışı" mesajı

---

## Files to Modify Summary

| File | Changes |
|------|---------|
| `backend/app/api/endpoints/auth.py` | OTP code generation + verification with attempt tracking |
| `backend/app/api/endpoints/agency.py` | Status check on all endpoints |
| `backend/app/schemas/users.py` | Already correct - verify |
| `frontend/lib/features/auth/screens/otp_screen.dart` | 3 wrong = block, resend enabled |
| `frontend/lib/features/auth/providers/auth_provider.dart` | Error handling for 403/429 |

---

## Notes

1. **Email OTP:** Firebase sendEmailVerification yerine custom 6-digit kod kullanılacak (yapılacaklar.txt'de 6 haneli OTP var)
2. **Phone OTP:** Firebase SMS OTP (client-side) + backend token verification
3. **Superadmin login:** Firebase email/password → DB role check → JWT token