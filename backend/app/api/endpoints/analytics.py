from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, desc, extract
from sqlalchemy.orm import selectinload
from typing import List
from datetime import date, datetime, timedelta
from dateutil.relativedelta import relativedelta
from uuid import UUID
import uuid

from app.api import deps
from app.models.users import User, AgencyStaff, Agency
from app.models.properties import Property, PropertyUnit
from app.models.tenants import Tenant, LandlordUnit
from app.models.finance import FinancialTransaction, PaymentSchedule, TransactionType, TransactionCategory, PaymentStatus
from app.schemas.analytics import (
    PortfolioPerformanceResponse, OccupancyRateItem, OccupancyTrendItem, VacantAgingItem,
    TenantChurnResponse, TenantFlowItem,
    FinancialAnnualResponse, MonthlyFinancialItem, CategoryTrendItem,
    CollectionPerformanceResponse, CollectionRateItem,
    BIAnalyticsDashboard,
)

router = APIRouter()


def _month_str(d: date) -> str:
    return f"{d.year}-{d.month:02d}"


# ──────────────────────────────────────────────
# A. PORTFÖY PERFORMANS
# ──────────────────────────────────────────────

async def _build_portfolio_performance(db: AsyncSession, agency_id: UUID) -> PortfolioPerformanceResponse:
    # Tüm mülkler
    prop_stmt = select(Property).where(Property.agency_id == agency_id, Property.is_deleted == False)
    props = (await db.execute(prop_stmt)).scalars().all()

    # Tüm birimler
    unit_stmt = select(PropertyUnit).where(PropertyUnit.agency_id == agency_id)
    units = (await db.execute(unit_stmt)).scalars().all()

    total_units = len(units)
    occupied_units = sum(1 for u in units if u.status == "rented")
    vacant_units = total_units - occupied_units
    overall_rate = (occupied_units / total_units * 100) if total_units > 0 else 0.0

    # Mülk bazlı doluluk
    by_property = []
    for p in props:
        prop_units = [u for u in units if u.property_id == p.id]
        p_total = len(prop_units)
        p_occ = sum(1 for u in prop_units if u.status == "rented")
        by_property.append(OccupancyRateItem(
            property_id=p.id,
            property_name=p.name,
            total_units=p_total,
            occupied_units=p_occ,
            vacant_units=p_total - p_occ,
            occupancy_rate=round(p_occ / p_total * 100, 1) if p_total > 0 else 0.0,
        ))

    # Son 12 ay trend — gerçek tarihsel veri
    # Her ay için o ayın DOLULUK ORANI = o ayda rented olan birim sayısı / toplam birim
    # Kiracı start_date/actual_end_date kayıtlarından aylık doluluk tahmini
    now = date.today()
    occupancy_trend = []
    for i in range(11, -1, -1):
        m = (now - relativedelta(months=i)).replace(day=1)
        m_end = m + relativedelta(months=1)

        # Bu ayda (m_start .. m_end) DOLULUK durumunda olan kiracıların birimleri
        # Dolu = kiracı o ayda aktifti:
        #   start_date < m_end (o aydan önce girmiş) AND
        #   (actual_end_date IS NULL AND end_date >= m) OR (actual_end_date >= m_start)
        rented_stmt = select(PropertyUnit.id).join(
            Tenant, Tenant.unit_id == PropertyUnit.id
        ).where(
            PropertyUnit.agency_id == agency_id,
            Tenant.start_date < m_end,
            (
                (Tenant.actual_end_date.is_(None) & (Tenant.end_date >= m)) |
                (Tenant.actual_end_date >= m)
            ),
        )
        rented_result = await db.execute(rented_stmt)
        rented_count = len(rented_result.scalars().all())

        # Toplam birim
        total_units_hist = len(units)
        rate = (rented_count / total_units_hist * 100) if total_units_hist > 0 else 0.0
        occupancy_trend.append(OccupancyTrendItem(month=_month_str(m), occupancy_rate=round(rate, 1)))

    # Boş daire yaşlandırma
    vacant_aging = []
    for u in units:
        if u.status == "vacant" and u.vacant_since:
            days = (now - u.vacant_since).days
            prop_name = next((p.name for p in props if p.id == u.property_id), "Bilinmeyen")
            vacant_aging.append(VacantAgingItem(
                unit_id=u.id,
                property_id=u.property_id,
                property_name=prop_name,
                door_number=u.unit_number,
                vacant_since_days=days,
                last_rent_price=u.rent_price,
            ))
    vacant_aging.sort(key=lambda x: x.vacant_since_days, reverse=True)

    return PortfolioPerformanceResponse(
        overall_occupancy_rate=round(overall_rate, 1),
        total_properties=len(props),
        total_units=total_units,
        occupied_units=occupied_units,
        vacant_units=vacant_units,
        by_property=by_property,
        occupancy_trend=occupancy_trend,
        vacant_aging=vacant_aging[:20],  # En fazla 20 kayıt
    )


