# Geliştirme Adımları — PRD v2.0 Eksiklikler

> **Tarih:** 16 Nisan 2026
> **Kaynak:** `development_report_2.0.md` (107/115 madde tamamlandı — 8 eksik)
> **Hedef:** Tüm eksikliklerin nasıl düzeltileceğini adım adım açıklar

---

## GENEL ÖZET

| #   | Eksiklik                               | Öncelik | Tahmini Süre |
|-----|----------------------------------------|---------|-------------|
| 1   | `ai_matched = True` atanmıyor         | Kritik  | 5 dakika    |
| 2 | `custom_category` kaydedilmiyor | Kritik | 5 dakika |
| 3 | BI Analytics admin-only kontrolü yok | Kritik | 15 dakika |
| 4 | Sözleşme PDF yükleme bağlantısı yok | Orta | 30 dakika |
| 5 | Ev Sahibi schema `documents` alanı yok | Orta | 15 dakika |
| 6 | Chat offline timestamp korunmuyor | Orta | 20 dakika |
| 7 | Fotoğraflara timestamp damgası basılmıyor | Orta | 45 dakika |
| 8 | "Destek İstiyorum" buton metni farklı | Düşük | 2 dakika |

---

## EKSİKLİK 1 — `ai_matched = True` Atanmıyor (Kritik)

### 📍 Konum
`backend/app/services/finance_service.py` — satır 109–119

### 🔍 Sorun
AI eşleşmesiyle oluşturulan `FinancialTransaction` kaydında `ai_matched=True` atanmıyor. `FinancialTransaction` modelinde `ai_matched` alanı mevcut (satır 43) ama oluşturulurken set edilmiyor.

### ✅ Çözüm

**Dosya:** `backend/app/services/finance_service.py`

**Bul:** (satır 108–119)
```python
new_tx = FinancialTransaction(
    agency_id=matched_tenant.agency_id,
    tenant_id=best_match_tenant_id,
    unit_id=matched_tenant.unit_id,
    type=TransactionType.income,
    category=ai_category,
    amount=amount_paid,
    transaction_date=datetime.strptime(tx_date_str, "%Y-%m-%d").date() if "-" in tx_date_str else datetime.now().date(),
    description=f"[Otonom AI] {ai_tx.get('description', '')} | AI Kategori: {ai_category_str}"
)
db.add(new_tx)
```

**Değiştir:**
```python
new_tx = FinancialTransaction(
    agency_id=matched_tenant.agency_id,
    tenant_id=best_match_tenant_id,
    unit_id=matched_tenant.unit_id,
    type=TransactionType.income,
    category=ai_category,
    amount=amount_paid,
    transaction_date=datetime.strptime(tx_date_str, "%Y-%m-%d").date() if "-" in tx_date_str else datetime.now().date(),
    description=f"[Otonom AI] {ai_tx.get('description', '')} | AI Kategori: {ai_category_str}",
    ai_matched=True  # ✅ EKLENDI — AI eşleşmesini işaretle
)
db.add(new_tx)
```

### 🧪 Doğrulama
1. Backend'i yeniden başlat: `uvicorn app.main:app --reload --port 8000`
2. PDF ekstresi yükle (Ekstre Yükle butonu)
3. Veritabanında `financial_transactions` tablosunda `ai_matched=True` olan kayıt olmalı
4. `finance_tab.dart` UI'da `🤖 Otomatik Eşleşti` etiketi görünmeli

---

## EKSİKLİK 2 — `custom_category` Kaydedilmiyor (Kritik)

### 📍 Konum
`backend/app/api/endpoints/finance.py` — satır 247–258

### 🔍 Sorun
`ManualTransactionCreate` schema'sında `custom_category` alanı mevcut (schema satır 43) ama `create_transaction` endpoint'i bu alanı `FinancialTransaction` oluştururken **kullanmıyor**. Sütun her zaman NULL kalır.

### ✅ Çözüm

**Dosya:** `backend/app/api/endpoints/finance.py`

**Bul:** (satır 247–258)
```python
new_tx = FinancialTransaction(
    agency_id=agency_id,
    property_id=data.property_id,
    unit_id=data.unit_id,
    tenant_id=data.tenant_id,
    type=data.type,
    category=data.category,
    amount=data.amount,
    currency="TRY",
    transaction_date=data.transaction_date,
    description=data.description,
)
```

