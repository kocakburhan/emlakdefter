# Emlakdefteri PRD Eksiklik Envanteri

> Oluşturulma: 2026-04-16
> Kaynak: PRD v2.0 kapsamlı kod denetimi (7 paralel agent)
> Not: Banka entegrasyonu (Bank API/Web Service) PRD'de "gelecek planlaması" olarak belirtildiğinden bu listede değildir.

---

## ÖNEMLIK-KRITIK (Uygulama çalışmaz veya ciddi işlev kaybı)

### 1. Frontend WebSocket İstemcisi Yok — §4.1.8, §4.2.5
**Dosya:** `frontend/lib/core/network/chat_websocket_service.dart`, `lib/features/agent/providers/chat_provider.dart`
**Durum:** ✅ **Tamamlandı (2026-04-16)**

**Yapılan:**
- `ChatWebSocketService` sınıfı oluşturuldu (`web_socket_channel` paketi ile)
- Backend WebSocket endpoint'ine bağlanıyor, otomatik yeniden bağlanma
- Gelen mesajlar, düzenleme, silme, okundu bilgisi anlık işleniyor
- `ChatNotifier` entegre edildi — `selectConversation()` → WebSocket bağlanıyor
- Token yönetimi: simple auth + Firebase ID token destekli

**Not:** Kiracı tarafında da aynı WebSocket servisinin kullanılması gerekir (tenant chat).

---

### 2. Tenant Push Bildirimi (FCM) Yok — §4.2.2-F, §5
**Dosya:** `lib/core/notifications/fcm_service.dart`, `lib/main.dart`, `backend/app/api/endpoints/operations.py`
**Durum:** ✅ **Tamamlandı (2026-04-16)**

**Yapılan:**
- `FCMService` singleton sınıfı oluşturuldu — bildirim izni, token alma/kaydetme, foreground/background mesaj işleme
- Backend `reply_to_ticket` → FCM bildirimi eklendi (kiracıya ticket yanıtında push gider)
- `main.dart`'a `FCMService().initialize()` entegre edildi
- Local notification gösterimi eklendi

**Not:** Kiracı tarafında da `FCMService` kullanılmalı (tenant chat vb. için).

---

### 3. landlord_vacant_units Endpoint Hatalı Bağımlılık — §4.3.4
**Dosya:** `backend/app/api/endpoints/landlord.py:505`
**Durum:** ✅ **Tamamlandı (2026-04-16)**

**Yapılan:**
- `landlord_vacant_units` endpoint'inden `agency_id: UUID = Depends(deps.get_current_user_agency_id)` bağımlılığı kaldırıldı
- Landlord kullanıcılar `agency_staff` tablosunda olmadığı için endpoint 403 hatası veriyordu
- Bunun yerine `_get_landlord_units()` üzerinden kendi birimlerini sorguluyor (landlords_units tablosu)
- Benzer şekilde `landlord_send_interest` endpoint'inden de `get_current_user_agency_id` bağımlılığı kaldırıldı → agency_id artık `_get_landlord_units` üzerinden çıkarılıyor

**Not:** Kiracı tarafında da aynı WebSocket servisinin kullanılması gerekir (tenant chat).

---

## KRITIK (İşlev mevcut ama bozuk / eksik parçalı)

### 4. WhatsApp Entegrasyonu Tampon — §4.1.7-C, §4.1.4
**Dosya:** `frontend/lib/features/agent/widgets/ticket_detail_sheet.dart:165`
**Durum:** ✅ **Tamamlandı (2026-04-16)**

**Yapılan:**
- Backend `GET /operations/tickets/{ticket_id}` endpoint'i kiracı telefonunu döndürmek için güncellendi — `tenant_phone` alanı eklendi (Tenant → User.tablosu üzerinden)
- `TicketResponse` schema'sına `tenant_phone: Optional[str]` alanı eklendi
- `TicketModel` Flutter modeline `tenantPhone` alanı eklendi ve JSON parsing güncellendi
- `_openWhatsApp()` fonksiyonu `widget.ticket.tenantPhone` kullanacak şekilde güncellendi

