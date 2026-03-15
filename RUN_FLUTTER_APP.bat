@echo off
echo Launching Flutter app in a fresh environment...
echo.

REM Check if Flutter is available
flutter --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Flutter not found in PATH!
    echo.
    echo Please exit this window and open a NEW PowerShell/Command Prompt,
    echo then try running this file again.
    echo.
    pause
    exit /b 1
)

echo Flutter is working! Launching app...
echo.
cd /d "%~dp0"
flutter run android

echo.
echo App finished running.
pause
