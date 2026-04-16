# EmlakDefteri — Detaylı Geliştirme Adımları

> **Hazırlık:** Bu dosya, `development_report.md`'deki tüm eksiklikleri tamamlamak için gereken her adımı içerir.
> **Ön koşul:** Her adım, önceki adımda yapılan değişikliklerin üzerine inşa eder. Sırayla uygulanmalıdır.
> **Test:** Her adım sonunda ilgili ekranı/el API'ı manual olarak test edin.

---

## FAZA 1 — KRİTİK BUG DÜZELTMELERİ

---

### Adım 1.1: Backend — `landlord.py` `User.agency_id` SQL Hatası Düzeltmesi

**Dosya:** `backend/app/api/endpoints/landlord.py`
**Satır:** ~499-502
**Bug:** `User.agency_id` sütunu yok — `User` modeli `agency_id` içermez, bunun yerine `AgencyStaff` tablosu üzerinden `user ↔ agency` ilişkisi kurulur.
**Etki:** `landlord_send_interest` endpoint'i çağrıldığında `sqlalchemy.exc.InvalidRequestError` fırlatır.

**Mevcut hatalı kod:**
```python
# ~satır 499
agent_stmt = select(User).where(
    User.agency_id == agency_id,   # ❌ HATA: User.agency_id yok
    User.role == "agent",
).limit(1)
```

**Doğru kod:**
```python
# Satır 499 — Aşağıdaki gibi değiştir:
from app.models.users import AgencyStaff

agent_stmt = (
    select(User)
    .join(AgencyStaff, User.id == AgencyStaff.user_id)
    .where(
        AgencyStaff.agency_id == agency_id,
    )
    .limit(1)
)
```

**Tam satırlar (yaklaşık 499-505):**
```python
agent_stmt = (
    select(User)
    .join(AgencyStaff, User.id == AgencyStaff.user_id)
    .where(
        AgencyStaff.agency_id == agency_id,
    )
    .limit(1)
)
agent_res = await db.execute(agent_stmt)
agent_user = agent_res.scalar_one_or_none()
```

**Doğrulama:**
```bash
cd backend
uvicorn app.main:app --reload --port 8000
# Postman/curl ile test:
# POST /landlord/conversations  (token ile) → 200 dönmeli, 500 HATA OLMAMALI
```

---

### Adım 1.2: Frontend — Chat `client_role` Schema Uyumsuzluğu Düzeltmesi

**Dosya:** `frontend/lib/features/agent/tabs/chat_tab.dart`
**Satır:** ~574-577
**Bug:** `_NewChatSheet._startOrOpenChat()` `POST /chat/conversations` isteğinde `client_role` gönderiyor ama backend `ConversationCreate` schema'sında bu alan yok. Sonuç: `422 Unprocessable Entity`.

**Mevcut hatalı kod (satır ~574-577):**
```dart
final response = await ApiClient.dio.post('/chat/conversations', data: {
  'client_user_id': user['user_id'] ?? user['id'],
  'client_role': role,  // ❌ HATA: Backend buna cevap vermiyor
});
```

**Düzeltme — `client_role` satırını kaldır:**
```dart
final response = await ApiClient.dio.post('/chat/conversations', data: {
  'client_user_id': user['user_id'] ?? user['id'],
});
```

**Doğrulama:**
- Chat Tab → Yeni Sohbet → Kiracı seç → Sohbet oluştur.
- 201 veya 200 dönmeli; 422 hatası alınmamalı.

---

## FAZA 2 — CHAT MEDYA GÖNDERİMİ

---

### Adım 2.1: `chat_window_screen.dart` — Görsel Seçici ve Upload Entegrasyonu

**Dosya:** `frontend/lib/features/agent/screens/chat_window_screen.dart`
**Satır:** ~821-849
**Durum:** `_showAttachmentSheet()` sadece snackbar gösteriyor. Gerçek `image_picker`/`file_picker` implementasyonu eklenecek.

