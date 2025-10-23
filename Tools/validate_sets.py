#!/usr/bin/env python3
"""
Validador completo de arquivos .set gerados
"""

import re
from pathlib import Path

def validate_set_file(filepath: Path) -> dict:
    """Valida arquivo .set"""
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    lines = content.strip().split('\n')
    
    # Extrair parâmetros
    params = {}
    duplicates = []
    
    for line in lines:
        if '=' in line and not line.startswith(';'):
            key = line.split('=')[0].strip()
            value = line.split('=')[1].split('||')[0].strip()
            
            if key in params:
                duplicates.append(key)
            
            params[key] = value
    
    # Validações
    issues = []
    
    # 1. Quantidade de parâmetros
    if len(params) < 140:
        issues.append(f"❌ Apenas {len(params)} parâmetros (esperado ~145)")
    
    # 2. Parâmetros duplicados
    if duplicates:
        issues.append(f"⚠️ Parâmetros duplicados: {', '.join(set(duplicates))}")
    
    # 3. Validar parâmetros críticos
    critical_params = {
        'AccountRiskPercent': float,
        'MaxRiskPremium': float,
        'CustomStartHour': int,
        'CustomEndHour': int,
        'TrailingATRMultiplier': float,
        'MinConfluenceScore': int,
    }
    
    for param, ptype in critical_params.items():
        if param not in params:
            issues.append(f"❌ Parâmetro CRÍTICO faltando: {param}")
    
    # 4. Verificar hora 10 (pior hora)
    if params.get('CustomStartHour') == '10':
        issues.append(f"⚠️ CustomStartHour=10 (HORA 10 É A PIOR IDENTIFICADA!)")
    
    return {
        'filepath': filepath.name,
        'lines': len(lines),
        'parameters': len(params),
        'duplicates': list(set(duplicates)),
        'critical_values': {k: params.get(k, 'N/A') for k in critical_params.keys()},
        'issues': issues,
        'valid': len(issues) == 0
    }

def main():
    presets_dir = Path('Presets')
    
    # Validar 3 perfis
    profiles = ['CONSERVATIVE', 'MODERATE', 'AGGRESSIVE']
    
    print("=" * 80)
    print("🔍 VALIDAÇÃO COMPLETA DE ARQUIVOS .SET GERADOS")
    print("=" * 80)
    
    all_valid = True
    results = {}
    
    for profile in profiles:
        filepath = presets_dir / f"NexusConfluence_USDJPY_{profile}_20251023.set"
        
        if not filepath.exists():
            print(f"\n❌ {profile}: Arquivo não encontrado!")
            all_valid = False
            continue
        
        print(f"\n📄 {profile}")
        print("-" * 80)
        
        result = validate_set_file(filepath)
        results[profile] = result
        
        print(f"   Arquivo: {result['filepath']}")
        print(f"   Linhas: {result['lines']}")
        print(f"   Parâmetros: {result['parameters']}")
        
        if result['duplicates']:
            print(f"   Duplicados: {', '.join(result['duplicates'])}")
        
        print(f"\n   Parâmetros Críticos:")
        for key, value in result['critical_values'].items():
            print(f"     • {key}: {value}")
        
        if result['issues']:
            print(f"\n   ⚠️ PROBLEMAS IDENTIFICADOS:")
            for issue in result['issues']:
                print(f"     {issue}")
            all_valid = False
        else:
            print(f"\n   ✅ Arquivo VÁLIDO!")
    
    # Comparação entre perfis
    print(f"\n" + "=" * 80)
    print("📊 COMPARAÇÃO ENTRE PERFIS")
    print("=" * 80)
    
    if all(p in results for p in profiles):
        print(f"\n{'Parâmetro':<25} | {'CONSERVATIVE':<15} | {'MODERATE':<15} | {'AGGRESSIVE':<15}")
        print("-" * 80)
        
        critical_params = ['AccountRiskPercent', 'MaxRiskPremium', 'TrailingATRMultiplier', 
                          'CustomStartHour', 'CustomEndHour', 'MinConfluenceScore']
        
        for param in critical_params:
            cons_val = results['CONSERVATIVE']['critical_values'].get(param, 'N/A')
            mod_val = results['MODERATE']['critical_values'].get(param, 'N/A')
            agg_val = results['AGGRESSIVE']['critical_values'].get(param, 'N/A')
            
            # Verificar se todos são iguais
            if cons_val == mod_val == agg_val:
                flag = "⚠️"
            else:
                flag = "✅"
            
            print(f"{flag} {param:<23} | {cons_val:<15} | {mod_val:<15} | {agg_val:<15}")
    
    # Resultado final
    print(f"\n" + "=" * 80)
    if all_valid:
        print("✅ TODOS OS ARQUIVOS ESTÃO VÁLIDOS E COMPLETOS!")
    else:
        print("❌ PROBLEMAS ENCONTRADOS - REVISAR ARQUIVOS!")
    print("=" * 80)

if __name__ == '__main__':
    main()
