"""
Test 7: Chat REST E2E Testleri

/api/v1/chat/* endpoint'lerini test eder.
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


class TestChatEndpoints:
    """Chat endpoint testleri."""

    @pytest_asyncio.fixture
    async def client(self):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test", follow_redirects=True) as ac:
            yield ac

    @pytest.mark.asyncio
    async def test_get_conversations_requires_auth(self, client):
        """GET /api/v1/chat/conversations → auth yoksa 401"""
        response = await client.get("/api/v1/chat/conversations")
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_create_conversation_requires_auth(self, client):
        """POST /api/v1/chat/conversations → auth yoksa 401"""
        response = await client.post("/api/v1/chat/conversations", json={})
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_archive_conversation_requires_auth(self, client):
        """PATCH /api/v1/chat/conversations/id/archive → auth yoksa 401"""
        response = await client.patch("/api/v1/chat/conversations/some-id/archive", json={})
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_get_history_requires_auth(self, client):
        """GET /api/v1/chat/history/id → auth yoksa 401"""
        response = await client.get("/api/v1/chat/history/some-id")
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_send_message_requires_auth(self, client):
        """POST /api/v1/chat/messages → auth yoksa 401"""
        response = await client.post("/api/v1/chat/messages", json={})
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_patch_message_requires_auth(self, client):
        """PATCH /api/v1/chat/messages/id → auth yoksa 401"""
        response = await client.patch("/api/v1/chat/messages/some-id", json={})
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_delete_message_requires_auth(self, client):
        """DELETE /api/v1/chat/messages/id → auth yoksa 401"""
        response = await client.delete("/api/v1/chat/messages/some-id")
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_mark_read_requires_auth(self, client):
        """PATCH /api/v1/chat/messages/id/read → auth yoksa 401"""
        response = await client.patch("/api/v1/chat/messages/some-id/read", json={})
        assert response.status_code == 401
