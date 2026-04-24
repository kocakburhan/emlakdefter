#!/usr/bin/env python3
"""
Geliştirme için test verisi oluşturur.
DEV_MODE=true iken upload-statement test etmek için gerekli.

Kullanım:
    cd backend
    python seed_dev.py
"""
import asyncio
import uuid
from datetime import date, timedelta
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.models.base import Base
from app.models.users import User, Agency, AgencyStaff, GlobalUserRole, StaffRole, UserRole
from app.models.tenants import Tenant, ContractStatus
from app.models.properties import Property, PropertyUnit
from app.models.finance import PaymentSchedule, PaymentStatus, TransactionCategory


DEV_AGENCY_ID = uuid.UUID("00000000-0000-0000-0000-000000000001")
DEV_USER_ID = uuid.UUID("00000000-0000-0000-0000-000000000001")

ASYNC_DB_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+asyncpg://emlakdefter_user:emlakdefter_password@127.0.0.1:5433/emlakdefter"
)


async def seed():
    engine = create_async_engine(ASYNC_DB_URL, echo=False)

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with async_session() as db:
        # 1. Agency - upsert
        result = await db.execute(select(Agency).where(Agency.id == DEV_AGENCY_ID))
        agency = result.scalar_one_or_none()
        if agency is None:
            agency = Agency(
                id=DEV_AGENCY_ID,
                name="EmlakDefter Test Ofisi",
                subscription_status="trial",
            )
            db.add(agency)
            await db.flush()
            print("[+] Agency oluşturuldu")
        else:
            print("[=] Agency zaten var")

        # 2. User - upsert
        result = await db.execute(select(User).where(User.phone_number == "+905551234567"))
        user = result.scalar_one_or_none()
        if user is None:
            user = User(
                id=DEV_USER_ID,
                phone_number="+905551234567",
                full_name="Test Emlakçı",
                role=UserRole.boss,
                status="active",
            )
            db.add(user)
            await db.flush()
            print("[+] User oluşturuldu")
        else:
            print(f"[=] User zaten var: {user.full_name}")

        # 3. AgencyStaff - upsert
        result = await db.execute(
            select(AgencyStaff).where(
                AgencyStaff.agency_id == DEV_AGENCY_ID,
                AgencyStaff.user_id == user.id
            )
        )
        staff = result.scalar_one_or_none()
        if staff is None:
            staff = AgencyStaff(
                agency_id=DEV_AGENCY_ID,
                user_id=user.id,
                role=StaffRole.boss,
            )
            db.add(staff)
            await db.flush()
            print("[+] AgencyStaff oluşturuldu")
        else:
            print("[=] AgencyStaff zaten var")

        # 4. Property - upsert
        property_id = uuid.UUID("00000000-0000-0000-0000-000000000010")
        result = await db.execute(select(Property).where(Property.id == property_id))
        prop = result.scalar_one_or_none()
        if prop is None:
            prop = Property(
                id=property_id,
                agency_id=DEV_AGENCY_ID,
                name="Test Residence",
                type="standalone_house",
                address="İstanbul, Türkiye",
            )
            db.add(prop)
            await db.flush()
            print("[+] Property oluşturuldu")
        else:
            print(f"[=] Property zaten var: {prop.name}")

        # 5. PropertyUnit - upsert
        unit_id = uuid.UUID("00000000-0000-0000-0000-000000000020")
        result = await db.execute(select(PropertyUnit).where(PropertyUnit.id == unit_id))
        unit = result.scalar_one_or_none()
        if unit is None:
            unit = PropertyUnit(
                id=unit_id,
                property_id=property_id,
                agency_id=DEV_AGENCY_ID,
                door_number="101",
                floor="1",
            )
            db.add(unit)
            await db.flush()
            print("[+] PropertyUnit oluşturuldu")
        else:
            print("[=] PropertyUnit zaten var")

        # 6. Kiracılar
        kiracilar = [
            {
                "id": uuid.UUID("00000000-0000-0000-0000-000000000030"),
                "temp_name": "Ahmet Yilmaz",
                "temp_phone": "+905551000001",
                "rent_amount": 25000,
                "payment_day": 5,
            },
            {
                "id": uuid.UUID("00000000-0000-0000-0000-000000000031"),
                "temp_name": "Ayse Demir",
                "temp_phone": "+905551000002",
                "rent_amount": 30000,
                "payment_day": 15,
            },
            {
                "id": uuid.UUID("00000000-0000-0000-0000-000000000032"),
                "temp_name": "Mehmet Kaya",
                "temp_phone": "+905551000003",
                "rent_amount": 20000,
                "payment_day": 1,
            },
        ]

        for k_data in kiracilar:
            result = await db.execute(select(Tenant).where(Tenant.id == k_data["id"]))
            tenant = result.scalar_one_or_none()
            if tenant is None:
                tenant = Tenant(
                    id=k_data["id"],
                    agency_id=DEV_AGENCY_ID,
                    unit_id=unit_id,
                    temp_name=k_data["temp_name"],
                    temp_phone=k_data["temp_phone"],
                    rent_amount=k_data["rent_amount"],
                    currency="TRY",
                    payment_day=k_data["payment_day"],
                    start_date=date.today() - timedelta(days=180),
                    end_date=date.today() + timedelta(days=185),
                    status=ContractStatus.active,
                )
                db.add(tenant)
                await db.flush()
                print(f"[+] Tenant oluşturuldu: {k_data['temp_name']}")
            else:
                print(f"[=] Tenant zaten var: {tenant.temp_name}")

            # 7. PaymentSchedule - upsert
            result = await db.execute(
                select(PaymentSchedule).where(
                    PaymentSchedule.tenant_id == k_data["id"],
                    PaymentSchedule.status == PaymentStatus.pending
                )
            )
            schedule = result.scalar_one_or_none()
            if schedule is None:
                schedule = PaymentSchedule(
                    agency_id=DEV_AGENCY_ID,
                    tenant_id=k_data["id"],
                    amount=k_data["rent_amount"],
                    due_date=date.today() - timedelta(days=3),
                    category=TransactionCategory.rent,
                    status=PaymentStatus.pending,
                )
                db.add(schedule)
                print(f"[+] PaymentSchedule oluşturuldu for: {k_data['temp_name']}")
            else:
                print(f"[=] PaymentSchedule zaten var for: {k_data['temp_name']}")

        await db.commit()
        print()
        print("[OK] Seed data hazir!")
        print(f"   Agency ID: {DEV_AGENCY_ID}")
        print(f"   User: +905551234567 (Test Emlakci)")
        print(f"   3 Aktif Kiraci: Ahmet Yilmaz, Ayse Demir, Mehmet Kaya")


if __name__ == "__main__":
    asyncio.run(seed())
