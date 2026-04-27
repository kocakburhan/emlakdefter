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

## Agent Sistemi (.claude/agents/)

Proje, üç-dört agent'lı bir workflow ile çalışır. Orta-Büyük bir özellik veya refactoring görevi için sırayla veya paralel olarak kullanılırlar:

| Agent | Ne Yapar | Ne Zaman Kullanılır |
|---|---|---|
| **planner** | Gereksinimleri analiz eder, adım-adım uygulama planı çıkarır (kod yazmaz) | Kullanıcı yeni özellik, refactor veya mimari değişiklik istediğinde |
| **ui-agent** | Layout, component breakdown, tasarım kararlarını verir | UI/UX içeren görevlerde, planner'dan sonra |
| **builder** | TDD ile kodu yazar (test önce, sonra implementasyon) | Planner + ui-agent brief hazır olduğunda |
| **reviewer** | Kod kalitesi + güvenlik kontrolü yapar, CRITICAL bulursa merge'i bloklar | Builder kod ürettikten sonra, commit öncesi |

**Kullanım sırası:** `planner` → `ui-agent` → `builder` → `reviewer`

Detaylı bilgi için: `.claude/agents/` klasöründeki agent dosyalarını okuyun.

---

## Kritik Kurallar

1. **Veri izolasyonu:** Tüm sorgularda `agency_id` üzerinden RLS kontrolü — güvenli çoklu ofis desteği
2. **Soft delete:** Kritik tablolarda `is_deleted` ve `deleted_at` kullan
3. **UUID PK:** Tüm tablolarda UUID primary key kullan
4. **Firebase Auth:** JWT token doğrulama `get_current_user_agency_id` üzerinden
5. **API değişikliklerinde:** `project_status.md`'yi güncelle
6. **Her görev tamamlandığında:** `project_status.md`'ye o görevin tamamlandığını, ne yapıldığını ve tarihini **adım adım detaylıca** yaz. Bu değişmez bir kuraldır. project_status.md her zaman %100 proje gerçeği ile güncel olmalıdır — eksik veya güncellenmemiş bir project_status.md, proje durumunu yansıtmaz.
7. **Test kuralı:** Bir özellik "tamamlandı" olarak işaretlenmeden önce MUTLAKA test edilmiş olmalıdır. Sadece kod yazılması yeterli değildir.
8. **Kolaya kaçma yasağı:** Kod yazarken kolaya kaçma. Şimdi zaman kazanıp sonra hata oluşturacak yaklaşımlardan kaçın. Her zaman doğru ve sürdürülebilir çözümü tercih et.
9. **Hata fark etme kuralı:** Geliştirme sırasında bir hata veya yanlışlık fark ettiğinde görevini bitirdikten sonra bekleme, **o an çöz**. Görev tamamlandığında fark ettiğin hataları düzelt ve bu durumu bana bildir.

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

---

## Kullanılabilir Skill'ler (~78 adet)

Proje görevlerinde otomatik olarak kullanılması gereken skill'ler. Görev türüne göre ilgili skill'i seç.

### 🦸 Superpowers (Agent Workflow) — Hepsı Kullanılır
| Skill | Ne Zaman Kullanılır |
|---|---|
| `superpowers:brainstorming` | Yeni özellik öncesi fikir üretme |
| `superpowers:writing-plans` | Implementasyon planı yazma |
| `superpowers:executing-plans` | Planı adım adım uygulama |
| `superpowers:test-driven-development` | TDD ile kod yazma |
| `superpowers:systematic-debugging` | Hata ayıklama |
| `superpowers:code-review` | Kod kalitesi + güvenlik kontrolü |
| `superpowers:finishing-a-development-branch` | Branch tamamlama |
| `superpowers:dispatching-parallel-agents` | Paralel işler |
| `superpowers:verification-before-completion` | Tamamlamadan önce doğrulama |

