# Test 4 — Otonom Daire Üretim Motoru Implementasyon Spec

## Mevcut Durum
- `start_floor` → UI'da YOK, backend'e sabit 1 gönderiliyor
- `end_floor` → "Kat Sayısı" olarak backend'e gönderiliyor (aslında max floor number)
- `units_per_floor` → Uniform, her katta aynı sayıda birim
- Ön izleme, esnek kat yapılandırması, birim silme → HİÇ YOK

## Hedef Davranış

### Adım 1: Başlangıç ve Bitiş Katı Seçimi
- **Başlangıç katı**: Dropdown ile seçilecek (-3, -2, -1, 0, 1, 2... 20)
- **Bitiş katı**: Number input (örn. 12)
- Örn: Başlangıç = -3, Bitiş = 12 → 16 kat (bodrum 3'ten 12. kata)

### Adım 2: Her Kat İçin Birim Sayısı Belirleme
- Her kat için ayrı ayrı birim sayısı girilebilir
- Varsayılan: Tüm katlara aynı birim sayısı uygulanır (kullanıcı değiştirebilir)
- Esnek senaryolar:
  - Zemin kat (0): 2 dükkân + 1 apartman girişi
  - -1, -2: 1 birim (bodrum)
  - 12. kat: 1 birim (teras)
  - Normal katlar: 4 birim

### Adım 3: Ön İzleme
- "Önizleme" butonu tıklandığında tüm oluşturulacak birimler listelenir
- Her satırda: Kat numarası, kapı numaraları, birim sayısı
- Kullanıcı bu ekranda herhangi bir birimi/katı çıkarabilir

### Adım 4: Onay ve Üretim
- "Oluştur" butonu → Backend'e JSON olarak kat yapılandırması gönderilir
- Backend döngü yerine yapılandırılmış kat verisini işler

## Backend Değişikliği

### Mevcut API
```json
POST /api/properties/
{
  "start_floor": 1,
  "end_floor": 8,
  "units_per_floor": 3
}
→ Uniform döngüsel üretim
```

### Yeni API (Backward Compatible)
```json
POST /api/properties/
{
  "start_floor": -3,
  "end_floor": 12,
  "floor_config": [
    {"floor": -3, "units": 1, "exclude": false},
    {"floor": -2, "units": 1, "exclude": false},
    {"floor": -1, "units": 1, "exclude": false},
    {"floor": 0, "units": 2, "exclude": false},
    {"floor": 1, "units": 4, "exclude": false},
    ...
    {"floor": 12, "units": 1, "exclude": false}
  ]
}
```

**Not:** `floor_config` yoksa eski `{start_floor, end_floor, units_per_floor}` kullanılır (backward compatible).

## Frontend UI Akışı

### Ekrandaki Adımlar (3 sekme halinde):

**Step 1 — Kat Yapılandırması**
- Başlangıç katı dropdown
- Bitiş katı input
- Varsayılan birim/kat input
- "Tüm katlara uygula" butonu

**Step 2 — Kat Bazlı Düzenleme**
- Liste halinde her kat
- Her satırda: Kat no, birim sayısı spinner, çıkar/kaldır toggle
- Toplam birim sayısı ve özet bilgi

**Step 3 — Ön İzleme ve Onay**
- Tablo halinde tüm oluşturulacak birimler
- Toplam birim: X, Toplam kat: Y
- "Oluştur" butonu

## Kapı Numarası Üretim Formülü

```
Kat -3: Kapı 1
Kat -2: Kapı 2
Kat -1: Kapı 3
Kat 0: Kapı 4, 5
Kat 1: Kapı 6, 7, 8, 9
...
```

Her katın kapı numarası bir önceki katın son kapısı + 1'den başlar.

## Dosyaları Etkileyen Değişiklikler

| Dosya | Değişiklik |
|-------|------------|
| `backend/app/schemas/properties.py` | `floor_config` alanı ekle |
| `backend/app/services/property_service.py` | Esnek kat yapılandırması işleme |
| `backend/app/api/endpoints/properties.py` | Yeni schema'yı aktar |
| `frontend/lib/.../create_property_bottom_sheet.dart` | Çok adımlı kat yapılandırma UI |
| `frontend/lib/.../providers/properties_provider.dart` | floor_config desteği |

## Test Durumu Kontrolü

✅ Her kat için esnek birim sayısı belirlenebilmeli
✅ Bazı katlar "hariç" olarak işaretlenebilmeli (örn. teras katı)
✅ Ön izleme doğru kapı numaralarını göstermeli
✅ Backend uniform döngüyü de desteklemeli (backward compatible)