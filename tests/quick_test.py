#!/usr/bin/env python3
"""
Teste rápido para validar production_analyzer.py
"""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from Tools.production_analyzer import *
import numpy as np

print("=" * 70)
print("🧪 QUICK TEST - Production Analyzer")
print("=" * 70)

# Test 1: MetricsCalculator
print("\n✅ Test 1: MetricsCalculator")
calc = MetricsCalculator()

# Dados de teste
trades = [
    Trade(ticket=1, symbol="EURUSD", trade_type="BUY", volume=0.1, 
          entry_price=1.1000, close_price=1.1050, 
          profit=50, initial_sl=1.0950,
          open_time=datetime.now(), close_time=datetime.now(), is_closed=True),
    Trade(ticket=2, symbol="EURUSD", trade_type="SELL", volume=0.1,
          entry_price=1.1000, close_price=1.1020,
          profit=-20, initial_sl=1.1050,
          open_time=datetime.now(), close_time=datetime.now(), is_closed=True),
]

metrics = calc.calculate_all_metrics(trades)
print(f"   Win Rate: {metrics.win_rate:.1f}%")
print(f"   Profit Factor: {metrics.profit_factor:.2f}")
print(f"   Expectancy R: {metrics.expectancy_r:.2f}R")
assert metrics.win_rate == 50.0, "Win rate should be 50%"
assert metrics.total_trades == 2, "Should have 2 trades"
print("   ✅ PASSED")

# Test 2: BootstrapAnalyzer
print("\n✅ Test 2: BootstrapAnalyzer")
analyzer = BootstrapAnalyzer(seed=42)
data = np.array([1.0, 2.0, 3.0, 4.0, 5.0])
result = analyzer.bootstrap_metric(data, lambda x: np.mean(x), n_iterations=100)
print(f"   Point Estimate: {result.point_estimate:.2f}")
print(f"   CI 95%: [{result.ci_lower:.2f}, {result.ci_upper:.2f}]")
assert 2.5 <= result.point_estimate <= 3.5, "Mean should be around 3"
print("   ✅ PASSED")

# Test 3: Reprodutibilidade
print("\n✅ Test 3: Reprodutibilidade do Bootstrap")
analyzer1 = BootstrapAnalyzer(seed=42)
analyzer2 = BootstrapAnalyzer(seed=42)
result1 = analyzer1.bootstrap_metric(data, lambda x: np.mean(x), n_iterations=100)
result2 = analyzer2.bootstrap_metric(data, lambda x: np.mean(x), n_iterations=100)
print(f"   Result 1: {result1.point_estimate:.6f}")
print(f"   Result 2: {result2.point_estimate:.6f}")
assert abs(result1.point_estimate - result2.point_estimate) < 0.0001, "Should be identical"
assert abs(result1.ci_lower - result2.ci_lower) < 0.0001, "CI lower should be identical"
assert abs(result1.ci_upper - result2.ci_upper) < 0.0001, "CI upper should be identical"
print("   ✅ PASSED")

# Test 4: HypothesisTests  
print("\n✅ Test 4: HypothesisTests")
tester = HypothesisTests()
# Usar diferença maior para ter significância estatística
set1 = [1.0, 1.5, 2.0, 2.5, 3.0]
set2 = [5.0, 5.5, 6.0, 6.5, 7.0]
result = tester.compare_two_sets(set1, set2, "Set1", "Set2")
print(f"   Winner: {result['winner']}")
print(f"   P-value: {result['p_value']:.4f}")
print(f"   Effect Size: {result['effect_size']:.4f}")
assert result['winner'] == "Set2", "Set2 should have higher mean"
assert result['p_value'] < 0.05, "Should be statistically significant"
print("   ✅ PASSED")

print("\n" + "=" * 70)
print("✅ ALL QUICK TESTS PASSED!")
print("=" * 70)