### 🔥 FastAPI Backend (~25 skill)
| Skill | Kullanım |
|---|---|
| `api-scaffolding:fastapi-templates` | FastAPI proje scaffold |
| `backend-development:api-design-principles` | API tasarımı |
| `backend-development:architecture-patterns` | Mimari kalıplar |
| `backend-development:microservices-patterns` | Microservices |
| `backend-development:cqrs-implementation` | CQRS pattern |
| `backend-development:saga-orchestration` | Distributed transaction |
| `backend-development:projection-patterns` | Read models |
| `backend-development:event-store-design` | Event sourcing |
| `backend-development:workflow-orchestration-patterns` | Workflow design |
| `backend-development:temporal-python-testing` | Temporal testing |
| `python-development:async-python-patterns` | Async/await |
| `python-development:python-design-patterns` | Design patterns |
| `python-development:python-testing-patterns` | Testing |
| `python-development:python-performance-optimization` | Performans |
| `python-development:python-observability` | Logging/tracing |
| `python-development:python-error-handling` | Error handling |
| `python-development:python-resilience` | Retry/circuit breaker |
| `python-development:python-background-jobs` | Background tasks |
| `python-development:python-project-structure` | Proje yapısı |
| `python-development:python-packaging` | Packaging |
| `python-development:python-code-style` | Code style |
| `python-development:python-configuration` | Config management |
| `python-development:python-resource-management` | Resource management |
| `python-development:uv-package-manager` | uv package manager |
| `python-development:python-type-safety` | Type safety |

### 📱 Flutter Frontend (~15 skill)
| Skill | Kullanım |
|---|---|
| `minimax-skills:flutter-dev` | Flutter geliştirme |
| `minimax-skills:frontend-dev` | Genel frontend |
| `frontend-design:frontend-design` | UI design |
| `ui-design:responsive-design` | Responsive layout |
| `ui-design:mobile-android-design` | Material Design |
| `ui-design:mobile-ios-design` | iOS HIG |
| `ui-design:react-native-design` | React Native |
| `ui-design:web-component-design` | Web components |
| `ui-design:design-system-patterns` | Design system |
| `ui-design:interaction-design` | Microinteractions |
| `ui-design:visual-design-foundations` | Typography/color |
| `ui-design:accessibility-compliance` | WCAG erişilebilirlik |
| `ui-design:accessibility-audit` | Erişilebilirlik denetimi |
| `ui-design:design-system-setup` | Design system kurulumu |
| `ui-design:design-review` | UI review |

### 🔥 Firebase (~9 skill)
| Skill | Kullanım |
|---|---|
| `firebase-basics` | Firebase genel kurulum |
| `firebase-auth-basics` | Auth |
| `firebase-firestore-standard` | Firestore |
| `firebase-firestore-enterprise-native-mode` | Enterprise Firestore |
| `firebase-data-connect` | SQL Connector |
| `firebase-app-hosting-basics` | App Hosting |
| `firebase-hosting-basics` | Hosting |
| `firebase-ai-logic` | Gemini entegrasyonu |
| `firestore-security-rules-auditor` | **Security audit** |
| `security-check` | **Güvenlik kontrolü** |

### 🗄️ Database (~1 skill)
| Skill | Kullanım |
|---|---|
| `database-design:postgresql-table-design` | PostgreSQL tablo tasarımı |

### 🚀 Deployment / VPS (~4 skill)
| Skill | Kullanım |
|---|---|
| `fullstack-orchestration:deployment-engineer` | CI/CD, GitOps, Coolify |
| `fullstack-orchestration:performance-engineer` | Performans |
| `fullstack-orchestration:full-stack-feature` | Fullstack feature |
| `fullstack-orchestration:security-auditor` | Güvenlik denetimi |

### 🤖 AI/ML (~4 skill)
| Skill | Kullanım |
|---|---|
| `minimax-skills:vision-analysis` | Görsel analiz (Gemini) |
| `developing-genkit-python` | GenKit Python |
| `developing-genkit-js` | GenKit JS |
| `developing-genkit-dart` | GenKit Dart |

