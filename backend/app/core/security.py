import os
from datetime import datetime, timedelta
from jose import jwt
from passlib.context import CryptContext

# Bcrypt ile tek yönlü (çözülemez) parola özetlemesi
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# JWT Algoritma Ortam Değişkenleri
SECRET_KEY = os.getenv("SECRET_KEY", "b2c9a8db422e..._override_in_env_")
ALGORITHM = os.getenv("ALGORITHM", "HS256")

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)

def create_invitation_token(data: dict, expires_delta: timedelta) -> str:
    """PRD Madde 4.1.4: Akıllı Davet Jetonları için kriptografik string üretir."""
    to_encode = data.copy()
    expire = datetime.utcnow() + expires_delta
    to_encode.update({"exp": expire, "type": "invitation"})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def create_access_token(data: dict, expires_delta: timedelta) -> str:
    """Backend korumalı rotaları (Kullanıcı Oturumu) için yetki token'ı."""
    to_encode = data.copy()
    expire = datetime.utcnow() + expires_delta
    to_encode.update({"exp": expire, "type": "access"})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt
