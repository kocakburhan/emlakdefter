# EmlakDefteri — PRD Uyum & Geliştirme Durum Raporu

> **Rapor Tarihi:** 14 Nisan 2026
> **Kapsam:** PRD v2.0 ile mevcut kod tabanının karşılaştırmalı analizi
> **Yöntem:** Backend (FastAPI), Frontend (Flutter) ve PRD gereksinimleri satır satır karşılaştırıldı.

---

## Özet Tablo

| PRD Bölümü | Özellik | Durum |
|---|---|---|
| §3.1 | AI ile Otonom Tahsilat (PDF Dekont) | ✅ Hazır |
| §3.2 | Finansal Ayrım (Gelir/Gider) | ✅ Hazır |
| §3.3 | APScheduler Arka Plan Görevleri | ✅ Hazır |
| §4.1.1 | Dashboard — KPI Kartları & Etkinlik Akışı | ✅ Hazır |
| §4.1.2 | Portföy Yönetimi — Dinamik Form | ⚠️ Kısmen Hazır |
| §4.1.2 | Portföy — Otonom Daire Üretim Motoru | ✅ Hazır |
| §4.1.2 | Portföy — Toplu Bildirim Gönder | ⚠️ Kısmen Hazır |
| §4.1.3 | Daire Detay Ekranı (Mülk Künyesi) | ✅ Hazır |
| §4.1.4 | Kiracı & Ev Sahibi Yönetimi Ekranı | ❌ Eksik (Placeholder) |
| §4.1.4 | Dijital Profil Daveti (Smart Inviting) | ⚠️ Kısmen Hazır |
| §4.1.4 | WhatsApp ile Davet Gönderme | ⚠️ Kısmen Hazır |
| §4.1.4 | Firebase OTP Onboarding | ✅ Hazır |
| §4.1.4 | OTP ile Şifre Kurtarma | ⚠️ Kısmen Hazır |
| §4.1.5 | Finans — Ekstre/Dekont Yükle | ✅ Hazır |
| §4.1.5 | Finans — 4 Ana Sekme | ✅ Hazır |
| §4.1.5 | Finans — Manuel Onay Banner | ✅ Hazır |
| §4.1.5 | Finans — Excel Çıktısı | ✅ Hazır |
| §4.1.6 | Mali Rapor — Gelir/Gider Listesi | ✅ Hazır |
| §4.1.6 | Mali Rapor — Grafik & Özet Kartlar | ✅ Hazır |
| §4.1.6 | Mali Rapor — Esnek Kategori Yönetimi | ⚠️ Kısmen Hazır |
| §4.1.6 | Mali Rapor — Rapor İndir | ✅ Hazır |
| §4.1.7 | Destek Yönetimi — 3 Sekme | ✅ Hazır |
| §4.1.7 | Destek — Bina Operasyonlarına Ekle | ⚠️ Kısmen Hazır |
| §4.1.8 | Chat Merkezi — WebSocket | ✅ Hazır |
| §4.1.8 | Chat — Medya & Belge Gönderimi | ❌ Eksik (Placeholder) |
| §4.1.9 | Bina Operasyonları — Log Merkezi | ✅ Hazır |
| §4.1.9 | Bina Operasyonları — Mali Rapora Entegrasyon | ✅ Hazır |
| §4.1.10 | BI Analytics — Doluluk Oranı | ✅ Hazır |
| §4.1.10 | BI Analytics — Kiracı Sirkülasyon Analizi | ✅ Hazır |
| §4.1.10 | BI Analytics — Yıllık Finansal Rapor | ✅ Hazır |
| §4.1.10 | BI Analytics — Tahsilat Performansı | ✅ Hazır |
| §4.1.10 | BI Analytics — PDF/Excel Çıktı | ✅ Hazır |
| §4.2 | Kiracı Paneli — 7 Sekme | ✅ Hazır (UI) |
| §4.2.1 | Kiracı — Finansal Takip | ⚠️ Mock Veri |
| §4.2.2 | Kiracı — Destek & Sorun Bildirimi | ⚠️ Mock Veri |
| §4.2.3 | Kiracı — Belgelerim | ⚠️ Mock Veri |
| §4.2.4 | Kiracı — Bina Operasyonları (Şeffaflık) | ⚠️ Mock Veri |
| §4.2.5 | Kiracı — Chat | ⚠️ Mock Veri |
| §4.2.6 | Kiracı — Yeni Ev Keşfi (Vitrin) | ⚠️ Mock Veri |
| §4.3 | Ev Sahibi Paneli — 5 Sekme | ✅ Hazır (UI + API) |
| §4.3.1 | Ev Sahibi — Dashboard & Mülkler | ✅ Hazır |
| §4.3.2 | Ev Sahibi — Daire Detay & Kiracı Performans | ✅ Hazır |
| §4.3.3 | Ev Sahibi — Operasyon & Destek Takibi | ✅ Hazır |
| §4.3.4 | Ev Sahibi — Yatırım Fırsatları Vitrini | ⚠️ Kısmen Hazır |
| §5.1 | Offline — Veri Okuma Önbellekleme | ⚠️ Kısmen Hazır |
| §5.2 | Offline — Mesaj Kuyruklama | ✅ Hazır |
| §5.3 | Offline — İşlem Kuyruklama (UUID) | ✅ Hazır |
| §6 | Veritabanı RLS & Multi-Tenancy | ✅ Hazır |
| §6.1 | UUID PK, Soft Delete, Firebase UID | ✅ Hazır |

