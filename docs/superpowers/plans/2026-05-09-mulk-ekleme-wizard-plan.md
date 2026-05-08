# Mülk Ekleme Wizard — Implementation Plan

**Goal:** 2 aşamalı wizard ile mülk ekleme: (1) İşlem Tipi + Mülk Tipi seçimi, (2) Koşullu form gösterimi. "both" seçeneği ile aynı mülk hem kiralık hem satılık olabilir.

**Architecture:** Backend'de Property ve PropertyUnit tablolarına `listing_type` alanı eklenir. Frontend'de mevcut CreatePropertyBottomSheet'e wizard akışı entegre edilir. "Apartman Dairesi" için yeni tek-birim formu oluşturulur.

**Tech Stack:** Python/FastAPI backend, Flutter/Riverpod frontend, PostgreSQL (RLS)

---

## Adım 1: Backend — PropertyType Enum'a `apartment_unit` Ekle

**Files:**
- Modify: `backend/app/models/properties.py:7-11`

```python
class PropertyType(str, enum.Enum):
    apartment_complex = "apartment_complex"  # Apartman/Site
    apartment_unit = "apartment_unit"         # YENİ: Apartman Dairesi (tek birim)
    standalone_house = "standalone_house"
    land = "land"
    commercial = "commercial"
```

- [ ] **Step 1: Değişikliği uygula** — Yukarıdaki enum'u `backend/app/models/properties.py`'e uygula
- [ ] **Step 2: Commit**

```bash
git add backend/app/models/properties.py
git commit -m "feat(models): add apartment_unit to PropertyType enum"
```

---

## Adım 2: Backend — Property Tablosuna `listing_type` Sütunu Ekle

**Files:**
- Modify: `backend/app/models/properties.py:13-32`

Property model'e yeni alan ekle:

```python
class Property(BaseModel):
    __tablename__ = "properties"

    agency_id = Column(UUID(as_uuid=True), ForeignKey("agencies.id", ondelete="CASCADE"), nullable=False, index=True)
    name = Column(String, nullable=False)
    type = Column(Enum(PropertyType), nullable=False)
    address = Column(String, nullable=True)
    total_units = Column(Integer, default=1)
    central_dues = Column(Integer, default=0)
    features = Column(JSON, nullable=True)

    # YENİ ALANLAR
    floor_count = Column(Integer, nullable=True)
    year_built = Column(Integer, nullable=True)
    land_area = Column(Integer, nullable=True)
    commercial_type = Column(String, nullable=True)

    # YENİ: İşlem tipi (for_rent, for_sale, both)
    listing_type = Column(String, nullable=True)

    agency = relationship("Agency", back_populates="properties")
    units = relationship("PropertyUnit", back_populates="property")
```

- [ ] **Step 1: Değişikliği uygula** — `listing_type` sütununu Property model'e ekle
- [ ] **Step 2: Commit**

```bash
git add backend/app/models/properties.py
git commit -m "feat(models): add listing_type column to Property"
```

---

## Adım 3: Backend — PropertyUnit Tablosuna `listing_type` Sütunu Ekle

**Files:**
- Modify: `backend/app/models/properties.py:38-61`

PropertyUnit model'e yeni alan ekle:

```python
class PropertyUnit(BaseModel):
    __tablename__ = "property_units"

    agency_id = Column(UUID(as_uuid=True), ForeignKey("agencies.id", ondelete="CASCADE"), nullable=False, index=True)
    property_id = Column(UUID(as_uuid=True), ForeignKey("properties.id", ondelete="CASCADE"), nullable=False, index=True)
    door_number = Column(String, nullable=False)
    floor = Column(String, nullable=True)
    status = Column(Enum(UnitStatus), default=UnitStatus.vacant, nullable=False)
    vacant_since = Column(DateTime, nullable=True)
    dues_amount = Column(Integer, default=0)
    rent_price = Column(Integer, nullable=True)
    commission_rate = Column(Float, default=0.0)
    youtube_video_link = Column(String, nullable=True)
    media_links = Column(ARRAY(String), nullable=True)
    features = Column(JSON, nullable=True)
    area_sqm = Column(Integer, nullable=True)
    unit_identifier = Column(String, nullable=True)
    notes = Column(String, nullable=True)

    # YENİ: İşlem tipi (for_rent, for_sale, both)
    listing_type = Column(String, nullable=True)

    property = relationship("Property", back_populates="units")
    landlord_relations = relationship("LandlordUnit", back_populates="unit")
    tenant_contracts = relationship("Tenant", back_populates="unit")
```

