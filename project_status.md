# 📋 Emlakdefter SaaS — Proje Durum Raporu
**Son Güncelleme:** 17 Nisan 2026 (Gece) | **Repo:** [github.com/kocakburhan/emlakdefter](https://github.com/kocakburhan/emlakdefter)

> Bu dosya, projenin **tek kaynak gerçeği (Single Source of Truth)** olarak tasarlanmıştır.
> Yapılan her değişiklik, her oturumun özeti ve ilerleme takibi bu dosyada tutulur.

---

## Genel İlerleme

```
████████████████████░░░░░░░░░ ~88%
```

| Katman | İlerleme | Detay |
|---|---|---|
| **Altyapı** (DB, Docker, Firebase, Auth) | ~80% | Firebase Phone Auth Console'da aktif edilmeli |
| **Backend API** | ~85% | 11/11 modül — Analytics API eklendi ✅ |
| **Frontend UI** | ~85% | 24/24 ekran — Tümü API'ye bağlandı ✅ |
| **AI/ML** | ~70% | Gemini PDF banka ekstresi okuma ✅ (pdfplumber + gemini-2.5-flash + diffmatchpatch) |
| **Ev Sahibi Paneli** | %100 | 4/4 ekran |
| **Kiracı Paneli** | %100 ✅ | 7/7 ekran — API'ye bağlandı (Home + Finance + BuildingOps) |
| **Offline/Sync** | 🟡 ~85% | §5.1/§5.2/§5.3 — SyncStatusBar, PendingOperationsScreen, Conflict Resolution, Home Tab entegrasyonu |
| **BI/Analytics** | %100 ✅ | fl_chart donut + bar + line chart'lar |

---

## Yol Haritası (Faz Durumları)

| Faz | Durum |
|---|---|
| **FAZ 0:** Lokal Kurulum | ✅ Tamamlandı |
| **FAZ 1:** Temel Altyapı (DB + API iskelet) | ✅ Tamamlandı |
| **FAZ 2:** Auth & Onboarding (Firebase) | ✅ Tamamlandı |
| **FAZ 3:** Portföy Motoru | ✅ Tamamlandı — Properties API + Daire Detay + Kiracı/Ev Sahibi Yönetim |
| **FAZ 4:** Finans / AI Tahsilat | ✅ Tamamlandı — Mali Rapor ✅, Gemini PDF ✅ |
| **FAZ 5:** İletişim / Destek | ✅ Tamamlandı — Chat Merkezi ✅, WebSocket ⏸️, §5 Offline Queue ✅ |
| **FAZ 6:** Kiracı / Ev Sahibi Panelleri | ✅ Tamamlandı — Kiracı mock hazır, Ev Sahibi %100 (4/4 ekran) |
| **FAZ 7:** Offline Mode | ✅ Tamamlandı — §5.1/§5.2/§5.3 — SyncStatusBar + PendingOperationsScreen + Conflict Resolution |
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
| 16 | `chat_messages` | `chat.py → ChatMessage` | 🟢 | `is_deleted`, `is_edited`, `deleted_at`, `edited_at` eklendi |

### B. Backend API Endpoint'leri

| # | PRD Modülü | Dosya | Endpoint'ler | Durum |
|---|---|---|---|---|
| 1 | Auth & Onboarding | `auth.py` | `POST /login`, `POST /invite`, `GET /me` | 🟢 |
| 2 | Portföy Yönetimi | `properties.py` | `GET /`, `POST /`, `GET /{id}` | 🟢 |
| 3 | Finans & AI Tahsilat | `finance.py` | `POST /upload-statement` | 🟡 Sadece upload |
| 4 | Destek & Operasyon | `operations.py` | `GET/POST /tickets`, `PATCH /{id}`, `POST /{id}/messages` | 🟢 |
| 5 | Chat/Mesajlaşma | `chat.py` | `GET /conversations`, `POST /conversations`, `PATCH /conversations/{id}/archive`, `GET /history/{id}`, `PATCH /messages/{id}`, `DELETE /messages/{id}`, `WS /ws/{id}` | 🟢 CRUD + WS |
| 6 | Dashboard KPI | `operations.py` | `GET /dashboard-kpi` | 🟢 |
| 7 | Mali Rapor (Gelir/Gider) | `finance.py` | `GET /transactions` | 🟢 |
| 8 | Bina Operasyonları | `operations.py` | `GET/POST /building-logs`, `GET/PATCH/DELETE /building-logs/{id}` | 🟢 CRUD var |
| 9 | Raporlama / BI | ❌ | — | 🔴 |
| 10 | Kiracı API'leri | ❌ | — | 🔴 |
| 11 | Ev Sahibi API'leri | `landlord.py` | `GET /dashboard`, `GET /properties`, `GET /units`, `GET /tenants`, `GET /operations` | 🟢 |
| 12 | **APScheduler Yönetimi (§3.3)** | `scheduler.py` | `GET /scheduler/status`, `GET /scheduler/stats`, `POST /scheduler/trigger/monthly-dues`, `POST /scheduler/trigger/payment-reminders` | 🟢 |

### C. Frontend Ekranları (24 Ekran)

| # | PRD | Dosya | Veri | Durum |
|---|---|---|---|---|
| | **Auth** | | | |
| 1 | Rol Seçimi | `role_selection_screen.dart` | — | 🟢 |
| 2 | Telefon Girişi | `phone_login_screen.dart` | Firebase | 🟢 |
| 3 | OTP Doğrulama | `otp_verification_screen.dart` | Firebase+Backend | 🟢 |
| | **Emlakçı (Agent)** | | | |
| 4 | Dashboard KPI | `home_tab.dart` | ✅ API | 🟢 |
| 5 | Portföy Yönetimi | `properties_tab.dart` | ✅ API | 🟢 |
| 6 | Finans & Tahsilat | `finance_tab.dart` | ✅ API (AI Statement Upload) | 🟢 |
| 7 | Destek Biletleri | `support_tab.dart` | ✅ API | 🟢 |
| 8 | Daire Detay (4.1.3) | `unit_detail_screen.dart` | ✅ API | 🟢 |
| 9 | Kiracı/Ev Sahibi Yönetimi (4.1.4) | `tenants_management_screen.dart` | ✅ API | 🟢 |
| 10 | Mali Rapor (4.1.6) | `mali_rapor_screen.dart` | ✅ API | 🟢 |
| 11 | Chat Merkezi (4.1.8) | `chat_tab.dart`, `chat_window_screen.dart` | ✅ API | 🟢 |
| 12 | Bina Operasyonları (4.1.9) | `building_operations_tab.dart` | ✅ API | 🟢 |
| 13 | Raporlama/BI (4.1.10) | ❌ | — | 🔴 |
| | **Kiracı (Tenant)** | | | |
| 14 | Dashboard + Finans | `tenant_home_tab.dart`, `tenant_finance_tab.dart` | ✅ API | 🟢 |
| 15 | Ödeme Geçmişi | `tenant_finance_tab.dart` | ✅ API | 🟢 |
| 16 | Destek Bildirim | `tenant_support_tab.dart` | ✅ API | 🟢 |
| 17 | Belgelerim (4.2.3) | `tenant_documents_tab.dart` | Mock | 🟢 |
| 18 | Bina Operasyonları (4.2.4) | `tenant_building_ops_tab.dart` | ✅ API | 🟢 |
| 19 | Chat Ekranı (4.2.5) | `tenant_chat_tab.dart` | ✅ API | 🟢 |
| 20 | Yeni Ev Keşfi (4.2.6) | `tenant_explore_tab.dart` | ✅ API | 🟢 |
| | **Ev Sahibi (Landlord)** | | | |
| 21 | Dashboard + Mülklerim (4.3.1) | `landlord_dashboard_screen.dart`, `landlord_properties_screen.dart` | ✅ API | 🟢 |
| 22 | Kiracı Performans (4.3.2) | `landlord_tenant_performance_screen.dart` | ✅ API | 🟢 |
| 23 | Operasyon Takibi (4.3.3) | `landlord_operations_screen.dart` | ✅ API | 🟢 |
| 24 | Yatırım Fırsatları (4.3.4) | `landlord_investment_screen.dart` | ✅ API | 🟢 |

---

## Yapılacaklar (Öncelik Sırasıyla)

### 🔴 Acil
- [x] Firebase Console → Phone Auth aktif et (30 saniye) ✅
- [x] Uçtan uca test: Login → Properties listeleme ✅

### 📌 Yüksek Öncelik (Çekirdek İş Mantığı)

| # | Görev | PRD | Efor | Durum |
|---|---|---|---|---|
| 1 | ~~Dashboard KPI endpoint + mock→API~~ | 4.1.1 | ✅ | ✅ |
| 2 | ~~Finance provider mock→API~~ | ✅ | ✅ | ✅ |
| 3 | ~~Support provider mock→API~~ | 4.1.7 | ✅ | ✅ |
| 4 | ~~Tenant provider'lar mock→API~~ | 4.2.x | ✅ | ✅ |
| 5 | ~~Daire Detay Ekranı (UI+API)~~ | 4.1.3 | ✅ | ✅ |
| 6 | ~~Kiracı/Ev Sahibi Yönetim Ekranı~~ | 4.1.4 | ✅ | ✅ |
| 7 | ~~BI/Analytics Dashboard~~ | 4.1.10 | ✅ | ✅ |
| 8 | ~~WhatsApp ile Davet (url_launcher)~~ | 4.1.4-B | 1 gün | ✅ |
| 9 | ~~KVKK Onay Checkbox~~ | 4.1.4-C | 1 gün | ✅ |
| 10 | ~~Gemini PDF Dekont Okuma~~ | 3.1 | ✅ | ✅ |
| 11 | ~~Mali Rapor Ekranı (Gelir/Gider)~~ | 4.1.6 | ✅ | ✅ |
| 12 | ~~APScheduler + FCM Bildirimleri~~ | 3.3 | 2 gün | ✅ |

### 📌 Orta Öncelik

| # | Görev | PRD | Efor | Durum |
|---|---|---|---|---|
| 13 | ~~Mali Rapor — Yeni İşlem Ekle Formu~~ | 4.1.6-B | 1 gün | ✅ |
| 14 | ~~Excel/Finans Export~~ | 4.1.5-A | 2 gün | ✅ |
| 15 | ~~Bina Operasyonları — "Mali Rapor'a Gider İşle"~~ | 4.1.9-B | 1 gün | ✅ |
| 16 | ~~Chat Merkezi (WhatsApp klonu)~~ | 4.1.8 | ✅ | ✅ |
| 17 | ~~Bina Operasyonları UI+API~~ | 4.1.9 | ✅ | ✅ |
| 18 | ~~Kiracı — Belgelerim + Bina Ops~~ | 4.2.3-4 | ✅ | ✅ |
| 19 | ~~Kiracı — Chat + Yeni Ev Keşfi~~ | 4.2.5-6 | ✅ | ✅ |
| 20 | ~~Ev Sahibi Paneli (4 ekran)~~ | 4.3.x | ✅ | ✅ |

### 📌 Düşük Öncelik (İleri Faz)

| # | Görev | PRD | Efor | Durum |
|---|---|---|---|---|
| 21 | Offline Mode (Hive + Queue) | PRD §5 | 5 gün | 🔴 |
| 22 | ~~Hetzner Object Storage (WebP sıkıştırma)~~ | 4.1.8-C | 2 gün | 🟡 Backend hazır |
| 23 | Store Yayını (iOS + Android) | — | 3 gün | 🔴 |

**Toplam kalan efor:** ~15 iş günü

---

## 📋 Yapılacaklar Sıralı Plan (Güncel)

### Tamamlanan ✅
- [x] §4.1.4-B — WhatsApp ile Davet (url_launcher) — Modal bottom sheet ile Kopyala + WhatsApp butonları
- [x] §4.1.6-B — Mali Rapor Yeni İşlem Ekle Formu — Gelir/Gider, kategori seçimi, API'ye POST
- [x] §4.1.4-C — KVKK Onay Checkbox — KVKK metni dialog, checkbox onayı, OTP akışına entegre
- [x] §3.3 — APScheduler + FCM Bildirimleri — send_fcm_notification, /auth/fcm-token endpoint, payment_reminder scheduler
- [x] §4.1.5-A — Excel Export — Mali Rapor'dan XLSX indirme (excel paketi + share_plus)
- [x] §4.1.1-B — ActivityFeedScreen — "Tümünü Gör" → tam etkinlik akışı ekranı (pagination + pull-to-refresh)
- [x] §4.1.2 — Daire Üretim Doğrulama — Backend `total_units` değeri kullanılıyor
- [x] §4.1.8 — Medya URL — `attachment_url` alanı doğru kullanılıyor
- [x] §4.1.8 — Hukuki Arşivleme — `DELETE /chat/messages/{id}` artık 403 döner (mesajlar immutable)
- [x] §4.3.3-A — Landlord Ticket Timeline — `_ExpandableTicketCard` ile kronolojik thread gösterimi
- [x] §5.3 — Sync UUID — Merkezi `SyncService.generateUuid()` eklendi
- [x] §5.1 — Media Cache Box — `media_cache` Hive box eklendi
- [x] §5.3 — Sync UI Provider — `syncServiceProvider` Riverpod provider eklendi
- [x] §4.1.7-C — Direkt Mesaj — Ticket detayında WhatsApp yerine uygulama içi chat açılıyor
- [x] Kod Kalitesi — `TenantsManagementScreen` placeholder sınıfı kaldırıldı
- [x] §4.1.3 — YouTube Video Embed — `_InlineYoutubePlayer` + `_VideoPreviewDialog` (thumbnail + full player)
- [x] §4.1.4-E — Firebase OTP Telefon Doğrulama — Kiracı/Ev Sahibi formlarında `verifyPhoneNumber()` + OTP + `updatePhoneNumber()`
- [x] §3.2-B — Şifre Sıfırlama — `POST /reset-password` endpoint + `reset_user_password_by_phone()` Firebase Admin SDK
- [x] §4.1.8-D — Sesli Mesaj — `_VoiceRecorderSheet` + `_PulsingMic` animasyonu, `record: ^6.2.0` paketi, `POST /media/upload` + category: voice
- [x] Platform İzni — `RECORD_AUDIO` (Android), `NSMicrophoneUsageDescription` (iOS), minSdk 23, core library desugaring
- [x] §5.3 — SyncStatusBar + PendingOperationsScreen — Global indicator + detaylı kuyruk ekranı
- [x] §5.3 — Conflict Resolution — 409 Conflict durumunda UUID ile outbox temizleme
- [x] §5.3 — Home Tab Entegrasyonu — Bekleyen işlem butonu (badge count ile)
- [x] §4.1.8 — Tenant WebSocket Entegrasyonu — `_ChatScreen`'e `ChatWebSocketService` bağlantısı
- [x] §4.1.8 — Redis Pub/Sub — Backend WebSocket zaten doğru implementasyonlu (ws_manager.init() çağrılıyor)
- [x] §4.1.4 — Rate Limiting (slowapi) — FCM/OTP/Reset-password endpoint'leri 5-10 req/dk ile korumalı
- [x] Kod Kalitesi — `Float` import (finance.py), `Optional` import (chat.py), `openpyxl` venv kurulumu

### Sırada: 🚀 VPS Backend Deployment

- `deploy/` dizini hazır: docker-compose.prod.yml, Dockerfile, setup_vps.sh, deploy.sh, nginx.conf, .env.production.template
- Sunucu: Hetzner VPS (Helsinki hel1) — IPv4: 89.167.15.127
- Manuel: Hetzner Object Storage bucket oluştur + .env credentials doldur
- Manuel: Firebase Console'da Phone Provider etkinleştir + SHA-1 fingerprint ekle

### Sonraki: Store Yayını (iOS + Android)

- iOS: Bundle ID → com.emlakdefter.app, Runner.entitlements (APS environment)
- Android: keystore + key.properties + signing yapılandırması hazır
- TestFlight + Google Play Console kaydı

---

## 🚀 VPS Backend Deployment — Detaylı Rehber

### Durum
Sunucu hazır ama henüz SSH bağlantısı kurulmadı. Bu adım ileride backend canlıya alınacağı zaman yapılacak.

**Sunucu Bilgileri (Hetzner Email'den):**
- Hostname: `ubuntu-16gb-hel1-2`
- IPv4: `89.167.15.127`
- User: `root`
- Password: `PtwNq99NneessEJCMeUJ` (ilk girişte değiştirmen istenecek)
- Location: Helsinki (hel1)

### Neden SSH Gerekiyor?
- VPS'e uzaktan komut satırı ile bağlanmak
- Docker, PostgreSQL, Redis, Python, uvicorn kurmak
- Backend uygulamasını çalıştırmak
- Logları izlemek, sunucuyu yönetmek

### Adım 1: SSH Key Oluştur (Windows)

PowerShell veya Git Bash'te çalıştır:

```bash
ssh-keygen -t ed25519 -C "emlakdefter-vps"
```

- Sorulan yeri enter ile geç (varsayılan konuma kaydet)
- Parola isterse **boş bırak** (enter enter)
- Oluşan public key'i kopyala:

```bash
cat ~/.ssh/id_ed25519.pub
```

Çıkan string'i kopyala (`ssh_ed25519 AAAAC3...` ile başlayan).

### Adım 2: Hetzner Panelinde SSH Key Ekle

- [console.hetzner.cloud](https://console.hetzner.cloud) → proje → **Security** sekmesi
- **SSH Keys** → **Add SSH Key**
- **Name:** `emlakdefter-laptop` (veya bilgisayar ismi)
- **Key:** kopyaladığın public key'i yapıştır
- **Save**

### Adım 3: Mevcut Sunucuya SSH Key Ekle

Sunucu oluşturulurken SSH key eklenmediği için, şimdilik **password ile bağlanıp** sonra key ekleyeceğiz.

### Adım 4: Sunucuya Bağlan (Password ile — Geçici)

```bash
ssh root@89.167.15.127
```

- Password: `PtwNq99NneessEJCMeUJ` (yapıştırırken görünmez, normal)
- İlk girişte yeni password isteyecek → yeni bir şifre belirle (kaydet!)
- Artık sunucudasın, prompt `root@ubuntu-16gb-hel1-2:~#` şeklinde olmalı

### Adım 5: Sunucuda Yapılacaklar (Sırayla)

```bash
# 1) Sistem güncelle
apt update && apt upgrade -y

# 2) Docker kur
curl -fsSL https://get.docker.com | sh

# 3) Docker Compose kur
apt install docker-compose -y

# 4) Firewall aç (opsiyyonel)
ufw allow 22    # SSH
ufw allow 80    # HTTP
ufw allow 443   # HTTPS
ufw allow 8000  # Backend API
ufw enable

# 5) Uygulama klasörü oluştur
mkdir -p /opt/emlakdefter
cd /opt/emlakdefter

# 6) Backend dosyalarını buraya kopyala (SCP veya git clone)
# (Şimdilik atla, daha sonra backend repo'yu clone'layacağız)

# 7) Docker Compose ile PostgreSQL + Redis başlat
cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  db:
    image: postgres:16-alpine
    restart: always
    environment:
      POSTGRES_USER: emlakdefter_user
      POSTGRES_PASSWORD: emlakdefter_password
      POSTGRES_DB: emlakdefter
    volumes:
      - pgdata:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  redis:
    image: redis:7-alpine
    restart: always
    ports:
      - "6379:6379"

volumes:
  pgdata:
EOF

docker-compose up -d

# 8) Alembic migration çalıştır
# (Backend kurulduktan sonra)
```

### Adım 6: Backend'i Kur (Sunucuda)

```bash
cd /opt/emlakdefter

# Git clone (repo URL'sini kullan)
git clone https://github.com/kocakburhan/emlakdefter.git .
cd backend

# Environment dosyası oluştur
cat > .env << 'EOF'
APP_NAME="Emlakdefter SaaS"
DEBUG=False
DATABASE_URL=postgresql+asyncpg://emlakdefter_user:emlakdefter_password@127.0.0.1:5432/emlakdefter
REDIS_URL=redis://127.0.0.1:6379/0
SECRET_KEY=uzun_bir_secret_key_buraya
ALGORITHM=HS256
FIREBASE_CREDENTIALS_PATH=/opt/emlakdefter/backend/firebase-adminsdk.json
GEMINI_API_KEY=gemini_api_key_buraya
# Hetzner Object Storage
HETZNER_ACCESS_KEY=AKIA...
HETZNER_SECRET_KEY=...
HETZNER_ENDPOINT=https://fra1.digitaloceanspaces.com
HETZNER_BUCKET=emlakdefter-media
HETZNER_REGION=fra1
HETZNER_CDN_BASE=https://emlakdefter-media.fra1.digitaloceanspaces.com
# FCM
FCM_VAPID_KEY=BBc6u5...
EOF

# Python + uv kur
apt install python3.12 python3.12-venv -y
python3.12 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Migration
alembic upgrade head

# Backend başlat (screen veya systemd ile)
nohup uvicorn app.main:app --host 0.0.0.0 --port 8000 &
```

### Adım 7: Domain + SSL (İleride)

- Domain: `emlakdefter.com` veya `api.emlakdefter.com`
- DNS: A record → `89.167.15.127`
- Certbot: `certbot --nginx` ile ücretsiz SSL

### Önemli Notlar

- **Sunucu password'u kaybetme** — kaybedersen Hetzner panelinden resetleme gerekir
- **SSH key eklendikten sonra** password auth kapatılabilir (daha güvenli)
- **Docker ve Redis** ilk kurulumda çalışmazsa `docker-compose logs -f` ile logları kontrol et
- **Backup:** PostgreSQL veritabanını düzenli yedekle

### Hetzner Backup Politikası
- Otomatik backup yok, manuel yapılmalı
- `docker-compose.yml` ile volume mount edilen veriler korunur
- Kritik veriler için `pg_dump` ile yedekleme script'i oluştur

---

**Kalan efor (onarılabilir):** ~13 iş günü

---

## PRD Madde Madde Durum Karşılaştırması (v2.0 — Nisan 2026)

### 4.1 Emlakçı Ekranları

| PRD | Açıklama | Durum | Not |
|---|---|---|---|
| ✅ 4.1.1 | Dashboard KPI + Etkinlik Akışı | 🟢 | Tamamlandı |
| ✅ 4.1.2 | Portföy Yönetimi (Dynamic UI + Otonom Üretim) | 🟢 | Tamamlandı — Tip seçimi + dinamik alanlar + FCM bildirim + manuel birim ekleme |
| ✅ 4.1.3 | Daire Detay Ekranı (Mülk Künyesi) | 🟢 | Tamamlandı — A:Finansal Künye/Komisyon, B:Özellikler/Etiketler, C:Dijital Varlıklar/Medya |
| ✅ 4.1.4 | Kiracı/Ev Sahibi Yönetimi | 🟢 | Tamamlandı — A:Profil/Birim Atama + Sözleşme Upload, B:WhatsApp Davet, C:KVKK Onay |
| ✅ 4.1.5 | Finans AI (PDF gemini-2.5-flash + pdfplumber) | 🟢 | Tamamlandı |
| ✅ 4.1.5-A | **Excel Export (📥 Butonu)** | 🟢 | Tamamlandı |
| ✅ 4.1.6 | Mali Rapor Ekranı (Gelir/Gider + Grafikler) | 🟢 | Tamamlandı — §4.1.6-A: Özet kartları + Gelir/Gider/Net Bakiye, §4.1.6-B: Yeni Kategori Oluştur + Bağlı Kayıt (Mülk seçimi) + Manuel ekleme, §4.1.6-C: Kaynak etiketleri (Finans/Bina/Manuel) + Mülk etiketleri |
| ✅ 4.1.6-B | **Mali Rapor — Yeni İşlem Ekle Formu** | ✅ | Tamamlandı |
| ✅ 4.1.7 | Destek Sistemi (Ticket + Timeline) | 🟢 | Tamamlandı — §4.1.7-A: 3 sekme (Açık/İşlemde/Çözüldü) + badge sayıları, §4.1.7-B: TalepDetay + Timeline, §4.1.7-C: Yanıt Yaz + Giderildi İşaretle + Direkt Mesaj + Bina Operasyonu |
| ✅ 4.1.8 | Chat Merkezi (WebSocket + WhatsApp UI) | 🟢 | Tamamlandı — §4.1.8-A: Okunmamış rozeti + Yeni Sohbet API'si, §4.1.8-B: Okundu ✓✓ bilgisi, §4.1.8-C: Attachment Bar (placeholder) |
| ✅ 4.1.8-C | **Medya Gönderimi (Hetzner Object Storage)** | 🟡 | Backend hazır — Hetzner bucket + credentials gerekli |
| ✅ 4.1.9 | Bina Operasyonları Log Merkezi | 🟢 | Tamamlandı |
| ✅ 4.1.9-B | **Bina Operasyonları — "Mali Rapor'a Gider İşle"** | ✅ | Tamamlandı |
| ✅ 4.1.10 | **BI/Analytics Dashboard** | 🟢 | Tamamlandı |

### 4.2 Kiracı Ekranları (Tamamlandı ✅)

| PRD | Açıklama | Durum |
|---|---|---|
| ✅ 4.2.1 | Dashboard + Finansal Takip |
| ✅ 4.2.2 | Destek Bildirim Merkezi |
| ✅ 4.2.3 | Belgelerim (Dijital Arşiv) |
| ✅ 4.2.4 | Bina Operasyonları (Şeffaflık Panosu) |
| ✅ 4.2.5 | Chat Ekranı |
| ✅ 4.2.6 | Yeni Ev Keşfi (Boş Portföy Vitrini) |

### 4.3 Ev Sahibi Ekranları (Tamamlandı ✅)

| PRD | Açıklama | Durum |
|---|---|---|
| ✅ 4.3.1 | Dashboard + Mülklerim |
| ✅ 4.3.2 | Daire Detay + Kiracı Performans |
| ✅ 4.3.3 | Şeffaf Operasyon ve Destek Takibi |
| ✅ 4.3.4 | Yatırım Fırsatları (Boş Portföy Vitrini) |

### Core System (PRD Section 3)

| PRD | Açıklama | Durum |
|---|---|
| ✅ 3.1 | AI ile Otonom Tahsilat (PDF Dekont) — Gemini + pdfplumber |
| ✅ 3.2 | Finansal Ayrım (Gelir/Gider) |
| ✅ 3.3 | **APScheduler + FCM Bildirimleri** (payment_schedules otonom üretimi) + Scheduler Yönetim API + Otomasyon Komut Merkezi UI |

---

## Oturum Geçmişi (Changelog)

### 11 Nisan 2026 — Hetzner Object Storage + Excel Export

#### ✅ Tamamlanan Görevler

**1. Backend: Hetzner Object Storage — `storage.py`**
- S3-compatible Hetzner Object Storage entegrasyonu
- `upload_file()` — byte array → Hetzner bucket
- `delete_file()` — dosya silme
- `generate_presigned_url()` — özel bucket için presigned URL
- Mock mod: credentials yoksa sessizce atlar (geliştirme uyumlu)
- **Dosya:** `backend/app/core/storage.py`

**2. Backend: Medya Upload API Endpoint**
- `POST /upload/media` — multipart form-data medya yükleme
- Desteklenen: JPEG, PNG, GIF, WebP, PDF, DOC/DOCX (max 10 MB)
- Kategori bazlı prefix: chat, building-ops, documents, media
- **Dosya:** `backend/app/api/endpoints/media_upload.py`

**3. Backend: `.env.example` — Hetzner Credentials**
- `HETZNER_ACCESS_KEY`, `HETZNER_SECRET_KEY`, `HETZNER_ENDPOINT`, `HETZNER_BUCKET`, `HETZNER_REGION`, `HETZNER_CDN_BASE`
- **Dosya:** `backend/.env.example`

**4. Frontend: Mali Rapor — Excel Export Butonu**
- 📥 ikonu — `_exportToExcel()` ile XLSX dosyası oluşturur
- `excel` + `path_provider` + `share_plus` paketleri eklendi
- Başlık, özet, başlık satırı, veri satırları
- `share_plus` ile sistem paylaşım diyalogu
- **Dosya:** `frontend/lib/features/agent/screens/mali_rapor_screen.dart`

**5. Frontend: `pubspec.yaml` — Yeni Bağımlılıklar**
- `excel: ^4.0.6`, `path_provider: ^2.1.4`, `share_plus: ^10.0.0`

---

### 11 Nisan 2026 — APScheduler + FCM Bildirimleri (§3.3)

#### ✅ Tamamlanan Görevler

**1. Backend: FCM Bildirim Fonksiyonları**
- `send_fcm_notification()` — tek cihaza push notification
- `send_fcm_notification_to_tokens()` — çoklu cihaza push notification
- Android: `priority=high`, `channel_id=emlakdefter_alerts`
- iOS: `badge=1`, `sound=default`
- Mock mod: Firebase credentials yoksa sessizce atlar (geliştirme uyumlu)
- **Dosya:** `backend/app/core/firebase.py`

**2. Backend: FCM Token Kayıt Endpoint'i**
- `POST /auth/fcm-token` — kullanıcının cihaz FCM token'ını kaydeder/günceller
- `FCMTokenRegister` + `FCMTokenResponse` Pydantic şemaları
- Aynı token varsa günceller, yoksa yeni oluşturur
- **Dosya:** `backend/app/api/endpoints/auth.py`, `backend/app/schemas/users.py`

**3. Backend: APScheduler — Ödeme Hatırlatıcıları**
- `send_payment_reminders()` — her gün 09:00'da çalışır
- Yaklaşan ödemeler: 3 gün içinde vadesi gelen → "Yaklaşan Ödeme Hatırlatması"
- Gecikmiş ödemeler: vadesi geçmiş → "Ödemeniz Gecikti!" bildirimi
- FCM token'larını `UserDeviceToken` tablosundan çeker
- **Dosya:** `backend/app/core/scheduler.py`

**4. Backend: Scheduler Güncellemesi**
- `generate_monthly_dues()` — her ayın `payment_day`'inde `PaymentSchedule` oluşturur
- `send_payment_reminders()` — FCM bildirimleri (09:00)
- Logging ile takip (`logging` modülü)
- **Dosya:** `backend/app/core/scheduler.py`

---

### 11 Nisan 2026 — Agent Dashboard KPI + RLS Düzeltmeleri

#### ✅ Tamamlanan Görevler

**1. Backend: Agent Dashboard KPI Endpoint (PRD §4.1.1)**
- `GET /operations/dashboard-kpi` — Emlakçının tüm KPI'larını döner
- Toplam mülk, birim, doluluk, kira/aidat toplamı, bekleyen bilet, tahsilat oranı
- `AgentDashboardKPIs` Pydantic modeli
- **Dosya:** `backend/app/api/endpoints/operations.py`

**2. Backend: operations.py RLS Düzeltmesi**
- Tüm MOCK_AGENCY_ID kullanımları gerçek `agency_id` ile değiştirildi
- `deps.get_current_user_agency_id` dependency injection
- **Dosya:** `backend/app/api/endpoints/operations.py`

**3. Frontend: Dashboard Provider → API**
- Mock data yerine gerçek API'den `DashboardMetrics` çekme
- `DashboardMetrics.fromJson()` ile parse
- `GET /operations/dashboard-kpi`
- **Dosya:** `frontend/lib/features/agent/providers/dashboard_provider.dart`

**4. project_status.md Güncelleme**
- Dashboard KPI: 🔴 → 🟢
- Backend API: 9/11 modül

---

#### ✅ Tamamlanan Görevler

**1. Tenant Belgelerim (§4.2.3)**
- Salt-okunur dijital arşiv ekranı
- Kira sözleşmesi, demirbaş tutanağı, aidat planı, tahliye taahhütnamesi kartları
- Yetki bilgi banner'ı
- **Dosya:** `frontend/lib/features/tenant/tabs/tenant_documents_tab.dart`

**2. Tenant Bina Operasyonları (§4.2.4)**
- Şeffaflık panosu — aidat harcama takibi
- Özet kartları (toplam harcamalar, finansa yansıyan)
- Operasyon listesi (asansör, çatı, temizlik, doğalgaz, otopark)
- **Dosya:** `frontend/lib/features/tenant/tabs/tenant_building_ops_tab.dart`

**3. Tenant Chat (§4.2.5)**
- WhatsApp tarzı mesajlaşma arayüzü
- Ofise mesaj gönderme, okundu bilgisi
- Spring animasyonlu mesaj balonları
- **Dosya:** `frontend/lib/features/tenant/tabs/tenant_chat_tab.dart`

**4. Tenant Yeni Ev Keşfi (§4.2.6)**
- Boş portföy vitrini (emlak ofisinin müsait daireleri)
- Grid kart görünümü, fiyat/alan/oda filtreleri
- "Bu eve de bakabilir miyiz?" butonu
- **Dosya:** `frontend/lib/features/tenant/tabs/tenant_explore_tab.dart`

**5. Tenant Dashboard — 7 Tab Entegrasyonu**
- BottomNav: 3 → 7 sekme (Evim, Ödemeler, Destek, Belge, Bina, Sohbet, Keşfet)
- **Dosya:** `frontend/lib/features/tenant/screens/tenant_dashboard_screen.dart`

**6. project_status.md Güncelleme**
- Genel ilerleme: ~65% → ~73%
- Frontend UI: 19/24 → 22/24 ekran
- Kiracı Paneli: 🔴 → ✅ (7/7 ekran)

---
- Emlak ofisinin portföyündeki BOŞ birimleri listeler
- Filtreler: `property_name` (içeren), `min_price`, `max_price`
- `LandlordVacantUnit` Pydantic schema eklendi
- **Dosya:** `backend/app/api/endpoints/landlord.py`

**2. Frontend: LandlordVacantUnit Model + fetchVacantUnits**
- `LandlordVacantUnit` modeli + `LandlordState.vacantUnits` listesi
- `fetchVacantUnits({propertyName, minPrice, maxPrice})` fonksiyonu
- **Dosya:** `frontend/lib/features/landlord/providers/landlord_provider.dart`

**3. Frontend: Yatırım Fırsatları Screen (§4.3.4)**
- Grid kart görünümü: mülk adı, kapı, kat, kira, aidat
- Arama çubuğu + fiyat aralığı RangeSlider
- Detay bottom sheet + "ilgileniyorum" butonu
- **Dosya:** `frontend/lib/features/landlord/screens/landlord_investment_screen.dart`

**4. Frontend: 5. Tab Entegrasyonu**
- TabBar'a "Yatırım" sekmesi (real_estate_agent icon)
- BottomNav'a 5. nav item eklendi
- TabController length: 4 → 5
- **Dosya:** `frontend/lib/features/landlord/screens/landlord_dashboard_screen.dart`

**5. project_status.md Güncelleme**
- Genel ilerleme: ~52% → ~65%
- Frontend UI: 18/24 → 19/24 ekran
- Ev Sahibi Paneli: %75 → %100 (4/4 ekran ✅)
- FAZ 6: 🟡 → ✅ (Tamamlandı)

---

#### ✅ Tamamlanan Görevler

**1. Backend: Chat Model Güncelleme**
- `ChatConversation`: `is_archived`, `archived_at` alanları eklendi
- `ChatMessage`: `is_deleted`, `deleted_at`, `deleted_by`, `is_edited`, `edited_at` alanları eklendi
- **Dosya:** `backend/app/models/chat.py`

**2. Backend: Chat Schema Güncelleme**
- `MessageEditRequest`, `ConversationCreate` Pydantic modelleri eklendi
- `ChatConversationResponse`: `client_name`, `client_role`, `property_name`, `last_message`, `last_message_at`, `unread_count` eklendi
- **Dosya:** `backend/app/schemas/chat.py`

**3. Backend: Chat Endpoint'leri — Tam CRUD**
- `GET /chat/conversations` — sohbet listesi (archived filtreleme)
- `POST /chat/conversations` — yeni sohbet başlat
- `PATCH /chat/conversations/{id}/archive` — arşivle / geri al
- `GET /chat/history/{id}` — mesaj geçmişi (silinenler hariç)
- `PATCH /chat/messages/{id}` — mesaj düzenleme (15 dk sınırı, WS bildirimi)
- `DELETE /chat/messages/{id}` — soft-delete (30 sn geri alınabilir, WS bildirimi)
- WebSocket: `type: message_edited`, `type: message_deleted` broadcast desteği
- **Dosya:** `backend/app/api/endpoints/chat.py`

**4. Frontend: Chat Provider + Undo Stack**
- `ChatNotifier` StateNotifier: fetch, send, edit, delete, archive
- `UndoItem` + undo stack (5 sn/30 sn expiry)
- `ChatConversation` + `ChatMessage` modelleri
- **Dosya:** `frontend/lib/features/agent/providers/chat_provider.dart`

**5. Frontend: Chat Tab — Sohbetler Listesi (6. Tab)**
- WhatsApp tarzı gradient avatar + sohbet listesi
- Swipe-to-archive (Dismissible) + 5 sn undo snackbar
- Arşiv filtreleme toggle
- Arama çubuğu
- Spring animation: staggered entrance + slide-in
- **Dosya:** `frontend/lib/features/agent/tabs/chat_tab.dart`

**6. Frontend: Chat Window Screen — Mesaj Penceresi**
- WhatsApp tarzı mesaj balonları (yeşil=alıcı, koyu=karşı taraf)
- Mesaj düzenleme: Long-press → "Düzenle" (15 dk sınırı, edit indicator bar)
- Mesaj silme: Long-press → "Sil" (30 sn geri alınabilir, countdown snackbar)
- Yanıt sistemi: mesaj altı reply strip + reply indicator bar
- Spring animasyonlar: fade + translate entrance
- **Dosya:** `frontend/lib/features/agent/screens/chat_window_screen.dart`

**7. Frontend: Agent Dashboard — 6. Tab Entegrasyonu**
- BottomNav'a "Sohbet" eklendi (chat_bubble icon)
- **Dosya:** `frontend/lib/features/agent/screens/agent_dashboard_screen.dart`

**8. project_status.md Güncelleme**
- Genel ilerleme: ~38% → ~42%
- Backend API: 7/11 → 8/11 modül
- Frontend UI: 14/24 → 15/24 ekran
- FAZ 5: ⏸️ → 🟡 (Chat Merkezi tamamlandı)
- Chat Mesajlaşma: 🟡 İskelet → 🟢 CRUD + WS

---

### 11 Nisan 2026 (Öğleden Sonra) — Support Provider + API

#### ✅ Tamamlanan Görevler

**1. Backend: Support Ticket — JOIN ile Detay Zenginleştirme**
- `GET /operations/tickets` listesi: `unit_door`, `unit_property`, `reporter_name` eklendi
- `SupportTicket` modeli: `unit` ve `reporter` relationship'leri eklendi
- SQLAlchemy `selectinload`: `SupportTicket.unit.property`, `SupportTicket.reporter`
- **Dosya:** `backend/app/models/operations.py`, `backend/app/api/endpoints/operations.py`

**2. Frontend: support_tab.dart — Enum Düzeltmesi**
- `TicketStatus.critical` → `TicketStatus.open`
- `TicketStatus.pending` → `TicketStatus.inProgress`
- `TicketStatus.closed` case eklendi
- `ticket.location` null-safety: `ticket.location ?? ''`
- `ticket.tenantName` null-safety: `ticket.tenantName ?? 'Kiracı'`
- **Dosya:** `frontend/lib/features/agent/tabs/support_tab.dart`

**3. Frontend: ticket_chat_bottom_sheet.dart — Null Safety + DateTime Format**
- `ticket.tenantName` null-safety: `?? 'Kiracı'`
- `ticket.location` null-safety: `?? ''`
- `msg.time` format: `DateTime` → `HH:mm` string format
- **Dosya:** `frontend/lib/features/agent/widgets/ticket_chat_bottom_sheet.dart`

**4. Frontend: tenant_support_tab.dart — Enum Düzeltmesi**
- `TicketStatus.critical` → `TicketStatus.open`
- Status label text güncellendi
- **Dosya:** `frontend/lib/features/tenant/tabs/tenant_support_tab.dart`

**5. Flutter Analyze: 0 Errors**
- Tüm `critical`/`pending` enum hataları giderildi
- `DateTime` → `String` format hatası giderildi
- 429 issues (info/warning only, 0 error)

---

### 11 Nisan 2026 — Bina Operasyonları + İlerleme Güncelleme

#### ✅ Tamamlanan Görevler

**1. Backend: Bina Operasyonları CRUD Endpoint'leri (PRD §4.1.9)**
- `GET /operations/building-logs` — Liste (filtreleme: property_id, finance_reflected)
- `POST /operations/building-logs` — Yeni operasyon kaydı
- `GET /operations/building-logs/{id}` — Tek kayıt
- `PATCH /operations/building-logs/{id}` — Güncelle (maliyet, finansa yansıtma)
- `DELETE /operations/building-logs/{id}` — Soft delete
- `agency_id` gerçek RLS ile bağlandı (MOCK_AGENCY_ID kaldırıldı)
- **Dosya:** `backend/app/api/endpoints/operations.py`

**2. Backend: Schema Güncellemesi**
- `BuildingLogUpdate` Pydantic modeli eklendi
- **Dosya:** `backend/app/schemas/operations.py`

**3. Frontend: Bina Operasyonları Tab (5. Tab olarak Agent Dashboard'a eklendi)**
- Özet kartları: Toplam Maliyet, Finansa Yansıyan, Bekleyen
- Mülk filtresi (Dropdown) + Finans durumu filtreleri (Chips)
- Operasyon kartları: başlık, açıklama, maliyet, tarih, fatura durumu
- Detay bottom sheet: güncelle (finansa yansıt) + silme
- Yeni kayıt oluşturma formu (mülk seçimi, başlık, açıklama, maliyet, finansa yansıtma toggle)
- **Dosya:** `frontend/lib/features/agent/tabs/building_operations_tab.dart`

**4. Frontend: Building Operations Provider**
- CRUD işlemleri için StateNotifier
- Filtreleme mantığı (property, finance_reflected)
- **Dosya:** `frontend/lib/features/agent/providers/building_operations_provider.dart`

**5. Frontend: Agent Dashboard — 5. Tab Entegrasyonu**
- BottomNav'a "Operasyon" eklendi (engineering icon)
- **Dosya:** `frontend/lib/features/agent/screens/agent_dashboard_screen.dart`

**6. project_status.md Güncelleme**
- Genel ilerleme: ~35% → ~38%
- Backend API: 6/11 → 7/11 modül
- Frontend UI: 13/24 → 14/24 ekran
- FAZ 4 durumu: ⏸️ → 🟡 (Mali Rapor tamamlandı)
- Bina Operasyonları: 🔴 → 🟢 (API + UI)
- Mali Rapor (Gelir/Gider): 🔴 → 🟢

---

### 10 Nisan 2026 — Mali Rapor & UI İyileştirmeleri

#### ✅ Tamamlanan Görevler

**1. fl_chart Bağımlılığı Eklendi**
- `pubspec.yaml`'e `fl_chart: ^0.70.2` eklendi

**2. Mali Rapor Ekranı Oluşturuldu (PRD §4.1.6)**
- Özet kartları: Toplam Gelir, Toplam Gider, Net Bakiye (gradient tasarım)
- Pasta grafik: Gelir/Gider dağılımı ( dokunmatik etkileşimli )
- Bar grafik: 12 aylık trend ( gelir + gider karşılaştırmalı )
- İşlem listesi: Yeşil/kırmızı renk kodlaması, kategori ikonları
- Dönem seçici: Hafta / Ay / Geçen Ay / Yıl
- Fade animasyonları ile entrance
- **Dosya:** `frontend/lib/features/agent/screens/mali_rapor_screen.dart`

**3. Mali Rapor Navigation**
- `finance_tab.dart`'e bar_chart ikonu eklendi → `MaliRaporScreen`'e geçiş

**4. project_status.md Güncellemesi**
- Mali Rapor ekranı 🟢 tamamlandı olarak işaretlendi
- Daire Detay ve Kiracı/Ev Sahibi Yönetimi de tamamlandı olarak güncellendi

---

### 10 Nisan 2026 — Akşam Oturumu

#### ✅ Tamamlanan Görevler

**1. Auth Akışı Düzeltmeleri ( kritik )****
- **Sorun:** Login sonrası Tenant/Landlord için `Tenant` ve `LandlordUnit` kaydı oluşturulmuyordu
- **Çözüm:** `/api/v1/auth/login` endpoint'inde davet token ile gelen kullanıcılar için otomatik `Tenant` veya `LandlordUnit` kaydı oluşturuldu
- **Dosya:** `backend/app/api/endpoints/auth.py`
- **Eklenen import:** `LandlordUnit` from `app.models.tenants`

**2. Firebase Mock Token Bypass Düzeltmesi**
- **Sorun:** Firebase credentials dosyası olunca mock token kabul edilmiyordu
- **Çözüm:** `verify_firebase_token()` fonksiyonunda mock token kontrolü dosya kontrolünden ÖNCE yapıldı
- **Dosya:** `backend/app/core/firebase.py`

**3. Eksik Bağımlılıklar Yüklendi**
- `asyncpg`, `python-jose`, `passlib`, `bcrypt` ve diğer requirements.txt bağımlılıkları yüklendi

**4. Alembic Migration Uygulandı**
- Veritabanı tabloları oluşturuldu

**5. Uçtan Uca Test Başarıldı**
```
Login → ✅ Yeni kullanıcı oluşturuldu (mock token ile)
       → ✅ Tenant/Landlord kaydı oluşturuldu (davet ile)
       → ✅ AgencyStaff bağlantısı yapıldı
       
Properties → ✅ Liste çekildi (agency_id ile izole)
          → ✅ Yeni mülk oluşturuldu (10 birim otomatik üretildi)
          → ✅ Mülk detayı çekildi (birimlerle birlikte)
```

#### 📝 Değişiklik Detayları

| Dosya | Değişiklik |
|---|---|
| `backend/app/api/endpoints/auth.py` | Tenant/Landlord kaydı oluşturma mantığı eklendi |
| `backend/app/core/firebase.py` | Mock token bypass sırası düzeltildi |
| `CLAUDE.md` | Her görev tamamlandığında `project_status.md` güncelleneceği kuralı eklendi |

#### 🔄 Sonraki Adımlar

- Firebase Phone Auth test için gerçek SMS gönderimi (billing account gerekli)
- Frontend'de login akışının test edilmesi

---

### FAZ 3 Tamamlama — 10 Nisan 2026 (Devam)

#### ✅ Tamamlanan Görevler

**1. Backend: PropertyUnit Model & Migration**
- `rent_price` alanı eklendi (`property_units` tablosu)
- Alembic migration oluşturuldu ve uygulandı
- **Dosya:** `backend/app/models/properties.py`

**2. Backend: Unit Update Endpoint**
- `GET /properties/{id}/units/{unit_id}` — birim detayı
- `PATCH /properties/{id}/units/{unit_id}` — birim güncelleme (kira, aidat, kat, kapı)
- **Dosya:** `backend/app/api/endpoints/properties.py`

**3. Backend: Tenant CRUD Endpoint'leri**
- `GET /tenants/` — tüm kiracıları listele
- `POST /tenants/` — yeni kiracı oluştur
- `PATCH /tenants/{id}` — kiracı güncelle
- `POST /tenants/{id}/deactivate` — kiracı pasifleştir (sözleşme feshi)
- `GET /tenants/{id}` — kiracı detay
- **Dosya:** `backend/app/api/endpoints/tenants.py`

**4. Backend: Landlord CRUD Endpoint'leri**
- `GET /tenants/landlords` — tüm ev sahiplerini listele
- `POST /tenants/landlords` — yeni ev sahibi oluştur
- `GET /tenants/landlords/{id}` — ev sahibi detay
- **Dosya:** `backend/app/api/endpoints/tenants.py`

**5. Backend: Yeni Şemalar**
- `backend/app/schemas/tenants.py` — Tenant ve Landlord şemaları

**6. Frontend: Daire Detay Ekranı**
- `GET /properties/{id}/units/{unit_id}` → detay gösterimi
- `PATCH` → kira/ aidat/ kat/ kapı güncelleme
- PRD §4.1.3 uyumlu tasarım
- **Dosya:** `frontend/lib/features/agent/screens/unit_detail_screen.dart`

**7. Frontend: Mülk Detay (Birim Listesi) Ekranı**
- Property detay → birimlerin grid görünümü
- Her birime tıklayınca Daire Detay ekranına geçiş
- **Dosya:** `frontend/lib/features/agent/screens/property_detail_screen.dart`

**8. Frontend: Kiracı/Ev Sahibi Yönetim Ekranı**
- Tab bazlı (Kiracılar / Ev Sahipleri) liste
- Yeni kiracı/ev sahibi oluşturma formu
- Davet linki oluşturma (WhatsApp için)
- Kiracı pasifleştirme (sözleşme feshi)
- PRD §4.1.4 uyumlu
- **Dosya:** `frontend/lib/features/agent/screens/tenants_management_screen.dart`

**9. Frontend: Navigation Entegrasyonu**
- `properties_tab.dart` → bina kartı tıklanınca `PropertyDetailScreen`'e git
- `unit_detail_screen.dart` → Kiracı Ata butonu → `TenantsManagementScreen`'e git

#### 🔄 Sonraki Adımlar

- Mali Rapor Ekranı (§4.1.6) — Backend + Frontend
- Chat Merkezi (§4.1.8) — WebSocket + Frontend UI
- Bina Operasyonları (§4.1.9) — Backend + Frontend

---

### 13 Nisan 2026 — §4.1.10 BI/Analytics — "Intelligence Vault" Premium Redesign

#### ✅ Tamamlanan Görevler

**1. Frontend: bi_analytics_screen.dart — §4.1.10 Kapsamlı Yeniden Tasarım**
- **§A — Portföy Performansı:**
  - Anlık Doluluk Donut Chart (glow effect, 00D9FF accent)
  - Doluluk Trendi — 12 aylık çizgi grafik (GradientAreaFill, curved)
  - Boş Daire Yaşlandırma kartı (60+ gün = kırmızı urgency, 30+ = turuncu)
  - Mülk bazlı doluluk listesi (renk kodlu % badge)
  - Mini KPI kartları grid (toplam mülk/daire/doluluk/boş)
- **§B — Kiracı Sirkülasyonu:**
  - KPI chips: Aktif Kiracı + Ortalama Kalış + Churn Rate
  - Aylık Giriş/Çıkış Bar Chart — dokunmatik tooltip (yeşil=kırmızı)
- **§C — Yıllık Finansal Rapor:**
  - Cari Yıl / Geçen Yıl karşılaştırmalı özet kartları
  - Aylık Gelir/Gider çift bar chart (son 12 ay, dokunmatik tooltip)
  - Net Kar Marjı Trendi — çizgi grafik (amber accent)
  - Kategori Bazlı Gider Dağılımı — çoklu çizgi+area (Tamirat/Fatura/Diğer)
- **§D — Tahsilat Performansı:**
  - 4 dinamik KPI kart: Tahsilat Oranı + Ortalama Gecikme + Zamanında Ödeme + Bekleyen
  - Tahsilat Oranı Trendi — çizgi grafik + "Bu Ay: ₺X / ₺Y" badge
- **§E — Dışa Aktarım:**
  - 📥 PDF Rapor İndir (logo + tarih + çok sayfa, `pdf: ^3.11.1`)
  - 📊 Excel Detay Çıktısı (sheet formatında, `excel: ^4.0.6`)
  - Her iki export da `share_plus` ile sistem paylaşım diyalogu
- **PRD Ref:** §4.1.10-A/B/C/D/E section badge'leri + § kodu
- **Tarih Aralığı Seçici:** Bu Ay / Son 3 Ay / Son 6 Ay / Bu Yıl / Geçen Yıl
- **Tema:** "Intelligence Vault" — ultra koyu (#090910) arka plan, 00D9FF/krom accent, amber/chrom aksanlar, glass morphism kartlar, glow shadow effects, staggered fade animasyonları
- **Dosya:** `frontend/lib/features/agent/screens/bi_analytics_screen.dart`

**2. pubspec.yaml — pdf paketi eklendi**
- `pdf: ^3.11.1` bağımlılığı eklendi
- **Dosya:** `frontend/pubspec.yaml`

**3. Flutter Analyze: 0 Errors**

**4. PRD §4.1.10 Uyumluluğu**
- ✅ A: Anlık Doluluk Donut + Doluluk Trendi Çizgi Grafik + Boş Daire Yaşlandırma
- ✅ B: Aylık Giriş/Çıkış Bar + Ortalama Kalış Süresi + Sirkülasyon Oranı
- ✅ C: Gelir/Gider Yıl Karşılaştırma + Kategori Bazlı Gider Trend + Net Kâr Marjı
- ✅ D: Zamanında Ödeme Oranı + Ortalama Gecikme + Tahsilat Başarı Oranı
- ✅ E: PDF Rapor İndir + Excel Detay Çıktısı + Tarih Aralığı Seçici
- ✅ §PRD Ref: Section badge kodları

---

### 13 Nisan 2026 — §4.2.1 Kiracı Ana Sayfa — "Hearth Sanctuary" Premium Redesign

#### ✅ Tamamlanan Görevler

**1. Frontend: tenant_home_tab.dart — §4.2.1 Kapsamlı Yeniden Tasarım**

- **§A — Cari Dönem Borç Hero Card:**
  - Gradient arka plan: yeşil (#7AB892, ₺0 borç) ↔ kırmızı (#E27D7D, borçlu)
  - ₺50.000+ örnek tutar bold 38px display
  - Countdown badge: "X gün içinde öde" (daysLeft hesaplaması)
  - Kira/Aidat breakdown pills (rentDue + duesDue, %70/%30)
  - Yaklaşan ödeme takvimi listesi (PaymentScheduleItem'ler)
  - Son ödeme tarihi info chip
  - `nextDue` nullable — boşta çıkmaz

- **§B — Son İşlemler (Geçmiş Hareketler):**
  - `tenantTransactionsProvider` üzerinden API'den gelen TransactionItem'lar
  - Her kart: kategori chip, ₺tutar, tarih, "Ödendi" (yeşil) / "Bekliyor" (amber) badge
  - 3D tilt + staggered entrance animasyonu (TweenAnimationBuilder, 50ms stagger)
  - Pull-to-refresh (RefreshIndicator)

- **Tema:** "Hearth Sanctuary" — sıcak koyu (#0F0D0B arka plan), #E8A87C amber, #7AB892 sage green, #E27D7D coral, glass morphism kartlar, ısı gradient glow efektleri, staggered fade animasyonları

- **Dosya:** `frontend/lib/features/tenant/tabs/tenant_home_tab.dart`

**2. Type Fix: `_fmt` double → int**

- `totalDue` double iken `_fmt()` int bekliyor — `.round()` eklendi
- Kullanılmayan import'lar temizlendi (`flutter_riverpod/legacy.dart`, `colors.dart`)
- **Dosya:** `frontend/lib/features/tenant/tabs/tenant_home_tab.dart`

**3. Flutter Analyze: 0 Errors**

- `flutter analyze` → sadece 1 info (super parameter önerisi), 0 error

**4. PRD §4.2.1 Uyumluluğu**

- ✅ §A: Cari dönem borç hero card + gradient + countdown badge + kira/aidat breakdown
- ✅ §B: Son işlemler listesi + status badge + tarih + pull-to-refresh
- ✅ Tema: "Hearth Sanctuary" warm premium dark

---

### 13 Nisan 2026 — §4.2.2 Destek Merkezi — "Workbench Warmth" Premium Redesign

#### ✅ Tamamlanan Görevler

**1. Backend: Tenant Ticket API Endpoints**
- `POST /tenants/me/tickets` — Yeni bilet oluştur (kiracı → otomatik birim bağlantısı)
- `GET /tenants/me/tickets` — Kiracının kendi biletlerini listele (birim bazlı RLS izolasyonu)
- `GET /tenants/me/tickets/{ticket_id}` — Bilet detayı + zaman tüneli
- `POST /tenants/me/tickets/{ticket_id}/reply` — Kiracının yanıt göndermesi
- Yeni şemalar: `TenantTicketCreate`, `TenantTicketResponse`, `TenantTicketMessageResponse`
- **Dosya:** `backend/app/api/endpoints/tenants.py`, `backend/app/schemas/tenants.py`

**2. Frontend: tenant_provider.dart — TenantSupportNotifier**
- `TenantSupportTicket` modeli: `fromJson`, status enum parsing, messages list
- `TenantTicketMessage` modeli
- `TenantSupportNotifier`: `fetchTickets`, `createTicket`, `fetchTicketDetail`, `replyToTicket`
- `tenantSupportProvider` StateNotifierProvider
- **Dosya:** `frontend/lib/features/tenant/providers/tenant_provider.dart`

**3. Frontend: tenant_support_tab.dart — §4.2.2 Kapsamlı Yeniden Tasarım**

- **§A — Yeni Bilet Formu (BottomSheet):**
  - Başlık + detaylı açıklama alanları
  - §4.2.2-B: Fotoğraf kanıtı — `file_picker` ile kamera/galeri seçimi
  - Tarih/Saat timestamp overlay'i fotoğraf üzerinde (📅 13/04/2026 14:30 format)
  - `MultipartFile` + `FormData` ile API'ye medya yükleme
  - Gönder butonu + loading state

- **§C — Durum Takibi + Zaman Tüneli (BottomSheet):**
  - `Açık 🔴` / `İşlemde 🟠` / `Çözüldü 🟢` / `Kapandı ⚪` renk kodlu status chips + ikonlar
  - Her bilet kartı: priority badge, konum bilgisi, son mesaj önizleme, tarih, mesaj sayısı
  - Timeline görünümü: agent vs kiracı balonları (amber = ofis, koyu = kiracı)
  - Agent: "Emlak Ofisi" etiketi + destek ikonu avatar; Kiracı: kişisel avatar
  - Alternating alignment (agent sol, kiracı sağ) — WhatsApp tarzı sohbet
  - Smooth slide-in animasyonları (index bazlı stagger)
  - Canlı yanıt gönderme + otomatik liste yenileme

- **Tema:** "Workbench Warmth" — sıcak koyu (#141210), amber (#D4893F) + sage (#7AB892) + coral (#E27D7D), zanaatkar/tesisat hissi, glass card efektleri, staggered entrance animasyonları
- **Dosya:** `frontend/lib/features/tenant/tabs/tenant_support_tab.dart`

**4. Flutter Analyze: 0 Errors**
- `flutter analyze` → 360 infos/warnings, 0 error

**5. PRD §4.2.2 Uyumluluğu**
- ✅ §A: Yeni talep formu + başlık/açıklama
- ✅ §B: Fotoğraf kanıtı + timestamp overlay + galeri/kamera seçimi + API upload
- ✅ §C: Status takibi (Açık/İşlemde/Çözüldü) + zaman tüneli + agent yanıtları
- ✅ Temiz, sade, sıcak premium dark tema

---

### 13 Nisan 2026 — §4.2.3 Belgelerim — "Archival Navy" Premium Redesign

#### ✅ Tamamlanan Görevler

**1. Backend: Tenant Documents Endpoint**
- `GET /tenants/me/documents` — Kira Sözleşmesi + tüm belgeleri döner
- Şema: `TenantDocumentItem` (name, doc_type, url, uploaded_at)
- Şema: `TenantDocumentsResponse` (contract_document_url + documents list)
- **Dosya:** `backend/app/api/endpoints/tenants.py`, `backend/app/schemas/tenants.py`

**2. Frontend: tenant_provider.dart — Tenant Documents Provider**

- `TenantDocument` modeli: `fromJson`, `docType`, `colorValue`, `iconName`
- `TenantDocumentsPayload` modeli
- `tenantDocumentsProvider` FutureProvider — `/tenants/me/documents` API'si
- **Dosya:** `frontend/lib/features/tenant/providers/tenant_provider.dart`

**3. Frontend: tenant_documents_tab.dart — §4.2.3 Kapsamlı Yeniden Tasarım**

- **API Entegrasyonu:** Gerçek endpoint'ten gelen belgeler (Kira Sözleşmesi, Demirbaş Tutanağı, Aidat Planı)
- **Salt-okunur rozet:** Sağ üstte kilit ikonu ile "Salt Okunur" etiketi
- **Her belge kartı:** Tip ikonu (article/table_chart/inventory), renk kodlu chip (Mavi=contract, Yeşil=handover, Amber=aidat, Mor=eviction), PDF badge, görüntüle butonu + indir butonu
- **url_launcher:** `LaunchMode.externalApplication` ile PDF/dışarıda açma
- **Shimmer yükleme animasyonu:** `AnimatedBuilder` + `SingleTickerProviderStateMixin`, 1200ms döngü
- **Boş durum:** Klasör ikonu + "Henüz belgeniz yok" mesajı
- **Tema:** "Archival Navy" — koyu lacivert (#0C1426), cyan accent (#00B4D8), mimari/plan hissi
- **Dosya:** `frontend/lib/features/tenant/tabs/tenant_documents_tab.dart`

**4. Flutter Analyze: 0 Errors**

**5. PRD §4.2.3 Uyumluluğu**

- ✅ Salt okunur belge listesi
- ✅ Görüntüle + İndir butonları
- ✅ PDF badge, tip rengi kodlaması
- ✅ Shimmer loading, boş durum

---

### 13 Nisan 2026 — §4.2.4 Bina Operasyonları — "Transparency Ledger" Premium Redesign

#### ✅ Tamamlanan Görevler

**1. Frontend: tenant_building_ops_tab.dart — §4.2.4 Kapsamlı Yeniden Tasarım**

- **Mevcut API kullanımı:** `tenantBuildingLogsProvider` üzerinden gerçek veri
- **10 kategori filtresi:** Tümü / Temizlik / Tamirat / Asansör / Tesisat / Elektrik / Boya / Bahçe / Güvenlik / Diğer — yatay kaydırılabilir chip'ler, aktif state animasyonu
- **Özet kartları:** Toplam Harcama (kırmızı) + Kayıtlı İşlem sayısı (teal) — staggered fade-in
- **Dikey timeline görünümü:** Sol tarafta nokta+çizgi timeline, sağda kartlar, son kayıtta çizgi kesilir
- **Her kayıt kartı:** Kategori rengiyle dot glow efekti, ikon, başlık, tarih, açıklama (3 satır max), ₺tutar badge (coral)
- **Shimmer yükleme:** Timeline skeleton
- **Boş durum:** Tümü + kategori bazlı ayrı mesajlar
- **Tema:** "Transparency Ledger" — gece mavisi (#0F1823), teal accent (#14B8A6), blueprint/hesap defteri estetiği
- **Dosya:** `frontend/lib/features/tenant/tabs/tenant_building_ops_tab.dart`

**2. Flutter Analyze: 0 Errors**

**3. PRD §4.2.4 Uyumluluğu**

- ✅ Salt okunur kronolojik zaman akışı
- ✅ Sadece kendi apartmana ait işlemler
- ✅ Fatura tutarları şeffaf gösterimi
- ✅ Kategori filtresi
- ✅ Timeline görünümü

---

### 13 Nisan 2026 — §4.2.5 İletişim ve Sohbet — "Crystal Chat" Premium Redesign

#### ✅ Tamamlanan Görevler

**1. Frontend: tenant_chat_tab.dart — §4.2.5 Kapsamlı Yeniden Tasarım**

- **Konuşma Listesi (WhatsApp tarzı):**
  - Konuşma başlıkları: mülk adı, son mesaj önizleme, zaman damgası, okunmamış mesaj sayacı (kırmızı badge)
  - Okunmuş/konuşulmuş konuşmalar sessiz renk tonlarında, okunmamış olanlar accent ile vurgulu
  - Konuşma seçildiğinde slide-in animasyonu ile chat screen'e geçiş
  - Boş durum: "Sohbete Başla" butonu ile direkt konuşma açma

- **Chat Screen — iMessage tarzı:**
  - Header: Geri butonu, office avatar, "Çevrimiçi" durumu, telefon ikonu
  - Mesaj balonları: Yeşil (kullanıcı, sağ hizalı) / Gri (ofis, sol hizalı)
  - Okundu bilgisi: `done_all_rounded` ikonu (yeşil = iletildi, mavi = görüldü)
  - Tarih ayırıcıları: "Bugün" / "Dün" / "13 Nis" formatında ince çizgiler ile
  - Pull-to-refresh: `RefreshIndicator` ile mesajları yenileme

- **Spring Animations:**
  - Konuşma listesi: `SlideTransition` + `_springFast` (easeOutBack) — staggered 50ms delay
  - Mesaj balonları: `_SpringCurve` (critically damped spring approximation) — her mesaj için ayrı AnimationController, 500ms, yatay kayma + fade
  - Send butonu: `_SpringButton` ile 0.88→1.0 scale press effect
  - Input açılma: `ScaleTransition` + bounce (elasticOut)
  - Attachment picker: `AnimatedContainer` + `AnimatedOpacity` 280ms
  - Typing dots: 3 nokta wave animasyonu (offset + opacity)

- **Medya Gönderme (§4.2.5-B):**
  - Attachment picker: Kamera / Galeri / Belge seçenekleri
  - `file_picker` ile platform uyumlu dosya seçimi (image, media, pdf/doc)
  - Seçilen dosya önizlemesi: Resim ise thumbnail, doküman ise dosya ikonu + isim
  - `MultipartFile` + `FormData` ile `/media/upload` API'sine yükleme
  - Gönderim sırasında spinner animasyonu
  - Gönderim sonrası otomatik scroll-to-bottom (340ms easeOutCubic)

- **Performans:**
  - Her mesaj balonu için ayrı AnimationController — gerektiğinde oluşturulur, `_bubbleControllers` Map'inde tutulur, dispose edilir
  - `BouncingScrollPhysics` tüm scrollable alanlarda — native his
  - `_isOwnMessage` backend user_id karşılaştırması ile doğru balon rengi
  - `mounted` kontrolleri ile memory leak önleme

- **Tema:** "Crystal Chat" — iMessage/WhatsApp hibriti, (#F0F2F5) açık gri arka plan, (#00A884) yeşil accent, beyaz kartlar, glassmorphism shadow'lar

- **Dosya:** `frontend/lib/features/tenant/tabs/tenant_chat_tab.dart`

**2. Flutter Analyze: 0 Errors**

**3. PRD §4.2.5 Uyumluluğu**

- ✅ WhatsApp tarzı konuşma listesi
- ✅ Kurumsal "Ofis Sistemi"ne mesaj gönderme
- ✅ Fotoğraf ve belge ekleme (kamera/galeri/dosya)
- ✅ Spring physics mesaj animasyonları
- ✅ Okundu bilgisi, tarih ayırıcıları, pull-to-refresh

---

### 13 Nisan 2026 — §4.2.6 Yeni Ev Keşfi — "Atlas" Editorial Magazine Redesign

#### ✅ Tamamlanan Görevler

**1. Frontend: tenant_explore_tab.dart — §4.2.6 Kapsamlı Yeniden Tasarım**

-- **Tema: "Atlas" — Editorial Luxury Real Estate Magazine:**
  - Warm cream arka plan (#FAF8F5), forest green (#1B4332), warm gold (#C9963F)
  - Premium serif/grotesque tipografi Kombinasyonu
  - Geometrik gradient placeholder görsel yerleri (gerçek API görselleri için hazır)

-- **Arama ve Filtreleme (§4.2.6):**
  - Animated search bar — focus'ta genişleyen animasyon
  - 7 oda tipi filtresi: Stüdyo / 1+0 / 1+1 / 2+1 / 3+1 / 4+1 / 5+2
  - Fiyat aralığı RangeSlider (0–100.000₺)
  - 6 özellik multi-select: Balkon / Otopark / Eşyalı / Asansör / Merkezi / Güvenlik
  - AnimatedContainer + AnimatedOpacity ile filter panel açılır animasyonu (420ms easeOutCubic)
  - Temizle + Uygula butonları

-- **Mülk Kartları — Parallax Scroll + Spring Animasyonları:**
  - Her karttaki görsel parallax efekti: scroll pozisyonuna göre yatay kayma
  - Damped spring entrance: `_DampedSpring` custom curve (critically damped: c1=1.70158, c3=2.70158)
  - Her kartan 50ms staggered delay ile sıralı açılış
  - Kartın solunda kategoriyi gösteren renkli pill (Kiralık / Satılık / Yeni Proje)
  - Fiyat, oda tipi, m², lokasyon badge'leri

-- **Mülk Detay Bottom Sheet:**
  - Hero parallax görsel (daha güçlü parallax efekti)
  - Genişletilmiş özellik listesi, spec grid (oda, m², bina yaşı, kat)
  - Harita placeholder + "Haritada Göster" butonu
  - Kiralık: aylık fiyat; Satılık: toplam fiyat + m² başına fiyat
  - "Bilgi Al" CTA butonu

-- **Boş Durum ve Shimmer:**
  - API'den boş sonuç gelirse: Editoryal "Sonuç Bulunamadı" illüstrasyonu
  - Shimmer skeleton: gradient shimmer kartlar (1200ms loop)

**2. Flutter Analyze: 0 Errors**

**3. PRD §4.2.6 Uyumluluğu**

- ✅ Editorial magazine layout — premium property showcase
- ✅ Parallax scroll effect on property cards
- ✅ Spring physics entrance animations (staggered, damped)
- ✅ Oda tipi + fiyat aralığı + özellik filtreleri
- ✅ Property detail bottom sheet with hero parallax
- ✅ "Bilgi Al" butonu → chat tab'a geçiş + mülk hakkında otomatik mesaj hazırlama (§4.2.6 PRD gereksinimi)
- ✅ Salt okunur, şık ve kolay kullanımlı arayüz

**4. Bug Fixes & Backend Improvements — 13 Nisan 2026**

-- **§4.2.5 Chat — Endpoint Düzeltmeleri:**
  - `tenantConversationsProvider`: `/chat/conversations` → `/tenants/me/conversations` (kiracıya özel endpoint)
  - `tenantChatHistoryProvider`: `/chat/history/$id` → `/tenants/me/conversations/$id/messages`
  - `ChatConversation` modeline `property_id` eklendi (mülk bazlı sohbet takibi için)
  - Backend: `/tenants/me/conversations`, `/tenants/me/conversations/{id}/messages` yeni endpointler
  - `SendMessageParams`'a `propertyId` eklendi (yeni sohbet başlatma desteği)

-- **§4.2.6 Explore — Endpoint Düzeltme:**
  - `tenantVacantUnitsProvider`: `/landlord/vacant-units` → `/tenants/me/vacant-units` (kiracının kendi birimi hariç)
  - Backend: `/tenants/me/vacant-units` yeni endpoint (RLS benzeri filtreleme ile)

-- **§4.2.6 "Bilgi Al" — Chat Entegrasyonu:**
  - `ChatLaunchContext` + `ChatLaunchNotifier` state eklendi (provider)
  - Explore tab'da "Bu eve de bakabilir miyiz?" butonu → chat tab'a geçiş + otomatik mesaj
  - `TenantChatTab`'a `onNavigateToTab` callback'i eklendi
  - `_ChatScreen`'e `propertyId` + `initialMessage` parametreleri eklendi

-- **Backend Migration:**
  - `a3f8c2b1d704_add_property_id_to_chat_conversations.py` — ChatConversation'a property_id sütunu

---

### 11 Nisan 2026 (Gece) — BI/Analytics Dashboard (§4.1.10)

#### ✅ Tamamlanan Görevler

**1. Backend: Analytics Endpoint'leri + Schema**
- `GET /analytics/bi-dashboard` — Tüm BI metriklerini birleştiren ana endpoint
- `GET /analytics/bi/portfolio` — Portföy performansı (doluluk, boş daire yaşlandırma)
- `GET /analytics/bi/tenant-churn` — Kiracı sirkülasyon analizi (churn rate, ortalama kalış süresi)
- `GET /analytics/bi/financial` — Yıllık finansal karşılaştırmalı rapor
- `GET /analytics/bi/collection` — Tahsilat performans KPI'ları
- `BIAnalyticsDashboard`, `PortfolioPerformanceResponse`, `TenantChurnResponse`, `FinancialAnnualResponse`, `CollectionPerformanceResponse` Pydantic şemaları
- **Dosya:** `backend/app/schemas/analytics.py`, `backend/app/api/endpoints/analytics.py`

**2. Backend: API Router Entegrasyonu**
- `analytics` router'ı `api_router`'a eklendi (`prefix="/analytics"`)
- **Dosya:** `backend/app/api/api.py`

**3. Frontend: BIAnalyticsScreen**
- 4 ana sekme: Portföy (donut + list), Kiracı Sirkülasyonu (bar chart), Finansal Yıllık (bar chart), Tahsilat (line chart)
- `BIAnalyticsNotifier` StateNotifier — `GET /analytics/bi-dashboard`
- Donut chart, bar chart (gelir/gider), line chart (tahsilat oranı trendi)
- Boş daire yaşlandırma listesi (60+ gün kırmızı uyarı)
- Kiracı giriş/çıkış bar chart (yeşil/kırmızı)
- **Dosya:** `frontend/lib/features/agent/screens/bi_analytics_screen.dart`

**4. Frontend: home_tab.dart Navigation**
- Sağ üst köşeye BI Analytics ikonu (analytics_rounded)
- Tıklanınca `BIAnalyticsScreen`'e geçiş
- **Dosya:** `frontend/lib/features/agent/tabs/home_tab.dart`

**5. Backend Verify**
- `python -c "from app.main import app; print('OK')"` → ✅
- Flutter analyze: 0 errors

**6. project_status.md Güncelleme**
- 4.1.10 BI/Analytics: 🔴 → ✅ Tamamlandı
- Genel ilerleme: ~82% → ~85%
- Backend API: 10/11 → 11/11 modül ✅

---

### 8 Nisan 2026 — Gece Oturumu
- **Rebrand:** Emlog → Emlakdefter (tüm dosyalarda)
- Docker yeniden oluşturuldu (`emlakdefter_db` + `emlakdefter_redis`)
- Alembic migration uygulandı
- FlutterFire CLI: `firebase_options.dart` + `google-services.json`
- `main.dart` → `DefaultFirebaseOptions.currentPlatform` aktif
- Firebase Admin SDK yeni anahtar → `.env` güncellendi
- Git güvenlik: Eski SDK anahtarı `filter-branch` ile silindi, force push

---

### 11 Nisan 2026 (Akşam) — Tenant Chat API + Yeni Ev Keşfi API Entegrasyonu

#### ✅ Tamamlanan Görevler

**1. Backend: Tenant Chat Mesaj Gönderme Endpoint**
- `POST /chat/messages` — yeni mesaj gönder + WebSocket broadcast
- `MessageCreate` Pydantic schema eklendi
- **Dosya:** `backend/app/api/endpoints/chat.py`, `backend/app/schemas/chat.py`

**2. Backend: ChatConversation Schema — client_name ve diğer alanlar**
- `ChatConversationResponse`: `client_name`, `client_role`, `property_name`, `last_message`, `last_message_at` alanları zaten mevcut

**3. Frontend: Tenant Chat Provider — API Entegrasyonu**
- `ConversationItem` modeli: sohbet listesi için
- `ChatMessageItem` modeli: mesaj geçmişi için
- `SendMessageParams` class: mesaj gönderme parametreleri
- `tenantConversationsProvider` → `GET /chat/conversations`
- `tenantChatHistoryProvider(conversationId)` → `GET /chat/history/{id}`
- `tenantSendMessageProvider(params)` → `POST /chat/messages`
- **Dosya:** `frontend/lib/features/tenant/providers/tenant_provider.dart`

**4. Frontend: tenant_chat_tab.dart — Mock → API**
- `_loadConversation()`: konuşma ID'si alınır, history çekilir
- `_sendMessage()`: REST API üzerinden mesaj gönderilir, animasyonlu ekleme
- Boş durum, yükleme spinner'ı, hata yönetimi
- `withOpacity` → `withValues(alpha:)` güncellemesi
- **Dosya:** `frontend/lib/features/tenant/tabs/tenant_chat_tab.dart`

**5. Frontend: Finance Tab — `withOpacity` Deprecation Fix**
- Tüm `.withOpacity(...)` → `.withValues(alpha: ...)` olarak güncellendi
- **Dosya:** `frontend/lib/features/agent/tabs/finance_tab.dart`

**6. Backend Verify**
- `python -c "from app.main import app; print('app OK')"` → ✅
- Flutter analyze: 0 errors

**7. project_status.md Güncelleme**
- Tenant Chat: Mock → ✅ API
- Genel ilerleme: ~76% → ~78%
- Kiracı Paneli: %100 ✅ (7/7 ekran API'ye bağlı)
- Orta öncelik: Kiracı — Chat + Yeni Ev Keşfi → ✅ Tamamlandı
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

### 14 Nisan 2026 — firebase_uid Tümleştirmesi

- **Backend:** `User.firebase_uid` sütunu + Alembic migration (`f0a1b2c3d4e5`)
- **Backend:** `deps.py` → kullanıcı lookup `firebase_uid` ile (geriye uyumlu `phone_number` fallback)
- **Backend:** `auth.py` → `/login` başında `firebase_uid` kaydetme + backfill
- **Backend:** `DEV_MODE=false` → `.env` güncellendi (artık gerçek Firebase token gerekli)
- **Flutter:** Firebase config tam — `google-services.json` (Android) + `firebase_options.dart` (web/iOS/Android)
- **Flutter:** iOS `GoogleService-Info.plist` eksik — manual eklenebilir (Firebase Console'dan indirilebilir)
- **Test:** Backend import + Firebase Admin SDK başarıyla başlatılıyor
- **Basit Auth:** `verify_access_token()` → `firebase.py`'de basit JWT doğrulama, `deps.py`'de Firebase öncesi kontrol
- **Test:** Email/şifre ile kayıt + giriş + korumalı endpoint (`/auth/me`, `/properties`) ✅
- **Port uyumu:** `api_client.dart` port `8004` → `8001` (start.bat ile uyumlu)
- **Telefon ile giriş:** `SimpleLoginScreen`'e "Telefon ile giriş yap" butonu eklendi → `/phone` rotası → `PhoneLoginScreen` → OTP ekranı

---

## Sistem Durumu (Anlık)

| Bileşen | Durum |
|---|---|
| PostgreSQL (Docker) | ✅ `emlakdefter_db` — port 5433 |
| Redis (Docker) | ✅ `emlakdefter_redis` — port 6379 |
| Backend (FastAPI) | ✅ `uvicorn app.main:app` — port 8000 |
| Firebase Auth | ✅ Admin SDK bağlı |
| Firebase Phone Auth | ✅ Console'da aktif edildi |
| Git | ✅ `github.com/kocakburhan/emlakdefter` |

---

## 🚀 VPS Deployment — Canlı Yayın Durumu (11 Nisan 2026 Gece)

### Sunucu Bilgileri
- **Host:** `root@89.167.15.127`
- **Hostname:** `ubuntu-16gb-hel1-2`
- **Location:** Helsinki (hel1)
- **VPS:** Hetzner CX43 (8 çekirdek, 16 GB RAM, 160 GB SSD)

### Tamamlanan VPS Kurulum Adımları
- [x] Docker + docker-compose kuruldu
- [x] PostgreSQL 16 + Redis 7 container'ları çalışıyor (`docker ps` ✅)
- [x] Git clone yapıldı (`/opt/emlakdefter/`)
- [x] `.env` dosyası oluşturuldu (Hetzner credentials, Gemini, FCM hepsi içinde)
- [x] Python 3.12 venv oluşturuldu (`/opt/emlakdefter/backend/venv`)
- [x] `pip install -r requirements.txt` tamamlandı (tüm paketler ✅)
- [x] `psycopg2` ve `asyncpg` import test edildi ✅

### 🔴 Kalan Sorunlar (Bu Oturumda Çözülemedi)

**1. PostgreSQL port uyumsuzluğu:**
- Docker container port: **5432** (published)
- `.env` DATABASE_URL: **5433** (yanlış)
- Ayrıca host olarak `db` service name gerekiyor, `127.0.0.1` değil
- **Düzeltme:** `.env` içinde `localhost:5433` → `db:5432`

**2. Alembic migration çalışmadı:**
- Hata: `connection to server at "127.0.0.1", port 5433 failed: Connection refused`
- Neden: .env port hatası ve host hatası

**3. Uvicorn başlatılamadı:**
- `nohup uvicorn ...` çalışıp anında Exit 127 verdi
- Muhtemelen venv dışından çalıştırılmaya çalışıldı

### Yapılacak Adımlar (Sırayla)

```bash
# 1. .env düzelt (sunucuda)
cd /opt/emlakdefter/backend
sed -i 's/localhost:5433/db:5432/g' .env
sed -i 's/127.0.0.1:5433/db:5432/g' .env

# 2. Environment'i kaynakla ve alembic çalıştır
source venv/bin/activate
export $(grep -v '^#' .env | xargs)
alembic upgrade head

# 3. Uvicorn başlat
nohup uvicorn app.main:app --host 0.0.0.0 --port 8000 > uvicorn.log 2>&1 &
sleep 3
curl http://localhost:8000/api/v1/

# 4. Firewall aç (HTTP + HTTPS)
ufw allow 80
ufw allow 443
ufw allow 8000

# 5. Backend erişilebilir mi test et
curl http://89.167.15.127:8000/api/v1/
```

### Beklenen Sonuç
- API: `http://89.167.15.127:8000/api/v1/` → JSON yanıt
- PostgreSQL bağlantısı başarılı
- Tüm endpoint'ler erişilebilir

---

### Öncelik Sıralaması (Sonraki Oturum İçin)

| # | Görev | Öncelik |
|---|---|---|
| 1 | VPS .env düzelt → alembic migration çalıştır | 🔴 Acil |
| 2 | Uvicorn başlat + public IP'den test | 🔴 Acil |
| 3 | Backend'i systemd service olarak ayarla (auto-start) | 🟡 Önemli |
| 4 | Frontend API base URL'sini VPS'ye yönlendir | 🟡 Önemli |
| 5 | Chat WebSocket canlı mesaj (FAZ 5 tamamla) | 🟡 Önemli |
| 6 | Firebase Phone Auth Console'da aktif et | 🟡 Önemli |
| 7 | Domain bağla (emlakdefter.com veya subdomain) | 🔴 Gelecek |

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
        ├── main.dart            # EmlakdefterApp
        ├── core/                # theme, router, network (Dio)
        └── features/
            ├── auth/            # 3 ekran + 1 provider
            ├── agent/           # 4 tab + 4 provider
            └── tenant/          # 3 tab + 1 provider

---

### 11 Nisan 2026 (Akşam) — Tenant API'leri

#### ✅ Tamamlanan Görevler

**1. Backend: Tenant `/me` Endpoint'leri**
- `GET /tenants/me` — Aktif kiracının kendi bilgilerini döner (birim + mülk dahil)
- `GET /tenants/me/finance` — Kiracının finans özeti (borç, yaklaşan takvim, son işlemler)
- `GET /tenants/me/building-logs` — Kiracının kendi sitesindeki bina operasyonları
- `GET /tenants/me/transactions` — Kiracının kendi işlem geçmişi
- **Dosya:** `backend/app/api/endpoints/tenants.py`

**2. Backend: TenantFinanceSummary Schema**
- `current_debt`, `next_due_date`, `next_due_amount`, `upcoming_schedules`, `recent_transactions`
- **Dosya:** `backend/app/schemas/finance.py`

**3. Frontend: tenant_provider.dart — API'ye Bağlantı**
- `TenantInfo.fromJson()` — `/tenants/me` yanıtını parse eder
- `tenantFinanceProvider` — FutureProvider `/tenants/me/finance`
- `tenantBuildingLogsProvider` — FutureProvider `/tenants/me/building-logs`
- **Dosya:** `frontend/lib/features/tenant/providers/tenant_provider.dart`

**4. Frontend: tenant_home_tab.dart — API Entegrasyonu**
- Borç kartı artık API'den gelen `currentDebt` kullanır
- `tenantFinanceProvider` ile reactive güncelleme
- Mock ödeme dialog'u kaldırıldı (gerçek akış yönlendirmesi)
- **Dosya:** `frontend/lib/features/tenant/tabs/tenant_home_tab.dart`

**5. Frontend: tenant_building_ops_tab.dart — API Entegrasyonu**
- `tenantBuildingLogsProvider` ile gerçek bina operasyonları listesi
- Summary kartları API verisinden hesaplanır
- Boş durum kontrolü
- **Dosya:** `frontend/lib/features/tenant/tabs/tenant_building_ops_tab.dart`

**6. Frontend: tenant_finance_tab.dart — API Entegrasyonu**
- İşlem geçmişi: `tenantTransactionsProvider` → `GET /tenants/me/transactions`
- Borç durumu banner'ı: `tenantFinanceProvider` ile ödenmemiş borç gösterimi
- Dropzone (PDF yükleme placeholder) korundu
- Boş durum: "Henüz işlem kaydınız bulunmuyor" mesajı
- **Dosya:** `frontend/lib/features/tenant/tabs/tenant_finance_tab.dart`

**7. Frontend: tenant_explore_tab.dart — API Entegrasyonu**
- `tenantVacantUnitsProvider` → `GET /landlord/vacant-units` (portföy vitrini)
- `VacantUnitItem` model + `fromJson()` parse
- Fiyat aralığı RangeSlider (0–100K) ile filtreleme
- Aramaya göre `property_name` parametresi
- Boş durum kontrolü
- **Dosya:** `frontend/lib/features/tenant/tabs/tenant_explore_tab.dart`

**8. Backend: Chat Message Send Endpoint**
- `POST /chat/messages` — Yeni mesaj gönderme + WebSocket broadcast
- `MessageCreate` Pydantic schema eklendi
- **Dosya:** `backend/app/api/endpoints/chat.py`, `backend/app/schemas/chat.py`

**9. Backend: landlord.py Import Düzeltmeleri**
- `Dict, Any` → `landlord.py` schema import
- `Optional, UUID` → `landlord.py` endpoint import
- **Dosya:** `backend/app/schemas/landlord.py`, `backend/app/api/endpoints/landlord.py`

---

### 13 Nisan 2026 — §4.1.9 Bina Operasyonları — Premium Dark Tema + Kategori Sistemi

#### ✅ Tamamlanan Görevler

**1. Frontend: building_operations_tab.dart — §4.1.9 Kapsamlı Yeniden Tasarım**
- §A) Özet kartları: Toplam Maliyet / Finansa Yansıyan / Bekleyen — animasyonlu giriş
- §A) İşlem kartları: **kategori chip** (Temizlik/Asansör/Elektrik/Su Tesisat/Boya Badana/Güvenlik/Peyzaj/Diğer) + **mülk adı** (propertyName) + başlık + maliyet
- §A) İşlem Künyesi formatı: `[Kategori] Başlık` formatında
- §B) Yeni Operasyon formu: **kategori chip seçimi** + bina seçimi + başlık + açıklama + maliyet + fatura kanıtı placeholder + finansa yansıtma toggle
- §B) Kanıt/Medya (fatura fotoğrafı) ekleme UI placeholder
- §C) **Kategori filtresi** (8 hazır kategori chip'i — Temizlik/Asansör/Elektrik/Su Tesisat/Boya Badana/Güvenlik/Peyzaj/Diğer)
- §C) **Tarih aralığı filtresi** (DateRangePicker ile)
- Bina bazlı filtre + Finans durumu filtreleri zaten mevcut
- Staggered entrance animasyonları (TweenAnimationBuilder, index-based delay)
- Premium dark tema (#0D0D14), category color map, FAB gradient
- **Dosya:** `frontend/lib/features/agent/tabs/building_operations_tab.dart`

**2. Frontend: building_operations_provider.dart — category alanı eklendi**
- `BuildingOperationModel`: `category` alanı eklendi
- `fromJson`: `category` alanı parse ediliyor
- `createOperation`: `category` parametresi eklendi (conditional JSON)
- **Dosya:** `frontend/lib/features/agent/providers/building_operations_provider.dart`

**3. Flutter Analyze: 0 Errors**

**4. PRD §4.1.9 Uyumluluğu**
- ✅ A: İşlem kartlarında **kategori etiketi** + **lokasyon (mülk adı)** gösterimi
- ✅ A: **İşlem Künyesi formatı** — "[Kategori] Başlık" yapısı
- ✅ B: **Hazır kategori seçimi** (Temizlik/Asansör/Elektrik/Su Tesisat/Boya Badana/Güvenlik/Peyzaj/Diğer)
- ✅ B: **Kanıt/Medya (fatura)** ekleme UI placeholder (Hetzner Object Storage hazır)
- ✅ C: **Kategori filtresi** — 8 hazır kategori chip ile
- ✅ C: **Tarih aralığı filtresi** — DateRangePicker ile
- ✅ Staggered entrance animasyonları — TweenAnimationBuilder, index-based offset

---

### 13 Nisan 2026 — §4.1.2 Portföy Yönetimi — Tam Yeniden Tasarım

#### ✅ Tamamlanan Görevler

**1. Backend: Toplu Bildirim Endpoint (§4.1.2-C)**
- `POST /properties/{property_id}/broadcast-notification` — FCM push notification
- Tüm aktif kiracıların FCM token'larına bildirim gönderir
- `title` + `body` Body parametreleri, döndürü: `{success, message, sent_count}`
- **Dosya:** `backend/app/api/endpoints/properties.py`

**2. Backend: Tekil Daire Ekle Endpoint (§4.1.2-C)**
- `POST /properties/{property_id}/units` — Body parametreli (`door_number`, `floor`, `dues_amount`)
- Manuel ekstra birim ekleme (otonom üretim dışı)
- **Dosya:** `backend/app/api/endpoints/properties.py`

**3. Frontend: CreatePropertyBottomSheet — Dinamik Tip Seçimi (§4.1.2-A)**
- `PropertyFormType` enum: apartment, villa, land, commercial
- 4 tip chip seçimi (Apartman/Site, Müstakil Ev, Arsa/Tarla, Dükkan)
- Tip bazlı dinamik alanlar: apartment=floors/units/blocks, villa=rent/dues, land=ada/parsel/imar, commercial=shop count
- "Bina Özellikleri" checklist: asansör, otopark, havuz, güneş enerjisi, güvenlik, bahçe
- BackdropFilter blur + fadeSlide animasyonu
- **Dosya:** `frontend/lib/features/agent/widgets/create_property_bottom_sheet.dart`

**4. Frontend: PropertiesTab — Editorial Dark Tema**
- "PORTFÖY" + "Gayrimenkul Yönetimi" başlık overlay
- Staggered slide+fade header animasyonu
- Property type icon + label mapping (apartment/villa/land/commercial)
- Occupancy % badge (yeşil ≥80, kırmızı <80)
- Mini stats row: Kapı | Kiracı | Boş
- LinearProgressIndicator doluluk çubuğu
- TweenAnimationBuilder staggered card entrance
- Boş durum: CTA "İlk Mülkü Ekle" butonu
- RefreshIndicator pull-to-refresh
- **Dosya:** `frontend/lib/features/agent/tabs/properties_tab.dart`

**5. Frontend: PropertyDetailScreen — Action Bar + Birim Ekle (§4.1.2-C)**
- "Toplu Bildirim" butonu → AlertDialog (başlık + mesaj) → FCM POST
- "Birim Ekle" butonu → inline form (kapı no, kat, aidat, onay)
- 3-column grid unit cards + scale+fade TweenAnimationBuilder
- Renk kodlu border (yeşil=occupied, amber=vacant)
- Pull-to-refresh (AppBar refresh icon)
- **Dosya:** `frontend/lib/features/agent/screens/property_detail_screen.dart`

**6. PRD §4.1.2 Uyumluluğu**
- ✅ A: Dinamik mülk tipi seçimi (4 tip)
- ✅ A: Dinamik alanlar (tipe göre farklı form)
- ✅ B: Otonom Üretim Motoru (zaten çalışıyordu)
- ✅ C: Toplu Bildirim + Tekil Daire Ekle butonları
- ✅ D: Daire Detayına Geçiş (birim kutusu tıklanınca UnitDetailScreen)

**7. Flutter Analyze: 0 Errors**
- `withOpacity` → `withValues(alpha:)` tüm dosyalarda güncellendi
- `unused_catch_stack` → `catch (e)` düzeltildi
- 11 warnings, 406 info (sadece style/info, 0 error)

---

### 13 Nisan 2026 — §4.1.3 Daire Detay Ekranı — Tam Yeniden Tasarım

#### ✅ Tamamlanan Görevler

**1. Backend: PropertyUnit Model — Yeni Alanlar (§4.1.3)**
- `commission_rate` → Float, komisyon oranı % (PRD §4.1.3-A)
- `youtube_video_link` → String, liste dışı video linki (PRD §4.1.3-C)
- **Dosya:** `backend/app/models/properties.py`

**2. Backend: PropertyUnitUpdate + PropertyUnitResponse Schema Güncellemesi (§4.1.3)**
- `PropertyUnitUpdate`: `commission_rate`, `youtube_video_link`, `media_links` eklendi
- `PropertyUnitResponse`: `commission_rate`, `youtube_video_link`, `media_links` eklendi
- **Dosya:** `backend/app/schemas/properties.py`

**3. Frontend: UnitDetailScreen — Premium Dark Editorial Tema**
- §A) FİNANSAL & TEMEL KÜNYE: Kapı/Kat/Kira/Aidat/Komisyon/YouTube alanları
  - Inline edit modu (edit butonu → Kaydet/İptal)
  - Renk kodlu alanlar: success=kira, warning=aidat, accent=komisyon
  - YouTube video linki için dahili önizleme dialog
- §B) ÖZELLİKLER & ETİKETLER: Bina özellikleri chip listesi (asansör/otopark/havuz/güneş/güvenlik/bahçe/balkon/garaj)
  - Feature map: backend `features` JSON'dan dinamik okuma
  - Staggered entrance animasyonları (TweenAnimationBuilder)
- §C) DİJİTAL VARLIKLAR: Fotoğraf galerisi + YouTube dahili oynatıcı
  - Horizontal scrollable media grid
  - Open-in-new dialog ile video önizleme
  - Görsel önizleme dialog (ImagePreview)
- Staggered header fade+slide animasyonları (CurvedAnimation)
- Section badge'ler (A/B/C) ile PRD referansı
- Status card: gradient glow, elastic scale animasyonu, renk kodlu badge
- `withValues(alpha:)` — deprecated `withOpacity` giderildi
- **Dosya:** `frontend/lib/features/agent/screens/unit_detail_screen.dart`

**4. PRD §4.1.3 Uyumluluğu**
- ✅ A: Finansal ve Temel Künye (kapı/kat/kira/aidat/komisyon oranı)
- ✅ B: Özellikler ve Etiketler (bina özellikleri chip listesi)
- ✅ C: Dijital Varlıklar (fotoğraf galerisi + YouTube dahili oynatıcı)

**5. Flutter Analyze: 0 Errors**
- `dart:ui` gereksiz import kaldırıldı
- `unused_catch_stack` → `catch (e)` düzeltildi
- `_mediaFade` unused field kaldırıldı
- 2 info (use_super_parameters), 0 error

---

### 13 Nisan 2026 — §4.1.4 Kiracı & Ev Sahibi Yönetimi — Tam Yeniden Tasarım

#### ✅ Tamamlanan Görevler

**1. Frontend: TenantsManagementScreen — Premium Dark Tema + Staggered Animations**
- §A) PROFİL YÖNETİMİ: Kiracı ve Ev Sahibi listesi + Tab'lar
  - Kiracı → Birim seçimi (Dropdown: Mülk → Birim, 1-to-1 atama)
  - Ev Sahibi → Mülk seçimi (tüm birimler otomatik 1-to-Many atama)
  - Sözleşme Feshi: confirm dialog → `/tenants/{id}/deactivate` → birim "Boş" statüsü
  - Active/Pasif badge, kira bedeli chip, ödeme günü chip
- §B) WHATSAPP DAVET (url_launcher wa.me):
  - `/auth/invite` → invite_url → bottom sheet (Kopyala + WhatsApp butonları)
  - wa.me/?text= encoded message → externalApplication mode
  - Tenant şablonu: "Emlakdefter sistemine kaydınız açılmıştır..."
  - Landlord şablonu: "Değerli mülk sahibimiz..."
- §C) KVKK AYDINLATMA METNİ ONAYI:
  - Checkbox ile zorunlu onay (form submit engellenir)
  - Her iki formda da (Kiracı + Ev Sahibi) KVKK checkbox
  - Onay yoksa form gönderilemez (hata mesajı ile)
- Header: slide+fade CurvedAnimation, TabBar custom styled
- FAB: elasticOut scale animasyonu
- ListView: TweenAnimationBuilder staggered card entrance
- `withValues(alpha:)` — deprecated `withOpacity` giderildi
- **Dosya:** `frontend/lib/features/agent/screens/tenants_management_screen.dart`

**2. Backend: Sözleşme Feshi — Otomatik Birim Durumu Güncellemesi**
- `POST /tenants/{id}/deactivate`: kiracı pasif → birim "vacant" + `vacant_since` set
- `POST /tenants/{id}/upload-contract`: sözleşme PDF URL güncelleme (Hetzner Object Storage)
- Tenant modeli: `contract_document_url` + `documents` (JSON) alanları eklendi
- **Dosya:** `backend/app/api/endpoints/tenants.py`, `backend/app/models/tenants.py`

**3. Frontend: Sözleşme Yükle UI (§4.1.4-A)**
- Kiracı kartında "Sözleşme" chip'i (mavi, description icon) — URL varsa gösterilir
- "Sözleşme" butonu → `_uploadContract()` → backend endpoint hazır
- PDF/DOCX → `/upload/media` → Hetzner → `/tenants/{id}/upload-contract`
- **Dosya:** `frontend/lib/features/agent/screens/tenants_management_screen.dart`

**4. PRD §4.1.4 Uyumluluğu**
- ✅ A: Profil Yönetimi ve Atama Merkezi (Kiracı/Ev Sahibi CRUD)
- ✅ A: Sözleşme Feshi (Offboarding → birim müsait statüsü)
- ✅ A: Sözleşme Upload (PDF/DOCX → Hetzner → contract_document_url)
- ✅ B: Dijital Profil Daveti (WhatsApp url_launcher wa.me)
- ✅ B: Kiracı (1-to-1) ve Ev Sahibi (1-to-Many) ayrı şablonlar
- ✅ C: KVKK Aydınlatma Metni onay checkbox (zorunlu)

**5. Flutter Analyze: 0 Errors**
- 3 info (use_super_parameters, use_build_context_synchronously), 0 error

---

### 13 Nisan 2026 — §4.1.8 Chat Merkezi — İyileştirmeler

#### ✅ Tamamlanan Görevler

**1. Frontend: chat_tab.dart — §4.1.8-A İyileştirmeler**
- Okunmamış rozeti (§4.1.8-A): her sohbet kartında kırmızı badge + sayı (99+ overflow)
- Yeni Sohbet Sheet: Kiracı/Ev Sahibi listesi API'den çekiliyor, sohbet başlatma/devam ettirme
- Arama: kiracı adı ve daire numarasına göre filtreleme
- §4.1.7-D entegrasyonu: Kiracıya Direkt Mesaj → ilgili sohbete yönlendirme
- **Dosya:** `frontend/lib/features/agent/tabs/chat_tab.dart`

**2. Frontend: chat_window_screen.dart — §4.1.8-B/C İyileştirmeler**
- Okundu bilgisi (§4.1.8-B): gönderilen mesajlarda `done_all` ikonu (✓✓)
- Attachment Bar (§4.1.8-C): Fotoğraf ve Belge gönderme seçenekleri (placeholder — Hetzner hazır)
- Görsel iyileştirmeler: gradient avatar, shadow effects
- **Dosya:** `frontend/lib/features/agent/screens/chat_window_screen.dart`

**3. Flutter Analyze: 0 Errors**
- Tüm dosyalarda sadece info/warning seviyesinde

---

### 13 Nisan 2026 — §4.1.7 Destek Yönetimi — Yeniden Tasarım

#### ✅ Tamamlanan Görevler

**1. Frontend: support_tab.dart — §4.1.7-A Kapsamlı Yeniden Tasarım**
- 3 Sekme: Açık Talepler (kırmızı badge) / İşlemde Olanlar (turuncu badge) / Çözülenler (yeşil badge)
- Sekme badge'leri: her sekmedeki talep sayısını gösterir
- TabBarDelegate: NestedScrollView içinde sticky tab bar
- Staggered card entrance animasyonları (TweenAnimationBuilder)
- Boş durumlar: her sekme için özel boş ekran
- Kiracı + daire bilgisi + son mesaj özeti kartlarda
- **Dosya:** `frontend/lib/features/agent/tabs/support_tab.dart`

**2. Frontend: ticket_detail_sheet.dart — §4.1.7-B/C Kapsamlı Detay Ekranı**
- §B) Talep Künyesi: başlık, açılış zamanı, daire/kiracı chip'leri, durum badge'i
- §B) Talep açıklaması (varsa)
- §B) Aksiyon Geçmişi (Timeline): her mesaj için renk kodlu yorum zinciri
- §C) Action Bar: Yanıt Yaz / Giderildi İşaretle / Direkt Mesaj (WhatsApp) / Bina Operasyonu Ekle
- §C) Inline WhatsApp-style chat sheet: mesaj gönderme + tarih-saat etiketleri
- §C) Bina Operasyonu'na ekle → SnackBar aksiyonu
- Premium dark tema (#0F0F18)
- **Dosya:** `frontend/lib/features/agent/widgets/ticket_detail_sheet.dart`

**3. Flutter Analyze: 0 Errors**
- support_tab.dart: No issues found
- ticket_detail_sheet.dart: No issues found

**4. PRD §4.1.7 Uyumluluğu**
- ✅ A: 3 sekme (Açık/İşlemde/Çözüldü) — badge'li
- ✅ B: Talep Detay + Künye (başlık, açılış, daire, kiracı)
- ✅ B: Timeline — renk kodlu mesaj zinciri
- ✅ C: Yanıt Yaz (thread) + anlık bildirim
- ✅ C: Giderildi İşaretle → kapandı bildirimi
- ✅ C: Direkt Mesaj (WhatsApp url_launcher)
- ✅ C: Bina Operasyonlarına Ekle

---

### 13 Nisan 2026 — §4.1.6 Mali Rapor Ekranı — Yeniden Tasarım

#### ✅ Tamamlanan Görevler

**1. Frontend: mali_rapor_screen.dart — §4.1.6 Kapsamlı Yeniden Tasarım**
- §A) Özet kartları: Toplam Gelir (yeşil) + Toplam Gider (kırmızı) + Net Bakiye — TweenAnimationBuilder ile animasyonlu sayaç
- §A) Pasta grafik (kategori dağılımı, dokunmatik etkileşimli) + Bar grafik (12 aylık trend, gelir/gider karşılaştırmalı)
- §B) Yeni İşlem Ekle formu: Gelir/Gider toggle + kategori chip seçimi + "Yeni Kategori Oluştur" + **Mülk Bağlama (Bağlı Kayıt)** + açıklama alanı
- §C) İşlem listesi: Kaynak etiketleri (Finans Ekranı / Bina Operasyonu / Manuel) + Mülk etiketleri — renk kodlu
- §B) Excel Export: Mülk sütunu eklendi
- "Refined Ledger" dark tema: 0D0D14 arka plan, yeşil/kırmızı aksan, staggered entrance animasyonları (her kart 100ms offset ile)
- `property_id` parametresi ile backend'e bağlı kayıt
- **Dosya:** `frontend/lib/features/agent/screens/mali_rapor_screen.dart`

