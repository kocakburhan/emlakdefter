from uuid import UUID
from pydantic import BaseModel
from typing import List, Optional
from datetime import date

# ──────────────────────────────────────────────
# A. Portföy Performansı
# ──────────────────────────────────────────────

class OccupancyRateItem(BaseModel):
    """Tek bir mülkün doluluk oranı"""
    property_id: UUID
    property_name: str
    total_units: int
    occupied_units: int
    vacant_units: int
    occupancy_rate: float  # 0-100 arası yüzde

class OccupancyTrendItem(BaseModel):
    """Aylık doluluk trend verisi"""
    month: str  # "2026-01"
    occupancy_rate: float

class VacantAgingItem(BaseModel):
    """Boş daire yaşlandırma — ne kadar süredir boş"""
    unit_id: UUID
    property_id: UUID
    property_name: str
    door_number: str
    vacant_since_days: int
    last_rent_price: Optional[int] = None

class PortfolioPerformanceResponse(BaseModel):
    overall_occupancy_rate: float
    total_properties: int
    total_units: int
    occupied_units: int
    vacant_units: int
    by_property: List[OccupancyRateItem]
    occupancy_trend: List[OccupancyTrendItem]
    vacant_aging: List[VacantAgingItem]

# ──────────────────────────────────────────────
# B. Kiracı Sirkülasyonu
# ──────────────────────────────────────────────

class TenantFlowItem(BaseModel):
    """Aylık giriş/çıkış sayısı"""
    month: str
    new_tenants: int
    departed_tenants: int

class TenantChurnResponse(BaseModel):
    total_active_tenants: int
    avg_tenancy_months: float
    churn_rate_percent: float
    monthly_flow: List[TenantFlowItem]

# ──────────────────────────────────────────────
# C. Finansal Rapor (Yıllık Karşılaştırmalı)
# ──────────────────────────────────────────────

class MonthlyFinancialItem(BaseModel):
    """Tek ayın gelir/gider özeti"""
    month: str
    total_income: int
    total_expense: int
    net_balance: int

class CategoryTrendItem(BaseModel):
    """Kategori bazlı gider trendi"""
    month: str
    rent_income: int
    dues_income: int
    commission_income: int
    maintenance_expense: int
    utility_expense: int
    other_expense: int

class FinancialAnnualResponse(BaseModel):
    current_year_income: int
    current_year_expense: int
    current_year_net: int
    previous_year_income: int
    previous_year_expense: int
    previous_year_net: int
    income_growth_percent: float
    expense_growth_percent: float
    monthly_breakdown: List[MonthlyFinancialItem]
    category_trends: List[CategoryTrendItem]

# ──────────────────────────────────────────────
# D. Tahsilat Performansı
# ──────────────────────────────────────────────

class CollectionRateItem(BaseModel):
    """Aylık tahsilat oranı"""
    month: str
    expected_amount: int
    collected_amount: int
    collection_rate_percent: float

class CollectionPerformanceResponse(BaseModel):
    overall_collection_rate: float
    avg_delay_days: float
    on_time_payment_rate: float
    total_outstanding: int
    overdue_amount: int
    monthly_rates: List[CollectionRateItem]

# ──────────────────────────────────────────────
# E. BI Ana Dashboard (Tümünü Birleştiren)
# ──────────────────────────────────────────────

class BIAnalyticsDashboard(BaseModel):
    portfolio: PortfolioPerformanceResponse
    tenant_churn: TenantChurnResponse
    financial: FinancialAnnualResponse
    collection: CollectionPerformanceResponse