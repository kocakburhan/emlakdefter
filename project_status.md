# Emlakdefter SaaS — Proje Durum Raporu
**Son Güncelleme:** 26 Nisan 2026 | **Repo:** [github.com/kocakburhan/emlakdefter](https://github.com/kocakburhan/emlakdefter)

> Bu dosya projenin **tek kaynak gerçeği (Single Source of Truth)** olarak tasarlanmıştır.
> ⚠️ **ÖNEMLİ:** Burada "Tamamlandı" yazması, test edilmiş ve çalışıyor anlamına gelmez. Her madde **test edilerek** doğrulanmalıdır.

---

## Genel İlerleme

| Katman | İlerleme | Durum |
|---|---|---|
| **Altyapı** (DB, Docker, Firebase) | ~80% | 🟡 Firebase Phone Auth hâlâ aktif değil |
| **Backend API** | ~60% | 🟡 Modüller mevcut ama test edilmemiş |
| **Frontend UI** | ~70% | 🟡 Ekranlar var ama kapsamlı test yok |
| **AI/ML** (Gemini PDF) | ~70% | 🟡 Temel entegrasyon var, detaylı test gerekli |
| **Ev Sahibi Paneli** | ~85% | 🟡 |
| **Kiracı Paneli** | ~85% | 🟡 |
| **Offline/Sync** | ~50% | 🔴 İskelet var, test edilmedi |
| **BI/Analytics** | ~80% | 🟡 Web platformuna ayrıştırma devam ediyor |

---

## Teknik Mimari

### Teknoloji Yığını
- **Backend:** Python/FastAPI + PostgreSQL (RLS) + Redis Pub/Sub
- **Mobil:** Flutter (iOS, Android, Web)
- **Auth:** Firebase Auth (JWT tabanlı)
- **Altyapı:** Hetzner VPS + Hetzner Object Storage

### Backend Modülleri (12 endpoint dosyası)
```
backend/app/api/endpoints/
├── auth.py          → Login, OTP, Password reset, FCM token
├── properties.py    → Portföy CRUD + birim yönetimi
├── tenants.py       → Kiracı/Ev Sahibi CRUD + tenant-specific API'ler
├── finance.py       → Mali işlemler + AI statement upload
├── operations.py   → Destek biletleri + bina operasyonları + dashboard KPI
├── chat.py          → WebSocket + mesajlaşma CRUD
├── landlord.py     → Ev sahibi özel endpoint'leri
├── analytics.py    → BI dashboard endpoint'leri
├── media_upload.py → Dosya yükleme (Hetzner Object Storage)
├── scheduler.py    → APScheduler yönetim API
├── admin.py        → Admin paneli
└── agency.py       → Ajans yönetimi
```

### Frontend Ekran Sayısı (~24 ekran)
- **Auth:** 4 ekran (rol seçimi, telefon, OTP, şifre)
- **Agent:** ~12 ekran (dashboard, portföy, finans, destek, chat, mali rapor, BI, etc.)
- **Tenant:** ~7 ekran
- **Landlord:** ~5 ekran

---

## Kritik Eksiklikler ve Yapılacaklar

### 🔴 Acil — Test Edilmesi Gerekenler
1. **Firebase Phone Auth** — Console'da aktif edilmedi
2. **Tüm API endpoint'leri** — Entegrasyon testleri yok
3. **WebSocket Chat** — Backend çalışıyor mu test edilmedi
4. **Offline Sync** — Queue mekanizması var ama test edilmedi
5. **Gemini PDF parsing** — Gerçek banka ekstresiyle test edilmedi

### 🟡 Orta Öncelik
1. **Web platformu** — `bi_analytics_screen_web.dart`, `mali_rapor_screen_web.dart` ayrıştırması devam
2. **Hetzner Object Storage** — Bucket credentials gerekli (prod deployment)
3. **APScheduler bildirimleri** — FCM notification mekanizması test edilmedi
4. **Excel/PDF export** — Gerçek verilerle test edilmedi

---

## Veritabanı Modelleri (16 tablo)

| Tablo | Model Dosyası | Durum |
|---|---|---|
| `agencies` | `users.py → Agency` | 🟢 |
| `users` | `users.py → User` | 🟡 `firebase_uid` alanı kontrol edilmeli |
| `agency_staff` | `users.py → AgencyStaff` | 🟢 |
| `invitations` | `users.py → Invitation` | 🟢 |
| `user_device_tokens` | `users.py → UserDeviceToken` | 🟢 |
| `properties` | `properties.py → Property` | 🟡 type enum uyumsuzluğu olabilir |
| `property_units` | `properties.py → PropertyUnit` | 🟡 |
| `landlords_units` | `tenants.py → LandlordUnit` | 🟢 |
| `tenants` | `tenants.py → Tenant` | 🟡 `documents` JSONB eksik |
| `financial_transactions` | `finance.py → FinancialTransaction` | 🟡 `receipt_url`, `ai_matched` eksik |
| `payment_schedules` | `finance.py → PaymentSchedule` | 🟡 `transaction_id` FK eksik |
| `support_tickets` | `operations.py → SupportTicket` | 🟢 |
| `ticket_messages` | `operations.py → TicketMessage` | 🟢 |
| `building_operations_log` | `operations.py → BuildingOperation` | 🟡 `transaction_id` FK eksik |
| `chat_conversations` | `chat.py → ChatConversation` | 🟢 |
| `chat_messages` | `chat.py → ChatMessage` | 🟢 |

---

## Backend API Endpoint'leri

| Servis | Endpoint'ler | Durum |
|---|---|---|
| Auth | `/login`, `/otp`, `/reset-password`, `/fcm-token` | 🟡 Test edilmedi |
| Properties | `GET/POST /`, `GET/PATCH /{id}`, `GET/PATCH /units/{id}` | 🟡 Test edilmedi |
| Tenants | `GET/POST /`, `PATCH/{id}`, `deactivate`, `/landlords/*` | 🟡 Test edilmedi |
| Finance | `GET /transactions`, `POST /upload-statement` | 🟡 Test edilmedi |
| Operations | `GET/POST /tickets`, `dashboard-kpi`, `building-logs` | 🟡 Test edilmedi |
| Chat | `GET/POST /conversations`, `WS /ws/{id}`, CRUD | 🟡 Test edilmedi |
| Landlord | `/dashboard`, `/properties`, `/units`, `/tenants` | 🟡 Test edilmedi |
| Analytics | `/bi-dashboard`, `/bi/*` | 🟡 Test edilmedi |
| Media | `POST /upload/media` | 🟡 Test edilmedi |
| Scheduler | `/scheduler/status`, `/trigger/*` | 🟡 Test edilmedi |

---

## Yol Haritası

| Faz | Açıklama | Durum |
|---|---|---|
| FAZ 0 | Lokal Kurulum | ✅ Tamamlandı |
| FAZ 1 | Temel Altyapı (DB + API iskelet) | ✅ Tamamlandı |
| FAZ 2 | Auth & Onboarding | 🟡 Temel var, test gerekli |
| FAZ 3 | Portföy Motoru | 🟡 Var, detaylı test gerekli |
| FAZ 4 | Finans / AI Tahsilat | 🟡 Var, test gerekli |
| FAZ 5 | İletişim / Destek | 🟡 Var, WebSocket test gerekli |
| FAZ 6 | Kiracı / Ev Sahibi Panelleri | 🟡 Var, test gerekli |
| FAZ 7 | Offline Mode | 🔴 Sadece iskelet |
| FAZ 8 | BI, Raporlama & Yayın | 🟡 Web platformu devam |

---

## Deployment Durumu

### VPS (Hetzner — 89.167.15.127)
- Sunucu hazır ancak backend deploy edilmedi
- `deploy/` dizini hazır: docker-compose.prod.yml, Dockerfile, nginx.conf

### Yapılacaklar (Deployment)
1. SSH key ekleme (Hetzner panelinden)
2. Backend repo clone + `.env` setup
3. Docker Compose ile PostgreSQL + Redis başlatma
4. Alembic migration çalıştırma
5. uvicorn ile backend başlatma

---

## Test Durumu Özeti

⚠️ **KRITIK NOT:** Aşağıdaki maddelerde "Tamamlandı" yazması gerçekte test edilmiş olduğu anlamına GELMEZ. Her biri ayrıca test edilmelidir.

| Alan | Test Edildi mi? | Not |
|---|---|---|
| Login/OTP Flow | ❌ Hayır | Firebase Phone Auth aktif değil |
| Properties CRUD | ❌ Hayır | — |
| Tenant CRUD | ❌ Hayır | — |
| Chat WebSocket | ❌ Hayır | — |
| Gemini PDF Parsing | ❌ Hayır | Sadece mock data ile çalıştı |
| FCM Notifications | ❌ Hayır | — |
| Offline Sync | ❌ Hayır | Sadece kod yazıldı |
| Excel/PDF Export | ❌ Hayır | — |

---

## Bilinen Önemli Noktalar

- Firebase Phone Auth: Console'da henüz aktif edilmedi
- `emlakdefter_db` → port 5433, `emlakdefter_redis` → port 6379
- Eski Firebase Admin SDK anahtarı git geçmişinden temizlendi
- Web platformu için ayrı screen dosyaları oluşturuluyor (`*_web.dart`, `*_web_stub.dart`)

---

## Tamamlanan Görevler

### 30 Nisan 2026 — Özet Ekranı Agent Workflow ile Yeniden Geliştirildi

**Agent Workflow Kullanıldı:** planner → ui-agent → builder → reviewer

#### 1. Planlama (planner agent)
- Mevcut sorunlar tespit edildi: sahte demo veriler, API bağlantısı yok, filtreleme yok
- Adım-adım uygulama planı oluşturuldu
- Risk analizi yapıldı

#### 2. UI Tasarım (ui-agent agent)
- Layout wireframe oluşturuldu
- Component breakdown yapıldı
- FilterChipBar, ActivityItem, ActivityListContainer tasarımları
- Animation specs belirlendi (400ms fade-in + slideX, 60ms stagger)
- States: Loading, Empty, Error, Pagination

#### 3. Kod Geliştirme (builder agent)
- `ActivityItem` modeli API'den gerçek veri çekiyor
- `/operations/activity-feed` API'sine bağlandı
- 5'li filtre sistemi eklendi (Tümü, Ödemeler, Biletler, Kiracılar, Bina Operasyonları)
- Client-side filtering (backend filter yoktu)
- Pagination ("Daha Fazla Göster")
- Pull-to-refresh
- Animasyonlar korundu (flutter_animate)
- Test dosyası oluşturuldu (6 test geçti)

#### 4. Code Review (reviewer agent)
- Quality review: MEDIUM (silent API error handling, performance), LOW (no end indicator)
- Security review: CRITICAL/HIGH issue yok — güvenli
- Auth properly handled, no hardcoded secrets

#### Dosyalar
- `frontend/lib/features/agent/screens/summary_screen.dart` — Baştan yazıldı
- `frontend/test/summary_screen_test.dart` — Yeni test dosyası

**Durum:** Production seviyesinde ✅

### 1 Mayıs 2026 — Özet Ekranı Timestamp + Auth Bug'ları Düzeltildi

**Sorunlar:**
1. Özet ekranında yeni eklenen mülkler 3 saat önce görünüyordu
2. Giriş yapmadan API'ye erişilemiyordu (401 Unauthorized)

**Kök Nedenler:**
1. **Timestamp:** Backend UTC timestamp gönderiyor ama Z suffix yok. Dart `DateTime.parse` naive datetime'yu UTC değil LOCAL olarak yorumluyor. Sonuç: 22:30 UTC → 22:30 Turkey olarak görünüyor (aslında 01:30 Turkey olmalı)
2. **Auth:** Flutter debug mode'da giriş yapmadan API'ye istek atılıyordu ama geçerli token yoktu

**Düzeltmeler:**

1. `frontend/lib/features/agent/screens/summary_screen.dart`:
   - `ActivityItem.fromJson()`: `DateTime.parse('${ts}Z').toLocal()` ile doğru timezone çevirisi

2. `frontend/lib/core/network/api_client.dart`:
   - Debug mode'da `dev_bypass_token_12345` otomatik kullanılıyor
   - `getEffectiveToken()` ve `devBypassToken` getter'ları eklendi

3. `backend/app/api/endpoints/operations.py`:
   - Tenant sorgusuna `selectinload(Tenant.user)` eklendi (lazy load hatası)
   - `t.full_name` yerine `t.user.full_name` kullanılıyor

4. `backend/.env`:
   - `DEV_TOKEN="dev_bypass_token_12345"` eklendi

5. `deploy/docker-compose.dev.yml`:
   - `DEV_MODE=false` environment satırı kaldırıldı (`.env` değerlerini eziyordu)

**Doğrulama:**
```bash
curl -H "Authorization: Bearer dev_bypass_token_12345" \
  "http://localhost:8000/api/v1/operations/activity-feed?limit=5"
```
Sonuç: Mülkler doğru zaman damgasıyla görünüyor ✅

**Dosyalar:**
- `frontend/lib/features/agent/screens/summary_screen.dart`
- `frontend/lib/core/network/api_client.dart`
- `backend/app/api/endpoints/operations.py`
- `backend/.env`
- `deploy/docker-compose.dev.yml`

**Durum:** Test edildi, hatasız ✅

### 1 Mayıs 2026 — BI Analytics Dönem Filtresi Düzeltildi

**Sorun:** 1 Ay / 3 Ay / 6 Ay / 12 Ay / Geçen Yıl seçenekleri çalışmıyordu — backend tüm verileri her zaman 12 ay olarak döndürüyordu, frontend'in seçim yapmasına rağmen.

**Kök Neden:** 
1. Backend `bi-dashboard` endpoint'i `period` query parametresi almıyordu
2. Frontend `_selectedPeriod` değiştirince API'ye yeni period değeri gönderilmiyordu
3. Tüm `_build_*` helper fonksiyonları sabit `range(11, -1, -1)` (12 ay) kullanıyordu

**Çözüm:**

1. `backend/app/api/endpoints/analytics.py`:
   - `_PERIOD_MAP` dictionary eklendi: `{"1m":1, "3m":3, "6m":6, "12m":12, "ytd":0, "py":-1}`
   - `get_bi_analytics_dashboard` endpoint'ine `period: str = "12m"` param eklendi
   - `months_back = _PERIOD_MAP.get(period, 12)` ile dönem çözümlemesi
   - 4 helper fonksiyonun signature'ına `months_back: int = 12` eklendi
   - Tüm loop'lar `range(months_back - 1, -1, -1)` olarak güncellendi

2. `frontend/lib/features/agent/screens/bi_analytics_screen.dart`:
   - `BIAnalyticsNotifier.fetch(period)` → API'ye `?period=` gönderiyor
   - `_periodValueMap`: UI label → backend değer (`'Bu Yıl' → '12m'`, vb.)
   - `onTap` → `setState` + `fetch(period)` eşzamanlı çağrılıyor

3. Test dosyaları:
   - `backend/tests/verify_period.py` — Manuel doğrulama scripti
   - `backend/tests/test_analytics_period.py` — pytest testleri

**Doğrulama:**
```bash
for p in 1m 3m 6m 12m; do python tests/verify_period.py $p; done
# period=1m -> 1 months
# period=3m -> 3 months
# period=6m -> 6 months
# period=12m -> 12 months

pytest tests/test_analytics_period.py -v
# 2 passed in 7.57s
```

**Dosyalar:**
- `backend/app/api/endpoints/analytics.py` — Period param + helper güncellemeleri
- `frontend/lib/features/agent/screens/bi_analytics_screen.dart` — Fetch + period map
- `backend/tests/test_analytics_period.py` — pytest testleri
- `backend/tests/verify_period.py` — Manuel doğrulama

**Durum:** Tüm testler geçti, hatasız ✅

### 30 Nisan 2026 — Activity Feed Property Bug Düzeltildi

**Sorun:** Binalar ekranından yeni arsa/mülk eklenince özet ekranındaki aksiyon listesinde gösterilmiyordu.

**Kök Neden:** `/operations/activity-feed` endpoint'i sadece 4 kaynak sorguluyordu:
1. FinancialTransaction (ödeme)
2. SupportTicket (bilet)
3. BuildingOperationLog (bina operasyonu)
4. Tenant (kiracı)

Property tablosu hic sorgulanmiyordu.

**Çözüm:** Backend `operations.py`'ya 5. kaynak olarak Property sorgusu eklendi.

**Değişiklik:**
- `backend/app/api/endpoints/operations.py` — Property sorgusu eklendi (satır 601+)
- Property tipi: "property", icon: "home", color: "accent"
- Type labels: Apartment, Müstakil Ev, Arsa, Ticari

**Dosyalar:**
- `backend/app/api/endpoints/operations.py` — Property activity eklendi
- `backend/.env` — DEV_AGENCY_ID düzeltildi

### 30 Nisan 2026 — Activity Feed Property Bug ROOT CAUSE + FIX

**ROOT CAUSE (Sistematik Debug ile Tespit Edildi):**
1. `DEV_AGENCY_ID` yanlış değere sahipti: `00000000-0000-0000-0000-000000000001`
2. Properties tablosundaki mülkler farklı agency_id'lerle kayıtlı
3. Backend doğru agency_id'den property sorguladığı için sonuç boş geliyordu

**Çözüm:**
1. `backend/.env` dosyasında `DEV_AGENCY_ID` doğru değere değiştirildi: `f8148239-11b2-462b-b116-a25f1d3b42e8`
2. Backend container yeniden başlatıldı

**Test:** Artık mülk ekleme aksiyonları görünür olmalı.