**2. Flutter Analyze: 0 Errors**
- mali_rapor_screen.dart: No issues found

**3. PRD §4.1.6 Uyumluluğu**
- ✅ A: Özet kartları + Gelir/Gider/Net Bakiye + Pasta + Bar grafikler
- ✅ B: Yeni İşlem Ekle (Gelir/Gider toggle, kategori seçimi, Yeni Kategori Oluştur)
- ✅ B: Bağlı Kayıt — Mülk seçimi dropdown ile işlem-mülk bağlama
- ✅ B: Excel Export (📥 butonu, mülk sütunu dahil)
- ✅ C: İşlem kaynağı etiketleri (Finans Ekranı / Bina Operasyonu / Manuel)
- ✅ C: Kronolojik liste (yeşil=kasa giriş, kırmızı=kasa çıkış)

---

### 13 Nisan 2026 — §4.1.5 Finans ve Ödemeler Ekranı — Tam Yeniden Tasarım

#### ✅ Tamamlanan Görevler

**1. Frontend: finance_tab.dart — §4.1.5 Tam Uyumlu 4 Sekme + Action Bar + Warning Banner**
- Action Bar (§A): "Ekstre Yükle" (PDF → Gemini AI) + "Excel Export" butonları
- Warning Banner (§B): AI eşleşemedi uyarısı banner'ı (ödenmemiş transactions için)
- 4 Sekme (§C):
  - **Ödeyenler**: MatchStatus.matched → yeşil onay badge
  - **Bekleyenler**: MatchStatus.pending → "X gün var" countdown + Hatırlat butonu
  - **Gecikenler**: MatchStatus.overdue → "X gün gecikti" kırmızı badge + İhtar + Mesaj butonları
  - **Kısmi Ödeyenler**: MatchStatus.partial → Beklenen/Yatan/Kalan tutar + Devret + Elden Alındı butonları
