@echo off
REM Simple batch file to build Windows Nano Server 2025 Azure Monitor Agent
REM Double-click this file or run from command prompt

echo Building Windows Nano Server 2025 Azure Monitor Agent...
echo.

REM Check if Docker is accessible
docker version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker is not running or not installed.
    echo Please start Docker Desktop and try again.
    echo.
    pause
    exit /b 1
)

echo Docker is running - proceeding with build...
echo.

REM Set image name and tag
set IMAGE_NAME=azure-monitor-nano
set TAG=latest

echo Building image: %IMAGE_NAME%:%TAG%
echo Build context: %~dp0
echo.

REM Ask for confirmation
set /p confirm="Proceed with build? (y/N): "
if /i not "%confirm%"=="y" (
    echo Build cancelled.
    pause
    exit /b 0
)

echo.
echo Starting Docker build...
echo Command: docker build -t %IMAGE_NAME%:%TAG% .
echo.

REM Execute Docker build
docker build -t %IMAGE_NAME%:%TAG% .

if errorlevel 1 (
    echo.
    echo ERROR: Build failed!
    echo.
    echo Troubleshooting tips:
    echo   1. Ensure Docker Desktop is running and configured for Windows containers
    echo   2. Check your internet connection for downloading components
    echo   3. Try running: docker system prune -f  [to clean up Docker cache]
    echo   4. For more options, use the PowerShell script: .\build.ps1
    echo.
    pause
    exit /b 1
) else (
    echo.
    echo SUCCESS: Build completed successfully!
    echo Image: %IMAGE_NAME%:%TAG%
    echo.
    echo Next steps:
    echo   Run the image:     docker run %IMAGE_NAME%:%TAG%
    echo   Test components:   docker run %IMAGE_NAME%:%TAG% pwsh -File C:\opt\scripts\test-components.ps1
    echo   Interactive shell: docker run -it %IMAGE_NAME%:%TAG% pwsh
    echo.
    echo Image information:
    docker images %IMAGE_NAME%
    echo.
    pause
)
