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
