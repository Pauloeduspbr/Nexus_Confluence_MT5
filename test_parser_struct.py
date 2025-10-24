#!/usr/bin/env python3
"""
Teste ultra-rápido: valida apenas que a estrutura está OK
Processa só 100k linhas para verificar se não há erros
"""
import sys
sys.path.insert(0, 'Tools')

from production_analyzer import TradeReconstructor
from pathlib import Path

print("🧪 TESTE ULTRA-RÁPIDO - Validação Estrutural")
print("=" * 60)

log_file = Path("log/20251023.log")

print(f"📄 Testando: {log_file.name}")
print(f"🎯 Objetivo: Validar que chaves compostas funcionam")
print()

print("🔄 Criando reconstructor...")
reconstructor = TradeReconstructor(str(log_file))

print(f"  ✅ Instância criada")
print(f"  ✅ self.trades inicializado: {type(reconstructor.trades)}")
print(f"  ✅ self.open_positions inicializado: {type(reconstructor.open_positions)}")
print(f"  ✅ self.current_config_set: {reconstructor.current_config_set}")
print(f"  ✅ self.patterns contém {len(reconstructor.patterns)} regex")

# Testar método _get_trade_key
print()
print("🧪 Testando _get_trade_key():")
reconstructor.current_config_set = "CONSERVATIVE"
key1 = reconstructor._get_trade_key(123)
print(f"  CONFIG=CONSERVATIVE, ticket=123 → '{key1}'")

reconstructor.current_config_set = "AGGRESSIVE"
key2 = reconstructor._get_trade_key(123)
print(f"  CONFIG=AGGRESSIVE, ticket=123 → '{key2}'")

if key1 != key2:
    print(f"  ✅ Chaves diferentes! ({key1} != {key2})")
else:
    print(f"  ❌ ERRO: Chaves iguais!")
    sys.exit(1)

# Processar algumas linhas para garantir que não há erros
print()
print("🔄 Processando primeiras linhas do log...")
count = 0
with open(log_file, 'r', encoding='utf-16-le', errors='ignore') as f:
    for i, line in enumerate(f):
        try:
            reconstructor._process_line(line)
            count = i + 1
            if i >= 100000:  # Processar só 100k linhas
                break
        except Exception as e:
            print(f"  ❌ ERRO na linha {i}: {e}")
            sys.exit(1)

print(f"  ✅ Processadas {count:,} linhas sem erros")
print(f"  📊 Trades detectados: {len(reconstructor.trades)}")
print(f"  🔓 Posições abertas: {len(reconstructor.open_positions)}")

# Mostrar algumas chaves
if reconstructor.trades:
    print()
    print("  🔑 Exemplos de chaves geradas:")
    for i, key in enumerate(list(reconstructor.trades.keys())[:5]):
        trade = reconstructor.trades[key]
        print(f"     {i+1}. '{key}' → ticket={trade.ticket}, config={trade.config_set_name}")

print()
print("=" * 60)
print("✅ TESTE ESTRUTURAL PASSOU!")
print("   Código compilou, classes inicializaram, métodos funcionam!")
print("=" * 60)
