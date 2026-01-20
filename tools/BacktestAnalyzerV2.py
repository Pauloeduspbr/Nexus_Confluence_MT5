#!/usr/bin/env python3
"""
BacktestAnalyzerV2.py - Enhanced MT5 Backtest Log Analyzer

New Features:
1. Deep Code Analysis - Analyzes EA source code for logic issues
2. Historical Comparison - Compares current vs previous backtests
3. Robustness Testing - Monte Carlo, Walk-Forward indicators
4. Auto-save history for tracking evolution

Usage:
    python3 BacktestAnalyzerV2.py <log_file>
    python3 BacktestAnalyzerV2.py log/20260120.log --code-dir ../Experts --history-dir .tmp/history
"""

import re
import sys
import json
import hashlib
import argparse
from pathlib import Path
from dataclasses import dataclass, field, asdict
from typing import Optional, List, Dict, Tuple, Any
from datetime import datetime
from collections import defaultdict
import math
import os
import glob

# Optional imports
try:
    import pandas as pd
    HAS_PANDAS = True
except ImportError:
    HAS_PANDAS = False


@dataclass
class Trade:
    """Represents a single trade from the backtest."""
    ticket: int
    direction: str
    symbol: str
    lot: float
    entry_price: float
    entry_time: datetime
    sl: float = 0.0
    tp: float = 0.0
    close_price: float = 0.0
    close_time: Optional[datetime] = None
    profit: float = 0.0
    signal_class: str = ""
    score: int = 0
    be_activated: bool = False
    ts_activated: bool = False
    close_reason: str = ""


@dataclass
class BacktestMetrics:
    """Statistical metrics for the backtest."""
    symbol: str = ""
    timeframe: str = ""
    period_start: str = ""
    period_end: str = ""
    initial_balance: float = 0.0
    final_balance: float = 0.0
    total_profit: float = 0.0
    total_trades: int = 0
    winning_trades: int = 0
    losing_trades: int = 0
    win_rate: float = 0.0
    profit_factor: float = 0.0
    sharpe_ratio: float = 0.0
    max_drawdown_pct: float = 0.0
    max_drawdown_abs: float = 0.0
    expectancy: float = 0.0
    avg_win: float = 0.0
    avg_loss: float = 0.0
    largest_win: float = 0.0
    largest_loss: float = 0.0
    buy_trades: int = 0
    sell_trades: int = 0
    buy_win_rate: float = 0.0
    sell_win_rate: float = 0.0
    t_statistic: float = 0.0
    p_value_significant: bool = False
    # Robustness metrics
    recovery_factor: float = 0.0
    sqn: float = 0.0  # System Quality Number
    consecutive_losses_max: int = 0
    consecutive_wins_max: int = 0


@dataclass
class CodeIssue:
    """Represents a potential issue found in EA code."""
    file: str
    line: int
    severity: str  # CRITICAL, WARNING, INFO
    category: str  # LOGIC, PERFORMANCE, RISK, SYNC
    message: str
    suggestion: str


@dataclass 
class RobustnessResult:
    """Results from robustness testing."""
    monte_carlo_95_percentile: float = 0.0
    monte_carlo_5_percentile: float = 0.0
    monte_carlo_mean: float = 0.0
    parameter_sensitivity: Dict[str, float] = field(default_factory=dict)
    worst_period_drawdown: float = 0.0
    best_period_profit: float = 0.0
    profit_consistency: float = 0.0  # Std of monthly returns


@dataclass
class HistoricalComparison:
    """Comparison between current and previous backtests."""
    current_id: str = ""
    previous_id: str = ""
    profit_factor_delta: float = 0.0
    win_rate_delta: float = 0.0
    drawdown_delta: float = 0.0
    expectancy_delta: float = 0.0
    is_improvement: bool = False
    changed_inputs: Dict[str, Tuple[str, str]] = field(default_factory=dict)


