:: Increment build number (comment out if you don't want this for debug builds)
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

cd ..
call flutter build apk --debug --target-platform android-arm64
cd tools
pause