# ──────────────────────────────────────────────
# B. KİRACI SİRKÜLASYONU
# ──────────────────────────────────────────────

async def _build_tenant_churn(db: AsyncSession, agency_id: UUID) -> TenantChurnResponse:
    now = date.today()

    # Aktif kiracılar
    active_stmt = select(func.count(Tenant.id)).where(
        Tenant.agency_id == agency_id, Tenant.is_active == True
    )
    active_count = (await db.execute(active_stmt)).scalar() or 0

    # Son 12 ay giriş/çıkış
    monthly_flow = []
    for i in range(11, -1, -1):
        m_start = (now - relativedelta(months=i)).replace(day=1)
        m_end = m_start + relativedelta(months=1)

        new_stmt = select(func.count(Tenant.id)).where(
            Tenant.agency_id == agency_id,
            Tenant.start_date >= m_start,
            Tenant.start_date < m_end,
        )
        departed_stmt = select(func.count(Tenant.id)).where(
            Tenant.agency_id == agency_id,
            Tenant.is_active == False,
            Tenant.actual_end_date >= m_start,
            Tenant.actual_end_date < m_end,
        )
        new_count = (await db.execute(new_stmt)).scalar() or 0
        departed_count = (await db.execute(departed_stmt)).scalar() or 0

        monthly_flow.append(TenantFlowItem(
            month=_month_str(m_start),
            new_tenants=new_count,
            departed_tenants=departed_count,
        ))

    # Ortalama kalış süresi (ay)
    tenure_stmt = select(func.avg(
        func.extract('year', func.age(Tenant.start_date)) * 12 +
        func.extract('month', func.age(Tenant.start_date))
    )).where(Tenant.agency_id == agency_id, Tenant.start_date.isnot(None))
    avg_months = (await db.execute(tenure_stmt)).scalar() or 0.0

    # Churn rate (bu ay ayrılan / toplam aktif)
    this_month_departed = monthly_flow[-1].departed_tenants if monthly_flow else 0
    churn_rate = (this_month_departed / active_count * 100) if active_count > 0 else 0.0

    return TenantChurnResponse(
        total_active_tenants=active_count,
        avg_tenancy_months=round(avg_months, 1),
        churn_rate_percent=round(churn_rate, 1),
        monthly_flow=monthly_flow,
    )


# ──────────────────────────────────────────────
# C. FİNANSAL YILLIK RAPOR
# ──────────────────────────────────────────────