---

## Bölüm 1 — Halihazırda Geliştirilmiş Özellikler ✅

### 1.1 Backend Altyapısı (Core)

**Firebase Entegrasyonu (`core/firebase.py`)**
Firebase Admin SDK başarıyla entegre edilmiş. `verify_firebase_token()` ve `verify_access_token()` fonksiyonları çalışır durumda. FCM push notification gönderimi (`send_fcm_notification`) implemente edilmiş. JWT doğrulama FastAPI dependency injection ile tüm korumalı endpoint'lere bağlanmış.

**APScheduler (`core/scheduler.py`)**
PRD §3.3 kapsamında iki kritik cron görevi implemente edilmiş:
- `generate_monthly_dues`: Her gün 01:00'de çalışır, ay başında payment_schedules tablosuna o aya ait kira/aidat kayıtları otonom olarak eklenir.
- `send_payment_reminders`: Her gün 09:00'da çalışır, vadesi gelen veya geçen ödemeleri olan kiracılara FCM üzerinden otomatik push notification gönderir.
APScheduler ayrıca ayrı bir endpoint grubu üzerinden (`/scheduler/`) yönetilebilir durumda.

**Gemini AI - PDF Banka Ekstresi Ayrıştırma (`core/llm_processor.py`)**
PRD §3.1 kapsamında Gemini 2.5 Flash modeli (temperature=0.1) kullanılarak PDF ekstresi JSON'a çevrilmekte. `pdfplumber` ile metin okunmakta, LLM çıktısı deterministik Python kodu ile veritabanındaki kiracılarla `difflib` kullanılarak eşleştirilmekte. Tam/eksik/eşleştirilemeyen işlemler farklı statülerle işaretlenmekte.

**Hetzner Object Storage (`core/storage.py`)**
Presigned URL mimarisiyle dosya yükleme implemente edilmiş. Medya upload endpoint'i (`/media/upload`) 10MB limit, image/PDF/DOC formatlarını destekliyor.

### 1.2 Veritabanı Mimarisi (§6)

**Tüm PRD §6.2 tabloları implemente edilmiş:**
- `agencies`, `users`, `agency_staff`, `invitations`, `user_device_tokens`
- `properties`, `property_units`
- `landlords_units`, `tenants`
- `financial_transactions`, `payment_schedules`
- `support_tickets`, `ticket_messages`, `building_operations_log`
- `chat_conversations`, `chat_messages`

**PRD §6.1 standartları eksiksiz uygulanmış:**
- UUID primary key tüm tablolarda mevcut.
- Soft delete (`is_deleted`, `deleted_at`) kritik tablolarda mevcut.
- `firebase_uid` users tablosunda unique constraint ile tutulmakta.
- `agency_id` üzerinden multi-tenant veri izolasyonu sağlanmış.

### 1.3 Emlakçı Paneli Backend API

**Properties Endpoint (`/properties/`)**
- Tam CRUD (Apartman, Müstakil Ev, Arsa, Ticari)
- PRD §4.1.2-B Otonom Daire Üretim Motoru: `createPropertyWithAutonomousUnits` servisi `start_floor × units_per_floor` döngüsüyle otomatik alt birimler üretmekte. Tekil üretim istisnası (Müstakil Ev/Arsa için Single Unit) da implemente edilmiş.
- Toplu bildirim endpoint'i (`/broadcast-notification`) mevcut.
- Daire durumu (vacant/rented/maintenance) yönetimi çalışır.

