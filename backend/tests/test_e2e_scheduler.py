"""
APScheduler & Export Endpoint Testleri

/api/v1/scheduler/* ve /api/v1/analytics/* endpoint'lerini test eder.
"""
import pytest
import pytest_asyncio
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from dotenv import load_dotenv
load_dotenv()

from httpx import AsyncClient, ASGITransport
from app.main import app


class TestSchedulerEndpoints:
    """Scheduler endpoint testleri."""

    @pytest_asyncio.fixture
    async def client(self):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test", follow_redirects=True) as ac:
            yield ac

    @pytest.mark.asyncio
    async def test_scheduler_status_requires_auth(self, client):
        """GET /api/v1/scheduler/scheduler/status → auth yoksa 401"""
        response = await client.get("/api/v1/scheduler/scheduler/status")
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_scheduler_stats_requires_auth(self, client):
        """GET /api/v1/scheduler/scheduler/stats → auth yoksa 401"""
        response = await client.get("/api/v1/scheduler/scheduler/stats")
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_trigger_monthly_dues_requires_auth(self, client):
        """POST /api/v1/scheduler/scheduler/trigger/monthly-dues → auth yoksa 401"""
        response = await client.post("/api/v1/scheduler/scheduler/trigger/monthly-dues", json={})
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_trigger_payment_reminders_requires_auth(self, client):
        """POST /api/v1/scheduler/scheduler/trigger/payment-reminders → auth yoksa 401"""
        response = await client.post("/api/v1/scheduler/scheduler/trigger/payment-reminders", json={})
        assert response.status_code == 401


class TestExportEndpoints:
    """Excel/PDF export endpoint testleri."""

    @pytest_asyncio.fixture
    async def client(self):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test", follow_redirects=True) as ac:
            yield ac

    @pytest.mark.asyncio
    async def test_export_transactions_requires_auth(self, client):
        """GET /api/v1/finance/transactions/export → auth yoksa 401"""
        response = await client.get("/api/v1/finance/transactions/export")
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_export_bi_analytics_requires_auth(self, client):
        """GET /api/v1/analytics/bi/export → auth yoksa 401"""
        response = await client.get("/api/v1/analytics/bi/export")
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_upload_statement_requires_auth(self, client):
        """POST /api/v1/finance/upload-statement → auth yoksa 401"""
        response = await client.post("/api/v1/finance/upload-statement", files={"file": b"%PDF-1.4", "period": "2026-01"})
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_analytics_bi_dashboard_requires_auth(self, client):
        """GET /api/v1/analytics/bi-dashboard → auth yoksa 401"""
        response = await client.get("/api/v1/analytics/bi-dashboard")
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_analytics_bi_portfolio_requires_auth(self, client):
        """GET /api/v1/analytics/bi/portfolio → auth yoksa 401"""
        response = await client.get("/api/v1/analytics/bi/portfolio")
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_analytics_bi_financial_requires_auth(self, client):
        """GET /api/v1/analytics/bi/financial → auth yoksa 401"""
        response = await client.get("/api/v1/analytics/bi/financial")
        assert response.status_code == 401
