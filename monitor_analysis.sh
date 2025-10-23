#!/bin/bash
echo "═══════════════════════════════════════════════════════════"
echo "🔍 MONITOR DE ANÁLISE - Nexus Confluence v4.31"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Verificar se processo está rodando
PID=$(ps aux | grep "master_analyzer.py log/20251023.log" | grep -v grep | awk '{print $2}')

if [ -z "$PID" ]; then
    echo "❌ Análise NÃO está rodando!"
    echo ""
    echo "📊 Verificando se completou..."
    if [ -f "analysis_output/master_analysis_$(date +%Y%m%d)_*.json" ]; then
        echo "✅ Análise COMPLETA! Arquivos gerados:"
        ls -lth analysis_output/master_analysis_$(date +%Y%m%d)_*.json | head -1
    else
        echo "⚠️  Nenhuma análise concluída hoje"
    fi
else
    echo "✅ Análise RODANDO!"
    echo ""
    
    # Status do processo
    ps aux | grep $PID | grep -v grep | awk '{printf "PID: %s\nCPU: %s%%\nMEM: %s%%\nTEMPO: %s\n", $2, $3, $4, $10}'
    
    echo ""
    echo "───────────────────────────────────────────────────────────"
    echo "📋 PROGRESSO (últimas 10 linhas):"
    echo "───────────────────────────────────────────────────────────"
    tail -10 analysis_progress.log | grep -E "\[FASE|\[INFO\]|trades|⏳|✓"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
