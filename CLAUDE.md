# Emlakdefter SaaS — Claude Code Yardımcısı

## Proje Özeti
Türkiye pazarındaki emlak ofislerinin portföy yönetimi, finansal tahsilat otomasyonu, müşteri ilişkileri ve bina/bakım operasyonlarını tek bir merkezden yönettiği **B2B2C SaaS platformudur**.

**Teknoloji Yığını:** Python/FastAPI + PostgreSQL (RLS) + Flutter + Firebase Auth + Redis Pub/Sub + Hetzner VPS

**3 Kullanıcı Rolü:**
- **Emlakçı (Agent):** Portföy, finans, destek, chat yönetimi
- **Kiracı (Tenant):** Kendi dairesinin ödeme takibi ve destek bildirimi
- **Ev Sahibi (Landlord):** Mülklerinin salt-okunur finansal ve operasyonel takibi

---

## Kaynak Dosyalar ( Tek Gerçek )

| Dosya | İçerik |
|---|---|
| `prd.md` | Kapsamlı gereksinim dokümanı ( PRD v2.0 ) — **okunmalı** |
| `project_status.md` | Tek kaynak ilerleme raporu — **okunmalı** |

Herhangi bir görev için önce bu iki dosyayı referans al. Yeni bir ekran, API endpoint veya özellik eklerken prd.md'deki ilgili bölümü oku ve project_status.md'yi güncelle.

---

## Proje Yapısı

```
backend/
├── .env                          # 🔒 Git'te yok
├── emlakdefter-*.json            # 🔒 Git'te yok
├── app/
│   ├── main.py                   # FastAPI app entry
│   ├── database.py               # PostgreSQL + Redis
│   ├── core/                     # firebase, security, scheduler, llm
│   ├── models/                   # SQLAlchemy modelleri (7 dosya)
│   ├── schemas/                  # Pydantic şeması (6 dosya)
│   ├── services/                 # finance_service, property_service
│   └── api/endpoints/           # auth, properties, finance, operations, chat, landlord

frontend/
├── firebase_options.dart
├── google-services.json
└── lib/
    ├── main.dart
    └── features/
        ├── auth/                 # 3 ekran + provider
        ├── agent/               # 6 tab + provider (Dashboard, Properties, Finance, Support, BuildingOps, Chat)
        ├── tenant/              # 3 tab + provider
        └── landlord/            # 5 tab + provider (Overview, Properties, Tenants, Operations, Investment)
```

---

## Mevcut İlerleme Durumu

| Katman | İlerleme |
|---|---|
| Altyapı (DB, Docker, Firebase) | ~80% |
| Backend API | ~60% |
| Frontend UI | ~70% |
| AI/ML (Gemini PDF okuma) | ~70% |
| Ev Sahibi Paneli | ~85% |
| Kiracı Paneli | ~85% |
| Offline/Sync | ~50% |
| BI/Analytics | ~80% |

**⚠️ ÖNEMLİ:** "Tamamlandı" yazması test edilmiş demek DEĞİLDİR. Tüm API endpoint'leri ve özellikler ayrıca test edilmelidir.

---

## Kritik Kurallar

1. **Veri izolasyonu:** Tüm sorgularda `agency_id` üzerinden RLS kontrolü — güvenli çoklu ofis desteği
2. **Soft delete:** Kritik tablolarda `is_deleted` ve `deleted_at` kullan
3. **UUID PK:** Tüm tablolarda UUID primary key kullan
4. **Firebase Auth:** JWT token doğrulama `get_current_user_agency_id` üzerinden
5. **API değişikliklerinde:** `project_status.md`'yi güncelle
6. **Her görev tamamlandığında:** `project_status.md`'ye o görevin tamamlandığını, ne yapıldığını ve tarihini detaylıca yaz. Bu değişmez bir kuraldır.
7. **Test kuralı:** Bir özellik "tamamlandı" olarak işaretlenmeden önce MUTLAKA test edilmiş olmalıdır. Sadece kod yazılması yeterli değildir.

---

## Kullanılan Komutlar

```bash
# Backend çalıştır
uvicorn app.main:app --reload --port 8000

# Docker DB + Redis
docker-compose up -d

# Migration
alembic upgrade head

# Flutter analiz
flutter analyze

# Backend doğrulama
python -c "from app.main import app; print('OK')"
```

---

## Bilinen Önemli Noktalar

- Firebase Phone Auth: Console'da henüz aktif edilmedi
- `emlakdefter_db` → port 5433, `emlakdefter_redis` → port 6379
- Eski Firebase Admin SDK anahtarı git geçmişinden temizlendi
- Web platformu için ayrı screen dosyaları: `*_web.dart`, `*_web_stub.dart`
- **Tüm API endpoint'leri test edilmelidir** — "Tamamlandı" yazısı test edilmişlik anlamına gelmez