- [ ] **Step 1: Değişikliği uygula** — `listing_type` sütununu PropertyUnit model'e ekle
- [ ] **Step 2: Commit**

```bash
git add backend/app/models/properties.py
git commit -m "feat(models): add listing_type column to PropertyUnit"
```

---

## Adım 4: Backend — Schema Güncellemesi

**Files:**
- Modify: `backend/app/schemas/properties.py`

**4.1 PropertyCreate schema'ya listing_type ekle:**

```python
class PropertyCreate(BaseModel):
    """Emlakçının UI formundan doldurup göndereceği paket"""
    name: str = Field(..., description="Mülk Adı")
    type: str = Field(..., description="'apartment_complex', 'apartment_unit', 'standalone_house', 'land' veya 'commercial'")
    address: Optional[str] = None
    central_dues: NonNegativeInt = Field(0)
    features: Optional[Dict[str, Any]] = Field(default_factory=dict)
    listing_type: Optional[str] = Field(None, description="'for_rent', 'for_sale' veya 'both'")

    # Otonom Generative Parameters
    start_floor: Optional[int] = Field(None)
    end_floor: Optional[int] = Field(None)
    units_per_floor: Optional[int] = Field(None)
    floor_config: Optional[List[FloorConfigItem]] = Field(None)
```

**4.2 PropertyResponse schema'ya listing_type ekle:**

```python
class PropertyResponse(BaseModel):
    id: UUID
    agency_id: UUID
    name: str
    type: str
    address: Optional[str]
    total_units: int
    central_dues: int
    features: Optional[Dict[str, Any]]
    created_at: datetime
    listing_type: Optional[str] = None  # YENİ

    class Config:
        from_attributes = True
```

**4.3 PropertyUnitResponse schema'ya listing_type ekle:**

```python
class PropertyUnitResponse(PropertyUnitBase):
    id: UUID
    agency_id: UUID
    property_id: UUID
    status: str
    vacant_since: Optional[datetime] = None
    created_at: datetime
    commission_rate: Optional[float] = None
    youtube_video_link: Optional[str] = None
    media_links: Optional[List[Dict[str, Any]]] = None
    listing_type: Optional[str] = None  # YENİ

    class Config:
        from_attributes = True
```

- [ ] **Step 1: Değişikliği uygula** — Yukarıdaki 3 değişikliği `backend/app/schemas/properties.py`'e uygula
- [ ] **Step 2: Commit**

```bash
git add backend/app/schemas/properties.py
git commit -m "feat(schemas): add listing_type to PropertyCreate, PropertyResponse, PropertyUnitResponse"
```

---

## Adım 5: Backend — API Endpoint'i Güncelle

**Files:**
- Modify: `backend/app/api/endpoints/properties.py`

`listing_type`'ı PropertyCreate'den alıp Property model oluştururken kullan.

Mevcut `create_property` fonksiyonunu incele ve `listing_type` parametresini ekle.

- [ ] **Step 1: API endpoint'i güncelle** — `listing_type`'ı create işlemine ekle
- [ ] **Step 2: Commit**

```bash
git add backend/app/api/endpoints/properties.py
git commit -m "feat(api): accept listing_type in property creation endpoint"
```

---

## Adım 6: Frontend — PropertyModel'e `listingType` Ekle

**Files:**
- Modify: `frontend/lib/features/agent/providers/properties_provider.dart:9-51`

```dart
class PropertyModel {
  final String id;
  final String name;
  final String type;
  final String? address;
  final int totalUnits;
  final int centralDues;
  final Map<String, dynamic>? features;
  final DateTime? createdAt;
  final int emptyUnits;
  final String? listingType; // YENİ: "for_rent" | "for_sale" | "both"

  PropertyModel({
    required this.id,
    required this.name,
    this.type = 'apartment_complex',
    this.address,
    required this.totalUnits,
    this.centralDues = 0,
    this.features,
    this.createdAt,
    this.emptyUnits = 0,
    this.listingType, // YENİ
  });

  factory PropertyModel.fromJson(Map<String, dynamic> json) {
    return PropertyModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? 'apartment_complex',
      address: json['address'],
      totalUnits: json['total_units'] ?? 0,
      centralDues: json['central_dues'] ?? 0,
      features: json['features'] != null
          ? Map<String, dynamic>.from(json['features'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      emptyUnits: 0,
      listingType: json['listing_type'], // YENİ
    );
  }
}
```

- [ ] **Step 1: Değişikliği uygula** — `listingType` alanını PropertyModel'e ekle
- [ ] **Step 2: Commit**

