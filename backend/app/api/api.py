from fastapi import APIRouter
from app.api.endpoints import auth, properties, finance, operations, chat

api_router = APIRouter()

# Alt kırılımlardaki rotalar (Modüller) Ana Yönlendiriciye Enjekte Ediliyor.
api_router.include_router(auth.router, prefix="/auth", tags=["A. Kimlik, Otorite ve Sisteme Katılım Aracı"])
api_router.include_router(properties.router, prefix="/properties", tags=["B. Otonom Portföy Motoru (Property Loop)"])
api_router.include_router(finance.router, prefix="/finance", tags=["C. Yapay Zeka (Gemini) Finans ve Banka Okuyucusu"])
api_router.include_router(operations.router, prefix="/operations", tags=["D. Müşteri Destek Biletleri ve Şeffaflık Modülü"])
api_router.include_router(chat.router, prefix="/chat", tags=["E. WebSocket Canlı Mesajlaşma Altyapısı"])
