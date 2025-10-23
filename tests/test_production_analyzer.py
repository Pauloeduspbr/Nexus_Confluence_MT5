#!/usr/bin/env python3
"""
🧪 TESTES UNIT

ÁRIOS - Production Analyzer
==========================================
Testes completos para validação do sistema

Autor: Nexus Confluence Test Suite
Data: 23 de Outubro de 2025
"""

import sys
import os
import unittest
import numpy as np
from datetime import datetime
from pathlib import Path

# Adicionar diretório Tools ao path
sys.path.insert(0, str(Path(__file__).parent.parent / 'Tools'))

from production_analyzer import (
    Trade, PerformanceMetrics, BootstrapResult,
    TradeReconstructor, MetricsCalculator, BootstrapAnalyzer, HypothesisTests
)


class TestMetricsCalculator(unittest.TestCase):
    """Testes para MetricsCalculator"""
    
    def setUp(self):
        """Setup para cada teste"""
        # Criar trades sintéticos
        self.trades = []
        
        # 5 trades vencedores
        for i in range(5):
            trade = Trade(
                ticket=i,
                symbol='EURUSD',
                trade_type='BUY',
                open_time=datetime.now(),
                entry_price=1.1000,
                initial_sl=1.0980,
                volume=0.1,
                is_closed=True,
                close_price=1.1020,
                profit=20.0,
                r_multiple=1.0
            )
            self.trades.append(trade)
        
        # 3 trades perdedores
        for i in range(5, 8):
            trade = Trade(
                ticket=i,
                symbol='EURUSD',
                trade_type='BUY',
                open_time=datetime.now(),
                entry_price=1.1000,
                initial_sl=1.0980,
                volume=0.1,
                is_closed=True,
                close_price=1.0990,
                profit=-10.0,
                r_multiple=-0.5
            )
            self.trades.append(trade)
    
    def test_basic_metrics(self):
        """Testa métricas básicas"""
        metrics = MetricsCalculator.calculate_all_metrics(self.trades)
        
        self.assertEqual(metrics.total_trades, 8)
        self.assertEqual(metrics.winning_trades, 5)
        self.assertEqual(metrics.losing_trades, 3)
        self.assertAlmostEqual(metrics.win_rate, 62.5, places=1)
    
    def test_profit_metrics(self):
        """Testa métricas de lucro"""
        metrics = MetricsCalculator.calculate_all_metrics(self.trades)
        
        self.assertAlmostEqual(metrics.total_profit, 100.0, places=1)
        self.assertAlmostEqual(metrics.total_loss, 30.0, places=1)
        self.assertAlmostEqual(metrics.profit_factor, 3.33, places=2)
    
    def test_expectancy(self):
        """Testa expectância"""
        metrics = MetricsCalculator.calculate_all_metrics(self.trades)
        
        # Expectancy = (5*20 + 3*(-10)) / 8 = 70/8 = 8.75
        self.assertAlmostEqual(metrics.expectancy, 8.75, places=2)
    
    def test_r_multiples(self):
        """Testa R-múltiplos"""
        metrics = MetricsCalculator.calculate_all_metrics(self.trades)
        
        self.assertIsNotNone(metrics.r_mean)
        self.assertIsNotNone(metrics.r_median)
        self.assertGreater(metrics.r_mean, 0)
    
    def test_sharpe_ratio(self):
        """Testa Sharpe Ratio"""
        returns = [20, 20, 20, 20, 20, -10, -10, -10]
        sharpe = MetricsCalculator.calculate_sharpe_ratio(returns)
        
        self.assertGreater(sharpe, 0)
        self.assertIsInstance(sharpe, float)
    
    def test_sortino_ratio(self):
        """Testa Sortino Ratio"""
        returns = [20, 20, 20, 20, 20, -10, -10, -10]
        sortino = MetricsCalculator.calculate_sortino_ratio(returns)
        
        self.assertGreater(sortino, 0)
        self.assertIsInstance(sortino, float)
    
    def test_var_es(self):
        """Testa VaR e ES"""
        returns = list(range(-50, 51))  # -50 a 50
        var, es = MetricsCalculator.calculate_var_es(returns, confidence=0.95)
        
        self.assertLess(var, 0)  # VaR deve ser negativo
        self.assertLess(es, var)  # ES deve ser pior que VaR
    
    def test_drawdown(self):
        """Testa cálculo de drawdown"""
        returns = [10, -5, -3, -2, 15, -8]
        max_dd, max_dd_pct, avg_dd = MetricsCalculator.calculate_drawdown(returns)
        
        self.assertGreater(max_dd, 0)
        self.assertGreater(max_dd_pct, 0)
        self.assertGreater(avg_dd, 0)