**Mevcut kod (satır ~821-849):**
```dart
// Mevcut placeholder:
onTap: () {
  Navigator.pop(ctx2);
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Fotoğraf seçimi için image_picker gerekli'),
        backgroundColor: AppColors.warning),
  );
},
```

**Yeni eklenmesi gereken import'lar (dosya başına, mevcut import'ların yanına):**
```dart
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
```

**`chat_window_screen.dart` _ChatWindowScreenState sınıfına yeni metodlar ekle:**

```dart
// Satır ~870 civarı, _buildAttachmentTile ve _showAttachmentSheet'in altına ekle:

Future<void> _pickAndSendImage() async {
  final picker = ImagePicker();
  final XFile? image = await picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 1920,
    maxHeight: 1920,
    imageQuality: 85,
  );
  if (image == null) return;

  Navigator.pop(context); // Bottom sheet'i kapat

  // Önce upload et
  final uploadResp = await _uploadMedia(image.path, 'image');
  if (uploadResp != null) {
    // Mesaj olarak gönder
    await _sendMessageWithAttachment(uploadResp);
  }
}

Future<void> _pickAndSendFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf', 'doc', 'docx'],
    allowMultiple: false,
  );
  if (result == null || result.files.isEmpty) return;

  final file = result.files.first;
  if (file.path == null) return;

  Navigator.pop(context); // Bottom sheet'i kapat

  // Önce upload et
  final uploadResp = await _uploadMedia(file.path!, 'document');
  if (uploadResp != null) {
    await _sendMessageWithAttachment(uploadResp);
  }
}

Future<String?> _uploadMedia(String filePath, String category) async {
  try {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
      'category': category,
    });
    final resp = await ApiClient.dio.post(
      '/media/upload',
      data: formData,
      options: Options(
        headers: {'Content-Type': 'multipart/form-data'},
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
      ),
    );
    if (resp.statusCode == 200 && resp.data['url'] != null) {
      return resp.data['url'] as String;
    }
  } catch (e) {
    _showError('Yükleme hatası: $e');
  }
  return null;
}

Future<void> _sendMessageWithAttachment(String url) async {
  final msgData = {
    'type': 'message',
    'conversation_id': widget.conversation.id.toString(),
    'attachment_url': url,
  };
  await ref.read(chatProvider.notifier).sendMessage(
    widget.conversation.id.toString(),
    msgData,
  );
}
```

**Bottom sheet'deki `onTap` handler'larını güncelle:**

`_showAttachmentSheet()` içindeki iki `onTap` callback'ini değiştir:

```dart
Expanded(child: _buildAttachmentTile(
  Icons.image_outlined, 'Fotoğraf',
  'Galeri veya kamera',
  AppColors.success,
  () => _pickAndSendImage(),  // ✅ Güncellendi
)),

Expanded(child: _buildAttachmentTile(
  Icons.picture_as_pdf_outlined, 'Belge',
  'PDF dosyası gönder',
  AppColors.error,
  () => _pickAndSendFile(),  // ✅ Güncellendi
)),
```

**`dio` import'ı eksikse dosya başına ekle:**
```dart
import 'package:dio/dio.dart';
```

**Not:** `image_picker` ve `file_picker` paketleri `pubspec.yaml`'da zaten mevcut (`file_picker: ^8.1.2`). Ek package eklemeye gerek yok.

**Doğrulama:**
- Chat aç → Ek dosya butonu → Galeri'den fotoğraf seç → Yüklenip mesaj olarak gönderilmeli.
- Aynısı PDF dosyası için de test edilmeli.

---

## FAZA 3 — TENANT PANELİ API KÖPRÜSÜ

---

### Adım 3.1: Tenant Finance Tab — Dekont Upload Gerçek Implementasyonu

**Dosya:** `frontend/lib/features/tenant/tabs/tenant_finance_tab.dart`
**Satır:** ~108-138
**Durum:** `_buildUploadReceiptBox()` sadece snackbar gösteriyor. Backend'de `/finance/upload-statement` endpoint'i hazır.