**Değiştir:**
```python
new_tx = FinancialTransaction(
    agency_id=agency_id,
    property_id=data.property_id,
    unit_id=data.unit_id,
    tenant_id=data.tenant_id,
    type=data.type,
    category=data.category,
    amount=data.amount,
    currency="TRY",
    transaction_date=data.transaction_date,
    description=data.description,
    custom_category=data.custom_category,  # ✅ EKLENDI — Özel kategori kaydediliyor
)
```

### 🧪 Doğrulama
1. Mali Rapor ekranında "Yeni İşlem Ekle" aç
2. "Yeni Kategori Oluştur" ile özel kategori ekle (örn: "Kira Geçişi")
3. İşlemi kaydet
4. Veritabanında `financial_transactions.custom_category` sütununda değer olmalı
5. Aynı işlem tekrar listelendiğinde özel kategori görünmeli

---

## EKSİKLİK 3 — BI Analytics Admin-Only Erişim Kontrolü Yok (Kritik)

### 📍 Konum
`backend/app/api/endpoints/analytics.py` — satır 356

### 🔍 Sorun
PRD §4.1.10 ve §4.1.10-E'ye göre BI Analytics ekranına **yalnızca Admin rolü** erişebilir. Mevcut kodda sadece yorum var ama gerçek rol kontrolü yok.

### ✅ Çözüm

**Dosya:** `backend/app/api/endpoints/analytics.py`

**Bul:** (satır ~345–358)
```python
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

    NOT: Yalnızca admin rolü erişebilir (ileride auth kontrolü eklenecek).
    """
```

**Değiştir:**
```python
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
    from app.models.users import AgencyStaff

    staff_stmt = select(AgencyStaff).where(
        AgencyStaff.user_id == current_user.id,
        AgencyStaff.agency_id == agency_id,
    )
    staff_result = await db.execute(staff_stmt)
    staff_record = staff_result.scalar_one_or_none()

    if not staff_record or staff_record.role != "admin":
        raise HTTPException(
            status_code=403,
            detail="Bu sayfaya yalnızca Admin erişebilir."
        )
```

**Dosyanın başındaki import'lara ekle** (varsa kontrol et, yoksa ekle):
```python
from app.models.users import AgencyStaff
```

### 🧪 Doğrulama
1. Admin kullanıcıyla `/bi-dashboard` endpoint'ini çağır → 200 OK
2. Agent/Danışman rolüyle çağır → 403 Forbidden hatası dönmeli
3. Backend log: `detail: "Bu sayfaya yalnızca Admin erişebilir."`

---

## EKSİKLİK 4 — Sözleşme PDF Yükleme Flutter Bağlantısı Yok (Orta)

### 📍 Konum
`frontend/lib/features/agent/screens/tenants_management_screen.dart` — satır 496–502

### 🔍 Sorun
Backend endpoint hazır (`POST /tenants/{tenant_id}/upload-contract`) ama Flutter'da `file_picker` + API çağrısı bağlanmamış. Mevcut fonksiyon sadece snackbar gösteriyor.

### ✅ Çözüm

**Dosya:** `frontend/lib/features/agent/screens/tenants_management_screen.dart`

**Bul:** (satır ~496–502)
```dart
Future<void> _uploadContract(String tenantId) async {
    // In a real app, this would use file_picker to pick PDF/image
    // Then PATCH /tenants/{id}/upload-contract with the returned URL
    _showSuccess('Sözleşme yükleme: Backend endpoint hazır (POST /upload/media → /tenants/{id}/upload-contract)');
}
```

**Değiştir:**
```dart
Future<void> _uploadContract(String tenantId) async {
    try {
      // 1. PDF dosyasını seç
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      if (file.path == null) {
        _showError('Dosya seçilemedi');
        return;
      }

      // 2. Dosyayı Hetzner Object Storage'a yükle
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path!,
          filename: file.name,
        ),
        'category': 'contracts',  // contracts klasörüne yüklenecek
      });

      final uploadResp = await ApiClient.dio.post(
        '/media/upload',
        data: formData,
      );

      if (uploadResp.statusCode != 200 || uploadResp.data == null) {
        _showError('Dosya yüklenemedi');
        return;
      }

      final fileUrl = uploadResp.data['url'] as String;

      // 3. Backend'e URL'i bildir
      final updateResp = await ApiClient.dio.patch(
        '/tenants/$tenantId/upload-contract',
        data: {'contract_url': fileUrl},
      );

      if (updateResp.statusCode == 200) {
        _showSuccess('Sözleşme başarıyla yüklendi');

        // Kiracı listesini yenile
        _loadTenants();
      } else {
        _showError('Sözleşme URL güncellenemedi');
      }
    } catch (e) {
      _showError('Yükleme hatası: $e');
    }
  }
```

