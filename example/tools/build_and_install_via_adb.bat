@echo off
setlocal enabledelayedexpansion

:: Check for debug parameter
set "BUILD_MODE=debug"
if /i "%~1"=="debug" set "BUILD_MODE=debug"

echo ========================================
if "%BUILD_MODE%"=="debug" (
    echo Build and Install Android Debug APK via ADB
) else (
    echo Build and Install Android Release APK via ADB
)
echo ========================================
echo.

:: Step 1: Check ADB is available
echo [Step 1/4] Checking ADB availability...
adb version >nul 2>&1
if errorlevel 1 (
    echo.
    echo ERROR: ADB not found. Please ensure Android SDK platform-tools are in your PATH.
    pause
    exit /b 1
)
echo    - ADB found
echo.

:: Step 2: Check for connected devices
echo [Step 2/4] Checking for connected devices...
adb devices | findstr /r "device$" >nul
if errorlevel 1 (
    echo.
    echo ERROR: No connected devices found.
    echo Please connect an Android device or start an emulator.
    pause
    exit /b 1
)

:: Count devices
set "DEVICE_COUNT=0"
for /f "tokens=1" %%d in ('adb devices ^| findstr /r "device$"') do (
    set /a DEVICE_COUNT+=1
    set "DEVICE_ID=%%d"
)

if %DEVICE_COUNT% GTR 1 (
    echo WARNING: Multiple devices connected. Using first device: !DEVICE_ID!
) else (
    echo    - Device connected: !DEVICE_ID!
)
echo.

:: Step 3: Build Android APK using shared build script
echo [Step 3/4] Building Android APK...
call "%~dp0build_android.bat" %BUILD_MODE%
if errorlevel 1 (
    echo.
    echo ERROR: Build failed!
    pause
    exit /b 1
)

:: Step 4: Install APK via ADB
echo [Step 4/4] Installing APK via ADB...
echo    - Package: com.example.example
echo    - Mode: %BUILD_MODE%
echo.

:: Check if app is already installed
adb shell pm list packages | findstr "com.example.example" >nul
if not errorlevel 1 (
    echo    - App is already installed, updating...
    :: Use -r flag to reinstall and -d to allow downgrade (in case of debug after release)
    adb install -r -d "%APK_PATH%"
) else (
    echo    - Installing new app...
    adb install "%APK_PATH%"
)

if errorlevel 1 (
    echo.
    echo ERROR: Installation failed!
    echo.
    echo Trying alternative method: Uninstall and reinstall...
    adb uninstall com.example.example
    if not errorlevel 1 (
        echo    - Old app uninstalled, installing fresh...
        adb install "%APK_PATH%"
        if errorlevel 1 (
            echo.
            echo ERROR: Fresh installation also failed!
            echo.
            echo Troubleshooting tips:
            echo  - Ensure USB debugging is enabled on your device
            echo  - Check if the device is unlocked
            echo  - Check device storage space
            echo  - Try rebooting your device
            pause
            exit /b 1
        )
    ) else (
        echo.
        echo ERROR: Could not uninstall or install!
        echo.
        echo Troubleshooting tips:
        echo  - Ensure USB debugging is enabled on your device
        echo  - Check if the device is unlocked
        pause
        exit /b 1
    )
)

echo.
echo ========================================
echo Build and installation completed successfully!
echo ========================================
echo.
echo The app is now installed/updated on your device.
echo You can launch it from your device's app drawer.
echo.
pause
endlocal
