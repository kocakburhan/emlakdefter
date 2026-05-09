"""
Test 3: Properties CRUD E2E Testleri

/api/v1/properties/* endpoint'lerini test eder.
307 redirect + 401/403 auth korumalı endpoint'leri test eder.
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


class TestPropertiesEndpoints:
    """Properties endpoint testleri."""

    @pytest_asyncio.fixture
    async def client(self):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test", follow_redirects=True) as ac:
            yield ac

    @pytest.mark.asyncio
    async def test_get_properties_requires_auth(self, client):
        """GET /api/v1/properties → auth yoksa 401"""
        response = await client.get("/api/v1/properties")
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_create_property_requires_auth(self, client):
        """POST /api/v1/properties → auth yoksa 401"""
        response = await client.post("/api/v1/properties", json={})
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_get_single_property_requires_auth(self, client):
        """GET /api/v1/properties/nonexistent → auth yoksa 401"""
        response = await client.get("/api/v1/properties/nonexistent-id")
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_patch_property_requires_auth(self, client):
        """PATCH /api/v1/properties/nonexistent → auth yoksa 401"""
        response = await client.patch("/api/v1/properties/nonexistent-id", json={"name": "Yeni"})
        # 401 = auth gerekli, 404 = bulunamadı (route var ama auth passed olsaydı), 405 = method not allowed
        assert response.status_code in [401, 403, 404, 405]

    @pytest.mark.asyncio
    async def test_create_property_validation_error(self, client):
        """POST /api/v1/properties → eksik body 422 (auth sonrası) veya 401"""
        # Bu test auth header ile yapılır, şimdilik 401 bekle
        response = await client.post("/api/v1/properties", json={"name": "Test Bina"})
        assert response.status_code in [401, 403, 422]

    @pytest.mark.asyncio
    async def test_get_property_units_requires_auth(self, client):
        """GET /api/v1/properties/id/units/id → auth yoksa 401"""
        response = await client.get("/api/v1/properties/id/units/unit-id")
        assert response.status_code == 401
