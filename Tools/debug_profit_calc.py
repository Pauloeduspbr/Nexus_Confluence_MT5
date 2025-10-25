#!/usr/bin/env python3
"""Debug profit calculation"""
from pathlib import Path
import re
from datetime import datetime

html_file = Path(__file__).parent.parent / 'log' / 'ReportTester-7635384.html'

with open(html_file, 'r', encoding='utf-16-le') as f:
    html = f.read()

# Primeiro trade
entry_pattern = re.compile(
    r'<td>([\d.]+\s+[\d:]+)</td><td>(\d+)</td><td>USDJPY</td><td>(buy|sell)</td>'
    r'.*?<td>([\d.]+)</td><td>([\d.]+)</td>.*?<td>(Nexus_[A-Z]+_(GOOD|PREMIUM))</td>',
    re.DOTALL | re.IGNORECASE
)

exit_pattern = re.compile(
    r'<td>([\d.]+\s+[\d:]+)</td><td>(\d+)</td><td>USDJPY</td><td>(buy|sell)</td>'
    r'.*?<td></td><td></td>.*?<td>(tp|sl|be)\s+([\d.]+)</td>',
    re.DOTALL | re.IGNORECASE
)

entries = list(entry_pattern.finditer(html))[:5]
exits = list(exit_pattern.finditer(html))[:5]

print("=== PRIMEIRAS 5 ENTRADAS ===")
for i, match in enumerate(entries, 1):
    print(f"\nTrade #{i}:")
    print(f"  Time: {match.group(1)}")
    print(f"  Ticket: {match.group(2)}")
    print(f"  Direction: {match.group(3)}")
    print(f"  Entry Price: {match.group(4)}")
    print(f"  TP: {match.group(5)}")
    print(f"  Setup: {match.group(7)}")

print("\n=== PRIMEIRAS 5 SAÍDAS ===")
for i, match in enumerate(exits, 1):
    print(f"\nExit #{i}:")
    print(f"  Time: {match.group(1)}")
    print(f"  Ticket: {match.group(2)}")
    print(f"  Exit Direction: {match.group(3)}")
    print(f"  Reason: {match.group(4)}")
    print(f"  Close Price: {match.group(5)}")

# Calcular primeiro trade manualmente
if entries and exits:
    entry = entries[0]
    exit_trade = exits[0]
    
    entry_price = float(entry.group(4))
    close_price = float(exit_trade.group(5))
    direction = entry.group(3)
    reason = exit_trade.group(4)
    
    print("\n=== CÁLCULO MANUAL DO PRIMEIRO TRADE ===")
    print(f"Direction: {direction}")
    print(f"Entry Price: {entry_price}")
    print(f"Close Price: {close_price}")
    print(f"Reason: {reason}")
    
    if direction == 'buy':
        profit = (close_price - entry_price) * 1000
    else:
        profit = (entry_price - close_price) * 1000
    
    print(f"Profit: {profit:.2f} pips")
    print(f"Winner? {profit > 0}")