**Eklenecek import'lar (dosya başına):**
```dart
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
```

**`_buildUploadReceiptBox` metodunu değiştir:**
```dart
Widget _buildUploadReceiptBox(BuildContext context) {
  return InkWell(
    onTap: () => _pickAndUploadReceipt(context),
    borderRadius: BorderRadius.circular(24),
    child: Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.accent.withValues(alpha:0.4), width: 1.5),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
            child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 16),
          const Text("Yeni Dekont / Makbuz Yükle", style: TextStyle(color: AppColors.accent, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("EFT/Havale yaptıysanız makbuzu buradan yükleyin. AI sistemimiz onu okuyup Emlakçınıza iletecektir.", textAlign: TextAlign.center, style: TextStyle(color: AppColors.textBody, fontSize: 13, height: 1.4)),
        ],
      ),
    ),
  );
}

Future<void> _pickAndUploadReceipt(BuildContext context) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    allowMultiple: false,
  );
  if (result == null || result.files.isEmpty) return;

  final file = result.files.first;
  if (file.path == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Dosya seçilemedi'),
        backgroundColor: AppColors.error,
      ),
    );
    return;
  }

  // Yükleme göster
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Dekont yükleniyor...'),
      backgroundColor: AppColors.accent,
      duration: Duration(seconds: 1),
    ),
  );

  try {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path!),
    });
    final resp = await ApiClient.dio.post(
      '/finance/upload-statement',
      data: formData,
      options: Options(
        headers: {'Content-Type': 'multipart/form-data'},
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
      ),
    );
    if (resp.statusCode == 200) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Dekont başarıyla yüklendi! Emlakçınız inceleyecek.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Yükleme hatası: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
```

**Doğrulama:**
- Tenant Finance Tab → Dekont yükle kutusuna tıkla → PDF/görsel seç → Backend'e yükle.

---

### Adım 3.2: Tenant Destek Tab — Ticket Açma Formu API Bağlantısı

**Dosya:** `frontend/lib/features/tenant/tabs/tenant_support_tab.dart`

**Mevcut durumu anlamak için dosyayı oku.** Eğer `_buildCreateTicketDialog()` veya benzeri bir fonksiyon placeholder snackbar gösteriyorsa, backend `POST /tenants/tickets/` endpoint'ine bağlanacak şekilde güncellenir.

**Genel patern:**
```dart
Future<void> _submitTicket({
  required String title,
  required String description,
  required BuildContext context,
}) async {
  try {
    final resp = await ApiClient.dio.post('/tenants/tickets', data: {
      'title': title,
      'description': description,
    });
    if (resp.statusCode == 201) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Talebiniz iletildi!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
      );
    }
  }
}
```

**Destek talebi formunda fotoğraf yükleme varsa (PRD §4.2.2):**
- `image_picker` ile kanıt fotoğrafı çek.
- Fotoğrafı `/media/upload` endpoint'ine yükle → URL'i ticket oluştururken `attachments` listesine ekle.

---

### Adım 3.3: Tenant Documents Tab — API Bağlantısı

**Dosya:** `frontend/lib/features/tenant/tabs/tenant_documents_tab.dart`

**Beklenen API:** `GET /tenants/me/documents` → `TenantDocumentsResponse`

**Provider'da (`tenant_provider.dart`) eklenmesi gereken:**
```dart
// tenant_provider.dart ~satır 200+
final tenantDocumentsProvider = FutureProvider.family<TenantDocumentsResponse, void>((
  ref,
  _,
) async {
  final resp = await ApiClient.dio.get('/tenants/me/documents');
  return TenantDocumentsResponse.fromJson(resp.data);
});
```

**Tab'da kullanım:**
```dart
final docsAsync = ref.watch(tenantDocumentsProvider);
docsAsync.when(
  data: (docs) => ListView.builder(
    itemCount: docs.documents.length,
    itemBuilder: (_, i) => _buildDocumentTile(docs.documents[i]),
  ),
  // ...
)
```

---