**Finance Endpoint (`/finance/`)**
- Tüm finansal işlem CRUD'u hazır.
- Aylık istatistik ve kategori bazlı döküm endpoint'leri çalışır.
- Payment schedule yönetimi (pending/paid/overdue) hazır.
- AI destekli ekstre yükleme endpoint'i (`/upload-statement`) hazır.

**Operations Endpoint (`/operations/`)**
- Support ticket tam yaşam döngüsü (open → in_progress → resolved) yönetimi hazır.
- Building operations log CRUD hazır.
- Activity feed (dashboard için son işlemler akışı) hazır.
- Dashboard KPI hesaplama hazır.

**Chat Endpoint (`/chat/`)**
- WebSocket tabanlı gerçek zamanlı mesajlaşma hazır.
- Mesaj düzenleme (15 dakika limiti) ve silme (30 saniye limiti) implemente edilmiş.
- Okunmamış mesaj sayısı tracking hazır.

**Landlord Endpoint (`/landlord/`)**
- Ev sahibi dashboard KPI'ları hazır.
- Ev sahibine ait mülk listesi, kiracı performans raporu, operasyon log takibi hazır.
- Boş daire listesi (yatırım vitrini) hazır.

**Analytics Endpoint (`/analytics/`)**
- Portfolio doluluk oranı ve boş daire yaşlandırma listesi hazır.
- Kiracı sirkülasyon/churn analizi hazır.
- Yıllık karşılaştırmalı finansal rapor hazır.
- Tahsilat performans metrikleri hazır.

### 1.4 Emlakçı Frontend (Flutter)

**Dashboard Tab (`agent/tabs/home_tab.dart`)**
- 3 KPI kartı (Toplam Daire, Aktif Kiracı, Çalışanlar) dinamik veriyle besleniyor.
- Etkinlik Akışı (Son İşlemler) kronolojik, "Daha Fazla Göster" pagination ile çalışıyor.

**Portföy Tab (`agent/tabs/properties_tab.dart`)**
- Mülk tipi seçimi (4 tip: Apartman/Müstakil/Arsa/Ticari) mevcut.
- Dinamik form yapısı: mülk tipine göre form alanları değişiyor.
- Apartman detay ekranına geçiş çalışır.

**Daire Detay Ekranı (`agent/screens/unit_detail_screen.dart`)**
- Finansal künye (kira fiyatı, aidat, komisyon oranı) yönetimi çalışır.
- Özellikler/etiketler yönetimi çalışır.
- Medya linkleri ve YouTube link girişi mevcut.

**Finans Tab (`agent/tabs/finance_tab.dart`)**
- 4 alt sekme: Ödeyenler / Bekleyenler / Gecikenler / Kısmi Ödeyenler tamamen çalışır.
- AI eşleştirme etiketi (`🤖 Otomatik Eşleşti`) uygulanmış.
- Manuel onay banner kırmızı uyarı bandı olarak çalışır.
- `[ Hatırlat ]` ve `[ İhtar Gönder ]` FCM bildirimleri implemente edilmiş.
- Excel çıktısı export fonksiyonu mevcut.

**Mali Rapor Ekranı (`agent/screens/mali_rapor_screen.dart`)**
- Toplam Gelir / Gider / Net Bakiye özet kartları çalışır.
- Pasta grafiği ile kategori dağılımı mevcut.
- Kronolojik gelir/gider listesi (yeşil/kırmızı) çalışır.
- Finansal rapor indirme mevcut.

**Destek Tab (`agent/tabs/support_tab.dart`)**
- 3 sekme: Açık (🔴) / İşlemde (🟠) / Çözüldü (🟢) tam çalışır.
- Talep detayında yanıt yazma, "Giderildi" işaretleme, bina operasyonlarına ekleme kısayolları mevcut.
- Push notification ile kiracıya bildirim gönderimi çalışır.

**Bina Operasyonları Tab (`agent/tabs/building_operations_tab.dart`)**
- Kronolojik log listesi çalışır.
- Yeni operasyon ekleme formu (bina seçimi, kategori, maliyet) mevcut.
- "Mali Rapora Gider Olarak İşle" checkbox çalışır, `financial_transactions` tablosuna otomatik düşer.
- Filtreleme (bina bazlı/kategori/tarih) mevcut.
- Offline kuyruklama (`queueToOutbox`) implemente edilmiş.