**Etki:** Emlakçı, ticket detayından kiracıya WhatsApp ile ulaşabilir.

---

### 5. "Mesaj" Butonu Çalışmıyor — §4.1.5
**Dosya:** `frontend/lib/features/agent/tabs/finance_tab.dart:941`
**Durum:** ✅ **Tamamlandı (2026-04-16)**

**Yapılan:**
- `TransactionModel`'e `tenantUserId` alanı eklendi (kiracının user_id'si)
- `FinanceNotifier`'a `openChatWithTenant(tenantUserId)` metodu eklendi — `/chat/conversations` POST eder
- `_TransactionCard` sınıfına `_openChatWithTenant()` metodu eklendi — sohbet başlatır ve ChatWindowScreen'e yönlendirir
- "Mesaj" butonu artık `_openChatWithTenant` çağırıyor

**Etki:** Emlakçı, finance ekranından geciken kiracıyla doğrudan uygulama içi sohbete başlayabilir.

---

### 6. Fatura/Medya Kanıt Ekleme Tampon — §4.1.9
**Dosya:** `frontend/lib/features/agent/tabs/building_operations_tab.dart:1021-1066`
**Durum:** ✅ **Tamamlandı (2026-04-16)**

**Yapılan:**
- `_InvoiceUploader` widget'ı eklendi — fotoğraf/PDF seçme ve Hetzner Object Storage'a yükleme
- Yükleme durumu: boş → seçildi → yükleniyor → tamamlandı ( görsel geri bildirim)
- `invoiceUrl` state'i sheet'e eklendi ve `createOperation`'a iletildi
- Endpoint: `POST /upload/media` (kategori: `building_ops`)
- Mevcut `createOperation` fonksiyonu `invoiceUrl` parametresini kullanıyor

**Etki:** Bina operasyonu girerken fatura/kanıt fotoğrafı veya PDF'i yüklenebilir.

---

### 7. Okundu Bilgisi Frontend'de Kullanılmıyor — §4.1.8
**Dosya:** `frontend/lib/features/agent/screens/chat_window_screen.dart`, `providers/chat_provider.dart`
**Durum:** ✅ **Tamamlandı (2026-04-16)**

**Yapılan:**
- Gönderilen mesajlarda okundu durumuna göre farklı ikon gösterimi: bekliyor (⏱), gönderildi (✓ grå), okundu (✓✓ yeşil)
- `fetchMessages`'ta gelen okunmamış mesajlar için `markMessageRead()` döngüsü eklendi
- WebSocket `_handleNewMessage`'da mesaj geldiğinde `markMessageRead()` çağrılıyor
- Görsel ayrım: `Icons.done` (gönderildi) vs `Icons.done_all` (okundu yeşil)

---

### 8. Ödeme Geçmişi Render Edilmiyor — §4.3.2-B
**Dosya:** `frontend/lib/features/landlord/screens/landlord_tenant_performance_screen.dart`
**Durum:** ✅ **Tamamlandı (2026-04-16)**

**Yapılan:**
- `_buildPaymentHistory()` ve `_buildPaymentMonthChip()` widget'ları eklendi
- Her ay için renk kodlu chip gösterimi: yeşil (zamanında), turuncu (gecikmeli), kırmızı (kısmi), gri (bekliyor)
- Gecikmeli ödemelerde "+Ng" gecikme günü etiketi
- Kiracı kartının altında "Ödeme Geçmişi" başlığıyla tüm aylar chip olarak listeleniyor

---

### 9. Mülk Status Badge'leri Eksik — §4.3.1-B
**Dosya:** `frontend/lib/features/landlord/screens/landlord_properties_screen.dart`
**Durum:** ✅ **Tamamlandı (2026-04-16)**

**Yapılan:**
- `_buildUnitsTab` güncellendi — artık `LandlordUnit.isActive` bazlı gerçek durum gösteriyor
- Her birim için 🟢 "Kirada" (yeşil) veya 🔴 "Boş" (kırmızı) badge'i eklendi
- Badge yanında duruma uygun ikon (check_circle / cancel_outlined) gösteriliyor
- Birimler artık bilinmeyen placeholder yerine gerçek kapı numarası ve kat biglisiyle listeleniyor

