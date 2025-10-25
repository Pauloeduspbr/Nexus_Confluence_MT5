#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Analisador de Log de Debug - Extrai trades com novos logs formatados
"""

import codecs
import re
from datetime import datetime
import statistics

print("=" * 80)
print("ANÁLISE COMPLETA DO LOG DE DEBUG")
print("=" * 80)
print()

# Ler log (UTF-16 LE)
with codecs.open('log/20251025.log', 'r', 'utf-16-le', errors='ignore') as f:
    log_content = f.read()

print(f"📊 Tamanho do log: {len(log_content) / 1024 / 1024:.2f} MB")
print()

# Extrair aberturas
print("🔍 Extraindo aberturas de ordens...")
buy_opens = []
sell_opens = []

# Pattern para abertura
open_pattern = re.compile(
    r'(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2})\s+🔵 ABERTURA DE COMPRA \(BUY\)|'
    r'(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2})\s+🔴 ABERTURA DE VENDA \(SELL\)',
    re.MULTILINE
)

for match in open_pattern.finditer(log_content):
    if match.group(1):  # BUY
        buy_opens.append(match.group(1))
    elif match.group(2):  # SELL
        sell_opens.append(match.group(2))

print(f"✅ Aberturas BUY encontradas: {len(buy_opens)}")
print(f"✅ Aberturas SELL encontradas: {len(sell_opens)}")
print()

# Extrair fechamentos
print("🔍 Extraindo fechamentos de ordens...")

# Pattern para fechamento
close_pattern = re.compile(
    r'(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2})\s+(💚|❌) FECHAMENTO DE (BUY|SELL).*?'
    r'🎫 Ticket: (\d+).*?'
    r'📈 Preço Abertura: ([\d.]+).*?'
    r'📉 Preço Fechamento: ([\d.]+).*?'
    r'📏 Diferença: ([\d.]+) pips \(([+-][\d.]+)\).*?'
    r'💵 Resultado: ([+-][\d.]+) USD.*?'
    r'🏁 Motivo: (Take Profit|Stop Loss)',
    re.DOTALL
)

trades = []
for match in close_pattern.finditer(log_content):
    close_time = match.group(1)
    emoji = match.group(2)
    direction = match.group(3)
    ticket = int(match.group(4))
    open_price = float(match.group(5))
    close_price = float(match.group(6))
    pips = float(match.group(7))
    price_diff = float(match.group(8))
    profit_usd = float(match.group(9))
    close_reason = match.group(10)
    
    is_winner = profit_usd > 0
    
    trades.append({
        'ticket': ticket,
        'direction': direction,
        'close_time': close_time,
        'open_price': open_price,
        'close_price': close_price,
        'pips': pips if is_winner else -pips,
        'profit_usd': profit_usd,
        'close_reason': close_reason,
        'is_winner': is_winner
    })

print(f"✅ Trades fechados extraídos: {len(trades)}")
print()

# Separar por direção
buy_trades = [t for t in trades if t['direction'] == 'BUY']
sell_trades = [t for t in trades if t['direction'] == 'SELL']

print(f"📈 Trades BUY: {len(buy_trades)}")
print(f"📉 Trades SELL: {len(sell_trades)}")
print()

# =============================
# ANÁLISE BUY
# =============================
if buy_trades:
    buy_winners = [t for t in buy_trades if t['is_winner']]
    buy_losers = [t for t in buy_trades if not t['is_winner']]
    buy_tp = [t for t in buy_trades if t['close_reason'] == 'Take Profit']
    buy_sl = [t for t in buy_trades if t['close_reason'] == 'Stop Loss']
    
    buy_total_pips = sum(t['pips'] for t in buy_trades)
    buy_total_usd = sum(t['profit_usd'] for t in buy_trades)
    buy_avg_winner_pips = statistics.mean([t['pips'] for t in buy_winners]) if buy_winners else 0
    buy_avg_loser_pips = statistics.mean([t['pips'] for t in buy_losers]) if buy_losers else 0
    buy_avg_winner_usd = statistics.mean([t['profit_usd'] for t in buy_winners]) if buy_winners else 0
    buy_avg_loser_usd = statistics.mean([t['profit_usd'] for t in buy_losers]) if buy_losers else 0
    
    buy_gross_profit = sum(t['profit_usd'] for t in buy_winners)
    buy_gross_loss = abs(sum(t['profit_usd'] for t in buy_losers))
    buy_pf = buy_gross_profit / buy_gross_loss if buy_gross_loss > 0 else 0
    
    print("=" * 80)
    print("📈 ANÁLISE DETALHADA: COMPRAS (BUY)")
    print("=" * 80)
    print()
    print(f"Total de trades: {len(buy_trades)}")
    print(f"Vencedores: {len(buy_winners)} ({len(buy_winners)/len(buy_trades)*100:.1f}%)")
    print(f"Perdedores: {len(buy_losers)} ({len(buy_losers)/len(buy_trades)*100:.1f}%)")
    print()
    print(f"Fechamentos em TP: {len(buy_tp)} ({len(buy_tp)/len(buy_trades)*100:.1f}%)")
    print(f"Fechamentos em SL: {len(buy_sl)} ({len(buy_sl)/len(buy_trades)*100:.1f}%)")
    print()
    print(f"📏 Ganho médio: {buy_avg_winner_pips:.1f} pips (${buy_avg_winner_usd:.2f})")
    print(f"📏 Perda média: {buy_avg_loser_pips:.1f} pips (${buy_avg_loser_usd:.2f})")
    print(f"💰 Profit Factor: {buy_pf:.2f}")
    print(f"📊 Total: {buy_total_pips:.0f} pips (${buy_total_usd:.2f})")
    print()
    
    # Winners que não chegaram no TP
    buy_winners_no_tp = [t for t in buy_winners if t['close_reason'] != 'Take Profit']
    print(f"🔍 Vencedores que NÃO chegaram no TP: {len(buy_winners_no_tp)} ({len(buy_winners_no_tp)/len(buy_winners)*100 if buy_winners else 0:.1f}% dos ganhos)")
    print()

# =============================
# ANÁLISE SELL
# =============================
if sell_trades:
    sell_winners = [t for t in sell_trades if t['is_winner']]
    sell_losers = [t for t in sell_trades if not t['is_winner']]
    sell_tp = [t for t in sell_trades if t['close_reason'] == 'Take Profit']
    sell_sl = [t for t in sell_trades if t['close_reason'] == 'Stop Loss']
    
    sell_total_pips = sum(t['pips'] for t in sell_trades)
    sell_total_usd = sum(t['profit_usd'] for t in sell_trades)
    sell_avg_winner_pips = statistics.mean([t['pips'] for t in sell_winners]) if sell_winners else 0
    sell_avg_loser_pips = statistics.mean([t['pips'] for t in sell_losers]) if sell_losers else 0
    sell_avg_winner_usd = statistics.mean([t['profit_usd'] for t in sell_winners]) if sell_winners else 0
    sell_avg_loser_usd = statistics.mean([t['profit_usd'] for t in sell_losers]) if sell_losers else 0
    
    sell_gross_profit = sum(t['profit_usd'] for t in sell_winners)
    sell_gross_loss = abs(sum(t['profit_usd'] for t in sell_losers))
    sell_pf = sell_gross_profit / sell_gross_loss if sell_gross_loss > 0 else 0
    
    print("=" * 80)
    print("📉 ANÁLISE DETALHADA: VENDAS (SELL)")
    print("=" * 80)
    print()
    print(f"Total de trades: {len(sell_trades)}")
    print(f"Vencedores: {len(sell_winners)} ({len(sell_winners)/len(sell_trades)*100:.1f}%)")
    print(f"Perdedores: {len(sell_losers)} ({len(sell_losers)/len(sell_trades)*100:.1f}%)")
    print()
    print(f"Fechamentos em TP: {len(sell_tp)} ({len(sell_tp)/len(sell_trades)*100:.1f}%)")
    print(f"Fechamentos em SL: {len(sell_sl)} ({len(sell_sl)/len(sell_trades)*100:.1f}%)")
    print()
    print(f"📏 Ganho médio: {sell_avg_winner_pips:.1f} pips (${sell_avg_winner_usd:.2f})")
    print(f"📏 Perda média: {sell_avg_loser_pips:.1f} pips (${sell_avg_loser_usd:.2f})")
    print(f"💰 Profit Factor: {sell_pf:.2f}")
    print(f"📊 Total: {sell_total_pips:.0f} pips (${sell_total_usd:.2f})")
    print()
    
    # Winners que não chegaram no TP
    sell_winners_no_tp = [t for t in sell_winners if t['close_reason'] != 'Take Profit']
    print(f"🔍 Vencedores que NÃO chegaram no TP: {len(sell_winners_no_tp)} ({len(sell_winners_no_tp)/len(sell_winners)*100 if sell_winners else 0:.1f}% dos ganhos)")
    print()

# =============================
# COMPARAÇÃO
# =============================
if buy_trades and sell_trades:
    print("=" * 80)
    print("🎯 COMPARAÇÃO BUY vs SELL")
    print("=" * 80)
    print()
    
    print("| Métrica              | BUY           | SELL          | Diferença     |")
    print("|----------------------|---------------|---------------|---------------|")
    print(f"| Trades               | {len(buy_trades):3d}           | {len(sell_trades):3d}           | {len(buy_trades) - len(sell_trades):+4d}          |")
    print(f"| Win Rate             | {len(buy_winners)/len(buy_trades)*100:5.1f}%        | {len(sell_winners)/len(sell_trades)*100:5.1f}%        | {(len(buy_winners)/len(buy_trades) - len(sell_winners)/len(sell_trades))*100:+5.1f}%       |")
    print(f"| Taxa TP              | {len(buy_tp)/len(buy_trades)*100:5.1f}%        | {len(sell_tp)/len(sell_trades)*100:5.1f}%        | {(len(buy_tp)/len(buy_trades) - len(sell_tp)/len(sell_trades))*100:+5.1f}%       |")
    print(f"| Profit Factor        | {buy_pf:6.2f}        | {sell_pf:6.2f}        | {buy_pf - sell_pf:+6.2f}      |")
    print(f"| Total pips           | {buy_total_pips:7.0f}       | {sell_total_pips:7.0f}       | {buy_total_pips - sell_total_pips:+8.0f}    |")
    print(f"| Total USD            | ${buy_total_usd:7.2f}     | ${sell_total_usd:7.2f}     | ${buy_total_usd - sell_total_usd:+8.2f}   |")
    print()
    
    # DIAGNÓSTICO
    print("=" * 80)
    print("🔍 DIAGNÓSTICO")
    print("=" * 80)
    print()
    
    pf_diff = abs(buy_pf - sell_pf)
    
    if pf_diff > 0.15:
        if buy_pf < sell_pf:
            print(f"🚨 COMPRAS (BUY) são PIORES que vendas")
            print(f"   PF: {buy_pf:.2f} vs {sell_pf:.2f} (diferença: {sell_pf - buy_pf:.2f})")
            print()
            print("💡 RECOMENDAÇÕES:")
            print("   - Considerar TP_BUY menor que TP_SELL")
            print("   - Avaliar SL_BUY maior que SL_SELL")
            print("   - Implementar Breakeven + Trailing prioritariamente em BUY")
        else:
            print(f"🚨 VENDAS (SELL) são PIORES que compras")
            print(f"   PF: {sell_pf:.2f} vs {buy_pf:.2f} (diferença: {buy_pf - sell_pf:.2f})")
            print()
            print("💡 RECOMENDAÇÕES:")
            print("   - Considerar TP_SELL menor que TP_BUY")
            print("   - Avaliar SL_SELL maior que SL_BUY")
            print("   - Implementar Breakeven + Trailing prioritariamente em SELL")
    else:
        print("✅ BUY e SELL têm performance SIMILAR")
        print(f"   Diferença PF: {pf_diff:.2f} (insignificante)")
        print()
        print("💡 RECOMENDAÇÕES:")
        print("   - Manter TP/SL simétricos")
        print("   - Implementar Breakeven + Trailing igualmente para ambos")
        print("   - Problema é SISTÊMICO, não específico de direção")

elif buy_trades and not sell_trades:
    print("=" * 80)
    print("⚠️  AVISO: APENAS TRADES BUY ENCONTRADOS")
    print("=" * 80)
    print()
    print("O backtest contém APENAS compras (BUY), nenhuma venda (SELL).")
    print("Impossível comparar performance direcional.")
    
elif sell_trades and not buy_trades:
    print("=" * 80)
    print("⚠️  AVISO: APENAS TRADES SELL ENCONTRADOS")
    print("=" * 80)
    print()
    print("O backtest contém APENAS vendas (SELL), nenhuma compra (BUY).")
    print("Impossível comparar performance direcional.")

print()
print("=" * 80)
print("✅ ANÁLISE CONCLUÍDA")
print("=" * 80)
