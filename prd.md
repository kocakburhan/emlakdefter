# EMLAK YÖNETİM UYGULAMASI (KAPSAMLI PRD - v2.0)

## 1. Proje Özeti ve Teknoloji Yığını
Türkiye pazarındaki emlak ofislerinin portföy yönetimi, finansal tahsilat otomasyonu, müşteri ilişkileri (kiracı/ev sahibi) ve bina/bakım operasyonlarını tek bir merkezden yönetmesini sağlayan **B2B2C** (İşletmeden İşletmeye ve Tüketiciye) SaaS platformudur. Uygulama; emlakçılar, kiracılar ve ev sahipleri için özel olarak tasarlanmış 3 farklı arayüz ve yetki seti sunar.

### Teknoloji Yığını
- **Backend:** Python / FastAPI (Asenkron) & PostgreSQL.
- **Veri İzolasyonu (Multi-Tenancy):** Sistemde yer alacak farklı emlak ofislerinin verilerinin birbirine karışmasını kesin olarak engellemek için PostgreSQL Row Level Security (RLS) ve tablolar düzeyinde agency_id (ofis ID'si) tabanlı katı veri izolasyonu kullanılacaktır.
- **Mobil/İstemci:** Flutter (iOS, Android, Web) - 3 Rol için tek kod tabanı, dinamik arayüz.
- **Gerçek Zamanlı İletişim:** Uygulama içi sohbet (Chat) modülünün çoklu çekirdekli (worker) FastAPI mimarisinde sorunsuz ölçeklenebilmesi için WebSocket altyapısı *Redis (Pub/Sub)* ile desteklenecektir.
- **Altyapı:** Hetzner CX43 VPS (8 çekirdek, 16 GB RAM, 160 GB SSD) & Hetzner Object Storage (Görseller arka planda sıkıştırılarak depolanır).
- **Video:** YouTube "Liste Dışı" (Unlisted) link mimarisi.
- **Yedekleme:** `rclone` ile günlük otonom bulut yedeklemesi (Google Drive vb. hedeflere tek yönlü delta aktarım).
- **Bildirim Altyapısı:** Anlık mobil bildirimler (Push Notification) için Firebase Cloud Messaging (FCM) kullanılacaktır.
- **SaaS Abonelikleri (MVP):** İlk fazda ofisler için kredi kartı ödeme entegrasyonuna (Stripe vb.) girilmeyecek, abonelik ve emlakçı hesapları tamamen manuel yönetilecektir.

---

## 2. Kullanıcı Rolleri ve Yetki Çerçevesi
- **Kurucu Emlakçı (Admin):** Ofis profilini oluşturur. Finans, çalışan yönetimi ve tüm portföye tam erişime sahiptir.
- **Çalışan / Danışman:** Sisteme e-posta davetiyle girer. Mali rapor dışındaki her sayfada tam kapsamlı erişime ve işlevselliğe sahiptir.
- **Kiracı (Tenant):** Sadece kendi kiraladığı dairenin bilgilerini, finansal durumunu, apartman bakım geçmişini görebilir ve destek/sorun bildiriminde bulunabilir.
- **Ev Sahibi (Landlord):** Sadece kendi mülklerinin durumunu, kiracılarının ödeme geçmişini ve dairede/binada yapılan bakım ve destek operasyonlarını (salt okunur) görüntüleyebilir.

---

## 3. Temel Sistem İşleyişi (Core Logic)

### 3.1. Yapay Zeka ile Otonom Tahsilat (PDF Dekont)
- Emlakçı, banka ekstresini "Ekstre Yükle" ekranından PDF olarak yükler. Sistem `pdfplumber` ile metni okur.
- **Yapay Zeka (Model: gemini-2.5-flash, Temp: 0.1):** Metni analiz ederek; "kira", "aidat", "fatura" gibi kesin kategorilere ayrılmış bir JSON dizisi üretir.
- **Eşleştirme:** LLM'den dönen verideki Kira Tutarı, Kiracı Adı ve Ödeme Tarihi parametreleri, veritabanındaki aktif kiracılarla deterministik olarak (Python kodu ile) eşleştirilir.
- **Statü Yönetimi:** Tam eşleşenler "Ödendi" olur, eksik/hatalı olanlar "Onay Bekliyor" veya "Kısmi Ödendi" statüsüne alınarak emlakçıya bildirilir. Emlakçı burada ödemeyi seçerek tutarı açıklamayı vs değiştirerek işlemi aidat/kira/fatura olarak onaylar.

### 3.2. Finansal Ayrım (Gelir ve Gider)
- **Gelir:** Komisyonlar ve hizmet bedelleri doğrudan mali rapora gelir olarak yansır. Aidat, fatura, kira ödemeleri de gelir olarak yansır.
- **Gider:** Emlak ofisinin giderleri doğrudan mali rapora gider olarak yansır. Apartmanda yapılan işlemler, faturalar, ev sahiplerine ödenecek olan kira bedelleri gider olarak yansır. Kullanıcı giderleri direkt olarak listeden seçebilir veya esnek bir şekilde başlığı açıklaması kendisi de yazabilir hatta kendisi de custom kategori oluşturabilir.

### 3.3. Otonom Arka Plan Görevleri (Zamanlayıcı)
- Harici ve ağır bir "Worker" (örn: Celery) kullanmak yerine, FastAPI içine gömülü, hafif ve yüksek performanslı **APScheduler** mimarisi kullanılacaktır.
- Kiracıların `payment_schedules` (beklenen ödeme takvimleri) bu sistem tarafından her ay ilgili günde otonom olarak veritabanına işlenecek ve günü yaklaşanlara/gecikenlere FCM üzerinden otomatik bildirimler (hatırlatmalar) atılacaktır.

---

## 4. Kullanıcı Arayüzleri ve İşlevler (Role Bazlı)

### 4.1. Emlakçı (Admin ve Danışman) Ekranları

#### 4.1.1. Dashboard (Ana Ekran)
Uygulamanın açılış ekranıdır. Emlak ofisinin o anki genel durumunu özetler.

**A. Özet Kartları (KPI):** Ekranın en üstünde yan yana 3 adet dinamik kart bulunur: {Toplam Daire}, {Aktif Kiracı} ve {Çalışanlarım}.

**B. Etkinlik Akışı (Son İşlemler):** Kartların hemen altında, sistemdeki son hareketlerin (Ödeme alındı, destek talebi açıldı, ev sahibi eklendi, yeni daire oluşturuldu vb.) kronolojik olarak listelendiği zaman tünelidir. Liste sayfanın altındaki [ Daha Fazla Göster ] butonu ile 10'arlı paketler (pagination) halinde yüklenir.

#### 4.1.2. Portföy Yönetimi (Detaylı Mimari)
Bu ekran üzerinden apartman, arsa, tarla veya müstakil ev ekleme işlemi ve mevcutta olanları görüntüleme/güncelleme işlemleri gerçekleştirilecektir. Yine bu ekranda ofisin portföyündeki tüm mülk tipleri listelenecektir. Ekran; **Genel Portföy Listesi**, **Otomatik Daire Üretim Motoru** ve **Apartman Detay/Yönetim Ekranından** oluşur.

---

**A. Portföy Listesi ve Dinamik Kayıt Ekleme (Dynamic UI)**
Ekranın ana yüzünde ofise ait tüm apartmanlar, müstakil evler, arsalar ve ticari alanlar listelenir. Yeni bir mülk eklenmek istendiğinde sistem statik bir form sunmaz; bunun yerine kullanıcı deneyimini (UX) ve veri kalitesini korumak için Dinamik Form yapısı kullanır:

*   **İlk Adım (Zorunlu Seçim):** Emlakçı "Yeni Ekle" butonuna bastığında sistem ilk olarak mülkün tipini sorar: [ Açılır Liste: Apartman/Site, Müstakil Ev/Villa, Arsa/Tarla, Dükkan/Ticari ].
*   **Dinamik Veri Alanları (UI Render):** Ekranda yer alacak doldurulabilir alanlar, yukarıdaki seçime göre anında şekil değiştirir:
    *   *Apartman/Site Seçilirse:* "Başlangıç/Bitiş Katı", "Her Katta Kaç Daire Var?", "Ortak Aidat Tutarı", "Yönetici Bilgileri" ve bina teknik özellikleri (Asansör, Kapalı Otopark, Havuz vb.) görünür hale gelir.
    *   *Müstakil Ev / Villa Seçilirse:* Kat döngüsü ve daire sayısı gibi alanlar ekrandan gizlenir. Sadece mülkün fiziksel özellikleri, adresi ve aidat/vergi bilgileri istenir.
    *   *Arsa / Tarla Seçilirse:* Asansör, otopark, aidat, kat ve daire sayısı gibi tüm anlamsız alanlar tamamen gizlenir. Bunların yerine sadece bu mülk tipine özel olan "Ada", "Parsel", "İmar Durumu" ve "Metrekare" alanları açılır.

**B. Otonom Üretim Motoru ve Tekil Birim (Single-Unit) Mantığı**
Sistem arka planda (Backend), her bir kiracıyı veya finansal işlemi mutlaka bir "Alt Birime (Unit)" bağlamak zorundadır (Veritabanı referans bütünlüğü). Bu nedenle eklenen mülkün tipine göre arka plan üretim motoru iki farklı senaryoda çalışır:

*   **Çoklu Üretim Senaryosu (Apartman/Site):** Emlakçı formu onayladığında sistem; girilen başlangıç/bitiş katı ve katta bulunan daire sayısı parametrelerini kullanarak bir döngü (loop) çalıştırır. Saniyeler içinde o apartmana ait tüm alt birimleri (Örn: Kat 1 - No: 1, Kat 1 - No: 2) veritabanında otonom olarak üretir. Binanın ortak aidat tutarı ve teknik özellikleri bu üretilen birimlere kalıtımsal (miras yoluyla) olarak aktarılır.
*   **Tekil Üretim İstisnası (Müstakil Ev / Arsa / Tarla):** Seçilen mülk tipi kat veya daire barındırmayan bir yapıysa, otonom döngü motoru devre dışı kalır. Ancak veritabanı ilişkilerinin (Kiracı Ataması, Finansal Loglar vb.) çökmemesi için sistem, arka planda bu mülke bağlı görünmez bir "Tekil Birim (Single Unit)" kaydı oluşturur. Emlakçı ekranda arsasını tek bir satır olarak görür, ancak sistem o arsayı kiralarken/satarken bu tekil alt birimi kullanarak hatasız çalışmaya devam eder.
*   **Esnek Düzenleme:** Otonom üretilen daireler emlakçı tarafından sonradan manuel olarak düzenlenebilir veya silinebilir (Örn: 2 numaralı daire ile 3 numaralı daire fiziksel olarak birleştirilip dubleks yapılmışsa, biri sistemden silinerek portföy güncellenebilir).

**C. Apartman Detay Ekranı ve Toplu Bildirim (Action Bar)**
Apartmana tıklandığında açılan yönetim panelinde daire listesi ve kritik iletişim araçları yer alır:
*   **[ 📢 Toplu Bildirim Gönder ]:** Tüm kiracılarla hayati iletişim aracıdır. Tıklandığında açılan metin kutusuna yazılan mesaj (Su kesintisi, asansör bakımı vb.), apartmandaki tüm aktif kiracıların telefonlarına anlık **Push Notification** olarak iletilir.
*   **[ ➕ Tekil Daire Ekle ]:** Otomatik üretim dışında kalan ekstra bölümlerin manuel eklenmesini sağlar.

**D. Daire Detayına Geçiş**
Apartman detay ekranındaki herhangi bir daireye tıklandığında, o dairenin finansal ve fiziksel özelliklerinin yönetildiği **Daire Detay Ekranı (4.1.3)** açılır.


#### 4.1.3. Daire Detay Ekranı (Mülk Künyesi)
Seçilen dairenin tüm dijital ve fiziksel verilerinin yönetildiği kontrol panelidir.

**A. Finansal ve Temel Künye:** Dairenin Başlığı, Katı, Kapı Numarası, Kira/Satış Fiyatı, Aidat Tutarı ve emlakçının alacağı Komisyon oranı burada yer alır ve güncellenebilir.

**B. Özellikler ve Etiketler:** Daireye ait teknik olanaklar (Otopark, Balkon, Asansör vb.) emlakçı tarafından eklenebilir ve düzenlenebilir.

**C. Dijital Varlıklar (Medya):** Emlakçının eklediği fotoğraflar eklenme tarihine göre (kronolojik) listelenir. Ayrıca girilen YouTube "Liste Dışı" video linki ile görseller (image) doğrudan uygulama içerisinden (dahili oynatıcı/görüntüleyici ile) açılır.
#### 4.1.4. Kiracı ve Ev Sahibi Yönetimi Ekranı
Bu ekran üzerinden aktif profillerin listelenmesi ve atama yönetimi gerçekleştirilir. Emlakçı; kiracı ve ev sahibi ekleme, silme ve düzenleme işlemlerini bu panelden yönetir.

**A. Profil Yönetimi ve Atama Merkezi:**
*   **Profil Yönetimi:** Aktif profillerin listesi ve atama yönetimi. Bu ekranda kiracı ve ev sahibi ekleme, silme ve düzenleme işlemi gerçekleştirilecektir. Burada kiracı sisteme dahil edilirken kiracı profili oluşturulur ve sistemdeki daire kiracıya atanır. Sözleşme olarak pdf, resim vs. upload edilmesi gibi tüm işlemler burada gerçekleştirilir.
*   **Sözleşme Feshi (Offboarding):** Kiracı evden çıktığında sistemden tamamen silinmez. "Pasif/Eski Kiracı" statüsüne alınarak o daireyle olan bağı koparılır. Bu işlemle birlikte ilgili dairenin durumu sistem tarafından otomatik olarak "Boş/Müsait" statüsüne geçirilir.

**B. Dijital Profil Daveti (Smart Inviting):**
Emlakçı, uygulama üzerinden profilleri (kiracı veya ev sahibi) oluşturup ilgili mülklerle eşleştirdiği anda FastAPI sunucusu veritabanında bu profili oluşturarak tek kullanımlık, kriptografik bir güvenlik jetonu (token) barındıran özel bir davet bağlantısı ve kayıt/giriş işlemlerinin nasıl gerçekleştirileceğini anlatan bir yönlendirme mesajı üretir.

*   **Kiracı İçin (1-to-1 İlişki):** Emlakçı, kiracı profilini ilgili tek bir daireyle eşleştirerek kaydeder. Sistem, şifrelenmiş davet linkini içeren şu şablonda bir mesaj üretir: *"Emlakdefter sistemine kaydınız açılmıştır. Kira takibinizi yapmak için tıklayın: [Link]"*
*   **Ev Sahibi İçin (1-to-Many İlişki):** Emlakçı, ev sahibi profilini oluşturur ve portföyündeki birden fazla mülkü (daireleri) bu kişiye "Sahibi" olarak tanımlar. Sistem, ev sahibine özel şu şablonda bir mesaj üretir: *“Değerli mülk sahibimiz, gayrimenkullerinizin finansal raporlarını ve bakım süreçlerini şeffafça takip etmek için tıklayın: [Link]”*
*   **Gönderim ve Sıfır Maliyet Mimarisi:** Emlakçı bu linki içeren hazır metni dilerse kopyalayabilir, dilerse de **[ WhatsApp ile Gönder ]** butonuna tıklayarak karşı tarafa iletir. (Teknik Gereksinim: Gönderim işlemi WhatsApp Business API üzerinden yapılmayacaktır. Sistem, Flutter url_launcher paketi ile wa.me/ şemasını kullanarak doğrudan kullanıcının cihazında yüklü olan WhatsApp uygulamasını tetikleyecek ve mesajı yerel olarak aktaracaktır. Bu sayede sıfır entegrasyon maliyeti sağlanır.)

**C. Pürüzsüz Onboarding ve Kimlik Eşleştirme (Flutter Web & Firebase):**

*   **Web-First Deneyim:** Kiracı veya Ev Sahibi bu bağlantıya tıkladığında, uygulama mağazası yönlendirmelerinin yarattığı karmaşayı ve indirme bariyerini tamamen atlayarak doğrudan telefonunun tarayıcısında (Safari/Chrome) uygulamanın Flutter Web sürümüne ulaşır.
*   **Firebase OTP ve Şifre Belirleme (Kimlik Otoritesi):** Sistem arka planda URL'deki davet jetonunu (token) okur. Kullanıcının hesabı güvenle devralması için, ekranda telefon numarası istenir ve araya başka SMS firması girmeden Firebase üzerinden anında 6 haneli bir OTP (Doğrulama Kodu) gönderilir. Numara doğrulandıktan sonra kullanıcı sadece kendi şifresini belirler (Kimlik ve şifre verisi tamamen Firebase Auth altyapısında tutulur). Bu onay esnasında sistem, kullanıcının veri işleme politikalarına dair zorunlu "KVKK ve Aydınlatma Metni" sözleşmelerini dijital olarak onaylamasını (Checkbox) zorunlu tutarak emlak ofisine hukuki zırh sağlar.
*   **Backend Eşleşmesi (Binding) ve Sisteme Giriş:** Şifre belirlenip Firebase hesabı oluştuğunda, elde edilen Firebase ID Token ve URL'deki davet jetonu FastAPI sunucusuna iletilir. FastAPI, Firebase Admin SDK'yı kullanarak token'ın orijinalliğini teyit eder, üretilen firebase_uid değerini veritabanındaki (PostgreSQL) ilgili kiracı/ev sahibi profiline kaydeder ve URL'deki davet jetonunu güvenlik amacıyla kalıcı olarak imha eder. Bu dakikadan itibaren JWT (Oturum) üretimi tamamen Firebase'in sorumluluğundadır; FastAPI yalnızca isteklerle gelen Firebase JWT'sini okuyarak veriye erişim izni verir. Paneline ulaşan kullanıcı, dilerse mobil uygulamayı indirmesi için yönlendirilir.

**D. Güvenli OTP ve Şifre Kurtarma (Firebase Merkezli):**

*   **Limitli Talep (Backend Koruması):** Kiracılar veya Ev Sahipleri şifrelerini unuttuklarında, uygulamanın giriş ekranındaki "Şifremi Unuttum" butonuna tıklayarak sisteme kayıtlı cep telefonu numaralarını girerler. Bu aşamada sistem, kötü niyetli SMS Pumping (bot) saldırılarını ve gereksiz fatura maliyetlerini engellemek amacıyla öncelikle kendi backend (FastAPI) veritabanından bu numaranın o ay içindeki şifre sıfırlama talebi sayısını kontrol eder. Belirlenen güvenli limiti (örneğin ayda 15 kez) aşmışsa işlem reddedilir ve kullanıcı doğrudan emlakçısıyla iletişime geçmeye yönlendirilir.
*   **Firebase Entegrasyonu (Tek Kimlik Otoritesi):** Limit dahilindeki meşru taleplerde, şifre sıfırlama işlemi için FastAPI herhangi bir token üretmez. Doğrudan Firebase'in verifyPhoneNumber altyapısı tetiklenir. Firebase, arka planda reCAPTCHA veya Play Integrity gibi görünmez güvenlik katmanlarını çalıştırarak numaraya saniyeler içinde 6 haneli doğrulama kodu (OTP) gönderir.
*   **Sıfırlama ve Doğrulama:** Kullanıcı, telefonuna gelen bu kodu uygulama ekranına doğru bir şekilde girdiğinde Firebase arka planda kimliği doğrular ve karşısına "Yeni Şifrenizi Belirleyin" ekranını çıkarır. Kullanıcının girdiği yeni şifre, Firebase'in updatePassword metodu ile doğrudan Firebase üzerinde güncellenir. Kullanıcı giriş yaptığında (Login), FastAPI sadece Firebase'den dönen güncel JWT'ye güvenerek kullanıcının profiline/paneline pürüzsüzce erişimini sağlar.

#### 4.1.5. Finans ve Ödemeler Ekranı (Detaylı Mimari) 
Bu ekran, emlak ofisinin o ayki tahsilat durumunu anlık olarak yönettiği, yapay zeka eşleştirmelerinin sonuçlarını gördüğü ve kiracılarla finansal iletişime geçtiği kontrol merkezidir. Ekran; bir **Eylem Çubuğu**, **Manuel Onay Merkezi** ve **4 Ana Sekmeden** oluşur.

---

**A. Eylem Çubuğu (Action Bar)**
Ekranın en üstünde yer alan ve genel işlemleri tetikleyen ana kontrol grubudur:
*   **[ 📄 Ekstre / Dekont Yükle ]:** Sistemin otonom tahsilat motorunu tetikler. Emlakçı bankadan indirdiği PDF hesap dökümünü yükler. Sistem arka planda `pdfplumber` ve **gemini-2.5-flash** modeli (Temperature: 0.1) kullanarak verileri (Gönderen, Tutar, Tarih, Açıklama) JSON'a çevirip eşleştirme algoritmasını başlatır.
*   **[ 📥 Excel Çıktısı Al (Export) ]:** Aktif sekmelerdeki kiracı ödeme verilerini (Ad, Daire, Bekleyen Tutar, Gecikme Günü vb.) `.xlsx` formatında indirerek raporlama sağlar.

**B. Manuel Onay Bekleyen İşlemler (Uyarı Banner'ı)**
Sistem/LLM %100 eşleşme sağlayamadığı (Örn: Farklı isimle gönderilen ödemeler) şüpheli işlemler için kırmızı bir uyarı bandı çıkar:
> ⚠️ *"Sistem banka dökümünüzde kime ait olduğunu tam eşleştiremediği X adet işlem buldu. İncelemek için tıklayın."*
> 
> *Tıklandığında manuel eşleştirme ve onay arayüzü açılır.*

**C. Ana Sekmeler (Tabs) ve İşlevleri**
1.  **Ödeyenler (Sorunsuz Tahsilatlar):**
    *   **Kriter:** O ayki kira/aidat bedelini tam ve zamanında ödeyen kiracıların listesidir.
    *   **Veriler:** Ad, Daire, Tutar, Tarih, İşlem Tipi.
    *   **AI Etiketi:** Otomatik eşleşenlerde `🤖 Otomatik Eşleşti` veya `⚡ AI` etiketi yer alır.
2.  **Bekleyenler (Ödeme Günü Gelmeyenler):**
    *   **Kriter:** Ödeme tarihi henüz geçmemiş ancak ödemesini yapmamış kiracılar.
    *   **Görünüm:** "Ödemeye X Gün Kaldı" gibi dinamik geri sayım sayaçları.
    *   **Eylem:** `[ 🔔 Hatırlat ]` butonu ile standart Push Notification gönderimi.
3.  **Gecikenler (Kırmızı Liste):**
    *   **Kriter:** Ödeme tarihi geçmiş ve ödeme yapmamış kiracılar.
    *   **Görünüm:** Kırmızı renkli "X Gün Gecikti" vurgusu.
    *   **Eylem:** `[ 🔔 İhtar Gönder ]` (sert tonlu bildirim) ve `[ 💬 Mesaj Yaz ]` (doğrudan uygulama içi chat).
4.  **Kısmi Ödeyenler (Eksik Bakiyeler):**
    *   **Kriter:** Yatan tutarın beklenen kiradan az olduğu durumlar.
    *   **Veriler:** Beklenen Tutar, Yatan Tutar (Yeşil) ve Kalan Borç (Kırmızı) dökümü.
    *   **Eylem:** Borcu sonraki aya devretme veya elden alındı olarak kapatma seçenekleri.

---

**🚀 Gelecek Planlaması**
Finansal operasyonların tam otomasyonu için ilerleyen fazlarda sisteme **Otomatik Banka Entegrasyonu** (Bank API/Web Service) seçeneği eklenecektir. Bu sayede emlakçının manuel PDF yüklemesine gerek kalmadan veriler bankadan anlık çekilebilecektir. *Şu andaki fazda bunun bilgilendirmesi ekranda yazmalıdır.*

#### 4.1.6. Mali Rapor Ekranı (Detaylı Mimari)
Bu ekran, emlak ofisinin tüm nakit akışını (gelir ve giderlerini) tek bir merkezi havuz üzerinden şeffaf ve esnek bir şekilde yönettiği ana muhasebe merkezidir. Sistem, karmaşık muhasebe standartları yerine pratik işleyişi benimser: Kasaya giren her para (Kira, Aidat, Komisyon) "Gelir", kasadan çıkan her para (Ev sahibine ödenen kira, Apartman faturası, Ofis masrafı) "Gider" olarak tek listede işlenir.

**A. Görselleştirme ve Özet Kartları (Dashboard UI)**
Seçilen tarih aralığına göre dinamik güncellenen özet veriler:

*   **Toplam Gelir Kartı:** O ay ofisin kasasına giren tüm paraların (Kira, Aidat, Komisyon, Fatura tahsilatı) toplamı.
*   **Toplam Gider Kartı:** O ay ofisin kasasından çıkan tüm paraların (Ev sahibine aktarılan kira, Ofis gideri, Apartman masrafı) toplamı.
*   **Net Bakiye (Kasa Durumu):** Toplam Gelir (-) Toplam Gider.
*   **Gelir/Gider Grafikleri:** Pasta grafiği ile kategorilere göre dağılım (Örn: %60 Kira Geçişi, %20 Komisyon, %20 Aidat).

**B. Eylem Çubuğu ve Esnek Kategori Yönetimi**

*   **[ ➕ Yeni İşlem (Gelir/Gider) Ekle ]:** Esnek bir giriş formu açılır. Kullanıcılar işlemi "Gelir" veya "Gider" olarak seçer. Sistemin esnekliği sayesinde emlakçı, örneğin tahsil ettiği bir aidatı etiketleme sistemiyle "Aidatı Gelir Olarak İşaretle" mantığıyla kolayca sisteme kaydedebilir. İhtiyaç halinde "Yeni Kategori Oluştur" ile ofise özel kategoriler tanımlanabilir.
*   **Bağlı Kayıt:** İşlem bir apartmanı veya daireyi ilgilendiriyorsa ilgili mülk seçilerek finansal ilişki kurulur.
*   **[ 📥 Finansal Rapor İndir ]:** Tüm gelir-gider dökümünü dışa aktarır.

**C. Ana Finansal Görünüm (Merkezi Liste)**
Tüm finansal hareketler tek bir kronolojik listede, yeşil (Gelir/Artı) ve kırmızı (Gider/Eksi) renk kodlarıyla gösterilir.

*   **Otonom Girdiler:** Dekont eşleştirme (4.1.5) ekranından "Ödendi" olarak onaylanan tüm kiralar ve aidatlar bu listeye otomatik olarak "Gelir" olarak düşer.
*   **Operasyonel Çıktılar:** Bina operasyonları (4.1.9) ekranında yapılan ve "Gider Olarak İşle" denen tüm tamirat/temizlik masrafları ile ev sahiplerine aktarılan kira bedelleri bu listeye "Gider" olarak düşer.


#### 4.1.7. Destek Yönetimi (Ticket System) Ekranı (Detaylı Mimari)
Bu ekran, emlak ofisinin kiracılardan gelen fiziksel veya idari sorunları (Örn: "Kombi bozuldu", "Çatı akıtıyor", "Aidat itirazı") tek bir merkezden takip edip çözüme kavuşturduğu operasyon panosudur. Ekran, anlık bildirimlerle beslenir ve ofisteki tüm çalışanların ortaklaşa müdahale edebileceği esnek bir yapıya sahiptir. Ekran; **Durum Sekmeleri**, **Talep (Ticket) Detay Görünümü** ve **Eylem/İletişim Çubuğundan** oluşur.

---

**A. Ana Sekmeler (Durum Bazlı Görünüm)**
Taleplerin aciliyetine ve durumuna göre filtrelendiği 3 ana sekme bulunur:
*   **🔴 Açık Talepler (Yeni):** 
    *   **Kriter:** Yeni açılmış, henüz yanıtlanmamış veya işlem yapılmamış talepler.
    *   **Görünüm:** Kırmızı bildirim rozeti (badge) ile aciliyet vurgulanır. Kiracı adı, daire bilgisi, talep başlığı ve tarih/saat özeti listelenir.
*   **🟠 İşlemde Olanlar (Bekleyenler):** 
    *   **Kriter:** Ofis çalışanının cevap yazdığı, ustaya yönlendirdiği ancak henüz kapanmamış talepler.
    *   **Görünüm:** Turuncu/Sarı renk kodu ve son işlem özeti (Örn: "2 saat önce Danışman yanıtladı") görünür.
*   **🟢 Çözülenler (Arşiv):** 
    *   **Kriter:** "Giderildi / Çözüldü" olarak işaretlenmiş, kapanmış talepler. 
    *   **Referans:** Ev sahibine raporlama ve geçmiş kayıtlar için tutulur.

**B. Talep (Ticket) Detay Ekranı ve İçerik Yapısı**
Talebe tıklandığında açılan detaylı görünüm şu yapı taşlarını barındırır:
*   **Talep Künyesi:** Başlık, açılış zamanı, bağlı Daire/Apartman ve Kiracı profiline hızlı erişim linkleri.
*   **Kiracı Bildirimi ve Medya (Kanıtlar):** Sorunun tam metni ve kiracının yüklediği, üzerinde sistemsel **Tarih-Saat Etiketi (Timestamp)** bulunan hasar fotoğrafları kronolojik olarak dizilir.
*   **Aksiyon Geçmişi (Timeline):** Ofis çalışanlarının ve kiracının yazdığı tüm yanıtlar ile durum değişiklikleri bir zaman tüneli mantığıyla listelenir.

**C. Eylem ve İletişim Çubuğu (Action Bar)**
Çalışanların soruna müdahale ettiği araçlar:
*   **[ 💬 Yanıt Yaz (Thread) ]:** Talep başlığı altına yazılı cevap verilir. Yanıt anında kiracıya **Push Notification** olarak düşer.
*   **[ ✅ Giderildi Olarak İşaretle ]:** Sorun çözüldüğünde talep arşive kaldırılır ve kiracıya kapandığına dair bildirim gider.
*   **[ 👤 Kiracıya Direkt Mesaj At ]:** Hızlı/samimi iletişim için doğrudan uygulamanın **WhatsApp Mantığındaki Chat** ekranına atlar.
*   **[ 🔧 Bina Operasyonlarına Ekle ]:** Tamirat bir maliyet gerektiriyorsa, tek tıkla **Mali Rapor** ve **Bina Operasyonları** listesine (Gider/İşlem olarak) veri ekleme kısayolu.

---

**🔒 Şeffaflık ve Çapraz Rol Görünürlüğü**
Ofis çalışanlarının yaptığı durum güncellemeleri, yanıtlar ve hasar fotoğrafları, **Ev Sahibi Arayüzündeki** "Destek Takibi" sekmesine salt okunur (Read-Only) olarak anında yansır. Bu sayede ev sahibi, emlakçısının süreci nasıl yönettiğini şeffaf bir şekilde takip eder.

#### 4.1.8. İletişim ve Sohbet (Chat) Merkezi (Detaylı Mimari)
Bu ekran, emlak ofisi çalışanlarının (Admin ve Danışmanlar) kiracılarla **"WhatsApp mantığında"**, gerçek zamanlı (**WebSocket** tabanlı) ve geçmişe dönük kayıt tutan mesajlaşma arayüzüdür. Emlakçının kişisel numarasını gizleyerek iletişimi ofis veritabanında arşivler. Ekran; **Gelen Kutusu**, **Aktif Sohbet Penceresi** ve **Eklenti Araçlarından** oluşur.

---

**A. Gelen Kutusu (Sohbet Listesi)**
*   **Sıralama:** En son mesajlaşılan kiracı en üstte yer alacak şekilde kronolojik olarak listelenir.
*   **Veri Yapısı:** Kiracı adı, daire bilgisi, son mesaj önizlemesi (snippet) ve zaman damgası.
*   **Okunmamış Rozeti (Unread Badge):** Okunmamış mesajlar kırmızı bir bildirim rozeti ile vurgulanır; toplam sayı uygulamanın alt menü ikonunda da gösterilir.
*   **Arama:** Kiracı adına veya daire numarasına göre anlık filtreleme yapılabilir.

**B. Aktif Sohbet Penceresi (WhatsApp Tasarımı)**
*   **Görsel Hiyerarşi:** Gönderilen mesajlar sağda (ofis renklerinde), gelen mesajlar solda (nötr renkte) baloncuklar içinde sunulur.
*   **Hukuki Arşivleme:** Konuşmalar **PostgreSQL** üzerinde şifreli tutulur. Mesajlar kullanıcı tarafından tek taraflı silinemez (hukuki kanıt niteliği).
*   **Okundu Bilgisi:** Mesaj balonunun altında çift tik (✓✓) veya "Okundu" belirteci yer alır.

**C. Medya ve Belge Gönderimi (Attachment Bar)**
*   **Fotoğraf/Galeri:** Kamera veya galeriden görsel paylaşımı. Görseller **Hetzner Object Storage** üzerinde **WebP** formatında sıkıştırılarak saklanır.
*   **Belge (PDF):** Tahliye taahhütnameleri, kira ekstreleri veya dekontlar doğrudan sohbet üzerinden iletilebilir.

**D. Çapraz Modül Entegrasyonu**
Sistemin bütünüyle entegre olan bu yapı, **4.1.7 Destek Yönetimi** ekranındaki `[ 👤 Kiracıya Direkt Mesaj At ]` butonu ile tetiklenebilir. Sistem, emlakçıyı otomatik olarak bu merkeze yönlendirir ve ilgili kiracının aktif sohbet penceresini anında açar.
#### 4.1.9. Bina Operasyonları ve Tesis Yönetimi (Log Merkezi)
Bu ekran, emlak ofisinin yönetimi altındaki tüm apartmanlarda gerçekleşen fiziksel müdahalelerin (temizlik, bakım, tamirat vb.) kronolojik olarak tutulduğu merkezi kayıt defteridir (**Log**). Operasyonel hafıza niteliği taşır. Ekran; **Merkezi Log Listesi**, **Yeni Kayıt Girişi** ve **Denetim Araçlarından** oluşur.

---

**A. Merkezi Kayıt Defteri (Global Log Listesi)**
En son yapılan işlem en üstte olacak şekilde sıralanmış zaman akışıdır.
*   **Veri Yapısı:** Tarih, Saat, Lokasyon (Apartman/Site adı), İşlem Künyesi (Örn: *[Asansör] Yıllık Bakım*) ve opsiyonel Maliyet bilgisi.
*   **Navigasyon:** Lokasyon ismine tıklandığında doğrudan ilgili apartmanın detay ekranına (**4.1.2**) yönlendirir.

**B. Eylem Çubuğu ve Yeni Operasyon Girişi (Action Bar)**
Yeni bir bina işleminin sisteme otonom bir şekilde işlendiği alandır:
*   **[ ➕ Yeni Operasyon Ekle ]:**
    *   **Bina Seçimi:** İşlemin yapıldığı apartman portföyden seçilir (Zorunlu).
    *   **Kategori:** Temizlik, Asansör, Elektrik vb. hazır kategoriler veya özel başlık girişi.
    *   **💰 Finansal Entegrasyon:** "☑️ Bu tutarı Mali Rapor'a gider olarak işle" kutusu işaretlenirse, tutar otomatik olarak **4.1.6 Mali Rapor** ekranındaki "Giderler" listesine yansır.
    *   **Kanıt/Medya:** Fatura veya işlem fotoğrafları eklenebilir.

**C. Filtreleme ve Denetim (Arama Araçları)**
*   **Bina Bazlı Filtre:** Belirli bir apartmana ait geçmiş tüm işlemleri saniyeler içinde listeler. (Aidat itirazları ve ev sahibi toplantıları için kritik araç).
*   **Kategori/Tarih Filtresi:** Belirli işlem tiplerini veya dönemleri süzmeye yarar.

---

**💡 Şeffaflık ve Çapraz Rol Görünürlüğü**
Log merkezinde oluşturulan her kayıt, ilgili apartmandaki **Kiracıların** ve **Ev Sahiplerinin** mobil uygulamalarındaki "Bina Operasyonları" sekmesine anında **Salt Okunur (Read-Only)** olarak düşer. Bu otonom şeffaf yapı, "Aidatlar nereye gidiyor?" sorularını ortadan kaldırırken ofise olan güveni pekiştirir.

#### 4.1.10. Raporlama ve İş Zekası (Analytics Dashboard)
Bu ekran, emlak ofisi yöneticisinin (Kurucu Emlakçı / Admin) portföyünün genel sağlık durumunu stratejik düzeyde analiz ettiği, geçmişe dönük karşılaştırmalar yapabildiği ve veri odaklı kararlar aldığı üst düzey iş zekası (BI) panelidir. Mali Rapor ekranı (4.1.6) günlük nakit akışını yönetirken, bu ekran **"Büyük resmi görmek"** için tasarlanmıştır.

---

**A. Doluluk ve Portföy Performans Raporu**
Portföyün fiziksel verimliliğini ölçen temel göstergeler:

*   **Anlık Doluluk Oranı (%):** Portföydeki toplam daire/mülk sayısına karşılık aktif kiracısı olan birimlerin yüzdesel oranı. Büyük ve dikkat çekici bir dairesel (donut) grafik ile görselleştirilir (Örn: 🟢 %87 Dolu — 🔴 %13 Boş).
*   **Doluluk Trendi (Çizgi Grafik):** Son 12 ayın doluluk oranının aylık kırılımla çizgi grafikte gösterilmesi. Mevsimsel trendler ve düşüş/yükseliş dönemleri bu grafik ile analiz edilir.
*   **Boş Daire Yaşlandırma Listesi:** Statüsü \"Boş/Müsait\" olan dairelerin ne kadar süredir boş kaldığını gösteren tablo. \"45 Gündür Boş\" gibi etiketlerle acil aksiyon gerektiren mülkler vurgulanır.

**B. Kiracı Sirkülasyon ve Sadakat Analizi**
Kiracı hareketlerinin stratejik analizi:

*   **Aylık Giriş/Çıkış Raporu (Bar Grafik):** Her ay sisteme eklenen yeni kiracı sayısı (yeşil çubuk) ile \"Pasif/Eski Kiracı\" statüsüne alınan kiracı sayısı (kırmızı çubuk) yan yana çubuk grafikte karşılaştırılır.
*   **Ortalama Kiracı Kalış Süresi:** Portföy genelinde bir kiracının ortalama kaç ay kaldığını gösteren metrik. Düşük kalış süresi, fiyatlandırma veya hizmet kalitesi sorunlarına işaret edebilir.
*   **Sirkülasyon Oranı (Churn Rate %):** Belirli bir dönemde ayrılan kiracıların toplam aktif kiracıya oranı. Bu oran, ofisin kiracı tutma (retention) başarısının en net ölçütüdür.

**C. Yıllık Karşılaştırmalı Finansal Rapor**
Mali Rapor ekranındaki (4.1.6) günlük verilerin yıllık stratejik özeti:

*   **Gelir/Gider Karşılaştırma (Yıl Bazlı):** Mevcut yılın aylık gelir ve gider toplamları, bir önceki yılın aynı aylarıyla yan yana çubuk grafiklerde karşılaştırılır. \"Geçen yılın Mart'ına göre gelir %12 arttı\" gibi çıkarımlar yapılabilir.
*   **Kategori Bazlı Gider Dağılımı (Trend):** Giderlerin (Tamirat, Fatura, Ofis Masrafı vb.) aylara göre nasıl değiştiğini gösteren yığılmış alan grafik (Stacked Area Chart). Hangi gider kaleminin büyüdüğü veya kontrol altına alındığı analiz edilir.
*   **Net Kâr Marjı Trendi:** Aylık Net Bakiye (Gelir - Gider) değerinin 12 aylık çizgi grafik ile gösterimi. Ofisin karlılık seyrini yansıtır.

**D. Tahsilat Performans Raporu**
Ödeme disiplini ve tahsilat verimliliğini ölçen metrikler:

*   **Zamanında Ödeme Oranı (%):** Tüm kiracılar arasında son ödeme tarihinde veya öncesinde ödemesini yapanların yüzdesi. Aylık trendi çizgi grafik ile gösterilir.
*   **Ortalama Gecikme Süresi (Gün):** Geciken ödemelerde ortalama kaç gün gecikme yaşandığını gösteren metrik.
*   **Tahsilat Başarı Oranı:** O ay beklenen toplam tahsilatın yüzde kaçının gerçekleştiğini gösteren dinamik KPI kartı (Örn: \"Bu Ay: ₺185.000 / ₺200.000 — %92.5 Tahsil Edildi\").

**E. Dışa Aktarım ve Raporlama Araçları**
*   **[ 📥 PDF Rapor İndir ]:** Seçilen tarih aralığındaki tüm analitik verilerin profesyonel bir PDF raporu olarak (logolu, tarihli) indirilmesi. Ev sahiplerine veya ortaklara sunulmak üzere kullanılabilir.
*   **[ 📊 Excel Detay Çıktısı ]:** Ham verilerin `.xlsx` formatında dışa aktarımı.
*   **Tarih Aralığı Seçici:** Tüm grafikler ve metrikler; \"Bu Ay\", \"Son 3 Ay\", \"Son 6 Ay\", \"Bu Yıl\", \"Geçen Yıl\" ve \"Özel Aralık\" filtreleri ile dinamik olarak güncellenir.

---

**🔒 Erişim Kısıtlaması**
Bu ekrana yalnızca **Kurucu Emlakçı (Admin)** rolü erişebilir. Danışman/Çalışan rolündeki kullanıcılar bu ekranı görmez. Bu tasarım, ofisin stratejik finansal verilerinin yetkisiz kişilerce görüntülenmesini engeller.

### 4.2. Kiracı Ekranları (Detaylı Mimari)
Kiracı arayüzü, kullanıcının sisteme (Web veya Mobil üzerinden) kendi belirlediği şifreyle giriş yaptığı andan itibaren onu karşılayan, salt okunur (read-only) veri panoları ile interaktif iletişim araçlarının harmanlandığı bir müşteri portalıdır.

#### 4.2.1. Dashboard ve Finansal Takip Merkezi
Kiracının uygulamayı açtığında karşısına çıkan ana ekrandır. Kendi dairesine ait sözleşme bedellerini ve ödeme takvimini şeffaf bir şekilde takip etmesini sağlar.

**A. Yaklaşan Ödemeler Kartı:** Ekranın en üstünde yer alan dinamik, büyük özet kartıdır. O ay ödenmesi gereken Kira ve Aidat tutarlarını, son ödeme tarihini ve kalan günü (Örn: "Ödemeye 4 Gün Kaldı") gösterir.

**B. Geçmiş İşlemler (Hesap Dökümü):** Kiracının bugüne kadar yaptığı tüm ödemelerin (veya geciktirdiği/kısmi ödediği ayların) kronolojik bir listesidir. Bu veriler doğrudan emlakçının onayladığı Finans Ekranı'ndan (4.1.5) beslenir. Kiracı, "Geçen ay aidatı yatırmış mıydım?" sorusunun cevabını emlakçıyı aramadan buradan anında yeşil (Ödendi) veya kırmızı (Gecikti) etiketlerle görür.

#### 4.2.2. Destek ve Sorun Bildirim Merkezi (Ticket System)
Kiracının dairesindeki fiziksel sorunları (tesisat, elektrik, demirbaş arızaları) ofise resmi olarak bildirdiği ve sürecin durumunu takip ettiği ekrandır.

**A. [ 🛠️ Destek İstiyorum ] Butonu:** Yeni bir talep açma eylemidir. Tıklandığında açılan formda kiracı sorunun başlığını ve detaylı açıklamasını yazar.

**B. Kanıt ve Medya Ekleme:** En kritik özelliktir. Kiracı, kamerayı açıp sorunun (Örn: Su akıtan kombi) fotoğrafını çeker veya galeriden yükler. Sistem bu fotoğrafların üzerine arka planda Tarih ve Saat Etiketi (Timestamp) basar. Bu sayede "Ben bu sorunu 3 gün önce bildirmiştim, işte fotoğrafı" şeklinde kanıt sunulabilir.

**C. Durum Takibi ve Zaman Tüneli:** Kiracı, açtığı talebin güncel durumunu (Açık 🔴, İşlemde 🟠, Çözüldü 🟢) anlık görür. Emlak ofisinden bir çalışan bu talebe yanıt yazdığında (4.1.7 ekranından), kiracıya anında Push Notification (Bildirim) gelir ve bu ekranda bir sohbet/zaman tüneli akışı şeklinde listelenir.

#### 4.2.3. Belgelerim (Dijital Arşiv)
Sözleşmelerin kaybolma derdini bitiren, Salt Okunur (Read-Only) belge kasasıdır.

**İçerik:** Kiracının daireye girerken imzaladığı Kira Sözleşmesi, Demirbaş Teslim Tutanağı, varsa Tahliye Taahhütnamesi veya aidat planı gibi PDF/Görsel formatındaki tüm resmi belgeler burada listelenir.

**Yetki:** Kiracı bu belgelere tıklayarak görüntüleyebilir veya telefonuna indirebilir ancak asla silemez veya değiştiremez.

#### 4.2.4. Bina Operasyonları (Şeffaflık Panosu)
"Verdiğimiz aidatlar nereye gidiyor?" tartışmasını kökünden çözen, güven inşa edici ekrandır.

**İşleyiş:** Emlak ofisi 4.1.9 Bina Operasyonları ekranına o apartmanla ilgili bir işlem girdiğinde (Örn: Asansör periyodik bakımı, ortak alan temizliği, çatı tamiratı), bu veri anında kiracının bu ekranına düşer.

**Görünüm:** Kiracı, sadece kendi oturduğu apartmana ait işlemleri kronolojik bir zaman akış (Log) şeklinde, salt okunur olarak takip eder. Fatura tutarları (emlakçı gizlemediği sürece) ve işlem tarihleri şeffafça sergilenir.

#### 4.2.5. İletişim ve Sohbet (Chat) Ekranı
WhatsApp kalabalığından kurtaran, doğrudan emlak ofisi ile yazışma modülüdür.

**Arayüz:** Tanıdık bir mesajlaşma (Chat) arayüzüdür. Kiracı buradan emlak ofisine doğrudan yazabilir, fotoğraf veya belge gönderebilir.

**Kurumsallık:** Kiracı, spesifik bir emlakçının kişisel numarasına değil, doğrudan "Ofis Sistemine" mesaj atar. Bu mesaj, emlakçıların 4.1.8 Sohbet Merkezi'ne düşer. Kiracı için kesintisiz ve resmi bir iletişim kanalı yaratılır.

#### 4.2.6. Yeni Ev Keşfi (Boş Portföy Vitrini)
Mevcut kiracıyı elden kaçırmamak ve ofis içinde tutmak için tasarlanmış, B2C (Tüketiciye Yönelik) pazarlama ekranıdır.

**İşlev:** Kiracı evden taşınmayı veya daha büyük/küçük bir eve geçmeyi düşünüyorsa, sahibinden.com gibi sitelere gitmeden önce emlak ofisinin portföyündeki "Müsait / Boş" durumdaki diğer kiralık evleri burada liste halinde görür.

**Filtreleme:** Fiyat, oda sayısı ve özelliklere göre kendi uygulamasının içinden diğer daireleri inceleyebilir, beğendiği bir ev olursa doğrudan kendi emlakçısına "Bu eve de bakabilir miyiz?" diye uygulama içinden chat üzerinden mesaj atabilir.

### 4.3. Ev Sahibi Ekranları (Detaylı Mimari)
Ev sahibi arayüzü, mülk sahibinin sisteme giriş yaptığı andan itibaren yatırımının (mülklerinin) finansal ve fiziksel sağlık durumunu anlık olarak izleyebildiği, Salt Okunur (Read-Only) ağırlıklı üst düzey bir raporlama portalıdır.

#### 4.3.1. Dashboard ve Mülklerim Portföyü
Ev sahibini karşılayan, sahip olduğu tüm mülklerin özet finansal ve doluluk durumunu tek bakışta gösteren ana komuta merkezidir.

**A. Finansal Özet Kartları:** Sisteme kayıtlı tüm dairelerinden o ay beklenen toplam kira geliri, tahsil edilen (ödenmiş) tutar ve varsa gecikmedeki bakiye grafiksel (pasta/çubuk) olarak gösterilir.

**B. Mülklerim Listesi:** Ev sahibinin emlak ofisine emanet ettiği tüm dairelerin (Örn: "Güneş Apt. No: 4", "Akasya Sitesi 2. Kat") alt alta sıralandığı vizyoner bir listedir. Her satırda mülkün anlık statüsü (🟢 Kirada, 🔴 Boş/Müsait) ve kiralıksa o ayki kira ödemesinin yapılıp yapılmadığı (Ödendi/Bekliyor) net bir rozet (badge) ile belirtilir.

#### 4.3.2. Daire Detay ve Kiracı Performans Raporu
"Mülklerim" listesinden herhangi bir daireye tıklandığında açılan, o gayrimenkulün röntgeninin çekildiği detaylı analiz ekranıdır.

**A. Kiracı Künyesi:** Dairede oturan mevcut kiracının temel iletişim bilgileri (Emlakçı gizlemediği sürece) ve sözleşme başlangıç tarihi yer alır.

**B. Ödeme Düzeni (Performans Skoru):** Bu bölüm uygulamanın kalbidir. Sistemin otonom tahsilat motorundan (PDF Dekont Okuyucu) gelen verilerle, kiracının geçmiş aylardaki ödeme sadakati listelenir. Ev sahibi, son 12 ayın dökümünü "Zamanında Ödedi", "5 Gün Geciktirdi" gibi net etiketlerle şeffafça görür.

**C. Dijital Arşiv (Salt Okunur Belgeler ve Medya):** Emlakçının sisteme yüklediği o daireye ait güncel fotoğraflar, kiracıyla yapılan Kira Sözleşmesi (PDF) ve Demirbaş Teslim Tutanağı gibi kritik evraklar bu alanda arşivlenir. Ev sahibi bunları dilediği zaman görüntüleyip indirebilir ancak asla silemez.

#### 4.3.3. Şeffaf Operasyon ve Destek Takibi (Log)
Emlak ofisinin "Biz sizin evinizle 7/24 ilgileniyoruz" mesajını sessizce ve en güçlü şekilde verdiği, operasyonel raporlama ekranıdır.

**A. İçerideki Sorunlar (Ticket Yansıması):** Eğer kiracı, evdeki bir arıza için "Destek İstiyorum" talebi açmışsa (Örn: Kombi arızası), ev sahibi bunu anında bu ekranda görür. İşin can alıcı noktası; emlakçının o sorunu çözmek için verdiği yanıtları, çağırdığı ustayı ve sorunun "Çözüldü" olarak işaretlenme hızını zaman tüneli (Timeline) mantığıyla adım adım izler.

**B. Bina Operasyonları (Genel Bakım Listesi):** Dairenin bulunduğu apartmanda emlak ofisi/yönetim tarafından yapılan genel harcamalar ve fiziksel müdahaleler (Asansör periyodik bakımı, çatı aktarımı, ortak alan temizliği) kronolojik bir liste halinde bu ekrana yansır.

#### 4.3.4. Yeni Yatırım Fırsatları (Boş Portföy Vitrini)
Emlak ofisinin elindeki diğer yatırımcıyı (ev sahibini) ofis içinde tutmak ve ona yeni gayrimenkuller satmak/kiralamak için kurguladığı B2B pazarlama alanıdır.

**İşlev:** Ev sahibi, yeni bir gayrimenkul yatırımı yapmayı planlıyorsa veya portföyünü genişletmek istiyorsa, piyasadaki diğer sitelere girmeden doğrudan bu sekmeden emlak ofisinin elindeki "Satılık" veya "Kiralık" boş daireleri filtreleyerek (fiyat, lokasyon, özellik) inceler.

**İletişim:** İlgisini çeken bir mülk olduğunda tek tıkla emlakçısına "Bu portföyle ilgileniyorum, detayları görüşelim" mesajı atabilir.

---

## 5. Offline (Çevrimdışı) ve Bağlantı Kopması Senaryoları
Emlakçıların sahada (örneğin bodrum katlarda, asansörlerde, yeni inşaat alanlarında veya mobil verinin çekmediği yerlerde) kesintisiz çalışabilmesi uygulamanın başarılı olması için kritik bir gereksinimdir. Mobil uygulamada (Flutter) yerel önbellekleme (Caching) ve işlem kuyruklama mekanizmaları kullanılacaktır.

### 5.1. Veri Okuma (Read-Only) Offline Erişimi
Kullanıcı (özellikle emlakçı), cihazında internet bağlantısı olmasa dahi en son bağlandığında cihazına yüklenmiş kritik verileri kesintisiz olarak görüntülemelidir:
- **Portföy ve İletişim Rehberi:** Portföydeki daireler, boş/dolu durumları ve kiracı/ev sahibi telefon numaraları cihazda yerel veritabanında (örn. SQLite, Hive, Isar vb.) tutulur. İnternet yokken kiracıyı aramak mümkündür.
- **Geçmiş Raporlar:** En son indirilen finansal raporlar ve mali özet tabloları çevrimdışı incelenebilir.
- *Medya (Görsel/PDF):* Sadece daha önce açılmış ve cihazın önbelleğinde (cache) bulunan görsel ve belgeler çevrimdışı görüntülenebilir. Yeni medyalar indirilemez.

### 5.2. Mesajlaşma (Chat) Kuyruklama Sistemi
Saha koşullarında bağlantısı kesilen çalışanın iletişim sürekliliği sağlanır:
- **Geçici Bekletme:** İnternet yokken gönderilen mesajlar arayüzde "Saat" (Bekliyor) ikonuyla görünür ve cihazın yerel "Giden Kutusu"na (Outbox) kaydedilir.
- **Oto-Senkronizasyon:** Cihaz internet bağlantısını yeniden sağladığı anda (arka planda dahi), bekleyen mesajlar sırayla ve kullanıcının asıl "Gönderme" zaman damgasıyla (timestamp) karşı tarafa iletilir. Bu sayede hiçbir mesaj kaybolmaz veya sıralaması bozulmaz.

### 5.3. Finansal ve Operasyonel İşlem Kuyruklama
Emlakçının sahada yapması gereken kayıt işlemleri de offline olarak desteklenir:
- **Gider ve Operasyon Girişi:** Sahada, internet olmayan bir apartmanda yapılan asansör tamiratı harcaması veya yeni bir Bina Operasyonu (Log) makbuzu çekilip sisteme "Gider" olarak girilebilir.
- **Local Validation:** Kayıt cihazda tutulur ve UI üzerinde "Senkronizasyon Bekliyor" (Cloud Upload ikonu) şeklinde gösterilir.
- **Bağlantı Algılama:** İnternet geldiğinde bu veri otomatik olarak backend'e (FastAPI) gönderilir. Yükleme başarılı olduğunda statüsü normale döner. Mevcut çakışmaları engellemek için her offline işleme özel `uuid` (benzersiz işlem kimliği) atanır.

---

## 6. Veritabanı Mimarisi (PostgreSQL Şeması)
Sistem, veri izolasyonunu sağlamak için **Row Level Security (RLS)** kullanan, ilişkisel bir PostgreSQL veritabanı üzerine inşa edilecektir. Tüm asıl tablolarda (ofis düzeyinde) `agency_id` bulunacak ve emlak ofisleri arasında (multi-tenant) veri sızıntıları kesin olarak engellenecektir.

### 6.1. Temel Standartlar
- **Kimlik Yönetimi:** Firebase Auth kullanılacak, tablolarda oturum referansı olarak `firebase_uid` tutulacaktır.
- **Soft Delete:** Veri kaybının önüne geçmek için kritik tüm tablolarda `is_deleted` (boolean) ve `deleted_at` kolonları yer alacaktır.
- **UUID:** Dağıtık veri işleme ve offline kuyruklama optimizasyonu için tüm Primary Key (PK) alanlarında `UUID` (PostgreSQL `uuid-ossp` veya `pgcrypto`) kullanılacaktır.

### 6.2. Çekirdek Tablolar ve İlişkiler

#### A. Yetki ve Kullanıcı Yönetimi
- **`agencies` (Ana Emlak Ofisleri):** Emlak bürolarının listesi (Sistemin ana müşterileri).
  - Alanlar: `id`, `name`, `contact_email`, `contact_phone`, `subscription_plan`, `created_at`
- **`users` (Global Sistem Kullanıcıları):** Kiracı, ev sahibi veya emlakçıların Firebase ile doğrulanan tekil kimliği. B2B2C yapısında bir kişi X ofisinde kiracı, Y ofisinde ev sahibi olabileceği için `role` ve `agency_id` burada tutulmaz, globaldir.
  - Alanlar: `id`, `firebase_uid` (Unique), `full_name`, `phone_number` (Unique), `created_at`
- **`agency_staff` (Ofis Çalışanları):** Platformdaki emlakçı ve danışmanları kendi ofislerine bağlayan yetki tablosu.
  - Alanlar: `id`, `agency_id` (FK), `user_id` (FK), `role` (Enum: 'admin', 'agent'), `created_at`
- **`invitations` (Akıllı Davet Jetonları):** Emlakçının WhatsApp/SMS ile yolladığı tek kullanımlık kayıt token'larının tutulduğu geçici havuz.
  - Alanlar: `id`, `agency_id` (FK), `token` (String, Unique), `target_role` (Enum), `related_entity_id` (UUID - İlgili birim veya profil), `is_used` (Boolean), `expires_at`
- **`user_device_tokens` (FCM Bildirim Kayıtları):** Kullanıcıların mobil cihazlarına Push Notification atabilmek için Firebase Cihaz ID'lerinin tutulduğu tablo.
  - Alanlar: `id`, `user_id` (FK), `fcm_token` (String, Unique), `device_type` (Enum: 'ios', 'android', 'web'), `created_at`, `last_used_at`

#### B. Portföy Yönetimi (Mülk ve Daireler)
- **`properties` (Üst Mülk / Bina / Arsa):** Apartman, site veya tekil arsaların üst çatı kaydı.
  - Alanlar: `id`, `agency_id` (FK), `type` (Enum: 'apartment_complex', 'standalone_house', 'land', 'commercial'), `title`, `address`, `features` (JSONB, örn: asansör, havuz), `created_at`
- **`property_units` (Alt Birim / Daire):** Kiraya verilen veya satılan yegane birimler (Otonom motorun ürettiği veya istisnai tekil birimler).
  - Alanlar: `id`, `property_id` (FK, Arsa ve evlerde aynı id'ye bağlanabilir), `agency_id` (FK), `unit_number` (String, örn: "No: 12"), `floor_number`, `status` (Enum: 'vacant', 'rented', 'maintenance'), `vacant_since` (Date - Ortalama boş kalma yaşı hesaplaması için), `rent_price`, `dues_amount` (Ortak Aidat Tutarı), `features` (JSONB), `media_links` (Array of Strings), `youtube_video_link`, `created_at`

#### C. Kiracı ve Ev Sahibi Bağlantıları
- **`landlords_units` (Ev Sahibi - Mülk İlişkisi):** Ev sahiplerini mülklere bağlayan çoka çok (Many-to-Many) eşleştirme tablosu.
  - Alanlar: `id`, `landlord_user_id` (FK), `unit_id` (FK), `ownership_share` (Decimal, hisse oranı)
- **`tenants` (Akit ve Kiracı Profili):** Kiracıların sözleşme ve kiralama döngüsünün tutulduğu tablo.
  - Alanlar: `id`, `user_id` (FK), `unit_id` (FK), `agency_id` (FK), `status` (Enum: 'active', 'past'), `contract_start_date`, `contract_end_date`, `actual_end_date` (Date - Gerçek ayrılma tarihi, sirkülasyon analizi için), `agreed_rent`, `payment_day` (Ayın kaçı), `documents` (JSONB - Sözleşme PDF, taahhütname linkleri)

#### D. Finans ve Otonom Tahsilat
- **`financial_transactions` (Genel Kasa / Rapor Merkezi):** Gelir ve giderlerin tek havuzda birleştiği ana finans (muhasebe) tablosu.
  - Alanlar: `id`, `agency_id` (FK), `type` (Enum: 'income', 'expense'), `category` (Enum: 'rent', 'dues', 'commission', 'maintenance', 'utility', 'other'), `amount` (Decimal), `transaction_date`, `description` (Açıklama), `status` (Enum: 'completed', 'pending_approval', 'partial'), `receipt_url` (PDF/Görsel dekont)
  - Opsiyonel Çoklu Referanslar (Nullable): `unit_id`, `tenant_id`, `property_id` (İşlemin neyle ilgili olduğunu çözmemizi sağlar)
  - `ai_matched` (Boolean - Dekont yapay zeka/PDF okuma işleminden mi geldi?)
- **`payment_schedules` (Ödeme Beklentileri / Takvim):** Kiracılardan zamanı geldikçe beklenen (tahakkuk eden) kira ve aidat ödemelerinin periyodik takvimi.
  - Alanlar: `id`, `tenant_id` (FK), `expected_amount`, `category` (rent / dues), `due_date`, `status` (Enum: 'paid', 'pending', 'overdue'), `transaction_id` (Ödendiyse financial_transactions referansı)

#### E. Operasyon, Destek (Tickets) ve Loglar
- **`support_tickets` (Destek/Arıza Talepleri):** Kiracıların açtığı şikayet, hasar ve arıza bildirimleri.
  - Alanlar: `id`, `agency_id` (FK), `tenant_user_id` (FK), `unit_id` (FK), `title`, `description`, `status` (Enum: 'open', 'in_progress', 'resolved', 'closed'), `priority`
- **`ticket_messages` (Talep İçi Yanıtlar / Timeline):** Arıza durumundaki (Thread) konuşmalar ve fotoğraf kanıtları.
  - Alanlar: `id`, `ticket_id` (FK), `sender_user_id` (FK), `message`, `attachment_url` (Zaman damgalı imaj), `created_at`
- **`building_operations_log` (Şeffaf Bina Bakım Logları):** Bölüm 4.1.9 Bina Operasyonları için kaydedilen kronolojik fiziksel işlemler.
  - Alanlar: `id`, `agency_id` (FK), `property_id` (FK), `title` (Açıklama), `operation_date`, `invoice_url` (Fatura kanıtı/Makbuz), `transaction_id` (Eğer mali rapora gider olarak düşmüşse financial_transactions FK referansı)

#### F. Çevrimiçi İletişim (Chat Merkezi)
- **`chat_conversations` (Sohbet Oturumları):** Ofis ve Müşteri (Kiracı veya Ev Sahibi) arasındaki diyalogların listesini tutar. WhatsApp ana ekran mantığı.
  - Alanlar: `id`, `agency_id` (FK), `client_user_id` (FK - İletişim kuran kiracı veya ev sahibi), `last_message_at`
- **`chat_messages` (Sohbet Geçmişi):** WhatsApp benzeri chat arayüzündeki tekil iletiler ve medya.
  - Alanlar: `id`, `conversation_id` (FK), `sender_user_id` (FK), `content` (Text), `attachment_url` (Belge/Foto linki), `is_read` (Boolean), `created_at`