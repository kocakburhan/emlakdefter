from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import date, timedelta
import asyncio
import logging

from app.database import AsyncSessionLocal
from app.models.tenants import Tenant, ContractStatus
from app.models.finance import PaymentSchedule, TransactionCategory, PaymentStatus
from app.models.users import UserDeviceToken
from app.core.firebase import send_fcm_notification_to_tokens

logger = logging.getLogger(__name__)

# Tüm Asenkron görevleri takvime bağlayan yönetici (Manager) nesnesi
scheduler = AsyncIOScheduler()


async def generate_monthly_dues():
    """
    Kriti Arka Plan İşlemi:
    Her gece saat tam 01:00'da veritabanındaki tüm açık (Active) kontratları süzerek,
    "Sözleşmenin yıldönümü/ayı dönümü bugün mü?" kontrolü yapar. Eğer denk geliyorsa "Tahakkuk (Pending Borç)" kilitler.
    PRD §3.3 — APScheduler + FCM Bildirimleri.
    """
    logger.info("[APScheduler] Otonom Tahakkuk/Borçlandırma Algoritması Uykudan Uyandı...")

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
            logger.info(f"[APScheduler] İşlem Başarılı: {len(new_schedules)} yeni kira tahakkuku kiracıların hanesine yazıldı.")
        else:
             logger.info(f"[APScheduler] Pas geçiliyor: BUGÜN ({today}) ödeme listesinde (Due) hiçbir kiracı kontratına saptanmadı.")


async def send_payment_reminders():
    """
    Her gün saat 09:00'da çalışır.
    - 3 gün içinde vadesi gelen ödemeler için "Yaklaşan Ödeme" bildirimi gönderir.
    - Vadesi geçmiş (overdue) ödemeler için "Gecikme" bildirimi gönderir.
    PRD §3.3 — FCM Bildirimleri.
    """
    logger.info("[APScheduler] Ödeme Hatırlatıcıları Kontrol Ediliyor...")

    today = date.today()
    three_days_later = today + timedelta(days=3)

    async with AsyncSessionLocal() as db:
        # === YAKLAŞAN ÖDEMELER (3 gün içinde) ===
        upcoming_stmt = select(PaymentSchedule).where(
            PaymentSchedule.status == PaymentStatus.pending,
            PaymentSchedule.due_date >= today,
            PaymentSchedule.due_date <= three_days_later,
        )
        upcoming_result = await db.execute(upcoming_stmt)
        upcoming_schedules = upcoming_result.scalars().all()

        for schedule in upcoming_schedules:
            tokens = await _get_user_fcm_tokens(db, schedule.tenant_id)
            if tokens:
                days_left = (schedule.due_date - today).days
                title = "Yaklaşan Ödeme Hatırlatması"
                body = (
                    f"{schedule.category.value.title()} ödemeniz {days_left} gün içinde "
                    f"({schedule.due_date.strftime('%d.%m.%Y')}) gerçekleşecek. "
                    f"Tutar: {schedule.amount:,} TL"
                )
                await send_fcm_notification_to_tokens(
                    tokens,
                    title,
                    body,
                    data={"type": "payment_reminder", "schedule_id": str(schedule.id)},
                )
                logger.info(f"[FCM] Yaklaşan ödeme hatırlatması gönderildi: {schedule.id}")

        # === GECİKMİŞ ÖDEMELER (vadesi geçmiş, bugün veya öncesi) ===
        overdue_stmt = select(PaymentSchedule).where(
            PaymentSchedule.status == PaymentStatus.pending,
            PaymentSchedule.due_date < today,
        )
        overdue_result = await db.execute(overdue_stmt)
        overdue_schedules = overdue_result.scalars().all()

        for schedule in overdue_schedules:
            tokens = await _get_user_fcm_tokens(db, schedule.tenant_id)
            if tokens:
                days_overdue = (today - schedule.due_date).days
                title = "Ödemeniz Gecikti!"
                body = (
                    f"{schedule.category.value.title()} ödemeniz {days_overdue} gün gecikmiş. "
                    f"Tutar: {schedule.amount:,} TL. "
                    f"Lütfen en kısa sürede ödeme yapınız."
                )
                await send_fcm_notification_to_tokens(
                    tokens,
                    title,
                    body,
                    data={"type": "payment_overdue", "schedule_id": str(schedule.id)},
                )
                logger.info(f"[FCM] Gecikme bildirimi gönderildi: {schedule.id}")

        logger.info(
            f"[APScheduler] Bildirim döngüsü tamamlandı: "
            f"{len(upcoming_schedules)} yaklaşan, {len(overdue_schedules)} gecikmiş."
        )


async def _get_user_fcm_tokens(db: AsyncSession, tenant_id: str) -> list[str]:
    """Kiracının user_id'sini bularak kayıtlı FCM token'larını döner."""
    # Tenant'ın user_id'sini bul
    tenant_stmt = select(Tenant).where(Tenant.id == tenant_id)
    tenant_result = await db.execute(tenant_stmt)
    tenant = tenant_result.scalar_one_or_none()
    if not tenant:
        return []

    # Kullanıcının tüm FCM token'larını getir
    token_stmt = select(UserDeviceToken.fcm_token).where(
        UserDeviceToken.user_id == tenant.user_id
    )
    token_result = await db.execute(token_stmt)
    tokens = [row[0] for row in token_result.fetchall()]
    return tokens


def start_scheduler():
    """FastAPI OnStartup listesinde çağırılacak ateşleme butonu."""
    # PRD §3.3: Her ay otonom payment_schedules üretimi
    scheduler.add_job(generate_monthly_dues, CronTrigger(hour=1, minute=0))
    # PRD §3.3: FCM bildirimleri — her gün saat 09:00'da
    scheduler.add_job(send_payment_reminders, CronTrigger(hour=9, minute=0))
    scheduler.start()
    logger.info("[INFO] Arka Plan Botu (APScheduler Cron) sessizce devreye sokuldu.")
