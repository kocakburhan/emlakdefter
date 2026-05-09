"""
Test 4: Tenants CRUD E2E Testleri

/api/v1/tenants/* ve /api/v1/tenants/landlords/* endpoint'lerini test eder.
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


class TestTenantsEndpoints:
    """Tenants endpoint testleri."""

    @pytest_asyncio.fixture
    async def client(self):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test", follow_redirects=True) as ac:
            yield ac

    @pytest.mark.asyncio
    async def test_get_tenants_requires_auth(self, client):
        """GET /api/v1/tenants → auth yoksa 401"""
        response = await client.get("/api/v1/tenants")
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_create_tenant_requires_auth(self, client):
        """POST /api/v1/tenants → auth yoksa 401"""
        response = await client.post("/api/v1/tenants", json={})
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_get_landlords_requires_auth(self, client):
        """GET /api/v1/tenants/landlords → auth yoksa 401"""
        response = await client.get("/api/v1/tenants/landlords")
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_patch_tenant_requires_auth(self, client):
        """PATCH /api/v1/tenants/id → auth yoksa 401"""
        response = await client.patch("/api/v1/tenants/some-id", json={})
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_deactivate_tenant_requires_auth(self, client):
        """POST /api/v1/tenants/id/deactivate → auth yoksa 401"""
        response = await client.post("/api/v1/tenants/some-id/deactivate", json={})
        assert response.status_code == 401
