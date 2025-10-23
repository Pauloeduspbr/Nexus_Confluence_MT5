#!/bin/bash
PID=$(cat .analysis_pid)
START_TIME=$(date +%s)

echo "════════════════════════════════════════════════════════════════"
echo "🤖 MONITORAMENTO AUTOMÁTICO 100% - v4.31"
echo "════════════════════════════════════════════════════════════════"
echo "📊 PID Análise: $PID"
echo "⏳ Iniciado em: $(date '+%H:%M:%S')"
echo "🔴 ZERO INTERVENÇÃO HUMANA!"
echo ""

while true; do
    if ! ps -p $PID > /dev/null 2>&1; then
        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))
        MINUTES=$((DURATION / 60))
        
        echo ""
        echo "════════════════════════════════════════════════════════════════"
        echo "✅ ANÁLISE COMPLETA EM ${MINUTES} MINUTOS!"
        echo "════════════════════════════════════════════════════════════════"
        
        LATEST_JSON=$(ls -t analysis_output/master_analysis_*.json 2>/dev/null | head -1)
        
        if [ -n "$LATEST_JSON" ]; then
            echo "📁 $LATEST_JSON"
            
            QUALITY=$(grep -o '"quality_score":[0-9.]*' "$LATEST_JSON" | head -1 | cut -d':' -f2)
            WIN_RATE=$(grep -o '"win_rate":[0-9.]*' "$LATEST_JSON" | head -1 | cut -d':' -f2)
            N_TRADES=$(grep -o '"n_trades":[0-9]*' "$LATEST_JSON" | head -1 | cut -d':' -f2)
            
            echo "🎯 Quality Score: ${QUALITY}/100"
            echo "📈 Win Rate: ${WIN_RATE}%"
            echo "🔢 Trades: ${N_TRADES}"
            echo ""
            echo "📁 ARQUIVOS .SET:"
            ls -1 Presets/*_$(date +%Y%m%d).set 2>/dev/null
        fi
        
        touch .analysis_complete
        break
    fi
    
    CURRENT_TIME=$(date +%s)
    ELAPSED=$(((CURRENT_TIME - START_TIME) / 60))
    CPU=$(ps -p $PID -o %cpu --no-headers 2>/dev/null | tr -d ' ')
    PHASE=$(tail -20 analysis_progress.log 2>/dev/null | grep -oE '\[FASE [0-9]+/10\]' | tail -1)
    
    echo "[$(date '+%H:%M:%S')] ${ELAPSED}min | CPU:${CPU}% | ${PHASE:-Processando...}"
    
    sleep 120
done
