@echo off
cd /d "%~dp0"
echo ==== Zentrixa server ====
if exist pixabay_key.txt goto compile
if exist pexels_key.txt goto compile
echo.
echo Reels mein free videos ke liye Pixabay key chahiye (free: https://pixabay.com/api/docs/)
echo Key copy karke yahan paste karo aur Enter dabao. Chhodna ho to bas Enter dabao.
set /p PK=Pixabay key: 
if "%PK%"=="" goto compile
>pixabay_key.txt echo %PK%
:compile
echo.
echo Server compile ho raha hai...
g++ -std=c++17 -O2 server.cpp -o server.exe -lcurl -lws2_32
if errorlevel 1 goto fail
echo.
server.exe
pause
exit /b 0
:fail
echo Compile fail hua. Upar ka error dekho (link error ho to end mein -lcrypt32 jodo).
pause
exit /b 1
