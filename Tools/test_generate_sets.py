#!/usr/bin/env python3
"""
Script para testar geração de arquivos .set COMPLETOS
"""

import sys
import json
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from complete_set_generator import CompleteSetGenerator

# Ler análise mais recente
analysis_files = sorted(Path('analysis_output').glob('master_analysis_*.json'), reverse=True)
if not analysis_files:
    print("❌ Nenhum arquivo de análise encontrado!")
    sys.exit(1)

latest_analysis = analysis_files[0]
print(f"📊 Usando análise: {latest_analysis.name}")

with open(latest_analysis, 'r', encoding='utf-8') as f:
    analysis_data = json.load(f)

print(f"   Symbol: {analysis_data.get('metadata', {}).get('symbol', 'UNKNOWN')}")
print(f"   Trades: {analysis_data.get('metadata', {}).get('n_trades', 0)}")

# Criar gerador
output_dir = Path('Presets')
generator = CompleteSetGenerator(output_dir=output_dir)

print(f"\n🔧 Gerando 3 perfis COMPLETOS...")

profiles = ['CONSERVATIVE', 'MODERATE', 'AGGRESSIVE']

for profile in profiles:
    print(f"\n   → {profile}")
    
    # Gerar conteúdo
    content = generator.generate_complete_set(
        analysis_data=analysis_data,
        profile=profile
    )
    
    # Salvar arquivo
    symbol = analysis_data.get('metadata', {}).get('symbol', 'UNKNOWN')
    from datetime import datetime
    timestamp = datetime.now().strftime('%Y%m%d')
    filename = f"NexusConfluence_{symbol}_{profile}_{timestamp}.set"
    filepath = output_dir / filename
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    
    # Validar
    lines = content.strip().split('\n')
    params = [l for l in lines if '=' in l and not l.startswith(';')]
    
    print(f"     ✓ Arquivo: {filepath.name}")
    print(f"     ✓ Linhas: {len(lines)}")
    print(f"     ✓ Parâmetros: {len(params)}")
    print(f"     ✓ Tamanho: {len(content):,} bytes")
    
    # Validar se é completo
    if len(params) < 140:
        print(f"     ❌ ERRO: Apenas {len(params)} parâmetros! Esperado ~145")
    else:
        print(f"     ✅ OK: Arquivo COMPLETO!")

print(f"\n✅ Geração concluída!")