```bash
git add frontend/lib/features/agent/providers/properties_provider.dart
git commit -m "feat(frontend): add listingType to PropertyModel"
```

---

## Adım 7: Frontend — Enum Güncellemeleri

**Files:**
- Modify: `frontend/lib/features/agent/widgets/create_property_bottom_sheet.dart`

**7.1 Yeni enum'ları ekle:**

```dart
enum PropertyFormType {
  apartment,     // → apartment_complex
  apartmentUnit, // → apartment_unit (YENİ)
  villa,         // → standalone_house
  land,
  commercial,
}

enum ListingType {
  forRent,   // "for_rent"
  forSale,   // "for_sale"
  both,      // "both" — YENİ
}
```

**7.2 State değişkenlerini ekle:**

```dart
class _CreatePropertyBottomSheetState extends ConsumerState<CreatePropertyBottomSheet>
    with TickerProviderStateMixin {
  // ... mevcut değişkenler ...

  // YENİ: Wizard adımları
  int _wizardStep = 0; // 0=Tip seçimi, 1=Form
  ListingType? _selectedListingType; // Kiralık/Satılık/Both
  PropertyFormType _selectedType = PropertyFormType.apartment;
}
```

- [ ] **Step 1: Enum'ları ekle**
- [ ] **Step 2: State değişkenlerini ekle**
- [ ] **Step 3: Commit**

```bash
git add frontend/lib/features/agent/widgets/create_property_bottom_sheet.dart
git commit -m "feat(frontend): add ListingType and PropertyFormType enums"
```

---

## Adım 8: Frontend — Wizard Step 0 (Tip Seçimi) UI

**Files:**
- Modify: `frontend/lib/features/agent/widgets/create_property_bottom_sheet.dart`

`build()` metodunda `_wizardStep == 0` ise tip seçim ekranını göster:

```dart
@override
Widget build(BuildContext context) {
  // ...
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      // Handle
      // ...
      Expanded(
        child: _wizardStep == 0
            ? _buildTypeSelectionStep() // YENİ
            : _buildFormStep(),         // Mevcut form
      ),
    ],
  ),
);
```

**`_buildTypeSelectionStep()` UI:**

```dart
Widget _buildTypeSelectionStep() {
  return SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(children: [...]),
        const SizedBox(height: 32),

        // İŞLEM TİPİ SEÇİMİ
        const Text("İŞLEM TİPİ", style: TextStyle(...)),
        const SizedBox(height: 12),
        Row(children: [
          _buildListingTypeChip("KİRALIK", Icons.home, ListingType.forRent),
          const SizedBox(width: 8),
          _buildListingTypeChip("SATILIK", Icons.sell, ListingType.forSale),
          const SizedBox(width: 8),
          _buildListingTypeChip("HER İKİSİ", Icons.swap_horiz, ListingType.both),
        ]),
        const SizedBox(height: 28),

        // MÜLK TİPİ SEÇİMİ
        const Text("MÜLK TİPİ", style: TextStyle(...)),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _buildPropertyTypeChip("APARTMAN/SİTE", Icons.apartment, PropertyFormType.apartment),
            const SizedBox(width: 8),
            _buildPropertyTypeChip("APARTMAN DAİRESİ", Icons.meeting_room, PropertyFormType.apartmentUnit), // YENİ
            const SizedBox(width: 8),
            _buildPropertyTypeChip("MÜSTAKİL EV", Icons.villa, PropertyFormType.villa),
            const SizedBox(width: 8),
            _buildPropertyTypeChip("ARSA/TARLA", Icons.landscape, PropertyFormType.land),
            const SizedBox(width: 8),
            _buildPropertyTypeChip("DÜKKAN", Icons.storefront, PropertyFormType.commercial),
          ]),
        ),
        const SizedBox(height: 40),

        // DEVAM BUTONU
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _canProceed() ? _proceedToForm : null,
            style: ElevatedButton.styleFrom(...),
            child: const Text("DEVAM"),
          ),
        ),
      ],
    ),
  );
}

bool _canProceed() {
  return _selectedListingType != null;
}

void _proceedToForm() {
  setState(() => _wizardStep = 1);
}
```

- [ ] **Step 1: Wizard step 0 UI'ı oluştur** — Tip seçimi ekranı
- [ ] **Step 2: `_canProceed` ve `_proceedToForm` fonksiyonlarını ekle**
- [ ] **Step 3: Chip widget'larını ekle**
- [ ] **Step 4: Commit**

```bash
git add frontend/lib/features/agent/widgets/create_property_bottom_sheet.dart
git commit -m "feat(frontend): add wizard step 0 type selection UI"
```

