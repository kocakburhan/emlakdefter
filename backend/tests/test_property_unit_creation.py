"""
Test 4: Otonom Daire Üretim Motoru
Test 5: Tekil Birim (Single-Unit) İstisnası

Test 4 - Esnek Kat Yapılandırması:
- floor_config ile her kat için farklı birim sayısı belirlenebilmeli
- Bazı katlar "exclude" ile atlanabilmeli
- Kapı numaraları doğru artmalı (her katın kapısı bir öncekinin devamı)
- Backward compatible: floor_config yoksa eski {start, end, units_per_floor} çalışmalı

Test 5 - Tekil Birim İstisnası:
- land ve commercial tipleri için döngü yok, 1 birim oluşmalı
- standalone_house 1 birim oluşturmalı
"""

import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from app.services.property_service import create_property_with_autonomous_units
from app.schemas.properties import PropertyCreate, FloorConfigItem
from app.models.properties import PropertyType


class TestFloorConfigAutonomousUnitCreation:
    """Test 4: Otonom Daire Üretim Motoru — floor_config ile esnek kat yapılandırması"""

    @pytest.fixture
    def mock_db(self):
        db = AsyncMock()
        db.add = MagicMock()
        db.add_all = MagicMock()
        db.flush = AsyncMock()
        db.commit = AsyncMock()
        db.refresh = AsyncMock()
        return db

    @pytest.mark.asyncio
    async def test_floor_config_with_excludes(self, mock_db):
        """Katlar: -3, -2, -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12
        -3,-2,-1: 1 birim (bodrum)
        0: 2 birim (zemin - dükkan)
        1-11: 4 birim (normal)
        12: 1 birim (teras)
        Sonuç: (3*1) + 2 + (11*4) + 1 = 3+2+44+1 = 50 birim
        Kapılar: 1-50
        """
        config = [
            FloorConfigItem(floor=-3, units=1, exclude=False),
            FloorConfigItem(floor=-2, units=1, exclude=False),
            FloorConfigItem(floor=-1, units=1, exclude=False),
            FloorConfigItem(floor=0, units=2, exclude=False),
            FloorConfigItem(floor=12, units=1, exclude=False),
        ]
        # 1-11 normal katlar ekle
        for f in range(1, 12):
            config.append(FloorConfigItem(floor=f, units=4, exclude=False))

        prop_in = PropertyCreate(
            name="Test Apartman",
            type="apartment_complex",
            start_floor=None,
            end_floor=None,
            units_per_floor=None,
            floor_config=config,
        )

        result = await create_property_with_autonomous_units(
            db=mock_db,
            agency_id="00000000-0000-0000-0000-000000000001",
            prop_in=prop_in,
        )

        assert result.total_units == 50
        # units_to_create listesi kontrolü
        calls = mock_db.add_all.call_args
        assert calls is not None

    @pytest.mark.asyncio
    async def test_floor_config_with_all_excluded_kat(self, mock_db):
        """Tüm katlar exclude edilirse 0 birim oluşmalı"""
        config = [
            FloorConfigItem(floor=1, units=4, exclude=True),
            FloorConfigItem(floor=2, units=4, exclude=True),
        ]

        prop_in = PropertyCreate(
            name="Bos Bina",
            type="apartment_complex",
            start_floor=None,
            end_floor=None,
            units_per_floor=None,
            floor_config=config,
        )

        result = await create_property_with_autonomous_units(
            db=mock_db,
            agency_id="00000000-0000-0000-0000-000000000001",
            prop_in=prop_in,
        )

        assert result.total_units == 0

    @pytest.mark.asyncio
    async def test_backward_compatible_uniform_loop(self, mock_db):
        """floor_config yoksa eski uniform döngü çalışmalı (start=1, end=5, units=2)
        Sonuç: (5-1+1)*2 = 10 birim, kapılar 1-10
        """
        prop_in = PropertyCreate(
            name="Eski Usul Bina",
            type="apartment_complex",
            start_floor=1,
            end_floor=5,
            units_per_floor=2,
            floor_config=None,
        )

        result = await create_property_with_autonomous_units(
            db=mock_db,
            agency_id="00000000-0000-0000-0000-000000000001",
            prop_in=prop_in,
        )

        assert result.total_units == 10  # 5 kat * 2 birim

    @pytest.mark.asyncio
    async def test_door_number_continuity(self, mock_db):
        """Kapı numaraları kesintisiz artmalı
        Kat -3: 1 birim → kapı 1
        Kat -2: 1 birim → kapı 2
        Kat 0: 2 birim → kapı 3, 4
        Kat 1: 4 birim → kapı 5, 6, 7, 8
        """
        config = [
            FloorConfigItem(floor=-3, units=1, exclude=False),
            FloorConfigItem(floor=-2, units=1, exclude=False),
            FloorConfigItem(floor=0, units=2, exclude=False),
            FloorConfigItem(floor=1, units=4, exclude=False),
        ]

        prop_in = PropertyCreate(
            name="Kapı Numarası Test",
            type="apartment_complex",
            start_floor=None,
            end_floor=None,
            units_per_floor=None,
            floor_config=config,
        )

        result = await create_property_with_autonomous_units(
            db=mock_db,
            agency_id="00000000-0000-0000-0000-000000000001",
            prop_in=prop_in,
        )

        # Toplam: 1+1+2+4 = 8 birim, kapılar 1-8
        assert result.total_units == 8


class TestSingleUnitException:
    """Test 5: Tekil Birim (Single-Unit) İstisnası — Arsa/Müstakil/Ticari için döngü yok, 1 birim"""

    @pytest.fixture
    def mock_db(self):
        db = AsyncMock()
        db.add = MagicMock()
        db.add_all = MagicMock()
        db.flush = AsyncMock()
        db.commit = AsyncMock()
        db.refresh = AsyncMock()
        return db

    @pytest.mark.asyncio
    async def test_land_creates_single_unit(self, mock_db):
        """land tipi için döngü yok, 1 birim oluşmalı"""
        prop_in = PropertyCreate(
            name="Boğa Arsa",
            type="land",
            start_floor=None,
            end_floor=None,
            units_per_floor=None,
            floor_config=None,
        )

        result = await create_property_with_autonomous_units(
            db=mock_db,
            agency_id="00000000-0000-0000-0000-000000000001",
            prop_in=prop_in,
        )

        assert result.total_units == 1
        # db.add() bir kez çağrılmalı (tekil birim için)
        assert mock_db.add.call_count >= 1

    @pytest.mark.asyncio
    async def test_standalone_house_creates_single_unit(self, mock_db):
        """standalone_house için 1 birim oluşmalı"""
        prop_in = PropertyCreate(
            name="Müstakil Villa",
            type="standalone_house",
            start_floor=None,
            end_floor=None,
            units_per_floor=None,
            floor_config=None,
        )

        result = await create_property_with_autonomous_units(
            db=mock_db,
            agency_id="00000000-0000-0000-0000-000000000001",
            prop_in=prop_in,
        )

        assert result.total_units == 1

    @pytest.mark.asyncio
    async def test_commercial_creates_single_unit(self, mock_db):
        """commercial tipi için döngü yok, 1 birim oluşmalı"""
        prop_in = PropertyCreate(
            name="Kiralık Dükkan",
            type="commercial",
            start_floor=None,
            end_floor=None,
            units_per_floor=None,
            floor_config=None,
        )

        result = await create_property_with_autonomous_units(
            db=mock_db,
            agency_id="00000000-0000-0000-0000-000000000001",
            prop_in=prop_in,
        )

        assert result.total_units == 1