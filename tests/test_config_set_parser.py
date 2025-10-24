#!/usr/bin/env python3
"""
Teste rápido do parser v4.34 - Validação CONFIG_SET
"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

from Tools.production_analyzer import TradeReconstructor

def test_config_set_detection():
    print("🔧 Testando detecção de CONFIG_SET no log consolidado...")
    print("=" * 70)
    
    log_file = "log/20251023.log"
    reconstructor = TradeReconstructor(log_file)
    
    # Processar primeiras 100k linhas
    print(f"\n📄 Processando primeiras 100.000 linhas...")
    
    with open(log_file, 'r', encoding='utf-16-le', errors='ignore') as f:
        for i, line in enumerate(f):
            if i >= 100000:
                break
            
            reconstructor._process_line(line)
            
            # Mostrar progresso a cada 10k linhas
            if (i + 1) % 10000 == 0:
                print(f"  ⏳ {i+1:,} linhas | "
                      f"Trades: {len(reconstructor.trades):,} | "
                      f"CONFIG_SET atual: {reconstructor.current_config_set or 'None'}")
    
    trades = list(reconstructor.trades.values())
    
    print(f"\n📊 RESULTADO:")
    print(f"  Total de trades encontrados: {len(trades)}")
    print(f"  CONFIG_SET atual no parser: {reconstructor.current_config_set}")
    
    # Contar por CONFIG_SET
    config_sets = {}
    for trade in trades:
        cs = trade.config_set_name or 'UNKNOWN'
        config_sets[cs] = config_sets.get(cs, 0) + 1
    
    print(f"\n🏷️  DISTRIBUIÇÃO POR CONFIG_SET:")
    print("=" * 70)
    
    for cs in sorted(config_sets.keys()):
        count = config_sets[cs]
        pct = (count / len(trades) * 100) if trades else 0
        bar = "█" * int(pct / 2)
        print(f"  {cs:15} | {count:4} trades ({pct:5.1f}%) {bar}")
    
    # Validação
    print(f"\n✅ VALIDAÇÃO:")
    if config_sets.get('UNKNOWN', 0) == len(trades):
        print("  ⚠️  TODOS os trades estão como UNKNOWN - CONFIG_SET NÃO foi detectado!")
        print("  💡 Verificar formato do log ou pattern do regex")
    elif len(config_sets) > 1:
        print(f"  ✅ CONFIG_SET detectado com sucesso!")
        print(f"  📊 {len(config_sets)} configurações diferentes encontradas")
    else:
        print(f"  ⚠️  Apenas 1 configuração encontrada: {list(config_sets.keys())[0]}")
    
    # Mostrar amostra de trades
    print(f"\n📋 AMOSTRA DE TRADES:")
    print("=" * 70)
    for i, trade in enumerate(list(trades)[:5]):
        print(f"  Trade #{trade.ticket}: "
              f"{trade.trade_type} @ {trade.entry_price:.2f} | "
              f"CONFIG_SET: {trade.config_set_name or 'UNKNOWN'}")

if __name__ == "__main__":
    test_config_set_detection()
