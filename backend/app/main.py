from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from dotenv import load_dotenv
import os

# .env dosyasını yükle (DEV_MODE, DEV_AGENCY_ID vb. için)
load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))

from app.api.api import api_router
from app.core.firebase import init_firebase
from app.core.rate_limiter import limiter, rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

app = FastAPI(
    title="Emlakdefter SaaS API",
    description="Emlak Yönetim Uygulaması Backend Servisleri",
    version="1.0.0"
)

# Rate limiter state
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, rate_limit_exceeded_handler)

# CORS yetkileri (Geliştirme aşamasında her şeye açık)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
async def root():
    return {"message": "Emlakdefter API Sistemleri Başarıyla Çalışıyor!"}

@app.on_event("startup")
async def startup_event():
    # Sunucu başlarken Firebase Admin SDK Mock veya Gerçek moda geçer
    init_firebase()

    # WebSocket Redis Pub/Sub başlat (PRD §4.1.8 - Çoklu worker desteği)
    from app.core.websocket_manager import ws_manager
    await ws_manager.init()

    # Faz 5: Kira Borçlarını Tutan Takvim Motoru Uyanır (Arka Plan - Thread)
    from app.core.scheduler import start_scheduler
    start_scheduler()

@app.on_event("shutdown")
async def shutdown_event():
    # WebSocket Redis bağlantısını kapat
    from app.core.websocket_manager import ws_manager
    await ws_manager.close()

# Oluşturduğumuz uç noktaları sisteme bağlıyoruz
app.include_router(api_router, prefix="/api/v1")

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "service": "Emlakdefter Core API",
        "api_documentation": "/docs"
    }
