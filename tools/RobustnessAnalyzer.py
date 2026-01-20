#!/usr/bin/env python3
"""
RobustnessAnalyzer.py - Robustness Testing for MT5 EAs

Features:
- Walk-Forward Analysis (WFA) with IS/OOS windows
- Walk-Forward Matrix (WFM) for parameter sweet spots
- Monte Carlo Monkey Test to compare vs randomness
- 5-Whys Robustness Diagnostic
- Integration with BacktestAnalyzerV2
- Auto-generate robust preset

Usage:
    python3 RobustnessAnalyzer.py log/20260120.log --preset Presets/current.set
    python3 RobustnessAnalyzer.py --help
"""

import re
import sys
import json
import math
import random
import argparse
from pathlib import Path
from dataclasses import dataclass, field, asdict
from typing import Optional, List, Dict, Tuple, Any
from datetime import datetime, timedelta
from collections import defaultdict
import statistics

# Import BacktestAnalyzerV2 if available
try:
    from BacktestAnalyzerV2 import BacktestAnalyzerV2, Trade, BacktestMetrics
    HAS_ANALYZER = True
except ImportError:
    HAS_ANALYZER = False


@dataclass
class WFAResult:
    """Result of a single Walk-Forward Analysis run."""
    run_id: int
    is_start: datetime
    is_end: datetime
    oos_start: datetime
    oos_end: datetime
    net_profit_is: float
    net_profit_oos: float
    wfe: float  # Walk-Forward Efficiency
    profit_factor_oos: float
    sharpe_oos: float
    max_drawdown_oos: float
    sqn_oos: float
    passed: bool


@dataclass
class WFMCell:
    """Single cell in Walk-Forward Matrix."""
    is_months: int
    oos_months: int
    avg_wfe: float
    avg_pf: float
    pass_rate: float
    is_sweet_spot: bool = False


@dataclass
class MonkeyTestResult:
    """Result of Monte Carlo Monkey Test."""
    num_simulations: int
    ea_profit: float
    ea_percentile: float  # Percentile vs random (target >95%)
    mean_random_profit: float
    std_random_profit: float
    z_score: float  # (EA - Mean) / StdDev (target >2)
    p_value: float  # KS test p-value (target <0.05)
    is_robust: bool


@dataclass
class RobustnessReport:
    """Complete robustness analysis report."""
    symbol: str = ""
    timeframe: str = ""
    analysis_date: str = ""
    
    # WFA Results
    wfa_runs: int = 0
    wfa_avg_wfe: float = 0.0
    wfa_pass_rate: float = 0.0
    wfa_results: List[WFAResult] = field(default_factory=list)
    
    # WFM Results
    wfm_best_is: int = 0
    wfm_best_oos: int = 0
    wfm_matrix: List[WFMCell] = field(default_factory=list)
    
    # Monkey Test Results
    monkey_result: Optional[MonkeyTestResult] = None
    
    # 5-Whys
    robustness_issues: List[Dict] = field(default_factory=list)
    
    # Recommendations
    is_robust: bool = False
    confidence_score: float = 0.0
    recommendations: List[str] = field(default_factory=list)


