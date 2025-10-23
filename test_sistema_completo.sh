#!/bin/bash
# ============================================================================
# TESTE COMPLETO DO SISTEMA AUTOMÁTICO v4.31
# Sistema 100% automático - ZERO intervenção humana
# ============================================================================

echo "════════════════════════════════════════════════════════════════"
echo "🧪 TESTE COMPLETO - SISTEMA AUTOMÁTICO v4.31"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Navegar para diretório
cd /mnt/d/EA_Projetos/Nexus_Confluence_MT5/Nexus_Confluence_MT5 || exit 1

# Ativar venv
source venv/bin/activate || exit 1

# Limpar análises antigas
echo "[1/5] Limpando cache..."
rm -f analysis_output/master_analysis_20251023_*.json
rm -f .analysis_pid .analysis_complete
echo "✅ Cache limpo"
echo ""

# Encontrar log
echo "[2/5] Localizando log..."
LOG_FILE=$(ls -t log/*.log | head -1)
LOG_SIZE=$(du -h "$LOG_FILE" | cut -f1)
echo "✅ Log: $LOG_FILE ($LOG_SIZE)"
echo ""

# Iniciar análise COMPLETA
echo "[3/5] Iniciando análise COMPLETA (vai demorar 3-4 horas)..."
nohup python -u Tools/master_analyzer.py "$LOG_FILE" > analysis_progress.log 2>&1 &
ANALYSIS_PID=$!
echo $ANALYSIS_PID > .analysis_pid
sleep 3

# Verificar se iniciou
if ps -p $ANALYSIS_PID > /dev/null 2>&1; then
    echo "✅ Análise iniciada - PID: $ANALYSIS_PID"
else
    echo "❌ ERRO: Análise não iniciou"
    tail -20 analysis_progress.log
    exit 1
fi
echo ""

# Iniciar monitor
echo "[4/5] Iniciando monitor automático..."
chmod +x auto_monitor_complete.sh
nohup ./auto_monitor_complete.sh > auto_monitor_complete.log 2>&1 &
MONITOR_PID=$!
sleep 2

if ps -p $MONITOR_PID > /dev/null 2>&1; then
    echo "✅ Monitor iniciado - PID: $MONITOR_PID"
else
    echo "⚠️  Monitor não iniciou, mas análise continua"
fi
echo ""

echo "[5/5] Sistema 100% automático rodando..."
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✅ INICIADO COM SUCESSO!"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "📊 PID Análise: $ANALYSIS_PID"
echo "🔍 PID Monitor: $MONITOR_PID"
echo "📁 Log: $LOG_FILE ($LOG_SIZE)"
echo ""
echo "⏳ TEMPO ESTIMADO: 3-4 HORAS (log de $LOG_SIZE)"
echo ""
echo "🔴 ZERO INTERVENÇÃO HUMANA!"
echo "🔴 NÃO PRECISA FAZER MAIS NADA!"
echo ""
echo "O sistema vai:"
echo "  [1/4] Analisar log completo (~3-4h)"
echo "  [2/4] Analisar código EA (~5min)"
echo "  [3/4] APLICAR correções automaticamente (~1min)"
echo "  [4/4] RECOMPILAR EA automaticamente (~1min)"
echo ""
echo "MONITORAR (OPCIONAL):"
echo "  tail -f auto_monitor_complete.log"
echo ""
echo "VERIFICAR CONCLUSÃO:"
echo "  [ -f .analysis_complete ] && echo 'COMPLETO' || echo 'RODANDO'"
echo ""
echo "════════════════════════════════════════════════════════════════"
