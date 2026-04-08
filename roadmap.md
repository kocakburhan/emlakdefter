# EMLAKDEFTERI SaaS Platformu Geliştirme Yol Haritası (Roadmap)

Bu doküman, `prd.md` dosyasında belirlenen iş mantığı, mimari ve kullanıcı senaryolarına dayalı olarak uygulamanın sıfırdan canlıya alınmasına kadar olan süreçte izlenecek **Adım Adım Geliştirme Planını** içermektedir. Tüm adımlar PRD ile %100 uyumludur.

> **Son Güncelleme:** 8 Nisan 2026
> 
> | Faz | Durum |
> |---|---|
> | FAZ 0: Lokal Kurulum | ✅ Tamamlandı |
> | FAZ 1: Temel Altyapı | ✅ Tamamlandı (DB modelleri, API iskeleti) |
> | FAZ 2: Auth & Onboarding | 🔄 Devam Ediyor — Firebase token köprüsü, Dio interceptor, Backend auth entegrasyonu kodlandı (8 Nisan 2026). Firebase CLI yapılandırması bekliyor. |
> | FAZ 3: Portföy Motoru | 🔄 Devam Ediyor — Properties provider gerçek API'ye bağlandı (8 Nisan 2026). UI mock veriden kurtarıldı. |
> | FAZ 4: Finans/AI | ⏸️ Bekliyor |
> | FAZ 5: İletişim/Destek | ⏸️ Bekliyor |
> | FAZ 6: Kiracı/Ev Sahibi | ⏸️ Bekliyor (Kiracı UI mock hazır) |
> | FAZ 7: Offline Mode | ⏸️ Bekliyor |
> | FAZ 8: BI & Yayın | ⏸️ Bekliyor |

---

## 💻 FAZ 0: Lokal Kurulum ve Geliştirme Ortamı (Local Setup)
Kodlama aşamasına (Faz 1) geçmeden önce makinemizde geliştirme ortamının çalışır duruma getirilmesi için gerekli ön atılımlar.

* **Adım 0.1: Backend (FastAPI) Yerel Ortamının Kurulması**
  * Proje dizininde `backend` klasörünün açılması ve Python (3.11+) Sanal Ortamının oluşturulması (`python -m venv venv`).
  * Sanal ortamın aktif edilip temel kütüphanelerin yüklenmesi: `pip install fastapi uvicorn sqlalchemy alembic asyncpg psycopg2-binary pydantic-settings python-multipart python-jose[cryptography] passlib[bcrypt] pdfplumber apscheduler redis google-generativeai firebase-admin`.
  * Veritabanı ve güvenlik anahtarları (Gemini API, JWT, Firebase) için yerel `.env` ve referans `.env.example` dosyalarının oluşturulması.

* **Adım 0.2: Lokal Veritabanları (Docker Compose)**
  * Sistemde çakışmaları önlemek adına PostgreSQL ve Redis'in yerelde çalışması için temiz bir `docker-compose.yml` dosyası yazılması.
  * Terminalden `docker-compose up -d` komutuyla 5432 (Postgre) ve 6379 (Redis) portlarının geliştirme ortamı için ayağa kaldırılması.

* **Adım 0.3: Frontend (Flutter) İskeletinin Baslatılması**
  * Sistemde kurulu `flutter` SDK'sının güncelliğinin teyit edilmesi (`flutter doctor`).
  * Terminal üzerinden projenin inşası: `flutter create --org com.emlog emlog_app` (veya app_client).
  * `pubspec.yaml` içerisine ana kütüphanelerin enjekte edilmesi (`flutter_riverpod`, `go_router`, `dio`, `firebase_core`, `firebase_auth`, `url_launcher`, vb.).

* **Adım 0.4: Firebase Local Entegrasyonu (CLI Modülü)**
  * Firebase Konsolundan boş bir "Emlakdefteri" projesi açılması.
  * Backend için **Firebase Admin SDK** `.json` servis hesabı anahtarının indirilip, `backend` dizininde güvenli bir klasöre konarak `.env` yoluna tanımlanması.
  * Flutter dizininde terminalden `flutterfire configure` çalıştırılarak mobil ve web bağlantı anahtarlarının koda (firebase_options.dart) yerel olarak entegre edilmesi.

---

## 🏗️ FAZ 1: Temel Altyapı ve Veritabanı Mimarisi (Hazırlık ve Çekirdek)
Bu evre, uygulamanın teknik temelini oluşturan veritabanı yalıtımı ve API altyapısının kurulmasını hedefler.

