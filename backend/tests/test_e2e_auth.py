"""
Test 1: Auth Endpoint E2E Testleri

/api/v1/auth/* endpoint'lerini test eder.
Backend'in çalışıyor olması gerekiyor (port 8000).

Not: Test database'de gerçek kullanıcı olmadığı için login/test_auth_me
 gibi gerçek auth gerektiren testler 404/401 alır.
 Bu testler endpoint'in DOĞRU çalışıp çalışmadığını doğrular.
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


class TestAuthEndpoints:
    """Auth endpoint testleri."""

    @pytest_asyncio.fixture
    async def client(self):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as ac:
            yield ac

    @pytest.mark.asyncio
    async def test_login_unknown_user(self, client):
        """POST /api/v1/auth/login → bilinmeyen kullanıcı 404 döner"""
        payload = {
            "email_or_phone": "nobody@emlakdefter.com",
            "password": "anypassword"
        }
        response = await client.post("/api/v1/auth/login", json=payload)
        # Kullanıcı bulunamazsa 404
        assert response.status_code == 404

    @pytest.mark.asyncio
    async def test_login_missing_field(self, client):
        """POST /api/v1/auth/login → eksik field 422 döner"""
        payload = {"password": "onlypassword"}
        response = await client.post("/api/v1/auth/login", json=payload)
        assert response.status_code == 422

    @pytest.mark.asyncio
    async def test_send_otp_invalid_phone(self, client):
        """POST /api/v1/auth/send-otp → geçersiz telefon formatı 422 döner"""
        response = await client.post("/api/v1/auth/send-otp", json={
            "phone": "not-a-phone"
        })
        assert response.status_code in [400, 422]

    @pytest.mark.asyncio
    async def test_verify_otp_missing_fields(self, client):
        """POST /api/v1/auth/verify-otp → eksik field 422 döner"""
        response = await client.post("/api/v1/auth/verify-otp", json={
            "phone": "+905551234567"
            # code yok
        })
        assert response.status_code == 422

    @pytest.mark.asyncio
    async def test_password_login_validation(self, client):
        """POST /api/v1/auth/password-login → eksik field 422 döner"""
        response = await client.post("/api/v1/auth/password-login", json={
            "password": "onlypassword"
        })
        assert response.status_code == 422

    @pytest.mark.asyncio
    async def test_forgot_password_validation(self, client):
        """POST /api/v1/auth/forgot-password → eksik field 422 döner"""
        response = await client.post("/api/v1/auth/forgot-password", json={})
        assert response.status_code == 422

    @pytest.mark.asyncio
    async def test_reset_password_validation(self, client):
        """POST /api/v1/auth/reset-password → eksik field 422 döner"""
        response = await client.post("/api/v1/auth/reset-password", json={
            "new_password": "onlypassword"
            # token yok
        })
        assert response.status_code == 422

    @pytest.mark.asyncio
    async def test_invite_validation(self, client):
        """POST /api/v1/auth/invite → eksik field 422 döner"""
        response = await client.post("/api/v1/auth/invite", json={})
        assert response.status_code == 422

    @pytest.mark.asyncio
    async def test_login_firebase_validation(self, client):
        """POST /api/v1/auth/login/firebase → eksik field 422 döner"""
        response = await client.post("/api/v1/auth/login/firebase", json={})
        assert response.status_code == 422

    @pytest.mark.asyncio
    async def test_fcm_token_validation(self, client):
        """POST /api/v1/auth/fcm-token → eksik field 422 döner"""
        response = await client.post("/api/v1/auth/fcm-token", json={
            "token": "only-token"
            # platform yok
        })
        assert response.status_code == 422

    @pytest.mark.asyncio
    async def test_auth_me_no_token(self, client):
        """GET /api/v1/auth/me → token olmadan 401/403 döner"""
        response = await client.get("/api/v1/auth/me")
        assert response.status_code in [401, 403]

    @pytest.mark.asyncio
    async def test_auth_me_invalid_token(self, client):
        """GET /api/v1/auth/me → geçersiz token 401/403 döner"""
        response = await client.get("/api/v1/auth/me", headers={"Authorization": "Bearer invalid-token"})
        assert response.status_code in [401, 403]
