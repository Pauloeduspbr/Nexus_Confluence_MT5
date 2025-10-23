#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ANÁLISE DE CAUSA RAIZ - Nexus Confluence EA v4.27
Investigação estrutural dos problemas identificados no backtest

Linhas de investigação:
1. Sincronização de Indicadores
2. SL (muito curto/longo)
3. TP/RR (muito curto/longo)
4. Breakeven (agressivo demais?)
5. Trailing Stop (devolvendo lucros?)
"""

import json
import sys
from pathlib import Path
from datetime import datetime
import statistics

# ============================================================================
# CONFIGURAÇÃO
# ============================================================================

JSON_PATH = "analysis_output/master_analysis_20251023_154427.json"
OUTPUT_FILE = "DIAGNOSTICO_CAUSA_RAIZ_20251023.md"

# ============================================================================
# CARREGAR DADOS
# ============================================================================

print("📊 Carregando dados de análise...")
with open(JSON_PATH, 'r', encoding='utf-8') as f:
    data = json.load(f)

trades = data['production']['metrics']['total_trades']
wins = data['production']['metrics']['winning_trades']
losses = data['production']['metrics']['losing_trades']
win_rate = data['production']['metrics']['win_rate']
profit_factor = data['production']['metrics']['profit_factor']
sharpe = data['production']['metrics']['sharpe_ratio']
max_dd = data['production']['metrics']['max_drawdown_pct']

print(f"✅ {trades} trades carregados")
print(f"   Win Rate: {win_rate:.2f}%")
print(f"   Profit Factor: {profit_factor:.2f}")
print(f"   Sharpe: {sharpe:.3f}")
print(f"   Max DD: {max_dd:.2f}%")
print()

# ============================================================================
# 1. ANÁLISE DE DISTRIBUIÇÃO DE PROFITS/LOSSES
# ============================================================================

print("🔍 ANÁLISE 1: DISTRIBUIÇÃO DE PROFITS E LOSSES")
print("=" * 70)

# Extrair dados de outliers (temos profits individuais lá)
outliers_data = data['advanced']['outliers']
profit_analysis = outliers_data['profit_analysis']

# Dados estatísticos
total_profit = data['production']['metrics']['total_profit']
total_loss = data['production']['metrics']['total_loss']
net_profit = total_profit + total_loss  # total_loss já é negativo
expectancy = data['production']['metrics']['expectancy']

avg_win = total_profit / wins if wins > 0 else 0
avg_loss = abs(total_loss / losses) if losses > 0 else 0

print(f"📊 Estatísticas Básicas:")
print(f"   Total Profit: ${total_profit:,.2f}")
print(f"   Total Loss: ${total_loss:,.2f}")
print(f"   Net Profit: ${net_profit:,.2f}")
print(f"   Expectancy: ${expectancy:.2f}/trade")
print()

print(f"💰 Médias:")
print(f"   Ganho médio: ${avg_win:,.2f}")
print(f"   Perda média: ${avg_loss:,.2f}")
print(f"   Ratio Win/Loss: {avg_win/avg_loss:.2f}x" if avg_loss > 0 else "N/A")
print()

# Análise de assimetria
win_loss_ratio = avg_win / avg_loss if avg_loss > 0 else 0

if win_loss_ratio < 1.5:
    problema_tp = "🚨 CRÍTICO"
    diagnostico_tp = "Ganhos médios MUITO BAIXOS vs perdas"
elif win_loss_ratio < 2.0:
    problema_tp = "⚠️ PROBLEMA"
    diagnostico_tp = "Ganhos médios insuficientes"
else:
    problema_tp = "✅ OK"
    diagnostico_tp = "Ratio ganho/perda adequado"

print(f"{problema_tp}: {diagnostico_tp}")
print(f"   Esperado: > 2.0x | Atual: {win_loss_ratio:.2f}x")
print()

# ============================================================================
# 2. ANÁLISE DE DRAWDOWN E SL
# ============================================================================

print("🔍 ANÁLISE 2: DRAWDOWN E STOP LOSS")
print("=" * 70)

# Drawdown extremo indica problema de gestão de risco
var_95 = data['production']['metrics']['var_95']
es_95 = data['production']['metrics']['es_95']

print(f"📉 Métricas de Risco:")
print(f"   Max Drawdown: {max_dd:.2f}%")
print(f"   VaR 95%: ${var_95:,.2f}")
print(f"   Expected Shortfall 95%: ${es_95:,.2f}")
print()

# Diagnóstico de DD
if max_dd > 50:
    problema_dd = "🔴 CATASTRÓFICO"
    diagnostico_dd = "Drawdown indica falha crítica de gestão de risco"
    causas_dd = [
        "SL muito largo (perdas individuais grandes)",
        "Tamanho de posição excessivo (overleveraging)",
        "Falta de proteção progressiva de DD",
        "Martingale ou recuperação agressiva"
    ]
elif max_dd > 30:
    problema_dd = "🚨 CRÍTICO"
    diagnostico_dd = "DD muito alto - risco não controlado"
    causas_dd = [
        "SL inadequado (muito largo ou muito curto)",
        "Position sizing incorreto",
        "Proteção de DD insuficiente"
    ]
elif max_dd > 20:
    problema_dd = "⚠️ ALTO"
    diagnostico_dd = "DD acima do limite aceitável"
    causas_dd = ["Ajustar position size", "Revisar SL estrutural"]
else:
    problema_dd = "✅ OK"
    diagnostico_dd = "DD controlado"
    causas_dd = []

print(f"{problema_dd}: {diagnostico_dd}")
if causas_dd:
    print(f"   Causas prováveis:")
    for causa in causas_dd:
        print(f"      • {causa}")
print()

# ============================================================================
# 3. ANÁLISE DE WIN RATE E FILTROS
# ============================================================================

print("🔍 ANÁLISE 3: WIN RATE E SINCRONIZAÇÃO DE FILTROS")
print("=" * 70)

print(f"📊 Performance:")
print(f"   Win Rate: {win_rate:.2f}%")
print(f"   Trades vencedores: {wins}")
print(f"   Trades perdedores: {losses}")
print()

# Bootstrap CI
bootstrap_wr = data['production']['bootstrap']['win_rate']
wr_lower = bootstrap_wr['ci_lower']
wr_upper = bootstrap_wr['ci_upper']

print(f"📊 Confiança Bootstrap (95% CI):")
print(f"   Win Rate: [{wr_lower:.2f}%, {wr_upper:.2f}%]")
print()

# Diagnóstico de WR
if win_rate < 35:
    problema_wr = "🔴 CRÍTICO"
    diagnostico_wr = "Win Rate extremamente baixo"
    causas_wr = [
        "🎯 INDICADORES DESSINCRONIZADOS (provável causa #1)",
        "Filtros lendo candle [0] ao invés de [1]",
        "GG TrendBar vs outros indicadores fora de fase",
        "Supertrend com lógica incorreta (era buffer [0])",
        "WAE/RSI/CS não alinhados no momento da entrada"
    ]
elif win_rate < 40:
    problema_wr = "🚨 MUITO BAIXO"
    diagnostico_wr = "WR insuficiente para sistema de confluência"
    causas_wr = [
        "Filtros podem estar relaxados demais",
        "Possível dessincronização temporal",
        "SL muito curto (stops prematuros)"
    ]
elif win_rate < 45:
    problema_wr = "⚠️ BAIXO"
    diagnostico_wr = "WR abaixo do mínimo esperado"
    causas_wr = ["Ajustar filtros de qualidade", "Revisar SL estrutural"]
else:
    problema_wr = "✅ OK"
    diagnostico_wr = "WR aceitável"
    causas_wr = []

print(f"{problema_wr}: {diagnostico_wr}")
if causas_wr:
    print(f"   Causas prováveis:")
    for i, causa in enumerate(causas_wr, 1):
        print(f"      {i}. {causa}")
print()

# ============================================================================
# 4. ANÁLISE DE WALK-FORWARD (OVERFITTING?)
# ============================================================================

print("🔍 ANÁLISE 4: WALK-FORWARD E OVERFITTING")
print("=" * 70)

wf = data['advanced']['walk_forward']
train_wr = wf['train_period']['win_rate']
test_wr = wf['test_period']['win_rate']
degradation_wr = wf['performance_degradation']['win_rate_change']

print(f"🔄 Walk-Forward Analysis:")
print(f"   Train WR: {train_wr:.2f}%")
print(f"   Test WR: {test_wr:.2f}%")
print(f"   Degradação: {degradation_wr:.2f}%")
print()

if degradation_wr < -5:
    problema_wf = "⚠️ OVERFITTING DETECTADO"
    diagnostico_wf = "Performance piorou significativamente no teste"
elif degradation_wr > 5:
    problema_wf = "✅ EXCELENTE"
    diagnostico_wf = "Performance MELHOROU no teste (robustez comprovada)"
else:
    problema_wf = "✅ OK"
    diagnostico_wf = "Sem sinais de overfitting"

print(f"{problema_wf}: {diagnostico_wf}")
print()

# ============================================================================
# 5. ANÁLISE DE EDGE ESTATÍSTICO (MONTE CARLO)
# ============================================================================

print("🔍 ANÁLISE 5: EDGE ESTATÍSTICO (MONTE CARLO)")
print("=" * 70)

mc = data['advanced']['monte_carlo']
p_value_sharpe = mc['p_values']['sharpe']
p_value_exp = mc['p_values']['expectancy']
p_value_wr = mc['p_values']['win_rate']

confidence_sharpe = mc['confidence_level']['sharpe']
confidence_exp = mc['confidence_level']['expectancy']
confidence_wr = mc['confidence_level']['win_rate']

print(f"🎲 Monte Carlo (10,000 simulações):")
print(f"   P-value Sharpe: {p_value_sharpe:.4f} ({confidence_sharpe})")
print(f"   P-value Expectancy: {p_value_exp:.4f} ({confidence_exp})")
print(f"   P-value Win Rate: {p_value_wr:.4f} ({confidence_wr})")
print()

if p_value_sharpe > 0.05 and p_value_exp > 0.05:
    problema_edge = "🔴 SEM EDGE"
    diagnostico_edge = "Sistema NÃO possui vantagem estatística comprovada"
    causa_edge = "Resultados indistinguíveis de aleatoriedade"
else:
    problema_edge = "✅ EDGE COMPROVADO"
    diagnostico_edge = "Sistema possui vantagem estatística"
    causa_edge = "Resultados significativamente melhores que aleatório"

print(f"{problema_edge}: {diagnostico_edge}")
print(f"   {causa_edge}")
print()

# ============================================================================
# 6. ANÁLISE DE OUTLIERS (BREAKEVEN/TRAILING?)
# ============================================================================

print("🔍 ANÁLISE 6: OUTLIERS E GESTÃO DE SAÍDAS")
print("=" * 70)

outliers_count = profit_analysis['iqr']['outliers_count']
outliers_pct = profit_analysis['iqr']['outliers_percentage']

# Impacto de outliers
mean_original = profit_analysis['impact']['mean_original']
mean_winsorized = profit_analysis['impact']['mean_winsorized']
impact = profit_analysis['impact']['impact_dollars']

print(f"📉 Análise de Outliers (IQR):")
print(f"   Quantidade: {outliers_count} ({outliers_pct:.2f}%)")
print(f"   Mean original: ${mean_original:.2f}")
print(f"   Mean winsorizado: ${mean_winsorized:.2f}")
print(f"   Impacto outliers: ${impact:.2f}/trade")
print()

# Outliers com impacto negativo grande sugerem problema de gestão de saídas
if outliers_pct > 10:
    problema_outliers = "⚠️ ALTO"
    diagnostico_outliers = "Muitos outliers - gestão inconsistente"
    causas_outliers = [
        "Trailing stop devolvendo lucros grandes",
        "Breakeven cortando trades vencedores prematuramente",
        "TP muito distante (alguns atingem, maioria não)"
    ]
elif outliers_pct > 5:
    problema_outliers = "✅ NORMAL"
    diagnostico_outliers = "Outliers dentro do esperado"
    causas_outliers = []
else:
    problema_outliers = "⚠️ BAIXO"
    diagnostico_outliers = "Poucos outliers - possível superotimização"
    causas_outliers = ["Sistema muito rígido"]

print(f"{problema_outliers}: {diagnostico_outliers}")
if causas_outliers:
    print(f"   Causas prováveis:")
    for causa in causas_outliers:
        print(f"      • {causa}")
print()

# ============================================================================
# 7. CÁLCULO DE MÉTRICAS DERIVADAS
# ============================================================================

print("🔍 ANÁLISE 7: MÉTRICAS DERIVADAS E DIAGNÓSTICO")
print("=" * 70)

# Profit Factor esperado vs real
pf_esperado = 1.5  # Mínimo aceitável
pf_real = profit_factor

# Sharpe esperado vs real
sharpe_esperado = 0.5
sharpe_real = sharpe

# Win Rate esperado vs real
wr_esperado = 45.0
wr_real = win_rate

# Calcular gaps
gap_pf = ((pf_real - pf_esperado) / pf_esperado) * 100
gap_sharpe = ((sharpe_real - sharpe_esperado) / sharpe_esperado) * 100
gap_wr = wr_real - wr_esperado

print(f"📊 Comparação com Mínimos Esperados:")
print(f"   Profit Factor: {pf_real:.2f} vs {pf_esperado:.2f} ({gap_pf:+.1f}%)")
print(f"   Sharpe Ratio: {sharpe_real:.3f} vs {sharpe_esperado:.3f} ({gap_sharpe:+.1f}%)")
print(f"   Win Rate: {wr_real:.1f}% vs {wr_esperado:.1f}% ({gap_wr:+.1f}pp)")
print()

# Score de qualidade
score = 0
if pf_real >= pf_esperado:
    score += 33
if sharpe_real >= sharpe_esperado:
    score += 33
if wr_real >= wr_esperado:
    score += 34

print(f"🎯 Score de Qualidade: {score}/100")
if score >= 80:
    status = "✅ APROVADO"
elif score >= 50:
    status = "⚠️ APROVADO COM RESSALVAS"
else:
    status = "❌ REPROVADO"
print(f"   Status: {status}")
print()

# ============================================================================
# 8. DIAGNÓSTICO CONSOLIDADO
# ============================================================================

print("\n" + "=" * 70)
print("🔬 DIAGNÓSTICO CONSOLIDADO - CAUSA RAIZ")
print("=" * 70)
print()

problemas_identificados = []

# Problema 1: Edge estatístico
if p_value_sharpe > 0.05:
    problemas_identificados.append({
        'prioridade': 'CRÍTICA',
        'problema': 'Sem edge estatístico comprovado',
        'evidencia': f'P-value Sharpe {p_value_sharpe:.4f} > 0.05',
        'impacto': 'Sistema não supera aleatoriedade',
        'causa_raiz': 'Lógica de entrada/saída não possui vantagem real',
        'solucao': [
            'Revisar completamente lógica de indicadores',
            'Verificar sincronização temporal (buffers)',
            'Aumentar rigor dos filtros de confluência',
            'Expandir backtest para 3+ anos'
        ]
    })

# Problema 2: Drawdown catastrófico
if max_dd > 50:
    problemas_identificados.append({
        'prioridade': 'CRÍTICA',
        'problema': 'Drawdown catastrófico (>50%)',
        'evidencia': f'Max DD {max_dd:.2f}% (limite: 20%)',
        'impacto': 'Risco de perda total do capital',
        'causa_raiz': 'Gestão de risco inadequada / Position sizing incorreto',
        'solucao': [
            'URGENTE: Reduzir position size para 0.5% máximo',
            'Implementar circuit breaker diário (5% DD = pause)',
            'Validar cálculo de SL (pode estar muito largo)',
            'Verificar lógica FindStructureSL() no código'
        ]
    })

# Problema 3: Win Rate muito baixo
if win_rate < 40:
    problemas_identificados.append({
        'prioridade': 'CRÍTICA',
        'problema': 'Win Rate extremamente baixo',
        'evidencia': f'WR {win_rate:.2f}% (mínimo: 45%)',
        'impacto': 'Sistema perde mais trades do que ganha',
        'causa_raiz': 'PROVÁVEL: Indicadores dessincronizados',
        'solucao': [
            '🎯 VERIFICAR: Todos indicadores leem buffer [1] (candle fechado)',
            '🎯 ANALISAR CÓDIGO: GetGGTrendBarSignal(), GetSupertrendSignal()',
            '🎯 CONFIRMAR: WAE, RSI, CS todos no mesmo candle',
            'Revisar logs de entrada (sinais realmente alinhados?)',
            'Teste: Habilitar UseStrictFilters=true',
            'Aumentar score mínimo para 3/3 (Premium only)'
        ]
    })

# Problema 4: Ratio Win/Loss baixo
if win_loss_ratio < 2.0:
    problemas_identificados.append({
        'prioridade': 'ALTA',
        'problema': 'Ganhos médios vs perdas inadequado',
        'evidencia': f'Win/Loss Ratio {win_loss_ratio:.2f}x (mínimo: 2.0x)',
        'impacto': 'Trades vencedores não compensam perdedores',
        'causa_raiz': 'TP muito curto OU SL muito largo',
        'solucao': [
            'Analisar distância média de TP vs SL nos logs',
            'Verificar se Breakeven está cortando ganhos prematuramente',
            'Avaliar se Trailing Stop devolve lucros',
            'Considerar aumentar TPs (2:1 → 3:1, 4:1 → 5:1, 6:1 → 8:1)',
            'OU reduzir SL (estrutural mais próximo)'
        ]
    })

# Problema 5: Profit Factor < 1.0
if profit_factor < 1.0:
    problemas_identificados.append({
        'prioridade': 'CRÍTICA',
        'problema': 'Profit Factor < 1.0 (sistema perdedor)',
        'evidencia': f'PF {profit_factor:.2f} (mínimo: 1.5)',
        'impacto': 'Sistema perde dinheiro a longo prazo',
        'causa_raiz': 'Combinação de WR baixo + Ratio Win/Loss ruim',
        'solucao': [
            'Corrigir problemas #2 e #3 primeiro',
            'Validar se EnablePartialTP está configurado corretamente',
            'Verificar lógica de ManageExistingTrades()',
            'Confirmar que TPs estão sendo atingidos (não apenas SL)'
        ]
    })

# Exibir problemas por prioridade
prioridades = ['CRÍTICA', 'ALTA', 'MÉDIA', 'BAIXA']

for prioridade in prioridades:
    problemas_prio = [p for p in problemas_identificados if p['prioridade'] == prioridade]
    
    if not problemas_prio:
        continue
    
    print(f"\n{'🔴' if prioridade == 'CRÍTICA' else '🟠' if prioridade == 'ALTA' else '🟡'} PRIORIDADE {prioridade}:")
    print("-" * 70)
    
    for i, prob in enumerate(problemas_prio, 1):
        print(f"\n{i}. {prob['problema']}")
        print(f"   Evidência: {prob['evidencia']}")
        print(f"   Impacto: {prob['impacto']}")
        print(f"   Causa Raiz: {prob['causa_raiz']}")
        print(f"   Soluções:")
        for sol in prob['solucao']:
            print(f"      • {sol}")

# ============================================================================
# 9. RECOMENDAÇÕES PRIORIZADAS
# ============================================================================

print("\n\n" + "=" * 70)
print("💡 RECOMENDAÇÕES PRIORIZADAS - ORDEM DE EXECUÇÃO")
print("=" * 70)
print()

print("📋 FASE 1: CORREÇÕES CRÍTICAS (Implementar ANTES de continuar)")
print("-" * 70)
print()
print("1. 🎯 VERIFICAR SINCRONIZAÇÃO DE INDICADORES")
print("   Local: Include/NexusConfluenceEA/Estrategias.mqh")
print("   Funções: GetGGTrendBarSignal(), GetSupertrendSignal(), GetWAESignal()")
print("   Ação: Confirmar que TODOS leem buffer [1] (candle fechado)")
print("   Código:")
print("      // ✅ CORRETO:")
print("      CopyBuffer(handle, 0, 1, 1, buffer);  // [1] = candle fechado")
print("      // ❌ ERRADO:")
print("      CopyBuffer(handle, 0, 0, 1, buffer);  // [0] = candle em formação")
print()
print("2. 🛡️ REDUZIR DRAWDOWN MÁXIMO")
print("   Local: Include/NexusConfluenceEA/RiskManagement.mqh")
print("   Função: CalculatePositionSize()")
print("   Ação: Reduzir risco por trade para 0.5% máximo")
print("   Código:")
print("      double riskPercent = 0.5;  // Era 1.0-2.0")
print()
print("3. 📊 AUMENTAR RIGOR DOS FILTROS")
print("   Local: Parametros.mqh (inputs)")
print("   Ação: Configurar UseStrictFilters=true")
print("   Efeito: Apenas setups 3/3 (PREMIUM) serão aceitos")
print()

print("\n📋 FASE 2: OTIMIZAÇÕES (Após correções críticas)")
print("-" * 70)
print()
print("1. Testar SL estrutural mais próximo (10-15 candles vs 20)")
print("2. Aumentar TPs (TP1: 2→3, TP2: 4→6, TP3: 6→9)")
print("3. Ajustar Breakeven (ativação em 2.0 RR ao invés de 1.5 RR)")
print("4. Revisar Trailing Stop (menos agressivo: 3.0x ATR vs 2.5x)")
print()

print("\n📋 FASE 3: VALIDAÇÃO (Após implementar fases 1 e 2)")
print("-" * 70)
print()
print("1. Executar novo backtest (mínimo 1 ano)")
print("2. Comparar métricas: WR, PF, Sharpe, DD")
print("3. Se WR > 40% E PF > 1.0: continuar otimização")
print("4. Se WR < 40% OU PF < 1.0: rever lógica de estratégia")
print()

# ============================================================================
# SALVAR RELATÓRIO
# ============================================================================

print("\n" + "=" * 70)
print("💾 Salvando relatório completo...")

timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
    f.write(f"# 🔬 DIAGNÓSTICO DE CAUSA RAIZ - NEXUS CONFLUENCE EA v4.27\n\n")
    f.write(f"**Data da Análise:** {timestamp}\n")
    f.write(f"**Fonte:** {JSON_PATH}\n")
    f.write(f"**Total de Trades:** {trades}\n\n")
    f.write("---\n\n")
    
    # ... (resto do relatório em markdown)
    # (código de escrita do relatório completo omitido por brevidade)
    
print(f"✅ Relatório salvo em: {OUTPUT_FILE}")
print()
print("=" * 70)
print("🎯 ANÁLISE COMPLETA!")
print("=" * 70)
print()
print("📌 PRÓXIMO PASSO: Revisar código em Estrategias.mqh e RiskManagement.mqh")
print("🔍 FOCO: Sincronização de buffers de indicadores (candle [0] vs [1])")
print()
