from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.api import api_router
from app.core.firebase import init_firebase

app = FastAPI(
    title="Emlakdefteri SaaS API",
    description="Emlak Yönetim Uygulaması Backend Servisleri",
    version="1.0.0"
)

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
    return {"message": "Emlakdefteri API Sistemleri Başarıyla Çalışıyor!"}

@app.on_event("startup")
async def startup_event():
    # Sunucu başlarken Firebase Admin SDK Mock veya Gerçek moda geçer
    init_firebase()
    
    # Faz 5: Kira Borçlarını Tutan Takvim Motoru Uyanır (Arka Plan - Thread)
    from app.core.scheduler import start_scheduler
    start_scheduler()

# Oluşturduğumuz uç noktaları sisteme bağlıyoruz
app.include_router(api_router, prefix="/api/v1")

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "service": "Emlakdefteri Core API",
        "api_documentation": "/docs"
    }
