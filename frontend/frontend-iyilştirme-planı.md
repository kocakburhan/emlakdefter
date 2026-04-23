# Frontend İyileştirme Planı - v2.0

## 1. Tema & Görsel Kimlik

### 1.1 Renk Paleti (Modern Minimalist)
| Token | Hex | Kullanım |
|-------|-----|----------|
| `charcoal` | `#36454F` | Primary, headers, aktif elementler |
| `slateGray` | `#708090` | Accent, secondary text, borders |
| `lightGray` | `#D3D3D3` | Dividers, disabled states, backgrounds |
| `white` | `#FFFFFF` | Text, card backgrounds, surfaces |
| `success` | `#10B981` | Ödeme tamam, olumlu durumlar |
| `warning` | `#F59E0B` | Bekleyen, yaklaşan ödemeler |
| `error` | `#EF4444` | Gecikmiş, hata durumları |

### 1.2 Tipografi
- **Headers:** DejaVu Sans Mono Bold
- **Body:** DejaVu Sans Mono Regular
- **Font Source:** `google_fonts` paketi üzerinden yüklenecek

### 1.3 Tasarım İlkeleri
- Yumuşak köşeler (12-16px radius)
- İnce, minimal border kullanımı
- Generous whitespace (nefes alan tasarım)
- Outlined ikonografi
- Az renk, maksimum okunabilirlik

---

## 2. Animasyon Kütüphaneleri

### 2.1 flutter_animate 4.5.2
**Kullanım Alanları:**
- Sayfa geçişleri (fade + slide)
- Kart animasyonları (staggered reveal)
- Listenin elemanlarının sıralı görünümü
- Mikro-interactionlar (button press, success feedback)
- Loading state animasyonları

**Temel Kullanım:**
```dart
// Staggered list reveal
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => items[index]
    .animate()
    .fadeIn(delay: (100 * index).ms)
    .slideX(begin: 0.1, end: 0),
)

// Card tap effect
Card(child: ...)
  .animate()
  .scale(begin: 1.0, end: 0.98, duration: 100.ms)
  .then()
  .scale(begin: 0.98, end: 1.0, duration: 100.ms)
```

### 2.2 Rive Runtime (Interactive Animasyonlar)
**Kullanım Alanları:**
- Dashboard'da kullanıcı aksiyonlarına gerçek-zamanlı tepki veren animasyonlar
- Ödeme başarılı/başarısız feedback
- Loading states için çekici loading animasyonları
- Boş durum (empty state) illüstrasyonları
- Onboarding flow animasyonları

**Rive Dosyaları (assets/rive/):**
| Dosya | Animasyon | Tetikleyici |
|-------|-----------|-------------|
| `success_check.riv` | Checkmark animasyonu | Ödeme onaylandığında |
| `error_x.riv` | X animasyonu | Hata durumlarında |
| `loading_dots.riv` | Yükleniyor dots | API bekleme |
| `empty_box.riv` | Boş kutu animasyonu | Liste boş olduğunda |
| `money_fly.riv` | Para uçuşu | Gelir gider işleminde |
| `house_pop.riv` | Ev pop-up | Yeni mülk eklendiğinde |
| `chat_bubble.riv` | Mesaj balonu | Yeni mesaj geldiğinde |

---

## 3. Eklenmesi Gereken Bağımlılıklar

### 3.1 pubspec.yaml Güncelleme
```yaml
dependencies:
  # Mevcut...
  flutter_animate: ^4.5.2
  rive: ^0.13.4

dev_dependencies:
  # Mevcut...
  rive_common: ^0.13.4
```

### 3.2 Assets Konfigürasyonu
```yaml
flutter:
  assets:
    - assets/rive/
```

---

## 4. Uygulama Sırası ve Detayları

### Faz 1: Tema Altyapısı
**Dosyalar:**
1. `lib/core/theme/colors.dart` - Yeni renk paleti
2. `lib/core/theme/app_theme.dart` - Minimalist theme config
3. `lib/core/theme/typography.dart` - Font stilleri

**Değişiklikler:**
- `AppColors` sınıfını yeni renklerle güncelle
- `ColorScheme.light` oluştur (minimalist light theme)
- `TextTheme` DejaVu Sans Mono ile yapılandır
- Elevated button, input decoration, card stillerini minimalist yap

