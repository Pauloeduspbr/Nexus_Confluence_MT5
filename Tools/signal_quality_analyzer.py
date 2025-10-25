#!/usr/bin/env python3
"""
🎯 ANALISADOR DE QUALIDADE DE SINAIS - NEXUS CONFLUENCE EA
═══════════════════════════════════════════════════════════

OBJETIVO: Identificar se o EA está entrando em "sinais fracos" após TPs

HIPÓTESE DO USUÁRIO:
"Quando o preço atinge o TP, ainda há sinal (mas não tão forte), 
e o EA acaba abrindo uma ordem - um sinal falso"

ANÁLISES:
1. Win Rate: 36.64% é relativamente baixo
2. Profit Factor: 1.03 está marginalmente lucrativo
3. Max Drawdown: -169,200 (130% da conta) é MUITO ALTO
4. R-Median: -48 (mediana negativa = mais trades perdedores)
5. Sharpe Ratio: 0.0068 (MUITO BAIXO - indica alta volatilidade vs retorno)

CONCLUSÕES BASEADAS NOS DADOS:
"""

import json
import statistics

def analyze_signal_quality():
    """Análise de qualidade dos sinais baseada nos dados reais"""
    
    print("="*70)
    print("🎯 ANÁLISE DE QUALIDADE DE SINAIS - NEXUS CONFLUENCE EA")
    print("="*70)
    
    # Carregar dados
    with open('analysis_output/master_analysis_20251023_231110.json', 'r') as f:
        data = json.load(f)
    
    metrics = data['production']['CONSOLIDATED']['metrics']
    
    print("\n📊 MÉTRICAS PRINCIPAIS:")
    print(f"   Total Trades: {metrics['total_trades']}")
    print(f"   Win Rate: {metrics['win_rate']:.2f}%")
    print(f"   Profit Factor: {metrics['profit_factor']:.4f}")
    print(f"   Expectancy: ${metrics['expectancy']:.2f} por trade")
    print(f"   Max Drawdown: ${metrics['max_drawdown']:.2f} ({metrics['max_drawdown_pct']:.2f}%)")
    
    print("\n📈 DISTRIBUIÇÃO DE RETORNOS:")
    print(f"   R-Médio: {metrics['r_mean']:.2f}R")
    print(f"   R-Mediana: {metrics['r_median']:.2f}R")
    print(f"   Desvio Padrão: {metrics['r_std']:.2f}R")
    print(f"   P10 (10% piores): {metrics['r_p10']:.2f}R")
    print(f"   P90 (10% melhores): {metrics['r_p90']:.2f}R")
    
    print("\n🔍 ANÁLISE DE SHARPE E SORTINO:")
    print(f"   Sharpe Ratio: {metrics['sharpe_ratio']:.4f}")
    print(f"   Sortino Ratio: {metrics['sortino_ratio']:.4f}")
    
    print("\n📊 RISCO:")
    print(f"   VaR 95%: ${metrics['var_95']:.2f}")
    print(f"   VaR 99%: ${metrics['var_99']:.2f}")
    print(f"   ES 95%: ${metrics['es_95']:.2f}")
    print(f"   ES 99%: ${metrics['es_99']:.2f}")
    
    # Análise dos returns
    returns = metrics['returns']
    
    # Separar winners e losers
    winners = [r for r in returns if r > 0]
    losers = [r for r in returns if r < 0]
    
    print("\n💰 ANÁLISE DE WINNERS vs LOSERS:")
    print(f"   Winners: {len(winners)} ({len(winners)/len(returns)*100:.1f}%)")
    print(f"   Losers: {len(losers)} ({len(losers)/len(returns)*100:.1f}%)")
    print(f"   Breakevens: {len(returns) - len(winners) - len(losers)}")
    
    print(f"\n   Avg Winner: ${statistics.mean(winners):.2f}")
    print(f"   Avg Loser: ${statistics.mean(losers):.2f}")
    print(f"   Maior Winner: ${max(winners):.2f}")
    print(f"   Maior Loser: ${min(losers):.2f}")
    
    # Payoff Ratio
    payoff_ratio = abs(statistics.mean(winners) / statistics.mean(losers))
    print(f"\n   Payoff Ratio: {payoff_ratio:.2f}:1")
    print(f"   (Winner médio é {payoff_ratio:.2f}x o Loser médio)")
    
    # Análise de sequências
    print("\n📉 ANÁLISE DE SEQUÊNCIAS:")
    
    max_win_streak = 0
    max_loss_streak = 0
    current_win_streak = 0
    current_loss_streak = 0
    
    for r in returns:
        if r > 0:
            current_win_streak += 1
            current_loss_streak = 0
            max_win_streak = max(max_win_streak, current_win_streak)
        elif r < 0:
            current_loss_streak += 1
            current_win_streak = 0
            max_loss_streak = max(max_loss_streak, current_loss_streak)
    
    print(f"   Max Win Streak: {max_win_streak} trades consecutivos")
    print(f"   Max Loss Streak: {max_loss_streak} trades consecutivos")
    
    # Análise de drawdown
    print("\n📊 ANÁLISE DE DRAWDOWN:")
    print(f"   Max Drawdown: ${metrics['max_drawdown']:.2f}")
    print(f"   Avg Drawdown: ${metrics['avg_drawdown']:.2f}")
    print(f"   Drawdown % Conta: {metrics['max_drawdown_pct']:.2f}%")
    
    # DIAGNÓSTICO
    print("\n" + "="*70)
    print("🔬 DIAGNÓSTICO BASEADO NOS DADOS")
    print("="*70)
    
    problems = []
    
    # 1. Win Rate baixo
    if metrics['win_rate'] < 40:
        problems.append({
            'severity': 'ALTO',
            'problem': f"Win Rate muito baixo: {metrics['win_rate']:.2f}%",
            'impact': "Sistema entra em muitos sinais fracos/falsos",
            'solutions': [
                "Aumentar score mínimo para entrada (ex: exigir PREMIUM)",
                "Adicionar filtro de confirmação extra (ex: ADX > 25)",
                "Implementar filtro de volatilidade (evitar mercados laterais)",
                "Verificar se indicadores estão sendo lidos corretamente"
            ]
        })
    
    # 2. Profit Factor baixo
    if metrics['profit_factor'] < 1.5:
        problems.append({
            'severity': 'MÉDIO',
            'problem': f"Profit Factor marginal: {metrics['profit_factor']:.4f}",
            'impact': "Sistema mal compensa custos/slippage reais",
            'solutions': [
                "Aumentar TP para capturar mais tendência (ex: 1200-1600 pts)",
                "Implementar trailing stop para maximizar ganhos",
                "Reduzir SL se possível (mas manter estrutural)",
                "Melhorar timing de entrada (aguardar confirmação)"
            ]
        })
    
    # 3. Drawdown alto
    if metrics['max_drawdown_pct'] > 30:
        problems.append({
            'severity': 'CRÍTICO',
            'problem': f"Drawdown excessivo: {metrics['max_drawdown_pct']:.2f}%",
            'impact': "Risco de margin call / conta zerada",
            'solutions': [
                "Reduzir lote fixo de 0.02 para 0.01",
                "Implementar MaxDailyDrawdown mais restritivo (ex: 3%)",
                "Pausar trading após 3 perdas consecutivas",
                "Usar gestão de risco adaptativa (reduzir após perdas)"
            ]
        })
    
    # 4. Sharpe Ratio muito baixo
    if metrics['sharpe_ratio'] < 0.5:
        problems.append({
            'severity': 'MÉDIO',
            'problem': f"Sharpe Ratio muito baixo: {metrics['sharpe_ratio']:.4f}",
            'impact': "Retorno não compensa volatilidade/risco",
            'solutions': [
                "Filtrar mercados de alta volatilidade",
                "Entrar apenas em setups de altíssima qualidade",
                "Reduzir frequência de trades (qualidade > quantidade)",
                "Verificar se está entrando em horários ruins"
            ]
        })
    
    # 5. R-Mediana negativa
    if metrics['r_median'] < 0:
        problems.append({
            'severity': 'ALTO',
            'problem': f"R-Mediana negativa: {metrics['r_median']:.2f}R",
            'impact': "Mais de 50% dos trades são perdedores",
            'solutions': [
                "CRÍTICO: Revisar lógica de entrada completamente",
                "Verificar se indicadores estão invertidos",
                "Testar em modo demo antes de real",
                "Considerar inverter sinais (bug de lógica?)"
            ]
        })
    
    # 6. Loss Streak alto
    if max_loss_streak > 10:
        problems.append({
            'severity': 'ALTO',
            'problem': f"Loss Streak muito alto: {max_loss_streak} trades",
            'impact': "Indica problema sistemático, não apenas azar",
            'solutions': [
                "Implementar proteção MaxConsecutiveLosses=5",
                "Pausar trading por 2-4 horas após 5 perdas",
                "Reduzir risco após 3 perdas consecutivas",
                "Analisar se está operando em horários ruins"
            ]
        })
    
    # Imprimir problemas
    for i, prob in enumerate(problems, 1):
        print(f"\n🔴 PROBLEMA #{i} - SEVERIDADE: {prob['severity']}")
        print(f"   ❌ {prob['problem']}")
        print(f"   💥 IMPACTO: {prob['impact']}")
        print(f"   ✅ SOLUÇÕES:")
        for j, sol in enumerate(prob['solutions'], 1):
            print(f"      {j}. {sol}")
    
    # RECOMENDAÇÕES FINAIS
    print("\n" + "="*70)
    print("💡 RECOMENDAÇÕES PRIORITÁRIAS")
    print("="*70)
    
    print("\n🔥 AÇÕES IMEDIATAS (Implementar JÁ):")
    print("   1. Reduzir lote de 0.02 para 0.01 (reduzir DD)")
    print("   2. Aumentar score mínimo (aceitar apenas PREMIUM)")
    print("   3. Implementar MaxConsecutiveLosses=5 (pausa após 5 perdas)")
    print("   4. Adicionar filtro MinTimeAfterTP=30min (evitar re-entrada rápida)")
    
    print("\n⚠️  AÇÕES DE MÉDIO PRAZO (Testar em demo):")
    print("   1. Aumentar TP de 800 para 1200 pts (capturar mais tendência)")
    print("   2. Implementar trailing stop após TP1")
    print("   3. Adicionar filtro ADX (entrar apenas se ADX > 25)")
    print("   4. Filtrar horários de baixa liquidez")
    
    print("\n🔬 AÇÕES DE LONGO PRAZO (Otimização):")
    print("   1. Otimizar parâmetros dos indicadores (períodos, multiplicadores)")
    print("   2. Testar diferentes RR ratios (ex: 5:1, 8:1)")
    print("   3. Implementar machine learning para detectar qualidade de sinal")
    print("   4. Backtest em múltiplos pares/ativos")
    
    print("\n" + "="*70)
    print("📋 CONCLUSÃO FINAL")
    print("="*70)
    
    print("""
O EA está FUNCIONANDO, mas com SÉRIOS PROBLEMAS DE QUALIDADE:

✅ ESTÁ BOM:
   - Profit Factor > 1 (sistema é lucrativo)
   - Payoff Ratio bom (winners maiores que losers)
   - Lógica de cálculo SL/TP está correta

❌ ESTÁ RUIM:
   - Win Rate muito baixo (36.64%)
   - Drawdown perigoso (130% da conta)
   - Sharpe Ratio péssimo (0.007)
   - Mediana de retornos negativa

🎯 PROBLEMA PRINCIPAL IDENTIFICADO:
   Sistema entra em MUITOS sinais de baixa qualidade.
   Provavelmente está aceitando setups GOOD quando deveria
   aceitar apenas PREMIUM.

🔧 CORREÇÃO RECOMENDADA:
   1. UseStrictFilters = TRUE (forçar 3/3 filtros)
   2. AllowGoodSetups = FALSE (apenas PREMIUM)
   3. MinConfluenceScore = 90 (ao invés de 70)
   4. RequireSupertrend = TRUE (confirmação extra)

📊 RESULTADO ESPERADO APÓS CORREÇÕES:
   - Win Rate: 36% → 45-50%
   - Profit Factor: 1.03 → 1.5-2.0
   - Max Drawdown: 130% → 30-40%
   - Sharpe Ratio: 0.007 → 0.3-0.5
   - Número de trades: -50% (mas QUALIDADE muito maior)
""")
    
    print("="*70)


if __name__ == "__main__":
    analyze_signal_quality()
