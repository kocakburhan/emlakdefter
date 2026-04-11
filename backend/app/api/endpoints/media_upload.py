"""
Medya yükleme endpoint'leri — Hetzner Object Storage.
PRD §4.1.8-C: Chat ve bina operasyonlarına medya yükleme.
"""
import os
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlalchemy.ext.asyncio import AsyncSession
from uuid import UUID

from app.api import deps
from app.models.users import User
from app.core.storage import upload_file

router = APIRouter()

# Allowed MIME types
ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/gif", "image/webp"}
ALLOWED_DOC_TYPES = {"application/pdf", "application/msword",
                      "application/vnd.openxmlformats-officedocument.wordprocessingml.document"}
MAX_FILE_SIZE = 10 * 1024 * 1024  # 10 MB


@router.post("/media")
async def upload_media(
    file: UploadFile = File(...),
    category: str = Form("general", description="Kategori: 'chat', 'building_ops', 'document', 'general'"),
    current_user: User = Depends(deps.get_current_user),
    db: AsyncSession = Depends(deps.get_db),
):
    """
    Tek bir medya dosyasını Hetzner Object Storage'a yükler.
    Desteklenen: JPEG, PNG, GIF, WebP, PDF, DOC/DOCX (max 10 MB).
    Dönen: { "url": "https://...", "key": "media/..." }
    """
    # Validate file type
    content_type = file.content_type or "application/octet-stream"

    allowed = ALLOWED_IMAGE_TYPES | ALLOWED_DOC_TYPES
    if content_type not in allowed:
        raise HTTPException(
            status_code=400,
            detail=f"İzin verilmeyen dosya tipi: {content_type}. İzin verilen: {', '.join(allowed)}",
        )

    # Read content
    content = await file.read()
    file_size = len(content)

    if file_size > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=400,
            detail=f"Dosya çok büyük: {file_size / 1024 / 1024:.1f} MB. Maksimum: 10 MB.",
        )

    if file_size == 0:
        raise HTTPException(status_code=400, detail="Boş dosya yüklenemez.")

    # Upload to Hetzner
    prefix_map = {
        "chat": "chat",
        "building_ops": "building-ops",
        "document": "documents",
        "general": "media",
    }
    prefix = prefix_map.get(category, "media")

    url = await upload_file(
        file_content=content,
        filename=file.filename or "unknown",
        content_type=content_type,
        prefix=prefix,
    )

    if url is None:
        raise HTTPException(
            status_code=500,
            detail="Dosya yüklenemedi. Lütfen daha sonra tekrar deneyin.",
        )

    return {
        "url": url,
        "filename": file.filename,
        "content_type": content_type,
        "size": file_size,
        "category": category,
    }
