#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Análise BUY vs SELL usando regex validado do html_report_analyzer.py
"""

import re
import codecs
from datetime import datetime
import statistics

print("=" * 80)
print("ANÁLISE BUY vs SELL - VERSÃO VALIDADA")
print("=" * 80)
print()

# Ler HTML (UTF-16 LE)
with codecs.open('log/ReportTester-7635384.html', 'r', 'utf-16-le', errors='ignore') as f:
    html = f.read()

print(f"📊 HTML: {len(html) / 1024:.2f} KB")

# REGEX VALIDADO (do html_report_analyzer.py)
entry_pattern = re.compile(
    r'<td>([\d.]+\s+[\d:]+)</td><td>(\d+)</td><td>USDJPY</td><td>(buy|sell)</td>'
    r'.*?<td>([\d.]+)</td><td>([\d.]+)</td><td>([\d.]+)</td>.*?<td>(Nexus_[A-Z]+_(GOOD|PREMIUM))</td>',
    re.DOTALL | re.IGNORECASE
)

exit_pattern = re.compile(
    r'<td>([\d.]+\s+[\d:]+)</td><td>(\d+)</td><td>USDJPY</td><td>(buy|sell)</td>'
    r'.*?<td></td><td></td>.*?<td>(tp|sl|be)\s+([\d.]+)</td>',
    re.DOTALL | re.IGNORECASE
)

# Extrair entradas
entries = {}
for match in entry_pattern.finditer(html):
    time_str = match.group(1)
    ticket = int(match.group(2))
    direction = match.group(3).lower()
    entry_price = float(match.group(5))
    tp_price = float(match.group(6))
    setup_type = match.group(8)
    
    open_time = datetime.strptime(time_str, '%Y.%m.%d %H:%M:%S')
    
    entries[ticket] = {
        'open_time': open_time,
        'direction': direction,
        'entry_price': entry_price,
        'tp_price': tp_price,
        'setup_type': setup_type
    }

print(f"✅ Entradas encontradas: {len(entries)}")

# Extrair saídas e montar trades completos
trades = []
for match in exit_pattern.finditer(html):
    time_str = match.group(1)
    ticket = int(match.group(2))
    close_reason = match.group(4).lower()
    close_price = float(match.group(5))
    
    close_time = datetime.strptime(time_str, '%Y.%m.%d %H:%M:%S')
    
    # Entrada correspondente (ticket - 1)
    entry_ticket = ticket - 1
    
    if entry_ticket in entries:
        entry = entries[entry_ticket]
        
        # Calcular profit em pips
        if entry['direction'] == 'buy':
            profit_pips = (close_price - entry['entry_price']) * 1000
        else:
            profit_pips = (entry['entry_price'] - close_price) * 1000
        
        trades.append({
            'ticket': entry_ticket,
            'direction': entry['direction'],
            'entry': entry['entry_price'],
            'tp': entry['tp_price'],
            'close': close_price,
            'close_reason': close_reason,
            'profit': profit_pips,
            'is_winner': profit_pips > 0,
            'setup': entry['setup_type']
        })

print(f"✅ Trades completos: {len(trades)}")
print()

# Separar por direção
buy_trades = [t for t in trades if t['direction'] == 'buy']
sell_trades = [t for t in trades if t['direction'] == 'sell']

print(f"📈 Trades BUY: {len(buy_trades)}")
print(f"📉 Trades SELL: {len(sell_trades)}")
print()

# ANÁLISE BUY
if buy_trades:
    buy_winners = [t for t in buy_trades if t['is_winner']]
    buy_losers = [t for t in buy_trades if not t['is_winner']]
    buy_tp = [t for t in buy_trades if t['close_reason'] == 'tp']
    buy_sl = [t for t in buy_trades if t['close_reason'] == 'sl']
    
    buy_gross_profit = sum(t['profit'] for t in buy_winners)
    buy_gross_loss = abs(sum(t['profit'] for t in buy_losers))
    buy_pf = buy_gross_profit / buy_gross_loss if buy_gross_loss > 0 else 0
    buy_total = sum(t['profit'] for t in buy_trades)
    
    print("=" * 80)
    print("📈 COMPRAS (BUY)")
    print("=" * 80)
    print()
    print(f"Total: {len(buy_trades)} trades")
    print(f"Vencedores: {len(buy_winners)} ({len(buy_winners)/len(buy_trades)*100:.1f}%)")
    print(f"Perdedores: {len(buy_losers)} ({len(buy_losers)/len(buy_trades)*100:.1f}%)")
    print()
    print(f"Fecham TP: {len(buy_tp)} ({len(buy_tp)/len(buy_trades)*100:.1f}%)")
    print(f"Fecham SL: {len(buy_sl)} ({len(buy_sl)/len(buy_trades)*100:.1f}%)")
    print()
    print(f"Ganho médio: {statistics.mean([t['profit'] for t in buy_winners]) if buy_winners else 0:.1f} pips")
    print(f"Perda média: {statistics.mean([t['profit'] for t in buy_losers]) if buy_losers else 0:.1f} pips")
    print(f"Profit Factor: {buy_pf:.2f}")
    print(f"Total pips: {buy_total:.0f}")
    print()
    
    # Winners que não chegaram no TP
    buy_winners_no_tp = [t for t in buy_winners if t['close_reason'] != 'tp']
    print(f"🔍 Vencedores que NÃO chegaram no TP: {len(buy_winners_no_tp)} ({len(buy_winners_no_tp)/len(buy_winners)*100 if buy_winners else 0:.1f}% dos ganhos)")
    print()

# ANÁLISE SELL
if sell_trades:
    sell_winners = [t for t in sell_trades if t['is_winner']]
    sell_losers = [t for t in sell_trades if not t['is_winner']]
    sell_tp = [t for t in sell_trades if t['close_reason'] == 'tp']
    sell_sl = [t for t in sell_trades if t['close_reason'] == 'sl']
    
    sell_gross_profit = sum(t['profit'] for t in sell_winners)
    sell_gross_loss = abs(sum(t['profit'] for t in sell_losers))
    sell_pf = sell_gross_profit / sell_gross_loss if sell_gross_loss > 0 else 0
    sell_total = sum(t['profit'] for t in sell_trades)
    
    print("=" * 80)
    print("📉 VENDAS (SELL)")
    print("=" * 80)
    print()
    print(f"Total: {len(sell_trades)} trades")
    print(f"Vencedores: {len(sell_winners)} ({len(sell_winners)/len(sell_trades)*100:.1f}%)")
    print(f"Perdedores: {len(sell_losers)} ({len(sell_losers)/len(sell_trades)*100:.1f}%)")
    print()
    print(f"Fecham TP: {len(sell_tp)} ({len(sell_tp)/len(sell_trades)*100:.1f}%)")
    print(f"Fecham SL: {len(sell_sl)} ({len(sell_sl)/len(sell_trades)*100:.1f}%)")
    print()
    print(f"Ganho médio: {statistics.mean([t['profit'] for t in sell_winners]) if sell_winners else 0:.1f} pips")
    print(f"Perda média: {statistics.mean([t['profit'] for t in sell_losers]) if sell_losers else 0:.1f} pips")
    print(f"Profit Factor: {sell_pf:.2f}")
    print(f"Total pips: {sell_total:.0f}")
    print()
    
    # Winners que não chegaram no TP
    sell_winners_no_tp = [t for t in sell_winners if t['close_reason'] != 'tp']
    print(f"🔍 Vencedores que NÃO chegaram no TP: {len(sell_winners_no_tp)} ({len(sell_winners_no_tp)/len(sell_winners)*100 if sell_winners else 0:.1f}% dos ganhos)")
    print()

# COMPARAÇÃO
if buy_trades and sell_trades:
    print("=" * 80)
    print("🎯 COMPARAÇÃO BUY vs SELL")
    print("=" * 80)
    print()
    
    print("| Métrica              | BUY       | SELL      | Diferença   |")
    print("|----------------------|-----------|-----------|-------------|")
    print(f"| Trades               | {len(buy_trades):3d}       | {len(sell_trades):3d}       | {len(buy_trades) - len(sell_trades):+4d}        |")
    print(f"| Win Rate             | {len(buy_winners)/len(buy_trades)*100:5.1f}%    | {len(sell_winners)/len(sell_trades)*100:5.1f}%    | {(len(buy_winners)/len(buy_trades) - len(sell_winners)/len(sell_trades))*100:+5.1f}%     |")
    print(f"| Taxa TP              | {len(buy_tp)/len(buy_trades)*100:5.1f}%    | {len(sell_tp)/len(sell_trades)*100:5.1f}%    | {(len(buy_tp)/len(buy_trades) - len(sell_tp)/len(sell_trades))*100:+5.1f}%     |")
    print(f"| Profit Factor        | {buy_pf:6.2f}    | {sell_pf:6.2f}    | {buy_pf - sell_pf:+6.2f}    |")
    print(f"| Total pips           | {buy_total:6.0f}    | {sell_total:6.0f}    | {buy_total - sell_total:+7.0f}   |")
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
    
    print()
    print("=" * 80)