* **Adım 1.1: Proje Başlatma ve İskelet (Scaffolding)**
  * Asenkron yapıdaki Python/FastAPI backend projesinin oluşturulması.
  * Flutter (Web/iOS/Android destekli) tek kod tabanlı frontend uygulamasını inisiyalize etme.
  * Geliştirme, Staging ve Production ortam değişkenlerinin (ENV) yapılandırılması.

* **Adım 1.2: Veritabanı Şeması ve Soft Delete (PRD Madde 6.1 ve 6.2)**
  * PostgreSQL `uuid-ossp` kullanılarak tabloların PK alanlarının UUID yapılması.
  * SQLAlchemy ve Alembic kullanılarak Tüm Çekirdek Tabloların (agencies, users, property_units, tenants, financial_transactions vb.) Migration ile oluşturulması.
  * Veri kaybı güvenliği için tüm tablolara `is_deleted` ve `deleted_at` mekanizmasının (Soft Delete) entegrasyonu.

* **Adım 1.3: Multi-Tenancy (Veri Yalıtımı)**
  * FastAPI tarafında gelen her isteğin `agency_id` parametresini kontrol altına alacak bir Middleware veya Dependency Injection yazılması.
  * SQL seviyesinde emlak ofislerinin birbirinin verisini görmesini %100 engelleyecek mantıksal katmanların uygulanması.

* **Adım 1.4: Bulut Entegrasyonları (Dosya ve Bildirim)**
  * Firebase projesinin kurulması ve Firebase Admin SDK'nın FastAPI'ye eklenmesi.
  * FCM (Push Notification) cihaz token yönetimi ve `user_device_tokens` tablosu arayüzünün yazılması.
  * Hetzner Object Storage (S3 uyumlu) arayüzüne dosya ve fotoğraf `WebP` yükleme servisinin kodlanması.

---

## 🔐 FAZ 2: Kimlik Otoritesi, Güvenlik ve Akıllı Davet (Onboarding)
Firebase ve SMS doğrulama odaklı, şifresiz geçiş ve B2B2C kimlik ataması yapısı.

* **Adım 2.1: Akıllı Davet Jetonları Üretimi (PRD Madde 4.1.4 - B)**
  * Backend üzerinde tek kullanımlık, şifreli JWT jetonları (Token) üreten motorun yazılması.
  * Bu jetonların `invitations` tablosuna kaydedilmesi ve "Süresi dolma" (expiration) mantığının kurgulanması.

