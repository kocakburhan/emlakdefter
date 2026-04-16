"""
PostgreSQL Row Level Security (RLS) Context Yönetimi

Bu modül, RLS ile çoklu kiracı (multi-tenant) izolasyonunu yönetir.
Her veritabanı oturumu açıldığında, o oturumun hangi agency_id'ye
ait olduğu PostgreSQL session variable olarak set edilir.

Bu sayede RLS politikaları otomatik olarak devreye girer ve
her sorgu sadece ilgili agency'nin verilerini döner.

Kullanım:
    from app.core.rls import set_rls_context

    # Async session ile
    await set_rls_context(session, agency_id)

    # Artık tüm sorgular sadece bu agency_id'nin verilerini dönecek
"""

from uuid import UUID
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text


async def set_rls_context(session: AsyncSession, agency_id: UUID) -> None:
    """
    PostgreSQL session'ında RLS context'ini set eder.

    Bu fonksiyon, her yeni veritabanı oturumu için çağrılmalıdır.
    set_config() ile 'app.current_agency_id' session variable'u set edilir.
    get_agency_context() fonksiyonu bu değeri okur ve RLS politikaları
    buna göre çalışır.

    Args:
        session: SQLAlchemy AsyncSession
        agency_id: İzolasyon için kullanılacak agency UUID'si

    Not:
        - Bu fonksiyon PERFORM(set_config(...)) kullanır, RETURNING değil
        - SET LOCAL değil, set_config() kullanılır çünkü transaction
          içinde bile kalıcı olmalı
    """
    await session.execute(
        text("SELECT set_agency_context(:agency_id)"),
        {"agency_id": str(agency_id)}
    )


async def clear_rls_context(session: AsyncSession) -> None:
    """
    PostgreSQL session'ındaki RLS context'ini temizler.
    Çıkış yaparken veya bağlantı kapatılırken çağrılabilir.

    Args:
        session: SQLAlchemy AsyncSession
    """
    await session.execute(
        text("SELECT set_config('app.current_agency_id', '', true)")
    )


async def get_rls_context(session: AsyncSession) -> UUID | None:
    """
    Mevcut session'daki RLS context'ini döner.
    Test ve debug amaçlı kullanılabilir.

    Args:
        session: SQLAlchemy AsyncSession

    Returns:
        Mevcut agency_id veya None
    """
    result = await session.execute(text("SELECT get_agency_context()"))
    agency_id = result.scalar_one_or_none()
    return UUID(agency_id) if agency_id else None
