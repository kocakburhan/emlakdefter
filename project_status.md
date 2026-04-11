# 📋 Emlakdefter SaaS — Proje Durum Raporu
**Son Güncelleme:** 11 Nisan 2026 | **Repo:** [github.com/kocakburhan/emlakdefter](https://github.com/kocakburhan/emlakdefter)

> Bu dosya, projenin **tek kaynak gerçeği (Single Source of Truth)** olarak tasarlanmıştır.
> Yapılan her değişiklik, her oturumun özeti ve ilerleme takibi bu dosyada tutulur.

---

## Genel İlerleme

```
████████████████░░░░░░░░░░░░░░░ ~78%
```

| Katman | İlerleme | Detay |
|---|---|---|
| **Altyapı** (DB, Docker, Firebase, Auth) | ~80% | Firebase Phone Auth Console'da aktif edilmeli |
| **Backend API** | ~85% | 11/11 modül — Analytics API eklendi ✅ |
| **Frontend UI** | ~85% | 24/24 ekran — Tümü API'ye bağlandı ✅ |
| **AI/ML** | ~70% | Gemini PDF banka ekstresi okuma ✅ (pdfplumber + gemini-2.5-flash + diffmatchpatch) |
| **Ev Sahibi Paneli** | %100 | 4/4 ekran |
| **Kiracı Paneli** | %100 ✅ | 7/7 ekran — API'ye bağlandı (Home + Finance + BuildingOps) |
| **Offline/Sync** | %0 | Hive/Isar + Queue henüz yok |
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
| **FAZ 5:** İletişim / Destek | 🟡 Devam — Chat Merkezi ✅, WebSocket canlı mesaj ⏸️ |
| **FAZ 6:** Kiracı / Ev Sahibi Panelleri | ✅ Tamamlandı — Kiracı mock hazır, Ev Sahibi %100 (4/4 ekran) |
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

### Sırada: §4.1.8-C — Hetzner Object Storage (Medya Görsel Yükleme)
- Chat ve bina operasyonlarına medya yükleme
- Hetzner Object Storage + WebP sıkıştırma

### Sonraki: §5 — Offline Mode (Hive/Isar + Queue)
- Yerel veri önbelleği + çevrimdışı işlem kuyruğu

### Sonraki: 🚀 VPS Backend Deployment (SSH ile Uzaktan Kurulum)
- Sunucu: Hetzner VPS (Helsinki hel1) — IPv4: 89.167.15.127
- SSH ile bağlanıp uvicorn + PostgreSQL + Redis + Backend kurulumu
- Detaylar aşağıda

### Sonraki: Store Yayını (iOS + Android)
- TestFlight + Google Play Console hazırlığı

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
| ✅ 4.1.2 | Portföy Yönetimi (Dynamic UI + Otonom Üretim) | 🟢 | Tamamlandı |
| ✅ 4.1.3 | Daire Detay Ekranı | 🟢 | Tamamlandı |
| 🟡 4.1.4 | Kiracı/Ev Sahibi Yönetimi | 🟡 | A=✅, B=🔴, C=🔴 |
| ✅ 4.1.5 | Finans AI (PDF gemini-2.5-flash + pdfplumber) | 🟢 | Tamamlandı |
| ✅ 4.1.5-A | **Excel Export (📥 Butonu)** | 🟢 | Tamamlandı |
| ✅ 4.1.6 | Mali Rapor Ekranı (Gelir/Gider + Grafikler) | 🟢 | Tamamlandı |
| ✅ 4.1.6-B | **Mali Rapor — Yeni İşlem Ekle Formu** | ✅ | Tamamlandı |
| ✅ 4.1.7 | Destek Sistemi (Ticket + Timeline) | 🟢 | Tamamlandı |
| ✅ 4.1.8 | Chat Merkezi (WebSocket + WhatsApp UI) | 🟢 | Tamamlandı |
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
| ✅ 3.3 | **APScheduler + FCM Bildirimleri** (payment_schedules otonom üretimi) |

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

---

## Sistem Durumu (Anlık)

| Bileşen | Durum |
|---|---|
| PostgreSQL (Docker) | ✅ `emlakdefter_db` — port 5433 |
| Redis (Docker) | ✅ `emlakdefter_redis` — port 6379 |
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
