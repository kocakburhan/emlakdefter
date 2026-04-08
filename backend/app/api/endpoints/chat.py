from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect, Query, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List, Dict
import uuid

from app.api import deps
from app.models.users import User
from app.models.chat import ChatConversation, ChatMessage
from app.schemas.chat import ChatMessageResponse
from app.database import AsyncSessionLocal
from jose import jwt, JWTError
from app.core.security import SECRET_KEY, ALGORITHM

router = APIRouter()

class ConnectionManager:
    """Faz 6 Canlı İletişim: Sunucunun hafızasında yüzlerce Web/Mobil WebSocket bağlantısını aynı anda ayakta tutan Havuz yöneticisidir!"""
    def __init__(self):
        # Format (Dictionary): "oda_UUIDsi": [kullanici1_socket, kullanici2_socket vb.]
        self.active_connections: Dict[str, List[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, conversation_id: str):
        await websocket.accept()
        if conversation_id not in self.active_connections:
            self.active_connections[conversation_id] = []
        self.active_connections[conversation_id].append(websocket)
        print(f"[WebSocket] Oda {conversation_id[:6]}... yeni bir cihaz katıldı.")

    def disconnect(self, websocket: WebSocket, conversation_id: str):
        if conversation_id in self.active_connections:
             if websocket in self.active_connections[conversation_id]:
                 self.active_connections[conversation_id].remove(websocket)
             if not self.active_connections[conversation_id]: # Oda tamamen boşaldıysa belleği temizle.
                 del self.active_connections[conversation_id]
        print(f"[WebSocket] Bir kullanıcı {conversation_id[:6]}... numuralı odayı terk etti.")

    async def broadcast_to_room(self, message_data: dict, conversation_id: str):
        """O sohbette kayıtlı (Açık ekranı olan) tüm cihazlara saliseler içinde JSON verisi basan asenkron duyuru sistemi."""
        if conversation_id in self.active_connections:
            for connection in self.active_connections[conversation_id]:
                await connection.send_json(message_data)

manager = ConnectionManager()

async def get_user_from_token_for_ws(token: str) -> User:
    """Olay WebSocket kanalında döndüğü için 'Headers' koruması kırıktır. Bu yüzden JWT'yi Query string parametresinden okutur."""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = payload.get("sub")
        if not user_id:
            raise Exception("Kopuk veya Yetkisiz WS Token'ı")
            
        async with AsyncSessionLocal() as db:
             stmt = select(User).where(User.id == user_id)
             res = await db.execute(stmt)
             user = res.scalar_one_or_none()
             if not user:
                 raise Exception("Kullanıcı veri tabanından çıkmadı.")
             return user
    except Exception:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Geçersiz Socket Anahtarı Şifresi")

@router.websocket("/ws/{conversation_id}")
async def websocket_chat_endpoint(websocket: WebSocket, conversation_id: str, token: str = Query(...)):
    """
    (PRD Faz 6 İçeriği) Ana Canlı İletişim Kanalı (WhatsApp Mantığı)!
    Rest API (bekle ve al) yerine bağlantı kopana dek açık kalır. Mesaj yazıldığı saniye karşıdaki ekranı fırlatılır.
    """
    try:
        user = await get_user_from_token_for_ws(token)
    except Exception:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    # Kimlik kanıtlandı; Cihaz Odaya alınıyor...
    await manager.connect(websocket, conversation_id)
    try:
        while True:
            # Beklenen JSON örneği: { "message": "Evdeki kombi çalışmıyor!", "media_url": null }
            data = await websocket.receive_json()
            
            # 1. Asenkron Kontekst Kullanarak Diğer Thread'leri dondurmadan mesajı Kalıcı DB'ye yaz!
            async with AsyncSessionLocal() as db:
                db_msg = ChatMessage(
                     conversation_id=uuid.UUID(conversation_id),
                     sender_user_id=user.id,
                     message=data.get("message"),
                     media_url=data.get("media_url")
                )
                db.add(db_msg)
                await db.commit()
                
                # Hem DB IDsini hem de atanin ismini paketle (UX icin kolaylik)
                broadcast_data = {
                    "id": str(db_msg.id),
                    "conversation_id": conversation_id,
                    "sender_user_id": str(user.id),
                    "sender_name": user.full_name, 
                    "message": db_msg.message,
                    "media_url": db_msg.media_url,
                    "created_at": str(db_msg.created_at)
                }
                
            # 2. Toplanan bu paketi Odada uyuyan (Dinleyen) diğer Müşteri/Acente ekranlarına bas!
            await manager.broadcast_to_room(broadcast_data, conversation_id)
            
    except WebSocketDisconnect:
        manager.disconnect(websocket, conversation_id)
    except Exception as e:
        # Unexpected disconnect
        manager.disconnect(websocket, conversation_id)

@router.get("/history/{conversation_id}", response_model=List[ChatMessageResponse])
async def get_chat_history(
    conversation_id: str,
    current_user: User = Depends(deps.get_current_user),
    db: AsyncSession = Depends(deps.get_db)
):
    """Kullanıcı mobil uygulamaya aylar sonra girdiğinde, offline kaldığı tüm sohbet 'History'sini (GEÇMİŞ) kalıcı SQL'den okuyan ve iade eden kurtarıcı Rest API noktası."""
    stmt = (
        select(ChatMessage)
        .where(ChatMessage.conversation_id == uuid.UUID(conversation_id))
        .order_by(ChatMessage.created_at.desc())
        .limit(100) # Pagination (sayfalandırma) kolaylığı için limit (En yeni 100)
    )
    result = await db.execute(stmt)
    messages = result.scalars().all()
    
    # Sohbet uygulaması (UI) aşağı doğru kaydığı için zaman çizelgesini ters döndürüp yolluyoruz.
    return messages[::-1]
