@echo off
cd ..
echo Stopping Gradle daemons...
cd android
call gradlew.bat --stop
cd ..

echo Running Flutter clean...
call flutter clean

echo Removing build directories...
rd /s /q .dart_tool 2>nul
rd /s /q build 2>nul
rd /s /q android\.gradle 2>nul
rd /s /q android\build 2>nul
rd /s /q android\app\build 2>nul

echo Clean complete!