---

## Adım 9: Frontend — `createProperty` Method'una `listingType` Ekle

**Files:**
- Modify: `frontend/lib/features/agent/providers/properties_provider.dart:108-160`

```dart
Future<int?> createProperty({
  required String name,
  required String type,
  String? address,
  int centralDues = 0,
  Map<String, dynamic>? features,
  int? startFloor,
  int? endFloor,
  int? unitsPerFloor,
  List<Map<String, dynamic>>? floorConfig,
  String? listingType, // YENİ
}) async {
  final currentList = state.value ?? [];

  try {
    final Map<String, dynamic> payload = {
      'name': name,
      'type': type,
      'address': address,
      'central_dues': centralDues,
      'features': features ?? {},
      'listing_type': listingType, // YENİ
    };
    // ...
  }
}
```

- [ ] **Step 1: `createProperty` method'una `listingType` parametresini ekle**
- [ ] **Step 2: Payload'a `listing_type` ekle**
- [ ] **Step 3: Commit**

```bash
git add frontend/lib/features/agent/providers/properties_provider.dart
git commit -m "feat(frontend): add listingType parameter to createProperty"
```

---

## Adım 10: Frontend — Form Step'te Mevcut Formu Koşullu Render Et

**Files:**
- Modify: `frontend/lib/features/agent/widgets/create_property_bottom_sheet.dart`

`_wizardStep == 1` olduğunda, mevcut `_buildDynamicFields()` çağrısından önce `listingType`'ı form'a entegre et.

**10.1 `_submit()` güncelle:**

```dart
void _submit() async {
  // ...
  final response = await ref.read(propertiesProvider.notifier).createProperty(
    name: name,
    type: _typeString,
    address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
    centralDues: int.tryParse(_duesController.text) ?? 0,
    features: featuresMap.isNotEmpty ? featuresMap : null,
    floorConfig: floorConfigPayload,
    listingType: _getListingTypeString(), // YENİ
  );
  // ...
}

String? _getListingTypeString() {
  switch (_selectedListingType) {
    case ListingType.forRent: return 'for_rent';
    case ListingType.forSale: return 'for_sale';
    case ListingType.both: return 'both';
    default: return null;
  }
}
```

- [ ] **Step 1: `_submit()` method'una `listingType` ekle**
- [ ] **Step 2: `_getListingTypeString()` helper'ını ekle**
- [ ] **Step 3: Commit**

```bash
git add frontend/lib/features/agent/widgets/create_property_bottom_sheet.dart
git commit -m "feat(frontend): integrate listingType into form submission"
```

---

## Adım 11: Frontend — Apartman Dairesi İçin Tek-Birim Formu

**Files:**
- Modify: `frontend/lib/features/agent/widgets/create_property_bottom_sheet.dart`

```dart
Widget _buildDynamicFields() {
  switch (_selectedType) {
    case PropertyFormType.apartment:
      return _buildApartmentFields();
    case PropertyFormType.apartmentUnit:     // YENİ
      return _buildApartmentUnitFields();    // YENİ
    case PropertyFormType.villa:
      return _buildVillaFields();
    case PropertyFormType.land:
      return _buildLandFields();
    case PropertyFormType.commercial:
      return _buildCommercialFields();
  }
}

Widget _buildApartmentUnitFields() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text("APARTMAN DAİRESİ BİLGİLERİ", style: TextStyle(...)),
      const SizedBox(height: 12),

      // Kapı numarası
      _buildTextField(
        controller: _nameController, // Kapı no için
        label: "Kapı Numarası",
        hint: "Örn: 15",
        icon: Icons.door_front_door,
      ),
      const SizedBox(height: 16),

      // Kat
      Row(children: [
        Expanded(child: _buildNumberField(_endFloorController, "Kat"))),
        const SizedBox(width: 12),
        Expanded(child: _buildNumberField(_rentController, "Kira (₺)")),
      ]),
      const SizedBox(height: 16),

      // Fiyat (kiralık/satılık/both'a göre)
      if (_selectedListingType == ListingType.forSale ||
          _selectedListingType == ListingType.both)
        _buildNumberField(_blocksController, "Satış Fiyatı (₺)"),

      if (_selectedListingType == ListingType.forRent ||
          _selectedListingType == ListingType.both)
        _buildNumberField(_rentController, "Kira Bedeli (₺)"),

      const SizedBox(height: 12),
      _buildNumberField(_duesController, "Aidat (₺)"),
      const SizedBox(height: 16),

      _buildFeaturesChecklist(),
    ],
  );
}
```

