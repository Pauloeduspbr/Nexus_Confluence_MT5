#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Extrator Rápido de SL e Rejeições de Margem
Processa log 1.1GB em streaming para encontrar padrões críticos
"""

import re
import json
from datetime import datetime
from pathlib import Path
from collections import defaultdict

def extract_critical_data(log_file):
    """
    Extrai dados críticos: SL calculado, rejeições de margem, valores ATR
    """
    
    print("=" * 80)
    print("🔍 EXTRAÇÃO DE DADOS CRÍTICOS - STOP LOSS E REJEIÇÕES")
    print("=" * 80)
    
    # Patterns para buscar
    patterns = {
        'sl_calc': re.compile(r'Stop loss calculado:\s*([\d.]+)'),
        'rejection': re.compile(r'(Margem insuficiente|REJEITADO|Ordem rejeitada)'),
        'atr_value': re.compile(r'ATR\s*[=:]\s*([\d.]+)'),
        'lot_size': re.compile(r'Lote calculado:\s*([\d.]+)'),
        'margin_req': re.compile(r'Margem necessária:\s*([\d.]+)'),
        'margin_free': re.compile(r'Margem livre:\s*([\d.]+)'),
        'min_margin': re.compile(r'MinFreeMarginPercent|margem mínima|safety.*margin', re.I),
        'sl_distance': re.compile(r'Distância SL:\s*([\d.]+)'),
        'risk_calc': re.compile(r'CALCULANDO TAMANHO.*risco:\s*([\d.]+)%', re.I)
    }
    
    # Contadores e dados
    data = {
        'sl_values': [],
        'atr_values': [],
        'lot_sizes': [],
        'margins_required': [],
        'margins_free': [],
        'sl_distances': [],
        'risk_percents': [],
        'rejections': [],
        'rejection_contexts': []
    }
    
    stats = defaultdict(int)
    current_context = []  # Últimas 5 linhas para contexto de rejeição
    
    print(f"\n📂 Processando: {log_file}")
    print("⏳ Lendo arquivo em streaming (pode demorar 30-60s)...\n")
    
    line_count = 0
    last_timestamp = None
    
    try:
        with open(log_file, 'r', encoding='utf-8', errors='ignore') as f:
            for line_num, line in enumerate(f, 1):
                line_count += 1
                
                # Progress a cada 1M linhas
                if line_count % 1_000_000 == 0:
                    print(f"  ✓ Processadas {line_count // 1_000_000}M linhas...")
                
                # Manter contexto (últimas 5 linhas)
                current_context.append(line.strip())
                if len(current_context) > 5:
                    current_context.pop(0)
                
                # Extração de timestamp
                ts_match = re.search(r'\d{4}\.\d{2}\.\d{2}\s+\d{2}:\d{2}:\d{2}', line)
                if ts_match:
                    last_timestamp = ts_match.group()
                
                # Stop Loss calculado
                sl_match = patterns['sl_calc'].search(line)
                if sl_match:
                    sl_val = float(sl_match.group(1))
                    data['sl_values'].append(sl_val)
                    stats['sl_calculations'] += 1
                
                # ATR
                atr_match = patterns['atr_value'].search(line)
                if atr_match:
                    atr_val = float(atr_match.group(1))
                    data['atr_values'].append(atr_val)
                
                # Lote calculado
                lot_match = patterns['lot_size'].search(line)
                if lot_match:
                    lot_val = float(lot_match.group(1))
                    data['lot_sizes'].append(lot_val)
                
                # Margem necessária
                margin_req_match = patterns['margin_req'].search(line)
                if margin_req_match:
                    margin_val = float(margin_req_match.group(1))
                    data['margins_required'].append(margin_val)
                
                # Margem livre
                margin_free_match = patterns['margin_free'].search(line)
                if margin_free_match:
                    margin_val = float(margin_free_match.group(1))
                    data['margins_free'].append(margin_val)
                
                # Distância SL
                sl_dist_match = patterns['sl_distance'].search(line)
                if sl_dist_match:
                    dist_val = float(sl_dist_match.group(1))
                    data['sl_distances'].append(dist_val)
                
                # Risk percent
                risk_match = patterns['risk_calc'].search(line)
                if risk_match:
                    risk_val = float(risk_match.group(1))
                    data['risk_percents'].append(risk_val)
                
                # REJEIÇÕES - CRÍTICO!
                if patterns['rejection'].search(line):
                    stats['rejections'] += 1
                    data['rejections'].append({
                        'line_num': line_num,
                        'timestamp': last_timestamp,
                        'message': line.strip()
                    })
                    
                    # Salvar contexto completo
                    data['rejection_contexts'].append({
                        'rejection_num': stats['rejections'],
                        'timestamp': last_timestamp,
                        'context_lines': current_context.copy()
                    })
                
                # MinFreeMarginPercent
                if patterns['min_margin'].search(line):
                    stats['min_margin_mentions'] += 1
                    # Tentar extrair valor
                    val_match = re.search(r'(\d+\.?\d*)%?', line)
                    if val_match:
                        print(f"\n🔍 ENCONTRADO MinFreeMargin: {line.strip()}")
    
    except Exception as e:
        print(f"\n❌ Erro ao processar log: {e}")
        return None
    
    print(f"\n✅ Processamento concluído: {line_count:,} linhas")
    print("=" * 80)
    
    return data, stats

def analyze_extracted_data(data, stats):
    """
    Analisa dados extraídos e identifica discrepâncias
    """
    
    print("\n" + "=" * 80)
    print("📊 ANÁLISE DOS DADOS EXTRAÍDOS")
    print("=" * 80)
    
    # Estatísticas SL
    if data['sl_values']:
        import numpy as np
        sl_arr = np.array(data['sl_values'])
        
        print(f"\n🎯 STOP LOSS CALCULADO ({len(sl_arr)} valores):")
        print(f"  - Mínimo: {sl_arr.min():.5f}")
        print(f"  - Máximo: {sl_arr.max():.5f}")
        print(f"  - Médio: {sl_arr.mean():.5f}")
        print(f"  - Mediana: {np.median(sl_arr):.5f}")
        print(f"  - StdDev: {sl_arr.std():.5f}")
        
        # Converter para pips (assumindo USDJPY, 1 pip = 0.01)
        sl_pips = sl_arr * 100
        print(f"\n  📏 EM PIPS:")
        print(f"  - SL Mínimo: {sl_pips.min():.1f} pips")
        print(f"  - SL Máximo: {sl_pips.max():.1f} pips")
        print(f"  - SL Médio: {sl_pips.mean():.1f} pips")
        print(f"  - SL Mediana: {np.median(sl_pips):.1f} pips")
    
    # Estatísticas Lote
    if data['lot_sizes']:
        import numpy as np
        lot_arr = np.array(data['lot_sizes'])
        
        print(f"\n💰 LOTES CALCULADOS ({len(lot_arr)} valores):")
        print(f"  - Mínimo: {lot_arr.min():.2f}")
        print(f"  - Máximo: {lot_arr.max():.2f}")
        print(f"  - Médio: {lot_arr.mean():.2f}")
        print(f"  - Mediana: {np.median(lot_arr):.2f}")
    
    # Estatísticas Margem
    if data['margins_required']:
        import numpy as np
        margin_arr = np.array(data['margins_required'])
        
        print(f"\n🏦 MARGEM NECESSÁRIA ({len(margin_arr)} valores):")
        print(f"  - Mínima: ${margin_arr.min():.2f}")
        print(f"  - Máxima: ${margin_arr.max():.2f}")
        print(f"  - Média: ${margin_arr.mean():.2f}")
    
    if data['margins_free']:
        import numpy as np
        free_arr = np.array(data['margins_free'])
        
        print(f"\n💵 MARGEM LIVRE ({len(free_arr)} valores):")
        print(f"  - Mínima: ${free_arr.min():.2f}")
        print(f"  - Máxima: ${free_arr.max():.2f}")
        print(f"  - Média: ${free_arr.mean():.2f}")
        
        # CRÍTICO: Calcular % margem livre
        if data['margins_required']:
            req_arr = np.array(data['margins_required'][:len(free_arr)])
            margin_percent = (free_arr / (free_arr + req_arr)) * 100
            print(f"\n  📊 % MARGEM LIVRE (após ordem):")
            print(f"  - Mínima: {margin_percent.min():.1f}%")
            print(f"  - Máxima: {margin_percent.max():.1f}%")
            print(f"  - Média: {margin_percent.mean():.1f}%")
            
            # Quantos teriam < 30% margem livre?
            below_30 = np.sum(margin_percent < 30)
            print(f"\n  🚨 Abaixo de 30% margem livre: {below_30} ({below_30/len(margin_percent)*100:.1f}%)")
    
    # Rejeições
    print(f"\n❌ REJEIÇÕES IDENTIFICADAS: {stats['rejections']}")
    
    if data['rejection_contexts']:
        print(f"\n📝 PRIMEIRAS 5 REJEIÇÕES (contexto completo):")
        for i, ctx in enumerate(data['rejection_contexts'][:5], 1):
            print(f"\n  [{i}] Timestamp: {ctx['timestamp']}")
            print("  Contexto (últimas 5 linhas antes da rejeição):")
            for line in ctx['context_lines']:
                print(f"    {line}")
    
    print("\n" + "=" * 80)
    
    return

def main():
    log_file = Path("log/20251022.log")
    
    if not log_file.exists():
        print(f"❌ Log não encontrado: {log_file}")
        return
    
    # Extração
    result = extract_critical_data(log_file)
    if not result:
        return
    
    data, stats = result
    
    # Análise
    analyze_extracted_data(data, stats)
    
    # Salvar resultados
    output_file = Path("analysis_output/sl_rejection_data.json")
    output_file.parent.mkdir(parents=True, exist_ok=True)
    
    # Preparar para JSON (converter numpy arrays)
    json_data = {
        'statistics': dict(stats),
        'sl_values': data['sl_values'][:100],  # Primeiros 100
        'lot_sizes': data['lot_sizes'][:100],
        'margins_required': data['margins_required'][:100],
        'margins_free': data['margins_free'][:100],
        'rejections': data['rejections'][:20],  # Primeiras 20
        'rejection_contexts': data['rejection_contexts'][:10]  # Primeiras 10 com contexto
    }
    
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(json_data, f, indent=2, ensure_ascii=False)
    
    print(f"\n💾 Dados salvos em: {output_file}")
    print("=" * 80)

if __name__ == '__main__':
    main()