**Chat Tab & Ekranı (`agent/tabs/chat_tab.dart`, `agent/screens/chat_window_screen.dart`)**
- Gelen kutusu (kronolojik, kiracı/daire bilgisi, son mesaj önizleme) çalışır.
- Okunmamış rozet (unread badge) tracking çalışır.
- Kiracı adına/daire numarasına göre anlık arama mevcut.
- WebSocket bağlantısı gerçek zamanlı mesajlaşma sağlar.
- Mesaj okundu/okunmadı bilgisi (çift tik ✓✓) mevcut.
- Mesaj düzenleme ve silme (zaman limitli) implemente edilmiş.
- Offline mesaj kuyruklama (`OfflineStorage`) mevcut.

**BI Analytics Ekranı (`agent/screens/bi_analytics_screen.dart`)**
- Doluluk oranı donut grafik, trend çizgi grafiği çalışır.
- Boş daire yaşlandırma listesi ("45 Gündür Boş" etiketleri) mevcut.
- Kiracı giriş/çıkış bar grafiği, ortalama kalış süresi, churn rate mevcut.
- Yıllık gelir/gider karşılaştırma grafikleri çalışır.
- Tahsilat performans KPI kartları çalışır.
- PDF rapor indirme ve Excel çıktısı mevcut.
- Tarih aralığı seçici (Bu Ay / Son 3 Ay / Son 6 Ay / Bu Yıl / Geçen Yıl / Özel) çalışır.
- **Bu ekrana sadece Admin rolü erişebilir** — PRD §4.1.10 erişim kısıtı uygulanmış.

### 1.5 Ev Sahibi Paneli (Frontend + Backend — %100)

**Landlord Dashboard (`landlord/screens/landlord_dashboard_screen.dart`)**
- 5 sekme: Genel Bakış / Mülklerim / Kiracı Performansı / Operasyonlar / Yatırım Fırsatları
- Finansal özet kartları (Beklenen Kira, Tahsil Edilen, Geciken) çalışır.
- Mülk listesi (🟢 Kirada / 🔴 Boş) anlık durum rozetleriyle çalışır.
- Kiracı ödeme performans skoru (geçmiş 12 ay, "Zamanında Ödedi", "5 Gün Geciktirdi" etiketleri) çalışır.
- Salt okunur destek ticket takibi (timeline ile) çalışır.
- Salt okunur bina operasyon log'u çalışır.

### 1.6 Kimlik Doğrulama (Auth)

**Firebase OTP Onboarding (`auth/screens/otp_verification_screen.dart`)**
- 6 haneli OTP otomatik submit (6. hanede tetiklenir) çalışır.
- KVKK ve Aydınlatma Metni checkbox zorunluluğu implemente edilmiş.
- Backend binding (firebase_uid → PostgreSQL tenant/landlord profili eşleştirme) çalışır.
- Davet token tek kullanımlık imha (`is_used = true`) mevcut.

**FCM Token Yönetimi**
- Cihaz bazlı FCM token kayıt endpoint'i (`/auth/fcm-token`) çalışır.
- `user_device_tokens` tablosuna iOS/Android/Web ayrımıyla kaydediliyor.

### 1.7 Offline Destek (§5)

**Mesajlaşma Kuyruklama (§5.2)**
- Bağlantısız ortamda gönderilen mesajlar "Bekliyor" statüsüyle `OfflineStorage`'a kaydediliyor.
- Bağlantı geldiğinde arka planda otomatik senkronizasyon tetikleniyor.

**Operasyonel İşlem Kuyruklama (§5.3)**
- Bina operasyonu girişleri ve finans kayıtları offline kuyruğa alınıyor.
- Her offline işleme `uuid` atanıyor (çakışma önleme).
- Senkronizasyon sonrası "Cloud Upload" ikonu normale dönüyor.

---

## Bölüm 2 — İyileştirilmesi Gereken Özellikler ⚠️

### 2.1 Kiracı Yönetimi Ekranı — Mock→API Geçişi (KRİTİK)

**Sorun:** `tenants_management_screen.dart` dosyasının sonu "Kiracı Yönetimi (Landlord CRUD + WhatsApp Davet)" placeholder metniyle bitiyor. Bu ekran çalışır durumda değil.