class RobustnessAnalyzer:
    """
    Robustness testing engine for MT5 EA backtests.
    
    Works with trade data from BacktestAnalyzerV2 to perform:
    - Walk-Forward Analysis (WFA)
    - Walk-Forward Matrix (WFM)
    - Monte Carlo Monkey Test
    """
    
    # Parameter ranges for Monte Carlo
    PARAM_RANGES = {
        'InpStopLossBuy': (200, 800),
        'InpStopLossSell': (200, 800),
        'InpTakeProfitBuy': (400, 2500),
        'InpTakeProfitSell': (400, 2500),
        'InpBE_Buy_Trigger': (100, 700),
        'InpBE_Sell_Trigger': (100, 700),
        'InpBE_Buy_Step': (5, 150),
        'InpBE_Sell_Step': (5, 150),
        'InpTS_Buy_Trigger': (200, 800),
        'InpTS_Sell_Trigger': (200, 800),
        'InpMinScoreBuy': (1, 5),
        'InpMinScoreSell': (1, 5),
        'InpLotSize': (0.01, 0.10),
    }
    
    # Thresholds for robustness
    MIN_WFE = 70.0  # Walk-Forward Efficiency minimum
    MIN_SHARPE = 0.8
    MIN_SQN = 2.5
    MAX_DD = 30.0
    MIN_PF = 1.5
    MIN_MONKEY_PERCENTILE = 95.0
    MIN_Z_SCORE = 2.0
    
    def __init__(self, trades: List, inputs: Dict, metrics: Any, 
                 preset_path: str = None, verbose: bool = True):
        """
        Initialize RobustnessAnalyzer.
        
        Args:
            trades: List of Trade objects from BacktestAnalyzerV2
            inputs: Dict of EA input parameters
            metrics: BacktestMetrics object
            preset_path: Path to current preset file
            verbose: Print progress messages
        """
        self.trades = trades
        self.inputs = inputs
        self.metrics = metrics
        self.preset_path = Path(preset_path) if preset_path else None
        self.verbose = verbose
        
        self.report = RobustnessReport()
        
        # Sort trades by time
        if trades:
            self.trades = sorted(trades, key=lambda t: t.entry_time)
            self.start_date = self.trades[0].entry_time
            self.end_date = self.trades[-1].entry_time
            self.total_days = (self.end_date - self.start_date).days
        else:
            self.start_date = None
            self.end_date = None
            self.total_days = 0
    
    def log(self, msg: str):
        if self.verbose:
            print(f"[ROBUSTNESS] {msg}")
    
    # =========================================================================
    # WALK-FORWARD ANALYSIS (WFA)
    # =========================================================================
    
    def run_wfa(self, is_ratio: float = 0.7, num_runs: int = 10) -> List[WFAResult]:
        """
        Run Walk-Forward Analysis with sliding windows.
        
        Args:
            is_ratio: Ratio of data for In-Sample (0.7 = 70%)
            num_runs: Number of sliding windows
        
        Returns:
            List of WFAResult objects
        """
        self.log(f"Running WFA with {num_runs} runs, IS={is_ratio*100:.0f}%...")
        
        if not self.trades or len(self.trades) < 50:
            self.log("Not enough trades for WFA (need 50+)")
            return []
        
        results = []
        trades_per_window = len(self.trades) // num_runs
        is_size = int(trades_per_window * is_ratio)
        oos_size = trades_per_window - is_size
        
        if is_size < 20 or oos_size < 10:
            self.log(f"Window too small: IS={is_size}, OOS={oos_size} trades")
            return []
        
        for run_id in range(num_runs):
            start_idx = run_id * trades_per_window
            is_end_idx = start_idx + is_size
            oos_end_idx = start_idx + trades_per_window
            
            if oos_end_idx > len(self.trades):
                break
            
            is_trades = self.trades[start_idx:is_end_idx]
            oos_trades = self.trades[is_end_idx:oos_end_idx]
            
            # Calculate IS metrics
            is_profit = sum(t.profit for t in is_trades)
            
            # Calculate OOS metrics
            oos_profits = [t.profit for t in oos_trades]
            oos_net_profit = sum(oos_profits)
            oos_pf = self._calc_profit_factor(oos_profits)
            oos_sharpe = self._calc_sharpe(oos_profits)
            oos_dd = self._calc_max_dd(oos_profits)
            oos_sqn = self._calc_sqn(oos_profits)
            
            # Walk-Forward Efficiency
            wfe = (oos_net_profit / is_profit * 100) if is_profit > 0 else 0
            
            # Check if passed thresholds
            passed = (
                wfe >= self.MIN_WFE and
                oos_sharpe >= self.MIN_SHARPE and
                oos_dd <= self.MAX_DD
            )
            
            result = WFAResult(
                run_id=run_id,
                is_start=is_trades[0].entry_time,
                is_end=is_trades[-1].entry_time,
                oos_start=oos_trades[0].entry_time,
                oos_end=oos_trades[-1].entry_time,
                net_profit_is=is_profit,
                net_profit_oos=oos_net_profit,
                wfe=wfe,
                profit_factor_oos=oos_pf,
                sharpe_oos=oos_sharpe,
                max_drawdown_oos=oos_dd,
                sqn_oos=oos_sqn,
                passed=passed
            )
            results.append(result)
        
        # Update report
        self.report.wfa_runs = len(results)
        self.report.wfa_results = results
        if results:
            self.report.wfa_avg_wfe = statistics.mean(r.wfe for r in results)
            self.report.wfa_pass_rate = sum(1 for r in results if r.passed) / len(results) * 100
        
        self.log(f"WFA Complete: {len(results)} runs, Avg WFE={self.report.wfa_avg_wfe:.1f}%, Pass Rate={self.report.wfa_pass_rate:.0f}%")
        
        return results
    
    def run_wfm(self, grid_size: int = 5) -> List[WFMCell]:
        """
        Run Walk-Forward Matrix with varying IS/OOS sizes.
        
        Args:
            grid_size: Size of the matrix (5 = 5x5)
        
        Returns:
            List of WFMCell results
        """
        self.log(f"Running WFM with {grid_size}x{grid_size} matrix...")
        
        if not self.trades or len(self.trades) < 100:
            self.log("Not enough trades for WFM (need 100+)")
            return []
        
        # Define IS/OOS ratios to test
        is_ratios = [0.5, 0.6, 0.7, 0.8, 0.9][:grid_size]
        
        matrix = []
        best_wfe = 0
        best_cell = None
        
        for is_idx, is_ratio in enumerate(is_ratios):
            for oos_idx in range(grid_size):
                # Vary number of runs
                num_runs = 5 + oos_idx * 2  # 5, 7, 9, 11, 13
                
                wfa_results = self._mini_wfa(is_ratio, num_runs)
                
                if wfa_results:
                    avg_wfe = statistics.mean(r.wfe for r in wfa_results)
                    avg_pf = statistics.mean(r.profit_factor_oos for r in wfa_results)
                    pass_rate = sum(1 for r in wfa_results if r.passed) / len(wfa_results) * 100
                else:
                    avg_wfe = 0
                    avg_pf = 0
                    pass_rate = 0
                
                cell = WFMCell(
                    is_months=int(is_ratio * 100),  # As percentage
                    oos_months=100 - int(is_ratio * 100),
                    avg_wfe=avg_wfe,
                    avg_pf=avg_pf,
                    pass_rate=pass_rate
                )
                
                if avg_wfe > best_wfe:
                    best_wfe = avg_wfe
                    best_cell = cell
                
                matrix.append(cell)
        
        # Mark sweet spot
        if best_cell:
            best_cell.is_sweet_spot = True
            self.report.wfm_best_is = best_cell.is_months
            self.report.wfm_best_oos = best_cell.oos_months
        
        self.report.wfm_matrix = matrix
        
        self.log(f"WFM Complete: Best IS={self.report.wfm_best_is}%, OOS={self.report.wfm_best_oos}%")
        
        return matrix
    
    def _mini_wfa(self, is_ratio: float, num_runs: int) -> List[WFAResult]:
        """Run a mini WFA for WFM cell calculation."""
        results = []
        trades_per_window = len(self.trades) // num_runs
        is_size = int(trades_per_window * is_ratio)
        oos_size = trades_per_window - is_size
        
        if is_size < 10 or oos_size < 5:
            return []
        
        for run_id in range(num_runs):
            start_idx = run_id * trades_per_window
            is_end_idx = start_idx + is_size
            oos_end_idx = start_idx + trades_per_window
            
            if oos_end_idx > len(self.trades):
                break
            
            is_trades = self.trades[start_idx:is_end_idx]
            oos_trades = self.trades[is_end_idx:oos_end_idx]
            
            is_profit = sum(t.profit for t in is_trades)
            oos_profits = [t.profit for t in oos_trades]
            oos_net_profit = sum(oos_profits)
            
            wfe = (oos_net_profit / is_profit * 100) if is_profit > 0 else 0
            
            result = WFAResult(
                run_id=run_id,
                is_start=is_trades[0].entry_time,
                is_end=is_trades[-1].entry_time,
                oos_start=oos_trades[0].entry_time,
                oos_end=oos_trades[-1].entry_time,
                net_profit_is=is_profit,
                net_profit_oos=oos_net_profit,
                wfe=wfe,
                profit_factor_oos=self._calc_profit_factor(oos_profits),
                sharpe_oos=self._calc_sharpe(oos_profits),
                max_drawdown_oos=self._calc_max_dd(oos_profits),
                sqn_oos=self._calc_sqn(oos_profits),
                passed=wfe >= self.MIN_WFE
            )
            results.append(result)
        
        return results
    
    # =========================================================================
    # MONTE CARLO MONKEY TEST
    # =========================================================================
    
    def run_monkey_test(self, num_simulations: int = 5000) -> MonkeyTestResult:
        """
        Run Monte Carlo Monkey Test to compare EA vs random.
        
        Generates random parameter configurations and simulates trades
        to create a null hypothesis distribution.
        
        Args:
            num_simulations: Number of random configurations to test
        
        Returns:
            MonkeyTestResult with percentile and p-value
        """
        self.log(f"Running Monkey Test with {num_simulations} simulations...")
        
        if not self.trades or len(self.trades) < 30:
            self.log("Not enough trades for Monkey Test (need 30+)")
            return MonkeyTestResult(
                num_simulations=0, ea_profit=0, ea_percentile=0,
                mean_random_profit=0, std_random_profit=0,
                z_score=0, p_value=1.0, is_robust=False
            )
        
        # EA's actual performance
        ea_profit = sum(t.profit for t in self.trades)
        ea_profits = [t.profit for t in self.trades]
        
        # Generate random results by shuffling trade outcomes
        random_profits = []
        random.seed(42)  # Reproducibility
        
        for _ in range(num_simulations):
            # Simulate by:
            # 1. Randomly scaling profits (simulating parameter variation)
            # 2. Randomly shuffling trade order
            # 3. Randomly flipping some trade directions
            
            simulated = []
            for t in self.trades:
                # Random factor between 0.3 and 2.0 (simulating param variation)
                scale = random.uniform(0.3, 2.0)
                # Random sign flip (10% chance)
                sign = -1 if random.random() < 0.1 else 1
                simulated.append(t.profit * scale * sign)
            
            random.shuffle(simulated)
            random_profits.append(sum(simulated))
        
        # Calculate statistics
        mean_random = statistics.mean(random_profits)
        std_random = statistics.stdev(random_profits) if len(random_profits) > 1 else 1.0
        
        # Percentile of EA in random distribution
        count_below = sum(1 for rp in random_profits if rp < ea_profit)
        ea_percentile = (count_below / num_simulations) * 100
        
        # Z-score
        z_score = (ea_profit - mean_random) / std_random if std_random > 0 else 0
        
        # Approximate p-value from z-score (one-tailed)
        # Using simplified calculation
        if z_score >= 2.0:
            p_value = max(0.001, 0.05 - (z_score - 2) * 0.02)
        elif z_score >= 1.0:
            p_value = 0.16 - (z_score - 1) * 0.11
        else:
            p_value = 0.5 - z_score * 0.34
        p_value = max(0.001, min(1.0, p_value))
        
        # Is it robust?
        is_robust = (
            ea_percentile >= self.MIN_MONKEY_PERCENTILE and
            z_score >= self.MIN_Z_SCORE
        )
        
        result = MonkeyTestResult(
            num_simulations=num_simulations,
            ea_profit=ea_profit,
            ea_percentile=ea_percentile,
            mean_random_profit=mean_random,
            std_random_profit=std_random,
            z_score=z_score,
            p_value=p_value,
            is_robust=is_robust
        )
        
        self.report.monkey_result = result
        
        self.log(f"Monkey Test Complete: EA Percentile={ea_percentile:.1f}%, Z-Score={z_score:.2f}, p={p_value:.4f}")
        
        return result
    
    # =========================================================================
    # 5-WHYS ROBUSTNESS DIAGNOSTIC
    # =========================================================================
    
    def apply_five_whys(self) -> List[Dict]:
        """Apply 5-Whys analysis to robustness issues."""
        self.log("Applying 5-Whys Robustness Analysis...")
        
        issues = []
        
        # Issue 1: Low WFE
        if self.report.wfa_avg_wfe < self.MIN_WFE:
            issues.append({
                "problem": f"WFE Baixo: {self.report.wfa_avg_wfe:.1f}% (mínimo {self.MIN_WFE}%)",
                "severity": "CRITICAL",
                "category": "OVERFITTING",
                "whys": [
                    "Por quê? Performance OOS muito inferior a IS",
                    "Por quê? Parâmetros muito ajustados aos dados históricos",
                    "Por quê? Otimização excessiva (curve-fitting)",
                    "Por quê? Falta de validação forward",
                    "Por quê? Não foi usado WFA durante desenvolvimento"
                ],
                "recommendation": "REDUZIR complexidade do EA, usar menos indicadores, ou parâmetros mais conservadores"
            })
        
        # Issue 2: Failed Monkey Test
        if self.report.monkey_result and not self.report.monkey_result.is_robust:
            issues.append({
                "problem": f"Falha no Monkey Test: Percentile={self.report.monkey_result.ea_percentile:.1f}%",
                "severity": "CRITICAL",
                "category": "RANDOMNESS",
                "whys": [
                    "Por quê? EA não supera configurações aleatórias",
                    "Por quê? Lógica de entrada não tem edge estatístico",
                    "Por quê? Confluência de indicadores pode ser ruído",
                    "Por quê? Sinais não são baseados em padrões reais",
                    "Por quê? Estratégia pode ser equivalente a random"
                ],
                "recommendation": "REVISAR lógica de entrada, validar edge estatístico de cada indicador"
            })
        
        # Issue 3: Low Pass Rate in WFA
        if self.report.wfa_pass_rate < 50:
            issues.append({
                "problem": f"Taxa de Aprovação WFA: {self.report.wfa_pass_rate:.0f}% (mínimo 50%)",
                "severity": "WARNING",
                "category": "CONSISTENCY",
                "whys": [
                    "Por quê? Menos de metade das janelas passaram",
                    "Por quê? Performance inconsistente ao longo do tempo",
                    "Por quê? Estratégia sensível a regime de mercado",
                    "Por quê? Falta de adaptação a condições variadas",
                    "Por quê? Parâmetros fixos não funcionam em todos regimes"
                ],
                "recommendation": "IMPLEMENTAR filtro de regime ou adaptar parâmetros dinamicamente"
            })
        
        # Issue 4: SQN Issues
        if self.report.wfa_results:
            avg_sqn = statistics.mean(r.sqn_oos for r in self.report.wfa_results)
            if avg_sqn < self.MIN_SQN:
                issues.append({
                    "problem": f"SQN Baixo: {avg_sqn:.2f} (mínimo {self.MIN_SQN})",
                    "severity": "WARNING",
                    "category": "QUALITY",
                    "whys": [
                        "Por quê? System Quality Number indica baixa qualidade",
                        "Por quê? Alta variância nos resultados dos trades",
                        "Por quê? Expectancy não é consistente",
                        "Por quê? Trades têm resultados muito dispersos",
                        "Por quê? Falta de disciplina na execução ou parâmetros ruins"
                    ],
                    "recommendation": "MELHORAR consistência: filtros mais rigorosos ou targets mais conservadores"
                })
        
        self.report.robustness_issues = issues
        
        return issues
    
    # =========================================================================
    # ROBUST PRESET GENERATION
    # =========================================================================
    
    def generate_robust_preset(self, output_dir: str = "Presets") -> Optional[str]:
        """Generate a preset with robustness-validated parameters."""
        self.log("Generating robust preset...")
        
        if not self.preset_path or not self.preset_path.exists():
            self.log("No base preset found")
            return None
        
        # Read current preset
        params = self._read_preset(self.preset_path)
        if not params:
            return None
        
        changes = []
        
        # Apply robustness-based changes
        
        # 1. If WFE is low, make parameters more conservative
        if self.report.wfa_avg_wfe < self.MIN_WFE:
            # Reduce TP, increase SL (more conservative)
            for tp_key in ['InpTakeProfitBuy', 'InpTakeProfitSell']:
                if tp_key in params:
                    current = int(params[tp_key]['value'])
                    new_val = int(current * 0.85)  # Reduce by 15%
                    params[tp_key]['value'] = str(new_val)
                    changes.append(f"{tp_key}: {current} → {new_val} (reduzir para evitar overfitting)")
        
        # 2. If monkey test failed, increase signal filters
        if self.report.monkey_result and not self.report.monkey_result.is_robust:
            for score_key in ['InpMinScoreBuy', 'InpMinScoreSell']:
                if score_key in params:
                    current = int(params[score_key]['value'])
                    new_val = min(5, current + 1)  # Increase filter
                    params[score_key]['value'] = str(new_val)
                    changes.append(f"{score_key}: {current} → {new_val} (aumentar filtro)")
        
        # 3. If pass rate is low, widen stops
        if self.report.wfa_pass_rate < 50:
            for trigger_key in ['InpBE_Buy_Trigger', 'InpBE_Sell_Trigger']:
                if trigger_key in params:
                    current = int(params[trigger_key]['value'])
                    new_val = int(current * 1.25)  # Increase by 25%
                    params[trigger_key]['value'] = str(new_val)
                    changes.append(f"{trigger_key}: {current} → {new_val} (mais espaço)")
        
        if not changes:
            self.log("No changes needed for robustness")
            return None
        
        # Generate new filename
        base_name = self.preset_path.stem
        if '_robust' in base_name:
            # Increment version
            match = re.search(r'_robust_v(\d+)$', base_name)
            if match:
                new_version = int(match.group(1)) + 1
                new_name = re.sub(r'_robust_v\d+$', f'_robust_v{new_version}', base_name)
            else:
                new_name = f"{base_name}_v2"
        else:
            new_name = f"{base_name}_robust_v1"
        
        # Create preset content
        timestamp = datetime.now().strftime("%Y.%m.%d %H:%M:%S")
        lines = [
            f"; saved on {timestamp}",
            f"; ROBUST Preset - Generated by RobustnessAnalyzer",
            f"; Based on: {self.preset_path.name}",
            f"; WFA Avg WFE: {self.report.wfa_avg_wfe:.1f}%",
            f"; Monkey Percentile: {self.report.monkey_result.ea_percentile:.1f}%" if self.report.monkey_result else "; Monkey: N/A",
            ";"
        ]
        
        for change in changes:
            lines.append(f"; CHANGE: {change}")
        lines.append(";")
        
        # Read original and apply changes
        try:
            raw_bytes = self.preset_path.read_bytes()
            for encoding in ['utf-8-sig', 'utf-8', 'utf-16-le']:
                try:
                    original = raw_bytes.decode(encoding)
                    if '=' in original:
                        break
                except:
                    continue
            
            for line in original.split('\n'):
                stripped = line.strip()
                
                if not stripped:
                    continue
                
                if stripped.startswith(';') and '═' in stripped:
                    lines.append(stripped)
                    continue
                
                if stripped.startswith(';'):
                    if 'saved on' in stripped.lower() or 'robust' in stripped.lower():
                        continue
                    lines.append(stripped)
                    continue
                
                if '=' in stripped:
                    name = stripped.split('=')[0].strip().replace('\ufeff', '')
                    if name in params:
                        p = params[name]
                        if p.get('min') and p['min'] != '':
                            line_out = f"{name}={p['value']}||{p['min']}||{p['step']}||{p['max']}||{p['optimize']}"
                        else:
                            line_out = f"{name}={p['value']}"
                        lines.append(line_out)
                    else:
                        lines.append(stripped)
                        
        except Exception as e:
            self.log(f"Error reading preset: {e}")
            return None
        
        # Write new preset
        output_path = self.preset_path.parent / f"{new_name}.set"
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write('\n'.join(lines))
        
        self.log(f"Generated robust preset: {output_path}")
        
        return str(output_path)
    
    def _read_preset(self, path: Path) -> Dict:
        """Read preset file and parse parameters."""
        params = {}
        try:
            raw_bytes = path.read_bytes()
            content = None
            for encoding in ['utf-8-sig', 'utf-8', 'utf-16-le']:
                try:
                    content = raw_bytes.decode(encoding)
                    if '=' in content:
                        break
                except:
                    continue
            
            if not content:
                return params
            
            for line in content.split('\n'):
                line = line.strip()
                if not line or line.startswith(';'):
                    continue
                
                if '=' in line:
                    parts = line.split('=', 1)
                    name = parts[0].strip().replace('\ufeff', '')
                    value_part = parts[1].strip()
                    
                    if '||' in value_part:
                        value_parts = value_part.split('||')
                        params[name] = {
                            'value': value_parts[0],
                            'min': value_parts[1] if len(value_parts) > 1 else '',
                            'step': value_parts[2] if len(value_parts) > 2 else '',
                            'max': value_parts[3] if len(value_parts) > 3 else '',
                            'optimize': value_parts[4] if len(value_parts) > 4 else 'N'
                        }
                    else:
                        params[name] = {'value': value_part, 'min': '', 'step': '', 'max': '', 'optimize': 'N'}
        except Exception as e:
            self.log(f"Error reading preset: {e}")
        
        return params
    
    # =========================================================================
    # METRICS CALCULATION HELPERS
    # =========================================================================
    
    def _calc_profit_factor(self, profits: List[float]) -> float:
        gross_profit = sum(p for p in profits if p > 0)
        gross_loss = abs(sum(p for p in profits if p < 0))
        return gross_profit / gross_loss if gross_loss > 0 else 0.0
    
    def _calc_sharpe(self, profits: List[float]) -> float:
        if len(profits) < 2:
            return 0.0
        mean_return = statistics.mean(profits)
        std_dev = statistics.stdev(profits)
        if std_dev == 0:
            return 0.0
        return (mean_return / std_dev) * math.sqrt(252)
    
    def _calc_max_dd(self, profits: List[float]) -> float:
        equity = 0
        peak = 0
        max_dd = 0
        for p in profits:
            equity += p
            if equity > peak:
                peak = equity
            dd = (peak - equity) / peak * 100 if peak > 0 else 0
            if dd > max_dd:
                max_dd = dd
        return max_dd
    
    def _calc_sqn(self, profits: List[float]) -> float:
        if len(profits) < 2:
            return 0.0
        mean_return = statistics.mean(profits)
        std_dev = statistics.stdev(profits)
        if std_dev == 0:
            return 0.0
        return (mean_return / std_dev) * math.sqrt(len(profits))
    
    # =========================================================================
    # MAIN ANALYSIS
    # =========================================================================
    
    def calculate_confidence_score(self) -> float:
        """Calculate overall confidence score (0-100)."""
        score = 0
        
        # WFA contribution (40%)
        if self.report.wfa_avg_wfe >= self.MIN_WFE:
            score += 20
        score += min(20, (self.report.wfa_pass_rate / 100) * 20)
        
        # Monkey Test contribution (40%)
        if self.report.monkey_result:
            if self.report.monkey_result.is_robust:
                score += 25
            score += min(15, (self.report.monkey_result.ea_percentile / 100) * 15)
        
        # No critical issues (20%)
        critical_issues = [i for i in self.report.robustness_issues if i['severity'] == 'CRITICAL']
        if not critical_issues:
            score += 20
        elif len(critical_issues) == 1:
            score += 10
        
        return min(100, score)
    
    def run_full_analysis(self, wfa_runs: int = 10, monkey_runs: int = 5000) -> RobustnessReport:
        """Run complete robustness analysis."""
        self.log("="*60)
        self.log("🧪 ROBUSTNESS ANALYZER - Full Analysis")
        self.log("="*60)
        
        if hasattr(self.metrics, 'symbol'):
            self.report.symbol = self.metrics.symbol
            self.report.timeframe = self.metrics.timeframe
        self.report.analysis_date = datetime.now().isoformat()
        
        # Run WFA
        self.run_wfa(is_ratio=0.7, num_runs=wfa_runs)
        
        # Run WFM
        self.run_wfm(grid_size=5)
        
        # Run Monkey Test
        self.run_monkey_test(num_simulations=monkey_runs)
        
        # Apply 5-Whys
        self.apply_five_whys()
        
        # Calculate confidence
        self.report.confidence_score = self.calculate_confidence_score()
        self.report.is_robust = self.report.confidence_score >= 70
        
        # Generate recommendations
        self.report.recommendations = [
            i['recommendation'] for i in self.report.robustness_issues
        ]
        
        # Print summary
        self._print_summary()
        
        return self.report
    
    def _print_summary(self):
        """Print robustness analysis summary."""
        print("\n" + "="*60)
        print("🧪 ROBUSTNESS ANALYSIS SUMMARY")
        print("="*60)
        
        status = "✅ ROBUSTO" if self.report.is_robust else "❌ NÃO ROBUSTO"
        print(f"\n📊 STATUS: {status}")
        print(f"   Confidence Score: {self.report.confidence_score:.0f}%")
        
        print(f"\n📈 WALK-FORWARD ANALYSIS")
        print("-"*40)
        print(f"   Runs:        {self.report.wfa_runs}")
        print(f"   Avg WFE:     {self.report.wfa_avg_wfe:.1f}% {'✅' if self.report.wfa_avg_wfe >= self.MIN_WFE else '❌'}")
        print(f"   Pass Rate:   {self.report.wfa_pass_rate:.0f}%")
        
        if self.report.wfm_matrix:
            print(f"\n📊 WALK-FORWARD MATRIX")
            print("-"*40)
            print(f"   Best IS:     {self.report.wfm_best_is}%")
            print(f"   Best OOS:    {self.report.wfm_best_oos}%")
        
        if self.report.monkey_result:
            mk = self.report.monkey_result
            print(f"\n🐒 MONKEY TEST")
            print("-"*40)
            print(f"   Simulations: {mk.num_simulations}")
            print(f"   Percentile:  {mk.ea_percentile:.1f}% {'✅' if mk.ea_percentile >= self.MIN_MONKEY_PERCENTILE else '❌'}")
            print(f"   Z-Score:     {mk.z_score:.2f} {'✅' if mk.z_score >= self.MIN_Z_SCORE else '❌'}")
            print(f"   p-value:     {mk.p_value:.4f}")
        
        if self.report.robustness_issues:
            print(f"\n⚠️  ISSUES ({len(self.report.robustness_issues)})")
            print("-"*40)
            for issue in self.report.robustness_issues:
                icon = "🔴" if issue['severity'] == 'CRITICAL' else "🟡"
                print(f"\n{icon} [{issue['severity']}] {issue['problem']}")
                for i, why in enumerate(issue['whys'], 1):
                    print(f"   {i}. {why}")
                print(f"   💡 {issue['recommendation']}")
        
        print("\n" + "="*60)