class BacktestAnalyzerV2:
    """Enhanced analyzer with code analysis, history, and robustness testing."""
    
    def __init__(self, log_path: str, code_dir: str = None, history_dir: str = ".tmp/history", verbose: bool = True):
        self.log_path = Path(log_path)
        self.code_dir = Path(code_dir) if code_dir else None
        self.history_dir = Path(history_dir)
        self.history_dir.mkdir(parents=True, exist_ok=True)
        self.verbose = verbose
        
        self.raw_content = ""
        self.inputs: Dict[str, str] = {}
        self.trades: List[Trade] = []
        self.equity_curve: List[float] = []
        self.metrics = BacktestMetrics()
        self.code_issues: List[CodeIssue] = []
        self.robustness = RobustnessResult()
        self.comparison: Optional[HistoricalComparison] = None
        self.issues: List[Dict] = []
        
        # Metadata
        self.ea_name = ""
        self.symbol = ""
        self.timeframe = ""
        self.period_start = ""
        self.period_end = ""
        self.initial_deposit = 0.0
        self.leverage = ""
        self.backtest_id = ""
        
    def log(self, msg: str):
        if self.verbose:
            print(f"[ANALYZER] {msg}")
    
    def generate_backtest_id(self) -> str:
        """Generate unique ID for this backtest based on inputs hash."""
        inputs_str = json.dumps(self.inputs, sort_keys=True)
        hash_obj = hashlib.md5(inputs_str.encode())
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        return f"{self.symbol}_{self.timeframe}_{timestamp}_{hash_obj.hexdigest()[:8]}"
    
    def read_log(self) -> bool:
        """Read and decode the log file (UTF-16LE)."""
        self.log(f"Reading log file: {self.log_path}")
        
        if not self.log_path.exists():
            print(f"ERROR: Log file not found: {self.log_path}")
            return False
        
        try:
            with open(self.log_path, 'rb') as f:
                raw_bytes = f.read()
            
            try:
                self.raw_content = raw_bytes.decode('utf-16-le')
                self.log(f"Decoded as UTF-16LE, {len(self.raw_content):,} characters")
            except UnicodeDecodeError:
                self.raw_content = raw_bytes.decode('utf-8', errors='replace')
                self.log(f"Fallback to UTF-8, {len(self.raw_content):,} characters")
            
            return True
        except Exception as e:
            print(f"ERROR reading log: {e}")
            return False
    
    def extract_metadata(self):
        """Extract EA name, symbol, timeframe, period from log."""
        self.log("Extracting metadata...")
        
        pattern = r"testing of Experts\\(.+?)\\(.+?)\.ex5 from (\d{4}\.\d{2}\.\d{2}) to (\d{4}\.\d{2}\.\d{2})"
        match = re.search(pattern, self.raw_content)
        if match:
            self.ea_name = match.group(2)
            self.period_start = match.group(3)
            self.period_end = match.group(4)
        
        pattern = r"NexusConfluenceEA \((\w+),(\w+)\)"
        match = re.search(pattern, self.raw_content)
        if match:
            self.symbol = match.group(1)
            self.timeframe = match.group(2)
        
        pattern = r"initial deposit ([\d.]+) (\w+)"
        match = re.search(pattern, self.raw_content)
        if match:
            self.initial_deposit = float(match.group(1))
        
        pattern = r"leverage (\d+:\d+)"
        match = re.search(pattern, self.raw_content)
        if match:
            self.leverage = match.group(1)
    
    def extract_inputs(self) -> Dict[str, str]:
        """Extract all Inp* parameters from log."""
        self.log("Extracting EA inputs...")
        pattern = r"Tester\s+(Inp\w+)=(.+?)(?:\r?\n|$)"
        matches = re.findall(pattern, self.raw_content)
        for name, value in matches:
            self.inputs[name] = value.strip()
        self.log(f"Extracted {len(self.inputs)} inputs")
        return self.inputs
    
    def extract_trades(self) -> List[Trade]:
        """Extract all trades from log with proper entry/exit pairing."""
        self.log("Extracting trades with entry/exit pairing...")
        
        completed_trades: List[Trade] = []
        deal_pattern = r"(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2})\s+deal #(\d+) (buy|sell) ([\d.]+) (\w+) at ([\d.]+) done"
        order_pattern = r"market (buy|sell) ([\d.]+) (\w+) sl: ([\d.]+) tp: ([\d.]+).*?\[done at ([\d.]+)\]"
        
        order_data = {}
        for match in re.finditer(order_pattern, self.raw_content, re.IGNORECASE):
            entry = float(match.group(6))
            order_data[entry] = {'sl': float(match.group(4)), 'tp': float(match.group(5))}
        
        all_deals = []
        for match in re.finditer(deal_pattern, self.raw_content, re.IGNORECASE):
            all_deals.append({
                'time': match.group(1),
                'ticket': int(match.group(2)),
                'direction': match.group(3).upper(),
                'lot': float(match.group(4)),
                'symbol': match.group(5),
                'price': float(match.group(6))
            })
        
        i = 0
        while i < len(all_deals):
            deal = all_deals[i]
            if i + 1 < len(all_deals):
                next_deal = all_deals[i + 1]
                if (next_deal['symbol'] == deal['symbol'] and 
                    next_deal['direction'] != deal['direction'] and
                    next_deal['lot'] == deal['lot']):
                    
                    entry_price = deal['price']
                    exit_price = next_deal['price']
                    if deal['direction'] == 'BUY':
                        profit_points = exit_price - entry_price
                    else:
                        profit_points = entry_price - exit_price
                    
                    profit_usd = profit_points * deal['lot'] * 100
                    sl = order_data.get(entry_price, {}).get('sl', 0)
                    tp = order_data.get(entry_price, {}).get('tp', 0)
                    
                    trade = Trade(
                        ticket=deal['ticket'],
                        direction=deal['direction'],
                        symbol=deal['symbol'],
                        lot=deal['lot'],
                        entry_price=entry_price,
                        entry_time=datetime.strptime(deal['time'], "%Y.%m.%d %H:%M:%S"),
                        sl=sl, tp=tp,
                        close_price=exit_price,
                        close_time=datetime.strptime(next_deal['time'], "%Y.%m.%d %H:%M:%S"),
                        profit=profit_usd
                    )
                    completed_trades.append(trade)
                    i += 2
                    continue
            i += 1
        
        # Mark BE/TS activations
        be_tickets = set(int(m.group(1)) for m in re.finditer(r"Break Even ativado.*?#(\d+)", self.raw_content))
        ts_tickets = set(int(m.group(1)) for m in re.finditer(r"\[TS\].*?#(\d+).*?TRIGGER ATINGIDO", self.raw_content))
        
        for trade in completed_trades:
            trade.be_activated = trade.ticket in be_tickets
            trade.ts_activated = trade.ticket in ts_tickets
        
        self.trades = completed_trades
        self.log(f"Extracted {len(self.trades)} completed trades")
        return self.trades
    
    def extract_final_balance(self) -> float:
        match = re.search(r"final balance ([\d.]+)", self.raw_content)
        return float(match.group(1)) if match else 0.0
    
    def calculate_metrics(self) -> BacktestMetrics:
        """Calculate all statistical metrics including robustness indicators."""
        self.log("Calculating metrics...")
        
        self.metrics.symbol = self.symbol
        self.metrics.timeframe = self.timeframe
        self.metrics.period_start = self.period_start
        self.metrics.period_end = self.period_end
        self.metrics.initial_balance = self.initial_deposit
        self.metrics.final_balance = self.extract_final_balance()
        self.metrics.total_profit = self.metrics.final_balance - self.metrics.initial_balance
        self.metrics.total_trades = len(self.trades)
        
        if not self.trades:
            return self.metrics
        
        wins = [t.profit for t in self.trades if t.profit > 0]
        losses = [t.profit for t in self.trades if t.profit < 0]
        
        self.metrics.winning_trades = len(wins)
        self.metrics.losing_trades = len(losses)
        self.metrics.win_rate = (len(wins) / len(self.trades) * 100) if self.trades else 0
        
        gross_profit = sum(wins) if wins else 0
        gross_loss = abs(sum(losses)) if losses else 0.01
        self.metrics.profit_factor = gross_profit / gross_loss if gross_loss > 0 else 0
        
        self.metrics.avg_win = (sum(wins) / len(wins)) if wins else 0
        self.metrics.avg_loss = (sum(losses) / len(losses)) if losses else 0
        self.metrics.largest_win = max(wins) if wins else 0
        self.metrics.largest_loss = min(losses) if losses else 0
        
        all_profits = [t.profit for t in self.trades]
        self.metrics.expectancy = sum(all_profits) / len(all_profits) if all_profits else 0
        
        # Sharpe Ratio
        if len(all_profits) > 1:
            mean_return = sum(all_profits) / len(all_profits)
            variance = sum((p - mean_return) ** 2 for p in all_profits) / (len(all_profits) - 1)
            std_dev = math.sqrt(variance) if variance > 0 else 0.01
            self.metrics.sharpe_ratio = (mean_return / std_dev) * math.sqrt(252) if std_dev > 0 else 0
            
            # SQN - System Quality Number
            self.metrics.sqn = (mean_return / std_dev) * math.sqrt(len(all_profits)) if std_dev > 0 else 0
        
        # Max Drawdown and Equity Curve
        equity = self.initial_deposit
        peak = equity
        max_dd = 0
        max_dd_pct = 0
        
        for trade in self.trades:
            equity += trade.profit
            self.equity_curve.append(equity)
            if equity > peak:
                peak = equity
            dd = peak - equity
            dd_pct = (dd / peak * 100) if peak > 0 else 0
            if dd > max_dd:
                max_dd = dd
            if dd_pct > max_dd_pct:
                max_dd_pct = dd_pct
        
        self.metrics.max_drawdown_abs = max_dd
        self.metrics.max_drawdown_pct = max_dd_pct
        
        # Recovery Factor
        if max_dd > 0:
            self.metrics.recovery_factor = self.metrics.total_profit / max_dd
        
        # Consecutive wins/losses
        current_streak = 0
        max_win_streak = 0
        max_loss_streak = 0
        last_was_win = None
        
        for trade in self.trades:
            is_win = trade.profit > 0
            if last_was_win == is_win:
                current_streak += 1
            else:
                current_streak = 1
            
            if is_win:
                max_win_streak = max(max_win_streak, current_streak)
            else:
                max_loss_streak = max(max_loss_streak, current_streak)
            
            last_was_win = is_win
        
        self.metrics.consecutive_wins_max = max_win_streak
        self.metrics.consecutive_losses_max = max_loss_streak
        
        # Buy vs Sell analysis
        buy_trades = [t for t in self.trades if t.direction == "BUY"]
        sell_trades = [t for t in self.trades if t.direction == "SELL"]
        
        self.metrics.buy_trades = len(buy_trades)
        self.metrics.sell_trades = len(sell_trades)
        
        if buy_trades:
            self.metrics.buy_win_rate = len([t for t in buy_trades if t.profit > 0]) / len(buy_trades) * 100
        if sell_trades:
            self.metrics.sell_win_rate = len([t for t in sell_trades if t.profit > 0]) / len(sell_trades) * 100
        
        # t-test
        if len(all_profits) > 1:
            mean_return = sum(all_profits) / len(all_profits)
            variance = sum((p - mean_return) ** 2 for p in all_profits) / (len(all_profits) - 1)
            std_dev = math.sqrt(variance) if variance > 0 else 0.01
            self.metrics.t_statistic = mean_return / (std_dev / math.sqrt(len(all_profits)))
            self.metrics.p_value_significant = abs(self.metrics.t_statistic) > 1.96
        
        self.log(f"Metrics: PF={self.metrics.profit_factor:.2f}, WR={self.metrics.win_rate:.1f}%, DD={self.metrics.max_drawdown_pct:.1f}%")
        return self.metrics

    # =========================================================================
    # CODE ANALYSIS - Deep analysis of EA source code
    # =========================================================================
    
    def analyze_code(self, ea_code_dir: str = None) -> List[CodeIssue]:
        """Analyze EA source code for potential logic issues."""
        self.log("Analyzing EA source code...")
        
        code_dir = Path(ea_code_dir) if ea_code_dir else self.code_dir
        if not code_dir or not code_dir.exists():
            self.log("No code directory specified, skipping code analysis")
            return []
        
        # Find all MQ5/MQH files
        mq_files = list(code_dir.rglob("*.mq5")) + list(code_dir.rglob("*.mqh"))
        self.log(f"Found {len(mq_files)} MQL5 files to analyze")
        
        for file_path in mq_files:
            try:
                content = file_path.read_text(encoding='utf-8', errors='replace')
                self._analyze_single_file(file_path, content)
            except Exception as e:
                self.log(f"Error reading {file_path}: {e}")
        
        self.log(f"Found {len(self.code_issues)} code issues")
        return self.code_issues
    
    def _analyze_single_file(self, file_path: Path, content: str):
        """Analyze a single MQL5 file for issues."""
        lines = content.split('\n')
        filename = str(file_path.name)
        
        for i, line in enumerate(lines, 1):
            # Check for hardcoded values
            if re.search(r'\b(1\.5|2\.0|100|200|300|400|500)\b', line) and 'input' not in line.lower():
                if 'SL' in line or 'TP' in line or 'stop' in line.lower() or 'take' in line.lower():
                    self.code_issues.append(CodeIssue(
                        file=filename, line=i, severity="WARNING", category="LOGIC",
                        message=f"Potential hardcoded SL/TP value: {line.strip()[:60]}",
                        suggestion="Use input parameters instead of hardcoded values"
                    ))
            
            # Check for missing error handling on OrderSend
            if 'OrderSend' in line and 'if' not in lines[max(0,i-2):i+1]:
                self.code_issues.append(CodeIssue(
                    file=filename, line=i, severity="WARNING", category="RISK",
                    message="OrderSend without immediate error checking",
                    suggestion="Always check OrderSend result before proceeding"
                ))
            
            # Check for potential race conditions
            if 'CopyBuffer' in line or 'CopyRates' in line:
                if 'if(' not in line and i+1 < len(lines) and 'if' not in lines[i]:
                    self.code_issues.append(CodeIssue(
                        file=filename, line=i, severity="INFO", category="SYNC",
                        message="CopyBuffer/CopyRates without return value check",
                        suggestion="Check if CopyBuffer returns expected count"
                    ))
            
            # Check for shift=0 (current bar) which may repaint
            if re.search(r'CopyBuffer.*,\s*0\s*,\s*1\s*,', line):
                self.code_issues.append(CodeIssue(
                    file=filename, line=i, severity="WARNING", category="SYNC",
                    message="Reading indicator at shift=0 may cause repaint",
                    suggestion="Use shift=1 for confirmed closed bars"
                ))
            
            # Check for division without zero check
            if re.search(r'/\s*\w+[^=]', line) and 'if' not in line and '==' not in line:
                if not re.search(r'/\s*\d+\.?\d*', line):  # Not dividing by literal
                    if 'MathMax' not in line and 'fmax' not in line:
                        self.code_issues.append(CodeIssue(
                            file=filename, line=i, severity="INFO", category="LOGIC",
                            message="Division without explicit zero check",
                            suggestion="Use MathMax(divisor, 0.0001) or check for zero"
                        ))
            
            # Check for missing position close on deinit
            if 'OnDeinit' in line:
                # Look for CloseAll or PositionClose in next 20 lines
                deinit_block = '\n'.join(lines[i:min(i+20, len(lines))])
                if 'CloseAll' not in deinit_block and 'PositionClose' not in deinit_block:
                    self.code_issues.append(CodeIssue(
                        file=filename, line=i, severity="INFO", category="RISK",
                        message="OnDeinit may not close open positions",
                        suggestion="Consider closing positions or at least logging open positions"
                    ))

    # =========================================================================
    # ROBUSTNESS TESTING - Monte Carlo and Walk-Forward indicators
    # =========================================================================
    
    def run_robustness_tests(self) -> RobustnessResult:
        """Run robustness tests on the trade results."""
        self.log("Running robustness tests...")
        
        if len(self.trades) < 30:
            self.log("Not enough trades for robustness testing (need 30+)")
            return self.robustness
        
        profits = [t.profit for t in self.trades]
        
        # Monte Carlo simulation (1000 iterations)
        import random
        mc_results = []
        for _ in range(1000):
            shuffled = random.sample(profits, len(profits))
            equity = self.initial_deposit
            for p in shuffled:
                equity += p
            mc_results.append(equity)
        
        mc_results.sort()
        self.robustness.monte_carlo_5_percentile = mc_results[50]  # 5th percentile
        self.robustness.monte_carlo_95_percentile = mc_results[950]  # 95th percentile
        self.robustness.monte_carlo_mean = sum(mc_results) / len(mc_results)
        
        # Monthly profit consistency
        monthly_profits = defaultdict(float)
        for trade in self.trades:
            month_key = trade.entry_time.strftime("%Y-%m")
            monthly_profits[month_key] += trade.profit
        
        if len(monthly_profits) > 1:
            monthly_values = list(monthly_profits.values())
            mean_monthly = sum(monthly_values) / len(monthly_values)
            variance = sum((p - mean_monthly) ** 2 for p in monthly_values) / len(monthly_values)
            self.robustness.profit_consistency = math.sqrt(variance)
            
            self.robustness.worst_period_drawdown = min(monthly_values)
            self.robustness.best_period_profit = max(monthly_values)
        
        self.log(f"Robustness: MC 5%=${self.robustness.monte_carlo_5_percentile:.2f}, "
                f"95%=${self.robustness.monte_carlo_95_percentile:.2f}")
        
        return self.robustness

    # =========================================================================
    # HISTORICAL COMPARISON - Compare with previous backtests
    # =========================================================================
    
    def save_to_history(self):
        """Save current backtest results to history."""
        self.backtest_id = self.generate_backtest_id()
        
        history_file = self.history_dir / f"{self.backtest_id}.json"
        
        history_data = {
            "id": self.backtest_id,
            "timestamp": datetime.now().isoformat(),
            "symbol": self.symbol,
            "timeframe": self.timeframe,
            "period": f"{self.period_start} to {self.period_end}",
            "inputs": self.inputs,
            "metrics": asdict(self.metrics),
            "robustness": asdict(self.robustness),
            "code_issues_count": len(self.code_issues)
        }
        
        with open(history_file, 'w', encoding='utf-8') as f:
            json.dump(history_data, f, indent=2, ensure_ascii=False, default=str)
        
        self.log(f"Saved to history: {history_file}")
        return self.backtest_id
    
    def compare_with_previous(self) -> Optional[HistoricalComparison]:
        """Compare current results with most recent previous backtest."""
        self.log("Comparing with previous backtests...")
        
        # Find previous backtests for same symbol/timeframe
        pattern = f"{self.symbol}_{self.timeframe}_*.json"
        history_files = sorted(self.history_dir.glob(pattern), reverse=True)
        
        if len(history_files) < 2:
            self.log("No previous backtest found for comparison")
            return None
        
        # Current is [0], previous is [1]
        previous_file = history_files[1]
        
        try:
            with open(previous_file, 'r', encoding='utf-8') as f:
                previous = json.load(f)
            
            prev_metrics = previous.get('metrics', {})
            prev_inputs = previous.get('inputs', {})
            
            self.comparison = HistoricalComparison(
                current_id=self.backtest_id,
                previous_id=previous.get('id', 'unknown'),
                profit_factor_delta=self.metrics.profit_factor - prev_metrics.get('profit_factor', 0),
                win_rate_delta=self.metrics.win_rate - prev_metrics.get('win_rate', 0),
                drawdown_delta=self.metrics.max_drawdown_pct - prev_metrics.get('max_drawdown_pct', 0),
                expectancy_delta=self.metrics.expectancy - prev_metrics.get('expectancy', 0)
            )
            
            # Check which inputs changed
            for key, current_val in self.inputs.items():
                prev_val = prev_inputs.get(key, '')
                if current_val != prev_val:
                    self.comparison.changed_inputs[key] = (prev_val, current_val)
            
            # Determine if overall improvement
            self.comparison.is_improvement = (
                self.comparison.profit_factor_delta > 0 and
                self.comparison.drawdown_delta < 0
            )
            
            self.log(f"Comparison: PF delta={self.comparison.profit_factor_delta:+.2f}, "
                    f"DD delta={self.comparison.drawdown_delta:+.1f}%")
            
            return self.comparison
            
        except Exception as e:
            self.log(f"Error loading previous backtest: {e}")
            return None

    # =========================================================================
    # 5-WHYS DIAGNOSTIC
    # =========================================================================
    
    def apply_five_whys(self) -> List[Dict]:
        """Apply 5-Whys root cause analysis including code issues."""
        self.log("Applying 5-Whys analysis...")
        
        # Catastrophic Drawdown
        if self.metrics.max_drawdown_pct > 50:
            self.issues.append({
                "problem": f"Drawdown Catastrófico: {self.metrics.max_drawdown_pct:.1f}%",
                "severity": "CRITICAL",
                "category": "RISK",
                "whys": [
                    "Por quê? Account perdeu mais de 50% do capital",
                    "Por quê? Trades perdedores consecutivos sem proteção",
                    f"Por quê? InpDD_Enable={self.inputs.get('InpDD_Enable', 'unknown')}",
                    f"Por quê? Lot size fixo {self.inputs.get('InpLotSize', '?')} não se adapta",
                    "Por quê? Configuração de risco não adaptativa"
                ],
                "recommendation": "ATIVAR InpDD_Enable=true + lot sizing dinâmico"
            })
        
        # Low Profit Factor
        if self.metrics.profit_factor < 1.0:
            avg_win = self.metrics.avg_win
            avg_loss = abs(self.metrics.avg_loss)
            rr_ratio = avg_win / avg_loss if avg_loss > 0 else 0
            
            self.issues.append({
                "problem": f"Profit Factor Negativo: {self.metrics.profit_factor:.2f}",
                "severity": "CRITICAL",
                "category": "STRATEGY",
                "whys": [
                    "Por quê? Perdas totais excedem ganhos totais",
                    f"Por quê? R:R invertido ({rr_ratio:.2f}:1) - avg_loss > avg_win",
                    f"Por quê? SL={self.inputs.get('InpStopLossBuy', '?')} pts pode ser muito grande",
                    "Por quê? BE/TS fecham trades cedo demais",
                    "Por quê? Parâmetros não otimizados para o ativo"
                ],
                "recommendation": f"REDUZIR SL para ~400pts ou AUMENTAR TP para ~2000pts"
            })
        
        # Code issues
        critical_code_issues = [i for i in self.code_issues if i.severity == "CRITICAL"]
        if critical_code_issues:
            self.issues.append({
                "problem": f"Problemas Críticos no Código: {len(critical_code_issues)} encontrados",
                "severity": "CRITICAL",
                "category": "CODE",
                "whys": [
                    f"Por quê? {critical_code_issues[0].message if critical_code_issues else 'N/A'}",
                    "Por quê? Lógica de entrada/saída pode ter bugs",
                    "Por quê? Indicadores podem estar dessincronizados",
                    "Por quê? Falta de tratamento de erros",
                    "Por quê? Código não testado em condições extremas"
                ],
                "recommendation": "REVISAR código nos arquivos: " + 
                                 ", ".join(set(i.file for i in critical_code_issues[:3]))
            })
        
        # Robustness issues
        if self.robustness.monte_carlo_5_percentile < 0:
            self.issues.append({
                "problem": f"Estratégia Frágil: Monte Carlo 5% = ${self.robustness.monte_carlo_5_percentile:.2f}",
                "severity": "WARNING",
                "category": "ROBUSTNESS",
                "whys": [
                    "Por quê? Em 5% dos cenários simulados, a conta quebra",
                    "Por quê? Estratégia depende da ordem dos trades",
                    "Por quê? Não há margem de segurança suficiente",
                    "Por quê? Possivelmente overfitting no período testado",
                    "Por quê? Parâmetros muito agressivos"
                ],
                "recommendation": "REDUZIR risco por trade (lot menor) ou AUMENTAR filtros"
            })
        
        # Margin calls
        margin_calls = self.raw_content.count("not enough money")
        if margin_calls > 0:
            self.issues.append({
                "problem": f"Margin Calls: {margin_calls} trades rejeitados",
                "severity": "CRITICAL",
                "category": "CAPITAL",
                "whys": [
                    "Por quê? Account sem margem para novas posições",
                    "Por quê? Balance caiu abaixo do mínimo",
                    f"Por quê? Lot {self.inputs.get('InpLotSize', '?')} requer margem fixa",
                    "Por quê? Sem redução automática de lot",
                    "Por quê? DrawdownProtection não estava ativo"
                ],
                "recommendation": "HABILITAR proteção de drawdown + lot sizing adaptativo"
            })
        
        return self.issues

    # =========================================================================
    # REPORT GENERATION
    # =========================================================================
    
    def generate_report(self) -> Dict:
        """Generate complete diagnostic report."""
        report = {
            "metadata": {
                "id": self.backtest_id,
                "ea_name": self.ea_name,
                "symbol": self.symbol,
                "timeframe": self.timeframe,
                "period": f"{self.period_start} to {self.period_end}",
                "leverage": self.leverage,
                "analysis_date": datetime.now().isoformat()
            },
            "inputs": self.inputs,
            "metrics": asdict(self.metrics),
            "robustness": asdict(self.robustness),
            "code_analysis": {
                "total_issues": len(self.code_issues),
                "critical": len([i for i in self.code_issues if i.severity == "CRITICAL"]),
                "warnings": len([i for i in self.code_issues if i.severity == "WARNING"]),
                "issues": [asdict(i) for i in self.code_issues[:20]]  # Top 20 issues
            },
            "comparison": asdict(self.comparison) if self.comparison else None,
            "issues": self.issues,
            "recommendations": {
                "critical": [i["recommendation"] for i in self.issues if i["severity"] == "CRITICAL"],
                "warnings": [i["recommendation"] for i in self.issues if i["severity"] == "WARNING"],
            }
        }
        return report
    
    def print_summary(self):
        """Print analysis summary to console."""
        print("\n" + "="*70)
        print("🔍 MT5 BACKTEST ANALYZER V2 - Enhanced Diagnostic")
        print("="*70)
        
        print(f"\n📊 MÉTRICAS PRINCIPAIS")
        print("-"*40)
        print(f"  Symbol/TF:        {self.symbol} {self.timeframe}")
        print(f"  Período:          {self.period_start} to {self.period_end}")
        print(f"  Balance:          ${self.initial_deposit:,.2f} → ${self.metrics.final_balance:,.2f}")
        print(f"  P/L:              ${self.metrics.total_profit:,.2f} ({self.metrics.total_profit/self.initial_deposit*100:.1f}%)")
        print(f"  Total Trades:     {self.metrics.total_trades}")
        print(f"  Win Rate:         {self.metrics.win_rate:.1f}%")
        print(f"  Profit Factor:    {self.metrics.profit_factor:.2f}")
        print(f"  Sharpe Ratio:     {self.metrics.sharpe_ratio:.2f}")
        print(f"  Max Drawdown:     {self.metrics.max_drawdown_pct:.1f}%")
        print(f"  Expectancy:       ${self.metrics.expectancy:.2f}/trade")
        print(f"  SQN:              {self.metrics.sqn:.2f}")
        print(f"  Recovery Factor:  {self.metrics.recovery_factor:.2f}")
        print(f"  Max Consec Loss:  {self.metrics.consecutive_losses_max}")
        
        if self.robustness.monte_carlo_mean > 0:
            print(f"\n🎲 ROBUSTNESS (Monte Carlo)")
            print("-"*40)
            print(f"  5th Percentile:   ${self.robustness.monte_carlo_5_percentile:,.2f}")
            print(f"  Mean:             ${self.robustness.monte_carlo_mean:,.2f}")
            print(f"  95th Percentile:  ${self.robustness.monte_carlo_95_percentile:,.2f}")
        
        if self.code_issues:
            print(f"\n💻 CODE ANALYSIS")
            print("-"*40)
            print(f"  Total Issues:     {len(self.code_issues)}")
            print(f"  Critical:         {len([i for i in self.code_issues if i.severity == 'CRITICAL'])}")
            print(f"  Warnings:         {len([i for i in self.code_issues if i.severity == 'WARNING'])}")
        
        if self.comparison:
            print(f"\n📈 COMPARISON vs PREVIOUS")
            print("-"*40)
            icon = "✅" if self.comparison.is_improvement else "❌"
            print(f"  Status:           {icon} {'IMPROVED' if self.comparison.is_improvement else 'DEGRADED'}")
            print(f"  PF Delta:         {self.comparison.profit_factor_delta:+.2f}")
            print(f"  WR Delta:         {self.comparison.win_rate_delta:+.1f}%")
            print(f"  DD Delta:         {self.comparison.drawdown_delta:+.1f}%")
            if self.comparison.changed_inputs:
                print(f"  Changed Inputs:   {len(self.comparison.changed_inputs)}")
                for k, (old, new) in list(self.comparison.changed_inputs.items())[:5]:
                    print(f"    - {k}: {old} → {new}")
        
        print(f"\n⚠️  ISSUES ({len(self.issues)})")
        print("-"*40)
        for issue in self.issues:
            icon = "🔴" if issue["severity"] == "CRITICAL" else "🟡"
            print(f"\n{icon} [{issue['severity']}] {issue['problem']}")
            for i, why in enumerate(issue['whys'], 1):
                print(f"   {i}. {why}")
            print(f"   💡 {issue['recommendation']}")
        
        print("\n" + "="*70)

    # =========================================================================
    # AUTO-PRESET GENERATION - Generate new preset based on analysis
    # =========================================================================
    
    def find_latest_preset(self, presets_dir: str = "Presets") -> Optional[Path]:
        """Find the most recent preset for this symbol/timeframe."""
        presets_path = self.log_path.parent.parent / presets_dir
        if not presets_path.exists():
            presets_path = Path(presets_dir)
        
        if not presets_path.exists():
            self.log(f"Presets directory not found: {presets_path}")
            return None
        
        # Look for presets matching pattern
        symbol_lower = self.symbol.lower() if self.symbol else ""
        tf_lower = self.timeframe.lower() if self.timeframe else ""
        
        patterns = []
        if symbol_lower and tf_lower:
            patterns.append(f"{symbol_lower}_{tf_lower}*.set")
            patterns.append(f"{symbol_lower.upper()}_{tf_lower.upper()}*.set")
        patterns.append("*.set")  # Fallback to all presets
        
        presets = []
        for pattern in patterns:
            try:
                presets.extend(presets_path.glob(pattern))
            except ValueError:
                continue  # Skip invalid patterns
        
        if not presets:
            self.log("No preset files found")
            return None
        
        # Sort by modification time, most recent first
        presets.sort(key=lambda p: p.stat().st_mtime, reverse=True)
        self.log(f"Found {len(presets)} presets, using: {presets[0].name}")
        return presets[0]
    
    def read_preset(self, preset_path: Path) -> Dict[str, Dict]:
        """Read a preset file and parse parameters."""
        self.log(f"Reading preset: {preset_path}")
        
        params = {}
        try:
            raw_bytes = preset_path.read_bytes()
            
            # Try different encodings
            content = None
            for encoding in ['utf-8-sig', 'utf-8', 'utf-16-le', 'utf-16']:
                try:
                    content = raw_bytes.decode(encoding)
                    if content and '=' in content:
                        break
                except:
                    continue
            
            if not content:
                self.log("Could not decode preset file")
                return params
            
            for line in content.split('\n'):
                line = line.strip()
                # Skip empty lines and comments
                if not line or line.startswith(';'):
                    continue
                
                # Format: Name=value||min||step||max||Y/N
                if '=' in line:
                    parts = line.split('=', 1)
                    name = parts[0].strip()
                    value_part = parts[1].strip()
                    
                    # Skip if name is empty or contains invalid chars
                    if not name or name.startswith('\ufeff'):
                        name = name.replace('\ufeff', '')
                        if not name:
                            continue
                    
                    # Parse optimization range if present
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
                        params[name] = {
                            'value': value_part,
                            'min': '', 'step': '', 'max': '', 'optimize': 'N'
                        }
            
            self.log(f"Parsed {len(params)} parameters from preset")
        except Exception as e:
            self.log(f"Error reading preset: {e}")
        
        return params
    
    def generate_optimized_preset(self, presets_dir: str = "Presets") -> Optional[str]:
        """Generate a new optimized preset based on analysis results."""
        self.log("Generating optimized preset...")
        
        # Find base preset
        base_preset_path = self.find_latest_preset(presets_dir)
        if not base_preset_path:
            self.log("No base preset found, cannot generate optimized version")
            return None
        
        # Read base preset
        params = self.read_preset(base_preset_path)
        if not params:
            return None
        
        # Track changes made
        changes = []
        
        # =====================================================================
        # OPTIMIZATION RULES based on diagnostic issues
        # =====================================================================
        
        # RULE 1: If DD Protection is off and we had drawdown issues, turn it on
        if 'InpDD_Enable' in params:
            if params['InpDD_Enable']['value'].lower() == 'false':
                has_dd_issue = any(i.get('category') == 'RISK' for i in self.issues)
                has_margin_issue = any('Margin' in i.get('problem', '') for i in self.issues)
                if has_dd_issue or has_margin_issue or self.metrics.max_drawdown_pct > 30:
                    params['InpDD_Enable']['value'] = 'true'
                    changes.append("InpDD_Enable: false → true (proteção de drawdown)")
        
        # RULE 2: If lot size is too high relative to balance, reduce it
        if 'InpLotSize' in params:
            current_lot = float(params['InpLotSize']['value'])
            # If we had margin calls or lost more than 50%, reduce lot
            if self.metrics.max_drawdown_pct > 50 or self.raw_content.count("not enough money") > 0:
                new_lot = max(0.01, current_lot * 0.3)  # Reduce to 30%
                params['InpLotSize']['value'] = f"{new_lot:.2f}"
                changes.append(f"InpLotSize: {current_lot} → {new_lot:.2f} (reduzir risco)")
        
        # RULE 3: If Profit Factor < 1, adjust SL/TP ratio
        if self.metrics.profit_factor < 1.0:
            avg_win = abs(self.metrics.avg_win)
            avg_loss = abs(self.metrics.avg_loss)
            
            # If average loss > average win, we need to either reduce SL or increase TP
            if avg_loss > avg_win and avg_win > 0:
                ratio_needed = avg_loss / avg_win  # How much bigger losses are
                
                # Adjust SL (reduce by 15-20%)
                for sl_key in ['InpStopLossBuy', 'InpStopLossSell']:
                    if sl_key in params:
                        current_sl = int(params[sl_key]['value'])
                        new_sl = int(current_sl * 0.85)  # Reduce by 15%
                        new_sl = max(200, new_sl)  # Minimum 200 points
                        params[sl_key]['value'] = str(new_sl)
                        changes.append(f"{sl_key}: {current_sl} → {new_sl} (melhorar R:R)")
                
                # Adjust TP (increase by 15-20%)
                for tp_key in ['InpTakeProfitBuy', 'InpTakeProfitSell']:
                    if tp_key in params:
                        current_tp = int(params[tp_key]['value'])
                        new_tp = int(current_tp * 1.20)  # Increase by 20%
                        params[tp_key]['value'] = str(new_tp)
                        changes.append(f"{tp_key}: {current_tp} → {new_tp} (melhorar R:R)")
        
        # RULE 4: If MinScoreBuy < MinScoreSell, equalize
        buy_score = int(params.get('InpMinScoreBuy', {}).get('value', 0) or 0)
        sell_score = int(params.get('InpMinScoreSell', {}).get('value', 0) or 0)
        if buy_score < sell_score and buy_score > 0:
            params['InpMinScoreBuy']['value'] = str(sell_score)
            changes.append(f"InpMinScoreBuy: {buy_score} → {sell_score} (equalizar filtros)")
        
        # RULE 5: If consecutive losses > 5, increase BE trigger
        if self.metrics.consecutive_losses_max >= 5:
            for be_key in ['InpBE_Buy_Trigger', 'InpBE_Sell_Trigger']:
                if be_key in params:
                    current = int(params[be_key]['value'])
                    new_val = int(current * 1.3)  # Increase by 30%
                    params[be_key]['value'] = str(new_val)
                    changes.append(f"{be_key}: {current} → {new_val} (dar mais espaço)")
            
            for be_step_key in ['InpBE_Buy_Step', 'InpBE_Sell_Step']:
                if be_step_key in params:
                    current = int(params[be_step_key]['value'])
                    new_val = max(20, int(current * 3))  # Triple the step
                    params[be_step_key]['value'] = str(new_val)
                    changes.append(f"{be_step_key}: {current} → {new_val} (mais proteção)")
        
        # RULE 6: If robustness test failed, disable GOOD signals (only PREMIUM)
        if self.robustness.monte_carlo_5_percentile < 0:
            for good_key in ['InpBuyGoodEnable', 'InpSellGoodEnable']:
                if good_key in params and params[good_key]['value'].lower() == 'true':
                    params[good_key]['value'] = 'false'
                    changes.append(f"{good_key}: true → false (só sinais PREMIUM)")
        
        # RULE 7: If DD protection is on, reduce consecutive loss limit
        if params.get('InpDD_Enable', {}).get('value', '').lower() == 'true':
            if 'InpDD_ConsecLoss' in params:
                current = int(params['InpDD_ConsecLoss']['value'])
                if current > 5:
                    params['InpDD_ConsecLoss']['value'] = '5'
                    changes.append(f"InpDD_ConsecLoss: {current} → 5 (parar mais cedo)")
        
        # =====================================================================
        # Generate new preset file
        # =====================================================================
        
        if not changes:
            self.log("No changes needed, current preset is optimal")
            return None
        
        # Determine version number
        base_name = base_preset_path.stem
        version_match = re.search(r'_v(\d+)$', base_name)
        if version_match:
            new_version = int(version_match.group(1)) + 1
            new_name = re.sub(r'_v\d+$', f'_v{new_version}', base_name)
        else:
            new_name = f"{base_name}_v2"
        
        # Create new preset content
        timestamp = datetime.now().strftime("%Y.%m.%d %H:%M:%S")
        lines = [
            f"; saved on {timestamp}",
            f"; Auto-generated by BacktestAnalyzerV2",
            f"; Based on: {base_preset_path.name}",
            f"; Changes made: {len(changes)}",
            ";"
        ]
        
        # Add change log as comments
        for change in changes:
            lines.append(f"; CHANGE: {change}")
        lines.append(";")
        
        # Read original file to preserve order and comments
        try:
            raw_bytes = base_preset_path.read_bytes()
            
            # Try different encodings
            original_content = None
            for encoding in ['utf-8-sig', 'utf-8', 'utf-16-le', 'utf-16']:
                try:
                    original_content = raw_bytes.decode(encoding)
                    if original_content and '=' in original_content:
                        break
                except:
                    continue
            
            if not original_content:
                raise Exception("Could not decode preset file")
            
            for line in original_content.split('\n'):
                stripped = line.strip()
                
                # Skip empty lines
                if not stripped:
                    continue
                
                # Preserve section comments (with ═ character)
                if stripped.startswith(';') and '═' in stripped:
                    lines.append(stripped)
                    continue
                
                # Skip old header comments (saved on, Auto-generated, etc)
                if stripped.startswith(';'):
                    lower_strip = stripped.lower()
                    if any(x in lower_strip for x in ['saved on', 'auto-generated', 'based on', 'change:', 'changes made']):
                        continue
                    # Preserve other comments (like descriptions)
                    lines.append(stripped)
                    continue
                
                # Process parameter lines
                if '=' in stripped:
                    name = stripped.split('=')[0].strip()
                    # Remove BOM if present
                    name = name.replace('\ufeff', '')
                    
                    if name in params:
                        p = params[name]
                        if p.get('min') and p['min'] != '':
                            line_out = f"{name}={p['value']}||{p['min']}||{p['step']}||{p['max']}||{p['optimize']}"
                        else:
                            line_out = f"{name}={p['value']}"
                        lines.append(line_out)
                    else:
                        # Keep original line if not in params dict
                        lines.append(stripped)
                        
        except Exception as e:
            self.log(f"Error reading original preset: {e}")
            # Fallback: just dump parameters
            for name, p in params.items():
                if p.get('min') and p['min'] != '':
                    line_out = f"{name}={p['value']}||{p['min']}||{p['step']}||{p['max']}||{p['optimize']}"
                else:
                    line_out = f"{name}={p['value']}"
                lines.append(line_out)
        
        # Write new preset
        new_preset_path = base_preset_path.parent / f"{new_name}.set"
        with open(new_preset_path, 'w', encoding='utf-8') as f:
            f.write('\n'.join(lines))
        
        self.log(f"Generated new preset: {new_preset_path}")
        
        # Print changes summary
        print(f"\n🆕 NEW PRESET GENERATED: {new_preset_path.name}")
        print("-"*50)
        for change in changes:
            print(f"  ✏️  {change}")
        print("-"*50)
        
        return str(new_preset_path)
    
    def should_generate_new_preset(self) -> bool:
        """Determine if a new preset should be generated based on results."""
        # Generate new preset if:
        # 1. Profit Factor < 1.5 (not profitable enough)
        # 2. Max Drawdown > 30% (too risky)
        # 3. Expectancy < 0 (losing money on average)
        # 4. There are CRITICAL issues identified
        
        critical_issues = [i for i in self.issues if i.get('severity') == 'CRITICAL']
        
        return (
            self.metrics.profit_factor < 1.5 or
            self.metrics.max_drawdown_pct > 30 or
            self.metrics.expectancy < 0 or
            len(critical_issues) > 0
        )
    
    def run_full_analysis(self, analyze_code: bool = True, auto_generate_preset: bool = True) -> Dict:
        """Run complete analysis pipeline."""
        if not self.read_log():
            return {"error": "Failed to read log file"}
        
        self.extract_metadata()
        self.extract_inputs()
        self.extract_trades()
        self.calculate_metrics()
        self.run_robustness_tests()
        
        if analyze_code:
            # Try to find code directory relative to log
            possible_paths = [
                self.log_path.parent.parent / "Include" / "NexusConfluenceEA",
                self.log_path.parent.parent / "Experts" / "NexusConfluenceEA",
            ]
            for p in possible_paths:
                if p.exists():
                    self.analyze_code(str(p))
                    break
        
        self.apply_five_whys()
        self.save_to_history()
        self.compare_with_previous()
        
        self.print_summary()
        
        # Auto-generate optimized preset if needed
        new_preset_path = None
        if auto_generate_preset and self.should_generate_new_preset():
            new_preset_path = self.generate_optimized_preset()
        
        report = self.generate_report()
        report['new_preset'] = new_preset_path
        return report


