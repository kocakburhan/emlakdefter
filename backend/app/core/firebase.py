import os
import firebase_admin
from firebase_admin import credentials, auth
from fastapi import HTTPException, status

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
    """
    if not os.path.exists(FIREBASE_CREDENTIALS_PATH):
        # Eğer geliştirme aşamasındaysak ve .json verisi girmemişsek bypass testi:
        if id_token == "mock_test_token":
            return {"uid": "mock_uid_12345", "phone_number": "+905551234567"}
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