async def _build_financial_annual(db: AsyncSession, agency_id: UUID) -> FinancialAnnualResponse:
    now = date.today()
    current_year = now.year
    prev_year = current_year - 1

    # Gelir toplamları (yıllık)
    async def _year_total(year: int, tx_type: str) -> int:
        stmt = select(func.coalesce(func.sum(FinancialTransaction.amount), 0)).where(
            FinancialTransaction.agency_id == agency_id,
            FinancialTransaction.type == tx_type,
            extract('year', FinancialTransaction.transaction_date) == year,
        )
        return (await db.execute(stmt)).scalar() or 0

    cur_inc = _year_total(current_year, "income")
    cur_exp = _year_total(current_year, "expense")
    prev_inc = _year_total(prev_year, "income")
    prev_exp = _year_total(prev_year, "expense")

    inc_growth = ((cur_inc - prev_inc) / prev_inc * 100) if prev_inc > 0 else 0.0
    exp_growth = ((cur_exp - prev_exp) / prev_exp * 100) if prev_exp > 0 else 0.0

    # Aylık breakdown
    monthly_breakdown = []
    for i in range(11, -1, -1):
        m = (now - relativedelta(months=i)).replace(day=1)
        m_start = m
        m_end = m + relativedelta(months=1)

        inc_stmt = select(func.coalesce(func.sum(FinancialTransaction.amount), 0)).where(
            FinancialTransaction.agency_id == agency_id,
            FinancialTransaction.type == "income",
            FinancialTransaction.transaction_date >= m_start,
            FinancialTransaction.transaction_date < m_end,
        )
        exp_stmt = select(func.coalesce(func.sum(FinancialTransaction.amount), 0)).where(
            FinancialTransaction.agency_id == agency_id,
            FinancialTransaction.type == "expense",
            FinancialTransaction.transaction_date >= m_start,
            FinancialTransaction.transaction_date < m_end,
        )
        inc_m = (await db.execute(inc_stmt)).scalar() or 0
        exp_m = (await db.execute(exp_stmt)).scalar() or 0

        monthly_breakdown.append(MonthlyFinancialItem(
            month=_month_str(m),
            total_income=inc_m,
            total_expense=exp_m,
            net_balance=inc_m - exp_m,
        ))

    # Kategori trendleri (son 6 ay)
    category_trends = []
    for i in range(5, -1, -1):
        m = (now - relativedelta(months=i)).replace(day=1)
        m_start = m
        m_end = m + relativedelta(months=1)

        async def _cat_total(cat: str, tx_type: str) -> int:
            stmt = select(func.coalesce(func.sum(FinancialTransaction.amount), 0)).where(
                FinancialTransaction.agency_id == agency_id,
                FinancialTransaction.type == tx_type,
                FinancialTransaction.category == cat,
                FinancialTransaction.transaction_date >= m_start,
                FinancialTransaction.transaction_date < m_end,
            )
            return (await db.execute(stmt)).scalar() or 0

        category_trends.append(CategoryTrendItem(
            month=_month_str(m),
            rent_income=await _cat_total("rent", "income"),
            dues_income=await _cat_total("dues", "income"),
            commission_income=await _cat_total("commission", "income"),
            maintenance_expense=await _cat_total("maintenance", "expense"),
            utility_expense=await _cat_total("utility", "expense"),
            other_expense=await _cat_total("other", "expense"),
        ))

    return FinancialAnnualResponse(
        current_year_income=cur_inc,
        current_year_expense=cur_exp,
        current_year_net=cur_inc - cur_exp,
        previous_year_income=prev_inc,
        previous_year_expense=prev_exp,
        previous_year_net=prev_inc - prev_exp,
        income_growth_percent=round(inc_growth, 1),
        expense_growth_percent=round(exp_growth, 1),
        monthly_breakdown=monthly_breakdown,
        category_trends=category_trends,
    )


# ──────────────────────────────────────────────
# D. TAHSİLAT PERFORMANSI
# ──────────────────────────────────────────────

async def _build_collection_performance(db: AsyncSession, agency_id: UUID) -> CollectionPerformanceResponse:
    now = date.today()

    # Genel tahsilat oranı (tüm ödeme takvimleri üzerinden)
    exp_stmt = select(
        func.coalesce(func.sum(PaymentSchedule.amount), 0),
        func.coalesce(func.sum(PaymentSchedule.paid_amount), 0),
    ).where(PaymentSchedule.agency_id == agency_id)
    result = await db.execute(exp_stmt)
    row = result.one_or_none()
    total_expected = row[0] if row else 0
    total_collected = row[1] if row else 0
    overall_rate = (total_collected / total_expected * 100) if total_expected > 0 else 0.0

    # Gecikenler
    overdue_stmt = select(func.coalesce(func.sum(PaymentSchedule.amount - PaymentSchedule.paid_amount), 0)).where(
        PaymentSchedule.agency_id == agency_id,
        PaymentSchedule.status == PaymentStatus.pending,
        PaymentSchedule.due_date < now,
    )
    overdue_amount = (await db.execute(overdue_stmt)).scalar() or 0

    # Ortalama gecikme günü (basit: gecikenlerin ortalama gecikmesi)
    overdue_schedules = (await db.execute(
        select(PaymentSchedule).where(
            PaymentSchedule.agency_id == agency_id,
            PaymentSchedule.due_date < now,
            PaymentSchedule.status == PaymentStatus.pending,
        ).limit(100)
    )).scalars().all()

    total_delay = sum((now - s.due_date).days for s in overdue_schedules if s.due_date)
    avg_delay = total_delay / len(overdue_schedules) if overdue_schedules else 0.0

    # Zamanında ödeme oranı (tamamlanmış + geçikmemiş)
    on_time_stmt = select(func.count(PaymentSchedule.id)).where(
        PaymentSchedule.agency_id == agency_id,
        PaymentSchedule.status == PaymentStatus.completed,
    )
    on_time_count = (await db.execute(on_time_stmt)).scalar() or 0
    total_schedules = (await db.execute(
        select(func.count(PaymentSchedule.id)).where(PaymentSchedule.agency_id == agency_id)
    )).scalar() or 0
    on_time_rate = (on_time_count / total_schedules * 100) if total_schedules > 0 else 0.0

    # Aylık tahsilat oranları (son 6 ay)
    monthly_rates = []
    for i in range(5, -1, -1):
        m = (now - relativedelta(months=i)).replace(day=1)
        m_start = m
        m_end = m + relativedelta(months=1)

        month_stmt = select(
            func.coalesce(func.sum(PaymentSchedule.amount), 0),
            func.coalesce(func.sum(PaymentSchedule.paid_amount), 0),
        ).where(
            PaymentSchedule.agency_id == agency_id,
            PaymentSchedule.due_date >= m_start,
            PaymentSchedule.due_date < m_end,
        )
        m_result = await db.execute(month_stmt)
        m_row = m_result.one_or_none()
        m_exp = m_row[0] if m_row else 0
        m_col = m_row[1] if m_row else 0
        monthly_rates.append(CollectionRateItem(
            month=_month_str(m),
            expected_amount=m_exp,
            collected_amount=m_col,
            collection_rate_percent=round((m_col / m_exp * 100) if m_exp > 0 else 0.0, 1),
        ))

    return CollectionPerformanceResponse(
        overall_collection_rate=round(overall_rate, 1),
        avg_delay_days=round(avg_delay, 1),
        on_time_payment_rate=round(on_time_rate, 1),
        total_outstanding=total_expected - total_collected,
        overdue_amount=overdue_amount,
        monthly_rates=monthly_rates,
    )