- Future Notice Banner: Bank API entegrasyonu duyurusu
- Staggered TweenAnimationBuilder entrance animasyonları
- Tab badge'leri ile transaction sayısı
- `_SmallActionButton` ile inline action button'lar
- Premium dark editorial tema
- **Dosya:** `frontend/lib/features/agent/tabs/finance_tab.dart`

**2. Frontend: finance_provider.dart — §4.1.5 Veri Modeli Genişletmesi**
- `MatchStatus`: `pending`, `matched`, `rejected` → `overdue`, `partial` eklendi
- `TransactionModel`: `daysUntilDue`, `overdueDays`, `expectedAmount` alanları eklendi
- `FinanceNotifier`: `sendReminder()`, `sendWarning()`, `markAsReceived()` metotları eklendi
- **Dosya:** `frontend/lib/features/agent/providers/finance_provider.dart`

**3. Flutter Analyze: 0 Errors**
- finance_tab.dart: 0 errors (1 info: use_super_parameters)
- Tüm frontend: info/warning seviyesinde, 0 error

**4. PRD §4.1.5 Uyumluluğu**
- ✅ A: Ekstre Yükle (PDF → Gemini AI) + Excel Export
- ✅ B: Warning Banner (AI eşleşemedi durumu için)
- ✅ C: Ödeyenler sekmesi (matched transactions)
- ✅ C: Bekleyenler sekmesi (pending + countdown + Hatırlat)
- ✅ C: Gecikenler sekmesi (overdue + İhtar + Mesaj)
- ✅ C: Kısmi Ödeyenler sekmesi (partial + Devret + Elden Alındı)
- ✅ Future Notice: Bank API entegrasyon banner'ı

