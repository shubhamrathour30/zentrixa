@echo off
setlocal
title Zentrixa - APK banao
echo ==== Zentrixa: phone ke liye APK ban raha hai ====
echo (Pehle chal rahi "flutter run" window band kar do.)
echo.
cd /d C:\my_app

rem ---------- Android tools pehli baar install karo
if exist "%LOCALAPPDATA%\Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat" goto sdkok
call "%~dp0setup_android.bat" nopause
if errorlevel 1 goto fail
:sdkok

rem ---------- Server ka link (optional - baad mein app ke andar bhi badal sakte ho)
echo.
echo Phone ko server se jodna hai. go_online.bat wala FIXED link daalo (ek baar), jaise:
echo    https://your-name.ts.net   (go_online.bat wala fixed link)
echo    ya  http://192.168.1.5:3000      (laptop ka WiFi IP, phone usi WiFi par ho)
echo Abhi nahi pata to bas Enter dabao - app pehli baar khulne par link poochega.
set "SRV="
set /p SRV=Server link: 

echo.
echo Packages aa rahe hain...
call flutter pub get
if errorlevel 1 goto fail

echo.
echo APK ban raha hai - pehli baar 10-20 minute lagte hain (Gradle sab download karta hai). Window band mat karna...
if "%SRV%"=="" goto buildplain
call flutter build apk --release --dart-define=ZX_SERVER=%SRV%
goto built
:buildplain
call flutter build apk --release
:built
if errorlevel 1 goto fail

if not exist build\app\outputs\flutter-apk\app-release.apk goto fail
copy /y build\app\outputs\flutter-apk\app-release.apk C:\my_app\Zentrixa.apk >nul
echo.
echo ================================================================
echo  APK taiyar:  C:\my_app\Zentrixa.apk
echo  Isse phone mein bhejo (WhatsApp / Drive / USB) aur phone par kholo.
echo  Ye APK ek hi baar install karni hai. Aage ke saare updates update_app.bat se khud aayenge.
echo  "Install unknown apps" ki permission maange to Allow karo.
echo ================================================================
explorer /select,"C:\my_app\Zentrixa.apk"
pause
exit /b 0

:fail
echo.
echo Kuch fail hua. Upar ka error dekho aur is window ka screenshot bhej do.
pause
exit /b 1
