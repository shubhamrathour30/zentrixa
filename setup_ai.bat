@echo off
cd /d C:\my_app\web\cpp_backend
echo ==== Zentrixa AI setup (free Gemini key) ====
echo.
echo   1. https://aistudio.google.com/apikey kholo, Gmail se login karo.
echo   2. "Create API key" dabao, key copy karo (AIza... se shuru).
echo.
set /p GK=Gemini key paste karo (right-click = paste): 
if "%GK%"=="" goto done
>gemini_key.txt echo %GK%
echo.
echo Save ho gaya. Ab server band karke dobara chalao (start_server.bat).
echo Server window mein Gemini key mil gayi wala message aana chahiye.
:done
if "%1"=="" pause
