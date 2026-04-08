import uuid
from datetime import datetime
from sqlalchemy import Column, DateTime, Boolean
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import declarative_base

# Tüm veritabanı tablolarımız için MetaData havuzu işlevi gören temel sınıfımız
Base = declarative_base()

class UUIDMixin:
    """Her kayda benzersiz bir UUID Primary Key atar."""
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True)

class TimestampMixin:
    """Kayıtların ne zaman atıldığı ve güncellendiği bilgisini otomatik işler."""
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

class SoftDeleteMixin:
    """Veri kaybını sıfıra indiren Soft-Delete mekanizması (PRD Madde 6.1)"""
    is_deleted = Column(Boolean, default=False, nullable=False, index=True)
    deleted_at = Column(DateTime, nullable=True)

    def soft_delete(self):
        self.is_deleted = True
        self.deleted_at = datetime.utcnow()

class BaseModel(Base, UUIDMixin, TimestampMixin, SoftDeleteMixin):
    """
    Domain modellerinin tamamının (%100) miras alacağı (inherit edeceği) soyut kalıtım sınıfı.
    PK ve silme işlemlerini güvenlik altına alır.
    """
    __abstract__ = True
