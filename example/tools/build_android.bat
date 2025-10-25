@echo off
setlocal enabledelayedexpansion

:: Check for debug parameter
set "BUILD_MODE=release"
if /i "%~1"=="debug" set "BUILD_MODE=debug"

echo ========================================
if "%BUILD_MODE%"=="debug" (
    echo Building Android Debug APK
) else (
    echo Building Android Release APK
)
echo ========================================
echo.

:: Increment build number
call "%~dp0increment_build_number.bat"
if errorlevel 1 (
    echo ERROR: Failed to increment build number
    exit /b 1
)

:: Update release notes assets
echo [Pre-Build] Updating release notes assets in pubspec.yaml...
call python "%~dp0update_release_notes_assets.py"
if errorlevel 1 (
    echo WARNING: Failed to update release notes assets
    echo Build will continue with existing asset configuration
)
echo.

:: Navigate to example directory
cd /d "%~dp0.."

:: Build APK
echo Building APK...
if "%BUILD_MODE%"=="debug" (
    call flutter build apk --debug --target-platform android-arm64
) else (
    call flutter build apk --release --target-platform android-arm64
)

if errorlevel 1 (
    echo.
    echo ERROR: Flutter build failed!
    cd tools
    exit /b 1
)

:: Set APK path for the install script
if "%BUILD_MODE%"=="debug" (
    set "APK_PATH=%~dp0..\build\app\outputs\flutter-apk\app-debug.apk"
) else (
    set "APK_PATH=%~dp0..\build\app\outputs\flutter-apk\app-release.apk"
)

:: Export APK_PATH to calling script
endlocal & set "APK_PATH=%APK_PATH%"

echo.
echo Build completed successfully!
echo APK location: %APK_PATH%
echo.

cd tools
exit /b 0