* **Adım 2.2: WhatsApp ile Sıfır Maliyetli İletişim (Flutter)**
  * Emlakçı panelinden oluşturulan kayıt linkinin Flutter tarafında `url_launcher` modülüyle (iOS ve Android'de) cihazın yerel WhatsApp'ını veya SMS uygulamasını tetikleyecek şekilde kodlanması.

* **Adım 2.3: Firebase OTP ve Kesintisiz Kayıt Deneyimi (Web-First)**
  * Davet linkini alan müşterinin doğrudan Flutter Web sayfasına düşmesini sağlayacak kurgunun kodlanması.
  * Araya aracı şirket almadan, doğrudan Firebase `verifyPhoneNumber` servisinin tetiklenerek kullanıcıya anlık OTP gönderilmesi ve yeni şifresinin alınması.

* **Adım 2.4: Hesap Bağlama (Binding) ve Global Sistem Kimliği**
  * Firebase ID'si doğrulanan kullanıcının, FastAPI'ye URL'deki referans jetonuyla bağlanarak `tenants` veya `landlords_units` bağının aktif hale getirilmesi.
  * Şifre unutma limitlerinin FastAPI tarafında "Aylık maksimum 15 deneme" şeklinde sınırlandırılması.

---

## 🏢 FAZ 3: Otonom Portföy Motoru ve Dinamik Formlar
Emlakçıların "Yapay Zeka gibi çalışan" apartman/daire oluşturma motorunun inşası.

* **Adım 3.1: Dinamik Portföy UI Formları (Flutter)**
  * Emlakçı "Yeni Ekle" butonuna bastığında Apartman/Müstakil/Arsa tipine göre anında şekilde değiştiren, reaktif ve state barındıran Flutter form kurgusunun tasarlanması.
  * Ekranda asansör, aidat gibi seçeneklerin gizlenip belirmesinin programlanması.

* **Adım 3.2: Çoklu Birim Otonom Üretim Motoru (PRD Madde 4.1.2 - B)**
  * Backend'e Apartman/Site eklendiğinde `Başlangıç/Bitiş Katı` ve `Kattaki Daire Sayısı` loop'larında dönecek toplu üretim motorunun yazılması.
  * Saniyeler içinde yüzlerce `property_units` (kapı numaraları, katlar vb.) satırı oluşturularak ortak aidat gibi bilgilerin miras (inherit) yoluyla birimlere işlenmesi.

* **Adım 3.3: Tekil Birim İstisna Mimarisi (Single-Unit)**
  * Arsa veya müstakil ev gibi durumlarda motorun durdurularak görünmez bir `property_unit` kaydı atama fonksiyonunun yazılması.
  * YouTube "Liste Dışı" video göstericisinin daire detay ekranlarına eklenmesi.

---

## 💰 FAZ 4: Yapay Zeka Tabanlı Tahsilat ve Finans Mimarisi
Projenin en can alıcı noktası: Banka PDF'inden otonom eşleştirmeye olan yolculuk.

* **Adım 4.1: Yapay Zeka Destekli Belge Okuyucu (Gemini-2.5-Flash)**
  * FastAPI 'Ekstre Yükle' endpoint'inin yazılması. Yüklenen PDF dosyasının arka planda `pdfplumber` ile ham metne çevrilmesi.
  * Gemini-2.5-flash (Temperature 0.1) modeli prompt mühendisliğinin yapılması: LLM'in dökümü "Ad Soyad", "Tutar", "Tarih", "category: rent/dues/utility" olarak katı bir JSON formatına ayırmasının sağlanması.

* **Adım 4.2: Eşleştirme Algoritması ve Statü Yönetimi**
  * LLM'den dönen JSON verisinin veritabanındaki aktif kiracıların (`payment_schedules`) listesiyle deterministik Python kurgusuyla eşleştirilmesi.
  * Kusursuz eşleşenlerin otomatik "Ödendi" (`status='completed'`), kusurlu olanların emlakçı ekranındaki "Manuel Bekleyenler" onay sayfasına yönlendirilmesi. Kısmi ödeyenlerin bakiyelerinin güncellenmesi.

* **Adım 4.3: APScheduler Arka Plan Görevleri (PRD Madde 3.3)**
  * FastAPI sunucusu kalktığında entegre çalışacak `APScheduler` zamanlayıcısının devreye girmesi.
  * Kiracı her ay dönümüne geldiğinde otonom olarak `payment_schedules` (Borç Tahakkuk) verisinin otomatik canlandırılması.
  * Günü gelen veya geçen kiracılara "Otomatik Hatırlatma" Firebase Push Notification görevinin yazılması.

* **Adım 4.4: Genel Muhasebe Havuzu (Mali Rapor)**
  * Bütün tahsilatların, harcamaların, bina operasyonlarının ve ofis faturalarının "Gelir-Gider" olarak tek bir `financial_transactions` havuzunda listelenmesi. Dinamik özet KPI kartlarının (Kasa Durumu vb.) oluşturulması.

---

## 🧰 FAZ 5: İletişim, Destek (Ticket) ve Operasyonel Şeffaflık
Kiracı ve Emlakçı trafiğini yöneten, Ev Sahibini rahatlatan araçların kodlanması.

* **Adım 5.1: Destek Yönetim Paneli (Ticket System)**
  * Kiracıların dairesindeki hasarı/fotoğrafı yükleyerek (`support_tickets`) şikayet açabilmesi operasyonunun yazılması.
  * Kiracının yüklediği hasar fotoğraflarına sunucu katmanında `Tarih-Saat (Timestamp)` şeridi basma backend işleminin Python image kütüphanesi ile yazılması.

* **Adım 5.2: WebSocket Mimarisi ve Chat (Gerçek Zamanlı İletişim)**
  * FastAPI'ye WebSocket kütüphanelerinin entegrasyonu (Çoklu worker ortamı için Redis destekli).
  * Flutter tarafında klasik bir anlık mesajlaşma (WhatsApp benzeri) arayüzünün oluşturulması. Mesajların, gönderim durumunun, çevrimiçi statülerinin aktarımı. Medyaların iletilmesi.

* **Adım 5.3: Bina Operasyon Logları (Şeffaflık Modülü)**
  * Emlakçıların bina geneli harcamalarını eklediği log mimarisi (Bkz: `building_operations_log`).
  * Finansal Entegrasyon özelliği: Emlakçı operasyonu girip `[Mali Rapora Gider Olarak İşle]` butonuna bastığı an hem log tutulup hem `financial_transactions` kaydının atılması işlemi.

---

## 📱 FAZ 6: Salt Okunur (Read-Only) Kiracı ve Ev Sahibi Arayüzleri
Müşteri portalı mantığında tüketici uygulamalarının (B2C) arayüz kodlamaları.

* **Adım 6.1: Kiracı Uygulaması (Tenant App)**
  * Ana ekrandaki dinamik "Ödemeye Kalan Gün" KPI kartları. Çıkarılması imkansız, salt okunur geçmiş dökümler (Red/Green listesi).
  * Yeni Ev Keşfi (Boş Portföy Vitrini) ekranının hazırlanıp emlak ofisinin `status='vacant'` mülkleriyle doldurulması.
  * "Belgelerim" listesinin oluşturulup AWS/Hetzner üzerinden evrakların sadece görüntülemeye açılması.

* **Adım 6.2: Ev Sahibi Uygulaması (Landlord App)**
  * Birden fazla evi olan maliklerin aylık genel ciro/tahsilat durumunu şeffaf takip etmesi için KPI kartlarının yapılması.
  * Tutarın kimden, ne zaman ve hangi gecikmeyle (% skor) yattığının otonom tablo olarak derlenmesi.
  * Kiracının açtığı arızalara ajansın (emlakçının) saat kaçta usta yolladığı verilerinin yansımasının "Okuma" modunda çıkarılması (`ticket` modülünün salt okunur entegrasyonu).

---

## 📡 FAZ 7: Çevrimdışı Çalışma (Offline Mode) ve Veri Senkronizasyonu
Mobil sahada internet olmasa dahi kesintisiz kullanabilmeyi sağlayan yerel tamponlama.

* **Adım 7.1: Yerel Depolama (Hive / Isar vb.) Entegrasyonu**
  * Uygulamanın en son açıldığı andaki daire, kira istatistikleri ve müşteri rehberi kopyasının şifreli SQLite/Hive tabanlı lokal dbase'e kopyalanması.
  * Medya olmayan verilere saf salt-okunur (read-only) internetsiz moddan erişilebilmesi.

* **Adım 7.2: İşlem Kuyruklama (Queue Sync)**
  * İnternet kesik olan bir apartman altında emlakçının attığı Chat mesajlarının "Outbox (Giden Kutusu)" içine saat ikonuyla geçici depolanması.
  * Yapılan tamirat kayıtlarının (Gider Girişi) cihaza kaydedilip bağlantı kontrol listener'ıyla Wi-Fi veya Hücreselye bağlandığı an otomatik olarak (uuid çakışma önlemiyle) buluta fırlatılması algoritması.

---

## 📊 FAZ 8: İş Zekası (Analitik Raporlar) ve Yayın
Kurucu Emlakçının ofisini analiz edebilmesi ve projenin ürün aşamasına gelmesi.

* **Adım 8.1: Yönetici BI (Business Intelligence) Dashboard**
  * SQL aggregations işlemi sayesinde "Doluluk Oranı", "Son 12 Aylık Kar Marjı Trendi" grafik verilerinin çekilmesi.
  * Analitik hesapları: `property_units` tablosundaki `vacant_since` kolonuna göre 45 gündür boş duran daireleri ve `tenants` tablosundaki `actual_end_date` verilerine dayanarak "Ortalama Kiracı Kalış Süresi Müşteri Sirkülasyon" raporlarının oluşturulması.

* **Adım 8.2: Excel / PDF Export Dinamikleri**
  * Rapor ekranına (ve Finans ekranlarına) tarih filtresi katarak backend taraflı PDF oluşturma ve kullanıcının cihazına bu dosyayı export etme işlemcisinin kurulumu.
  
* **Adım 8.3: Güvenlik, QA UAT, Çıktı ve Dağıtım**
  * Hata yakalama (Sentry vb.) kurulumları.
  * FastAPI kod bazında unit ve integration yazılım testlerinin koşulması.
  * Flutter App Store, Google Play ve Firebase Hosting (Web platformu) Production yapımlarının tamamlanıp marketlere verilmesi. 

---
**Not:** Bu yol haritası tüm geliştirme sürecine tek bir ışık kaynağı olarak referans verecektir. Geliştirmeler tamamlandıkça her faz ilgili şekilde takip edilebilir.
