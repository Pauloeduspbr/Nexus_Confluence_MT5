#!/usr/bin/env python3
"""
Script de debug para identificar onde estão os deals em cada CONFIG_SET
"""

import re

log_file = 'log/20251023.log'

# Detectar ConfigSetName e contar deals
config_sets = {}
current_config = None
line_number = 0

config_set_pattern = re.compile(r'ConfigSetName=(\w+)', re.IGNORECASE)
deal_pattern = re.compile(r'deal\s+#\d+', re.IGNORECASE)

print(f"📄 Analisando: {log_file}")
print(f"🔍 Procurando por ConfigSetName e deals...")
print()

with open(log_file, 'r', encoding='utf-16-le', errors='ignore') as f:
    for line in f:
        line_number += 1
        
        # Detectar mudança de CONFIG_SET
        match = config_set_pattern.search(line)
        if match:
            current_config = match.group(1)
            if current_config not in config_sets:
                config_sets[current_config] = {
                    'first_line': line_number,
                    'deals': 0,
                    'deal_lines': []
                }
            print(f"  🏷️  Linha {line_number:,}: Detectado CONFIG_SET = {current_config}")
        
        # Contar deals
        if deal_pattern.search(line):
            if current_config:
                config_sets[current_config]['deals'] += 1
                # Guardar apenas primeiros 5 deals de cada config
                if len(config_sets[current_config]['deal_lines']) < 5:
                    config_sets[current_config]['deal_lines'].append(line_number)

print()
print("=" * 70)
print("📊 RESULTADO DA ANÁLISE")
print("=" * 70)
print()

for config_name, data in config_sets.items():
    print(f"🏷️  {config_name}:")
    print(f"   Primeira aparição: Linha {data['first_line']:,}")
    print(f"   Total de deals: {data['deals']:,}")
    if data['deal_lines']:
        print(f"   Primeiros deals nas linhas: {', '.join(str(x) for x in data['deal_lines'])}")
    else:
        print(f"   ⚠️  NENHUM DEAL encontrado!")
    print()

total_deals = sum(data['deals'] for data in config_sets.values())
print(f"✅ Total de deals no log: {total_deals:,}")
print(f"📝 Total de linhas processadas: {line_number:,}")