---

### 13 Nisan 2026 — Dashboard §4.1.1 Yeniden Tasarım + Activity Feed

#### ✅ Tamamlanan Görevler

**1. Backend: Dashboard KPI — Yeni Alanlar + Activity Feed API**
- `AgentDashboardKPIs`: `active_tenants` ve `staff_count` alanları eklendi
- `ActivityFeedItem` + `ActivityFeedResponse` Pydantic şemaları eklendi
- `GET /operations/activity-feed`: Son işlemler zaman tüneli (ödeme, bilet, bina operasyonu, kiracı)
- 10'ar paket pagination ile döner, zaman sıralı
- **Dosya:** `backend/app/api/endpoints/operations.py`

**2. Frontend: Dashboard Provider Güncellemesi**
- `DashboardMetrics`: `activeTenants`, `staffCount` alanları eklendi
- `fromJson`: yeni alanlar eklendi
- **Dosya:** `frontend/lib/features/agent/providers/dashboard_provider.dart`

**3. Frontend: HomeTab — Yeniden Tasarım (Editorial/Refined Minimal)**
- Refined dark editorial tema — sharp typography, restrained palette
- 3'lü KPI grid: Toplam Daire | Aktif Kiracı | Çalışanlarım (PRD §4.1.1-A tam)
- 3'lü alt KPI: Tahsilat Oranı | Bekleyen Bilet | Boş Daire
- Hero card: Aylık tahsilat, gradient glow, collection rate badge
- **Son İşlemler (§4.1.1-B)**: Activity Feed listesi — gerçek API'den yükleniyor
- "Daha Fazla Göster" pagination butonu
- Staggered fade-in animasyonları (TweenAnimationBuilder)
- RefreshIndicator + pull-to-refresh
- `withValues(alpha:)` — deprecated `withOpacity` düzeltildi
- **Dosya:** `frontend/lib/features/agent/tabs/home_tab.dart`