### Adım 3.4: Tenant Chat Tab — WebSocket Bağlantısı Aktifleştirme

**Dosya:** `frontend/lib/features/tenant/tabs/tenant_chat_tab.dart`

**Mevcut durumu anlamak için dosyayı oku.** Chat widget'ı mevcutsa WebSocket bağlantısı için `ChatProvider`'ın `initWebSocket()` veya `connectWebSocket()` metodunu çağır.

**Beklenen yapı:**
```dart
@override
void initState() {
  super.initState();
  // WebSocket bağlantısı — agent/tabs/chat_tab.dart'daki paterni takip et
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ref.read(chatProvider.notifier).connectWebSocket();
  });
}
```

**WebSocket token'ı için:** `ApiClient.simpleAuthToken` veya Firebase token kullanılır. Backend `chat.py`'de `deps.get_current_user` WebSocket auth için `Authorization` header'ını okur.

---

## FAZA 4 — BİNA OPERASYONLARI KISAYOLU

---

### Adım 4.1: Ticket Detail Sheet — Bina Operasyonu Gerçek API Bağlantısı

**Dosya:** `frontend/lib/features/agent/widgets/ticket_detail_sheet.dart`
**Satır:** ~109-122
**Durum:** `_addToBuildingOps()` sadece snackbar gösteriyor. `POST /building-logs/` backend'e gerçek istek atılacak.

**Mevcut hatalı kod:**
```dart
void _addToBuildingOps() {
  Navigator.pop(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Bina Operasyonlarına eklendi: ${widget.ticket.title}'),
      // ...
    ),
  );
}
```

**Değiştirilecek kod:**
```dart
Future<void> _addToBuildingOps() async {
  Navigator.pop(context);

  final propertyId = widget.ticket.propertyId;
  if (propertyId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bu talebe mülk bilgisi bağlı değil'),
        backgroundColor: AppColors.error,
      ),
    );
    return;
  }

  try {
    final resp = await ApiClient.dio.post('/building-logs/', data: {
      'property_id': propertyId.toString(),
      'title': '[Destek Ticket] ${widget.ticket.title}',
      'description': widget.ticket.description,
      'operation_date': DateTime.now().toIso8601String().split('T')[0],
      'add_to_financial_expense': false,
    });

    if (resp.statusCode == 201) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bina Operasyonlarına eklendi: ${widget.ticket.title}'),
            backgroundColor: AppColors.success,
            action: SnackBarAction(
              label: 'Mali Rapor',
              textColor: Colors.white,
              onPressed: () {
                // TODO: Mali Rapor ekranına yönlendir
                // Navigator.push(context, MaterialPageRoute(builder: (_) => MaliRaporScreen()));
              },
            ),
          ),
        );
      }
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
```

**Backend'de `building-logs` endpoint'ini kontrol et** (`backend/app/api/endpoints/operations.py`):
`POST /building-logs/` mevcut değilse `operations.py`'de oluştur:
```python
@router.post("/building-logs/", response_model=BuildingOperationLogResponse, status_code=201)
async def create_building_log(
    data: BuildingOperationLogCreate,
    current_user: User = Depends(deps.get_current_user),
    agency_id: uuid.UUID = Depends(deps.get_current_user_agency_id),
    db: AsyncSession = Depends(deps.get_db),
):
    """Yeni bina operasyonu oluşturur."""
    log = BuildingOperationLog(
        agency_id=agency_id,
        property_id=data.property_id,
        title=data.title,
        description=data.description,
        operation_date=data.operation_date,
        invoice_url=data.invoice_url,
    )
    db.add(log)
    await db.commit()
    await db.refresh(log)
    return log
```

**Ayrıca schema eksikse (`schemas/operations.py`):**
```python
class BuildingOperationLogCreate(BaseModel):
    property_id: UUID
    title: str
    description: Optional[str] = None
    operation_date: date
    invoice_url: Optional[str] = None
    add_to_financial_expense: bool = False
```

---

## FAZA 5 — FİNANS KATEGORİ YÖNETİMİ

---

