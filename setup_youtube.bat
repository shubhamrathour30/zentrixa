@echo off
cd /d C:\my_app\web\cpp_backend
echo ==== Zentrixa: YouTube Shorts setup ====
echo.
echo Google ki FREE YouTube API key chahiye (roz ke 10,000 units free, kaafi hain):
echo   1. https://console.cloud.google.com kholo, Gmail se login, upar "New Project" banao (naam: zentrixa).
echo   2. Left menu: APIs ^& Services ^> Library ^> "YouTube Data API v3" search karo ^> ENABLE dabao.
echo   3. APIs ^& Services ^> Credentials ^> Create credentials ^> API key. Key copy karo (AIza... se shuru).
echo.
set /p YK=YouTube API key paste karo (right-click = paste): 
if "%YK%"=="" goto done
>youtube_key.txt echo %YK%
echo.
echo Save ho gaya. Ab server band karke dobara chalao (start_server.bat).
echo Server window mein "YouTube key mil gayi" likha aana chahiye.
:done
if "%1"=="" pause