**4. PRD §4.1.1 Uyumluluğu**
- ✅ Özet Kartları (3 adet dinamik KPI)
- ✅ Etkinlik Akışı (Son İşlemler — kronolojik zaman tüneli)
- ✅ [ Daha Fazla Göster ] butonu ile 10'arlı pagination

---

### 14 Nisan 2026 — §4.3 Ev Sahibi Paneli — §4.3.2 §4.3.3 §4.3.4

#### ✅ Tamamlanan Görevler

**1. Backend: landlord.py — Gerçek Ödeme Geçmişi Hesaplama (§4.3.2)**
- `/landlord/tenants` endpointi — önceki `on_time_payments = months` (sahte) → gerçek hesaplama
- Her kiracı için son 12 ayın `FinancialTransaction` kayıtları çekiliyor
- `PaymentSchedule` due date ile eşleştirme: `paid_on_time` / `paid_late` / `partial` / `pending`
- `payment_score` = (on_time / months) × 100 gerçek skot
- `late_payments`, `missed_payments`, `payment_history` alanları eklendi
- **Dosya:** `backend/app/api/endpoints/landlord.py`

**2. Backend: landlord.py — Kiracı Bilet Yansıması Endpoint (§4.3.3)**
- `GET /landlord/tenant-tickets` — Ev Sahibinin birimlerindeki kiracı destek biletleri
- `SupportTicket` tablosu `unit_id` bazlı filtreleme
- Son mesaj, agent yanıt sayısı, öncelik/durum bilgileri ile döner
- **Dosya:** `backend/app/api/endpoints/landlord.py`

