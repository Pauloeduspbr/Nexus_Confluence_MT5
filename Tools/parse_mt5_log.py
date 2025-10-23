#!/usr/bin/env python3
import re
import json
import sys
from collections import defaultdict

log_path = sys.argv[1] if len(sys.argv) > 1 else 'log/20251022.log'
print(f"Parsing {log_path}...")

stats = {
    'candles': 0,
    'mtf_approved': 0,
    'mtf_rejected': 0,
    'setups_good': 0,
    'setups_premium': 0,
    'risk_calc': 0,
    'rejections': defaultdict(int),
    'atr_values': []
}

with open(log_path, 'r', encoding='utf-8', errors='ignore') as f:
    for i, line in enumerate(f):
        if i % 100000 == 0 and i > 0:
            print(f"  {i:,} lines processed...")
        
        if 'NOVO CANDLE' in line:
            stats['candles'] += 1
        elif 'MULTI-TIMEFRAME APROVADO' in line:
            stats['mtf_approved'] += 1
        elif 'Multi-timeframe NÃO ALINHADO' in line or 'AMBOS NEUTROS' in line:
            stats['mtf_rejected'] += 1
        elif 'Classificação: P+ GOOD' in line or 'Classificação: GOOD' in line:
            stats['setups_good'] += 1
        elif 'Classificação: PREMIUM' in line:
            stats['setups_premium'] += 1
        elif 'CALCULANDO TAMANHO' in line:
            stats['risk_calc'] += 1
        elif 'Margem insuficiente' in line:
            stats['rejections']['margem'] += 1
        elif 'Risco INVÁLIDO' in line:
            stats['rejections']['risco'] += 1
        elif 'ATR OK:' in line:
            match = re.search(r'ATR OK: ([\d.]+)', line)
            if match:
                stats['atr_values'].append(float(match.group(1)))

print("\n=== RESULTS ===")
print(f"Candles: {stats['candles']}")
print(f"MTF Approved: {stats['mtf_approved']}")
print(f"MTF Rejected: {stats['mtf_rejected']}")
print(f"Setups GOOD: {stats['setups_good']}")
print(f"Setups PREMIUM: {stats['setups_premium']}")
print(f"Risk Calculations: {stats['risk_calc']}")
print(f"Rejections: {dict(stats['rejections'])}")
print(f"ATR samples: {len(stats['atr_values'])}")

if stats['atr_values']:
    import statistics as st
    print(f"\nATR Stats:")
    print(f"  Mean: {st.mean(stats['atr_values']):.5f}")
    print(f"  Median: {st.median(stats['atr_values']):.5f}")
    print(f"  StDev: {st.stdev(stats['atr_values']):.5f}")
    print(f"  CV: {st.stdev(stats['atr_values']) / st.mean(stats['atr_values']):.4f}")

with open('log/quick_stats.json', 'w') as f:
    json.dump(stats, f, indent=2)
print("\nSaved to log/quick_stats.json")
