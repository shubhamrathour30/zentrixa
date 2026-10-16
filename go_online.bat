@echo off
setlocal
title Zentrixa - fixed link (Tailscale)
echo ==== Zentrixa: kabhi na badalne wala link banao (Tailscale, free) ====
echo (Pehle server chalu rakho: web\cpp_backend\start_server.bat)
echo.
set "TS=C:\Program Files\Tailscale\tailscale.exe"
if exist "%TS%" goto havets
echo [1/3] Tailscale install ho raha hai (Yes/Allow dabana)...
winget install --id Tailscale.Tailscale -e --accept-source-agreements --accept-package-agreements
if not exist "%TS%" goto fail
:havets
echo.
echo [2/3] Tailscale login: browser khulega - Google ya Microsoft se login karo, phir yahan wapas aao.
"%TS%" up
echo.
echo [3/3] Link chalu ho raha hai (laptop ke server port 3000 ko)...
echo Agar neeche koi https://login.tailscale.com/... link aaye to use browser mein kholo,
echo "Enable" dabao, phir ye script dobara chalao. (HTTPS aur Funnel ek baar enable karne padte hain.)
echo.
"%TS%" funnel --bg 3000
echo.
echo ================================================================
echo  Neeche jo https://....ts.net link dikhe wahi aapka FIXED LINK hai.
echo  Ye kabhi nahi badalta. Laptop on aur server chalta hona chahiye.
echo ================================================================
"%TS%" funnel status
echo.
pause
exit /b 0

:fail
echo.
echo Tailscale install nahi hua. Is window ka screenshot bhej do.
pause
exit /b 1
