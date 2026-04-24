#!/usr/bin/env python3
"""
Superadmin kullanıcı oluşturma scripti.

Kullanım:
    cd backend
    python create_superadmin.py

Script sırayla şunları isteyecek:
    - Email: Firebase Console'da kullandığın email
    - Firebase UID: Firebase Console'dan aldığın UID
    - Full Name: Kullanıcı adı
    - Password: Firebase Console'da belirlediğin şifre (aynısı DB'ye hash'lenerek kaydedilir)
"""

import asyncio
import uuid
import os
import getpass
import bcrypt
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from sqlalchemy import text

# Database URL - .env dosyasından al veya direkt yaz
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+asyncpg://emlakdefter_user:emlakdefter_password@127.0.0.1:5433/emlakdefter"
)


async def create_superadmin(email: str, firebase_uid: str, full_name: str, password: str):
    engine = create_async_engine(DATABASE_URL, echo=False)
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    # Şifreyi hash'le
    password_hash = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

    async with async_session() as db:
        # Email veya UID ile zaten var mı kontrol et
        result = await db.execute(
            text("SELECT id, email, role FROM users WHERE email = :email OR firebase_uid = :uid"),
            {"email": email.lower(), "uid": firebase_uid}
        )
        existing = result.fetchone()

        if existing:
            # Güncelle
            await db.execute(
                text("""
                    UPDATE users SET password_hash = :hash, full_name = :name,
                    firebase_uid = :uid WHERE email = :email
                """),
                {"hash": password_hash, "name": full_name, "uid": firebase_uid, "email": email.lower()}
            )
            await db.commit()
            print(f"[~] Superadmin güncellendi: {email}")
            return

        # Yeni superadmin oluştur
        user_id = str(uuid.uuid4())
        await db.execute(
            text("""
                INSERT INTO users (id, email, firebase_uid, full_name, role, status, password_hash, failed_login_attempts, is_deleted, created_at, updated_at)
                VALUES (:id, :email, :uid, :name, 'superadmin', 'active', :hash, 0, false, NOW(), NOW())
            """),
            {"id": user_id, "email": email.lower(), "uid": firebase_uid, "name": full_name, "hash": password_hash}
        )
        await db.commit()
        print(f"[+] Superadmin oluşturuldu!")
        print(f"    Email: {email}")
        print(f"    UID: {firebase_uid}")


if __name__ == "__main__":
    print(f"Database: {DATABASE_URL.split('@')[-1] if '@' in DATABASE_URL else 'localhost'}")
    print()
    print("=== Superadmin Oluşturma ===")
    email = input("Email: ").strip()
    while not email:
        print("Email zorunludur!")
        email = input("Email: ").strip()

    uid = input("Firebase UID: ").strip()
    while not uid:
        print("Firebase UID zorunludur!")
        uid = input("Firebase UID: ").strip()

    name = input("Full Name: ").strip()
    while not name:
        print("Full Name zorunludur!")
        name = input("Full Name: ").strip()

    # Güvenli şifre girişi
    password = getpass.getpass("Firebase Console'daki şifre: ")
    while len(password) < 6:
        print("Şifre en az 6 karakter olmalı!")
        password = getpass.getpass("Firebase Console'daki şifre: ")

    confirm = getpass.getpass("Şifreyi tekrar girin: ")
    while password != confirm:
        print("Şifreler eşleşmiyor!")
        confirm = getpass.getpass("Şifreyi tekrar girin: ")

    print()
    asyncio.run(create_superadmin(email, uid, name, password))