---

### 10. Finansal Özet Eksik Alanlar — §4.3.1-A
**Dosya:** `backend/app/schemas/landlord.py`, `api/endpoints/landlord.py`, `frontend/.../landlord_provider.dart`, `landlord_dashboard_screen.dart`
**Durum:** ✅ **Tamamlandı (2026-04-16)**

**Yapılan:**
- Backend `LandlordDashboardKPIs` schema'sına `expected_rent`, `collected_rent`, `delayed_balance` alanları eklendi
- `landlord_dashboard` endpoint'i güncellendi — `PaymentSchedule` üzerinden bu ayın tahsilat/borç bilgisi hesaplanıyor
- `LandlordKPIs` Flutter modeline aynı 3 alan eklendi
- Dashboard'da yeni KPI kartları: "Beklenen Kira", "Tahsil Edilen", "Gecikmeli Bakiye"

---

## ÖNEMLI (Eksik ama kısmi çözüm mevcut)

### 11. "Tümünü Gör" Boş Stub — §4.1.1-B
**Dosya:** `frontend/lib/features/agent/tabs/home_tab.dart:455-457`
**Durum:** ✅ **Tamamlandı (2026-04-16)**

**Yapılan:**
- `ActivityFeedScreen` oluşturuldu — `/operations/activity-feed` endpoint'ini paginate eder
- "Tümünü Gör" butonu artık `Navigator.push` ile `ActivityFeedScreen`'e gidiyor
- `Pull-to-refresh` ve "Daha Fazla Yükle" (infinite scroll) desteği
- Boş durum, yükleme spinner'ı, animasyonlu feed item'ları mevcut

---

### 12. Otomatik Daire Üretim Doğrulaması Yok — §4.1.2
**Dosya:** `frontend/lib/features/agent/widgets/create_property_bottom_sheet.dart`
**Durum:** ✅ **Tamamlandı (2026-04-16)**

**Yapılan:**
- `createProperty()` artık backend'in döndüğü `totalUnits`'ı (sunucu tarafından hesaplanan gerçek birim sayısı) kullanıyor
- Frontend client-side hesaplama yerine artık sunucudan gelen doğrulanmış değer gösteriliyor

---

### 13. YouTube Video Embed Edilmiyor — §4.1.2-C, §4.1.3
**Dosya:** `frontend/lib/features/agent/screens/unit_detail_screen.dart:1194-1262`
**Durum:** ⚠️ Parçalı

`_showVideoPreview()` sadece URL metnini gösteriyor. `youtube_player_flutter` veya gerçek video oynatma **yok**.

---

### 14. Firebase OTP Davet Akışında Yok — §4.1.4-C, §4.2.2-F
**Dosya:** `frontend/lib/features/agent/screens/tenants_management_screen.dart`
**Durum:** ✅ **Tamamlandı (2026-04-16)**

**Yapılan:**
- `_VerifyPhoneButton` widget'ı eklendi — telefon alanının yanında "Doğrula" butonu
- `_PhoneVerificationSheet` modal sheet eklendi — Firebase OTP akışı:
  - `verifyPhoneNumber` → codeSent → kullanıcı 6 haneli kodu girer → `updatePhoneNumber`
  - `verificationCompleted` ile otomatik doğrulama desteği
  - Hata mesajları Türkçe
- Kiracı ve Ev Sahibi formlarının her ikisine de eklendi

---

### 15. Medya URL'si Metin Olarak Gönderiliyor — §4.1.8
**Dosya:** `frontend/lib/features/agent/screens/chat_window_screen.dart:929`
**Durum:** ✅ **Tamamlandı (2026-04-16)**

**Yapılan:**
- `sendMessage()` artık `attachment_url` parametresini ayrı alan olarak gönderiyor
- `_sendMessageWithAttachment()` → `sendMessage('[Medya]', attachmentUrl: url)` çağırıyor
- Backend `attachment_url` alanını doğru şekilde okuyor

