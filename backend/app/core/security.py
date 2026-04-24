import os
from datetime import datetime, timedelta, timezone
from jose import jwt
import bcrypt

# Bcrypt ile tek yönlü (çözülemez) parola özetlemesi
# NOT: bcrypt password sınırı 72 bytes - daha uzun şifreler kesilir

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return bcrypt.checkpw(plain_password.encode('utf-8'), hashed_password.encode('utf-8'))

def get_password_hash(password: str) -> str:
    return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

# JWT Algoritma Ortam Değişkenleri
SECRET_KEY = os.getenv("SECRET_KEY")
if not SECRET_KEY:
    raise RuntimeError("SECRET_KEY environment variable is required! Set it in your .env file.")
ALGORITHM = os.getenv("ALGORITHM", "HS256")

def create_invitation_token(data: dict, expires_delta: timedelta) -> str:
    """PRD Madde 4.1.4: Akıllı Davet Jetonları için kriptografik string üretir."""
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + expires_delta
    to_encode.update({"exp": expire, "type": "invitation"})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def create_access_token(data: dict, expires_delta: timedelta | None = None) -> str:
    """Backend korumalı rotaları (Kullanıcı Oturumu) için yetki token'ı."""
    if expires_delta is None:
        expires_delta = timedelta(minutes=1440)  # Default 24 hours
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + expires_delta
    to_encode.update({"exp": expire, "type": "access"})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt
