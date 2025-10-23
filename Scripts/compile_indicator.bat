@echo off
echo ===== COMPILANDO GG TRENDBAR INDICATOR =====
echo.

REM Caminho do MetaEditor (ajustar se necessário)
set METAEDITOR="C:\Program Files\MetaTrader 5\metaeditor64.exe"

REM Arquivo a compilar
set INDICATOR="d:\EA_Projetos\Nexus_Confluence_MT5\Nexus_Confluence_MT5\Indicators\NexusConfluenceEA\GG_TrendBar_Indicator.mq5"

REM Compilar
%METAEDITOR% /compile:%INDICATOR% /log

echo.
echo ===== COMPILACAO CONCLUIDA =====
echo Verifique erros acima (se houver)
echo.
pause