### Adım 5.1: Backend — `custom_category` Kolonu ve Schema Güncellemesi

**Dosya:** `backend/app/models/finance.py`
**Eklenecek kolon:** `FinancialTransaction` tablosuna `custom_category` String kolonu.

**`FinancialTransaction` sınıfına ekle (satır ~43, `description` kolonunun altına):**
```python
custom_category = Column(String, nullable=True)  # Kullanıcı özel kategori adı
```

**Migrasyon oluştur:**
```bash
cd backend
alembic revision --autogenerate -m "add custom_category to financial_transactions"
alembic upgrade head
```

**Dosya:** `backend/app/schemas/finance.py`
**`ManualTransactionCreate` schema'sına ekle:**
```python
class ManualTransactionCreate(BaseModel):
    # ... mevcut alanlar ...
    custom_category: Optional[str] = None  # ✅ Eklenecek
```

**`TransactionResponse` schema'sına ekle:**
```python
class TransactionResponse(BaseModel):
    # ... mevcut alanlar ...
    custom_category: Optional[str] = None  # ✅ Eklenecek
```

---

### Adım 5.2: Frontend — Mali Rapor "Yeni Kategori Oluştur" UI

**Dosya:** `frontend/lib/features/agent/screens/mali_rapor_screen.dart`

**Mali rapor "Yeni İşlem Ekle" formunda kategori seçimi varsa, "Yeni Kategori Oluştur" seçeneği ekle:**

```dart
// Form'daki kategori Dropdown'ı:
// Mevcut yapı: DropdownButtonFormField<CategoryEnum>
// Ek kısım olarak:

// "Özel Kategori" Switch veya "Yeni Oluştur" TextField
Row(
  children: [
    Expanded(
      child: DropdownButtonFormField<CategoryEnum>(
        value: _selectedCategory,
        decoration: InputDecoration(labelText: 'Kategori'),
        items: CategoryEnum.values.map((c) {
          return DropdownMenuItem(
            value: c,
            child: Text(c.name),
          );
        }).toList(),
        onChanged: (v) => setState(() => _selectedCategory = v),
      ),
    ),
    IconButton(
      icon: const Icon(Icons.add_circle_outline, color: AppColors.accent),
      onPressed: () => _showCreateCategoryDialog(),
      tooltip: 'Yeni Kategori Oluştur',
    ),
  ],
)
```

**`_showCreateCategoryDialog()`:**
```dart
void _showCreateCategoryDialog() {
  final controller = TextEditingController();
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Yeni Kategori', style: TextStyle(color: Colors.white)),
      content: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'Kategori adı',
          hintStyle: TextStyle(color: AppColors.textBody),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: () {
            if (controller.text.trim().isNotEmpty) {
              setState(() {
                _customCategoryName = controller.text.trim();
                _selectedCategory = CategoryEnum.other; // Özel = other'e düşer
              });
              Navigator.pop(ctx);
            }
          },
          child: const Text('Oluştur'),
        ),
      ],
    ),
  );
}
```

**Form gönderildiğinde `custom_category` alanını ekle:**
```dart
// Form submit'te:
data: {
  'type': _isIncome ? 'income' : 'expense',
  'category': _selectedCategory.name,
  'custom_category': _customCategoryName, // ✅ Eklenecek
  'amount': _amount,
  // ...
}
```

---

## FAZA 6 — OTP RATE LIMITING (SMS PUMPING KORUMASI)

---

### Adım 6.1: Backend — Şifre Sıfırlama Rate Limit Table ve Endpoint

**Dosya:** `backend/app/models/users.py`
**Eklenecek:** `PasswordResetAttempt` modeli (aylık limit takibi için).

**`users.py`'e ekle:**
```python
class PasswordResetAttempt(BaseModel):
    """OTP şifre sıfırlama talebi takibi — SMS Pumping koruması"""
    __tablename__ = "password_reset_attempts"

    phone_number = Column(String, nullable=False, index=True)
    attempted_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    ip_address = Column(String, nullable=True)
```