class TestBootstrapAnalyzer(unittest.TestCase):
    """Testes para BootstrapAnalyzer"""
    
    def setUp(self):
        """Setup para cada teste"""
        self.analyzer = BootstrapAnalyzer(seed=42)
        self.data = np.random.normal(loc=10, scale=5, size=100)
    
    def test_bootstrap_mean(self):
        """Testa bootstrap da média"""
        result = self.analyzer.bootstrap_metric(
            self.data,
            lambda x: np.mean(x),
            n_iterations=1000,
            confidence=0.95
        )
        
        self.assertIsInstance(result, BootstrapResult)
        self.assertGreater(result.ci_upper, result.ci_lower)
        self.assertGreater(result.ci_upper, result.point_estimate)
        self.assertLess(result.ci_lower, result.point_estimate)
    
    def test_bootstrap_std(self):
        """Testa bootstrap do desvio padrão"""
        result = self.analyzer.bootstrap_metric(
            self.data,
            lambda x: np.std(x, ddof=1),
            n_iterations=1000,
            confidence=0.95
        )
        
        self.assertGreater(result.point_estimate, 0)
        self.assertGreater(result.std_error, 0)
    
    def test_bootstrap_reproducibility(self):
        """Testa reprodutibilidade com mesma seed"""
        analyzer1 = BootstrapAnalyzer(seed=42)
        analyzer2 = BootstrapAnalyzer(seed=42)
        
        result1 = analyzer1.bootstrap_metric(self.data, lambda x: np.mean(x), n_iterations=100)
        result2 = analyzer2.bootstrap_metric(self.data, lambda x: np.mean(x), n_iterations=100)
        
        self.assertAlmostEqual(result1.point_estimate, result2.point_estimate, places=5)


class TestHypothesisTests(unittest.TestCase):
    """Testes para HypothesisTests"""
    
    def test_compare_identical_sets(self):
        """Testa comparação de sets idênticos"""
        set1 = [10, 12, 8, 15, 11]
        set2 = [10, 12, 8, 15, 11]
        
        result = HypothesisTests.compare_two_sets(set1, set2, "Set1", "Set2")
        
        self.assertEqual(result['winner'], 'tie')
        self.assertGreater(result['p_value'], 0.05)
    
    def test_compare_different_sets(self):
        """Testa comparação de sets diferentes"""
        set1 = [20, 22, 18, 25, 21]  # Média ~21
        set2 = [5, 7, 3, 10, 6]       # Média ~6
        
        result = HypothesisTests.compare_two_sets(set1, set2, "Set1", "Set2")
        
        self.assertEqual(result['winner'], 'Set1')
        self.assertLess(result['p_value'], 0.05)
        self.assertGreater(result['delta_expectancy'], 0)
    
    def test_effect_size(self):
        """Testa cálculo de effect size"""
        set1 = [20, 22, 18, 25, 21]
        set2 = [5, 7, 3, 10, 6]
        
        result = HypothesisTests.compare_two_sets(set1, set2, "Set1", "Set2")
        
        self.assertIsNotNone(result['effect_size'])
        self.assertGreater(abs(result['effect_size']), 0)


