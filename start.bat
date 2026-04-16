@echo off
chcp 65001 >nul
echo ========================================
echo   EmlakDefter Development Starter
echo ========================================
echo.

setlocal enabledelayedexpansion

set ROOT_DIR=%~dp0
set BACKEND_DIR=%ROOT_DIR%backend
set FRONTEND_DIR=%ROOT_DIR%frontend

REM Check if Docker is running
echo [-] Docker kontrol ediliyor...
docker info >nul 2>&1
if errorlevel 1 (
    echo [HATA] Docker calismiyor! Lutfen Docker Desktop'i baslatin.
    pause
    exit /b 1
)
echo [OK] Docker hazir.

REM Start Docker containers
echo.
echo [-] Docker konteynerleri baslatiliyor...
echo    (PostgreSQL:5433 + Redis:6379)
echo.
docker compose -f "%ROOT_DIR%docker-compose.yml" up -d

if errorlevel 1 (
    echo [HATA] Docker baslatilamadi!
    pause
    exit /b 1
)
echo [OK] Docker konteynerleri calisiyor.

REM Wait for PostgreSQL
echo.
echo [-] PostgreSQL hazirlaniyor...
timeout /t 5 /nobreak >nul

REM Check PostgreSQL ready
docker exec emlakdefter_db pg_isready -U emlakdefter_user -d emlakdefter >nul 2>&1
if errorlevel 1 (
    echo [UYARI] PostgreSQL henuz hazir degil, bekleniyor...
    timeout /t 10 /nobreak >nul
)
echo [OK] PostgreSQL hazir.

REM Kill existing process on port 8001
echo.
echo [-] Port 8001 kontrol ediliyor...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :8001 ^| findstr LISTENING') do (
    taskkill //F //PID %%a >nul 2>&1
)
echo [OK] Port 8001 temizlendi.

REM Start Backend
echo.
echo [-] Backend sunucusu baslatiliyor...
echo    http://localhost:8001
echo    http://localhost:8001/docs
echo.

start "" "http://localhost:8001"

if exist "%BACKEND_DIR%\venv\Scripts\python.exe" (
    start /B cmd /c "cd /d %BACKEND_DIR% && venv\Scripts\activate.bat && python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8001"
) else (
    start /B cmd /c "cd /d %BACKEND_DIR% && python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8001"
)

REM Wait for backend (max 30 sec)
echo [-] Backend hazirlaniyor (max 30 sn)...
set BACKEND_READY=0
for %%i in (1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30) do (
    if "!BACKEND_READY!"=="0" (
        curl -s http://localhost:8001/health >nul 2>&1
        if not errorlevel 1 (
            echo [OK] Backend hazir.
            set BACKEND_READY=1
        ) else (
            timeout /t 1 /nobreak >nul
        )
    )
)
if "%BACKEND_READY%"=="0" (
    echo [UYARI] Backend hazirlanmadi, devam ediliyor...
)

REM Run Alembic migration
echo.
echo [-] Veritabani tablolari olusturuluyor...
if exist "%BACKEND_DIR%\venv\Scripts\python.exe" (
    call "%BACKEND_DIR%\venv\Scripts\activate.bat"
    "%BACKEND_DIR%\venv\Scripts\python.exe" -m alembic upgrade head
) else (
    cd /d "%BACKEND_DIR%"
    python -m alembic upgrade head
)
echo [OK] Veritabani tablolari hazir.

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
echo   Backend: http://localhost:8001
echo   API Docs: http://localhost:8001/docs
echo ========================================
echo.
cd /d "%FRONTEND_DIR%"
flutter run -d chrome

REM If Flutter closes
echo.
echo.
echo ========================================
echo   Flutter kapandi.
echo   Backend loglarini gormek icin:
echo   docker compose -f docker-compose.yml logs -f
echo ========================================
pause

endlocal
