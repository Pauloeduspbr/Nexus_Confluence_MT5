#!/bin/bash
# Script de Diagnóstico Automático
# Aguarda análise completa e processa resultados

echo "════════════════════════════════════════════════════════════"
echo "🤖 AGENTE AUTÔNOMO - DIAGNÓSTICO E CORREÇÃO"
echo "════════════════════════════════════════════════════════════"
echo ""

# Aguardar processo terminar
while ps aux | grep "[p]ython Tools/master_analyzer.py" > /dev/null; do
    echo -ne "\r⏳ Aguardando análise completar... $(date +%H:%M:%S)  "
    sleep 10
done

echo -e "\n"
echo "✅ Análise concluída!"
echo ""

# Encontrar arquivo JSON mais recente
LATEST_JSON=$(ls -t analysis_output/master_analysis_*.json 2>/dev/null | head -1)

if [ -z "$LATEST_JSON" ]; then
    echo "❌ Nenhum arquivo de análise encontrado!"
    echo "📁 Arquivos disponíveis:"
    ls -lh analysis_output/
    exit 1
fi

echo "📄 Arquivo encontrado: $LATEST_JSON"
echo ""

# Extrair Quality Score
QUALITY_SCORE=$(python3 -c "
import json
try:
    with open('$LATEST_JSON') as f:
        data = json.load(f)
        score = data.get('summary', {}).get('quality_score', 0)
        print(f'{score:.1f}')
except:
    print('0.0')
")

echo "════════════════════════════════════════════════════════════"
echo "📊 QUALITY SCORE: $QUALITY_SCORE/100"
echo "════════════════════════════════════════════════════════════"
echo ""

# Classificar status
if (( $(echo "$QUALITY_SCORE >= 70" | bc -l) )); then
    echo "🟢 STATUS: BOM - Sistema validado!"
elif (( $(echo "$QUALITY_SCORE >= 50" | bc -l) )); then
    echo "🟡 STATUS: MÉDIO - Ajustes necessários"
else
    echo "🔴 STATUS: CRÍTICO - Revisar sistema completo"
fi

echo ""
echo "📋 Relatório completo salvo em:"
echo "   $LATEST_JSON"
echo ""
echo "════════════════════════════════════════════════════════════"
echo "✅ DIAGNÓSTICO AUTOMÁTICO CONCLUÍDO"
echo "════════════════════════════════════════════════════════════"
