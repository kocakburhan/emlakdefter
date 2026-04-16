#!/usr/bin/env python3
"""
Emlakdefter Development Starter
Bir tıkla: Docker + PostgreSQL + Redis + Backend + Flutter başlatır.
"""
import subprocess
import sys
import time
import os
import shutil

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
BACKEND_DIR = os.path.join(SCRIPT_DIR, "backend")
FRONTEND_DIR = os.path.join(SCRIPT_DIR, "frontend")
VENV_PY = os.path.join(BACKEND_DIR, "venv", "Scripts", "python.exe")
VENV_PIP = os.path.join(BACKEND_DIR, "venv", "Scripts", "pip.exe")
VENV_UVICORN = os.path.join(BACKEND_DIR, "venv", "Scripts", "uvicorn.exe")
VENV_ALEMBIC = os.path.join(BACKEND_DIR, "venv", "Scripts", "alembic.exe")
DOCKER_COMPOSE = os.path.join(SCRIPT_DIR, "docker-compose.yml")

def run(cmd, shell=True, capture=True, cwd=None, check=False):
    """Run a command and return result."""
    print(f"    $ {cmd}")
    kw = {}
    if capture:
        kw["capture_output"] = True
        kw["text"] = True
    if cwd:
        kw["cwd"] = cwd
    result = subprocess.run(cmd, shell=shell, **kw)
    if result.returncode != 0 and check:
        print(f"[HATA] Komut başarısız: {cmd}")
        print(result.stderr or result.stdout)
        sys.exit(1)
    return result

def header():
    print("=" * 50)
    print("  Emlakdefter Development Starter")
    print("=" * 50)
    print()

def step(msg):
    print(f"[-] {msg}...")

def ok(msg):
    print(f"[OK] {msg}")

def warn(msg):
    print(f"[UYARI] {msg}")

def wait_for_postgres(max_secs=30):
    """Wait for PostgreSQL to be ready."""
    print(f"    PostgreSQL hazirlaniyor (max {max_secs} sn)...")
    for i in range(max_secs):
        r = subprocess.run(
            ["docker", "exec", "emlakdefter_db", "pg_isready",
             "-U", "emlakdefter_user", "-d", "emlakdefter"],
            capture_output=True
        )
        if r.returncode == 0:
            print(f"    PostgreSQL hazir ({i+1} sn).")
            return True
        time.sleep(1)
    warn("PostgreSQL 30 saniyede hazir olmadi.")
    return False

def wait_for_backend(url="http://localhost:8001/health", max_secs=60):
    """Wait for backend to respond."""
    print(f"    Backend hazirlaniyor (max {max_secs} sn)...")
    for i in range(max_secs):
        r = subprocess.run(
            ["curl", "-s", url],
            capture_output=True
        )
        if r.returncode == 0 and r.stdout:
            print(f"    Backend hazir ({i+1} sn).")
            return True
        time.sleep(1)
    warn("Backend 30 saniyede hazir olmadi.")
    return False

