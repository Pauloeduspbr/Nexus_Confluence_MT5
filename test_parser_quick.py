#!/usr/bin/env python3
"""
Quick test do parser corrigido
"""
import sys
sys.path.insert(0, 'Tools')

from production_analyzer import TradeReconstructor
from pathlib import Path

print("🧪 TESTE RÁPIDO - Parser Corrigido v4.34")
print("=" * 60)

log_file = Path("log/20251023.log")
if not log_file.exists():
    print(f"❌ Arquivo não encontrado: {log_file}")
    sys.exit(1)

print(f"📄 Log file: {log_file}")
print(f"💾 Size: {log_file.stat().st_size / (1024*1024):.1f}MB")
print()

print("🔄 Iniciando parsing...")
reconstructor = TradeReconstructor(str(log_file))
trades_list = reconstructor.parse_log_streaming()

print()
print("=" * 60)
print("📊 RESULTADO:")
print(f"  Total de trades: {len(trades_list)}")

# Contar por CONFIG_SET
config_dist = {}
for trade in trades_list:
    config = trade.config_set_name or 'UNKNOWN'
    config_dist[config] = config_dist.get(config, 0) + 1

print()
print("  Distribuição por CONFIG_SET:")
for config_name in sorted(config_dist.keys()):
    count = config_dist[config_name]
    pct = (count / len(trades_list) * 100) if trades_list else 0
    print(f"    - {config_name:20s}: {count:4d} trades ({pct:5.1f}%)")

print()
print("✅ Teste concluído!")

# Validar resultado esperado
expected = {'CONSERVATIVE': 96, 'MODERATE': 96, 'AGGRESSIVE': 816}
print()
print("🎯 VALIDAÇÃO:")
all_ok = True
for config, expected_count in expected.items():
    actual = config_dist.get(config, 0)
    status = "✅" if actual == expected_count else "❌"
    print(f"  {status} {config}: {actual} / {expected_count} esperados")
    if actual != expected_count:
        all_ok = False

if all_ok:
    print()
    print("🎉 SUCESSO! Todos os 1,008 trades detectados corretamente!")
else:
    print()
    print("⚠️  ATENÇÃO: Divergência nos números esperados!")