**3. Backend: landlord.py — Yatırım İlgisi / Bilgi Al Endpoint (§4.3.4)**
- `POST /landlord/conversations` — Ev Sahibinin emlakçıyla sohbet başlatması
- İlk mesaj ile birlikte `ChatConversation` + `ChatMessage` oluşturur
- `LandlordInterestRequest` schema eklendi
- **Dosya:** `backend/app/api/endpoints/landlord.py`, `backend/app/schemas/landlord.py`

**4. Frontend: landlord_provider.dart — Syntax Hatası Düzeltmesi + Yeni Model**
- `LandlordTenantTicket` sınıfı syntax hatası giderildi (eksik `}` kapatma)
- `PaymentMonthItem` modeli eklendi (monthLabel, year, month, amount, paidAmount, status, daysLate, paidAt)
- `LandlordTenantTicket` modeli eklendi
- `LandlordState.tickets` listesi + `copyWith` güncellemesi
- `fetchTenantTickets()` + `_fetchTenantTickets()` metotları eklendi
- `fetchAll()` → `_fetchTenantTickets()` çağırıyor
- **Dosya:** `frontend/lib/features/landlord/providers/landlord_provider.dart`

**5. Frontend: landlord_operations_screen.dart — Bilet Bölümü Eklendi (§4.3.3)**
- "Kiracı Biletleri" section header (`_buildSectionHeader`)
- `_buildTicketCard()` — bilet kartı: öncelik/renk, durum badge'i, mesaj sayısı, agent yanıt sayısı, son mesaj alıntısı
- `_ticketStatusColor()`, `_ticketPriorityColor()`, `_ticketStatusLabel()` yardımcı metotları
- `RefreshIndicator` → `fetchTenantTickets()` çağırıyor
- Operations + Tickets birlikte gösteriliyor (section bazlı)
- **Dosya:** `frontend/lib/features/landlord/screens/landlord_operations_screen.dart`

