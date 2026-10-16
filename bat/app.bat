@echo off
title AniStream
set "SITE_URL=http://127.0.0.1:8765/index.html"

powershell.exe -NoProfile -Command "try { $response = Invoke-WebRequest -Uri 'http://127.0.0.1:8765/' -UseBasicParsing -TimeoutSec 2; if ($response.StatusCode -eq 200) { exit 0 } else { exit 1 } } catch { exit 1 }" >nul 2>&1
if not errorlevel 1 (
    start "" "%SITE_URL%"
    exit /b
)

start "AniStream Local Web Server" /min powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0server.ps1"
exit /b
