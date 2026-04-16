"""
Redis Pub/Sub WebSocket Yöneticisi

PRD §4.1.8 ve §3.3: Çoklu çekirdekli (worker) FastAPI mimarisinde sorunsuz
ölçeklenebilmesi için WebSocket altyapısı Redis (Pub/Sub) ile desteklenir.

Bu modül:
1. Her worker'da WebSocket bağlantılarını yönetir (in-memory)
2. Mesajları Redis'e publish eder
3. Redis Pub/Sub üzerinden diğer worker'lardan gelen mesajları alır
4. Böylece ikinci bir worker'da bağlı olan kullanıcılar da mesajları anında alır
"""

import os
import asyncio
import json
import logging
from typing import Dict, List, Callable
from contextlib import asynccontextmanager

import redis.asyncio as redis
from fastapi import WebSocket

logger = logging.getLogger(__name__)

REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379")


class RedisWebSocketManager:
    """
    Redis Pub/Sub destekli WebSocket bağlantı yöneticisi.

    Çalışma mantığı:
    1. Her worker, bağlı WebSocket'leri kendi memory'sinde tutar
    2. Bir mesaj gönderildiğinde Redis'e publish edilir
    3. Redis, tüm worker'lara aynı mesajı dağıtır
    4. Her worker, kendi memory'sindeki bağlantılara mesajı gönderir
    """

    def __init__(self):
        self._local_connections: Dict[str, List[WebSocket]] = {}  # worker-local
        self._redis: redis.Redis | None = None
        self._pubsub: redis.client.PubSub | None = None
        self._listener_task: asyncio.Task | None = None
        self._running = False

    async def init(self):
        """Redis bağlantısını başlatır ve listener'ı çalıştırır."""
        if self._redis is None:
            self._redis = redis.from_url(
                REDIS_URL,
                encoding="utf-8",
                decode_responses=True
            )
            self._pubsub = self._redis.pubsub()
            self._running = True
            self._listener_task = asyncio.create_task(self._redis_listener())
            logger.info("[WebSocket] Redis Pub/Sub başlatıldı")

    async def close(self):
        """Redis bağlantısını ve listener'ı kapatır."""
        self._running = False
        if self._listener_task:
            self._listener_task.cancel()
            try:
                await self._listener_task
            except asyncio.CancelledError:
                pass
        if self._pubsub:
            await self._pubsub.close()
        if self._redis:
            await self._redis.close()
        logger.info("[WebSocket] Redis bağlantısı kapatıldı")

    async def _redis_listener(self):
        """
        Arka planda Redis'ten gelen mesajları dinler.
        Bu fonksiyon sürekli çalışır ve Redis'ten gelen broadcast mesajlarını
        yerel WebSocket bağlantılarına yönlendirir.
        """
        while self._running:
            try:
                if self._pubsub is None:
                    break
                message = await self._pubsub.get_message(
                    ignore_subscribe_messages=True,
                    timeout=1.0
                )
                if message:
                    channel = message.get("channel")
                    data = message.get("data")
                    if channel and data:
                        try:
                            payload = json.loads(data)
                            conversation_id = payload.get("conversation_id")
                            if conversation_id:
                                await self._broadcast_local(conversation_id, payload)
                        except json.JSONDecodeError:
                            logger.warning(f"[WebSocket] Geçersiz JSON mesajı: {data}")
                await asyncio.sleep(0.01)  # CPU usage azalt
            except asyncio.CancelledError:
                break
            except Exception as e:
                logger.error(f"[WebSocket] Redis listener hatası: {e}")
                await asyncio.sleep(1)

    async def _broadcast_local(self, conversation_id: str, message_data: dict):
        """Yerel (bu worker'daki) WebSocket bağlantılarına broadcast eder."""
        if conversation_id in self._local_connections:
            disconnected = []
            for ws in self._local_connections[conversation_id]:
                try:
                    await ws.send_json(message_data)
                except Exception:
                    disconnected.append(ws)
            # Ölen bağlantıları temizle
            for ws in disconnected:
                self.disconnect(ws, conversation_id)

    async def connect(self, websocket: WebSocket, conversation_id: str):
        """Yeni WebSocket bağlantısı kabul eder ve Redis'e abone olur."""
        await websocket.accept()

        # Yerel bağlantıya ekle
        if conversation_id not in self._local_connections:
            self._local_connections[conversation_id] = []
            # Yeni bir conversation için Redis'e abone ol
            if self._pubsub:
                await self._pubsub.subscribe(conversation_id)
                logger.info(f"[WebSocket] Redis abone oldu: {conversation_id}")

        self._local_connections[conversation_id].append(websocket)
        logger.info(f"[WebSocket] Bağlandı: {conversation_id}, toplam: {len(self._local_connections[conversation_id])}")

    def disconnect(self, websocket: WebSocket, conversation_id: str):
        """WebSocket bağlantısını kaldırır."""
        if conversation_id in self._local_connections:
            if websocket in self._local_connections[conversation_id]:
                self._local_connections[conversation_id].remove(websocket)
            if not self._local_connections[conversation_id]:
                del self._local_connections[conversation_id]
                # Conversation boşaldığında Redis aboneliğini kaldır
                if self._pubsub and self._running:
                    asyncio.create_task(self._pubsub.unsubscribe(conversation_id))
                logger.info(f"[WebSocket] Abonelik kaldırıldı: {conversation_id}")

    async def broadcast_to_room(self, message_data: dict, conversation_id: str):
        """
        Mesajı hem yerel bağlantılara hem Redis'e broadcast eder.
        Böylece tüm worker'lardaki istemciler mesajı alır.
        """
        # Önce yerel broadcast (hızlı)
        await self._broadcast_local(conversation_id, message_data)

        # Sonra Redis'e publish et (diğer worker'lar için)
        if self._redis and self._running:
            try:
                await self._redis.publish(
                    conversation_id,
                    json.dumps(message_data, default=str)
                )
            except Exception as e:
                logger.error(f"[WebSocket] Redis publish hatası: {e}")

    @asynccontextmanager
    async def lifespan(self):
        """Context manager olarak kullanım için lifespan yönetimi."""
        await self.init()
        try:
            yield self
        finally:
            await self.close()


# Global manager instance
# Her worker'da bir tane oluşturulur
ws_manager = RedisWebSocketManager()
