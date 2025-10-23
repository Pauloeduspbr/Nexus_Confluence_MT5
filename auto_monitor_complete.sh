#!/bin/bash
PID=$(cat .analysis_pid 2>/dev/null || echo "0")
START_TIME=$(date +%s)

echo "════════════════════════════════════════════════════════════════"
echo "🤖 SISTEMA AUTOMÁTICO COMPLETO v4.31"
echo "════════════════════════════════════════════════════════════════"
echo "📊 PID Análise: $PID"
echo "⏳ Iniciado em: $(date '+%H:%M:%S')"
echo "🔴 ZERO INTERVENÇÃO HUMANA!"
echo ""
echo "ETAPAS:"
echo "  [1/4] Análise do Log       (Processando...)"
echo "  [2/4] Análise do Código EA (Aguardando...)"
echo "  [3/4] Correções Automáticas (Aguardando...)"
echo "  [4/4] Relatório Final      (Aguardando...)"
echo ""

while true; do
    if ! ps -p $PID > /dev/null 2>&1; then
        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))
        MINUTES=$((DURATION / 60))
        
        echo ""
        echo "════════════════════════════════════════════════════════════════"
        echo "✅ [1/4] ANÁLISE DO LOG COMPLETA EM ${MINUTES} MINUTOS!"
        echo "════════════════════════════════════════════════════════════════"
        echo ""
        
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
            
            echo "════════════════════════════════════════════════════════════════"
            echo "🔍 [2/4] INICIANDO ANÁLISE DO CÓDIGO EA..."
            echo "════════════════════════════════════════════════════════════════"
            echo ""
            
            # EXECUTAR AUTO FIX EA
            cd /mnt/d/EA_Projetos/Nexus_Confluence_MT5/Nexus_Confluence_MT5
            source venv/bin/activate
            python Tools/auto_fix_ea.py "$LATEST_JSON"
            
            echo ""
            echo "════════════════════════════════════════════════════════════════"
            echo "✅ [3/4] ANÁLISE COMPLETA!"
            echo "════════════════════════════════════════════════════════════════"
            echo ""
            
            # Verificar relatório de correções
            FIX_REPORT=$(ls -t analysis_output/auto_fix_report_*.md 2>/dev/null | head -1)
            
            if [ -n "$FIX_REPORT" ]; then
                echo "📁 RELATÓRIO DE CORREÇÕES:"
                echo "   $FIX_REPORT"
                echo ""
                
                # Contar problemas críticos
                CRITICAL=$(grep -c "🔴" "$FIX_REPORT" 2>/dev/null || echo "0")
                IMPORTANT=$(grep -c "🟡" "$FIX_REPORT" 2>/dev/null || echo "0")
                
                echo "🔴 Problemas Críticos: $CRITICAL"
                echo "🟡 Problemas Importantes: $IMPORTANT"
                echo ""
                
                if [ "$CRITICAL" -gt "0" ] || [ "$IMPORTANT" -gt "0" ]; then
                    echo "⚠️  CORREÇÕES NECESSÁRIAS NO CÓDIGO EA!"
                    echo ""
                    echo "📋 TOP 3 CORREÇÕES:"
                    grep -A 2 "###" "$FIX_REPORT" | head -15
                fi
            fi
            
            echo ""
            echo "════════════════════════════════════════════════════════════════"
            echo "📊 [4/4] RELATÓRIO FINAL"
            echo "════════════════════════════════════════════════════════════════"
            echo ""
            
            # Listar todos arquivos gerados
            echo "📁 ARQUIVOS GERADOS:"
            echo "   ✓ $LATEST_JSON"
            echo "   ✓ $(ls -1 analysis_output/master_log_*.txt 2>/dev/null | tail -1)"
            if [ -n "$FIX_REPORT" ]; then
                echo "   ✓ $FIX_REPORT"
            fi
            echo ""
            
            echo "📁 ARQUIVOS .SET:"
            ls -1 Presets/*_$(date +%Y%m%d).set 2>/dev/null | while read file; do
                echo "   ✓ $file"
            done
            echo ""
            
            echo "════════════════════════════════════════════════════════════════"
            echo "🎉 PROCESSO AUTOMÁTICO 100% CONCLUÍDO!"
            echo "════════════════════════════════════════════════════════════════"
            echo ""
            echo "⏱️  Tempo total: ${MINUTES} minutos"
            echo "✅ Análise do Log: Completa"
            echo "✅ Análise do Código EA: Completa"
            echo "✅ Detecção de Problemas: Completa"
            echo "✅ Relatórios: Gerados"
            echo ""
            
            if [ "$CRITICAL" -gt "0" ]; then
                echo "🔴 AÇÃO NECESSÁRIA: Revisar correções críticas no EA"
            elif [ "$IMPORTANT" -gt "0" ]; then
                echo "🟡 RECOMENDADO: Revisar melhorias sugeridas"
            else
                echo "✅ EA OTIMIZADO: Nenhuma correção necessária"
            fi
            
        else
            echo "⚠️  Nenhum arquivo JSON encontrado - análise falhou"
        fi
        
        touch .analysis_complete
        break
    fi
    
    CURRENT_TIME=$(date +%s)
    ELAPSED=$(((CURRENT_TIME - START_TIME) / 60))
    CPU=$(ps -p $PID -o %cpu --no-headers 2>/dev/null | tr -d ' ')
    PHASE=$(tail -20 analysis_progress.log 2>/dev/null | grep -oE '\[FASE [0-9]+/10\]' | tail -1)
    
    echo "[$(date '+%H:%M:%S')] ${ELAPSED}min | CPU:${CPU}% | ${PHASE:-[1/4] Processando log...}"
    
    sleep 120
done
