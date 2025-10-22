@echo off
echo Compilando NexusConfluenceEA.mq5...
"C:\Program Files\MetaTrader 5\metaeditor64.exe" /compile:"%~dp0NexusConfluenceEA.mq5" /log:"%~dp0compile.log"
echo.
echo Resultado da compilacao:
type "%~dp0compile.log"
pause
