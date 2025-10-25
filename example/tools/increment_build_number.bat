@echo off
setlocal enabledelayedexpansion

:: Path to pubspec.yaml
set "PUBSPEC=..\pubspec.yaml"

:: Check if pubspec.yaml exists
if not exist "%PUBSPEC%" (
    echo ERROR: pubspec.yaml not found at %PUBSPEC%
    exit /b 1
)

:: Read current version
for /f "tokens=2 delims=: " %%a in ('findstr /r "^version:" "%PUBSPEC%"') do set "CURRENT_VERSION=%%a"

:: Extract version name and build number
for /f "tokens=1,2 delims=+" %%a in ("%CURRENT_VERSION%") do (
    set "VERSION_NAME=%%a"
    set "BUILD_NUMBER=%%b"
)

:: Increment build number
set /a "NEW_BUILD_NUMBER=!BUILD_NUMBER! + 1"
set "NEW_VERSION=!VERSION_NAME!+!NEW_BUILD_NUMBER!"

:: Display change
echo Incrementing build number: %CURRENT_VERSION% -^> !NEW_VERSION!

:: Create temp file with updated version
set "TEMP_FILE=%PUBSPEC%.tmp"
(
    for /f "usebackq delims=" %%a in ("%PUBSPEC%") do (
        set "LINE=%%a"
        echo !LINE! | findstr /r "^version:" >nul
        if !errorlevel! equ 0 (
            echo version: !NEW_VERSION!
        ) else (
            echo %%a
        )
    )
) > "%TEMP_FILE%"

:: Replace original file
move /y "%TEMP_FILE%" "%PUBSPEC%" >nul

echo Build number updated successfully!
echo.
endlocal
exit /b 0
