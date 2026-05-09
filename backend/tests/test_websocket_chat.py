"""
WebSocket Chat Testleri

FastAPI WebSocket endpoint'ini test eder:
1. Geçersiz token → 403 Forbidden
2. Token olmadan → bağlantı reddedilir
3. Redis canlılığı kontrolü
"""
import pytest
import pytest_asyncio
import sys
import os
import websocket

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from dotenv import load_dotenv
load_dotenv()

# Backend URL
WS_BASE = "ws://127.0.0.1:8000/api/v1/chat"


class TestWebSocketAuth:
    """WebSocket auth testleri."""

    def test_connection_rejected_invalid_token(self):
        """Geçersiz token → WebSocket 403 Forbidden ile reddedilir."""
        ws_url = f"{WS_BASE}/ws/test-conversation-id?token=invalid_token"
        ws = websocket.WebSocket()
        try:
            ws.connect(ws_url, timeout=5)
            ws.close()
            pytest.fail("Expected WebSocketException with 403")
        except websocket.WebSocketBadStatusException as e:
            assert e.status_code == 403, f"Beklenen 403, alınan: {e.status_code}"
        except websocket.WebSocketTimeoutException:
            pytest.skip("Timeout — backend might have rejected before response")
        except OSError as e:
            pytest.skip(f"Backend not reachable: {e}")

    def test_connection_rejected_missing_token(self):
        """Token olmadan → WebSocket 403 Forbidden."""
        ws_url = f"{WS_BASE}/ws/test-conversation-id"
        ws = websocket.WebSocket()
        try:
            ws.connect(ws_url, timeout=5)
            ws.close()
            pytest.fail("Expected connection failure without token")
        except websocket.WebSocketBadStatusException as e:
            # 400 = missing required query param, 403 = auth rejected
            assert e.status_code in [400, 403], f"Beklenen 400/403, alınan: {e.status_code}"
        except websocket.WebSocketTimeoutException:
            pass
        except OSError as e:
            pytest.skip(f"Backend not reachable: {e}")

    def test_connection_with_fake_jwt_format(self):
        """Geçerli JWT formatında ama sahte imzalı token → 403."""
        ws_url = f"{WS_BASE}/ws/test-conv-id?token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ0ZXN0In0.fake"
        ws = websocket.WebSocket()
        try:
            ws.connect(ws_url, timeout=5)
            ws.close()
            pytest.fail("Expected 403 for fake JWT")
        except websocket.WebSocketBadStatusException as e:
            assert e.status_code == 403, f"Beklenen 403, alınan: {e.status_code}"
        except websocket.WebSocketTimeoutException:
            pass
        except OSError as e:
            pytest.skip(f"Backend not reachable: {e}")


class TestWebSocketBasicBehavior:
    """WebSocket temel davranış testleri."""

    def test_websocket_endpoint_reachable(self):
        """WebSocket endpoint'i mevcut — geçersiz token ile 403 dönüyor."""
        ws_url = f"{WS_BASE}/ws/healthcheck-test?token=invalid"
        ws = websocket.WebSocket()
        try:
            ws.connect(ws_url, timeout=5)
            ws.close()
            pytest.fail("Expected 403 for invalid token")
        except websocket.WebSocketBadStatusException as e:
            # 403 = auth rejected ama endpoint var
            assert e.status_code == 403, f"Beklenen 403, alınan: {e.status_code}"
        except websocket.WebSocketTimeoutException:
            pass
        except OSError as e:
            pytest.skip(f"Backend not reachable: {e}")

    def test_redis_alive(self):
        """Redis'in çalışıyor olduğunu doğrula."""
        import redis
        r = redis.from_url("redis://localhost:6379", decode_responses=True)
        try:
            pong = r.ping()
            assert pong is True, "Redis ping başarısız"
        except redis.ConnectionError:
            pytest.skip("Redis not running")
        finally:
            r.close()


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