**Migrasyon:**
```bash
alembic revision --autogenerate -m "add password_reset_attempts table"
alembic upgrade head
```

---

### Adım 6.2: Backend — Rate Limit Logic ve Endpoint Güncellemesi

**Dosya:** `backend/app/api/endpoints/auth.py`

**Mevcut `create_invite` veya yeni bir endpoint olarak ekle.** PRD §4.1.4-D kapsamında `/auth/request-password-reset-otp` endpoint'i:

```python
from datetime import datetime, timedelta
from app.models.users import PasswordResetAttempt

MONTHLY_LIMIT = 15  # PRD §4.1.4-D: ayda 15 kez

@router.post("/request-password-reset-otp")
async def request_password_reset_otp(
    phone_number: str,  # form_field
    current_user: User = Depends(deps.get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Şifre sıfırlama OTP'si talep eder.
    PRD §4.1.4-D: Aylık 15 limit kontrolü.
    """
    # 1) Limit kontrolü — bu ay içinde kaç talep var?
    first_of_month = datetime.utcnow().replace(day=1, hour=0, minute=0, second=0)
    stmt = select(func.count(PasswordResetAttempt.id)).where(
        PasswordResetAttempt.phone_number == phone_number,
        PasswordResetAttempt.attempted_at >= first_of_month,
    )
    result = await db.execute(stmt)
    count = result.scalar() or 0

    if count >= MONTHLY_LIMIT:
        raise HTTPException(
            status_code=429,
            detail=(
                "Bu ay için şifre sıfırlama limitine ulaşıldı (15/ay). "
                "Lütfen emlakçınızla iletişime geçin."
            ),
        )

    # 2) Meşru talep — Firebase verifyPhoneNumber tetikle
    # (Firebase Admin SDK ile)
    # Firebase otomatik olarak rate limiting yapar (Play Integrity, reCAPTCHA)
    # Bu aşamada sadece kaydı tut
    attempt = PasswordResetAttempt(
        phone_number=phone_number,
        attempted_at=datetime.utcnow(),
    )
    db.add(attempt)
    await db.commit()

    # 3) Firebase OTP gönder (mevcut Firebase Admin SDK flow'u)
    # Firebase verifyPhoneNumber otomatik olarak çalışır
    return {"message": "Doğrulama kodu gönderildi."}
```

**Not:** `func` import'unu dosya başına ekle:
```python
from sqlalchemy import func
```

**Doğrulama:**
```bash
# 15'ten fazla istek at — 16. istek 429 dönmeli
curl -X POST http://localhost:8000/api/v1/auth/request-password-reset-otp \
  -H "Content-Type: application/json" \
  -d '{"phone_number": "+905551112233"}'
```

---

## FAZA 7 — OFFLINE OKUMA ÖNBELLEKLEME

---

### Adım 7.1: Offline Cache — Portföy ve Kiracı Verisi

**Dosya:** `frontend/lib/core/offline/offline_cache_provider.dart`

**Mevcut yapı:** `OfflineStorage` sınıfı mevcut. `ConnectivityService` ve `SyncService` mevcut.

**Eklenecek:** API yanıtlarını başarılı fetch sonrası Hive'a yazma ve bağlantısız okuma.

**`properties_provider.dart`'a offline okuma/yazma ekle:**

```dart
// PropertiesProvider — fetch sonrası cache'e yaz:
Future<void> fetchProperties() async {
  try {
    final resp = await ApiClient.dio.get('/properties');
    final properties = (resp.data as List)
        .map((p) => PropertySummary.fromJson(p))
        .toList();

    // ✅ Offline cache'e yaz
    await OfflineStorage.instance.write(
      'cached_properties',
      resp.data,
    );

    state = AsyncValue.data(properties);
  } on DioException catch (e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      // ✅ Bağlantı yok — cache'den oku
      final cached = await OfflineStorage.instance.read('cached_properties');
      if (cached != null) {
        final properties = (cached as List)
            .map((p) => PropertySummary.fromJson(p as Map<String, dynamic>))
            .toList();
        state = AsyncValue.data(properties);
        return;
      }
    }
    state = AsyncValue.error(e, StackTrace.current);
  }
}
```