**Not:** `MultipartFile` ve `FormData` için şu import'ların dosyada olduğundan emin ol:
```dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
```

### 🧪 Doğrulama
1. Kiracı Yönetimi ekranını aç
2. Bir kiracının satırındaki "Sözleşme Yükle" butonuna tıkla
3. PDF dosya seç (dosya seçici açılmalı)
4. Yükle tamamlandığında snackbar "Sözleşme başarıyla yüklendi" mesajı verir
5. Veritabanında `tenants.contract_document_url` güncellenmiş olmalı

---

## EKSİKLİK 5 — Ev Sahibi Schema `documents` Alanı Yok (Orta)

### 📍 Konum
`backend/app/schemas/landlord.py` — `LandlordTenantPerformance` class (satır 61–81)

### 🔍 Sorun
Ev Sahibi, kiracı performansı ekranında sözleşme belgelerini göremez. `LandlordTenantPerformance` response schema'sında `documents` alanı bulunmuyor. Tenant modelinde `documents` alanı mevcut (`backend/app/models/tenants.py` satır 42).

### ✅ Çözüm

**Dosya:** `backend/app/schemas/landlord.py`

**Bul:** (satır 61–81)
```python
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
```

**Değiştir (satır 80'den sonra ekle):**
```python
    payment_history: List[PaymentMonthItem] = []
    documents: Optional[List[Dict[str, Any]]] = []  # ✅ EKLENDI — Sözleşme belgeleri (PRD §4.3.2-C)
```

**Şimdi backend'de bu veriyi döndürmemiz gerekiyor.** İlgili endpoint'i bul ve güncelle:

**Dosya:** `backend/app/api/endpoints/landlord.py` (veya ilgili dosya)

`LandlordTenantPerformance` döndüren fonksiyonu bul (genellikle `/landlord/unit/{unit_id}/tenant-performance` gibi bir endpoint olmalı). Orada Tenant modelinden `documents` alanını çekip schema'ya ekle.

Örnek (endpoint'te değişiklik gerekirse):
```python
# LandlordTenantPerformance response'da documents alanını doldur
tenant_record = result.scalar_one_or_none()
documents = tenant_record.documents if tenant_record else []

return LandlordTenantPerformance(
    ...
    documents=documents,  # ✅ EKLENDI
)
```

### 🧪 Doğrulama
1. Ev Sahibi panelinde bir daireye tıkla
2. "Kiracı Performansı" bölümünde belgeler listesi görünür olmalı
3. `documents` alanı boş değilse (sözleşme yüklendiyse) PDF linkleri görünür

---

## EKSİKLİK 6 — Chat Offline Timestamp Korunmuyor (Orta)

### 📍 Konum
`frontend/lib/core/offline/sync_service.dart` — satır 56–78

### 🔍 Sorun
Offline gönderilen mesajların orijinal zaman damgası (`created_at`) sunucuya replay edilmiyor. Bağlantı gelince mesaj yeni timestamp ile kaydediliyor.

PRD §5.2: *"cihaz internet bağlantısını yeniden sağladığı anda... kullanıcının asıl 'Gönderme' zaman damgasıyla (timestamp) karşı tarafa iletilir"*

### ✅ Çözüm

**Dosya:** `frontend/lib/core/offline/offline_storage.dart` (outbox mesajını kaydeden yer)

Outbox'a kaydedilen mesajda `created_at` timestamp'i saklanıyor olmalı. Önce kontrol et:

```dart
// offline_storage.dart — outbox'a mesaj eklerken timestamp ekle
Future<void> addToOutbox({
  required String localId,
  required String conversationId,
  required String message,
  required DateTime createdAt,  // ✅ Eklenmeli
}) async {
  final outbox = await _getOutbox();
  outbox.add({
    'local_id': localId,
    'conversation_id': conversationId,
    'message': message,
    'created_at': createdAt.toIso8601String(),  // ✅ Eklenmeli
  });
  await _saveOutbox(outbox);
}
```

**Dosya:** `frontend/lib/core/offline/sync_service.dart`

**Bul:** (satır 56–78)
```dart
for (final msg in pending) {
  final id = msg['local_id'] as String;
  final conversationId = msg['conversation_id'] as String?;
  final message = msg['message'] as String? ?? '';

  try {
    if (conversationId != null && conversationId.isNotEmpty) {
      final resp = await ApiClient.dio.post('/chat/messages', data: {
        'conversation_id': conversationId,
        'message': message,
        'type': 'message',
      });
```

**Değiştir:**
```dart
for (final msg in pending) {
  final id = msg['local_id'] as String;
  final conversationId = msg['conversation_id'] as String?;
  final message = msg['message'] as String? ?? '';
  final createdAtStr = msg['created_at'] as String?;

  try {
    if (conversationId != null && conversationId.isNotEmpty) {
      final requestData = {
        'conversation_id': conversationId,
        'message': message,
        'type': 'message',
      };

      // ✅ EKLENDI — Orijinal timestamp'i koru (PRD §5.2)
      if (createdAtStr != null) {
        requestData['client_created_at'] = createdAtStr;
      }

      final resp = await ApiClient.dio.post('/chat/messages', data: requestData);
```

**Backend'de karşılamak için** — Backend endpoint'inde `client_created_at` varsa onu kullan, yoksa sunucu zamanını kullan:

**Dosya:** `backend/app/api/endpoints/chat.py` — `POST /chat/messages`

```python
@router.post("/messages")
async def send_message(
    conversation_id: str,
    message: str,
    type: str = "message",
    client_created_at: Optional[str] = None,  # ✅ EKLENDI
    ...
):
    # client_created_at varsa onu kullan, yoksa şimdiki zamanı kullan
    if client_created_at:
        try:
            created_at = datetime.fromisoformat(client_created_at.replace("Z", "+00:00"))
        except:
            created_at = datetime.utcnow()
    else:
        created_at = datetime.utcnow()
```

### 🧪 Doğrulama
1.飞行 MODE'u aç (interneti kapat)
2. Kiracıya mesaj gönder → "Bekliyor" ikonu görünür
3. Internet'i aç → mesaj sync olur
4. Veritabanında `chat_messages.created_at` orijinal gönderim zamanını gösterir (sunucu zamanını değil)

---

## EKSİKLİK 7 — Fotoğraflara Timestamp Damgası Basılmıyor (Orta)

### 📍 Konum
`frontend/lib/features/tenant/tabs/tenant_support_tab.dart` — satır 516–527

### 🔍 Sorun
PRD §4.2.2-B ve §4.1.7-B'ye göre: *"Sistem bu fotoğrafların üzerine arka planda Tarih ve Saat Etiketi (Timestamp) basar"*

Mevcut kod sadece `ImagePicker` ile görsel seçiyor, üzerine timestamp basmıyor.

### ✅ Çözüm

**Dosya:** `frontend/lib/features/tenant/tabs/tenant_support_tab.dart`

**Mevcut:** `_pickAndStampImage` sadece dosya seçiyor:
```dart
Future<void> _pickAndStampImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;

    final path = result.files.single.path;
    if (path == null) return;

    setState(() => _attachmentPath = path);
}
```

**Değiştir:**
```dart
Future<void> _pickAndStampImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;

    final path = result.files.single.path;
    if (path == null) return;

    // ✅ EKLENDI — Görsel üzerine timestamp bas (PRD §4.2.2-B)
    final stampedPath = await _stampImageWithTimestamp(path);
    if (stampedPath != null) {
      setState(() => _attachmentPath = stampedPath);
    } else {
      // Timestamp basılamazsa orijinal dosyayı kullan
      setState(() => _attachmentPath = path);
    }
}

Future<String?> _stampImageWithTimestamp(String imagePath) async {
    try {
      // Görseli oku
      final bytes = await File(imagePath).readAsBytes();
      final codec = await instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      // Canvas oluştur
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final size = Size(image.width.toDouble(), image.height.toDouble());

      // Orijinal görseli çiz
      canvas.drawImage(image, Offset.zero, Paint());

      // Timestamp metni oluştur
      final timestamp = _timestampNow();
      final textStyle = TextStyle(
        color: Colors.white,
        fontSize: size.width * 0.03,  // Responsive font size
        fontWeight: FontWeight.bold,
        shadows: const [
          Shadow(
            offset: Offset(1, 1),
            blurRadius: 3,
            color: Colors.black54,
          ),
        ],
      );

      // Sağ alt köşeye timestamp bas
      final textSpan = TextSpan(text: timestamp, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      // Padding
      final padding = size.width * 0.02;
      final offset = Offset(
        size.width - textPainter.width - padding,
        size.height - textPainter.height - padding,
      );

      // Arka plan kutusu çiz (okunakarlık için)
      final bgRect = Rect.fromLTWH(
        offset.dx - 4,
        offset.dy - 2,
        textPainter.width + 8,
        textPainter.height + 4,
      );
      canvas.drawRect(bgRect, Paint()..color = Colors.black38);

      textPainter.paint(canvas, offset);

      // Kaydet
      final picture = recorder.endRecording();
      final stampedImage = await picture.toImage(
        image.width,
        image.height,
      );
      final pngBytes = await stampedImage.toByteData(
        format: ImageByteFormat.png,
      );

      if (pngBytes == null) return null;

      // Geçici dosyaya yaz
      final dir = await getTemporaryDirectory();
      final stampedFile = File(
        '${dir.path}/stamped_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await stampedFile.writeAsBytes(pngBytes.buffer.asUint8List());

      return stampedFile.path;
    } catch (e) {
      debugPrint('Timestamp basma hatası: $e');
      return null;
    }
}
```

**Ek olarak dosyanın başına import ekle:**
```dart
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/rendering.dart';
```

### 🧪 Doğrulama
1. Kiracı olarak Destek ekranını aç
2. "Yeni Talep" aç
3. Fotoğraf ekle butonuna tıkla
4. Fotoğraf seç
5. Gönderilen fotoğrafta sağ alt köşede tarih-saat damgası görünür olmalı
6. Admin Destek ekranında da aynı damga görünür

---

## EKSİKLİK 8 — "Destek İstiyorum" Buton Metni Farklı (Düşük)

### 📍 Konum
`frontend/lib/features/tenant/tabs/tenant_support_tab.dart` — satır 184

### 🔍 Sorun
PRD §4.2.2'de buton metni: *"🛠️ Destek İstiyorum"*
Mevcut kod: *"Yeni Talep"*

### ✅ Çözüm

**Dosya:** `frontend/lib/features/tenant/tabs/tenant_support_tab.dart`

**Bul:** (satır ~183–187)
```dart
label: const Text(
    'Yeni Talep',
    style: TextStyle(fontWeight: FontWeight.bold),
),
```

**Değiştir:**
```dart
label: const Text(
    'Destek İstiyorum',  // ✅ DÜZELTILDI — PRD §4.2.2 ile uyumlu
    style: TextStyle(fontWeight: FontWeight.bold),
),
```

Ayrıca aynı dosyada PRD §4.2.2'deki diğer metinlerle uyum için kontrol et:
- Satır 626: `'Yeni Destek Talebi'` → `'Destek İstiyorum'` olarak değiştirilebilir (opsiyonel)

### 🧪 Doğrulama
1. Kiracı Destek ekranını aç
2. FAB butonunun altında "Destek İstiyorum" yazısı görünür

---

## SIRALAMA ÖNERİSİ (Öncelik Sırasına Göre)

1. **Eksiklik 1** (`ai_matched`) — Hemen düzelt, AI tahsilat akışının doğru çalışması için kritik
2. **Eksiklik 2** (`custom_category`) — Hemen düzelt, mali rapor özelliği için kritik
3. **Eksiklik 3** (Admin kontrolü) — Hemen düzelt, güvenlik için kritik
4. **Eksiklik 4** (PDF yükleme) — Orta vadede düzelt
5. **Eksiklik 5** (Landlord documents) — Orta vadede düzelt
6. **Eksiklik 6** (Chat timestamp) — Orta vadede düzelt
7. **Eksiklik 7** (Foto timestamp) — Orta vadede düzelt
8. **Eksiklik 8** (Buton metni) — Düşük öncelikli

---

## TEST PLANI

Her düzeltmeden sonra şunları test et:

| Düzeltme | Test Adımları |
|----------|--------------|
| ai_matched | PDF ekstresi yükle → `financial_transactions.ai_matched = True` kontrol et |
| custom_category | Manuel işlem ekle → Özel kategori seç → DB'de `custom_category` dolu kontrol et |
| Admin kontrolü | Agent rolüyle BI Dashboard çağır → 403 hatası al |
| PDF yükleme | Sözleşme yükle → Backend endpoint çağır → `contract_document_url` güncellenir |
| Landlord docs | Ev Sahibi panelinde kiracı detayı aç → Belgeler listesi görünür |
| Chat timestamp | Offline mesaj → Sync → `created_at` orijinal zamanı gösterir |
| Foto timestamp | Destek talebi fotoğrafı → Yüklenen fotoğrafta tarih damgası görünür |
| Buton metni | Kiracı Destek aç → "Destek İstiyorum" yazısı görünür |
