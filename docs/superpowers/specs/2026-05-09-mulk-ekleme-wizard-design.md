# Mülk Ekleme Wizard — Tip & İşlem Seçimi Tasarım Dokümanı

**Tarih:** 2026-05-09
**Durum:** Onaylandı

---

## 1. Genel Bakış

Yeni mülk ekleme akışı 2 aşamalı wizard olarak yeniden tasarlandı:
1. **Aşama 1:** Zorunlu tip seçimi (İşlem Tipi + Mülk Tipi)
2. **Aşama 2:** Koşullu form gösterimi (seçimlere göre dinamik)

---

## 2. Seçim Tanımları

### İşlem Tipi (Listing Type)
| Değer | Etiket | Açıklama |
|-------|-------|----------|
| `for_rent` | Kiralık | Mülk kiralık olarak listelenir |
| `for_sale` | Satılık | Mülk satılık olarak listelenir |
| `both` | Kiralık + Satılık | **YENİ** — Aynı mülk hem kiralık hem satılık olabilir |

### Mülk Tipi (Property Type)
| Değer | Etiket | Açıklama |
|-------|-------|----------|
| `apartment_complex` | Apartman/Site | Çoklu birim üretim motoru |
| `apartment_unit` | **Apartman Dairesi** | Tek birim, manuel ekleme |
| `standalone_house` | Müstakil Ev/Villa | Tekil mülk |
| `land` | Arsa/Tarla | Tekil mülk |
| `commercial` | Dükkan | Ticari alan |

---

## 3. Backend Değişiklikleri

### PropertyType Enum (backend/app/models/properties.py)
```python
class PropertyType(str, enum.Enum):
    apartment_complex = "apartment_complex"  # Apartman/Site
    apartment_unit = "apartment_unit"         # Apartman Dairesi (YENİ)
    standalone_house = "standalone_house"
    land = "land"
    commercial = "commercial"
```

### Property Tablosu (backend/app/models/properties.py)
Eklenecek alan:
```python
listing_type = Column(String, nullable=True)  # "for_rent" | "for_sale" | "both"
```

### PropertyUnit Tablosu (backend/app/models/properties.py)
Eklenecek alan:
```python
listing_type = Column(String, nullable=True)  # Her birim için ayrı tanımlanabilir
```

### PropertyCreate Schema (backend/app/schemas/properties.py)
```python
listing_type: Optional[str] = Field(None, description="'for_rent', 'for_sale' veya 'both'")
```

---

## 4. Frontend Değişiklikleri

### Enum Tanımları
```dart
enum PropertyFormType {
  apartment,     // → apartment_complex
  apartmentUnit, // → apartment_unit (YENİ)
  villa,         // → standalone_house
  land,
  commercial,
}

enum ListingType {
  forRent,   // "for_rent"
  forSale,   // "for_sale"
  both,      // "both" — YENİ
}
```

### PropertyModel
```dart
class PropertyModel {
  // ... mevcut alanlar ...
  final String? listingType; // "for_rent" | "for_sale" | "both"
}
```

---

## 5. UI Akışı

### Aşama 1: Tip Seçim Ekranı
- Ekran açıldığında kullanıcı 2 seçim yapmak zorunda:
  1. **İşlem Tipi:** Kiralık / Satılık / **Kiralık + Satılık**
  2. **Mülk Tipi:** Apartman/Site / **Apartman Dairesi** / Müstakil Ev / Arsa/Tarla / Dükkan
- "Devam" butonu sadece her iki seçim de yapıldığında aktif olur
- Seçim yapıldığında animasyonlu geçiş ile Aşama 2 formu gösterilir

### Aşama 2: Koşullu Form
| İşlem Tipi | Mülk Tipi | Form |
|-----------|-----------|------|
| any | apartment_complex | Mevcut çoklu üretim formu + listing_type |
| any | apartment_unit | **YENİ** — Tek birim formu |
| any | standalone_house | Mevcut villa formu + listing_type |
| any | land | Mevcut arsa formu + listing_type |
| any | commercial | Mevcut ticari formu + listing_type |

### Apartman Dairesi Formu (YENİ)
- Kapı Numarası
- Kat
- Aidat (₺)
- Kira Bedeli (kiralık seçildiyse)
- Satış Bedeli (satılık seçildiyse)
- Özellikler (balkon, asansör vb.)

---

## 6. Veritabanı Migrasyonı

```sql
ALTER TABLE properties ADD COLUMN listing_type VARCHAR(20);
ALTER TABLE property_units ADD COLUMN listing_type VARCHAR(20);

-- Constraints (opsiyonel)
ALTER TABLE properties ADD CONSTRAINT chk_listing_type
  CHECK (listing_type IN ('for_rent', 'for_sale', 'both') OR listing_type IS NULL);
```

---

## 7. Test Senaryoları

1. Kiralık + Apartman/Site → Çoklu üretim formu açılır
2. Satılık + Apartman Dairesi → Tek birim formu açılır
3. Kiralık + Satılık + Müstakil Ev → Villa formu + her iki fiyat alanı
4. Sadece Mülk Tipi seçildi, İşlem Tipi seçilmedi → Devam butonu aktif değil
5. API'ye doğru listing_type değeri gönderiliyor