#!/bin/bash

# Script de Monitoramento Completo Unificado v4.32
# Integra análise + monitoramento em tempo real + correções automáticas

set -euo pipefail

START_TIME=$(date +%s)
VERSION="v4.32"

# Detectar PID da análise se já está rodando
PID=$(cat .analysis_pid 2>/dev/null || echo "")

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

print_banner() {
    clear
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}      🚀 SISTEMA AUTOMÁTICO COMPLETO ${VERSION} 🚀${NC}"
    echo -e "${CYAN}       Nexus Confluence EA - Monitoramento em Tempo Real${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    if [ -n "$PID" ]; then
        echo -e "${GREEN}📊 PID Análise: $PID${NC}"
    fi
    echo -e "${YELLOW}⏳ Iniciado em: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo -e "${RED}${BOLD}🔴 ZERO INTERVENÇÃO HUMANA - PROCESSO AUTOMÁTICO COMPLETO!${NC}"
    echo ""
    echo -e "${BLUE}ETAPAS DO PROCESSO:${NC}"
    echo "  [1/5] Análise do Log MT5      (Processando...)"
    echo "  [2/5] Análise do Código EA    (Aguardando...)"
    echo "  [3/5] Correções Automáticas   (Aguardando...)"
    echo "  [4/5] Geração de Presets .set (Aguardando...)"
    echo "  [5/5] Relatório Final         (Aguardando...)"
    echo ""
}

monitor_realtime() {
    # Monitorar progresso via arquivo de status JSON
    local status_file=".realtime_status.json"
    local last_progress=0
    local last_phase=""
    
    while [ -z "$PID" ] || ps -p $PID > /dev/null 2>&1 || [ -f "$status_file" ]; do
        CURRENT_TIME=$(date +%s)
        ELAPSED=$(((CURRENT_TIME - START_TIME) / 60))
        
        if [ -f "$status_file" ]; then
            # Ler progresso do JSON (requer jq)
            if command -v jq &> /dev/null; then
                current_progress=$(jq -r '.progress // 0' "$status_file" 2>/dev/null || echo "0")
                current_phase=$(jq -r '.current_phase // "PROCESSING"' "$status_file" 2>/dev/null || echo "PROCESSING")
                errors=$(jq -r '.errors | length' "$status_file" 2>/dev/null || echo "0")
                
                # Mostrar barra de progresso
                if [ "$current_progress" -ne "$last_progress" ] || [ "$current_phase" != "$last_phase" ]; then
                    filled=$((current_progress / 2))
                    empty=$((50 - filled))
                    bar=$(printf '█%.0s' $(seq 1 $filled))
                    spaces=$(printf ' %.0s' $(seq 1 $empty))
                    
                    echo -ne "\r${GREEN}[${bar}${spaces}]${NC} ${current_progress}% - ${current_phase}  "
                    
                    last_progress=$current_progress
                    last_phase=$current_phase
                fi
                
                if [ "$errors" -gt "0" ]; then
                    echo ""
                    echo -e "${RED}❌ Erros detectados: $errors${NC}"
                fi
            fi
        else
            # Fallback para monitoramento clássico
            if [ -n "$PID" ]; then
                CPU=$(ps -p $PID -o %cpu --no-headers 2>/dev/null | tr -d ' ' || echo "0")
                PHASE=$(tail -20 analysis_progress.log 2>/dev/null | grep -oE '\[FASE [0-9]+/10\]' | tail -1 || echo "")
                
                echo -e "\r[$(date '+%H:%M:%S')] ${ELAPSED}min | CPU:${CPU}% | ${PHASE:-Processando...}  "
            fi
        fi
        
        # Verificar se concluiu
        if [ -f ".analysis_complete" ]; then
            echo ""
            echo -e "${GREEN}✅ Processo concluído!${NC}"
            break
        fi
        
        sleep 2
    done
}

