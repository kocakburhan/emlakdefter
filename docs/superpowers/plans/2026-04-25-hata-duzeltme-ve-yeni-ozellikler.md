# Hata Düzeltme ve Yeni Özellik Implementasyonu

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 6 kritik hatayı düzeltmek ve 2 yeni özellik eklemek

**Architecture:**
- Backend: FastAPI endpoints for broadcast notification (query→body), media upload integration
- Frontend: Unit detail screen photo upload, tenant creation flow, input theme contrast fixes

**Tech Stack:** Flutter, FastAPI, PostgreSQL, Firebase Auth

---

## Maddeler (Issues)

### 1. [BUG] Broadcast Bildirim 422 Hatası — `title` ve `body` query değil body olmalı
**Dosya:** `backend/app/api/endpoints/properties.py:218-279`
**Sorun:** Endpoint `title: str` ve `body: str` yi query parameter olarak alıyor ama frontend JSON body ile POST atıyor → 422 Unprocessable Entity
**Çözüm:** Endpoint signature'ı `Body(...)` kullanacak şekilde güncelle

### 2. [YENİ ÖZELLİK] Dairelere Görsel Eklenemiyor — Unit Detail'e Fotoğraf Upload Butonu Ekle
**Dosya:** `frontend/lib/features/agent/screens/unit_detail_screen.dart`
**Sorun:** `_MediaSection` sadece mevcut fotoları gösteriyor, fotoğraf ekleme butonu yok
**Çözüm:**
- `_MediaSection`'a `image_picker` ile fotoğraf seçme butonu ekle
- `/upload/media` endpoint'ine POST at (multipart/form-data, category: 'media')
- Dönen URL'i `media_links` array'ine ekle
- `PUT /properties/{property_id}/units/{unit_id}` veya yeni endpoint ile kaydet

### 3. [YENİ ÖZELLİK] Her Daire İçin Döküman Yükleme
**Dosya:** `frontend/lib/features/agent/screens/unit_detail_screen.dart`
**Sorun:** PRD §4.1.4-A'da belge yükleme (sözleşme, taahhütname) belirtiliyor ama unit detail'de yok
**Çözüm:**
- Document section ekle ( `_DocumentSection` widget)
- Aynı `/upload/media` endpoint kullan, category: 'document'
- Belgeler listesi göster ve yeni ekle butonu

### 4. [YENİ ÖZELLİK] Daire Ekranda "Yeni Kiracı Ekle" Butonu ve Akışı
**Dosya:** `frontend/lib/features/agent/screens/property_detail_screen.dart` + backend tenant creation
**Sorun:** Kiracı oluşturma akışı PRD §4.1.4'te belirtiliyor ama UI'da eksik
**Çözüm:**
- Property detail veya unit detail'de "Kiracı Ekle" butonu
- Bottom sheet'te form: `Ad Soyad`, `Email`, `Telefon`, `Şifre`
- Backend'de yeni endpoint: `POST /tenants/create-with-user` veya mevcut endpoint kullan
- Firebase Auth'da kullanıcı oluştur, UID'yi tenant + user tablosuna kaydet

### 5. [HATA] Apartmana Ait Özellikler Bina Özelliği Olarak Yansımıyor
**Dosya:** `frontend/lib/features/agent/screens/unit_detail_screen.dart`
**Sorun:** Unit detail screen'de özellikler building'den değil unit'den okunuyor. PRD §4.1.3-B building özelliklerinin daireye miras olarak aktarılmasını istiyor
**Çözüm:**
- `_FeaturesSection`'ı `_unit?['property']['features']`'den okuyacak şekilde güncelle
- Display logic'i property.features'tan alacak

### 6. [HATA] TextInput Arka Plan ve Yazı Rengi Okunabilirlik Sorunu
**Dosya:** `frontend/lib/core/theme/app_theme.dart:123-150`
**Sorun:** `fillColor: AppColors.surfaceVariant` → text color beyaz veya çok açık renk. Koyu arka plan üstünde kontrast yetersiz
**Çözüm:**
- `fillColor: AppColors.surface` (daha koyu) veya beyaz tut
- `hintStyle` ve `labelStyle` text color'ları kontrol et
- Sadece property_detail_screen'deki custom TextField'lar için değil, tüm app_theme InputDecorationTheme için geçerli

### 7. [HATA] Genel — Diğer Ekramlarda Aynı TextInput Sorunu
**Dosya:** Birden fazla screen dosyası
**Sorun:** Property detail, unit detail ve diğer ekranlardaki TextField'larda aynı kontrast sorunu var
**Çözüm:**
- Tüm custom TextField'ları app_theme.dart'deki standard theme'yi kullanacak şekilde güncelle
- Veya custom TextField'ların fillColor ve text color'larını düzelt

