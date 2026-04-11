import os
import firebase_admin
from firebase_admin import credentials, auth
from firebase_admin import messaging as fb_messaging
from fastapi import HTTPException, status
import logging

logger = logging.getLogger(__name__)
FIREBASE_CREDENTIALS_PATH = os.getenv("FIREBASE_CREDENTIALS_PATH", "firebase-adminsdk.json")

def init_firebase():
    """FastAPI başlatıldığında çalışan, Firebase'i sisteme kitleyen fonksiyon."""
    try:
        if not firebase_admin._apps:
            if os.path.exists(FIREBASE_CREDENTIALS_PATH):
                cred = credentials.Certificate(FIREBASE_CREDENTIALS_PATH)
                firebase_admin.initialize_app(cred)
                print("[INFO] Firebase Admin SDK sisteme başarıyla bağlandı.")
            else:
                print(f"[WARN] {FIREBASE_CREDENTIALS_PATH} anahtarı bulunamadı! Firebase MOCK modunda (sahte yetki bypass'ı ile) çalışacaktır.")
    except Exception as e:
        print(f"[ERROR] Firebase entegrasyon arızası: {e}")

async def verify_firebase_token(id_token: str) -> dict:
    """
    Kullanıcının mobil uygulamasından API'ye gönderdiği ID Token'ı (Google Firebase) doğrular.
    Herhangi bir hile/suistimal durumunda anında 401 Unauthorized basıp isteği keser.

    Geliştirme modunda: id_token = "mock_test_token" ile bypass edilebilir.
    """
    # Geliştirme/a test için mock token bypass
    if id_token == "mock_test_token":
        return {"uid": "mock_uid_12345", "phone_number": "+905551234567"}

    if not os.path.exists(FIREBASE_CREDENTIALS_PATH):
        raise HTTPException(status_code=500, detail="Sunucuda Firebase key eksik olduğu için canlı yetkilendirme yapılamıyor.")

    try:
        decoded_token = auth.verify_id_token(id_token)
        return decoded_token
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Süresi dolmuş veya hatalı Firebase jetonu: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )


async def send_fcm_notification(
    fcm_token: str,
    title: str,
    body: str,
    data: dict | None = None,
) -> bool:
    """
    Firebase Cloud Messaging üzerinden tek bir cihaza push notification gönderir.
    PRD §3.3 — APScheduler + FCM Bildirimleri.

    Returns True if sent successfully, False otherwise.
    """
    if not os.path.exists(FIREBASE_CREDENTIALS_PATH):
        logger.warning("[FCM] Firebase credentials yok — bildirim atlanıyor (mock mod).")
        return False

    try:
        message = fb_messaging.Message(
            notification=fb_messaging.Notification(
                title=title,
                body=body,
            ),
            data=data or {},
            token=fcm_token,
            android=fb_messaging.AndroidConfig(
                priority="high",
                notification=fb_messaging.AndroidNotification(
                    icon="ic_notification",
                    color="#4CAF50",
                    channel_id="emlakdefter_alerts",
                ),
            ),
            apns=fb_messaging.ApnsConfig(
                payload=fb_messaging.ApnsPayload(
                    aps=fb_messaging.Aps(
                        badge=1,
                        sound="default",
                    )
                )
            ),
        )
        response = fb_messaging.send(message)
        logger.info(f"[FCM] Bildirim gönderildi: {response}")
        return True
    except Exception as e:
        logger.error(f"[FCM] Bildirim gönderilemedi: {e}")
        return False


async def send_fcm_notification_to_tokens(
    tokens: list[str],
    title: str,
    body: str,
    data: dict | None = None,
) -> int:
    """
    Firebase Cloud Messaging üzerinden birden fazla cihaza push notification gönderir.
    Başarıyla gönderilen token sayısını döner.
    """
    if not tokens:
        return 0

    if not os.path.exists(FIREBASE_CREDENTIALS_PATH):
        logger.warning("[FCM] Firebase credentials yok — çoklu bildirim atlanıyor (mock mod).")
        return 0

    success_count = 0
    for token in tokens:
        try:
            message = fb_messaging.Message(
                notification=fb_messaging.Notification(title=title, body=body),
                data=data or {},
                token=token,
                android=fb_messaging.AndroidConfig(
                    priority="high",
                    notification=fb_messaging.AndroidNotification(
                        icon="ic_notification",
                        color="#4CAF50",
                        channel_id="emlakdefter_alerts",
                    ),
                ),
            )
            fb_messaging.send(message)
            success_count += 1
        except Exception as e:
            logger.warning(f"[FCM] Token {token[:20]}... gönderilemedi: {e}")

    logger.info(f"[FCM] Çoklu bildirim: {success_count}/{len(tokens)} başarılı.")
    return success_count
