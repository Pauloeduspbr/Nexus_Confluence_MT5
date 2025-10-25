#!/usr/bin/env python3
"""Parser simples e direto do HTML report"""
import re
from datetime import datetime
from pathlib import Path

html_file = Path(__file__).parent.parent / 'log' / 'ReportTester-7635384.html'

with open(html_file, 'r', encoding='utf-16-le') as f:
    html = f.read()

# Buscar linhas com buy
entry_lines = []
exit_lines = []

for line in html.split('\n'):
    if 'buy' in line.lower() and 'Nexus_BUY' in line:
        entry_lines.append(line)
    elif ('tp ' in line or 'sl ' in line) and 'sell' in line.lower():
        exit_lines.append(line)

print(f"Entry lines: {len(entry_lines)}")
print(f"Exit lines: {len(exit_lines)}")

if entry_lines:
    print("\nPrimeira entry:")
    print(entry_lines[0][:500])
    
if exit_lines:
    print("\nPrimeira exit:")
    print(exit_lines[0][:500])