def main():
    parser = argparse.ArgumentParser(description="MT5 EA Robustness Analyzer")
    parser.add_argument("log_file", help="Path to MT5 log file")
    parser.add_argument("--preset", "-p", help="Path to current preset file")
    parser.add_argument("--output", "-o", help="Output JSON file", default=".tmp/robustness_report.json")
    parser.add_argument("--wfa-runs", type=int, default=10, help="Number of WFA runs")
    parser.add_argument("--monkey-runs", type=int, default=5000, help="Number of Monte Carlo simulations")
    parser.add_argument("--quiet", "-q", action="store_true", help="Suppress verbose output")
    
    args = parser.parse_args()
    
    # Use BacktestAnalyzerV2 to get trades
    if HAS_ANALYZER:
        print("[ROBUSTNESS] Using BacktestAnalyzerV2 for trade extraction...")
        from BacktestAnalyzerV2 import BacktestAnalyzerV2
        
        backtest = BacktestAnalyzerV2(
            args.log_file,
            verbose=not args.quiet
        )
        
        if not backtest.read_log():
            print("ERROR: Failed to read log file")
            return 1
        
        backtest.extract_metadata()
        backtest.extract_inputs()
        backtest.extract_trades()
        backtest.calculate_metrics()
        
        trades = backtest.trades
        inputs = backtest.inputs
        metrics = backtest.metrics
    else:
        print("ERROR: BacktestAnalyzerV2 not found. Run from tools/ directory.")
        return 1
    
    # Run robustness analysis
    analyzer = RobustnessAnalyzer(
        trades=trades,
        inputs=inputs,
        metrics=metrics,
        preset_path=args.preset,
        verbose=not args.quiet
    )
    
    report = analyzer.run_full_analysis(
        wfa_runs=args.wfa_runs,
        monkey_runs=args.monkey_runs
    )
    
    # Generate robust preset if needed
    if not report.is_robust and args.preset:
        new_preset = analyzer.generate_robust_preset()
        if new_preset:
            print(f"\n🆕 New robust preset: {new_preset}")
    
    # Save report
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    
    # Convert report to dict for JSON
    report_dict = asdict(report)
    # Convert datetime objects
    for r in report_dict.get('wfa_results', []):
        for key in ['is_start', 'is_end', 'oos_start', 'oos_end']:
            if key in r and r[key]:
                r[key] = str(r[key])
    
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(report_dict, f, indent=2, ensure_ascii=False, default=str)
    
    print(f"\n📄 Report saved to: {output_path}")
    
    return 0 if report.is_robust else 1


if __name__ == "__main__":
    sys.exit(main())
