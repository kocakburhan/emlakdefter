# BI Analytics Period Filter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Backend accepts `period` query param (`1m`, `3m`, `6m`, `12m`, `ytd`, `py`) and frontend sends it on period button tap. All 4 data sections filter to the selected period.

**Architecture:** Period param added to `bi-dashboard` endpoint. `_build_*` helper functions receive `months_back` int. Frontend sends `?period=3m` on every API call when a non-default period is selected.

**Tech Stack:** FastAPI + SQLAlchemy async, Flutter Riverpod

---

## File Map

| File | Role |
|---|---|
| `backend/app/api/endpoints/analytics.py` | Add `period` query param, pass `months_back` to helpers |
| `backend/app/schemas/analytics.py` | Update `BIAnalyticsDashboard` if needed |
| `frontend/lib/features/agent/screens/bi_analytics_screen.dart` | Send `period` param to API, rebuild data on change |

---

## Task 1: Add `period` Parameter to Backend Endpoint

**Files:**
- Modify: `backend/app/api/endpoints/analytics.py:366-390`

- [ ] **Step 1: Add period mapping and validation**

After line 24 (after `router = APIRouter()`), add:

```python
_PERIOD_MAP = {
    "1m": 1,
    "3m": 3,
    "6m": 6,
    "12m": 12,
    "ytd": None,   # current year to date — handled separately
    "py": None,   # previous year — handled separately
}
```

- [ ] **Step 2: Update `get_bi_analytics_dashboard` signature**

Change signature from:
```python
async def get_bi_analytics_dashboard(
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(deps.get_db),
):
```

To:
```python
async def get_bi_analytics_dashboard(
    current_user: User = Depends(deps.get_current_user),
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(deps.get_db),
    period: str = "12m",
):
```

- [ ] **Step 3: Validate period and compute `months_back`**

Add after the boss role check (line 378):

```python
    months_back = _PERIOD_MAP.get(period, 12)
```

- [ ] **Step 4: Pass `months_back` to all helper builders**

Change the 4 helper calls from:
```python
    portfolio = await _build_portfolio_performance(db, agency_id)
    tenant_churn = await _build_tenant_churn(db, agency_id)
    financial = await _build_financial_annual(db, agency_id)
    collection = await _build_collection_performance(db, agency_id)
```

To:
```python
    portfolio = await _build_portfolio_performance(db, agency_id, months_back)
    tenant_churn = await _build_tenant_churn(db, agency_id, months_back)
    financial = await _build_financial_annual(db, agency_id, months_back)
    collection = await _build_collection_performance(db, agency_id, months_back)
```

- [ ] **Step 5: Commit**

```bash
cd D:/Projects/EmlakDefteri/backend
git add app/api/endpoints/analytics.py
git commit -m "feat(analytics): add period query param to bi-dashboard"
```

---

## Task 2: Update Helper Functions to Accept `months_back`

**Files:**
- Modify: `backend/app/api/endpoints/analytics.py:35-359`

### 2A: `_build_portfolio_performance` (lines 35-120)

**Signature change (line 35):**
```python
async def _build_portfolio_performance(db: AsyncSession, agency_id: UUID, months_back: int = 12) -> PortfolioPerformanceResponse:
```

**Occupancy trend loop change (line 69):**
```python
    for i in range(months_back - 1, -1, -1):
```

### 2B: `_build_tenant_churn` (lines 127-178)

**Signature change (line 127):**
```python
async def _build_tenant_churn(db: AsyncSession, agency_id: UUID, months_back: int = 12) -> TenantChurnResponse:
```

**Monthly flow loop change (line 138):**
```python
    for i in range(months_back - 1, -1, -1):
```

### 2C: `_build_financial_annual` (lines 185-274)

**Signature change (line 185):**
```python
async def _build_financial_annual(db: AsyncSession, agency_id: UUID, months_back: int = 12) -> FinancialAnnualResponse:
```

**Monthly breakdown loop change (line 209):**
```python
    for i in range(months_back - 1, -1, -1):
```

**Category trends loop change (line 238):**
```python
    for i in range(min(months_back - 1, 5), -1, -1):
```

### 2D: `_build_collection_performance` (lines 281-359)

**Signature change (line 281):**
```python
async def _build_collection_performance(db: AsyncSession, agency_id: UUID, months_back: int = 12) -> CollectionPerformanceResponse:
```

**Monthly rates loop change (line 328):**
```python
    for i in range(months_back - 1, -1, -1):
```

- [ ] **Step 1: Update all 4 signatures and loop ranges**
- [ ] **Step 2: Verify with curl**