### Faz 2: Auth Ekranları (5 ekran)
**Dosyalar:**
1. `lib/features/auth/screens/phone_login_screen.dart`
2. `lib/features/auth/screens/otp_verification_screen.dart`
3. `lib/features/auth/screens/role_selection_screen.dart`
4. `lib/features/auth/screens/simple_login_screen.dart`
5. `lib/features/auth/providers/auth_provider.dart`

**Animasyonlar:**
- Phone login: Slide-up fade-in form, shake on error
- OTP: Digit boxes scale-in staggered
- Role selection: Cards scale + shadow on select
- Rive: `success_check.riv` on login success

### Faz 3: Agent Dashboard & Navigation
**Dosyalar:**
1. `lib/features/agent/screens/agent_dashboard_screen.dart`
2. `lib/core/router/router.dart`

**Animasyonlar:**
- Bottom nav: Icon scale + color transition (300ms)
- Sayfa geçişi: Fade + slight slide (400ms)
- Rive: Tab değişiminde subtle feedback

### Faz 4: Agent Home Tab
**Dosyalar:**
1. `lib/features/agent/tabs/home_tab.dart`
2. `lib/features/agent/providers/dashboard_provider.dart`

**Animasyonlar:**
- KPI kartları: Staggered fade-in (100ms delay each)
- Aktivite feed: Slide-in from right
- Refresh: Pull-down bounce effect
- Rive: Boş durum için `empty_box.riv`

### Faz 5: Agent Properties Tab
**Dosyalar:**
1. `lib/features/agent/tabs/properties_tab.dart`
2. `lib/features/agent/screens/property_detail_screen.dart`
3. `lib/features/agent/screens/unit_detail_screen.dart`
4. `lib/features/agent/widgets/create_property_bottom_sheet.dart`
5. `lib/features/agent/providers/properties_provider.dart`

**Animasyonlar:**
- Property list: Staggered card reveal
- Create property: Bottom sheet slide-up with form fields fade-in
- Property card tap: Scale to 0.98, ripple effect
- Rive: `house_pop.riv` on new property added

### Faz 6: Agent Finance Tab
**Dosyalar:**
1. `lib/features/agent/tabs/finance_tab.dart`
2. `lib/features/agent/screens/mali_rapor_screen.dart`
3. `lib/features/agent/providers/finance_provider.dart`

**Animasyonlar:**
- Finance cards: Count-up number animation
- Tab switching: Cross-fade
- Transaction items: Slide-in with swipe action
- Rive: `money_fly.riv` on income, `error_x.riv` on expense error

### Faz 7: Agent Support Tab
**Dosyalar:**
1. `lib/features/agent/tabs/support_tab.dart`
2. `lib/features/agent/widgets/ticket_detail_sheet.dart`
3. `lib/features/agent/widgets/ticket_chat_bottom_sheet.dart`
4. `lib/features/agent/providers/support_provider.dart`

**Animasyonlar:**
- Ticket cards: Color-coded fade-in by priority
- Status badges: Pulse animation for urgent
- Timeline: Sequential slide-in messages
- Rive: `chat_bubble.riv` on new message

### Faz 8: Agent Building Operations Tab
**Dosyalar:**
1. `lib/features/agent/tabs/building_operations_tab.dart`
2. `lib/features/agent/screens/pending_operations_screen.dart`
3. `lib/features/agent/providers/building_operations_provider.dart`

**Animasyonlar:**
- Operation logs: Reverse chronological reveal
- Filter chips: Scale + fade on select
- New operation: Card pop-in from bottom

### Faz 9: Agent Chat
**Dosyalar:**
1. `lib/features/agent/tabs/chat_tab.dart`
2. `lib/features/agent/screens/chat_window_screen.dart`
3. `lib/features/agent/providers/chat_provider.dart`

**Animasyonlar:**
- Conversation list: Slide-in from right
- Messages: Bubble scale-in from relevant side
- Send button: Pulse on new message
- Rive: `chat_bubble.riv` continuous subtle animation

### Faz 10: Agent Ek Detay Ekranları
**Dosyalar:**
1. `lib/features/agent/screens/tenants_management_screen.dart`
2. `lib/features/agent/screens/bi_analytics_screen.dart`
3. `lib/features/agent/screens/activity_feed_screen.dart`
4. `lib/features/agent/screens/scheduler_control_screen.dart`