def main():
    header()

    # 1. Docker check
    step("Docker kontrol ediliyor")
    r = subprocess.run(["docker", "info"], capture_output=True)
    if r.returncode != 0:
        print("[HATA] Docker calismiyor! Lutfen Docker Desktop'u baslatin.")
        sys.exit(1)
    ok("Docker hazir")

    # 2. Docker containers
    step("Docker konteynerleri baslatiliyor (PostgreSQL:5433 + Redis:6379)")
    r = subprocess.run(
        ["docker", "compose", "-f", DOCKER_COMPOSE, "up", "-d"],
        cwd=SCRIPT_DIR, capture_output=True, text=True
    )
    if r.returncode != 0:
        print(f"[HATA] Docker baslatilamadi!\n{r.stderr}")
        sys.exit(1)
    ok("Docker konteynerleri calisiyor")

    # 3. Wait for PostgreSQL
    wait_for_postgres()

    # 4. Recreate venv if needed
    step("Backend virtual environment kontrol ediliyor")
    need_venv = (
        not os.path.exists(VENV_PY) or
        not os.path.exists(VENV_PIP) or
        not os.path.exists(VENV_UVICORN)
    )
    if need_venv:
        venv_dir = os.path.join(BACKEND_DIR, "venv")
        if os.path.exists(venv_dir):
            step("Eski venv siliniyor")
            shutil.rmtree(venv_dir)
        step("Yeni venv olusturuluyor")
        r = subprocess.run(
            [sys.executable, "-m", "venv", "venv"],
            cwd=BACKEND_DIR, capture_output=True, text=True
        )
        if r.returncode != 0:
            print(f"[HATA] venv olusturulamadi!\n{r.stderr}")
            sys.exit(1)
        ok("Virtual environment hazir")
    else:
        ok("Virtual environment hazir")

    # 5. pip install
    step("Backend bagimliliklari yukleniyor")
    r = subprocess.run(
        [VENV_PY, "-m", "pip", "install", "-r", "requirements.txt"],
        cwd=BACKEND_DIR, capture_output=True, text=True
    )
    if r.returncode != 0:
        print(f"[HATA] pip install basarisiz!\n{r.stderr}")
        sys.exit(1)
    ok("Backend bagimliliklari tamam")

    # 6. Alembic migration
    step("Veritabani tablolari olusturuluyor")
    r = subprocess.run(
        [VENV_PY, "-m", "alembic", "upgrade", "head"],
        cwd=BACKEND_DIR, capture_output=True, text=True
    )
    if r.returncode != 0:
        print(f"[HATA] Migration basarisiz!\n{r.stderr}")
        sys.exit(1)
    ok("Veritabani tablolari hazir")

    # 7. Kill any existing process on port 8001
    print()
    step("Port 8001 kontrol ediliyor...")
    r = subprocess.run(
        ["netstat", "-ano"],
        capture_output=True, text=True
    )
    for line in r.stdout.split("\n"):
        if ":8001" in line and "LISTENING" in line:
            pid = line.split()[-1]
            if pid and pid.isdigit():
                subprocess.run(["taskkill", "//F", "//PID", pid],
                    capture_output=True)
    ok("Port 8001 temizlendi")

    # 8. Start Backend
    print()
    print("[-] Backend sunucusu baslatiliyor...")
    print("    http://localhost:8001")
    print("    http://localhost:8001/docs")
    subprocess.Popen(
        [VENV_PY, "-m", "uvicorn", "app.main:app", "--reload", "--host", "0.0.0.0", "--port", "8001"],
        cwd=BACKEND_DIR,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )

    # 8. Wait for backend
    wait_for_backend()

    # 9. Test API
    print()
    step("API test ediliyor")
    r = subprocess.run(
        ["curl", "-s", "http://localhost:8001/api/v1/"],
        capture_output=True, text=True
    )
    if r.returncode == 0 and r.stdout:
        ok("API erisilebilir")
    else:
        warn("API yanit vermiyor olabilir")

    # 10. Flutter
    print()
    print("=" * 50)
    print("  Flutter baslatiliyor...")
    print(f"  Backend: http://localhost:8001")
    print(f"  API Docs: http://localhost:8001/docs")
    print("=" * 50)
    print()

    # Clean build - kill all Chrome/Flutter processes FIRST, then clean
    step("Flutter prosesleri sonlandiriliyor...")
    for exe in ["chrome.exe", "flutter.exe", "dart.exe", "chromedriver.exe"]:
        subprocess.run(["taskkill", "//F", "//IM", exe],
            capture_output=True)
    time.sleep(3)

    build_dir = os.path.join(FRONTEND_DIR, "build")
    if os.path.exists(build_dir):
        step("Eski build temizleniyor...")
        try:
            shutil.rmtree(build_dir)
        except (PermissionError, OSError):
            warn("Build temizlenemedi, devam ediliyor...")

    FLUTTER = "C:/Users/kocak/dev/flutter/bin/flutter.bat"
    subprocess.Popen(
        [FLUTTER, "run", "-d", "chrome"],
        cwd=FRONTEND_DIR,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )
    r = None  # Don't wait for Flutter

    print()
    print()
    print("=" * 50)
    print("  Flutter kapandi.")
    print("  Backend loglarini gormek icin:")
    print("  docker compose -f docker-compose.yml logs -f")
    print("=" * 50)
    try:
        input("\nPress Enter to exit...")
    except (EOFError, KeyboardInterrupt):
        pass

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\nInterrupting...")
        sys.exit(0)