class TestTradeReconstruction(unittest.TestCase):
    """Testes para reconstrução de trades"""
    
    def test_trade_creation(self):
        """Testa criação de trade"""
        trade = Trade(
            ticket=12345,
            symbol='EURUSD',
            trade_type='BUY',
            open_time=datetime.now(),
            entry_price=1.1000,
            initial_sl=1.0980,
            volume=0.1
        )
        
        self.assertEqual(trade.ticket, 12345)
        self.assertEqual(trade.symbol, 'EURUSD')
        self.assertEqual(trade.trade_type, 'BUY')
        self.assertFalse(trade.is_closed)
    
    def test_trade_close(self):
        """Testa fechamento de trade"""
        trade = Trade(
            ticket=12345,
            symbol='EURUSD',
            trade_type='BUY',
            open_time=datetime(2025, 10, 23, 10, 0, 0),
            entry_price=1.1000,
            initial_sl=1.0980,
            volume=0.1,
            is_closed=True,
            close_time=datetime(2025, 10, 23, 11, 30, 0),
            close_price=1.1020,
            profit=20.0
        )
        
        self.assertTrue(trade.is_closed)
        self.assertEqual(trade.profit, 20.0)
    
    def test_r_multiple_calculation(self):
        """Testa cálculo de R-multiple"""
        # BUY trade com lucro de 1R
        entry = 1.1000
        sl = 1.0980
        exit_price = 1.1020
        
        risk = abs(entry - sl)  # 0.0020
        profit_pips = exit_price - entry  # 0.0020
        r_multiple = profit_pips / risk  # 1.0
        
        self.assertAlmostEqual(r_multiple, 1.0, places=2)


class TestIntegration(unittest.TestCase):
    """Testes de integração"""
    
    def test_full_workflow(self):
        """Testa workflow completo com dados sintéticos"""
        # Criar trades
        trades = []
        for i in range(20):
            profit = np.random.normal(10, 20)
            trade = Trade(
                ticket=i,
                symbol='EURUSD',
                trade_type='BUY',
                open_time=datetime.now(),
                entry_price=1.1000,
                initial_sl=1.0980,
                volume=0.1,
                is_closed=True,
                close_price=1.1000 + profit/10000,
                profit=profit,
                r_multiple=profit/20
            )
            trades.append(trade)
        
        # Calcular métricas
        metrics = MetricsCalculator.calculate_all_metrics(trades)
        
        # Validações
        self.assertEqual(metrics.total_trades, 20)
        self.assertIsNotNone(metrics.win_rate)
        self.assertIsNotNone(metrics.expectancy)
        self.assertIsNotNone(metrics.sharpe_ratio)
        
        # Bootstrap
        bootstrap = BootstrapAnalyzer(seed=42)
        bootstrap_results = bootstrap.bootstrap_all_metrics(trades)
        
        self.assertIn('win_rate', bootstrap_results)
        self.assertIn('expectancy', bootstrap_results)
        self.assertIn('sharpe', bootstrap_results)


def run_tests():
    """Executa todos os testes"""
    print("=" * 70)
    print("🧪 RUNNING UNIT TESTS - Production Analyzer")
    print("=" * 70)
    print()
    
    # Criar test suite
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    
    # Adicionar todos os testes
    suite.addTests(loader.loadTestsFromTestCase(TestMetricsCalculator))
    suite.addTests(loader.loadTestsFromTestCase(TestBootstrapAnalyzer))
    suite.addTests(loader.loadTestsFromTestCase(TestHypothesisTests))
    suite.addTests(loader.loadTestsFromTestCase(TestTradeReconstruction))
    suite.addTests(loader.loadTestsFromTestCase(TestIntegration))
    
    # Executar testes
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    print()
    print("=" * 70)
    if result.wasSuccessful():
        print("✅ ALL TESTS PASSED!")
    else:
        print("❌ SOME TESTS FAILED!")
    print("=" * 70)
    print(f"Tests run: {result.testsRun}")
    print(f"Failures: {len(result.failures)}")
    print(f"Errors: {len(result.errors)}")
    
    return result.wasSuccessful()


if __name__ == '__main__':
    success = run_tests()
    sys.exit(0 if success else 1)
