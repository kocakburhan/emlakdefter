from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import date
import asyncio

from app.database import AsyncSessionLocal
from app.models.tenants import Tenant, ContractStatus
from app.models.finance import PaymentSchedule, TransactionCategory, PaymentStatus

# Tüm Asenkron görevleri takvime bağlayan yönetici (Manager) nesnesi
scheduler = AsyncIOScheduler()

async def generate_monthly_dues():
    """
    Kriti Arka Plan İşlemi:
    Her gece saat tam 01:00'da veritabanındaki tüm açık (Active) kontratları süzerek,
    "Sözleşmenin yıldönümü/ayı dönümü bugün mü?" kontrolü yapar. Eğer denk geliyorsa "Tahakkuk (Pending Borç)" kilitler.
    """
    print("[APScheduler] Otonom Tahakkuk/Borçlandırma Algoritması Uykudan Uyandı...")
    
    today = date.today()
    current_day = today.day
    
    async with AsyncSessionLocal() as db:
        # Tüm Aktif Sözleşmeleri (Tenants) getir
        stmt = select(Tenant).where(Tenant.status == ContractStatus.active)
        result = await db.execute(stmt)
        active_tenants = result.scalars().all()
        
        new_schedules = []
        for t in active_tenants:
            # Kontratın ödeme günü bugüne denk geliyorsa Tahakkuk İşlemi yarat
            if t.payment_day == current_day:
                
                # 1. Rutin Kira Borcunun Sisteme İşlenmesi
                if t.rent_amount and t.rent_amount > 0:
                    rent_debt = PaymentSchedule(
                        agency_id=t.agency_id,
                        tenant_id=t.id,
                        amount=t.rent_amount,
                        due_date=today,
                        category=TransactionCategory.rent,
                        status=PaymentStatus.pending
                    )
                    new_schedules.append(rent_debt)
                
                # İlerleyen safhada "Bina Merkez Aidatı" da t.unit.property.central_dues üzerinden çekilip eklenecektir.
                
        if new_schedules:
            db.add_all(new_schedules)
            await db.commit()
            print(f"[APScheduler] İşlem Başarılı: {len(new_schedules)} yeni kira tahakkuku kiracıların hanesine yazıldı.")
        else:
             print("[APScheduler] Pas geçiliyor: BUGÜN ({}) ödeme listesinde (Due) hiçbir kiracı kontratına saptanmadı.".format(today))

def start_scheduler():
    """FastAPI OnStartup listesinde çağırılacak ateşleme butonu."""
    # (Not: Geliştirme aşamasında her saniye test etmek isterseniz 'CronTrigger' yerine 'IntervalTrigger(seconds=10)' verebiliriz.)
    scheduler.add_job(generate_monthly_dues, CronTrigger(hour=1, minute=0))
    scheduler.start()
    print("[INFO] Arka Plan Botu (APScheduler Cron) sessizce devreye sokuldu.")
