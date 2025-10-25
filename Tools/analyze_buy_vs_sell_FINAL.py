#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Análise BUY vs SELL - CORREÇÃO DEFINITIVA
HTML MT5 estrutura: 
- Linha abertura: contém SL, TP, comentário "Nexus_BUY_GOOD" ou "Nexus_SELL_PREMIUM"
- Linha fechamento: contém "tp X.XXX" ou "sl X.XXX"
"""

import codecs
import re

print("=" * 80)
print("ANÁLISE PROFUNDA: BUY vs SELL - VERSÃO CORRIGIDA")
print("=" * 80)
print()

# Ler HTML
with codecs.open('log/ReportTester-7635384.html', 'r', 'utf-16-le') as f:
    html = f.read()

# Extrair linhas
lines = html.split('<tr')

buy_trades = []
sell_trades = []

for i in range(len(lines) - 1):
    line = lines[i]
    
    # Procurar linha com "Nexus_BUY" ou "Nexus_SELL" (abertura)
    if 'Nexus_BUY' in line or 'Nexus_SELL' in line:
        cells = re.findall(r'<td[^>]*>(.*?)</td>', line, re.DOTALL | re.IGNORECASE)
        
        if len(cells) >= 8:
            try:
                open_time = cells[0].strip()
                ticket = cells[1].strip()
                symbol = cells[2].strip()
                order_type = cells[3].strip().lower()  # buy ou sell (direção da ordem)
                
                # Extrair SL e TP
                sl_text = cells[6].strip()
                tp_text = cells[7].strip()
                
                if sl_text and tp_text:
                    sl_price = float(sl_text)
                    tp_price = float(tp_text)
                    comment = cells[10].strip() if len(cells) > 10 else ''
                    
                    # Determinar direção REAL do trade pelo comentário
                    is_buy_trade = 'Nexus_BUY' in comment
                    is_sell_trade = 'Nexus_SELL' in comment
                    
                    # Próxima linha = fechamento
                    next_line = lines[i + 1]
                    next_cells = re.findall(r'<td[^>]*>(.*?)</td>', next_line, re.DOTALL | re.IGNORECASE)
                    
                    if len(next_cells) >= 10:
                        close_time = next_cells[0].strip()
                        close_comment = next_cells[10].strip() if len(next_cells) > 10 else ''
                        
                        # Extrair preço de fechamento
                        close_match = re.search(r'(tp|sl)\s+([\d\.]+)', close_comment, re.IGNORECASE)
                        
                        if close_match:
                            closed_at_type = close_match.group(1).upper()
                            close_price = float(close_match.group(2))
                            
                            # Calcular profit (em pips para USDJPY)
                            if is_buy_trade:
                                # Compra: lucro quando preço sobe
                                profit_pips = (close_price - sl_price) * 100
                                entry_price = sl_price
                            else:
                                # Venda: lucro quando preço desce
                                profit_pips = (sl_price - close_price) * 100
                                entry_price = sl_price
                            
                            is_winner = profit_pips > 0
                            
                            trade_data = {
                                'ticket': ticket,
                                'type': 'BUY' if is_buy_trade else 'SELL',
                                'entry': entry_price,
                                'sl': sl_price,
                                'tp': tp_price,
                                'close': close_price,
                                'profit_pips': profit_pips,
                                'open_time': open_time,
                                'close_time': close_time,
                                'closed_at': closed_at_type,
                                'is_winner': is_winner,
                                'comment': comment
                            }
                            
                            if is_buy_trade:
                                buy_trades.append(trade_data)
                            elif is_sell_trade:
                                sell_trades.append(trade_data)
                                
            except (ValueError, IndexError) as e:
                pass

print(f"✅ Trades BUY extraídos: {len(buy_trades)}")
print(f"✅ Trades SELL extraídos: {len(sell_trades)}")
print(f"✅ Total: {len(buy_trades) + len(sell_trades)}")
print()

# Validar consistência
expected_total = 430
actual_total = len(buy_trades) + len(sell_trades)
if actual_total != expected_total:
    print(f"⚠️  AVISO: Esperado {expected_total} trades, encontrado {actual_total}")
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
        
        if abs(buy_avg_loser) > abs(sell_avg_loser):
            print(f"   📊 Perda média em COMPRAS ({buy_avg_loser:.1f}) > VENDAS ({sell_avg_loser:.1f})")
            print(f"   → SL de 40 pips pode estar APERTADO para COMPRAS")
            print(f"   💡 SUGESTÃO: Considerar SL_BUY > SL_SELL (ex: SL_BUY=50 pips)")
        print()
            
    elif sell_pf < buy_pf:
        diff = buy_pf - sell_pf
        print(f"🚨 VENDAS (SELL) são PIORES que compras!")
        print(f"   → PF SELL ({sell_pf:.2f}) é {diff:.2f} menor que BUY ({buy_pf:.2f})")
        print(f"   → Problema prioritário: Melhorar trades de VENDA")
        print()
        
        if len(sell_tp_closes)/len(sell_trades) < len(buy_tp_closes)/len(buy_trades):
            print(f"   📊 Taxa de TP em VENDAS ({len(sell_tp_closes)/len(sell_trades)*100:.1f}%) < COMPRAS ({len(buy_tp_closes)/len(buy_trades)*100:.1f}%)")
            print(f"   → TP de 150 pips pode estar MUITO LONGE para VENDAS")
            print(f"   💡 SUGESTÃO: Considerar TP_SELL < TP_BUY (ex: TP_SELL=120 pips)")
        
        if abs(sell_avg_loser) > abs(buy_avg_loser):
            print(f"   📊 Perda média em VENDAS ({sell_avg_loser:.1f}) > COMPRAS ({buy_avg_loser:.1f})")
            print(f"   → SL de 40 pips pode estar APERTADO para VENDAS")
            print(f"   💡 SUGESTÃO: Considerar SL_SELL > SL_BUY (ex: SL_SELL=50 pips)")
        print()
    else:
        print("✅ BUY e SELL têm performance SIMILAR")
        print("   → Problema é GERAL, não específico de direção")
        print("   → Soluções aplicam-se igualmente para ambos")
        print()
    
    # RECOMENDAÇÕES FINAIS
    print("=" * 80)
    print("💡 RECOMENDAÇÕES FINAIS")
    print("=" * 80)
    print()
    print("1. BREAKEVEN: Implementar após 60 pips (1.5:1)")
    print("2. TRAILING STOP: Ativar após 100 pips (2.5:1)")
    if abs(buy_pf - sell_pf) > 0.15:
        print("3. TP/SL ASSIMÉTRICO: Considerar valores diferentes para BUY e SELL")
    else:
        print("3. TP/SL SIMÉTRICO: Manter valores iguais (problema não é assimétrico)")
    print()

print("=" * 80)