# ──────────────────────────────────────────────
# E. ANALYTICS DASHBOARD (TÜM BİRLEŞİK)
# ──────────────────────────────────────────────

@router.get("/bi-dashboard", response_model=BIAnalyticsDashboard)
async def get_bi_analytics_dashboard(
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(deps.get_db),
):
    """
    BI Analytics Dashboard — Emlak ofisi yöneticisinin (Kurucu Emlakçı / Admin)
    tüm stratejik metriklerini bir arada döner.
    PRD §4.1.10
    """
    # ✅ EKLENDI — Admin rolü kontrolü (PRD §4.1.10-E)
    staff_stmt = select(AgencyStaff).where(
        AgencyStaff.user_id == current_user.id,
        AgencyStaff.agency_id == agency_id,
    )
    staff_result = await db.execute(staff_stmt)
    staff_record = staff_result.scalar_one_or_none()

    if not staff_record or staff_record.role != "admin":
        from fastapi import HTTPException
        raise HTTPException(
            status_code=403,
            detail="Bu sayfaya yalnızca Admin erişebilir."
        )

    portfolio = await _build_portfolio_performance(db, agency_id)
    tenant_churn = await _build_tenant_churn(db, agency_id)
    financial = await _build_financial_annual(db, agency_id)
    collection = await _build_collection_performance(db, agency_id)

    return BIAnalyticsDashboard(
        portfolio=portfolio,
        tenant_churn=tenant_churn,
        financial=financial,
        collection=collection,
    )


