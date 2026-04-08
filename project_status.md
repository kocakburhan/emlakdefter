# 📋 Emlakdefteri SaaS — Proje Durum Raporu
**Son Güncelleme:** 8 Nisan 2026 (Gece) | **Repo:** [github.com/kocakburhan/emlakdefter](https://github.com/kocakburhan/emlakdefter)

> Bu dosya, projenin **tek kaynak gerçeği (Single Source of Truth)** olarak tasarlanmıştır. 
> Yapılan her değişiklik, her oturumun özeti ve ilerleme takibi bu dosyada tutulur.

---

## Genel İlerleme

```
████████████░░░░░░░░░░░░░░░░░░ ~35%
```

| Katman | İlerleme | Detay |
|---|---|---|
| **Altyapı** (DB, Docker, Firebase, Auth) | ~80% | Firebase Phone Auth Console'da aktif edilmeli |
| **Backend API** | ~30% | 5/11 modül (auth, properties, finance, operations, chat) |
| **Frontend UI** | ~30% | 7/24 ekran (6 mock, 1 gerçek API) |
| **AI/ML** | ~15% | Gemini iskelet var, gerçek dekont okuma yok |
| **Ev Sahibi Paneli** | %0 | 4 ekran hiç yok |
| **Offline/Sync** | %0 | Hive/Isar + Queue henüz yok |
| **BI/Analytics** | %0 | Grafik ve raporlama henüz yok |

---

## Yol Haritası (Faz Durumları)

| Faz | Durum |
|---|---|
| **FAZ 0:** Lokal Kurulum | ✅ Tamamlandı |
| **FAZ 1:** Temel Altyapı (DB + API iskelet) | ✅ Tamamlandı |
| **FAZ 2:** Auth & Onboarding (Firebase) | ✅ Tamamlandı |
| **FAZ 3:** Portföy Motoru | 🟡 Kısmen — Properties API bağlandı. Daire Detay + Kiracı/Ev Sahibi Yönetim ekranları yok. |
| **FAZ 4:** Finans / AI Tahsilat | ⏸️ Bekliyor — Finance endpoint iskelet var, Gemini entegrasyon bekliyor |
| **FAZ 5:** İletişim / Destek | ⏸️ Bekliyor — WebSocket iskelet var, Chat UI + Destek mock→API bekliyor |
| **FAZ 6:** Kiracı / Ev Sahibi Panelleri | ⏸️ Bekliyor — Kiracı mock hazır, Ev Sahibi %0 |
| **FAZ 7:** Offline Mode | ⏸️ Bekliyor |
| **FAZ 8:** BI, Raporlama & Yayın | ⏸️ Bekliyor |

---

## PRD ↔ Kod Eşleştirme Tablosu

### A. Veritabanı Modelleri (16 Tablo)

| # | PRD Tablosu | Model Dosyası | Durum | Eksikler |
|---|---|---|---|---|
| 1 | `agencies` | `users.py → Agency` | 🟢 | — |
| 2 | `users` | `users.py → User` | 🟡 | `firebase_uid` alanı eksik |
| 3 | `agency_staff` | `users.py → AgencyStaff` | 🟢 | — |
| 4 | `invitations` | `users.py → Invitation` | 🟢 | — |
| 5 | `user_device_tokens` | `users.py → UserDeviceToken` | 🟢 | — |
| 6 | `properties` | `properties.py → Property` | 🟡 | `title` → `name` uyumsuzluğu, type enum farklı |
| 7 | `property_units` | `properties.py → PropertyUnit` | 🟡 | `rent_price`, `media_links`, `youtube_video_link` eksik |
| 8 | `landlords_units` | `tenants.py → LandlordUnit` | 🟢 | — |
| 9 | `tenants` | `tenants.py → Tenant` | 🟡 | `documents` (JSONB) eksik |
| 10 | `financial_transactions` | `finance.py → FinancialTransaction` | 🟡 | `receipt_url`, `ai_matched` eksik |
| 11 | `payment_schedules` | `finance.py → PaymentSchedule` | 🟡 | `transaction_id` FK eksik |
| 12 | `support_tickets` | `operations.py → SupportTicket` | 🟢 | — |
| 13 | `ticket_messages` | `operations.py → TicketMessage` | 🟢 | — |
| 14 | `building_operations_log` | `operations.py → BuildingOperation` | 🟡 | `transaction_id` FK eksik |
| 15 | `chat_conversations` | `chat.py → ChatConversation` | 🟢 | — |
| 16 | `chat_messages` | `chat.py → ChatMessage` | 🟢 | — |

### B. Backend API Endpoint'leri

| # | PRD Modülü | Dosya | Endpoint'ler | Durum |
|---|---|---|---|---|
| 1 | Auth & Onboarding | `auth.py` | `POST /login`, `POST /invite`, `GET /me` | 🟢 |
| 2 | Portföy Yönetimi | `properties.py` | `GET /`, `POST /`, `GET /{id}` | 🟢 |
| 3 | Finans & AI Tahsilat | `finance.py` | `POST /upload-statement` | 🟡 Sadece upload |
| 4 | Destek & Operasyon | `operations.py` | `GET/POST /tickets`, `PATCH /{id}`, `POST /{id}/messages` | 🟡 CRUD var |
| 5 | Chat/Mesajlaşma | `chat.py` | `WS /ws/{id}`, `GET /conversations`, `GET /{id}/messages` | 🟡 İskelet |
| 6 | Dashboard KPI | ❌ | — | 🔴 |
| 7 | Mali Rapor (Gelir/Gider) | ❌ | — | 🔴 |
| 8 | Bina Operasyonları | ❌ | — | 🔴 |
| 9 | Raporlama / BI | ❌ | — | 🔴 |
| 10 | Kiracı API'leri | ❌ | — | 🔴 |
| 11 | Ev Sahibi API'leri | ❌ | — | 🔴 |

### C. Frontend Ekranları (24 Ekran)

| # | PRD | Dosya | Veri | Durum |
|---|---|---|---|---|
| | **Auth** | | | |
| 1 | Rol Seçimi | `role_selection_screen.dart` | — | 🟢 |
| 2 | Telefon Girişi | `phone_login_screen.dart` | Firebase | 🟢 |
| 3 | OTP Doğrulama | `otp_verification_screen.dart` | Firebase+Backend | 🟢 |
| | **Emlakçı (Agent)** | | | |
| 4 | Dashboard KPI | `home_tab.dart` | Mock | 🟡 |
| 5 | Portföy Yönetimi | `properties_tab.dart` | ✅ API | 🟢 |
| 6 | Finans & Tahsilat | `finance_tab.dart` | Mock | 🟡 |
| 7 | Destek Biletleri | `support_tab.dart` | Mock | 🟡 |
| 8 | Daire Detay (4.1.3) | ❌ | — | 🔴 |
| 9 | Kiracı/Ev Sahibi Yönetimi (4.1.4) | ❌ | — | 🔴 |
| 10 | Mali Rapor (4.1.6) | ❌ | — | 🔴 |
| 11 | Chat Merkezi (4.1.8) | ❌ | — | 🔴 |
| 12 | Bina Operasyonları (4.1.9) | ❌ | — | 🔴 |
| 13 | Raporlama/BI (4.1.10) | ❌ | — | 🔴 |
| | **Kiracı (Tenant)** | | | |
| 14 | Dashboard + Finans | `tenant_home_tab.dart` | Mock | 🟡 |
| 15 | Ödeme Geçmişi | `tenant_finance_tab.dart` | Mock | 🟡 |
| 16 | Destek Bildirim | `tenant_support_tab.dart` | Mock | 🟡 |
| 17 | Belgelerim (4.2.3) | ❌ | — | 🔴 |
| 18 | Bina Operasyonları (4.2.4) | ❌ | — | 🔴 |
| 19 | Chat Ekranı (4.2.5) | ❌ | — | 🔴 |
| 20 | Yeni Ev Keşfi (4.2.6) | ❌ | — | 🔴 |
| | **Ev Sahibi (Landlord)** | | | |
| 21 | Dashboard + Mülklerim (4.3.1) | ❌ | — | 🔴 |
| 22 | Kiracı Performans (4.3.2) | ❌ | — | 🔴 |
| 23 | Operasyon Takibi (4.3.3) | ❌ | — | 🔴 |
| 24 | Yatırım Fırsatları (4.3.4) | ❌ | — | 🔴 |

---

## Yapılacaklar (Öncelik Sırasıyla)

### 🔴 Acil
- [ ] Firebase Console → Phone Auth aktif et (30 saniye)
- [ ] Uçtan uca test: Login → Properties listeleme

### 📌 Yüksek Öncelik (Çekirdek İş Mantığı)

| # | Görev | PRD | Efor |
|---|---|---|---|
| 1 | Dashboard KPI endpoint + mock→API | 4.1.1 | 1 gün |
| 2 | ~~Finance provider mock→API~~ | ✅ Tamamlandı |
| 3 | Support provider mock→API | 4.1.7 | 1 gün |
| 4 | Tenant provider'lar mock→API | 4.2.x | 1 gün |
| 5 | Daire Detay Ekranı (UI+API) | 4.1.3 | 2 gün |
| 6 | Kiracı/Ev Sahibi Yönetim Ekranı | 4.1.4 | 3 gün |
| 7 | Akıllı Davet (WhatsApp + KVKK) | 4.1.4-B,C | 2 gün |
| 8 | Gemini PDF Dekont Okuma | 3.1 | 3 gün |
| 9 | Mali Rapor Ekranı (Gelir/Gider) | 4.1.6 | 3 gün |
| 10 | APScheduler + FCM bildirimleri | 3.3 | 2 gün |

### 📌 Orta Öncelik

| # | Görev | PRD | Efor |
|---|---|---|---|
| 11 | Chat Merkezi (WhatsApp klonu) | 4.1.8 | 3 gün |
| 12 | Bina Operasyonları UI+API | 4.1.9 | 2 gün |
| 13 | Kiracı — Belgelerim + Bina Ops | 4.2.3-4 | 2 gün |
| 14 | Kiracı — Chat + Yeni Ev Keşfi | 4.2.5-6 | 3 gün |
| 15 | Ev Sahibi Paneli (4 ekran) | 4.3.x | 5 gün |

### 📌 Düşük Öncelik (İleri Faz)

| # | Görev | PRD | Efor |
|---|---|---|---|
| 16 | Raporlama/BI (grafikler, KPI) | 4.1.10 | 5 gün |
| 17 | Excel/PDF Export | 4.1.5-A | 2 gün |
| 18 | Hetzner Object Storage | PRD 1 | 2 gün |
| 19 | Offline Mode (Hive + Queue) | PRD 5 | 5 gün |
| 20 | Store Yayını | — | 3 gün |

---

## Oturum Geçmişi (Changelog)

### 8 Nisan 2026 — Gece Oturumu
- **Rebrand:** Emlog → Emlakdefteri (tüm dosyalarda)
- Docker yeniden oluşturuldu (`emlakdefteri_db` + `emlakdefteri_redis`)
- Alembic migration uygulandı
- FlutterFire CLI: `firebase_options.dart` + `google-services.json`
- `main.dart` → `DefaultFirebaseOptions.currentPlatform` aktif
- Firebase Admin SDK yeni anahtar → `.env` güncellendi
- Git güvenlik: Eski SDK anahtarı `filter-branch` ile silindi, force push
- Bug fix: `ContractStatus` enum + `AsyncSessionLocal` import düzeltmeleri
- GitHub'a push: `github.com/kocakburhan/emlakdefter`
- Kapsamlı envanter raporu yazıldı
- **Finance Mock -> API:** `finance_provider.dart` mock veriden kurtarıldı. `file_picker` eklendi ve gerçek `ApiClient.dio.post` bağlandı.
- **Backend Finance Update:** `endpoints/finance.py` ve `schemas/finance.py` güncellendi, gerçek DB modelleriyle uçtan uca bağlandı.
- **Test:** API root ve Properties uçsuz auth guard testleri yapıldı. Firebase Phone Auth için tarafınızdan console onayı bekleniyor.

### 8 Nisan 2026 — Öğle Oturumu
- **Auth köprüsü:** `deps.py` Firebase token doğrulama + `get_current_user_agency_id`
- **Backend auth:** `/login` → Firebase-only, `/auth/me` eklendi
- **Dio Interceptor:** Firebase'den otomatik token + 401 retry + platform URL
- **Auth provider:** OTP sonrası `_loginToBackend` + `checkAuthStatus`
- **Properties:** Mock → API (`GET/POST /properties` gerçek agency_id ile)

---

## Sistem Durumu (Anlık)

| Bileşen | Durum |
|---|---|
| PostgreSQL (Docker) | ✅ `emlakdefteri_db` — port 5433 |
| Redis (Docker) | ✅ `emlakdefteri_redis` — port 6379 |
| Backend (FastAPI) | ✅ `uvicorn app.main:app` — port 8000 |
| Firebase Auth | ✅ Admin SDK bağlı |
| Firebase Phone Auth | ⚠️ Console'da aktif edilmeli |
| Git | ✅ `github.com/kocakburhan/emlakdefter` |

---

## Dosya Yapısı

```
Emlog/
├── prd.md                       # Gereksinimler (PRD v2.0)
├── project_status.md            # 📍 BU DOSYA — Tek kaynak rapor
├── docker-compose.yml
├── .gitignore
│
├── backend/
│   ├── .env                     # 🔒 Git'te yok
│   ├── emlakdefter-*.json       # 🔒 Git'te yok
│   └── app/
│       ├── main.py
│       ├── database.py
│       ├── core/                # firebase, security, scheduler, llm
│       ├── models/              # 7 dosya, 16 tablo
│       ├── schemas/             # 5 Pydantic şeması
│       ├── services/            # finance_service, property_service
│       └── api/endpoints/       # auth, properties, finance, operations, chat
│
└── frontend/
    ├── firebase_options.dart
    └── lib/
        ├── main.dart            # EmlakdefteriApp
        ├── core/                # theme, router, network (Dio)
        └── features/
            ├── auth/            # 3 ekran + 1 provider
            ├── agent/           # 4 tab + 4 provider
            └── tenant/          # 3 tab + 1 provider
```
