@echo off
cd /d C:\my_app\web\cpp_backend
echo ==== Zentrixa: OTP email (Brevo) setup ====
echo.
echo Pehle Brevo website par ye 3 kaam karo (brevo.com - free account):
echo   1. "Senders, Domains" ^> Senders ^> Add a sender: apna Gmail daalo, Brevo us par mail bhejega,
echo      mail ka link/code dabake VERIFY karo.
echo   2. Menu mein "SMTP ^& API" ^> API Keys ^> Generate a new API key. Key copy karo (xkeysib-... jaisi).
echo   3. "Security" ^> Authorised IPs: "Deactivate blocking" karo (warna Brevo 401 deta hai).
echo.
set /p BK=Brevo API key paste karo: 
if "%BK%"=="" goto done
set /p SE=Verify kiya hua sender email (jaise abc@gmail.com): 
>brevo_key.txt echo %BK%
if not "%SE%"=="" >sender_email.txt echo %SE%
echo.
echo Save ho gaya. Ab server band karke dobara chalao (start_server.bat).
echo Server window mein "Brevo key mil gayi" likha aana chahiye.
:done
if "%1"=="" pause
