@echo off
chcp 65001 >nul
echo ========================================
echo   EmlakDefter Docker Full Stack
echo ========================================
echo.

setlocal enabledelayedexpansion

set ROOT_DIR=%~dp0
set BACKEND_DIR=%ROOT_DIR%backend
set FRONTEND_DIR=%ROOT_DIR%frontend
set COMPOSE_FILE=%ROOT_DIR%deploy\docker-compose.dev.yml

REM Check if Docker is running
echo [-] Docker kontrol ediliyor...
docker info >nul 2>&1
if errorlevel 1 (
    echo [HATA] Docker calismiyor! Lutfen Docker Desktop'i baslatin.
    pause
    exit /b 1
)
echo [OK] Docker hazir.

REM Stop existing containers (both old and new compose files)
echo.
echo [-] Eski containerlar durduruluyor...
docker compose -f "%COMPOSE_FILE%" down >nul 2>&1
echo [OK] Temizlik tamam.

REM Start full Docker stack
echo.
echo [-] Full stack baslatiliyor...
echo    (db + redis + backend)
echo.
docker compose -f "%COMPOSE_FILE%" up -d --build

if errorlevel 1 (
    echo [HATA] Containerlar baslatilamadi!
    docker compose -f "%COMPOSE_FILE%" logs
    pause
    exit /b 1
)
echo [OK] Containerlar ayaga kalkti.

REM Wait for PostgreSQL (with retry loop)
echo.
echo [-] PostgreSQL hazirlaniyor...
set PG_READY=0
for %%i in (1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20) do (
    if "!PG_READY!"=="0" (
        docker exec emlakdefter_db pg_isready -U emlakdefter_user -d emlakdefter >nul 2>&1
        if not errorlevel 1 (
            set PG_READY=1
        ) else (
            timeout /t 3 /nobreak >nul
        )
    )
)
if "!PG_READY!"=="0" (
    echo [UYARI] PostgreSQL hazir degil, devam ediliyor...
)
echo [OK] PostgreSQL kontrolu tamam.

REM Wait for backend to be healthy
echo.
echo [-] Backend hazirlaniyor (max 60 sn)...
set BACKEND_READY=0
for %%i in (1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60) do (
    if "!BACKEND_READY!"=="0" (
        curl -s http://localhost:8000/health >nul 2>&1
        if not errorlevel 1 (
            echo [OK] Backend hazir.
            set BACKEND_READY=1
        ) else (
            timeout /t 1 /nobreak >nul
        )
    )
)
if "!BACKEND_READY!"=="0" (
    echo [UYARI] Backend hazirlanmadi, devam ediliyor...
    echo    Loglari gormek icin: docker compose -f "%COMPOSE_FILE%" logs backend
)

REM Run Alembic migration inside container
echo.
echo [-] Veritabani tablolari olusturuluyor...
docker exec emlakdefter_backend python -m alembic upgrade head
echo [OK] Veritabani tablolari hazir.

REM Open browser
echo.
start "" "http://localhost:8000"
start "" "http://localhost:8000/docs"

REM Clean Flutter build
echo.
echo [-] Flutter build temizleniyor...
if exist "%FRONTEND_DIR%\build" (
    rmdir /s /q "%FRONTEND_DIR%\build" 2>nul
)
echo [OK] Build temizlendi.

REM Start Flutter
echo.
echo ========================================
echo   Flutter baslatiliyor...
echo   Backend: http://localhost:8000
echo   API Docs: http://localhost:8000/docs
echo ========================================
echo.
cd /d "%FRONTEND_DIR%"
flutter run -d chrome

REM If Flutter closes
echo.
echo.
echo ========================================
echo   Flutter kapandi.
echo   Container loglarini gormek icin:
echo   docker compose -f "%COMPOSE_FILE%" logs -f
echo ========================================
pause

endlocal