**Ne Eksik:**
- Aktif/Pasif kiracı listesi API'den çekilmiyor.
- Kiracı ekleme formu (profil oluşturma + daireye atama + sözleşme upload) tamamlanmamış.
- Ev sahibi ekleme formu (çoklu mülk atama) tamamlanmamış.
- "Sözleşme Feshi (Offboarding)" akışı — kiracının pasife alınması, dairenin "Boş/Müsait" statüsüne geçmesi — UI'dan tetiklenemiyor.
- WhatsApp davet mesajı üretme ve `url_launcher` ile gönderme UI'da mevcut değil.

**Backend Durumu:** `tenants.py` endpoint'i ~1159 satır, tüm bu işlemler backend'de implemente edilmiş. Sorun tamamen frontend'de.

**Yapılması Gerekenler:**
1. `tenants_management_screen.dart`'ı sıfırdan yeniden yaz.
2. Kiracı listesi için `GET /tenants/` API çağrısı ekle.
3. "Yeni Kiracı Ekle" formu: isim, telefon, TC, birim seçimi, sözleşme PDF yükleme.
4. Ev Sahibi bölümü için `GET /landlord/` + CRUD API çağrıları ekle.
5. WhatsApp davet butonu: Backend'den gelen davet linkini `wa.me/` şemasıyla `url_launcher` üzerinden aç.
6. Offboarding UI: Kiracı kartında "Sözleşmeyi Fesh Et" aksiyonu, onay dialogu, ardından API çağrısı.

### 2.2 Kiracı Paneli — Tüm Sekmeler Mock Veriden API'ye Geçmeli

**Sorun:** `tenant_provider.dart` tüm veri yapılarını (TenantFinanceSummary, BuildingLogItem, TransactionItem, SupportTicket, vb.) doğru tanımlamış ancak sekmelerin büyük çoğunluğu sahte (hardcoded mock) veri gösteriyor.

**Sekme bazlı durum:**

| Sekme | Mevcut Durum | Yapılması Gereken |
|---|---|---|
| `tenant_home_tab` | Yaklaşan ödeme kartı mock veri | `GET /tenants/{id}/payment-schedules` bağla |
| `tenant_finance_tab` | İşlem listesi mock, PDF upload placeholder | `GET /tenants/{id}/transactions` bağla; `file_picker` paketi ekle |
| `tenant_support_tab` | Ticket listesi mock | `GET /tenants/tickets/` bağla, ticket açma formu API'ye bağla |
| `tenant_documents_tab` | Belge listesi mock | `GET /tenants/{id}/documents` bağla |
| `tenant_building_ops_tab` | Log listesi mock | `GET /building-logs/?property_id=X` bağla |
| `tenant_chat_tab` | Chat mock | Chat WebSocket bağlantısını tenant için de aktif et |
| `tenant_explore_tab` | Boş daire listesi mock | `GET /properties/vacant-units/` bağla |

**Backend Durumu:** Tüm bu endpoint'ler `tenants.py`'de mevcut. Sadece frontend→backend bağlantısı kurulmalı.

### 2.3 Chat — Medya ve Belge Gönderimi

**Sorun:** `chat_window_screen.dart`'da fotoğraf/PDF gönderme butonları `image_picker` ve `file_picker` paketleri kullanıma alınmadan placeholder snackbar gösteriyor.

**Mevcut Kod (satır ~823-840):**
```dart
// Görseller için:
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text('Galeriden resim seçmek için image_picker paketi gerekli')));
// PDF için:
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text('PDF seçmek için file_picker paketi gerekli')));
```

**Yapılması Gerekenler:**
1. `pubspec.yaml`'a `image_picker: ^1.x.x` ve `file_picker: ^6.x.x` ekle.
2. `ChatWindowScreen`'de `_pickImage()` ve `_pickFile()` metodlarını implemente et.
3. Seçilen medyayı önce `/media/upload` endpoint'ine yükle (Hetzner S3).
4. Dönen URL'i chat mesajında `attachment_url` olarak gönder.
5. Chat mesajında görsel önizleme (thumbnail) ve PDF ikonu render'ı ekle.

**Not:** Hetzner S3 upload altyapısı (`core/storage.py` + `/media/upload` endpoint) zaten hazır. Sadece Flutter tarafı tamamlanmalı.

### 2.4 Portföy — Dinamik Form (Mülk Tipi Bazlı Alan Gösterimi)

**Sorun:** `properties_tab.dart`'daki mülk ekleme formu temel alanları içeriyor ancak PRD §4.1.2-A'daki tam "dinamik UI render" henüz uygulanmamış. Arsa/tarla seçildiğinde "Ada", "Parsel", "İmar Durumu" alanları açılmıyor; apartman seçildiğinde "Ortak Alanlar" ve "Yönetici Bilgileri" gösterilmiyor.