- [ ] **Step 1: `_buildApartmentUnitFields()` fonksiyonunu oluştur**
- [ ] **Step 2: `_buildDynamicFields()`'e case ekle**
- [ ] **Step 3: Commit**

```bash
git add frontend/lib/features/agent/widgets/create_property_bottom_sheet.dart
git commit -m "feat(frontend): add apartment unit single-unit form"
```

---

## Adım 12: Backend — Veritabanı Migrasyon Scripti

**Files:**
- Create: `backend/migrations/versions/xxxx_add_listing_type.py`

```python
"""Add listing_type column to properties and property_units

Revision ID: xxxx
Revises: xxxx
Create Date: 2026-05-09
"""
from alembic import op
import sqlalchemy as sa

revision = 'xxxx'
down_revision = 'xxxx'
branch_labels = None
depends_on = None

def upgrade() -> None:
    op.add_column('properties', sa.Column('listing_type', sa.String(20), nullable=True))
    op.add_column('property_units', sa.Column('listing_type', sa.String(20), nullable=True))

def downgrade() -> None:
    op.drop_column('property_units', 'listing_type')
    op.drop_column('properties', 'listing_type')
```

- [ ] **Step 1: Migrasyon scripti oluştur**
- [ ] **Step 2: Commit**

```bash
git add backend/migrations/versions/xxxx_add_listing_type.py
git commit -m "migration: add listing_type columns to properties and property_units"
```

---

## Adım 13: Test — Backend

**Files:**
- Create: `backend/tests/test_properties.py`

```python
def test_property_with_listing_type():
    response = client.post(
        "/api/v1/properties",
        json={
            "name": "Test Bina",
            "type": "apartment_complex",
            "listing_type": "both",
        }
    )
    assert response.status_code == 201
    data = response.json()
    assert data["listing_type"] == "both"

def test_property_unit_with_listing_type():
    # property creation...
    # unit creation with listing_type...
    pass

def test_apartment_unit_creation():
    response = client.post(
        "/api/v1/properties",
        json={
            "name": "Daire 15",
            "type": "apartment_unit",
            "listing_type": "for_rent",
        }
    )
    assert response.status_code == 201
```

- [ ] **Step 1: Test dosyası oluştur**
- [ ] **Step 2: Testleri çalıştır**
- [ ] **Step 3: Commit**

---

## Adım 14: Test — Frontend

**Files:**
- Modify: `frontend/test/widgets/create_property_bottom_sheet_test.dart`

```dart
void main() {
  testWidgets('Wizard step 0 shows type selection', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: CreatePropertyBottomSheet()),
      ),
    );

    // Step 0 görünür
    expect(find.text('İŞLEM TİPİ'), findsOneWidget);
    expect(find.text('MÜLK TİPİ'), findsOneWidget);
    expect(find.text('DEVAM'), findsOneWidget);

    // Devam butonu disabled
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('Wizard step 0 allows selection and proceeds', (tester) async {
    // Kiralık ve Apartman/Site seç → Devam aktif olmalı
    // Tıkla → Step 1'e geçmeli
  });
}
```

- [ ] **Step 1: Widget testleri oluştur**
- [ ] **Step 2: Testleri çalıştır**
- [ ] **Step 3: Commit**

---

## Özet — Değiştirilecek/Oluşturulacak Dosyalar

| Dosya | İşlem |
|-------|-------|
| `backend/app/models/properties.py` | Enum + 2 yeni sütun |
| `backend/app/schemas/properties.py` | 3 schema güncellemesi |
| `backend/app/api/endpoints/properties.py` | Endpoint güncellemesi |
| `backend/migrations/versions/xxxx_add_listing_type.py` | Yeni migrasyon |
| `frontend/lib/features/agent/providers/properties_provider.dart` | Model + method güncellemesi |
| `frontend/lib/features/agent/widgets/create_property_bottom_sheet.dart` | Wizard + form güncellemeleri |
| `backend/tests/test_properties.py` | Yeni test dosyası |
| `frontend/test/widgets/create_property_bottom_sheet_test.dart` | Yeni test dosyası |

---

**Plan complete and saved to `docs/superpowers/plans/2026-05-09-mulk-ekleme-wizard-plan.md`.**

**Two execution options:**

**1. Subagent-Driven (recommended)** - Her task için ayrı subagent dispatch ederim, checkpoint'lerde review yaparım

**2. Inline Execution** - Bu session içinde executing-plans skill kullanarak adım adım executor yaparım

**Which approach?**