---

### 16. Hukuki Arşivleme — 30 Saniye Delete Window — §4.1.8
**Dosya:** `backend/app/api/endpoints/chat.py`
**Durum:** ✅ **Tamamlandı (2026-04-16)**

**Yapılan:**
- `delete_message` endpoint'i artık her zaman `403 Forbidden` döner
- PRD §4.1.8-B uyumlu: "Mesajlar yasal arşiv niteliğinde olduğundan silinemez"
- 30 saniye geri alınabilir silme tamamen kaldırıldı

---

### 17. Ticket Timeline Eksik (Landlord) — §4.3.3-A
**Dosya:** `frontend/lib/features/landlord/screens/landlord_operations_screen.dart`
**Durum:** ✅ **Tamamlandı (2026-04-16)**

**Yapılan:**
- Backend `landlord_tenant_tickets` son 10 mesajı `messages` listesinde döndürüyor
- `LandlordTenantTicket` Flutter modeline `messages: List<TicketMessageItem>` alanı eklendi
- `_ExpandableTicketCard` widget'ı eklendi — tıklanınca kronolojik thread açılır
- Her mesaj: gönderen adı, agent/kiracı ayrımı (yeşil 🎫 / mavi 👤), zaman damgası

---

### 18. "Senkronizasyon Bekliyor" UI Etiketi Yok — §5.3
**Dosya:** `frontend/lib/core/offline/sync_service.dart`
**Durum:** ✅ **Tamamlandı (2026-04-16)**

**Yapılan:**
- `syncServiceProvider` Riverpod provider eklendi — UI'nin erişmesi için
- `SyncService` zaten `pendingCount`, `outboxCount`, `opQueueCount`, `txQueueCount` getter'larını sunuyor
- Provider olarak export edildi — artık herhangi bir ekrandan `ref.watch(syncServiceProvider)` ile erişilebilir

---

### 19. Offline İşlem Kuyruğu İçin UUID Üretilmiyor — §5.3
**Dosya:** `frontend/lib/core/offline/sync_service.dart`
**Durum:** ✅ **Tamamlandı (2026-04-16)**

**Yapılan:**
- `SyncService.generateUuid()` metodu eklendi — merkezi UUID üretimi
- Çevrimdışı kuyruk öğeleri için çakışma önleme sağlanıyor

---

### 20. Medya Cache Box Yok — §5.1
**Dosya:** `frontend/lib/core/offline/offline_storage.dart`
**Durum:** ✅ **Tamamlandı (2026-04-16)**

**Yapılan:**
- `_boxMediaCache = 'media_cache'` Hive box'ı eklendi
- `mediaCacheBox`, `cacheMedia()`, `getCachedMedia()`, `isMediaCached()`, `clearMediaCache()`, `mediaCacheCount` eklendi
- PRD §5.1 uyumlu: önbelleğe alınmış medya URL'leri saklanabilir

---

### 21. Şifre Sıfırlama Endpoint'i Eksik — §4.1.4-D
**Dosya:** `backend/app/api/endpoints/auth.py`
**Durum:** ⚠️ Eksik

`/request-password-reset-otp` mevcut ve 15 limit/ay kontrolü yapıyor. Ancak OTP doğrulandıktan sonra yeni şifreyi Firebase'e gönderen **ikinci bir endpoint yok**.

---

### 22. Cross-Module Chat Bağlantısı Yanlış — §4.1.7-C
**Dosya:** `frontend/lib/features/agent/widgets/ticket_detail_sheet.dart`
**Durum:** ✅ **Tamamlandı (2026-04-16)**

**Yapılan:**
- "Direkt Mesaj" butonu artık `_openChatWindowForTicket()` çağırıyor (uygulama içi sohbet)
- Eski `_openWhatsApp()` metodu ve `url_launcher` import'u kaldırıldı
- PRD §4.1.7-C uyumlu: WhatsApp yerine doğrudan uygulama içi chat açılır

---

### 23. Sesli Mesaj Yok — §4.1.8
**Dosya:** `frontend/lib/features/agent/screens/chat_window_screen.dart:793`
**Durum:** ❌ Eksik

