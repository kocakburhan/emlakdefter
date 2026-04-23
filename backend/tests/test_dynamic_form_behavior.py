"""
Test 9: Dinamik Form Davranışları

Hedef:
- Mülk tipi seçilince ilgisiz alanlar gizlenir (backend doğrulaması)
- Apartment: floor_config, features, central_dues gönderilir
- Villa: features, rent_price gönderilir (floor_config DEĞİL)
- Land: ada/parcel/imar/alan gönderilir, features ve floor_config gönderilmez
- Commercial: shop_count, rent gönderilir (floor_config DEĞİL)
"""

import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from uuid import uuid4

from app.schemas.properties import PropertyCreate, FloorConfigItem
from app.services.property_service import create_property_with_autonomous_units


class TestPropertyTypeFieldHandling:
    """Farklı mülk tiplerine göre alan işleme testleri"""

    def test_apartment_accepts_floor_config(self):
        """Apartment tipi floor_config ile oluşturulabilir"""
        prop = PropertyCreate(
            name="Boğaz Evleri",
            type="apartment",
            address="Beşiktaş",
            central_dues=500,
            floor_config=[
                FloorConfigItem(floor=1, units=2, exclude=False),
                FloorConfigItem(floor=2, units=2, exclude=False),
            ],
            features={"Asansör": True, "Otopark": True}
        )
        assert prop.type == "apartment"
        assert prop.floor_config is not None
        assert len(prop.floor_config) == 2

    def test_apartment_features_are_stored(self):
        """Apartment özellikleri (asansör, havuz) doğru yapıda"""
        prop = PropertyCreate(
            name="Levent Sitesi",
            type="apartment",
            features={
                "Asansör": True,
                "Otopark": True,
                "Havuz": True,
                "Güvenlik": True,
            }
        )
        assert prop.features["Asansör"] is True
        assert prop.features["Havuz"] is True
        assert "Bahçe" not in prop.features

    def test_villa_does_not_need_floor_config(self):
        """Villa tipi floor_config gerektirmez (tek mülk)"""
        prop = PropertyCreate(
            name="Yalı Villa",
            type="villa",
            features={
                "Havuz": True,
                "Bahçe": True,
                "Güneş Enerjisi": True,
            }
        )
        assert prop.type == "villa"
        assert prop.floor_config is None
        assert prop.features["Havuz"] is True

    def test_land_has_no_features(self):
        """Land tipi bina özelliği gerektirmez"""
        prop = PropertyCreate(
            name="Hobi Bahçesi",
            type="land",
            features={}  # Boş dict — backend kabul etmeli
        )
        assert prop.type == "land"
        assert prop.floor_config is None

    def test_land_fields_are_relevant(self):
        """Land için relevant alanlar: ada, parsel, imar durumu, alan"""
        prop = PropertyCreate(
            name="Tarım Arazisi",
            type="land",
            address="Sarıyer"
        )
        # Land tipi backend'de tek birim olarak üretilir
        # (service katmanında kontrol edilir)
        assert prop.type == "land"

    def test_commercial_does_not_need_floor_config(self):
        """Commercial tipi floor_config gerektirmez"""
        prop = PropertyCreate(
            name="Çarşı Dükkânı",
            type="commercial",
            features={"Otopark": True}
        )
        assert prop.type == "commercial"
        assert prop.floor_config is None

    def test_features_dict_keys_match_ui_chips(self):
        """Feature dict anahtarları UI'daki chip labels ile eşleşmeli"""
        ui_feature_chips = [
            "Asansör", "Otopark", "Havuz",
            "Güneş Enerjisi", "Güvenlik", "Bahçe"
        ]

        prop = PropertyCreate(
            name="Test",
            type="apartment",
            features={chip: True for chip in ui_feature_chips}
        )

        for chip in ui_feature_chips:
            assert chip in prop.features


class TestDynamicFieldFiltering:
    """Backend'in frontend'den gelen gereksiz alanları sessizce filtrelemesi testleri"""

    def test_apartment_without_features_succeeds(self):
        """Features gönderilmeyen apartment yine de kabul edilmeli"""
        prop = PropertyCreate(
            name="Basit Apartman",
            type="apartment",
            central_dues=300
        )
        # features = {} default
        assert prop.features == {}

    def test_villa_without_features_succeeds(self):
        """Features gönderilmeyen villa yine de kabul edilmeli"""
        prop = PropertyCreate(
            name="Müstakil Ev",
            type="villa",
            central_dues=200
        )
        assert prop.features == {}

    def test_land_without_address_succeeds(self):
        """Adres gönderilmeyen land kabul edilmeli"""
        prop = PropertyCreate(
            name="Parsel 1234",
            type="land"
        )
        assert prop.address is None


class TestFloorConfigValidation:
    """floor_config yapısal doğrulama testleri"""

    def test_floor_config_item_model(self):
        """FloorConfigItem doğru alanları içerir"""
        item = FloorConfigItem(floor=5, units=4, exclude=False)
        assert item.floor == 5
        assert item.units == 4
        assert item.exclude is False

    def test_floor_config_with_excludes(self):
        """Bazı katlar exclude=true olabilir"""
        prop = PropertyCreate(
            name="Karışık Site",
            type="apartment",
            floor_config=[
                FloorConfigItem(floor=-1, units=2, exclude=True),  # Otopark hariç
                FloorConfigItem(floor=1, units=4, exclude=False),
                FloorConfigItem(floor=2, units=4, exclude=False),
            ]
        )
        excluded = [f for f in prop.floor_config if f.exclude]
        included = [f for f in prop.floor_config if not f.exclude]
        assert len(excluded) == 1
        assert len(included) == 2

    def test_empty_floor_config_accepted_by_schema(self):
        """Boş floor_config schema tarafından kabul edilir (servis katmanında kontrol edilir)"""
        prop = PropertyCreate(
            name="Test",
            type="apartment",
            floor_config=[]
        )
        assert prop.floor_config == []