### 📄 Dokümantasyon / Üretkenlik (~7 skill)
| Skill | Kullanım |
|---|---|
| `minimax-skills:minimax-pdf` | Rapor PDF oluşturma |
| `minimax-skills:minimax-docx` | Word DOCX oluşturma |
| `minimax-skills:minimax-xlsx` | Excel XLSX |
| `minimax-skills:pptx-generator` | PowerPoint sunum |
| `claude-md-management:claude-md-improver` | CLAUDE.md iyileştirme |
| `claude-md-management:revise-claude-md` | CLAUDE.md revizyonu |

### ❌ Kullanılmayacaklar (Proje Dışı)
- `buddy-sings`, `shader-dev`, `gif-sticker-maker`, `minimax-music-gen`, `minimax-music-playlist`

---

**Kullanım Kuralı:** Bir görev verildiğinde, görev türüne uygun skill'leri otomatik olarak kullan. Önce ilgili skill'i invoke et, sonra görevi gerçekleştir.

---

## 🧪 Geliştirme Sonrası Test Süreci (ZORUNLU)

Herhangi bir geliştirme, yeni özellik veya güncelleme yapıldığında, iş tamamlanana kadar aşağıdaki test süreci uygulanır:

### Test Akışı

```
Geliştirme tamamlandı
        ↓
Test Skill'leri otomatik devreye girer
        ↓
[Backend] python-testing-patterns + systematic-debugging
[Frontend] flutter-dev + ui-design review
        ↓
Hata var mı?
    ↓ Evet              ↓ Hayır
Hata düzeltilir     ✅ Test geçildi
    ↓                      ↓
Tekrar test      İş tamamlandı olarak işaretlenir
    ↓
Hata kalmayana kadar devam et
```

### Kullanılacak Test Skill'leri

| Katman | Skill'ler | Ne Test Edilir |
|---|---|---|
| **Backend API** | `python-testing-patterns` + `systematic-debugging` | Endpoint'ler, veritabanı işlemleri, auth |
| **Backend Logic** | `python-development:python-error-handling` | Exception handling, edge case'ler |
| **Frontend** | `minimax-skills:flutter-dev` + `ui-design:*` | Widget render, navigation, state management |
| **Güvenlik** | `security-check` + `firestore-security-rules-auditor` | Auth, RLS, veri izolasyonu |
| **Entegrasyon** | `fullstack-orchestration:test-automator` | API-Firebase-Flutter bağlantıları |

### Hata Durumunda Kural

1. **Hata tespit edildiğinde:** Hata logunu analiz et (`systematic-debugging`)
2. **Hata düzeltildiğinde:** İlgili test tekrar çalıştırılır
3. **Tüm testler geçene kadar:** Süreç devam eder, iş "tamamlandı" olarak işaretlenmez
4. **Kritik hatalar:** `code-review` skill'i ile birlikte reviewer'a yönlendirilir

### Test Onay Kriterleri

- Backend: Tüm endpoint'ler için başarılı HTTP 2xx yanıtı + doğru veri yapısı
- Frontend: `flutter analyze` hatasız + widget test geçti
- Güvenlik: `security-check` raporu temiz (Critical/High sıfır)
- Entegrasyon: Firebase Auth + Firestore + API bağlantıları çalışır durumda

### Örnek Akış

```
"Kiracıya ödeme hatırlatıcı ekle" görevi verildi
        ↓
backend/finance_service.py ve tenant_payment_screen.dart geliştirildi
        ↓
python-testing-patterns → API endpoint test
systematic-debugging → Error handling kontrol
flutter-dev → Ekran render test
        ↓
Hata: Ödeme API'si 500 veriyor
        ↓
Hata düzeltildi → Tekrar test
        ↓
Tüm testler geçti ✅
        ↓
project_status.md'ye "Ödeme hatırlatıcı eklendi, test edildi, hatasız" yazıldı
```

---

**Önemli:** Test süreci atlanamaz. Hata varsa çözümene kadar bir sonraki adıma geçilmez.