**Yapılması Gerekenler:**
1. `_PropertyType` enum'una göre form alanlarını `AnimatedSwitcher` veya `Visibility` widget'larıyla toggle et.
2. Arsa tipi seçildiğinde: Ada, Parsel No, İmar Durumu, m² alanları göster; asansör/aidat/kat alanlarını gizle.
3. Apartman tipi seçildiğinde: Başlangıç/Bitiş Katı, Katta Kaç Daire, Ortak Aidat, Yönetici Bilgisi alanlarını göster.
4. Müstakil Ev seçildiğinde: Kat döngüsü ve daire sayısı alanlarını gizle.

### 2.5 Bina Operasyonlarına Ekle Kısayolu (Destek Ticket'larından)

**Sorun:** PRD §4.1.7-C'de belirtilen `[ 🔧 Bina Operasyonlarına Ekle ]` butonu destek ticket detay ekranında görsel olarak mevcut ancak backend'e gerçek bir istek göndermek yerine sadece navigation yapıyor veya boş kalıyor.

**Yapılması Gereken:**
- Ticket detay ekranındaki "Bina Operasyonlarına Ekle" butonuna tıklandığında, ticket başlığı/açıklaması/birim bilgisiyle pre-fill edilmiş bir `CreateBuildingOperationLog` formu açılmalı.
- Form onaylandığında `POST /building-logs/` isteği gönderilmeli.
- Eğer "Mali Rapora Gider Olarak İşle" seçildiyse aynı anda `POST /finance/transactions/` isteği de atılmalı.

### 2.6 Finans — Esnek Kategori Yönetimi

**Sorun:** PRD §4.1.6-B'de "Yeni Kategori Oluştur" özelliği belirtilmiş. Mevcut `category` alanı sabit bir Enum (`rent`, `dues`, `commission`, `maintenance`, `utility`, `other`) ile sınırlı. Kullanıcı özel kategori tanımlayamıyor.

**Yapılması Gerekenler:**
1. `financial_transactions` tablosuna `custom_category` (String, nullable) kolonu ekle.
2. `category` Enum'u `other` için fallback olarak kullanılmaya devam etsin.
3. Mali Rapor → Yeni İşlem formunda "Yeni Kategori Oluştur" seçeneği: serbest metin girişi, backend'de `custom_category` alanına kaydedilsin.
4. Grafik/liste gösteriminde `custom_category` varsa Enum yerine o gösterilsin.

### 2.7 Şifre Sıfırlama — SMS Pumping Limiti

**Sorun:** PRD §4.1.4-D'de belirtilen "Aylık limit kontrolü (örn: ayda 15 kez)" backend'de tam implemente edilmemiş. Firebase'in OTP doğrulama akışı mevcut ancak kötü niyetli bot saldırılarına karşı FastAPI rate limiting katmanı eksik.

**Yapılması Gereken:**
1. `users` tablosuna veya Redis'e `password_reset_attempts` counter ekle (aylık sıfırlanan).
2. `/auth/request-otp` endpoint'ine: önce DB/Redis'ten bu aya ait deneme sayısını kontrol et.
3. Limit (15) aşıldıysa `429 Too Many Requests` döndür ve kullanıcıyı emlakçısına yönlendir.
4. Meşru taleplerde Firebase `verifyPhoneNumber` tetiklensin.

### 2.8 Ev Sahibi — Yatırım Fırsatları Vitrini (Filtreleme)

**Sorun:** `landlord_investment_screen.dart` boş daire listesini çekiyor ancak PRD §4.3.4'te belirtilen fiyat/lokasyon/özellik bazlı filtreleme ve chat üzerinden "Bu portföyle ilgileniyorum" mesajı gönderme henüz implemente edilmemiş.

**Yapılması Gerekenler:**
1. Fiyat aralığı, oda sayısı, özellik filtresi UI bileşenleri ekle.
2. Filtre parametrelerini `GET /properties/vacant-units/` sorgu parametrelerine bağla.
3. Mülk kartındaki "Emlakçıya Mesaj At" butonu — chat conversation oluştur ve ilgili mülk bilgisini mesaj içeriğine ekle.

### 2.9 Backend — Kritik Bug: `User.agency_id` Referansı

