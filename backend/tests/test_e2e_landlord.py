"""
Test 9: Landlord Endpoint E2E Testleri

/api/v1/landlord/* endpoint'lerini test eder.
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


class TestLandlordEndpoints:
    """Landlord endpoint testleri."""

    @pytest_asyncio.fixture
    async def client(self):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test", follow_redirects=True) as ac:
            yield ac

    @pytest.mark.asyncio
    async def test_landlord_dashboard_requires_auth(self, client):
        """GET /api/v1/landlord/dashboard → auth yoksa 401"""
        response = await client.get("/api/v1/landlord/dashboard")
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_landlord_properties_requires_auth(self, client):
        """GET /api/v1/landlord/properties → auth yoksa 401"""
        response = await client.get("/api/v1/landlord/properties")
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_landlord_units_requires_auth(self, client):
        """GET /api/v1/landlord/units → auth yoksa 401"""
        response = await client.get("/api/v1/landlord/units")
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_landlord_tenants_requires_auth(self, client):
        """GET /api/v1/landlord/tenants → auth yoksa 401"""
        response = await client.get("/api/v1/landlord/tenants")
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_landlord_tenant_tickets_requires_auth(self, client):
        """GET /api/v1/landlord/tenant-tickets → auth yoksa 401"""
        response = await client.get("/api/v1/landlord/tenant-tickets")
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_landlord_operations_requires_auth(self, client):
        """GET /api/v1/landlord/operations → auth yoksa 401"""
        response = await client.get("/api/v1/landlord/operations")
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_landlord_vacant_units_requires_auth(self, client):
        """GET /api/v1/landlord/vacant-units → auth yoksa 401"""
        response = await client.get("/api/v1/landlord/vacant-units")
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_landlord_create_conversation_requires_auth(self, client):
        """POST /api/v1/landlord/conversations → auth yoksa 401"""
        response = await client.post("/api/v1/landlord/conversations", json={})
        assert response.status_code == 401