**Animasyonlar:**
- Charts: Draw-in animation on appear
- Data cards: Count-up animations
- Timeline: Staggered event reveal

### Faz 11: Tenant (Kiracı) Tüm Ekranlar
**Dosyalar:**
1. `lib/features/tenant/screens/tenant_dashboard_screen.dart`
2. `lib/features/tenant/tabs/tenant_home_tab.dart`
3. `lib/features/tenant/tabs/tenant_finance_tab.dart`
4. `lib/features/tenant/tabs/tenant_support_tab.dart`
5. `lib/features/tenant/tabs/tenant_documents_tab.dart`
6. `lib/features/tenant/tabs/tenant_building_ops_tab.dart`
7. `lib/features/tenant/tabs/tenant_chat_tab.dart`
8. `lib/features/tenant/tabs/tenant_explore_tab.dart`
9. `lib/features/tenant/providers/tenant_provider.dart`

**Animasyonlar:**
- Dashboard: Welcome fade-in, cards staggered
- Finance: Payment status cards with color transitions
- Support: Ticket submission success with checkmark
- Explore: Property cards grid with hover/tap effects
- Rive: `success_check.riv` on payment confirmed

### Faz 12: Landlord (Ev Sahibi) Tüm Ekranlar
**Dosyalar:**
1. `lib/features/landlord/screens/landlord_dashboard_screen.dart`
2. `lib/features/landlord/screens/landlord_properties_screen.dart`
3. `lib/features/landlord/screens/landlord_tenant_performance_screen.dart`
4. `lib/features/landlord/screens/landlord_operations_screen.dart`
5. `lib/features/landlord/screens/landlord_investment_screen.dart`
6. `lib/features/landlord/providers/landlord_provider.dart`

**Animasyonlar:**
- Dashboard: Portfolio overview cards
- Property details: Tenant performance timeline
- Operations: Transparent log reveal
- Investment: Opportunity cards with hover effects

### Faz 13: Global Components & Reusable Animations
**Dosyalar:**
1. `lib/core/widgets/animated_card.dart` - Tüm kartlar için base
2. `lib/core/widgets/loading_indicator.dart` - Rive tabanlı
3. `lib/core/widgets/empty_state.dart` - Rive illüstrasyonlu
4. `lib/core/widgets/success_feedback.dart` - Rive success animasyonu

---

## 5. Rive Animasyon Detayları

### 5.1 Global Rive Assets (assets/rive/)
```
assets/
  rive/
    success_check.riv      # Ödeme/İşlem başarılı
    error_x.riv            # Hata durumu
    loading_dots.riv       # Yükleniyor
    empty_box.riv          # Boş liste
    money_fly.riv          # Para animasyonu
    house_pop.riv          # Yeni mülk
    chat_bubble.riv        # Mesaj bildirimi
    pulse_ring.riv         # Acil/Önemli bildirim
```

### 5.2 Rive Kullanım Pattern
```dart
class RiveAnimation extends StatefulWidget {
  final String assetPath;
  final String stateMachine;
  final String? input;

  @override
  Widget build(BuildContext context) {
    return RiveAnimation.asset(
      assetPath,
      stateMachine: stateMachine,
      onInit: (artboard) {
        final input = artboard.library.service<String>(stateMachine);
        input?.value = inputValue;
      },
    );
  }
}
```

---

## 6. flutter_animate Kullanım Detayları

### 6.1 Sayfa Geçişleri
```dart
// Custom page transition
PageRouteBuilder(
  pageBuilder: (context, animation, secondaryAnimation) => Screen(),
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(begin: Offset(0.05, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: child,
      ),
    );
  },
)
```

### 6.2 Staggered List
```dart
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => items[index]
    .animate()
    .fadeIn(delay: (50 * index).ms, duration: 300.ms)
    .slideX(begin: 0.1, end: 0, delay: (50 * index).ms),
)
```

### 6.3 Card Press Effect
```dart
GestureDetector(
  onTapDown: (_) => controller.forward(),
  onTapUp: (_) => controller.reverse(),
  onTapCancel: () => controller.reverse(),
  child: AnimatedBuilder(
    animation: controller,
    builder: (context, child) => Transform.scale(
      scale: 1 - (controller.value * 0.02),
      child: child,
    ),
    child: Card(...),
  ),
)
```

