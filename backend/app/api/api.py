from fastapi import APIRouter
from app.api.endpoints import auth, properties, finance, operations, chat, tenants, landlord, analytics, media_upload, scheduler, admin, agency

api_router = APIRouter()

# Auth endpoints (login, OTP, password)
# main.py mounts api_router at /api/v1, so auth -> /api/v1/auth
api_router.include_router(auth.router, prefix="/auth", tags=["Auth"])

# Admin panel endpoints (superadmin only)
api_router.include_router(admin.router, prefix="/admin", tags=["Admin"])

# Agency endpoints (boss/employee)
api_router.include_router(agency.router, prefix="/agency", tags=["Agency"])

# Legacy / Compatibility endpoints (no /v1 prefix - already under /api/v1 from main.py)
api_router.include_router(properties.router, prefix="/properties", tags=["B. Otonom Portföy Motoru (Property Loop)"])
api_router.include_router(tenants.router, prefix="/tenants", tags=["C. Kiracı ve Ev Sahibi Yönetimi"])
api_router.include_router(finance.router, prefix="/finance", tags=["D. Yapay Zeka (Gemini) Finans ve Banka Okuyucusu"])
api_router.include_router(operations.router, prefix="/operations", tags=["E. Müşteri Destek Biletleri ve Şeffaflık Modülü"])
api_router.include_router(chat.router, prefix="/chat", tags=["F. WebSocket Canlı Mesajlaşma Altyapısı"])
api_router.include_router(landlord.router, prefix="/landlord", tags=["G. Ev Sahibi Paneli"])
api_router.include_router(analytics.router, prefix="/analytics", tags=["H. BI/Analytics Dashboard"])
api_router.include_router(media_upload.router, prefix="/upload", tags=["I. Medya Yükleme (Hetzner Object Storage)"])
api_router.include_router(scheduler.router, prefix="/scheduler", tags=["J. Arka Plan İşleri ve Otomasyon"])
