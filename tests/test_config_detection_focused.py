#!/usr/bin/env python3
"""
Teste FOCADO - Validar detecção de CONFIG_SET em 3 pontos do log
"""
import sys
from pathlib import Path

def test_config_set_lines():
    """Testa as 3 linhas exatas onde CONFIG_SET aparece"""
    log_file = Path("log/20251023.log")
    
    print("🔍 TESTE FOCADO - Detecção de CONFIG_SET")
    print("=" * 70)
    
    # Linhas onde CONFIG_SET aparece (baseado em grep)
    target_lines = {
        45: "CONSERVATIVE",
        734322: "MODERATE",
        1468588: "AGGRESSIVE"
    }
    
    found_configs = {}
    
    print("\n📄 Lendo log UTF-16LE...")
    with open(log_file, 'r', encoding='utf-16-le', errors='ignore') as f:
        for line_num, line in enumerate(f, 1):
            if line_num in target_lines:
                expected = target_lines[line_num]
                
                # Verificar se contém ConfigSetName
                if 'ConfigSetName=' in line:
                    # Extrair valor
                    import re
                    match = re.search(r'ConfigSetName=(\w+)', line)
                    if match:
                        detected = match.group(1)
                        found_configs[line_num] = detected
                        
                        status = "✅" if detected == expected else "⚠️"
                        print(f"{status} Linha {line_num:7,}: "
                              f"Esperado '{expected}' → Detectado '{detected}'")
                    else:
                        print(f"❌ Linha {line_num:7,}: "
                              f"ConfigSetName= encontrado mas regex falhou")
                        print(f"   Linha: {line[:100]}")
                else:
                    print(f"❌ Linha {line_num:7,}: "
                          f"ConfigSetName= NÃO encontrado")
                    print(f"   Linha: {line[:100]}")
            
            # Interromper após última linha alvo
            if line_num > max(target_lines.keys()):
                break
    
    print(f"\n📊 RESULTADO:")
    print("=" * 70)
    print(f"  Esperados: {len(target_lines)} CONFIG_SETs")
    print(f"  Detectados: {len(found_configs)} CONFIG_SETs")
    
    if len(found_configs) == len(target_lines):
        print(f"\n✅ SUCESSO! Todos os 3 CONFIG_SETs foram detectados!")
        for line_num, config in sorted(found_configs.items()):
            print(f"     Linha {line_num:7,}: {config}")
    else:
        print(f"\n⚠️  PROBLEMA: Apenas {len(found_configs)}/3 detectados")
        missing = set(target_lines.keys()) - set(found_configs.keys())
        if missing:
            print(f"     Faltando nas linhas: {sorted(missing)}")

if __name__ == "__main__":
    test_config_set_lines()
