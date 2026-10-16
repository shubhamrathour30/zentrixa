@echo off
setlocal
title Zentrixa - app update
echo ==== Zentrixa: naya app server par daalo ====
echo Iske baad jinke phone mein app hai unhe agli baar khulte hi naya app mil jata hai (APK dobara nahi).
echo.
cd /d C:\my_app

echo [1/3] Website build ho rahi hai (3-5 minute)...
call flutter pub get
call flutter build web --release
if errorlevel 1 goto fail

echo.
echo [2/3] Server ke public folder mein copy ho rahi hai...
rem Flutter web/ folder ko build mein copy karta hai - backend (keys, data) public nahi hona chahiye
if exist build\web\cpp_backend rmdir /s /q build\web\cpp_backend
if exist web\cpp_backend\public rmdir /s /q web\cpp_backend\public
xcopy /e /i /y build\web web\cpp_backend\public >nul
if errorlevel 1 goto fail
if exist web\cpp_backend\public\cpp_backend rmdir /s /q web\cpp_backend\public\cpp_backend

echo.
echo [3/3] Purana cache hata rahe hain taaki phone par naya hi dikhe...
>web\cpp_backend\public\flutter_service_worker.js echo self.addEventListener('install',function(e){self.skipWaiting();});
>>web\cpp_backend\public\flutter_service_worker.js echo self.addEventListener('activate',function(e){e.waitUntil(caches.keys().then(function(k){return Promise.all(k.map(function(c){return caches.delete(c);}));}).then(function(){return self.registration.unregister();}));});

echo Speed ke liye files compress ho rahi hain...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0gzip_public.ps1"

echo.
echo ================================================================
echo  Update server par chadh gaya. Server restart ki zaroorat nahi.
echo  (Pehli baar ya server.cpp badla ho to start_server.bat dobara chalao.)
echo  Phone par: app band karke dobara kholo - naya app aa jayega.
echo ================================================================
pause
exit /b 0

:fail
echo.
echo Kuch fail hua. Upar ka error dekho aur screenshot bhej do.
pause
exit /b 1