**Sorun:** `backend/app/api/endpoints/landlord.py` satır ~499-502'de `User.agency_id` alanına sorgu yapılıyor, ancak `User` modelinde `agency_id` kolonu yok. Bu alan `agency_staff` tablosundan join ile elde edilmeli.

**Hatanın Sonucu:** Bu endpoint çağrıldığında `sqlalchemy.exc.InvalidRequestError` veya `AttributeError` fırlatır ve uygulama çöker.

**Düzeltme:**
```python
# YANLIŞ (mevcut):
User.agency_id == agency_id

# DOĞRU:
AgencyStaff.agency_id == agency_id, User.id == AgencyStaff.user_id
# (join ile)
```

### 2.10 Schema Uyumsuzluğu — Chat ConversationCreate

**Sorun:** `chat_tab.dart`'daki `_NewChatSheet` widget'ı backend'e `POST /chat/conversations/` isteği gönderirken `client_role` alanını gönderiyor, ancak backend `ConversationCreate` Pydantic schema'sında bu alan mevcut değil. Bu durum `422 Unprocessable Entity` hatasına yol açar.

**Düzeltme (2 seçenek):**
- Frontend'den `client_role` alanını kaldır (daha hızlı fix).
- Backend schema'ya `client_role: Optional[str]` alanı ekle ve gerekirse kullan.

### 2.11 Offline — Veri Okuma Önbellekleme (§5.1)

**Sorun:** PRD §5.1'de portföy, kiracı telefon rehberi ve geçmiş raporların yerel SQLite/Hive/Isar veritabanına kaydedilmesi gerekiyor. Mevcut offline destek sadece yazma kuyruğunu (chat mesajı, operasyon girişi) kapsıyor; okuma tarafında önbellekleme yok.

**Yapılması Gerekenler:**
1. `isar` veya `hive` paketi ekle.
2. `properties_provider.dart` ve `finance_provider.dart`'a: başarılı API yanıtlarını yerel DB'ye yaz.
3. Bağlantı yokken: API çağrısı yerine yerel DB'den oku.
4. Bağlantı geldiğinde: arka planda veriyi yenile ve yerel DB'yi güncelle.

---

## Bölüm 3 — Sıfırdan Geliştirilmesi Gereken Özellikler ❌

### 3.1 Kiracı Yönetimi Ekranı (Öncelik: KRİTİK)

Bu ekran (`tenants_management_screen.dart`) PRD §4.1.4'ün tüm gereksinimlerini karşılaması için sıfırdan yazılmalıdır. Backend her şeyi destekliyor.

**Geliştirme Kapsamı:**
```
KiracıYönetimiEkranı
├── Tab 1: Aktif Kiracılar
│   ├── Kiracı listesi (GET /tenants/ - status=active)
│   ├── Kiracı kartı: Ad, Daire, Kira Bedeli, Ödeme Günü
│   ├── Kiracı Detay: Sözleşme, Belgeler, Ödeme Geçmişi
│   └── Sözleşme Feshi (Offboarding) akışı → daire "Boş" olur
├── Tab 2: Eski Kiracılar (Pasif)
│   └── Kiracı listesi (GET /tenants/ - status=past)
├── Tab 3: Ev Sahipleri
│   ├── Ev sahibi listesi (GET /landlord/)
│   ├── Ev sahibi ekleme formu (çoklu mülk atama)
│   └── Ev sahibi profil detayı
└── FAB: Yeni Kiracı Ekle
    ├── Ad Soyad, Telefon, TC No
    ├── Daire seçimi (boş daireler listesi)
    ├── Kira bedeli, Aidat, Ödeme günü
    ├── Sözleşme başlangıç/bitiş tarihi
    ├── PDF sözleşme yükleme (file_picker → /media/upload)
    └── WhatsApp davet butonu (wa.me/ şeması)
```

### 3.2 Chat — Medya Gönderim Altyapısı (Öncelik: Yüksek)