```bash
curl -s "http://localhost:8000/api/v1/analytics/bi-dashboard?period=3m" \
  -H "Authorization: Bearer dev_bypass_token_12345" | \
  python -c "import sys,json; d=json.load(sys.stdin); print('occupancy_trend months:', len(d['portfolio']['occupancy_trend'])); print('monthly_flow months:', len(d['tenant_churn']['monthly_flow'])); print('monthly_breakdown months:', len(d['financial']['monthly_breakdown'])); print('monthly_rates months:', len(d['collection']['monthly_rates']))"
```

Expected output: `occupancy_trend months: 3`, `monthly_flow months: 3`, etc.

- [ ] **Step 3: Test all periods**

```bash
for p in 1m 3m 6m 12m; do
  echo -n "period=$p: "
  curl -s "http://localhost:8000/api/v1/analytics/bi-dashboard?period=$p" \
    -H "Authorization: Bearer dev_bypass_token_12345" | \
    python -c "import sys,json; d=json.load(sys.stdin); print(len(d['financial']['monthly_breakdown']), 'months')"
done
```

- [ ] **Step 4: Commit**

```bash
git add app/api/endpoints/analytics.py
git commit -m "feat(analytics): wire months_back to all helper builders"
```

---

## Task 3: Update Frontend to Send `period` Parameter

**Files:**
- Modify: `frontend/lib/features/agent/screens/bi_analytics_screen.dart:50-79`

### 3A: Provider — Add `period` to fetch

**BIAnalyticsNotifier.fetch change:**
```dart
Future<void> fetch({String period = '12m'}) async {
    state = const AsyncValue.loading();
    try {
      final resp = await ApiClient.dio.get(
        '/analytics/bi-dashboard',
        queryParameters: {'period': period},
      );
```

### 3B: Add `refresh()` that preserves period

Add to `BIAnalyticsNotifier`:
```dart
Future<void> setPeriod(String period) async {
    await fetch(period: period);
}
```

### 3C: Period button — call API on tap

Change the `onTap` at line 511 from:
```dart
onTap: () => setState(() => _selectedPeriod = p),
```

To:
```dart
onTap: () {
    setState(() => _selectedPeriod = p);
    final periodMap = {'Bu Ay': '1m', 'Son 3 Ay': '3m', 'Son 6 Ay': '6m', 'Bu Yıl': '12m', 'Geçen Yıl': 'py'};
    ref.read(biAnalyticsProvider.notifier).fetch(period: periodMap[p] ?? '12m');
},
```

- [ ] **Step 1: Make the 3 code changes above**
- [ ] **Step 2: Run flutter analyze**

```bash
cd D:/Projects/EmlakDefteri/frontend
flutter analyze lib/features/agent/screens/bi_analytics_screen.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/features/agent/screens/bi_analytics_screen.dart
git commit -m "feat(bi): send period param to backend on filter tap"
```

---

## Task 4: Write Integration Test

**Files:**
- Create: `backend/tests/test_analytics_period.py`

- [ ] **Step 1: Write failing test**

```python
import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app

@pytest.mark.asyncio
async def test_bi_dashboard_respects_period_param():
    """bi-dashboard should return N months of data when ?period=Nm."""
    async with AsyncClient(
        transport=ASGITransport(app=app),
        base_url="http://test",
        headers={"Authorization": "Bearer dev_bypass_token_12345"},
    ) as client:
        for period, expected_months in [("1m", 1), ("3m", 3), ("6m", 6), ("12m", 12)]:
            resp = await client.get(f"/api/v1/analytics/bi-dashboard?period={period}")
            assert resp.status_code == 200, f"period={period} failed"
            data = resp.json()
            assert len(data["financial"]["monthly_breakdown"]) == expected_months, \
                f"period={period}: expected {expected_months}, got {len(data['financial']['monthly_breakdown'])}"
            assert len(data["tenant_churn"]["monthly_flow"]) == expected_months
            assert len(data["portfolio"]["occupancy_trend"]) == expected_months
            assert len(data["collection"]["monthly_rates"]) == expected_months
```

- [ ] **Step 2: Run to verify it fails**

```bash
cd D:/Projects/EmlakDefteri/backend
pytest tests/test_analytics_period.py -v 2>&1 | tail -20
```

Expected: AssertionError with wrong month count (because filter not implemented yet)

- [ ] **Step 3: Verify fixes work**

After implementing Tasks 1-3, re-run. All should pass.

- [ ] **Step 4: Commit**

```bash
git add tests/test_analytics_period.py
git commit -m "test(analytics): period filter integration tests"
```

---

## Verification Checklist

- [ ] `period=1m` returns 1 month of data in all 4 sections
- [ ] `period=3m` returns 3 months of data in all 4 sections
- [ ] `period=6m` returns 6 months of data in all 4 sections
- [ ] `period=12m` returns 12 months of data in all 4 sections
- [ ] Default (no param) returns 12 months (backwards compatible)
- [ ] `flutter analyze` passes with no issues
- [ ] All 4 pytest tests pass
