from fastapi import APIRouter
from app.api.endpoints import auth, properties, finance, operations, chat, tenants, landlord, analytics, media_upload, scheduler

api_router = APIRouter()

# Alt kırılımlardaki rotalar (Modüller) Ana Yönlendiriciye Enjekte Ediliyor.
api_router.include_router(auth.router, prefix="/auth", tags=["A. Kimlik, Otorite ve Sisteme Katılım Aracı"])
api_router.include_router(properties.router, prefix="/properties", tags=["B. Otonom Portföy Motoru (Property Loop)"])
api_router.include_router(tenants.router, prefix="/tenants", tags=["C. Kiracı ve Ev Sahibi Yönetimi"])
api_router.include_router(finance.router, prefix="/finance", tags=["D. Yapay Zeka (Gemini) Finans ve Banka Okuyucusu"])
api_router.include_router(operations.router, prefix="/operations", tags=["E. Müşteri Destek Biletleri ve Şeffaflık Modülü"])
api_router.include_router(chat.router, prefix="/chat", tags=["F. WebSocket Canlı Mesajlaşma Altyapısı"])
api_router.include_router(landlord.router, prefix="/landlord", tags=["G. Ev Sahibi Paneli"])
api_router.include_router(analytics.router, prefix="/analytics", tags=["H. BI/Analytics Dashboard"])
api_router.include_router(media_upload.router, prefix="/upload", tags=["I. Medya Yükleme (Hetzner Object Storage)"])
api_router.include_router(scheduler.router, prefix="/scheduler", tags=["J. Arka Plan İşleri ve Otomasyon"])
