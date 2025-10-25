#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Análise BUY vs SELL usando dados já extraídos
Reaproveita html_report_analyzer.py que já funciona
"""

import codecs
import re

print("=" * 80)
print("ANÁLISE BUY vs SELL - Usando extração validada")
print("=" * 80)
print()

# Ler HTML
with codecs.open('log/ReportTester-7635384.html', 'r', 'utf-16-le') as f:
    html = f.read()

# EXTRAIR DADOS (mesmo código do html_report_analyzer.py validado)
lines = html.split('<tr')
trades = []

for line in lines:
    if '>buy<' in line or '>sell<' in line:
        cells = re.findall(r'<td[^>]*>(.*?)</td>', line, re.DOTALL | re.IGNORECASE)
        
        if len(cells) >= 11:
            try:
                ticket = cells[0].strip()
                open_time = cells[1].strip()
                symbol = cells[2].strip()
                
                # Determinar tipo de ordem
                order_type_match = re.search(r'>(buy|sell)<', line, re.IGNORECASE)
                if not order_type_match:
                    continue
                    
                order_type = order_type_match.group(1).lower()
                
                volume = float(cells[4].strip()) if cells[4].strip() else 0
                entry_price = float(cells[5].strip())
                
                sl_text = cells[6].strip()
                tp_text = cells[7].strip()
                
                close_time = cells[8].strip()
                close_price = float(cells[9].strip())
                commission = float(cells[10].strip()) if cells[10].strip() else 0
                profit_pips = float(cells[11].strip())
                
                # Skip linhas de fechamento (sem SL/TP)
                if not sl_text or not tp_text or sl_text == '' or tp_text == '':
                    continue
                
                sl_price = float(sl_text)
                tp_price = float(tp_text)
                
                # Determinar direção do trade (BUY ou SELL) pelo tipo de ordem de abertura
                # Se ordem é "buy" = trade de COMPRA
                # Se ordem é "sell" = trade de VENDA
                trade_direction = 'BUY' if order_type == 'buy' else 'SELL'
                
                # Determinar se fechou em TP ou SL
                dist_to_tp = abs(close_price - tp_price)
                dist_to_sl = abs(close_price - sl_price)
                closed_at = 'TP' if dist_to_tp < dist_to_sl else 'SL'
                
                is_winner = profit_pips > 0
                
                trades.append({
                    'ticket': ticket,
                    'direction': trade_direction,
                    'entry': entry_price,
                    'sl': sl_price,
                    'tp': tp_price,
                    'close': close_price,
                    'profit_pips': profit_pips,
                    'closed_at': closed_at,
                    'is_winner': is_winner,
                    'open_time': open_time,
                    'close_time': close_time
                })
                
            except (ValueError, IndexError) as e:
                continue

print(f"✅ Total de trades extraídos: {len(trades)}")
print()

# Separar por direção
buy_trades = [t for t in trades if t['direction'] == 'BUY']
sell_trades = [t for t in trades if t['direction'] == 'SELL']

print(f"📈 Trades BUY: {len(buy_trades)}")
print(f"📉 Trades SELL: {len(sell_trades)}")
print()

if len(buy_trades) + len(sell_trades) != len(trades):
    print("⚠️  ERRO: Soma BUY + SELL diferente do total!")
    print()

# =============================
# ANÁLISE BUY
# =============================
if buy_trades:
    buy_winners = [t for t in buy_trades if t['is_winner']]
    buy_losers = [t for t in buy_trades if not t['is_winner']]
    buy_tp_closes = [t for t in buy_trades if t['closed_at'] == 'TP']
    buy_sl_closes = [t for t in buy_trades if t['closed_at'] == 'SL']
    
    buy_total_pips = sum(t['profit_pips'] for t in buy_trades)
    buy_avg_winner = sum(t['profit_pips'] for t in buy_winners) / len(buy_winners) if buy_winners else 0
    buy_avg_loser = sum(t['profit_pips'] for t in buy_losers) / len(buy_losers) if buy_losers else 0
    
    buy_gross_profit = sum(t['profit_pips'] for t in buy_winners)
    buy_gross_loss = abs(sum(t['profit_pips'] for t in buy_losers))
    buy_pf = buy_gross_profit / buy_gross_loss if buy_gross_loss > 0 else 0
    
    print("=" * 80)
    print("📈 ANÁLISE DETALHADA: COMPRAS (BUY)")
    print("=" * 80)
    print()
    print(f"Total de trades BUY: {len(buy_trades)}")
    print(f"Vencedores: {len(buy_winners)} ({len(buy_winners)/len(buy_trades)*100:.1f}%)")
    print(f"Perdedores: {len(buy_losers)} ({len(buy_losers)/len(buy_trades)*100:.1f}%)")
    print()
    print(f"Fechamentos em TP: {len(buy_tp_closes)} ({len(buy_tp_closes)/len(buy_trades)*100:.1f}%)")
    print(f"Fechamentos em SL: {len(buy_sl_closes)} ({len(buy_sl_closes)/len(buy_trades)*100:.1f}%)")
    print()
    print(f"Ganho médio: {buy_avg_winner:.2f} pips")
    print(f"Perda média: {buy_avg_loser:.2f} pips")
    print(f"Profit Factor: {buy_pf:.2f}")
    print(f"Total de pips: {buy_total_pips:.0f}")
    print()
    
    # Insight crítico
    buy_winners_not_tp = [t for t in buy_winners if t['closed_at'] == 'SL']
    print(f"🔍 INSIGHT CRÍTICO BUY:")
    print(f"   Vencedores que NÃO chegaram no TP: {len(buy_winners_not_tp)} ({len(buy_winners_not_tp)/len(buy_winners)*100 if buy_winners else 0:.1f}% dos vencedores)")
    print()

# =============================
# ANÁLISE SELL
# =============================
if sell_trades:
    sell_winners = [t for t in sell_trades if t['is_winner']]
    sell_losers = [t for t in sell_trades if not t['is_winner']]
    sell_tp_closes = [t for t in sell_trades if t['closed_at'] == 'TP']
    sell_sl_closes = [t for t in sell_trades if t['closed_at'] == 'SL']
    
    sell_total_pips = sum(t['profit_pips'] for t in sell_trades)
    sell_avg_winner = sum(t['profit_pips'] for t in sell_winners) / len(sell_winners) if sell_winners else 0
    sell_avg_loser = sum(t['profit_pips'] for t in sell_losers) / len(sell_losers) if sell_losers else 0
    
    sell_gross_profit = sum(t['profit_pips'] for t in sell_winners)
    sell_gross_loss = abs(sum(t['profit_pips'] for t in sell_losers))
    sell_pf = sell_gross_profit / sell_gross_loss if sell_gross_loss > 0 else 0
    
    print("=" * 80)
    print("📉 ANÁLISE DETALHADA: VENDAS (SELL)")
    print("=" * 80)
    print()
    print(f"Total de trades SELL: {len(sell_trades)}")
    print(f"Vencedores: {len(sell_winners)} ({len(sell_winners)/len(sell_trades)*100:.1f}%)")
    print(f"Perdedores: {len(sell_losers)} ({len(sell_losers)/len(sell_trades)*100:.1f}%)")
    print()
    print(f"Fechamentos em TP: {len(sell_tp_closes)} ({len(sell_tp_closes)/len(sell_trades)*100:.1f}%)")
    print(f"Fechamentos em SL: {len(sell_sl_closes)} ({len(sell_sl_closes)/len(sell_trades)*100:.1f}%)")
    print()
    print(f"Ganho médio: {sell_avg_winner:.2f} pips")
    print(f"Perda média: {sell_avg_loser:.2f} pips")
    print(f"Profit Factor: {sell_pf:.2f}")
    print(f"Total de pips: {sell_total_pips:.0f}")
    print()
    
    # Insight crítico
    sell_winners_not_tp = [t for t in sell_winners if t['closed_at'] == 'SL']
    print(f"🔍 INSIGHT CRÍTICO SELL:")
    print(f"   Vencedores que NÃO chegaram no TP: {len(sell_winners_not_tp)} ({len(sell_winners_not_tp)/len(sell_winners)*100 if sell_winners else 0:.1f}% dos vencedores)")
    print()

# =============================
# COMPARAÇÃO
# =============================
if buy_trades and sell_trades:
    print("=" * 80)
    print("🎯 COMPARAÇÃO BUY vs SELL")
    print("=" * 80)
    print()
    
    print("| Métrica | BUY | SELL | Diferença |")
    print("|---------|-----|------|-----------|")
    print(f"| Trades | {len(buy_trades)} | {len(sell_trades)} | {len(buy_trades) - len(sell_trades)} |")
    print(f"| Win Rate | {len(buy_winners)/len(buy_trades)*100:.1f}% | {len(sell_winners)/len(sell_trades)*100:.1f}% | {(len(buy_winners)/len(buy_trades) - len(sell_winners)/len(sell_trades))*100:.1f}% |")
    print(f"| Taxa TP | {len(buy_tp_closes)/len(buy_trades)*100:.1f}% | {len(sell_tp_closes)/len(sell_trades)*100:.1f}% | {(len(buy_tp_closes)/len(buy_trades) - len(sell_tp_closes)/len(sell_trades))*100:.1f}% |")
    print(f"| Taxa SL | {len(buy_sl_closes)/len(buy_trades)*100:.1f}% | {len(sell_sl_closes)/len(sell_trades)*100:.1f}% | {(len(buy_sl_closes)/len(buy_trades) - len(sell_sl_closes)/len(sell_trades))*100:.1f}% |")
    print(f"| Ganho médio | {buy_avg_winner:.1f} pips | {sell_avg_winner:.1f} pips | {buy_avg_winner - sell_avg_winner:.1f} pips |")
    print(f"| Perda média | {buy_avg_loser:.1f} pips | {sell_avg_loser:.1f} pips | {buy_avg_loser - sell_avg_loser:.1f} pips |")
    print(f"| Profit Factor | {buy_pf:.2f} | {sell_pf:.2f} | {buy_pf - sell_pf:.2f} |")
    print(f"| Total pips | {buy_total_pips:.0f} | {sell_total_pips:.0f} | {buy_total_pips - sell_total_pips:.0f} |")
    print()
    
    # =============================
    # DIAGNÓSTICO FINAL
    # =============================
    print("=" * 80)
    print("🔍 DIAGNÓSTICO: ONDE ESTÁ O GARGALO?")
    print("=" * 80)
    print()
    
    # Determinar qual direção é pior
    pf_diff = abs(buy_pf - sell_pf)
    
    if pf_diff > 0.15:  # Diferença significativa
        if buy_pf < sell_pf:
            diff = sell_pf - buy_pf
            print(f"🚨 COMPRAS (BUY) são PIORES que vendas!")
            print(f"   → PF BUY ({buy_pf:.2f}) é {diff:.2f} menor que SELL ({sell_pf:.2f})")
            print(f"   → Problema prioritário: Melhorar trades de COMPRA")
            print()
            
            if len(buy_tp_closes)/len(buy_trades) < len(sell_tp_closes)/len(sell_trades):
                print(f"   📊 Taxa de TP em COMPRAS ({len(buy_tp_closes)/len(buy_trades)*100:.1f}%) < VENDAS ({len(sell_tp_closes)/len(sell_trades)*100:.1f}%)")
                print(f"   → TP de 150 pips pode estar MUITO LONGE para COMPRAS")
                print(f"   💡 SUGESTÃO: Considerar TP_BUY < TP_SELL (ex: TP_BUY=120 pips)")
                print()
            
            if abs(buy_avg_loser) > abs(sell_avg_loser):
                print(f"   📊 Perda média em COMPRAS ({buy_avg_loser:.1f}) > VENDAS ({sell_avg_loser:.1f})")
                print(f"   → SL de 40 pips pode estar APERTADO para COMPRAS")
                print(f"   💡 SUGESTÃO: Considerar SL_BUY > SL_SELL (ex: SL_BUY=50 pips)")
                print()
                
        else:
            diff = buy_pf - sell_pf
            print(f"🚨 VENDAS (SELL) são PIORES que compras!")
            print(f"   → PF SELL ({sell_pf:.2f}) é {diff:.2f} menor que BUY ({buy_pf:.2f})")
            print(f"   → Problema prioritário: Melhorar trades de VENDA")
            print()
            
            if len(sell_tp_closes)/len(sell_trades) < len(buy_tp_closes)/len(buy_trades):
                print(f"   📊 Taxa de TP em VENDAS ({len(sell_tp_closes)/len(sell_trades)*100:.1f}%) < COMPRAS ({len(buy_tp_closes)/len(buy_trades)*100:.1f}%)")
                print(f"   → TP de 150 pips pode estar MUITO LONGE para VENDAS")
                print(f"   💡 SUGESTÃO: Considerar TP_SELL < TP_BUY (ex: TP_SELL=120 pips)")
                print()
            
            if abs(sell_avg_loser) > abs(buy_avg_loser):
                print(f"   📊 Perda média em VENDAS ({sell_avg_loser:.1f}) > COMPRAS ({buy_avg_loser:.1f})")
                print(f"   → SL de 40 pips pode estar APERTADO para VENDAS")
                print(f"   💡 SUGESTÃO: Considerar SL_SELL > SL_BUY (ex: SL_SELL=50 pips)")
                print()
    else:
        print("✅ BUY e SELL têm performance SIMILAR (diferença < 0.15 no PF)")
        print("   → Problema é GERAL, não específico de direção")
        print("   → Soluções aplicam-se igualmente para ambos")
        print()
    
    # RECOMENDAÇÕES FINAIS
    print("=" * 80)
    print("💡 RECOMENDAÇÕES FINAIS")
    print("=" * 80)
    print()
    print("1. BREAKEVEN: Implementar após 60 pips (1.5:1 RR)")
    print("2. TRAILING STOP: Ativar após 100 pips (2.5:1 RR)")
    
    if pf_diff > 0.15:
        print("3. TP/SL ASSIMÉTRICO: ✅ RECOMENDADO (diferença significativa)")
        if buy_pf < sell_pf:
            print("   → Considerar TP_BUY < TP_SELL e/ou SL_BUY > SL_SELL")
        else:
            print("   → Considerar TP_SELL < TP_BUY e/ou SL_SELL > SL_BUY")
    else:
        print("3. TP/SL SIMÉTRICO: ✅ MANTER (problema não é assimétrico)")
        print("   → SL=40 pips, TP=150 pips para ambas direções")
    print()

print("=" * 80)
