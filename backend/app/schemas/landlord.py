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

    model_config = {"from_attributes": True}


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
    """Ev Sahibi özet kartları — PRD §4.3.1-A"""
    total_properties: int
    total_units: int
    occupied_units: int
    vacant_units: int
    total_monthly_income: int  # Tahsil edilen (ödenen) kira
    total_pending_dues: int
    active_tenants: int
    occupancy_rate: float
    expected_rent: int = 0  # Beklenen toplam kira (this month)
    collected_rent: int = 0  # Tahsil edilen kira (this month)
    delayed_balance: int = 0  # Gecikmeli bakiye


class PaymentMonthItem(BaseModel):
    """Tek bir aydaki ödeme durumu"""
    month_label: str          # "Oca 2026"
    year: int
    month: int
    amount: float
    paid_amount: float
    status: str               # "paid_on_time" | "paid_late" | "partial" | "pending"
    days_late: int = 0       # Geciktirilen gün sayısı (sadece geciktiyse)
    paid_at: Optional[date]  # Fiili ödeme tarihi


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
    months_rented: int
    on_time_payments: int
    late_payments: int = 0
    missed_payments: int = 0
    payment_score: float = 100.0
    payment_history: List[PaymentMonthItem] = []
    documents: Optional[List[Dict[str, Any]]] = []  # ✅ EKLENDI — Sözleşme belgeleri (PRD §4.3.2-C)


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

    model_config = {"from_attributes": True}


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

    model_config = {"from_attributes": True}


class LandlordInterestRequest(BaseModel):
    """§4.3.4 — Ev Sahibinin yatırım ilgisi bildirmesi (Bilgi Al)"""
    property_id: Optional[UUID4] = None
    initial_message: str = "Bu mülk hakkında bilgi almak istiyorum."


# ──────────────────────────────────────────────
# §4.3.2-C — Dijital Arşiv (Salt Okunur Belgeler ve Medya)
# ──────────────────────────────────────────────

class UnitDocumentItem(BaseModel):
    """Birime ait tek bir arşiv belgesi"""
    name: str
    doc_type: str  # "contract" | "handover" | "photo" | "other"
    url: str
    uploaded_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


class UnitDocumentsResponse(BaseModel):
    """Birime ait tüm dijital arşiv belgeleri — PRD §4.3.2-C"""
    unit_id: UUID4
    property_name: str
    door_number: str
    contract_document_url: Optional[str] = None
    documents: List[UnitDocumentItem] = []

    model_config = {"from_attributes": True}