---

## 7. Uygulama Sıralaması (Checklist)

✅ **TAMAMLANDI - 2026-04-18**

- [x] **Faz 1:** pubspec.yaml - flutter_animate + rive ekle ✅
- [x] **Faz 1:** assets/rive/ klasörü oluştur + .riv dosyaları ✅
- [x] **Faz 1:** colors.dart güncelle ✅
- [x] **Faz 1:** app_theme.dart güncelle ✅
- [x] **Faz 2:** Auth ekranları (5 adet) ✅
- [x] **Faz 3:** Agent dashboard + navigation ✅
- [x] **Faz 4:** Agent home tab ✅
- [x] **Faz 5:** Agent properties tab (properties_tab + property_detail + unit_detail + create_property_bottom_sheet) ✅
- [x] **Faz 6:** Agent finance tab ✅
- [x] **Faz 7:** Agent support tab (support_tab + ticket_detail_sheet + ticket_chat_bottom_sheet) ✅
- [x] **Faz 8:** Agent building operations tab ✅
- [x] **Faz 9:** Agent chat tab (chat_tab + chat_window_screen) ✅
- [x] **Faz 10:** Agent ekranları (bi_analytics, activity_feed, scheduler_control, tenants_management, pending_operations) ✅
- [x] **Faz 11:** Tenant tüm ekranlar ✅
- [x] **Faz 12:** Landlord tüm ekranlar ✅
- [x] **Faz 13:** Global reusable widgets ✅

**Renk Dönüşümleri:**
- `AppColors.accent` → `AppColors.charcoal` (#36454F)
- `AppColors.textHeader` → `AppColors.charcoal`
- `AppColors.textBody` → `AppColors.textSecondary` (#708090)

---

## 8. Beklenen Sonuçlar

- **Tema:** Sade, modern, minimalist beyaz yüzey + charcoal metin
- **Animasyonlar:** Pürüzsüz, 300-400ms geçişler, staggered reveals
- **Rive:** İnteraktif feedback, boş durum illüstrasyonları, başarı/hata animasyonları
- **Performans:** Animasyonlar GPU-friendly, 60fps hedef
- **Kod:** Tutarlı animasyon API'si, tekrar kullanılabilir widget'lar

---

## 9. Notlar

- Rive dosyaları Harviab.com veya Rive Editör ile oluşturulacak
- Animasyon timing değerleri test edilerek ayarlanacak
- Dark mode desteği şimdilik优先级 dışı (v2'de)
- Tüm ekranlar flutter_animate ile refactor edilecek

---

## 10. Eksiklikler (2026-04-18)

### Giderilen Eksiklikler

1. **typography.dart dosyası oluşturuldu** ✅
   - `lib/core/theme/typography.dart` oluşturuldu
   - Tüm font stilleri (display, headline, title, body, label, button, caption, overline) tanımlandı
   - `textTheme` getter'ı eklendi

2. **Rive bağımlılıkları kaldırıldı** ✅
   - `rive: ^0.13.4` ve `rive_common: ^0.13.4` pubspec.yaml'den kaldırıldı
   - `assets/rive/` asset configuration kaldırıldı
   - Tüm Rive import'ları temizlendi

3. **Animasyonlar flutter_animate ile yeniden yazıldı** ✅
   - `empty_state.dart` - Rive yerine flutter_animate scale/fade animasyonları
   - `success_feedback.dart` - Rive yerine flutter_animate elasticOut scale + fade
   - `AnimatedCheckmark`, `AnimatedErrorX`, `PulseWidget` eklendi
   - Tüm animasyonlar şimdi flutter_animate ile çalışıyor

### Animasyon Kütüphanesi

**Kullanılan:** flutter_animate 4.5.2

**Eklenen Widget'lar:**
- `AnimatedCheckmark` - Başarı durumu için scale + fade animasyonu
- `AnimatedErrorX` - Hata durumu için scale + fade animasyonu
- `PulseWidget` - Acil/önemli bildirimler için pulse efekti
- `AnimatedEmptyState` - Özelleştirilebilir boş durum widget'ı

### Not

- Rive artık kullanılmıyor - tüm animasyonlar flutter_animate ile yapılıyor
- AnimatedSwitcher, FadeIn, SlideTransition, scale, fade animasyonları kullanılıyor
