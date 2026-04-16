from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from datetime import date, timedelta
import uuid

from app.api import deps
from app.models.users import User
from app.models.tenants import Tenant, ContractStatus
from app.models.finance import PaymentSchedule, TransactionCategory, PaymentStatus, FinancialTransaction, TransactionType
from app.core.scheduler import scheduler, generate_monthly_dues, send_payment_reminders
from pydantic import BaseModel
from typing import List, Optional

router = APIRouter()


# ──────────────────────────────────────────────
# SCHEDULED JOBS STATUS & MANAGEMENT
# ──────────────────────────────────────────────

class ScheduledJobResponse(BaseModel):
    id: str
    name: str
    next_run: Optional[str]
    pending_runs: int
    active: bool


class SchedulerStatusResponse(BaseModel):
    running: bool
    jobs: List[ScheduledJobResponse]
    last_payment_check: Optional[str] = None


@router.get("/scheduler/status", response_model=SchedulerStatusResponse)
async def get_scheduler_status(
    current_user: User = Depends(deps.get_current_user),
    agency_id: uuid.UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(deps.get_db),
):
    """Mevcut arka plan işlerinin durumunu ve takvim istatistiklerini döner."""
    jobs = []
    for job in scheduler.get_jobs():
        jobs.append(ScheduledJobResponse(
            id=job.id,
            name=job.name,
            next_run=job.next_run_time.isoformat() if job.next_run_time else None,
            pending_runs=0,  # APScheduler doesn't expose this easily
            active=job.next_run_time is not None,
        ))

    return SchedulerStatusResponse(
        running=scheduler.running,
        jobs=jobs,
    )


@router.post("/scheduler/trigger/monthly-dues")
async def trigger_monthly_dues(
    current_user: User = Depends(deps.get_current_user),
    agency_id: uuid.UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(deps.get_db),
):
    """Manuel olarak aylık kira tahakkuku üretimini tetikler (Test/Debug)."""
    await generate_monthly_dues()

    # Kaç yeni tahakkuk oluştuğunu raporla
    today = date.today()
    result = await db.execute(
        select(func.count(PaymentSchedule.id)).where(
            PaymentSchedule.due_date == today,
            PaymentSchedule.status == PaymentStatus.pending,
        )
    )
    count = result.scalar() or 0

    return {
        "success": True,
        "message": f"Aylık tahakkuk üretimi manuel olarak tetiklendi. {count} yeni borç kaydı oluşturuldu."
    }


@router.post("/scheduler/trigger/payment-reminders")
async def trigger_payment_reminders(
    current_user: User = Depends(deps.get_current_user),
    agency_id: uuid.UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(deps.get_db),
):
    """Manuel olarak ödeme hatırlatıcılarını gönderir (Test/Debug)."""
    await send_payment_reminders()
    return {
        "success": True,
        "message": "Ödeme hatırlatıcıları tetiklendi. FCM bildirimleri gönderildi (logları kontrol edin)."
    }


# ──────────────────────────────────────────────
# SCHEDULER STATISTICS (Dashboard Widget)
# ──────────────────────────────────────────────

class SchedulerStatsResponse(BaseModel):
    total_active_tenants: int
    pending_schedules_this_month: int
    overdue_count: int
    upcoming_3_days: int
    next_scheduled_run: Optional[str]


@router.get("/scheduler/stats", response_model=SchedulerStatsResponse)
async def get_scheduler_stats(
    current_user: User = Depends(deps.get_current_user),
    agency_id: uuid.UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(deps.get_db),
):
    """Scheduler istatistiklerini döner — Dashboard widget için."""
    today = date.today()
    first_of_month = date(today.year, today.month, 1)
    three_days_later = today + timedelta(days=3)

    # Aktif kiracı sayısı
    tenants_result = await db.execute(
        select(func.count(Tenant.id)).where(
            Tenant.agency_id == agency_id,
            Tenant.status == ContractStatus.active,
        )
    )
    active_tenants = tenants_result.scalar() or 0

    # Bu ay oluşturulan pending schedule'lar
    pending_result = await db.execute(
        select(func.count(PaymentSchedule.id)).where(
            PaymentSchedule.agency_id == agency_id,
            PaymentSchedule.due_date >= first_of_month,
            PaymentSchedule.status == PaymentStatus.pending,
        )
    )
    pending_this_month = pending_result.scalar() or 0

    # Gecikmiş ödemeler
    overdue_result = await db.execute(
        select(func.count(PaymentSchedule.id)).where(
            PaymentSchedule.agency_id == agency_id,
            PaymentSchedule.status == PaymentStatus.pending,
            PaymentSchedule.due_date < today,
        )
    )
    overdue_count = overdue_result.scalar() or 0

    # 3 gün içinde vadesi gelenler
    upcoming_result = await db.execute(
        select(func.count(PaymentSchedule.id)).where(
            PaymentSchedule.agency_id == agency_id,
            PaymentSchedule.status == PaymentStatus.pending,
            PaymentSchedule.due_date >= today,
            PaymentSchedule.due_date <= three_days_later,
        )
    )
    upcoming_3_days = upcoming_result.scalar() or 0

    # Sonraki planlı çalışma
    next_run = None
    for job in scheduler.get_jobs():
        if job.next_run_time:
            if next_run is None or job.next_run_time < next_run:
                next_run = job.next_run_time

    return SchedulerStatsResponse(
        total_active_tenants=active_tenants,
        pending_schedules_this_month=pending_this_month,
        overdue_count=overdue_count,
        upcoming_3_days=upcoming_3_days,
        next_scheduled_run=next_run.isoformat() if next_run else None,
    )