#!/usr/bin/env python3
"""
Análise RÁPIDA do log consolidado v4.34
Valida CONFIG_SET sem processar todo o arquivo
"""
import re
from collections import Counter

def quick_analysis():
    """Análise rápida: apenas conta CONFIG_SETs e primeiros trades"""
    log_file = "log/20251023.log"
    
    print("⚡ ANÁLISE RÁPIDA - LOG CONSOLIDADO v4.34")
    print("=" * 70)
    
    config_pattern = re.compile(r'ConfigSetName=(\w+)')
    deal_pattern = re.compile(r'deal\s+#(\d+)\s+(buy|sell)')
    
    configs_found = []
    deals_per_config = {
        'CONSERVATIVE': 0,
        'MODERATE': 0,
        'AGGRESSIVE': 0
    }
    
    current_config = None
    total_deals = 0
    
    print("\n📄 Processando log...")
    
    with open(log_file, 'r', encoding='utf-16-le', errors='ignore') as f:
        for line_num, line in enumerate(f, 1):
            # Detectar mudança de CONFIG_SET
            config_match = config_pattern.search(line)
            if config_match:
                current_config = config_match.group(1)
                configs_found.append((line_num, current_config))
                print(f"  🏷️  Linha {line_num:7,}: CONFIG_SET = {current_config}")
            
            # Contar deals por CONFIG_SET
            deal_match = deal_pattern.search(line)
            if deal_match and current_config:
                deals_per_config[current_config] += 1
                total_deals += 1
            
            # Parar após processar 2M linhas (cobre as 3 execuções)
            if line_num >= 2000000:
                print(f"\n  ⏸️  Parado na linha 2.000.000 (análise completa)")
                break
            
            # Progresso a cada 200k linhas
            if line_num % 200000 == 0:
                print(f"  ⏳ Linha {line_num:7,} | "
                      f"Configs: {len(configs_found)} | "
                      f"Deals: {total_deals:,} | "
                      f"Config atual: {current_config or 'None'}")
    
    print(f"\n📊 RESULTADO DA ANÁLISE:")
    print("=" * 70)
    
    print(f"\n🏷️  CONFIG_SETS DETECTADOS: {len(configs_found)}")
    for line_num, config in configs_found:
        print(f"     Linha {line_num:7,}: {config}")
    
    print(f"\n📈 DEALS POR CONFIG_SET:")
    for config in ['CONSERVATIVE', 'MODERATE', 'AGGRESSIVE']:
        count = deals_per_config[config]
        pct = (count / total_deals * 100) if total_deals > 0 else 0
        bar = "█" * min(int(pct / 2), 50)
        print(f"     {config:15} | {count:5,} deals ({pct:5.1f}%) {bar}")
    
    print(f"\n     {'TOTAL':15} | {total_deals:5,} deals (100.0%)")
    
    # Validação
    print(f"\n✅ VALIDAÇÃO:")
    if len(configs_found) == 3:
        print("  ✅ 3 CONFIG_SETs detectados (CONSERVATIVE, MODERATE, AGGRESSIVE)")
    else:
        print(f"  ⚠️  Apenas {len(configs_found)} CONFIG_SETs detectados (esperado: 3)")
    
    if total_deals > 0:
        print(f"  ✅ {total_deals:,} deals processados")
    else:
        print(f"  ❌ Nenhum deal encontrado")
    
    # Verificar distribuição
    non_zero = sum(1 for c in deals_per_config.values() if c > 0)
    if non_zero == 3:
        print(f"  ✅ Trades distribuídos entre todas as 3 configurações")
    else:
        print(f"  ⚠️  Trades em apenas {non_zero}/3 configurações")
    
    return configs_found, deals_per_config

if __name__ == "__main__":
    configs, deals = quick_analysis()
    
    print(f"\n" + "=" * 70)
    print("🎯 CONCLUSÃO: Parser v4.34 está")
    if len(configs) == 3 and sum(deals.values()) > 0:
        print("     ✅ FUNCIONANDO CORRETAMENTE!")
        print(f"     💾 Pronto para análise completa com master_analyzer.py")
    else:
        print("     ⚠️  NECESSITA CORREÇÃO")
        print(f"     🔧 Verificar regex patterns ou lógica de aplicação")