**`OfflineStorage.instance` metodları** (`offline_storage.dart` içinde):
```dart
Future<void> write(String key, dynamic data) async {
  final box = await Hive.openBox('offline_cache');
  await box.put(key, jsonEncode(data));
}

Future<dynamic> read(String key) async {
  final box = await Hive.openBox('offline_cache');
  final raw = box.get(key);
  if (raw == null) return null;
  return jsonDecode(raw as String);
}
```

**`SyncService`** (`sync_service.dart`) — bağlantı geldiğinde cache'i invalidate et:
```dart
ConnectivityService.instance.addListener(() async {
  if (ConnectivityService.instance.isConnected) {
    // Arka planda yenile
    ref.read(propertiesProvider.notifier).fetchProperties();
  }
});
```

---

## ADIMLARIN ÖNCELİK SIRALAMASI (Hızlı Referans)

```
1. FAZA 1 — Kritik Bug'lar
   1.1 landlord.py User.agency_id düzelt          [ ~10 dakika ]
   1.2 chat client_role schema uyumsuzluğu      [ ~5 dakika ]

2. FAZA 2 — Chat Medya Gönderimi
   2.1 chat_window_screen medya upload          [ ~20 dakika ]

3. FAZA 3 — Tenant Panel API Bağlantısı
   3.1 tenant_finance_tab receipt upload         [ ~15 dakika ]
   3.2 tenant_support_tab ticket oluşturma       [ ~15 dakika ]
   3.3 tenant_documents_tab API bağlantısı       [ ~10 dakika ]
   3.4 tenant_chat_tab WebSocket                 [ ~10 dakika ]

4. FAZA 4 — Bina Operasyonları Kısayolu
   4.1 ticket_detail_sheet bina ops API          [ ~15 dakika ]

5. FAZA 5 — Finans Kategori Yönetimi
   5.1 backend custom_category kolonu            [ ~10 dakika + migration ]
   5.2 frontend mali rapor özel kategori UI     [ ~20 dakika ]

6. FAZA 6 — OTP Rate Limiting
   6.1 backend PasswordResetAttempt model        [ ~10 dakika + migration ]
   6.2 endpoint rate limit logic                 [ ~10 dakika ]

7. FAZA 7 — Offline Okuma Cache
   7.1 properties_provider offline yazma/okuma    [ ~20 dakika ]
   7.2 SyncService cache invalidation            [ ~10 dakika ]
```

**Toplam tahmini süre:** ~2.5 saat

---

## TEST KOORDİNATÖRÜ

Her FAZA tamamlandığında şu testler yapılmalı:

| FAZA | Test |
|---|---|
| 1.1 | `POST /landlord/conversations` → 200 dönmeli, 500 HATA OLMAMALI |
| 1.2 | Chat → Yeni Sohbet → Kiracı → Sohbet açılmalı, 422 HATA OLMAMALI |
| 2.1 | Chat → Ek dosya → Fotoğraf seç → Yükle → Mesajda görünmeli |
| 3.1 | Tenant Finance → Dekont yükle → PDF seç → Backend'e ulaşmalı |
| 3.2 | Tenant Support → Yeni talep aç → Backend'e ulaşmalı |
| 4.1 | Ticket → "Bina Operasyonu" → Kayıt oluşmalı |
| 5.1 | Migration çalışmalı, kolon DB'de görünmeli |
| 5.2 | Mali Rapor → Yeni İşlem → Özel kategori yazılabilmeli |
| 6.1 | Migration çalışmalı, tablo DB'de görünmeli |
| 6.2 | 16. OTP talebi → 429 dönmeli |
| 7.1 | Bağlantı kes → API hata → Cache'den okuma yapılmalı |

---

*Bu dosya `development_report.md` uyarınca hazırlanmıştır. Her FAZA sırayla uygulanmalıdır.*
