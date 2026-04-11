from pydantic import BaseModel, UUID4
from typing import Optional, List, Dict, Any
from datetime import date, datetime


class LandlordUnitResponse(BaseModel):
    """Ev Sahibinin tek bir birimine ait bilgi"""
    id: UUID4
    unit_id: UUID4
    property_name: str
    door_number: str
    floor: Optional[str]
    ownership_share: int
    rent_amount: Optional[int]
    tenant_name: Optional[str]
    tenant_phone: Optional[str]
    contract_status: str
    is_active: bool

    class Config:
        from_attributes = True


class LandlordPropertySummary(BaseModel):
    """Bir mülkteki tüm birimlerin özeti"""
    property_id: UUID4
    property_name: str
    address: Optional[str]
    total_units: int
    owned_units: int
    occupied_units: int
    vacant_units: int
    monthly_income: int
    occupancy_rate: float


class LandlordDashboardKPIs(BaseModel):
    """Ev Sahibi özet kartları"""
    total_properties: int
    total_units: int
    occupied_units: int
    vacant_units: int
    total_monthly_income: int
    total_pending_dues: int
    active_tenants: int
    occupancy_rate: float


class LandlordTenantPerformance(BaseModel):
    """Kiracı performans bilgisi (ödeme geçmişi vb.)"""
    tenant_id: UUID4
    unit_id: UUID4
    property_name: str
    door_number: str
    tenant_name: Optional[str]
    tenant_phone: Optional[str]
    rent_amount: int
    payment_day: int
    contract_start: date
    contract_end: date
    status: str
    is_active: bool
    # Tahmini ödeme performansı (basit)
    months_rented: int
    on_time_payments: int


class LandlordOperationItem(BaseModel):
    """Ev Sahibinin mülkündeki operasyonlar"""
    id: UUID4
    property_id: UUID4
    property_name: str
    title: str
    description: Optional[str]
    cost: int
    is_reflected_to_finance: bool
    created_at: datetime

    class Config:
        from_attributes = True


class LandlordVacantUnit(BaseModel):
    """Portföy Vitrini — Boş birim bilgisi (Ev Sahibi için yatırım fırsatları)"""
    unit_id: UUID4
    property_id: UUID4
    property_name: str
    address: Optional[str]
    door_number: str
    floor: Optional[str]
    rent_price: Optional[int]
    dues_amount: int
    features: Optional[Dict[str, Any]]

    class Config:
        from_attributes = True
