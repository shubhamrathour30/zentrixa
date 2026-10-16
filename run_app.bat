@echo off
rem Zentrixa Flutter ko fixed port par chalata hai taaki login yaad rahe.
rem Phir Chrome mein http://localhost:5000 kholo (apna normal Chrome - usme login save rehta hai).
cd /d C:\my_app
flutter run -d web-server --web-port 5000