@router.get("/bi/report")
async def download_bi_pdf(
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(deps.get_db),
):
    """
    BI Analytics PDF raporu indirir — PRD §4.1.10-E.
    Logo, tarihli, profesyonel format. Yalnızca Admin erişimli.
    """
    # Admin kontrolü
    staff_stmt = select(AgencyStaff).where(
        AgencyStaff.user_id == current_user.id,
        AgencyStaff.agency_id == agency_id,
    )
    staff_result = await db.execute(staff_stmt)
    staff_record = staff_result.scalar_one_or_none()
    if not staff_record or staff_record.role != "admin":
        raise HTTPException(status_code=403, detail="Bu sayfaya yalnızca Admin erişebilir.")

    portfolio = await _build_portfolio_performance(db, agency_id)
    tenant_churn = await _build_tenant_churn(db, agency_id)
    financial = await _build_financial_annual(db, agency_id)
    collection = await _build_collection_performance(db, agency_id)

    agency_stmt = select(Agency).where(Agency.id == agency_id)
    agency_res = await db.execute(agency_stmt)
    agency = agency_res.scalar_one_or_none()
    agency_name = agency.name if agency else ""

    dashboard_data = {
        "kpis": {
            "total_properties": portfolio.total_properties if portfolio else 0,
            "total_units": portfolio.total_units if portfolio else 0,
            "occupied_units": portfolio.occupied_units if portfolio else 0,
            "vacant_units": portfolio.vacant_units if portfolio else 0,
            "occupancy_rate": portfolio.overall_occupancy_rate if portfolio else 0,
            "active_tenants": tenant_churn.total_active_tenants if tenant_churn else 0,
            "this_month_collected": 0,
            "pending_this_month": collection.total_outstanding if collection else 0,
            "overdue_amount": collection.overdue_amount if collection else 0,
        },
        "occupancy_trend": portfolio.occupancy_trend if portfolio else [],
        "tenant_churn": tenant_churn.model_dump() if tenant_churn else {},
        "financial_annual": financial.model_dump() if financial else {},
        "collection": collection.model_dump() if collection else {},
    }

    from app.services.pdf_service import build_bi_pdf
    pdf_bytes = build_bi_pdf(dashboard_data, agency_name=agency_name)

    from fastapi.responses import StreamingResponse
    import io
    filename = f"bi-rapor-{date.today().strftime('%Y-%m-%d')}.pdf"
    return StreamingResponse(
        io.BytesIO(pdf_bytes),
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.get("/bi/export")
async def export_bi_analytics(
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(deps.get_db),
):
    """
    BI Analytics verilerini .xlsx olarak dışa aktarır — PRD §4.1.10-E.
    Yalnızca Admin rolü erişebilir.
    """
    # Admin kontrolü
    staff_stmt = select(AgencyStaff).where(
        AgencyStaff.user_id == current_user.id,
        AgencyStaff.agency_id == agency_id,
    )
    staff_result = await db.execute(staff_stmt)
    staff_record = staff_result.scalar_one_or_none()
    if not staff_record or staff_record.role != "admin":
        raise HTTPException(status_code=403, detail="Bu sayfaya yalnızca Admin erişebilir.")

    portfolio = await _build_portfolio_performance(db, agency_id)
    tenant_churn = await _build_tenant_churn(db, agency_id)
    financial = await _build_financial_annual(db, agency_id)
    collection = await _build_collection_performance(db, agency_id)

    from app.services.excel_service import export_analytics_to_excel
    agency_stmt = select(Agency).where(Agency.id == agency_id)
    agency_res = await db.execute(agency_stmt)
    agency = agency_res.scalar_one_or_none()
    agency_name = agency.name if agency else ""

    dashboard_data = {
        "kpis": {
            "total_properties": portfolio.total_properties if portfolio else 0,
            "total_units": portfolio.total_units if portfolio else 0,
            "occupied_units": portfolio.occupied_units if portfolio else 0,
            "vacant_units": portfolio.vacant_units if portfolio else 0,
            "occupancy_rate": portfolio.overall_occupancy_rate if portfolio else 0,
            "active_tenants": tenant_churn.total_active_tenants if tenant_churn else 0,
            "this_month_collected": 0,
            "pending_this_month": collection.total_outstanding if collection else 0,
            "overdue_amount": collection.overdue_amount if collection else 0,
        },
        "occupancy_trend": portfolio.occupancy_trend if portfolio else [],
        "tenant_churn": tenant_churn.model_dump() if tenant_churn else {},
        "financial_annual": financial.model_dump() if financial else {},
    }

    excel_bytes = export_analytics_to_excel(dashboard_data, agency_name=agency_name)

    from fastapi.responses import StreamingResponse
    import io
    return StreamingResponse(
        io.BytesIO(excel_bytes),
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={
            "Content-Disposition": f'attachment; filename="bi-analytics-{date.today().strftime("%Y-%m-%d")}.xlsx"'
        },
    )


# ──────────────────────────────────────────────
# F. TEKİL ENDPOINT'LER (İHTİYAÇ OLDUKÇA)
# ──────────────────────────────────────────────

@router.get("/bi/portfolio", response_model=PortfolioPerformanceResponse)
async def get_portfolio_performance(
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(deps.get_db),
):
    return await _build_portfolio_performance(db, agency_id)


@router.get("/bi/tenant-churn", response_model=TenantChurnResponse)
async def get_tenant_churn(
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(deps.get_db),
):
    return await _build_tenant_churn(db, agency_id)


@router.get("/bi/financial", response_model=FinancialAnnualResponse)
async def get_financial_annual(
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(deps.get_db),
):
    return await _build_financial_annual(db, agency_id)


@router.get("/bi/collection", response_model=CollectionPerformanceResponse)
async def get_collection_performance(
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(deps.get_db),
):
    return await _build_collection_performance(db, agency_id)