#!/usr/bin/env python3
"""
Script para regenerar arquivos .set com nome correto
"""
import sys
import json
from pathlib import Path

# Adicionar Tools ao path
sys.path.insert(0, str(Path(__file__).parent))

from complete_set_generator import CompleteSetGenerator

def main():
    # Diretório base
    base_dir = Path(__file__).parent.parent
    
    # Carregar análise
    analysis_file = base_dir / 'analysis_output' / 'master_analysis_20251023_083606.json'
    
    print(f"📂 Carregando análise: {analysis_file}")
    with open(analysis_file, 'r') as f:
        analysis_data = json.load(f)
    
    # Extrair símbolo
    symbol = analysis_data.get('metadata', {}).get('symbol', 'UNKNOWN')
    n_trades = analysis_data.get('metadata', {}).get('n_trades', 0)
    
    print(f"📊 Símbolo: {symbol}")
    print(f"📈 Trades: {n_trades}")
    print()
    
    # Detectar versão atual (padrão v4.32)
    version = "v4.32"
    
    # Gerar .set files
    presets_dir = base_dir / 'Presets'
    generator = CompleteSetGenerator(presets_dir)
    
    for profile in ['CONSERVATIVE', 'MODERATE', 'AGGRESSIVE']:
        print(f"⚙️  Gerando perfil {profile}...")
        content = generator.generate_complete_set(analysis_data, profile)
        filepath = generator.save_set_file(content, symbol, profile, version)
        
        print(f"   ✅ Arquivo: {filepath.name}")
        print(f"   📦 Tamanho: {filepath.stat().st_size:,} bytes")
        print(f"   📊 Linhas: {len(content.splitlines())}")
        print()
    
    print(f"✅ ARQUIVOS .SET {version} REGENERADOS COM SUCESSO!")

if __name__ == '__main__':
    main()
