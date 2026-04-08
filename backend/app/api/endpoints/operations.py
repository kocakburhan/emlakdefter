from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
import uuid

from app.api import deps
from app.models.users import User
from app.models.properties import PropertyUnit
from app.models.operations import SupportTicket, TicketMessage, BuildingOperationLog, TicketStatus
from app.schemas.operations import TicketCreate, TicketResponse, TicketMessageCreate, TicketMessageResponse, BuildingLogCreate, BuildingLogResponse

router = APIRouter()
MOCK_AGENCY_ID = "00000000-0000-0000-0000-000000000001" # RLS Isolation Protection

@router.post("/tickets", response_model=TicketResponse, status_code=status.HTTP_201_CREATED)
async def create_ticket(
    ticket_in: TicketCreate,
    current_user: User = Depends(deps.get_current_user),
    db: AsyncSession = Depends(deps.get_db)
):
    """
    (PRD Destek Bölümü): Kiracının dairesindeki hasarı, bozuk asansörü vb. 'Priority' (Öncelik) 
    ve opsiyonel Fotoğrafla (attachment_url) yetkili Emlakçıya kanıtladığı arıza biletini açar.
    """
    unit = await db.get(PropertyUnit, ticket_in.unit_id)
    if not unit or unit.agency_id != uuid.UUID(MOCK_AGENCY_ID):
        raise HTTPException(status_code=404, detail="Ulaşmaya çalıştığınız mülk yetkiniz dahilinde değil.")
        
    db_ticket = SupportTicket(
        agency_id=uuid.UUID(MOCK_AGENCY_ID),
        unit_id=ticket_in.unit_id,
        reporter_user_id=current_user.id,
        title=ticket_in.title,
        description=ticket_in.description,
        priority=ticket_in.priority,
        status=TicketStatus.open, # Yeni Açıldı!
        attachment_url=ticket_in.attachment_url
    )
    db.add(db_ticket)
    await db.commit()
    await db.refresh(db_ticket)
    return db_ticket

@router.post("/tickets/{ticket_id}/reply", response_model=TicketMessageResponse)
async def reply_to_ticket(
    ticket_id: str,
    reply_in: TicketMessageCreate,
    current_user: User = Depends(deps.get_current_user),
    db: AsyncSession = Depends(deps.get_db)
):
    """Emlakçı acente personelinin veya Kiracının mevcut açık bilete yazdığı mesajın (Örn: 'Usta yola çıktı') log tablosudur."""
    ticket = await db.get(SupportTicket, uuid.UUID(ticket_id))
    if not ticket or ticket.agency_id != uuid.UUID(MOCK_AGENCY_ID):
        raise HTTPException(status_code=404, detail="Bilet (Arıza kaydı) bulunamadı.")
        
    db_message = TicketMessage(
        ticket_id=uuid.UUID(ticket_id),
        sender_user_id=current_user.id,
        message=reply_in.message,
        attachment_url=reply_in.attachment_url
    )
    db.add(db_message)
    
    # Yeni bir mesaj eklendiyse ve bilet geçmişse; 'İşleme Alındı'ya oturt
    if ticket.status == TicketStatus.closed or ticket.status == TicketStatus.open:
        ticket.status = TicketStatus.in_progress
        
    await db.commit()
    await db.refresh(db_message)
    return db_message

@router.post("/building-logs", response_model=BuildingLogResponse)
async def create_building_log(
    log_in: BuildingLogCreate,
    current_user: User = Depends(deps.get_current_user),
    db: AsyncSession = Depends(deps.get_db)
):
    """
    PRD Şeffaflık Modülü: Ev Lortlarının (Mülk sahiplerinin) ortak görebileceği; 
    'Çatı Tamiratı 25.000 TL Tutmuştur, faturası ektedir' şeklinde binalara astığımız sanal şeffaf pano!
    """
    db_log = BuildingOperationLog(
        agency_id=uuid.UUID(MOCK_AGENCY_ID),
        property_id=log_in.property_id,
        created_by_user_id=current_user.id,
        title=log_in.title,
        description=log_in.description,
        cost=log_in.cost,
        invoice_url=log_in.invoice_url,
        is_reflected_to_finance=log_in.is_reflected_to_finance # Eğer ana kasadan para kesildiyse True yapılır.
    )
    db.add(db_log)
    await db.commit()
    await db.refresh(db_log)
    return db_log