def main():
    parser = argparse.ArgumentParser(description="MT5 Backtest Analyzer V2")
    parser.add_argument("log_file", help="Path to MT5 log file (UTF-16LE)")
    parser.add_argument("--output", "-o", help="Output JSON file", default=".tmp/analysis_v2.json")
    parser.add_argument("--code-dir", help="EA source code directory for analysis")
    parser.add_argument("--history-dir", help="Directory for historical comparisons", default=".tmp/history")
    parser.add_argument("--presets-dir", help="Directory containing presets", default="Presets")
    parser.add_argument("--no-code", action="store_true", help="Skip code analysis")
    parser.add_argument("--no-preset", action="store_true", help="Skip auto-preset generation")
    parser.add_argument("--quiet", "-q", action="store_true", help="Suppress verbose output")
    
    args = parser.parse_args()
    
    analyzer = BacktestAnalyzerV2(
        args.log_file,
        code_dir=args.code_dir,
        history_dir=args.history_dir,
        verbose=not args.quiet
    )
    
    report = analyzer.run_full_analysis(
        analyze_code=not args.no_code,
        auto_generate_preset=not args.no_preset
    )
    
    # Save report
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(report, f, indent=2, ensure_ascii=False, default=str)
    
    print(f"\n📄 Report saved to: {output_path}")
    
    if report.get('new_preset'):
        print(f"🆕 New preset: {report['new_preset']}")
        print("\n➡️  Próximo passo: Carregue o novo preset no MT5 e rode o backtest!")
    
    return 0 if report.get("metrics", {}).get("profit_factor", 0) > 1.0 else 1


if __name__ == "__main__":
    sys.exit(main())