---

## Task Structure

### Task 1: Broadcast Notification Endpoint — Query → Body Fix

**Files:**
- Modify: `backend/app/api/endpoints/properties.py:218-279`

- [ ] **Step 1: Read current endpoint signature**

```python
@router.post("/{property_id}/broadcast-notification")
async def send_property_notification(
    property_id: str,
    title: str,   # ← query param
    body: str,     # ← query param
```

- [ ] **Step 2: Change to Body parameters**

```python
from fastapi import Body

@router.post("/{property_id}/broadcast-notification")
async def send_property_notification(
    property_id: str,
    title: str = Body(...),
    body: str = Body(...),
```

- [ ] **Step 3: Verify no other changes needed (rest of logic stays the same)**

- [ ] **Step 4: Test with curl**

```bash
curl -X POST "http://127.0.0.1:8000/api/v1/properties/{property_id}/broadcast-notification" \
  -H "Content-Type: application/json" \
  -d '{"title": "Test", "body": "Deneme mesajı"}'
```
Expected: 200 with JSON response

---

### Task 2: Unit Detail — Add Photo Upload Button

**Files:**
- Modify: `frontend/lib/features/agent/screens/unit_detail_screen.dart` (~line 980-1100)
- Check: `frontend/lib/core/network/api_client.dart` (for upload method)

- [ ] **Step 1: Find `_MediaSection` widget and understand structure**

```dart
Widget _buildMediaSection() {
  // Current: shows placeholder OR horizontal image list
  // Need: add floating action button or "+" button to add photo
}
```

- [ ] **Step 2: Add image_picker import and dependency check**

Check `pubspec.yaml` for `image_picker` - if not present, note that it needs to be added

- [ ] **Step 3: Add `_addPhoto()` method**

```dart
Future<void> _addPhoto() async {
  final picker = ImagePicker();
  final image = await picker.pickImage(source: ImageSource.gallery);
  if (image == null) return;

  // Show loading indicator
  // Upload to /upload/media with multipart
  final formData = FormData.fromMap({
    'file': await MultipartFile.fromFile(image.path, filename: 'photo.jpg'),
    'category': 'media',
  });
  final resp = await ApiClient.dio.post('/upload/media', data: formData);
  final url = resp.data['url'];

  // Add to media_links
  final current = List<Map<String, dynamic>>.from(_unit?['media_links'] ?? []);
  current.add({'url': url, 'caption': ''});
  // TODO: save to backend
}
```

- [ ] **Step 4: Add "+" button to media section**

Find the media placeholder and add an "add photo" icon button that calls `_addPhoto()`

- [ ] **Step 5: Check for existing backend PUT/PATCH endpoint for updating unit media**

If none exists, note that a new endpoint or update to existing endpoint is needed

---

### Task 3: Unit Detail — Document Upload Section

**Files:**
- Modify: `frontend/lib/features/agent/screens/unit_detail_screen.dart`
- Add: New `_DocumentSection` widget

- [ ] **Step 1: Find where to add document section**

After media section or in a separate tab/card — check existing UI structure

- [ ] **Step 2: Create `_DocumentSection` widget**

```dart
Widget _DocumentSection extends StatelessWidget {
  // Similar to media section but:
  // - Uses documents field instead of media_links
  // - Upload button for PDFs and images
  // - Shows document icon + filename
}
```

- [ ] **Step 3: Add document upload logic**

Same as photo upload but category: 'document'

- [ ] **Step 4: Add to unit detail build method**

---

### Task 4: Kiracı Ekle — Create Tenant + User Flow

**Files:**
- Modify: `frontend/lib/features/agent/screens/property_detail_screen.dart` or `unit_detail_screen.dart`
- Modify: `backend/app/api/endpoints/tenants.py`
- Modify: `backend/app/api/endpoints/auth.py` (if Firebase user creation needed)

- [ ] **Step 1: Read current tenant creation flow**

```python
# tenants.py create_tenant endpoint
# What fields does it accept?
# Does it create a Firebase user?
```

- [ ] **Step 2: Create "Kiracı Ekle" button in property detail screen**

```dart
// In property_detail_screen.dart action bar or header
IconButton(
  icon: Icon(Icons.person_add),
  onPressed: _showAddTenantSheet,
)
```

- [ ] **Step 3: Create `_AddTenantSheet` bottom sheet**

