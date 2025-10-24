#!/usr/bin/env python3
"""
Teste rápido: Validar detecção de CONFIG_SET no log consolidado
Sem dependências pesadas (scipy, sklearn, etc)
"""

import re
from pathlib import Path

def test_config_set_detection(log_file: str):
    """Testa detecção de CONFIG_SET nos parâmetros"""
    
    log_path = Path(log_file)
    if not log_path.exists():
        print(f"❌ Arquivo não encontrado: {log_file}")
        return
    
    print(f"📄 Analisando: {log_file}")
    print(f"💾 Tamanho: {log_path.stat().st_size / (1024*1024):.1f} MB")
    print()
    
    # Regex para detectar ConfigSetName
    pattern = re.compile(r'ConfigSetName=(\w+)', re.IGNORECASE)
    
    # Rastrear CONFIG_SETs encontrados
    config_sets = []
    line_numbers = []
    
    print("🔍 Procurando CONFIG_SETs...")
    with open(log_path, 'r', encoding='utf-16-le', errors='ignore') as f:
        for line_num, line in enumerate(f, 1):
            match = pattern.search(line)
            if match:
                config_set = match.group(1)
                config_sets.append(config_set)
                line_numbers.append(line_num)
                print(f"  ✅ Linha {line_num:,}: ConfigSetName={config_set}")
            
            # Mostrar progresso a cada 100k linhas
            if line_num % 100000 == 0:
                print(f"  ... Processadas {line_num:,} linhas ({len(config_sets)} CONFIG_SETs encontrados)")
    
    print()
    print("=" * 60)
    print("📊 RESUMO DA DETECÇÃO")
    print("=" * 60)
    print(f"Total de linhas processadas: {line_num:,}")
    print(f"CONFIG_SETs encontrados: {len(config_sets)}")
    print()
    
    if config_sets:
        print("🏷️  CONFIG_SETs detectados (em ordem):")
        for i, (cs, ln) in enumerate(zip(config_sets, line_numbers), 1):
            print(f"  {i}. {cs} (linha {ln:,})")
        
        print()
        print("📋 LÓGICA DE SEPARAÇÃO:")
        for i in range(len(config_sets)):
            start_line = line_numbers[i]
            end_line = line_numbers[i+1] if i < len(config_sets)-1 else line_num
            num_lines = end_line - start_line
            
            print(f"  {config_sets[i]}:")
            print(f"    Linha inicial: {start_line:,}")
            print(f"    Linha final: {end_line:,}")
            print(f"    Total de linhas: {num_lines:,}")
            print()
    else:
        print("⚠️  Nenhum CONFIG_SET detectado!")
        print("   Verifique se o log foi gerado com EA v4.34+")
    
    print("=" * 60)

if __name__ == "__main__":
    import sys
    
    if len(sys.argv) < 2:
        print("Uso: python3 test_config_set_detection.py <log_file>")
        sys.exit(1)
    
    test_config_set_detection(sys.argv[1])
