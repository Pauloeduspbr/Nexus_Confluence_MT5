#!/bin/bash

echo "════════════════════════════════════════════════════════════════"
echo "🤖 MONITORAMENTO AUTOMÁTICO INICIADO"
echo "════════════════════════════════════════════════════════════════"
echo "⏳ Aguardando conclusão da análise..."
echo "🔴 ZERO INTERVENÇÃO HUMANA NECESSÁRIA!"
echo ""

PID=200743
START_TIME=$(date +%s)

while true; do
    # Verificar se processo ainda está rodando
    if ! ps -p $PID > /dev/null 2>&1; then
        echo ""
        echo "════════════════════════════════════════════════════════════════"
        echo "✅ ANÁLISE COMPLETA!"
        echo "════════════════════════════════════════════════════════════════"
        
        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))
        MINUTES=$((DURATION / 60))
        SECONDS=$((DURATION % 60))
        
        echo "⏱️  Tempo total: ${MINUTES}min ${SECONDS}s"
        echo ""
        
        # Buscar arquivo JSON mais recente
        LATEST_JSON=$(ls -t analysis_output/master_analysis_*.json 2>/dev/null | head -1)
        
        if [ -n "$LATEST_JSON" ]; then
            echo "📁 Arquivo gerado: $LATEST_JSON"
            echo ""
            
            # Extrair métricas principais
            echo "📊 MÉTRICAS PRINCIPAIS:"
            echo "───────────────────────────────────────────────────────────────"
            
            # Quality Score
            QUALITY=$(grep -o '"quality_score":[^,}]*' "$LATEST_JSON" | head -1 | cut -d':' -f2 | tr -d ' ')
            echo "🎯 Quality Score: ${QUALITY}/100"
            
            # Win Rate
            WIN_RATE=$(grep -o '"win_rate":[^,}]*' "$LATEST_JSON" | head -1 | cut -d':' -f2 | tr -d ' ')
            echo "📈 Win Rate: ${WIN_RATE}%"
            
            # Total Trades
            N_TRADES=$(grep -o '"n_trades":[^,}]*' "$LATEST_JSON" | head -1 | cut -d':' -f2 | tr -d ' ')
            echo "🔢 Total Trades: ${N_TRADES}"
            
            echo ""
            echo "📁 ARQUIVOS .SET GERADOS:"
            echo "───────────────────────────────────────────────────────────────"
            ls -lh Presets/*_$(date +%Y%m%d).set 2>/dev/null | awk '{print "   " $9 " (" $5 ")"}'
            
            echo ""
            echo "════════════════════════════════════════════════════════════════"
            echo "✅ PROCESSO AUTOMÁTICO CONCLUÍDO COM SUCESSO!"
            echo "════════════════════════════════════════════════════════════════"
        else
            echo "⚠️  Nenhum arquivo JSON encontrado"
        fi
        
        break
    fi
    
    # Mostrar progresso a cada 2 minutos
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))
    ELAPSED_MIN=$((ELAPSED / 60))
    
    # Status do processo
    CPU=$(ps -p $PID -o %cpu --no-headers 2>/dev/null)
    MEM=$(ps -p $PID -o %mem --no-headers 2>/dev/null)
    
    echo "[$(date '+%H:%M:%S')] ⏳ ${ELAPSED_MIN}min | CPU: ${CPU}% | MEM: ${MEM}% | Status: PROCESSANDO..."
    
    # Última linha do log
    LAST_LINE=$(tail -1 analysis_progress.log 2>/dev/null | grep -oE '\[FASE [0-9]+/10\]' || echo "")
    if [ -n "$LAST_LINE" ]; then
        echo "                  └─ $LAST_LINE"
    fi
    
    # Aguardar 2 minutos
    sleep 120
done

# Sinalizar conclusão
echo ""
echo "🎉 Análise disponível para uso!"
touch .analysis_complete