```dart
Future<void> _showAddTenantSheet() async {
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: nameCtrl, decoration: InputDecoration(labelText: "Ad Soyad")),
          TextField(controller: emailCtrl, decoration: InputDecoration(labelText: "Email")),
          TextField(controller: phoneCtrl, decoration: InputDecoration(labelText: "Telefon")),
          TextField(controller: passwordCtrl, obscureText: true, decoration: InputDecoration(labelText: "Şifre")),
          ElevatedButton(
            onPressed: () => _createTenant(nameCtrl.text, emailCtrl.text, phoneCtrl.text, passwordCtrl.text),
            child: Text("Kiracı Oluştur"),
          ),
        ],
      ),
    ),
  );
}
```

- [ ] **Step 4: Create backend endpoint for tenant with user creation**

New endpoint `POST /tenants/create-with-user`:
1. Create Firebase user with email/password via Firebase Admin SDK
2. Create User record in PostgreSQL with firebase_uid
3. Create Tenant record linked to user and unit
4. Return tenant data

```python
@router.post("/create-with-user")
async def create_tenant_with_user(
    unit_id: UUID,
    name: str,
    email: str,
    phone: str,
    password: str,
    rent_amount: int,
    start_date: date,
    end_date: date,
    agency_id: UUID = Depends(deps.get_current_user_agency_id),
):
    # 1. Firebase Admin SDK - create user
    firebase_user = auth.create_user(email=email, password=password, display_name=name)
    # 2. Create User record
    # 3. Create Tenant record
    # 4. Return
```

- [ ] **Step 5: Wire frontend to backend endpoint**

---

### Task 5: Unit Detail — Property Features Display Fix

**Files:**
- Modify: `frontend/lib/features/agent/screens/unit_detail_screen.dart`

- [ ] **Step 1: Find `_FeaturesSection` and `_unit` data structure**

Features come from `_unit?['property']['features']` — currently reading from wrong field

- [ ] **Step 2: Verify current data flow**

```dart
// Current (potentially wrong):
final features = _unit?['features'];

// Should be:
final features = _unit?['property']?['features'];
```

- [ ] **Step 3: Update feature reading and display**

Ensure all feature badges read from `property.features` not `unit.features`

---

### Task 6: TextInput Theme Contrast Fix — app_theme.dart

**Files:**
- Modify: `frontend/lib/core/theme/app_theme.dart:123-150`

- [ ] **Step 1: Read current InputDecorationTheme**

```dart
inputDecorationTheme: InputDecorationTheme(
  filled: true,
  fillColor: AppColors.surfaceVariant,  // ← problem?
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  // ...
)
```

- [ ] **Step 2: Check AppColors to understand surfaceVariant vs background**

```dart
// In colors.dart, find:
AppColors.surfaceVariant  // what color?
AppColors.background      // what color?
AppColors.surface        // what color?
```

- [ ] **Step 3: Fix fillColor and text colors**

```dart
inputDecorationTheme: InputDecorationTheme(
  filled: true,
  fillColor: Colors.white,  // or AppColors.surface if dark enough
  // text color on white/dark backgrounds needs proper contrast
  hintStyle: _baseTextStyle.copyWith(color: AppColors.textSecondary, fontSize: 14),
  labelStyle: _baseTextStyle.copyWith(color: AppColors.textSecondary, fontSize: 14),
),
```

- [ ] **Step 4: Also fix custom TextFields in property_detail_screen.dart**

The custom TextFields in `_showBroadcastDialog()` use:
```dart
filled: true,
fillColor: AppColors.background,  // dark background
style: TextStyle(color: Colors.white),  // white text → GOOD contrast
labelStyle: TextStyle(color: AppColors.textSecondary),  // gray label
```
These look fine — verify and document

- [ ] **Step 5: Audit other screens for text contrast issues**

Search for `filled: true, fillColor:` patterns across all screens

---

## Self-Review Checklist

1. **Spec coverage:** All 7 issues addressed?
2. **Placeholder scan:** No "TODO", "TBD", "fill in later"
3. **Type consistency:** Backend/frontend field names match?

## Dependencies

- `image_picker` Flutter package (for photo upload)
- Firebase Admin SDK access for user creation
- `multipart` support in ApiClient (check if upload works)

## Verification Commands

```bash
# Backend
cd backend
uvicorn app.main:app --reload --port 8000

# Broadcast notification test
curl -X POST "http://127.0.0.1:8000/api/v1/properties/{property_id}/broadcast-notification" \
  -H "Content-Type: application/json" \
  -d '{"title": "Test Bildirim", "body": "Deneme mesajı"}'

# Frontend
cd frontend
flutter run
```