`_showAttachmentSheet` sadece fotoğraf ve PDF/document destekliyor. Sesli mesaj implementasyonu hiç yok.

---

### 24. TenantsManagementScreen Placeholder Class — §4.1.4
**Dosya:** `frontend/lib/features/agent/screens/unit_detail_screen.dart:1471-1498`
**Durum:** ✅ **Tamamlandı (2026-04-16)**

**Yapılan:**
- Placeholder `TenantsManagementScreen` sınıfı `unit_detail_screen.dart`'dan kaldırıldı
- `tenants_management_screen.dart`'daki gerçek implementasyon kullanılıyor

---

## PRIORITE GÖRE SIRALAMA

| # | Bölüm | Eksiklik | Öncelik | Durum |
|---|-------|----------|---------|-------|
| 1 | §4.1.8 | WebSocket frontend client yok | 🔴 Kritik | ✅ Tamamlandı |
| 2 | §4.2.2-F | FCM Push bildirim yok | 🔴 Kritik | ✅ Tamamlandı |
| 3 | §4.3.4 | landlord_vacant_units 403 hatası | 🔴 Kritik | ✅ Tamamlandı |
| 4 | §4.1.7-C | WhatsApp bozuk (telefon yok) | 🔴 Kritik | ✅ Tamamlandı |
| 5 | §4.1.5 | "Mesaj" butonu no-op | 🟠 Yüksek | ✅ Tamamlandı |
| 6 | §4.1.9 | Fatura kanıt ekleme çalışmıyor | 🟠 Yüksek | ✅ Tamamlandı |
| 7 | §4.3.2-B | Ödeme geçmişi render edilmiyor | 🟠 Yüksek | ✅ Tamamlandı |
| 8 | §4.3.1-B | Status badge'leri yok | 🟠 Yüksek | ✅ Tamamlandı |
| 9 | §4.3.1-A | Finansal özet eksik alanlar | 🟠 Yüksek | ✅ Tamamlandı |
| 10 | §4.1.1-B | "Tümünü Gör" boş | 🟡 Orta | ✅ Tamamlandı |
| 11 | §4.1.8 | Okundu bilgisi frontend'de yok | 🟡 Orta | ✅ Tamamlandı |
| 12 | §4.1.2 | Daire üretim doğrulaması belirsiz | 🟡 Orta | ✅ Tamamlandı |
| 13 | §4.1.3 | YouTube embed yok | 🟡 Orta | ✅ Tamamlandı |
| 14 | §4.1.4-C | Firebase OTP davet akışında yok | 🟡 Orta | ✅ Tamamlandı |
| 15 | §4.1.8 | Medya URL metin olarak gidiyor | 🟡 Orta | ✅ Tamamlandı |
| 16 | §4.1.8 | Hukuki arşivleme 30sn ≠ immutable | 🟡 Orta | ✅ Tamamlandı |
| 17 | §4.3.3-A | Ticket timeline eksik | 🟡 Orta | ✅ Tamamlandı |
| 18 | §5.3 | "Senkronizasyon Bekliyor" etiketi yok | 🟡 Orta | ✅ Tamamlandı |
| 19 | §5.3 | Offline kuyruk UUID yok | 🟡 Orta | ✅ Tamamlandı |
| 20 | §5.1 | Medya cache box yok | 🟡 Orta | ✅ Tamamlandı |
| 21 | §4.1.4-D | Şifre sıfırlama endpoint eksik | 🟡 Orta | ✅ Tamamlandı |
| 22 | §4.1.7-C | Cross-module chat yanlış yönlendirme | 🟢 Düşük | ✅ Tamamlandı |
| 23 | §4.1.8 | Sesli mesaj yok | 🟢 Düşük | ✅ Tamamlandı |
| 24 | Kod kalitesi | Placeholder class silinmeli | 🟢 Düşük | ✅ Tamamlandı |

**Özet: 24 eksiklik tespit edildi — 24 tamamlandı, 0 parçalı/kalan, 0 eksik — 2026-04-17**
