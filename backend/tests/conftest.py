"""
conftest.py — Pytest konfigürasyonu

Tüm testler için ortak setup: .env dosyasını yükle.
"""
import os
from pathlib import Path
from dotenv import load_dotenv

# .env dosyasını pytest başlamadan ÖNCE yükle
_env_path = Path(__file__).parent.parent / ".env"
if _env_path.exists():
    load_dotenv(dotenv_path=_env_path, override=False)
