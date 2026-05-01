"""
Test 6: APScheduler Otonom Görevleri

Test kapsamı:
1. generate_monthly_dues() — aktif kiracı kontratlarından PaymentSchedule oluşturma
2. send_payment_reminders() — 3 gün içinde vadesi gelen + geçmiş ödemeler için FCM bildirimi
3. Scheduler cron konfigürasyonu
"""

import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from datetime import date, timedelta
from apscheduler.triggers.cron import CronTrigger

from app.models.tenants import ContractStatus
from app.models.finance import TransactionCategory, PaymentStatus


class TestGenerateMonthlyDues:
    """generate_monthly_dues() — Her ayın 1'inde çalışır"""

    @pytest.mark.asyncio
    async def test_creates_payment_schedule_for_active_tenant_same_payment_day(self):
        """Bugün kiracının ödeme gününe denk geliyorsa PaymentSchedule oluşturulmalı"""
        today = date.today()
        current_day = today.day

        mock_db = AsyncMock()
        mock_tenant = MagicMock()
        mock_tenant.id = "tenant-uuid-1"
        mock_tenant.agency_id = "agency-uuid-1"
        mock_tenant.status = ContractStatus.active
        mock_tenant.payment_day = current_day  # Bugün ödeme günü
        mock_tenant.rent_amount = 5000

        mock_scalars = MagicMock()
        mock_scalars.all.return_value = [mock_tenant]

        mock_result = MagicMock()
        mock_result.scalars.return_value = mock_scalars

        mock_db.execute.return_value = mock_result
        mock_db.add_all = MagicMock()
        mock_db.commit = AsyncMock()

        with patch("app.core.scheduler.AsyncSessionLocal") as mock_session:
            mock_session.return_value.__aenter__.return_value = mock_db
            mock_session.return_value.__aexit__.return_value = None

            # Import here to avoid module-level side effects
            from app.core.scheduler import generate_monthly_dues
            await generate_monthly_dues()

            assert mock_db.add_all.called
            added_schedules = mock_db.add_all.call_args[0][0]
            assert len(added_schedules) == 1
            assert added_schedules[0].amount == 5000
            assert added_schedules[0].category == TransactionCategory.rent
            assert added_schedules[0].status == PaymentStatus.pending

    @pytest.mark.asyncio
    async def test_no_schedule_when_payment_day_not_matched(self):
        """Ödeme günü bugün değilse schedule oluşturulmamalı"""
        mock_db = AsyncMock()

        mock_tenant = MagicMock()
        mock_tenant.status = ContractStatus.active
        mock_tenant.payment_day = 15  # Bugün değil
        mock_tenant.rent_amount = 5000

        mock_scalars = MagicMock()
        mock_scalars.all.return_value = [mock_tenant]

        mock_result = MagicMock()
        mock_result.scalars.return_value = mock_scalars
        mock_db.execute.return_value = mock_result

        with patch("app.core.scheduler.AsyncSessionLocal") as mock_session:
            mock_session.return_value.__aenter__.return_value = mock_db
            mock_session.return_value.__aexit__.return_value = None

            from app.core.scheduler import generate_monthly_dues
            await generate_monthly_dues()

            assert not mock_db.add_all.called

    @pytest.mark.asyncio
    async def test_no_schedule_when_rent_zero(self):
        """Kiracının kira bedeli 0 ise schedule oluşturulmamalı"""
        mock_db = AsyncMock()

        mock_tenant = MagicMock()
        mock_tenant.status = ContractStatus.active
        mock_tenant.payment_day = date.today().day
        mock_tenant.rent_amount = 0  # Kira yok

        mock_scalars = MagicMock()
        mock_scalars.all.return_value = [mock_tenant]

        mock_result = MagicMock()
        mock_result.scalars.return_value = mock_scalars
        mock_db.execute.return_value = mock_result

        with patch("app.core.scheduler.AsyncSessionLocal") as mock_session:
            mock_session.return_value.__aenter__.return_value = mock_db
            mock_session.return_value.__aexit__.return_value = None

            from app.core.scheduler import generate_monthly_dues
            await generate_monthly_dues()

            assert not mock_db.add_all.called

    @pytest.mark.asyncio
    async def test_multiple_active_tenants_all_get_schedules(self):
        """Birden fazla aktif kiracı varsa hepsi için schedule oluşmalı"""
        mock_db = AsyncMock()
        today = date.today()

        tenants = []
        for i in range(3):
            t = MagicMock()
            t.id = f"tenant-{i}"
            t.agency_id = "agency-1"
            t.status = ContractStatus.active
            t.payment_day = today.day
            t.rent_amount = 3000 * (i + 1)
            tenants.append(t)

        mock_scalars = MagicMock()
        mock_scalars.all.return_value = tenants

        mock_result = MagicMock()
        mock_result.scalars.return_value = mock_scalars
        mock_db.execute.return_value = mock_result
        mock_db.add_all = MagicMock()

        with patch("app.core.scheduler.AsyncSessionLocal") as mock_session:
            mock_session.return_value.__aenter__.return_value = mock_db
            mock_session.return_value.__aexit__.return_value = None

            from app.core.scheduler import generate_monthly_dues
            await generate_monthly_dues()

            added = mock_db.add_all.call_args[0][0]
            assert len(added) == 3


class TestSendPaymentReminders:
    """send_payment_reminders() — FCM bildirimleri"""

    def _setup_mock_db(self, mock_db, schedules):
        """Helper: mock DB for send_payment_reminders"""
        mock_scalars = MagicMock()
        mock_scalars.all.return_value = schedules

        mock_result = MagicMock()
        mock_result.scalars.return_value = mock_scalars

        # Her execute çağrısı için döndürülecek sonuçlar
        mock_db.execute.return_value = mock_result

    def _make_mock_tenant(self):
        t = MagicMock()
        t.user_id = "user-1"
        return t

    def _make_mock_schedule(self, due_date, amount=5000):
        s = MagicMock()
        s.id = "schedule-1"
        s.tenant_id = "tenant-1"
        s.due_date = due_date
        s.amount = amount
        s.category = TransactionCategory.rent
        s.status = PaymentStatus.pending
        return s

    @pytest.mark.asyncio
    async def test_sends_notification_for_upcoming_payment(self):
        """3 gün içinde vadesi gelen ödeme için FCM çağrılmalı"""
        mock_db = AsyncMock()
        today = date.today()
        mock_schedule = self._make_mock_schedule(today + timedelta(days=2), 5000)

        # Setup mock scalars for each execute call
        # 1. upcoming_stmt -> [schedule]
        upcoming_scalars = MagicMock()
        upcoming_scalars.all.return_value = [mock_schedule]

        upcoming_result = MagicMock()
        upcoming_result.scalars.return_value = upcoming_scalars

        # 2. tenant_stmt -> tenant
        tenant_scalars = MagicMock()
        tenant_scalars.scalar_one_or_none.return_value = self._make_mock_tenant()

        tenant_result = MagicMock()
        # Scheduler kodu tenant_result.scalar_one_or_none() diye doğrudan çağırıyor
        # (scalars().all() değil, scalar_one_or_none()!)
        tenant_result.scalar_one_or_none.return_value = self._make_mock_tenant()
        tenant_result.scalars.return_value = tenant_scalars  # fallback/alternatif yol

        # 3. token_stmt -> tokens
        # Scheduler kodu token_result.fetchall() diye DOĞRUDAN çağırıyor
        # (scalars().fetchall() değil!) — select tek kolon döndürüyor, fetchall tuples verir
        tokens_result = MagicMock()
        tokens_result.fetchall.return_value = [("token-xyz",)]

        # 4. overdue_stmt -> []
        overdue_scalars = MagicMock()
        overdue_scalars.all.return_value = []

        overdue_result = MagicMock()
        overdue_result.scalars.return_value = overdue_scalars

        mock_db.execute.side_effect = [
            upcoming_result,  # upcoming schedules query
            tenant_result,     # tenant lookup
            tokens_result,     # FCM tokens
            overdue_result,    # overdue schedules (empty)
        ]

        with patch("app.core.scheduler.AsyncSessionLocal") as mock_session, \
             patch("app.core.scheduler.send_fcm_notification_to_tokens") as mock_fcm:
            mock_session.return_value.__aenter__.return_value = mock_db
            mock_session.return_value.__aexit__.return_value = None

            from app.core.scheduler import send_payment_reminders
            await send_payment_reminders()

            assert mock_fcm.called, "FCM bildirimi gönderilmeli"

    @pytest.mark.asyncio
    async def test_no_fcm_when_no_pending_payments(self):
        """Bekleyen ödeme yoksa FCM çağrılmamalı"""
        mock_db = AsyncMock()

        mock_scalars = MagicMock()
        mock_scalars.all.side_effect = [[], []]  # Boş sonuçlar

        mock_result = MagicMock()
        mock_result.scalars.return_value = mock_scalars
        mock_db.execute.return_value = mock_result

        with patch("app.core.scheduler.AsyncSessionLocal") as mock_session, \
             patch("app.core.scheduler.send_fcm_notification_to_tokens") as mock_fcm:
            mock_session.return_value.__aenter__.return_value = mock_db
            mock_session.return_value.__aexit__.return_value = None

            from app.core.scheduler import send_payment_reminders
            await send_payment_reminders()

            assert not mock_fcm.called

    @pytest.mark.asyncio
    async def test_no_fcm_when_no_fcm_tokens(self):
        """Token yoksa FCM çağrılmamalı"""
        mock_db = AsyncMock()
        mock_schedule = self._make_mock_schedule(date.today() + timedelta(days=1))

        mock_tenant = self._make_mock_tenant()
        tenant_result = MagicMock()
        tenant_result.scalar_one_or_none.return_value = mock_tenant

        tokens_result = MagicMock()
        tokens_result.fetchall.return_value = []  # Boş token listesi

        mock_scalars = MagicMock()
        mock_scalars.all.side_effect = [
            [mock_schedule],
            tenant_result,
            tokens_result,
        ]

        mock_result = MagicMock()
        mock_result.scalars.return_value = mock_scalars
        mock_db.execute.return_value = mock_result

        with patch("app.core.scheduler.AsyncSessionLocal") as mock_session, \
             patch("app.core.scheduler.send_fcm_notification_to_tokens") as mock_fcm:
            mock_session.return_value.__aenter__.return_value = mock_db
            mock_session.return_value.__aexit__.return_value = None

            from app.core.scheduler import send_payment_reminders
            await send_payment_reminders()

            assert not mock_fcm.called, "Token yoksa FCM çağrılmamalı"


class TestSchedulerConfiguration:
    """APScheduler cron job konfigürasyonu"""

    def test_start_scheduler_registers_jobs(self):
        """start_scheduler çağrılınca 2 job eklenmeli"""
        import sys
        from app.core import scheduler as scheduler_module
        from app.core.scheduler import scheduler, start_scheduler

        scheduler.remove_all_jobs()
        scheduler_module._scheduler_started = False  # Reset for isolated test

        # scheduler.start() bir event loop gerektirir — test ortamında patch et
        with patch.object(scheduler, 'start', return_value=None):
            start_scheduler()
            jobs = scheduler.get_jobs()

        assert len(jobs) == 2, f"Expected 2 jobs, got {len(jobs)}: {[j.name for j in jobs]}"
        scheduler_module._scheduler_started = False  # Reset for next test

    def test_job_names_match_expected_functions(self):
        """Job isimleri doğru fonksiyonlara işaret etmeli"""
        import sys
        from app.core import scheduler as scheduler_module
        from app.core.scheduler import scheduler, start_scheduler

        scheduler.remove_all_jobs()
        scheduler_module._scheduler_started = False  # Reset for isolated test

        with patch.object(scheduler, 'start', return_value=None):
            start_scheduler()
            jobs = scheduler.get_jobs()
            job_names = {j.name for j in jobs}

        assert "generate_monthly_dues" in job_names
        assert "send_payment_reminders" in job_names