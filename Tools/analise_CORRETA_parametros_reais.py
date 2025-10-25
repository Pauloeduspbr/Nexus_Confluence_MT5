#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ANÁLISE CORRETA - Baseada em parâmetros REAIS do backtest
NÃO usa TP_RR (que não existe), usa SL_Points/TP_Points FIXOS
"""

print("=" * 80)
print("📋 PARÂMETROS REAIS DO BACKTEST (extraídos do Report HTML)")
print("=" * 80)
print()
print("🎯 STOP LOSS / TAKE PROFIT:")
print("   SL_Points = 220 (22 pips)")
print("   TP_Points = 1500 (150 pips)")
print("   Ratio TP:SL = 6.8:1 (FIXO)")
print()
print("🔍 FILTROS:")
print("   UseStrictFilters = true")
print("   RequireSupertrend = true")
print("   AllowGoodSetups = true")
print()
print("=" * 80)
print()

# Dados do backtest (430 trades de 2024-01-02 a 2024-08-05)
total_trades = 430
winners = 219  # 50.9%
losers = 211   # 49.1%

closes_at_tp = 64  # 14.9%
closes_at_sl = 366  # 85.1%

avg_winner_pips = 620.47
avg_loser_pips = -681.69

avg_winner_duration_min = 1116  # 18.6h
avg_loser_duration_min = 597    # 10.0h

profit_factor = 0.94
total_pips = -7955.00

print("📊 ESTATÍSTICAS DO BACKTEST:")
print(f"   Total de trades: {total_trades}")
print(f"   Vencedores: {winners} ({winners/total_trades*100:.1f}%)")
print(f"   Perdedores: {losers} ({losers/total_trades*100:.1f}%)")
print(f"   Profit Factor: {profit_factor:.2f}")
print(f"   Total de pips: {total_pips:.0f}")
print()

print("🎯 ANÁLISE DE FECHAMENTOS:")
print(f"   Fechamentos no TP (150 pips): {closes_at_tp} ({closes_at_tp/total_trades*100:.1f}%)")
print(f"   Fechamentos no SL (22 pips): {closes_at_sl} ({closes_at_sl/total_trades*100:.1f}%)")
print()

# INSIGHT CRÍTICO
print("=" * 80)
print("🚨 PROBLEMA IDENTIFICADO!")
print("=" * 80)
print()
print("❌ APENAS 14.9% DOS TRADES CHEGAM NO TP DE 150 PIPS!")
print("❌ 85.1% FECHAM NO SL DE 22 PIPS (perda)")
print()
print("🤔 CAUSA PROVÁVEL:")
print()
print("   1. TP MUITO LONGE (150 pips = 6.8x o SL)")
print("      → Preço precisa andar 150 pips na direção certa")
print("      → Muito difícil em mercado lateral")
print()
print("   2. SL MUITO APERTADO (22 pips)")
print("      → Noise normal do mercado aciona SL")
print("      → Trades bons sendo cortados prematuramente")
print()
print("   3. FILTROS MUITO ESTRITOS")
print("      → UseStrictFilters = true")
print("      → RequireSupertrend = true")
print("      → Entradas perfeitas, mas SL muito apertado não aguenta")
print()

# MATEMÁTICA
tp_points = 1500
sl_points = 220

expected_win_rate_for_breakeven = sl_points / (tp_points + sl_points)
print("📐 MATEMÁTICA:")
print(f"   Para BREAKEVEN com TP={tp_points} e SL={sl_points}:")
print(f"   Win Rate necessário = {expected_win_rate_for_breakeven*100:.1f}%")
print()
print(f"   Win Rate REAL = {winners/total_trades*100:.1f}%")
print()

if (winners/total_trades) < expected_win_rate_for_breakeven:
    diff = expected_win_rate_for_breakeven - (winners/total_trades)
    print(f"   ❌ FALTAM {diff*100:.1f}% de win rate para breakeven!")
else:
    surplus = (winners/total_trades) - expected_win_rate_for_breakeven
    print(f"   ✅ SOBRAM {surplus*100:.1f}% de win rate!")

print()

# Calcular win rate no TP
tp_win_rate = closes_at_tp / total_trades
print(f"🎯 Win rate quando chega no TP: {tp_win_rate*100:.1f}%")
print(f"   → Apenas {closes_at_tp} de {total_trades} trades chegam no TP!")
print()

# RECOMENDAÇÕES REAIS
print("=" * 80)
print("✅ RECOMENDAÇÕES BASEADAS NOS DADOS REAIS")
print("=" * 80)
print()

print("📋 OPÇÃO 1: REDUZIR TP (mais realista)")
print("   SL_Points = 220 (manter)")
print("   TP_Points = 800 (80 pips) → Ratio 3.6:1")
print("   Expectativa: Mais trades chegarão no TP")
print()

print("📋 OPÇÃO 2: AUMENTAR SL (dar mais espaço)")
print("   SL_Points = 400 (40 pips) → Ratio 3.75:1")
print("   TP_Points = 1500 (manter)")
print("   Expectativa: Menos trades cortados no SL")
print()

print("📋 OPÇÃO 3: BALANCEAR AMBOS")
print("   SL_Points = 300 (30 pips)")
print("   TP_Points = 900 (90 pips) → Ratio 3.0:1")
print("   Win rate necessário: 25% (mais alcançável)")
print()

print("📋 OPÇÃO 4: IMPLEMENTAR TRAILING STOP")
print("   Adicionar parâmetros:")
print("   - BreakevenActivationRR = 1.5")
print("   - TrailingActivationRR = 2.0")
print("   - TrailingStopATRMultiplier = 2.5")
print("   Expectativa: Proteger lucros e deixar correr")
print()

print("🎯 RECOMENDAÇÃO PRINCIPAL:")
print("   1. OPÇÃO 3 (SL=300, TP=900) + TRAILING STOP")
print("   2. Testar em backtest comparativo")
print("   3. Monitorar win rate e profit factor")
print()

print("=" * 80)
print("📊 CONCLUSÃO")
print("=" * 80)
print()
print("O problema NÃO é 'TP curto' - é o CONTRÁRIO!")
print("TP está MUITO LONGO (150 pips) e SL muito apertado (22 pips)")
print("Apenas 14.9% dos trades conseguem chegar no TP!")
print()
print("Solução: BALANCEAR TP/SL para win rate alcançável (>25%)")
print()
print("=" * 80)
