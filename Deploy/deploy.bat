@echo off
REM =====================================================
REM  Nexus Confluence V3 - Deploy Script
REM  Copies DLL, EA, and includes to MT5 directory
REM =====================================================

set MT5_DIR=C:\Users\santospaulo\AppData\Roaming\MetaQuotes\Terminal\FEC98F1D078C037902D797DB372EA18E\MQL5
set PROJECT_DIR=%~dp0..
set DLL_BUILD=%PROJECT_DIR%\DLL\build\bin\Release

echo =====================================================
echo  Nexus Confluence V3 - Deploy
echo =====================================================
echo.

REM Check MT5 directory exists
if not exist "%MT5_DIR%" (
    echo ERROR: MT5 directory not found: %MT5_DIR%
    pause
    exit /b 1
)

REM Copy DLL
echo [1/3] Copying DLL...
if exist "%DLL_BUILD%\NexusConfluence.dll" (
    copy /Y "%DLL_BUILD%\NexusConfluence.dll" "%MT5_DIR%\Libraries\" >nul
    echo       OK: NexusConfluence.dll -> Libraries/
) else (
    echo       WARNING: DLL not found at %DLL_BUILD%
    echo       Build the DLL first: cd DLL/build ^&^& cmake --build . --config Release
)

REM Copy EA
echo [2/3] Copying Expert Advisor...
if not exist "%MT5_DIR%\Experts\NexusConfluenceV3\" mkdir "%MT5_DIR%\Experts\NexusConfluenceV3\"
copy /Y "%PROJECT_DIR%\MQL5\Experts\NexusConfluenceV3\*.mq5" "%MT5_DIR%\Experts\NexusConfluenceV3\" >nul 2>nul
echo       OK: EA files copied

REM Copy Includes
echo [3/3] Copying Include files...
if not exist "%MT5_DIR%\Include\NexusConfluenceV3\" mkdir "%MT5_DIR%\Include\NexusConfluenceV3\"
copy /Y "%PROJECT_DIR%\MQL5\Include\NexusConfluenceV3\*.mqh" "%MT5_DIR%\Include\NexusConfluenceV3\" >nul 2>nul
echo       OK: Include files copied

echo.
echo =====================================================
echo  Deploy complete! Compile EA in MetaEditor (F7).
echo =====================================================
pause