show_results() {
    local END_TIME=$(date +%s)
    local DURATION=$((END_TIME - START_TIME))
    local MINUTES=$((DURATION / 60))
    local SECONDS=$((DURATION % 60))
    
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}        ✅ PROCESSO AUTOMÁTICO 100% CONCLUÍDO!${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${GREEN}⏱️  Tempo Total: ${MINUTES}min ${SECONDS}s${NC}"
    echo ""
    
    # Verificar arquivos gerados
    LATEST_JSON=$(ls -t analysis_output/master_analysis_*.json 2>/dev/null | head -1)
    
    if [ -n "$LATEST_JSON" ]; then
        echo -e "${YELLOW}📁 ARQUIVOS GERADOS:${NC}"
        echo "   ✅ $(basename $LATEST_JSON)"
        echo "   ✅ $(basename $(ls -1 analysis_output/master_log_*.txt 2>/dev/null | tail -1))"
        
        FIX_REPORT=$(ls -t analysis_output/auto_fix_report_*.md 2>/dev/null | head -1)
        if [ -n "$FIX_REPORT" ]; then
            echo "   ✅ $(basename $FIX_REPORT)"
        fi
        
        FINAL_REPORT=$(ls -t RELATORIO_COMPLETO_${VERSION}_*.md 2>/dev/null | head -1)
        if [ -n "$FINAL_REPORT" ]; then
            echo "   ✅ $(basename $FINAL_REPORT)"
        fi
        
        echo ""
        echo -e "${YELLOW}� PRESETS .SET GERADOS (${VERSION}):${NC}"
        ls -1 Presets/*_${VERSION}_*.set 2>/dev/null | while read file; do
            echo "   ✅ $(basename $file)"
        done
        
        echo ""
        
        # Estatísticas do JSON
        if command -v jq &> /dev/null; then
            WIN_RATE=$(jq -r '.quality_metrics.win_rate // "N/A"' "$LATEST_JSON" 2>/dev/null)
            PROFIT_FACTOR=$(jq -r '.quality_metrics.profit_factor // "N/A"' "$LATEST_JSON" 2>/dev/null)
            N_TRADES=$(jq -r '.basic_stats.n_trades // "N/A"' "$LATEST_JSON" 2>/dev/null)
            
            echo -e "${YELLOW}📊 MÉTRICAS DA ANÁLISE:${NC}"
            echo "   📈 Win Rate: ${WIN_RATE}%"
            echo "   💰 Profit Factor: ${PROFIT_FACTOR}"
            echo "   🔢 Total Trades: ${N_TRADES}"
            echo ""
        fi
        
        # Contar problemas do fix report
        if [ -n "$FIX_REPORT" ]; then
            CRITICAL=$(grep -c "🔴" "$FIX_REPORT" 2>/dev/null || echo "0")
            IMPORTANT=$(grep -c "🟡" "$FIX_REPORT" 2>/dev/null || echo "0")
            
            echo -e "${YELLOW}🔧 CORREÇÕES DETECTADAS:${NC}"
            echo "   🔴 Críticas: $CRITICAL"
            echo "   🟡 Importantes: $IMPORTANT"
            echo ""
            
            if [ "$CRITICAL" -gt "0" ]; then
                echo -e "${RED}⚠️  AÇÃO NECESSÁRIA: Revisar correções críticas aplicadas${NC}"
            elif [ "$IMPORTANT" -gt "0" ]; then
                echo -e "${YELLOW}� RECOMENDADO: Revisar melhorias sugeridas${NC}"
            else
                echo -e "${GREEN}✅ EA OTIMIZADO: Configurações adequadas${NC}"
            fi
            echo ""
        fi
    fi
    
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}              🎯 PRÓXIMOS PASSOS${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "  1. ✅ Revisar relatório completo gerado"
    echo "  2. ✅ Verificar presets ${VERSION} em Presets/"
    echo "  3. ✅ Carregar preset adequado no MT5"
    echo "  4. ✅ Testar em conta DEMO por 48-72 horas"
    echo "  5. ✅ Validar métricas antes de considerar REAL"
    echo ""
    
    if [ -n "$FINAL_REPORT" ]; then
        echo -e "${GREEN}📊 Relatório Completo: $FINAL_REPORT${NC}"
        echo ""
    fi
}

# EXECUÇÃO PRINCIPAL
print_banner

echo -e "${BLUE}🔍 Monitorando processo em tempo real...${NC}"
echo ""

monitor_realtime

show_results

echo -e "${GREEN}${BOLD}Sistema executado com sucesso!${NC}"
echo ""
