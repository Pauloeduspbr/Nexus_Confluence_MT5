#!/usr/bin/env python3
"""
🔬 ANÁLISE TÉCNICA PROFUNDA - NEXUS CONFLUENCE EA
Análise matemática para identificar causa raiz das rejeições por margem
"""

import json
import re
from pathlib import Path
from typing import Dict, List, Tuple
from statistics import mean, median, stdev
from collections import defaultdict


def load_stats() -> Dict:
    """Carrega estatísticas do log"""
    stats_file = Path("log/clean_stats.json")
    with open(stats_file, 'r') as f:
        return json.load(f)


def analyze_atr_values(atr_values: List[float]) -> Dict:
    """Analisa valores de ATR"""
    return {
        'mean': mean(atr_values),
        'median': median(atr_values),
        'stdev': stdev(atr_values) if len(atr_values) > 1 else 0,
        'min': min(atr_values),
        'max': max(atr_values),
        'p25': sorted(atr_values)[len(atr_values)//4],
        'p75': sorted(atr_values)[3*len(atr_values)//4],
    }


def extract_from_code_file(filepath: str, patterns: Dict[str, str]) -> Dict:
    """Extrai valores de parâmetros do código"""
    results = {}
    
    if not Path(filepath).exists():
        return results
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
        
    for param_name, pattern in patterns.items():
        match = re.search(pattern, content, re.IGNORECASE)
        if match:
            results[param_name] = match.group(1)
    
    return results


def calculate_margin_for_scenario(balance: float, risk_percent: float, 
                                   sl_pips: float, pip_value: float = 10.0,
                                   leverage: int = 100) -> Dict:
    """
    Calcula margem necessária para um cenário
    
    Args:
        balance: Saldo da conta
        risk_percent: % de risco por trade
        sl_pips: Distância do SL em pips
        pip_value: Valor do pip (default $10 para USDJPY lote padrão)
        leverage: Alavancagem (default 1:100)
    """
    risk_amount = balance * (risk_percent / 100.0)
    lot_size = risk_amount / (sl_pips * pip_value)
    
    # Arredondar para 0.01 (step mínimo)
    lot_size = round(lot_size, 2)
    
    # Valor nocional
    notional_value = lot_size * 100000  # 1 lote padrão = 100k unidades
    
    # Margem necessária
    margin_required = notional_value / leverage
    
    return {
        'risk_amount': risk_amount,
        'lot_size': lot_size,
        'notional_value': notional_value,
        'margin_required': margin_required,
        'sl_pips': sl_pips,
    }


def simulate_rejection_scenarios(balance: float, risk_percent: float,
                                  safety_margin_percent: float) -> List[Dict]:
    """Simula diferentes cenários de SL e identifica rejeições"""
    
    scenarios = []
    sl_values = [20, 25, 30, 35, 40, 45, 50, 60]
    
    for sl_pips in sl_values:
        calc = calculate_margin_for_scenario(balance, risk_percent, sl_pips)
        
        # Simular 3 trades simultâneos
        total_margin_used = calc['margin_required'] * 3
        margin_free = balance - total_margin_used
        safety_buffer = balance * (safety_margin_percent / 100.0)
        
        # Validação
        is_valid = (margin_free - calc['margin_required']) > safety_buffer
        
        scenarios.append({
            'sl_pips': sl_pips,
            'lot_size': calc['lot_size'],
            'margin_per_trade': calc['margin_required'],
            'total_margin_3trades': total_margin_used,
            'margin_free_after_3': margin_free,
            'safety_buffer': safety_buffer,
            'new_trade_margin': calc['margin_required'],
            'validation': is_valid,
            'gap': margin_free - calc['margin_required'] - safety_buffer
        })
    
    return scenarios


def analyze_code_parameters():
    """Analisa parâmetros do código fonte"""
    
    print("=" * 80)
    print("🔬 ANÁLISE DE PARÂMETROS DO CÓDIGO")
    print("=" * 80)
    
    # Padrões para buscar
    param_patterns = {
        'AccountRiskPercent': r'AccountRiskPercent\s*=\s*([\d.]+)',
        'MaxRiskPerTrade': r'MaxRiskPerTrade\s*=\s*([\d.]+)',
        'SLMultiplier': r'SL.*?Multiplier\s*=\s*([\d.]+)',
        'TPMultiplier1': r'TP.*?Multiplier.*?1\s*=\s*([\d.]+)',
        'TPMultiplier2': r'TP.*?Multiplier.*?2\s*=\s*([\d.]+)',
        'BEActivation': r'BE.*?Activation\s*=\s*([\d.]+)',
        'TrailingDistance': r'Trailing.*?Distance\s*=\s*([\d.]+)',
        'MinFreeMargin': r'Min.*?Free.*?Margin\s*=\s*([\d.]+)',
    }
    
    files_to_check = [
        'Include/NexusConfluenceEA/Parametros.mqh',
        'Include/NexusConfluenceEA/RiskManagement.mqh',
        'Include/NexusConfluenceEA/Estrategias.mqh',
    ]
    
    all_params = {}
    for filepath in files_to_check:
        if Path(filepath).exists():
            print(f"\n📄 Analisando: {filepath}")
            params = extract_from_code_file(filepath, param_patterns)
            all_params.update(params)
            for key, value in params.items():
                print(f"   ✓ {key}: {value}")
        else:
            print(f"\n⚠️  Arquivo não encontrado: {filepath}")
    
    return all_params


def main():
    """Execução principal"""
    
    print("\n")
    print("=" * 80)
    print("🔬 NEXUS CONFLUENCE EA - ANÁLISE TÉCNICA PROFUNDA")
    print("=" * 80)
    print("Objetivo: Identificar causa raiz das 36.6% rejeições por margem")
    print("=" * 80)
    
    # 1. Carregar estatísticas
    print("\n[1/5] 📊 Carregando estatísticas do log...")
    stats = load_stats()
    
    print(f"   ✓ Candles: {stats['candles']:,}")
    print(f"   ✓ Setups: {stats['setups_good'] + stats['setups_premium']:,}")
    print(f"   ✓ Cálculos de risco: {stats['risk_calc']:,}")
    print(f"   ✓ Rejeições por margem: {stats['rejections']['margem']:,}")
    print(f"   ✓ Taxa de rejeição: {(stats['rejections']['margem']/stats['risk_calc']*100):.1f}%")
    
    # 2. Analisar ATR
    print("\n[2/5] 📈 Analisando ATR (Average True Range)...")
    atr_analysis = analyze_atr_values(stats['atr_values'])
    
    print(f"   ✓ ATR médio: {atr_analysis['mean']:.5f}")
    print(f"   ✓ ATR mediano: {atr_analysis['median']:.5f}")
    print(f"   ✓ Desvio padrão: {atr_analysis['stdev']:.5f}")
    print(f"   ✓ Mínimo: {atr_analysis['min']:.5f}")
    print(f"   ✓ Máximo: {atr_analysis['max']:.5f}")
    print(f"   ✓ Percentil 25: {atr_analysis['p25']:.5f}")
    print(f"   ✓ Percentil 75: {atr_analysis['p75']:.5f}")
    
    # Converter para pips (USDJPY: 1 pip = 0.01, então × 100)
    atr_pips = atr_analysis['mean'] * 100
    print(f"\n   💡 ATR médio em pips: {atr_pips:.1f} pips")
    
    # 3. Extrair parâmetros do código
    print("\n[3/5] 💾 Extraindo parâmetros do código fonte...")
    code_params = analyze_code_parameters()
    
    # 4. Simulações matemáticas
    print("\n[4/5] 🧮 Simulando cenários de margem...")
    print("\nParâmetros da simulação:")
    print("   - Capital: $10,000 (assumido)")
    print("   - Risk%: 1.5% (assumido - verificar no código)")
    print("   - Safety Margin: 30% (assumido - verificar no código)")
    print("   - Leverage: 1:100")
    print("   - Pip Value: $10/lote padrão")
    
    scenarios = simulate_rejection_scenarios(
        balance=10000,
        risk_percent=1.5,
        safety_margin_percent=30
    )
    
    print("\n   Resultados por SL:")
    print("   " + "-" * 76)
    print(f"   {'SL':>6} | {'Lote':>6} | {'Margem':>8} | {'Margem 3x':>10} | {'Livre':>8} | {'Buffer':>8} | {'Status':>10}")
    print("   " + "-" * 76)
    
    for s in scenarios:
        status = "✅ APROVADO" if s['validation'] else "❌ REJEITADO"
        print(f"   {s['sl_pips']:>6.0f} | {s['lot_size']:>6.2f} | ${s['margin_per_trade']:>7.0f} | "
              f"${s['total_margin_3trades']:>9.0f} | ${s['margin_free_after_3']:>7.0f} | "
              f"${s['safety_buffer']:>7.0f} | {status}")
    
    # 5. Diagnóstico
    print("\n[5/5] 🔍 DIAGNÓSTICO")
    print("=" * 80)
    
    # Identificar ponto de quebra
    rejected_scenarios = [s for s in scenarios if not s['validation']]
    approved_scenarios = [s for s in scenarios if s['validation']]
    
    if rejected_scenarios:
        first_rejection = rejected_scenarios[0]
        print(f"\n⚠️  PROBLEMA IDENTIFICADO:")
        print(f"   Rejeições começam em SL = {first_rejection['sl_pips']:.0f} pips")
        print(f"   Com lote calculado = {first_rejection['lot_size']:.2f}")
        print(f"   Margem necessária = ${first_rejection['margin_per_trade']:.0f}")
        
        if approved_scenarios:
            last_approved = approved_scenarios[-1]
            print(f"\n✅ Último cenário aprovado:")
            print(f"   SL = {last_approved['sl_pips']:.0f} pips")
            print(f"   Lote = {last_approved['lot_size']:.2f}")
            print(f"   Gap de segurança = ${last_approved['gap']:.0f}")
        
        # Comparar com ATR
        print(f"\n📊 Comparação com ATR:")
        if atr_pips > 0:
            sl_atr_ratio_rejected = first_rejection['sl_pips'] / atr_pips
            print(f"   SL problemático / ATR = {sl_atr_ratio_rejected:.2f}x")
            print(f"   (Ideal: 1.5-2.5x ATR)")
            
            if sl_atr_ratio_rejected < 1.5:
                print(f"\n   🔴 CAUSA RAIZ: SL muito CURTO!")
                print(f"   SL atual: {first_rejection['sl_pips']:.0f} pips ({sl_atr_ratio_rejected:.2f}x ATR)")
                print(f"   SL ideal: {atr_pips * 1.8:.0f}-{atr_pips * 2.2:.0f} pips (1.8-2.2x ATR)")
            elif sl_atr_ratio_rejected > 2.5:
                print(f"\n   🔴 CAUSA RAIZ: SL muito LARGO!")
                print(f"   SL atual: {first_rejection['sl_pips']:.0f} pips ({sl_atr_ratio_rejected:.2f}x ATR)")
                print(f"   SL ideal: {atr_pips * 1.8:.0f}-{atr_pips * 2.2:.0f} pips (1.8-2.2x ATR)")
    
    # Recomendações
    print("\n" + "=" * 80)
    print("💡 RECOMENDAÇÕES")
    print("=" * 80)
    
    print("\n1. ANÁLISE MANUAL NECESSÁRIA:")
    print("   □ Ler código fonte em RiskManagement.mqh")
    print("   □ Verificar valor REAL de AccountRiskPercent")
    print("   □ Verificar valor REAL de MinFreeMarginPercent")
    print("   □ Verificar como SL é calculado (estrutura vs fixo)")
    
    print("\n2. EXTRAIR DO LOG:")
    print("   □ grep 'Stop loss calculado' log/20251022.log | head -100")
    print("   □ grep 'Margem insuficiente' log/20251022.log | head -100")
    print("   □ grep 'CALCULANDO TAMANHO' log/20251022.log | head -100")
    
    print("\n3. PRÓXIMOS PASSOS:")
    print("   □ Validar se SL médio está realmente curto")
    print("   □ Se sim: aumentar SLMultiplier ou SL mínimo")
    print("   □ Se não: verificar se safety margin está muito alto")
    print("   □ Considerar reduzir Risk% de 1.5% para 1.2%")
    
    print("\n" + "=" * 80)
    print("✅ Análise concluída!")
    print("   Próximo: Analisar código fonte com os valores encontrados")
    print("=" * 80)
    
    # Salvar resultados
    results = {
        'stats': stats,
        'atr_analysis': atr_analysis,
        'atr_pips': atr_pips,
        'code_params': code_params,
        'scenarios': scenarios,
        'rejected_count': len(rejected_scenarios),
        'approved_count': len(approved_scenarios),
    }
    
    with open('analysis_output/technical_analysis_results.json', 'w') as f:
        json.dump(results, f, indent=2, default=str)
    
    print(f"\n📁 Resultados salvos em: analysis_output/technical_analysis_results.json")


if __name__ == "__main__":
    main()
