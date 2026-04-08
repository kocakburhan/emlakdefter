from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List
import uuid

from app.api import deps
from app.models.users import User
from app.schemas.finance import ParsedStatementResponse
from app.services.finance_service import process_and_match_statement

router = APIRouter()

@router.post("/upload-statement", response_model=ParsedStatementResponse)
async def upload_bank_statement(
    file: UploadFile = File(...),
    current_user: User = Depends(deps.get_current_user),
    db: AsyncSession = Depends(deps.get_db)
):
    """
    Sistemin Kalbi: Emlakçının Banka Dekontunu (PDF formatında) fırlattığı uç nokta.
    Bu dosya doğrudan 'pdfplumber' yardımıyla parçalanır; 'gemini-2.5-flash' LLM modeline sokulup saniyeler içinde
    json tabloları dizilir, akabinde Difflib ve Karar Ağacı Zinciri ile kiracıların borçları sıfırlanır.
    """
    if file.content_type != "application/pdf":
        raise HTTPException(status_code=400, detail="Emlakdefteri YZ Motoru şu an için sadece PDF (.pdf) formatındaki ekstremeleri çözebilmektedir.")
        
    mock_agency_id = "00000000-0000-0000-0000-000000000001" # Mock Role-Level Security (Acenteye aitlik filtresi)
    
    file_bytes = await file.read()
    
    try:
        # LLM + Deterministik Algoritma Zincirini Motorla!
        response_tree = await process_and_match_statement(db, mock_agency_id, file_bytes)
        return response_tree
    except Exception as e:
         raise HTTPException(status_code=500, detail=f"LLM Motorunda veya Veritabanı Tahsilat Eşitlemesinde Kritik Hata: {str(e)}")