**6. Frontend: landlord_investment_screen.dart — Bilgi Al Gerçek API Entegrasyonu (§4.3.4)**
- `_sendInterestMessage()` → SnackBar → API çağrısı (`POST /landlord/conversations`)
- `ApiClient.dio.post('/landlord/conversations', ...)` ile gerçek mesaj gönderimi
- `mounted` guard ile async gap güvenliği
- Hata durumunda kırmızı SnackBar ile bilgilendirme
- **Dosya:** `frontend/lib/features/landlord/screens/landlord_investment_screen.dart`

**7. Flutter Analyze: 0 Errors**
- `landlord_provider.dart`: No issues found
- `landlord_operations_screen.dart`: 0 errors (info/warning only)
- `landlord_investment_screen.dart`: 0 errors (info/warning only)
- `landlord/` dizini: 123 info issues (withOpacity deprecation), 0 errors

**8. PRD §4.3 Uyumluluğu**
- ✅ §4.3.2: Gerçek ödeme geçmişi (on_time/late/partial/pending + score)
- ✅ §4.3.3: Kiracı bilet yansıması (operations screen'e entegre)
- ✅ §4.3.4: "Bilgi Al" → emlakçıya gerçek sohbet başlatma + mesaj

---

### 14 Nisan 2026 — §5 Offline (Çevrimdışı) ve Bağlantı Kopması Senaryoları

#### ✅ Tamamlanan Görevler

**1. pubspec.yaml — Yeni Bağımlılıklar**
- `hive_flutter: ^1.1.0` — Hive Flutter entegrasyonu
- `connectivity_plus: ^6.1.4` — Bağlantı durumu izleme
- `uuid: ^4.5.1` — Benzersiz offline işlem kimlikleri
- `hive_generator`, `build_runner` — dev bağımlılıkları
- **Dosya:** `frontend/pubspec.yaml`

**2. core/offline/connectivity_service.dart — Bağlantı İzleme Servisi (§5)**
- `ConnectivityService` singleton — `Stream<ConnectionStatus>` ile anlık bağlantı takibi
- `onConnectivityChanged` dinleyicisi — bağlantı kesildiğinde `_status = offline`, döndüğünde `_status = online`
- `isOnline` getter — anlık bağlantı durumu
- `onReconnect` callback — bağlantı geri geldiğinde sync tetikleme noktası
- **Dosya:** `frontend/lib/core/offline/connectivity_service.dart`

**3. core/offline/offline_storage.dart — Hive Box Yönetimi (§5)**
- 7 Hive box: `portfolio_cache`, `contacts_cache`, `reports_cache`, `message_outbox`, `operation_queue`, `transaction_queue`, `meta`
- `cachePortfolio()`, `cacheContact()`, `cacheReport()` — API verilerini Hive'a kaydetme
- `getAllOutboxMessages()`, `addToOutbox()`, `removeFromOutbox()` — chat outbox CRUD
- `addToOpQueue()`, `addToTxQueue()` — bina operasyonu ve işlem kuyruklama
- `totalPendingCount` — tüm kuyruklardaki bekleyen toplam sayı
- **Dosya:** `frontend/lib/core/offline/offline_storage.dart`

**4. core/offline/sync_service.dart — Auto-Senkronizasyon (§5.2 §5.3)**
- `SyncService` singleton — connectivity geri geldiğinde `_onConnectivityRestored` tetiklenir
- `syncAll()` — tüm kuyrukları sırayla senkronize eder
- `_syncChatOutbox()` — `POST /chat/messages` ile bekleyen mesajları gönderir, başarılı olunca outbox'tan siler
- `_syncOperationQueue()` — `POST /operations/building-logs` ile bina operasyonlarını gönderir
- `_syncTransactionQueue()` — `POST /finance/transactions` ile finansal işlemleri gönderir
- Hata durumunda kayıtlar kuyrukta kalır, bir sonraki sync'te tekrar denenebilir
- **Dosya:** `frontend/lib/core/offline/sync_service.dart`

**5. core/offline/offline_cache_provider.dart — Cache Provider'ları (§5.1)**
- `connectionStatusProvider` — `StreamProvider<ConnectionStatus>`
- `isOnlineProvider` — anlık `bool` bağlantı durumu
- `pendingSyncCountProvider` — `OfflineStorage().totalPendingCount`
- `PortfolioCacheNotifier` — portföy verilerini Hive'a cache'ler, çevrimdışıyken cache'ten okur
- `ContactsCacheNotifier` — kiracı ve ev sahibi telefonlarını cache'ler (§5.1)
- `ReportsCacheNotifier` — son 12 finansal rapor özetini cache'ler (§5.1)
- **Dosya:** `frontend/lib/core/offline/offline_cache_provider.dart`

**6. main.dart — Uygulama Başlangıcı (§5)**
- `OfflineStorage().initialize()` — Hive init + box açılışı
- `ConnectivityService().initialize()` — connectivity monitoring başlatır
- `SyncService().initialize()` — bağlantı-geri-dönme sync tetikleyicisini bağlar
- **Dosya:** `frontend/lib/main.dart`

**7. chat_provider.dart — Chat Outbox Kuyruklama (§5.2)**
- `ChatMessage.isPending` alanı — "saat" ikonu göstergesi
- `ChatMessage.pending()` factory — local UUID ile geçici mesaj oluşturur
- `sendMessage()` — çevrimdışıysa `_queueToOutbox()` çağırır, UI'ya `isPending=true` mesaj ekler
- `_queueToOutbox()` — `OfflineStorage.addToOutbox()` ile Hive'a kayıt
- `confirmMessage()` — SyncService başarılı sync sonrası pending mesajı gerçek server mesajına çevirir
- **Dosya:** `frontend/lib/features/agent/providers/chat_provider.dart`

**8. chat_window_screen.dart — Clock İkonu (§5.2)**
- `msg.isPending ? Icons.access_time : Icons.done_all` — bekleyen mesajlarda altın sarısı saat ikonu
- Gönderilmiş + onaylanmış mesajlarda yeşil ✓✓ okundu ikonu
- **Dosya:** `frontend/lib/features/agent/screens/chat_window_screen.dart`

**9. building_operations_provider.dart — Bina Operasyon Kuyruklama (§5.3)**
- `BuildingOperationModel.isPendingSync` alanı — "bulut yükleme" ikonu göstergesi
- `BuildingOperationModel.pending()` factory — local UUID ile bekleyen operasyon oluşturur
- `createOperation()` — çevrimdışıysa veya API hatasında operasyonu queue'lar
- `_offlineStorage.addToOpQueue()` — Hive'a bekleyen operasyon kaydı
- **Dosya:** `frontend/lib/features/agent/providers/building_operations_provider.dart`

**10. building_operations_tab.dart — Cloud Upload İkonu (§5.3)**
- `op.isPendingSync` → `Icons.cloud_upload_outlined` (amber) — bekleyen operasyon kartında
- "X işlem senkronizasyon bekliyor" banner'ı — `pendingSyncCountProvider` ile toplam sayı
- **Dosya:** `frontend/lib/features/agent/tabs/building_operations_tab.dart`

**11. mali_rapor_screen.dart — Finansal İşlem Kuyruklama (§5.3)**
- `_submitNewTransaction()` — çevrimdışıysa veya API hatasında işlemi `OfflineStorage.addToTxQueue()` ile Hive'a kaydeder
- Kullanıcıya amber SnackBar ile bilgilendirme ("İşlem kuyruğa eklendi")
- **Dosya:** `frontend/lib/features/agent/screens/mali_rapor_screen.dart`

**12. Flutter Analyze: 0 Errors**
- `connectivity_service.dart`: No issues found
- `offline_storage.dart`: No issues found
- `sync_service.dart`: 1 warning (unused local var)
- `offline_cache_provider.dart`: No issues found
- `chat_provider.dart`: No issues found
- `building_operations_provider.dart`: No issues found
- `mali_rapor_screen.dart`: No issues found
- `main.dart`: 1 info (use_super_parameters)
- Tüm offline dosyaları: 0 errors

**13. PRD §5 Uyumluluğu**
- ✅ §5.1: Portföy cache (Hive), İletişim rehberi cache, Finansal rapor cache
- ✅ §5.2: Chat outbox kuyruklama + Saat ikonu + Auto-sync (ConnectivityService → SyncService)
- ✅ §5.3: Bina operasyon kuyruklama + Cloud upload ikonu, Finansal işlem kuyruklama

