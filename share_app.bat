@echo off
setlocal
title Zentrixa - public link
echo ==== Zentrixa: public link banao ====
echo (Pehle Chrome/VS Code mein chal rahi "flutter run" band kar do.)
echo.
cd /d C:\my_app

echo [1/4] Website (Flutter web) build ho rahi hai - 2-3 minute lagte hain...
call flutter build web --release
if errorlevel 1 goto fail

echo.
echo [2/4] Website server folder mein copy ho rahi hai...
if exist web\cpp_backend\public rmdir /s /q web\cpp_backend\public
xcopy /e /i /y build\web web\cpp_backend\public >nul
if errorlevel 1 goto fail

echo.
echo [3/4] Server compile ho raha hai aur nayi window mein chalu ho raha hai...
taskkill /im server.exe /f >nul 2>&1
cd /d C:\my_app\web\cpp_backend
g++ -std=c++17 -O2 server.cpp -o server.exe -lcurl -lws2_32
if errorlevel 1 goto fail

if exist brevo_key.txt goto startsrv
if not "%BREVO_API_KEY%"=="" goto startsrv
echo.
echo Dusre log signup par OTP email se lete hain, isliye Brevo setup chahiye.
echo Abhi skip karna ho to key ke time bas Enter dabao (OTP tab sirf server window mein dikhega).
call C:\my_app\setup_email.bat nopause
cd /d C:\my_app\web\cpp_backend
:startsrv
start "Zentrixa Server (band mat karna)" cmd /k "cd /d C:\my_app\web\cpp_backend && server.exe"
timeout /t 3 >nul

echo.
echo [4/4] Public link ban raha hai (Cloudflare tunnel)...
set CF=cloudflared
where cloudflared >nul 2>&1
if not errorlevel 1 goto runcf
if exist "C:\Program Files (x86)\cloudflared\cloudflared.exe" (set "CF=C:\Program Files (x86)\cloudflared\cloudflared.exe" & goto runcf)
echo cloudflared install ho raha hai (ek baar ka kaam)...
winget install --id Cloudflare.cloudflared -e --accept-source-agreements --accept-package-agreements
if exist "C:\Program Files (x86)\cloudflared\cloudflared.exe" set "CF=C:\Program Files (x86)\cloudflared\cloudflared.exe"
:runcf
echo.
echo ================================================================
echo  Neeche kuch der mein  https://........trycloudflare.com  dikhega.
echo  Wahi aapka PUBLIC LINK hai - kisi ko bhi bhej do.
echo  Ye window aur "Zentrixa Server" window khuli rakho, warna link band.
echo  Har baar chalane par naya link banta hai.
echo ================================================================
echo.
"%CF%" tunnel --url http://localhost:3000
pause
exit /b 0

:fail
echo.
echo Kuch fail hua. Upar ka error dekho aur screenshot bhej do.
pause
exit /b 1
