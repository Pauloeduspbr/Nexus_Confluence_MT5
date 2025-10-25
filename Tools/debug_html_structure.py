#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Debug: Inspecionar estrutura real do HTML
"""

import codecs
import re

print("Lendo HTML...")
with codecs.open('log/ReportTester-7635384.html', 'r', 'utf-16-le') as f:
    html = f.read()

print("=" * 80)
print("PROCURANDO TRADES NA TABELA")
print("=" * 80)
print()

# Procurar seção de histórico
if 'History' in html or 'Histórico' in html or 'history' in html.lower():
    print("✅ Encontrada seção de histórico")
    
    # Extrair primeiras linhas após "history" (case insensitive)
    history_idx = html.lower().find('history')
    if history_idx != -1:
        snippet = html[history_idx:history_idx+5000]
        
        # Procurar primeiras 3 linhas <tr>
        lines = snippet.split('<tr')
        
        for i, line in enumerate(lines[:5]):
            print(f"\n--- LINHA {i} ---")
            # Extrair primeiros 500 chars
            print(line[:800])
            
            # Ver se tem 'buy' ou 'sell'
            if 'buy' in line.lower() or 'sell' in line.lower():
                print("\n🎯 ESTA LINHA TEM BUY/SELL!")
                
                # Tentar extrair células
                cells = re.findall(r'<td[^>]*>(.*?)</td>', line, re.DOTALL | re.IGNORECASE)
                print(f"Células encontradas: {len(cells)}")
                
                for j, cell in enumerate(cells):
                    print(f"  Célula {j}: {cell[:100]}")
else:
    print("❌ Seção de histórico não encontrada")

print()
print("=" * 80)
print("TENTANDO BUSCAR DIRETAMENTE 'BUY' E 'SELL'")
print("=" * 80)
print()

# Buscar primeiras ocorrências de 'buy' e 'sell' em tags
buy_matches = re.finditer(r'<[^>]*>buy<', html, re.IGNORECASE)
sell_matches = re.finditer(r'<[^>]*>sell<', html, re.IGNORECASE)

print(f"Ocorrências de '>buy<': {len(list(buy_matches))}")
print(f"Ocorrências de '>sell<': {len(list(sell_matches))}")

# Mostrar primeiras ocorrências
buy_matches = re.finditer(r'<[^>]*>buy<', html, re.IGNORECASE)
for i, match in enumerate(list(buy_matches)[:3]):
    start = max(0, match.start() - 200)
    end = min(len(html), match.end() + 500)
    print(f"\n--- BUY {i+1} ---")
    print(html[start:end])

sell_matches = re.finditer(r'<[^>]*>sell<', html, re.IGNORECASE)
for i, match in enumerate(list(sell_matches)[:3]):
    start = max(0, match.start() - 200)
    end = min(len(html), match.end() + 500)
    print(f"\n--- SELL {i+1} ---")
    print(html[start:end])
