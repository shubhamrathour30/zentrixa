@echo off
cd /d C:\my_app\web\cpp_backend
echo ==== Zentrixa admin setup ====
if exist admin_key.txt (
  echo.
  echo Admin key pehle se bana hua hai: admin_key.txt
  echo Nayi key chahiye to pehle us file ko delete karke ye script dobara chalao.
  goto show
)
powershell -NoProfile -Command "$b=New-Object byte[] 16;[Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b);($b|ForEach-Object{$_.ToString('x2')}) -join ''" > admin_key.tmp
set /p KEY=<admin_key.tmp
del admin_key.tmp
>admin_key.txt echo %KEY%
echo.
echo Admin key ban gayi.
:show
set /p SHOWKEY=<admin_key.txt
echo.
echo   Admin page:  https://shubhamrathour.tail6bf4af.ts.net/admin
echo   (laptop par:  http://localhost:3000/admin)
echo   Admin key :  %SHOWKEY%
echo.
echo Is key ko kisi ko mat dena. Server dobara chalao (start_server.bat), phir page kholke key daalo.
echo Band karna ho to admin_key.txt delete karo aur server restart karo.
if "%1"=="" pause
