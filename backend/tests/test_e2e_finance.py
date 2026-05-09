"""
Test 5: Finance E2E Testleri

/api/v1/finance/* endpoint'lerini test eder.
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


class TestFinanceEndpoints:
    """Finance endpoint testleri."""

    @pytest_asyncio.fixture
    async def client(self):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test", follow_redirects=True) as ac:
            yield ac

    @pytest.mark.asyncio
    async def test_get_transactions_requires_auth(self, client):
        """GET /api/v1/finance/transactions → auth yoksa 401"""
        response = await client.get("/api/v1/finance/transactions")
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_get_monthly_stats_requires_auth(self, client):
        """GET /api/v1/finance/monthly-stats → auth yoksa 401"""
        response = await client.get("/api/v1/finance/monthly-stats")
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_get_category_breakdown_requires_auth(self, client):
        """GET /api/v1/finance/category-breakdown → auth yoksa 401"""
        response = await client.get("/api/v1/finance/category-breakdown")
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_get_payment_schedules_requires_auth(self, client):
        """GET /api/v1/finance/payment-schedules → auth yoksa 401"""
        response = await client.get("/api/v1/finance/payment-schedules")
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_upload_statement_requires_auth(self, client):
        """POST /api/v1/finance/upload-statement → auth yoksa 401"""
        response = await client.post("/api/v1/finance/upload-statement", files={"file": b"%PDF-1.4", "period": "2026-01"})
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_create_transaction_requires_auth(self, client):
        """POST /api/v1/finance/transactions → auth yoksa 401"""
        response = await client.post("/api/v1/finance/transactions", json={})
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_create_expense_requires_auth(self, client):
        """POST /api/v1/finance/expenses → auth yoksa 401"""
        response = await client.post("/api/v1/finance/expenses", json={})
        assert response.status_code == 401
