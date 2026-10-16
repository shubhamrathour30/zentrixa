@echo off
setlocal
title Zentrixa - Android setup (ek baar ka kaam)
echo ==== Android setup (ek baar ka kaam, 10-15 minute) ====
echo.
set "SDK=%LOCALAPPDATA%\Android\Sdk"

rem ---------- 1. Java (JDK 17)
set "JDK="
for /d %%D in ("C:\Program Files\Microsoft\jdk-17*") do set "JDK=%%D"
for /d %%D in ("C:\Program Files\Eclipse Adoptium\jdk-17*") do set "JDK=%%D"
if defined JDK goto havejdk
echo [1/4] Java 17 install ho raha hai...
winget install --id Microsoft.OpenJDK.17 -e --accept-source-agreements --accept-package-agreements
for /d %%D in ("C:\Program Files\Microsoft\jdk-17*") do set "JDK=%%D"
if not defined JDK goto nojdk
:havejdk
echo Java mila: %JDK%
set "JAVA_HOME=%JDK%"
call flutter config --jdk-dir "%JDK%"

rem ---------- 2. Android command-line tools
if exist "%SDK%\cmdline-tools\latest\bin\sdkmanager.bat" goto havecmd
echo.
echo [2/4] Android command-line tools download ho rahe hain...
if not exist "%SDK%" mkdir "%SDK%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; $t=Join-Path $env:TEMP 'zx_cmdtools.zip'; $d=Join-Path $env:TEMP 'zx_cmdtools'; Invoke-WebRequest -UseBasicParsing -Uri 'https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip' -OutFile $t; if(Test-Path $d){Remove-Item -Recurse -Force $d}; Expand-Archive -Force -Path $t -DestinationPath $d; $dest='%SDK%\cmdline-tools'; New-Item -ItemType Directory -Force -Path $dest | Out-Null; if(Test-Path (Join-Path $dest 'latest')){Remove-Item -Recurse -Force (Join-Path $dest 'latest')}; Move-Item -Path (Join-Path $d 'cmdline-tools') -Destination (Join-Path $dest 'latest')"
if not exist "%SDK%\cmdline-tools\latest\bin\sdkmanager.bat" goto nocmd
:havecmd

rem ---------- 3. Licenses + platform-tools
echo.
echo [3/4] Android licenses accept ho rahe hain...
(for /l %%i in (1,1,40) do @echo y) | "%SDK%\cmdline-tools\latest\bin\sdkmanager.bat" --licenses --sdk_root="%SDK%" >nul
echo.
echo [4/4] platform-tools install ho rahe hain...
call "%SDK%\cmdline-tools\latest\bin\sdkmanager.bat" --sdk_root="%SDK%" "platform-tools"
call flutter config --android-sdk "%SDK%"
echo.
echo ==== Android setup ho gaya. Ab build_apk.bat chalao. ====
if /i not "%~1"=="nopause" pause
exit /b 0

:nojdk
echo.
echo Java install nahi ho paya. Is window ka screenshot bhej do.
if /i not "%~1"=="nopause" pause
exit /b 1

:nocmd
echo.
echo Android tools download nahi ho paye (net/antivirus ho sakta hai). Screenshot bhej do.
echo Vikalp: Android Studio install karke ek baar kholo (winget install Google.AndroidStudio), phir build_apk.bat chalao.
if /i not "%~1"=="nopause" pause
exit /b 1
