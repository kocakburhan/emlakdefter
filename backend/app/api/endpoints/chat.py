from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect, Query, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc
from sqlalchemy.orm import selectinload
from datetime import datetime
from typing import Dict, List
import uuid

from app.api import deps
from app.models.users import User
from app.models.chat import ChatConversation, ChatMessage
from app.models.properties import Property
from app.schemas.chat import (
    ChatMessageResponse, ChatConversationResponse, ConversationCreate, MessageEditRequest, MessageCreate
)
from app.database import AsyncSessionLocal
from jose import jwt, JWTError
from app.core.security import SECRET_KEY, ALGORITHM

router = APIRouter()


class ConnectionManager:
    """Canlı WebSocket bağlantılarını yönetir."""
    def __init__(self):
        self.active_connections: Dict[str, List[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, conversation_id: str):
        await websocket.accept()
        if conversation_id not in self.active_connections:
            self.active_connections[conversation_id] = []
        self.active_connections[conversation_id].append(websocket)

    def disconnect(self, websocket: WebSocket, conversation_id: str):
        if conversation_id in self.active_connections:
             if websocket in self.active_connections[conversation_id]:
                 self.active_connections[conversation_id].remove(websocket)
             if not self.active_connections[conversation_id]:
                 del self.active_connections[conversation_id]

    async def broadcast_to_room(self, message_data: dict, conversation_id: str):
        if conversation_id in self.active_connections:
            for connection in self.active_connections[conversation_id]:
                await connection.send_json(message_data)


manager = ConnectionManager()


async def get_user_from_token_for_ws(token: str) -> User:
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


# ──────────────────────────────────────────────
# CONVERSATIONS
# ──────────────────────────────────────────────

@router.get("/conversations", response_model=List[ChatConversationResponse])
async def list_conversations(
    include_archived: bool = False,
    current_user: User = Depends(deps.get_current_user),
    agency_id: uuid.UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(deps.get_db),
):
    """
    Kullanıcının tüm sohbetlerini listeler (WhatsApp listesi gibi).
    Her sohbet için son mesaj ve karşı tarafın ismi döner.
    """
    query = (
        select(ChatConversation)
        .where(ChatConversation.agency_id == agency_id)
        .options(selectinload(ChatConversation.messages))
        .order_by(desc(ChatConversation.updated_at))
    )
    if not include_archived:
        query = query.where(ChatConversation.is_archived == False)

    result = await db.execute(query)
    conversations = result.scalars().all()

    responses = []
    for conv in conversations:
        sorted_msgs = sorted(conv.messages, key=lambda m: m.created_at, reverse=True)
        last_msg = next((m for m in sorted_msgs if not m.is_deleted), None)

        is_agent = current_user.id == conv.agent_user_id
        client_id = conv.client_user_id if is_agent else conv.agent_user_id
        client_stmt = select(User).where(User.id == client_id)
        client_res = await db.execute(client_stmt)
        client_user = client_res.scalar_one_or_none()

        prop_stmt = select(Property).where(Property.id == conv.property_id)
        prop_res = await db.execute(prop_stmt)
        prop = prop_res.scalar_one_or_none()

        responses.append(ChatConversationResponse(
            id=conv.id,
            agency_id=conv.agency_id,
            agent_user_id=conv.agent_user_id,
            client_user_id=conv.client_user_id,
            property_id=conv.property_id,
            client_name=client_user.full_name if client_user else "Bilinmeyen",
            client_role="Kiracı" if client_user and "tenant" in str(client_user.role) else "Ev Sahibi",
            property_name=prop.name if prop else None,
            last_message=last_msg.content if last_msg else None,
            last_message_at=last_msg.created_at if last_msg else conv.created_at,
            unread_count=0,
            is_archived=conv.is_archived,
            created_at=conv.created_at,
        ))

    return responses


@router.post("/conversations", response_model=ChatConversationResponse, status_code=201)
async def create_conversation(
    data: ConversationCreate,
    current_user: User = Depends(deps.get_current_user),
    agency_id: uuid.UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(deps.get_db),
):
    """Yeni bir sohbet başlatır (veya varsa mevcut olanı döner)."""
    existing_stmt = select(ChatConversation).where(
        ChatConversation.agency_id == agency_id,
        ChatConversation.client_user_id == data.client_user_id,
        ChatConversation.is_archived == False,
    )
    existing_res = await db.execute(existing_stmt)
    existing = existing_res.scalar_one_or_none()
    if existing:
        # Mülk değiştiyse güncelle
        if data.property_id and not existing.property_id:
            existing.property_id = data.property_id
            await db.commit()
        return ChatConversationResponse(
            id=existing.id, agency_id=existing.agency_id,
            agent_user_id=existing.agent_user_id, client_user_id=existing.client_user_id,
            property_id=existing.property_id,
            created_at=existing.created_at, is_archived=existing.is_archived,
        )

    conv = ChatConversation(
        agency_id=agency_id,
        agent_user_id=current_user.id,
        client_user_id=data.client_user_id,
        property_id=data.property_id,
    )
    db.add(conv)
    await db.commit()
    await db.refresh(conv)
    return ChatConversationResponse(
        id=conv.id, agency_id=conv.agency_id,
        agent_user_id=conv.agent_user_id, client_user_id=conv.client_user_id,
        property_id=conv.property_id,
        created_at=conv.created_at, is_archived=conv.is_archived,
    )


@router.patch("/conversations/{conversation_id}/archive", response_model=ChatConversationResponse)
async def archive_conversation(
    conversation_id: uuid.UUID,
    current_user: User = Depends(deps.get_current_user),
    agency_id: uuid.UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(deps.get_db),
):
    """Sohbeti arşivler / arşivden geri alır."""
    conv = await db.get(ChatConversation, conversation_id)
    if not conv or conv.agency_id != agency_id:
        raise HTTPException(status_code=404, detail="Sohbet bulunamadı")
    conv.is_archived = not conv.is_archived
    conv.archived_at = datetime.utcnow().isoformat() if conv.is_archived else None
    await db.commit()
    await db.refresh(conv)
    return ChatConversationResponse.model_validate(conv)


# ──────────────────────────────────────────────
# MESSAGES
# ──────────────────────────────────────────────

@router.get("/history/{conversation_id}", response_model=List[ChatMessageResponse])
async def get_chat_history(
    conversation_id: str,
    current_user: User = Depends(deps.get_current_user),
    agency_id: uuid.UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(deps.get_db),
):
    """Offline dönemdeki sohbet geçmişini getirir."""
    conv = await db.get(ChatConversation, uuid.UUID(conversation_id))
    if not conv or conv.agency_id != agency_id:
        raise HTTPException(status_code=404, detail="Sohbet bulunamadı")

    stmt = (
        select(ChatMessage)
        .where(
            ChatMessage.conversation_id == uuid.UUID(conversation_id),
            ChatMessage.is_deleted == False,
        )
        .order_by(ChatMessage.created_at.desc())
        .limit(100)
    )
    result = await db.execute(stmt)
    messages = result.scalars().all()
    return [ChatMessageResponse.model_validate(m) for m in reversed(messages)]


@router.post("/messages", response_model=ChatMessageResponse, status_code=201)
async def send_message(
    message_in: MessageCreate,
    current_user: User = Depends(deps.get_current_user),
    agency_id: uuid.UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(deps.get_db),
):
    """Yeni mesaj gönderir ve WebSocket ile odaya broadcast eder."""
    # Konuşmanın agency'ye ait olduğunu doğrula
    conv_stmt = select(ChatConversation).where(
        ChatConversation.id == message_in.conversation_id,
        ChatConversation.agency_id == agency_id,
    )
    conv_res = await db.execute(conv_stmt)
    conv = conv_res.scalar_one_or_none()
    if not conv:
        raise HTTPException(status_code=404, detail="Sohbet bulunamadı.")

    db_msg = ChatMessage(
        conversation_id=message_in.conversation_id,
        sender_user_id=current_user.id,
        content=message_in.content or "",
        attachment_url=message_in.attachment_url,
    )
    db.add(db_msg)

    # Konuşma updated_at güncelle
    conv.updated_at = datetime.utcnow()
    await db.commit()
    await db.refresh(db_msg)

    # WebSocket ile broadcast
    await manager.broadcast_to_room({
        "type": "message",
        "id": str(db_msg.id),
        "conversation_id": str(db_msg.conversation_id),
        "sender_user_id": str(db_msg.sender_user_id),
        "content": db_msg.content,
        "attachment_url": db_msg.attachment_url,
        "created_at": db_msg.created_at.isoformat(),
    }, str(conv.id))

    return ChatMessageResponse.model_validate(db_msg)


@router.patch("/messages/{message_id}", response_model=ChatMessageResponse)
async def edit_message(
    message_id: uuid.UUID,
    edit_in: MessageEditRequest,
    current_user: User = Depends(deps.get_current_user),
    agency_id: uuid.UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(deps.get_db),
):
    """Mesajı düzenler (sadece gönderen kişi, 15 dakika içinde)."""
    msg = await db.get(ChatMessage, message_id)
    if not msg:
        raise HTTPException(status_code=404, detail="Mesaj bulunamadı")
    if msg.sender_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Bu mesajı düzenleyemezsiniz")

    elapsed = (datetime.utcnow() - msg.created_at).total_seconds()
    if elapsed > 15 * 60:
        raise HTTPException(status_code=400, detail="Mesaj düzenleme süresi dolmuş (15 dk)")

    msg.content = edit_in.content
    msg.is_edited = True
    msg.edited_at = datetime.utcnow().isoformat()
    await db.commit()
    await db.refresh(msg)

    await manager.broadcast_to_room({
        "type": "message_edited",
        "id": str(msg.id),
        "conversation_id": str(msg.conversation_id),
        "content": msg.content,
        "is_edited": True,
        "edited_at": msg.edited_at,
    }, str(msg.conversation_id))

    return ChatMessageResponse.model_validate(msg)


@router.delete("/messages/{message_id}", status_code=200)
async def delete_message(
    message_id: uuid.UUID,
    current_user: User = Depends(deps.get_current_user),
    agency_id: uuid.UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(deps.get_db),
):
    """Mesajı soft-delete olarak siler (30 saniye içinde geri alınabilir)."""
    msg = await db.get(ChatMessage, message_id)
    if not msg:
        raise HTTPException(status_code=404, detail="Mesaj bulunamadı")
    if msg.sender_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Bu mesajı silemezsiniz")

    elapsed = (datetime.utcnow() - msg.created_at).total_seconds()
    if elapsed > 30:
        raise HTTPException(status_code=400, detail="Mesaj silme süresi dolmuş (30 sn)")

    msg.is_deleted = True
    msg.deleted_at = datetime.utcnow().isoformat()
    msg.deleted_by = current_user.id
    await db.commit()

    await manager.broadcast_to_room({
        "type": "message_deleted",
        "id": str(msg.id),
        "conversation_id": str(msg.conversation_id),
        "deleted_at": msg.deleted_at,
    }, str(msg.conversation_id))

    return {"success": True, "deleted_message_id": str(msg.id)}


# ──────────────────────────────────────────────
# WEBSOCKET
# ──────────────────────────────────────────────

@router.websocket("/ws/{conversation_id}")
async def websocket_chat_endpoint(websocket: WebSocket, conversation_id: str, token: str = Query(...)):
    """
    Ana Canlı İletişim Kanalı (WhatsApp Mantığı)!
    Bağlantı kopana dek açık kalır. Mesaj yazıldığı saniye karşıdaki ekrana düşer.
    """
    try:
        user = await get_user_from_token_for_ws(token)
    except Exception:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    await manager.connect(websocket, conversation_id)
    try:
        while True:
            data = await websocket.receive_json()
            msg_type = data.get("type", "message")

            if msg_type == "message":
                async with AsyncSessionLocal() as db:
                    db_msg = ChatMessage(
                         conversation_id=uuid.UUID(conversation_id),
                         sender_user_id=user.id,
                         content=data.get("content"),
                         attachment_url=data.get("attachment_url")
                    )
                    db.add(db_msg)
                    await db.commit()

                    broadcast_data = {
                        "type": "new_message",
                        "id": str(db_msg.id),
                        "conversation_id": conversation_id,
                        "sender_user_id": str(user.id),
                        "sender_name": user.full_name,
                        "content": db_msg.content,
                        "attachment_url": db_msg.attachment_url,
                        "created_at": str(db_msg.created_at),
                        "is_edited": False,
                    }

                await manager.broadcast_to_room(broadcast_data, conversation_id)

    except WebSocketDisconnect:
        manager.disconnect(websocket, conversation_id)
    except Exception:
        manager.disconnect(websocket, conversation_id)