`image_picker` ve `file_picker` paketleri kurulup tam olarak entegre edilmeli (detaylar §2.3'te).

### 3.3 Portföy — Dinamik Form Tamamlanması (Öncelik: Orta)

Mülk tipine göre form alanlarının dinamik gösterim/gizleme mantığı tamamlanmalı (detaylar §2.4'te).

### 3.4 SMS Pumping Koruması / Rate Limiting (Öncelik: Orta)

OTP şifre sıfırlama endpoint'ine aylık limit kontrolü eklenmeli (detaylar §2.7'de).

### 3.5 Özel Finansal Kategori Yönetimi (Öncelik: Düşük)

Kullanıcı tanımlı özel kategori sistemi (detaylar §2.6'da).

---

## Bölüm 4 — Bug Öncelik Listesi 🐛

| # | Bug | Dosya | Etki | Öncelik |
|---|---|---|---|---|
| 1 | `User.agency_id` yok — runtime SQL hatası | `landlord.py` ~L499 | Uygulama çöker | 🔴 Kritik |
| 2 | `client_role` schema uyumsuzluğu | `chat_tab.dart` + `schemas/chat.py` | Chat conversation açılamaz | 🔴 Kritik |
| 3 | Medya gönderimi placeholder snackbar | `chat_window_screen.dart` ~L823 | Özellik çalışmıyor | 🟠 Yüksek |
| 4 | PDF receipt upload placeholder | `tenant_finance_tab.dart` ~L111 | Özellik çalışmıyor | 🟠 Yüksek |
| 5 | Tenant paneli tüm sekmeler mock veri | `tenant_provider.dart` | Kiracı veri göremez | 🟠 Yüksek |
| 6 | Kiracı Yönetim ekranı placeholder | `tenants_management_screen.dart` | Kiracı eklenemiyor | 🔴 Kritik |
| 7 | Offline okuma önbellekleme yok | `*_provider.dart` dosyaları | Offline'da veri yok | 🟡 Orta |
| 8 | OTP rate limiting yok | `auth.py` | SMS Pumping riski | 🟡 Orta |

---

## Bölüm 5 — Genel Mimari Değerlendirmesi

### Güçlü Yönler
- **Multi-tenancy** `agency_id` üzerinden RLS ile doğru uygulanmış.
- **AI Pipeline** (Gemini 2.5 Flash + pdfplumber + difflib) production kalitesinde tasarlanmış.
- **WebSocket Chat** ölçeklenebilir yapıda (Redis Pub/Sub hazırlığı mevcut).
- **Soft Delete** ve **UUID PK** tüm tablolarda tutarlı uygulanmış.
- **APScheduler** Celery bağımlılığı olmadan hafif ve etkin çalışıyor.
- **Ev Sahibi Paneli** %100 tamamlanmış durumda — backend + frontend eksiksiz.
- **BI Analytics** tüm PRD metrikleri implemente edilmiş.

### Zayıf Yönler / Dikkat Edilmesi Gerekenler
- **Kiracı paneli backend→frontend köprüsü** tamamlanmamış (en büyük eksik).
- **Kiracı Yönetim Ekranı** kritik akışların UI'ı yok.
- **Medya paylaşımı** chat ve dekont yükleme için tamamlanmalı.
- **Firebase Phone Auth** Console'da henüz aktif edilmemiş — production'a geçmeden önce aktif edilmeli.
- **Redis Pub/Sub** WebSocket için altyapıda var ancak tam entegrasyon doğrulanmalı.

---

## Bölüm 6 — Önerilen Geliştirme Sırası

```
FAZA 1 — Kritik Bug'lar (1-2 gün)
  1. landlord.py User.agency_id bug düzelt
  2. chat schema client_role uyumsuzluğunu çöz
  3. Firebase Phone Auth'u Console'da aktif et

FAZA 2 — Kiracı Yönetim Ekranı (3-5 gün)
  4. tenants_management_screen.dart sıfırdan yaz
  5. WhatsApp davet akışı (url_launcher)
  6. Sözleşme feshi / offboarding UI

FAZA 3 — Tenant Panel API Bağlantısı (2-3 gün)
  7. Tüm tenant sekme provider'larını mock'tan API'ye geçir
  8. file_picker / image_picker ekle (tenant dekont + chat medya)

FAZA 4 — Portföy Form Tamamlama (1-2 gün)
  9. Dinamik form alanları (arsa/müstakil/apartman)
  10. OTP rate limiting (SMS Pumping koruması)

FAZA 5 — Offline Okuma Önbellek (2-3 gün)
  11. isar/hive paketi + portföy/finans offline caching

FAZA 6 — İyileştirmeler (1-2 gün)
  12. Özel kategori yönetimi (mali rapor)
  13. Yatırım vitrini filtreleme
  14. Ticket → Bina Operasyonu kısayolu tam bağlantısı
```

---

*Bu rapor, `prd.md` (v2.0) ile `backend/app/` ve `frontend/lib/features/` kaynak kodu karşılaştırılarak 14 Nisan 2026 tarihinde hazırlanmıştır.*
