@echo off
echo Setting up Flutter environment...
set PATH=C:\flutter\bin;%PATH%
echo.
echo Flutter ready! Launching app...
echo.
cd /d "%~dp0"
flutter run android
echo.
echo Done.
pause
