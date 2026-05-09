"""
Test 6: Operations E2E Testleri

/api/v1/operations/* endpoint'lerini test eder.
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


class TestOperationsEndpoints:
    """Operations endpoint testleri."""

    @pytest_asyncio.fixture
    async def client(self):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test", follow_redirects=True) as ac:
            yield ac

    @pytest.mark.asyncio
    async def test_get_tickets_requires_auth(self, client):
        """GET /api/v1/operations/tickets → auth yoksa 401"""
        response = await client.get("/api/v1/operations/tickets")
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_create_ticket_requires_auth(self, client):
        """POST /api/v1/operations/tickets → auth yoksa 401"""
        response = await client.post("/api/v1/operations/tickets", json={})
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_patch_ticket_requires_auth(self, client):
        """PATCH /api/v1/operations/tickets/id → auth yoksa 401"""
        response = await client.patch("/api/v1/operations/tickets/some-id", json={})
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_dashboard_kpi_requires_auth(self, client):
        """GET /api/v1/operations/dashboard-kpi → auth yoksa 401"""
        response = await client.get("/api/v1/operations/dashboard-kpi")
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_get_building_logs_requires_auth(self, client):
        """GET /api/v1/operations/building-logs → auth yoksa 401"""
        response = await client.get("/api/v1/operations/building-logs")
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_create_building_log_requires_auth(self, client):
        """POST /api/v1/operations/building-logs → auth yoksa 401"""
        response = await client.post("/api/v1/operations/building-logs", json={})
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_patch_building_log_requires_auth(self, client):
        """PATCH /api/v1/operations/building-logs/id → auth yoksa 401"""
        response = await client.patch("/api/v1/operations/building-logs/some-id", json={})
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_get_activity_feed_requires_auth(self, client):
        """GET /api/v1/operations/activity-feed → auth yoksa 401"""
        response = await client.get("/api/v1/operations/activity-feed")
        assert response.status_code == 401
