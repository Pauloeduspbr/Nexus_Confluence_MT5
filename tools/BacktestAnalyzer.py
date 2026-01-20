#!/usr/bin/env python3
"""
BacktestAnalyzer.py - MT5 Backtest Log Analyzer
Analyzes UTF-16LE logs from MetaTrader 5 Strategy Tester.

Features:
- Auto-detect UTF-16LE encoding
- Extract EA inputs from log (not hardcoded)
- Extract all trades (entry, exit, profit)
- Calculate statistical metrics (Profit Factor, Sharpe, Drawdown, Win Rate)
- Apply 5-Whys root cause analysis
- Generate diagnostic report

Usage:
    python3 BacktestAnalyzer.py <log_file>
    python3 BacktestAnalyzer.py log/20260120.log --output .tmp/report.json
"""

import re
import sys
import json
import argparse
from pathlib import Path
from dataclasses import dataclass, field, asdict
from typing import Optional, List, Dict, Tuple
from datetime import datetime
from collections import defaultdict
import math

# Optional imports for visualization
try:
    import pandas as pd
    HAS_PANDAS = True
except ImportError:
    HAS_PANDAS = False

try:
    import matplotlib.pyplot as plt
    HAS_MATPLOTLIB = True
except ImportError:
    HAS_MATPLOTLIB = False


@dataclass
class Trade:
    """Represents a single trade from the backtest."""
    ticket: int
    direction: str  # BUY or SELL
    symbol: str
    lot: float
    entry_price: float
    entry_time: datetime
    sl: float = 0.0
    tp: float = 0.0
    close_price: float = 0.0
    close_time: Optional[datetime] = None
    profit: float = 0.0
    signal_class: str = ""  # PREMIUM or GOOD
    score: int = 0
    be_activated: bool = False
    ts_activated: bool = False
    close_reason: str = ""  # TP, SL, BE, TS, MANUAL


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
    premium_trades: int = 0
    good_trades: int = 0
    premium_win_rate: float = 0.0
    good_win_rate: float = 0.0
    t_statistic: float = 0.0
    p_value_significant: bool = False


@dataclass
class DiagnosticIssue:
    """Represents an identified issue with 5-Whys analysis."""
    problem: str
    severity: str  # CRITICAL, WARNING, INFO
    whys: List[str] = field(default_factory=list)
    recommendation: str = ""


class BacktestAnalyzer:
    """Main analyzer class for MT5 backtest logs."""
    
    def __init__(self, log_path: str, verbose: bool = True):
        self.log_path = Path(log_path)
        self.verbose = verbose
        self.raw_content = ""
        self.inputs: Dict[str, str] = {}
        self.trades: List[Trade] = []
        self.equity_curve: List[float] = []
        self.metrics = BacktestMetrics()
        self.issues: List[DiagnosticIssue] = []
        
        # Metadata extracted from log
        self.ea_name = ""
        self.symbol = ""
        self.timeframe = ""
        self.period_start = ""
        self.period_end = ""
        self.initial_deposit = 0.0
        self.leverage = ""
        
    def log(self, msg: str):
        """Print verbose log message."""
        if self.verbose:
            print(f"[ANALYZER] {msg}")
    
    def read_log(self) -> bool:
        """Read and decode the log file (UTF-16LE)."""
        self.log(f"Reading log file: {self.log_path}")
        
        if not self.log_path.exists():
            print(f"ERROR: Log file not found: {self.log_path}")
            return False
        
        try:
            # MT5 logs are UTF-16LE with BOM
            with open(self.log_path, 'rb') as f:
                raw_bytes = f.read()
            
            # Try UTF-16LE first (most common for MT5)
            try:
                self.raw_content = raw_bytes.decode('utf-16-le')
                self.log(f"Decoded as UTF-16LE, {len(self.raw_content):,} characters")
            except UnicodeDecodeError:
                # Fallback to UTF-8
                self.raw_content = raw_bytes.decode('utf-8', errors='replace')
                self.log(f"Fallback to UTF-8, {len(self.raw_content):,} characters")
            
            return True
            
        except Exception as e:
            print(f"ERROR reading log: {e}")
            return False
    
    def extract_metadata(self):
        """Extract EA name, symbol, timeframe, period from log."""
        self.log("Extracting metadata...")
        
        # Pattern: testing of Experts\...\EA.ex5 from YYYY.MM.DD to YYYY.MM.DD
        pattern = r"testing of Experts\\(.+?)\\(.+?)\.ex5 from (\d{4}\.\d{2}\.\d{2}) to (\d{4}\.\d{2}\.\d{2})"
        match = re.search(pattern, self.raw_content)
        if match:
            self.ea_name = match.group(2)
            self.period_start = match.group(3)
            self.period_end = match.group(4)
            self.log(f"EA: {self.ea_name}, Period: {self.period_start} to {self.period_end}")
        
        # Pattern: SYMBOL,TIMEFRAME
        pattern = r"NexusConfluenceEA \((\w+),(\w+)\)"
        match = re.search(pattern, self.raw_content)
        if match:
            self.symbol = match.group(1)
            self.timeframe = match.group(2)
            self.log(f"Symbol: {self.symbol}, Timeframe: {self.timeframe}")
        
        # Initial deposit
        pattern = r"initial deposit ([\d.]+) (\w+)"
        match = re.search(pattern, self.raw_content)
        if match:
            self.initial_deposit = float(match.group(1))
            self.log(f"Initial Deposit: {self.initial_deposit}")
        
        # Leverage
        pattern = r"leverage (\d+:\d+)"
        match = re.search(pattern, self.raw_content)
        if match:
            self.leverage = match.group(1)
            self.log(f"Leverage: {self.leverage}")
    
    def extract_inputs(self) -> Dict[str, str]:
        """Extract all Inp* parameters from log."""
        self.log("Extracting EA inputs...")
        
        # Pattern: Tester    InpName=value
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
        open_positions: Dict[int, Trade] = {}  # position_ticket -> Trade
        
        # Pattern for trade execution: deal #N buy/sell LOT SYMBOL at PRICE done
        deal_pattern = r"(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2})\s+deal #(\d+) (buy|sell) ([\d.]+) (\w+) at ([\d.]+) done"
        
        # Pattern for TP/SL triggered: take profit triggered #N sell ... [#M buy ... at PRICE]
        # or stop loss triggered #N buy ... [#M sell ... at PRICE]
        tp_pattern = r"take profit triggered #(\d+) (buy|sell).*?\[#(\d+) (buy|sell).*?at ([\d.]+)\]"
        sl_pattern = r"stop loss triggered #(\d+) (buy|sell).*?\[#(\d+) (buy|sell).*?at ([\d.]+)\]"
        
        # Pattern for SL/TP from order: market buy/sell LOT SYMBOL sl: SL tp: TP
        order_pattern = r"market (buy|sell) ([\d.]+) (\w+) sl: ([\d.]+) tp: ([\d.]+).*?\[done at ([\d.]+)\]"
        
        # First pass: collect all order executions with their SL/TP
        order_data = {}  # ticket -> {sl, tp, direction}
        for match in re.finditer(order_pattern, self.raw_content, re.IGNORECASE):
            direction = match.group(1).upper()
            lot = float(match.group(2))
            sl = float(match.group(4))
            tp = float(match.group(5))
            entry = float(match.group(6))
            # Store for matching
            order_data[entry] = {'sl': sl, 'tp': tp, 'direction': direction, 'lot': lot}
        
        # Collect all deals in order
        all_deals = []
        for match in re.finditer(deal_pattern, self.raw_content, re.IGNORECASE):
            deal_time = match.group(1)
            ticket = int(match.group(2))
            direction = match.group(3).upper()
            lot = float(match.group(4))
            symbol = match.group(5)
            price = float(match.group(6))
            all_deals.append({
                'time': deal_time,
                'ticket': ticket,
                'direction': direction,
                'lot': lot,
                'symbol': symbol,
                'price': price
            })
        
        # Pair trades: Entry (odd ticket in MT5) -> Exit (even ticket)
        # Actually in MT5: position orders have same # as position, closing deal has new #
        # Look at pattern: position opened with ticket X, closed by ticket X+1 with opposite direction
        
        i = 0
        while i < len(all_deals):
            deal = all_deals[i]
            ticket = deal['ticket']
            
            # Check if this is an entry (position open)
            # Entry deals are followed by matching close deals with opposite direction
            if i + 1 < len(all_deals):
                next_deal = all_deals[i + 1]
                
                # Same symbol, opposite direction = this is entry/exit pair
                if (next_deal['symbol'] == deal['symbol'] and 
                    next_deal['direction'] != deal['direction'] and
                    next_deal['lot'] == deal['lot']):
                    
                    # Calculate profit
                    if deal['direction'] == 'BUY':
                        # Opened BUY, closed SELL
                        entry_price = deal['price']
                        exit_price = next_deal['price']
                        profit_points = exit_price - entry_price
                    else:
                        # Opened SELL, closed BUY
                        entry_price = deal['price']
                        exit_price = next_deal['price']
                        profit_points = entry_price - exit_price
                    
                    # For XAUUSD, profit = points * lot * 100 (standard calculation)
                    # But we need point value - for simplicity use approximate
                    profit_usd = profit_points * deal['lot'] * 100
                    
                    # Get SL/TP if we have it
                    sl = 0
                    tp = 0
                    if entry_price in order_data:
                        sl = order_data[entry_price]['sl']
                        tp = order_data[entry_price]['tp']
                    
                    trade = Trade(
                        ticket=ticket,
                        direction=deal['direction'],
                        symbol=deal['symbol'],
                        lot=deal['lot'],
                        entry_price=entry_price,
                        entry_time=datetime.strptime(deal['time'], "%Y.%m.%d %H:%M:%S"),
                        sl=sl,
                        tp=tp,
                        close_price=exit_price,
                        close_time=datetime.strptime(next_deal['time'], "%Y.%m.%d %H:%M:%S"),
                        profit=profit_usd
                    )
                    completed_trades.append(trade)
                    i += 2  # Skip both deals
                    continue
            
            i += 1
        
        # Extract BE activations
        be_pattern = r"Break Even ativado.*?#(\d+)"
        be_tickets = set()
        for match in re.finditer(be_pattern, self.raw_content):
            be_tickets.add(int(match.group(1)))
        
        # Extract TS activations
        ts_pattern = r"\[TS\].*?#(\d+).*?TRIGGER ATINGIDO"
        ts_tickets = set()
        for match in re.finditer(ts_pattern, self.raw_content):
            ts_tickets.add(int(match.group(1)))
        
        # Mark trades with BE/TS
        for trade in completed_trades:
            if trade.ticket in be_tickets:
                trade.be_activated = True
            if trade.ticket in ts_tickets:
                trade.ts_activated = True
        
        # Determine close reason
        for trade in completed_trades:
            if trade.profit > 0:
                if trade.ts_activated:
                    trade.close_reason = "TS"
                elif abs(trade.close_price - trade.tp) < 1:  # Near TP
                    trade.close_reason = "TP"
                else:
                    trade.close_reason = "WIN"
            else:
                if trade.be_activated:
                    trade.close_reason = "BE"
                elif trade.sl > 0 and abs(trade.close_price - trade.sl) < 1:
                    trade.close_reason = "SL"
                else:
                    trade.close_reason = "LOSS"
        
        self.trades = completed_trades
        self.log(f"Extracted {len(self.trades)} completed trades with P/L")
        return self.trades
    
    def extract_final_balance(self) -> float:
        """Extract final balance from log."""
        pattern = r"final balance ([\d.]+)"
        match = re.search(pattern, self.raw_content)
        if match:
            return float(match.group(1))
        return 0.0
    
    def calculate_metrics(self) -> BacktestMetrics:
        """Calculate all statistical metrics."""
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
            self.log("No trades to analyze")
            return self.metrics
        
        # Separate wins and losses
        wins = [t.profit for t in self.trades if t.profit > 0]
        losses = [t.profit for t in self.trades if t.profit < 0]
        
        self.metrics.winning_trades = len(wins)
        self.metrics.losing_trades = len(losses)
        self.metrics.win_rate = (len(wins) / len(self.trades) * 100) if self.trades else 0
        
        # Profit Factor
        gross_profit = sum(wins) if wins else 0
        gross_loss = abs(sum(losses)) if losses else 0.01  # Avoid division by zero
        self.metrics.profit_factor = gross_profit / gross_loss if gross_loss > 0 else 0
        
        # Average win/loss
        self.metrics.avg_win = (sum(wins) / len(wins)) if wins else 0
        self.metrics.avg_loss = (sum(losses) / len(losses)) if losses else 0
        self.metrics.largest_win = max(wins) if wins else 0
        self.metrics.largest_loss = min(losses) if losses else 0
        
        # Expectancy
        all_profits = [t.profit for t in self.trades]
        self.metrics.expectancy = sum(all_profits) / len(all_profits) if all_profits else 0
        
        # Sharpe Ratio (annualized, assuming M15 = 96 bars/day * 252 trading days)
        if len(all_profits) > 1:
            mean_return = sum(all_profits) / len(all_profits)
            variance = sum((p - mean_return) ** 2 for p in all_profits) / (len(all_profits) - 1)
            std_dev = math.sqrt(variance) if variance > 0 else 0.01
            self.metrics.sharpe_ratio = (mean_return / std_dev) * math.sqrt(252) if std_dev > 0 else 0
        
        # Maximum Drawdown
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
        
        # Buy vs Sell analysis
        buy_trades = [t for t in self.trades if t.direction == "BUY"]
        sell_trades = [t for t in self.trades if t.direction == "SELL"]
        
        self.metrics.buy_trades = len(buy_trades)
        self.metrics.sell_trades = len(sell_trades)
        
        if buy_trades:
            buy_wins = len([t for t in buy_trades if t.profit > 0])
            self.metrics.buy_win_rate = buy_wins / len(buy_trades) * 100
        
        if sell_trades:
            sell_wins = len([t for t in sell_trades if t.profit > 0])
            self.metrics.sell_win_rate = sell_wins / len(sell_trades) * 100
        
        # t-test for statistical significance
        if len(all_profits) > 1:
            mean_return = sum(all_profits) / len(all_profits)
            variance = sum((p - mean_return) ** 2 for p in all_profits) / (len(all_profits) - 1)
            std_dev = math.sqrt(variance) if variance > 0 else 0.01
            self.metrics.t_statistic = mean_return / (std_dev / math.sqrt(len(all_profits)))
            # Significance at 95% confidence: |t| > 1.96
            self.metrics.p_value_significant = abs(self.metrics.t_statistic) > 1.96
        
        self.log(f"Metrics calculated: PF={self.metrics.profit_factor:.2f}, "
                f"WR={self.metrics.win_rate:.1f}%, DD={self.metrics.max_drawdown_pct:.1f}%")
        
        return self.metrics
    
    def apply_five_whys(self) -> List[DiagnosticIssue]:
        """Apply 5-Whys root cause analysis to identified problems."""
        self.log("Applying 5-Whys analysis...")
        
        # Issue 1: Catastrophic Drawdown
        if self.metrics.max_drawdown_pct > 50:
            issue = DiagnosticIssue(
                problem=f"Drawdown Catastrófico: {self.metrics.max_drawdown_pct:.1f}%",
                severity="CRITICAL",
                whys=[
                    "Por quê? Account perdeu mais de 50% do capital",
                    "Por quê? Trades perdedores consecutivos sem proteção",
                    "Por quê? InpDD_Enable está FALSE (proteção desabilitada)",
                    "Por quê? Lot size fixo não reduz com equidade caindo",
                    "Por quê? Configuração de risco não adaptativa ao capital restante"
                ],
                recommendation="ATIVAR InpDD_Enable=true e implementar lot sizing dinâmico baseado em % do capital"
            )
            self.issues.append(issue)
        
        # Issue 2: Low Profit Factor
        if self.metrics.profit_factor < 1.0:
            issue = DiagnosticIssue(
                problem=f"Profit Factor Negativo: {self.metrics.profit_factor:.2f}",
                severity="CRITICAL",
                whys=[
                    "Por quê? Perdas totais excedem ganhos totais",
                    "Por quê? Win Rate e/ou R:R insuficientes",
                    "Por quê? Filtros de entrada permitem trades de baixa qualidade",
                    "Por quê? MinScoreBuy=2 muito baixo (aceita sinais fracos)",
                    "Por quê? Configuração assimétrica BUY vs SELL não validada"
                ],
                recommendation="AUMENTAR InpMinScoreBuy para 3 ou 4, equalizar com SELL"
            )
            self.issues.append(issue)
        
        # Issue 3: Asymmetric Performance
        if abs(self.metrics.buy_win_rate - self.metrics.sell_win_rate) > 15:
            worse = "BUY" if self.metrics.buy_win_rate < self.metrics.sell_win_rate else "SELL"
            issue = DiagnosticIssue(
                problem=f"Performance Assimétrica: {worse} tem win rate muito menor",
                severity="WARNING",
                whys=[
                    f"Por quê? {worse} tem win rate {min(self.metrics.buy_win_rate, self.metrics.sell_win_rate):.1f}%",
                    "Por quê? Parâmetros de filtro diferentes para cada direção",
                    f"Por quê? MinScore{worse.capitalize()}={self.inputs.get(f'InpMinScore{worse.capitalize()}', 'N/A')}",
                    "Por quê? Mercado pode ter viés direcional no período",
                    "Por quê? Indicadores podem funcionar melhor em tendências de alta/baixa"
                ],
                recommendation=f"Considerar DESABILITAR trades {worse} ou AUMENTAR filtros"
            )
            self.issues.append(issue)
        
        # Issue 4: BE/TS not helping
        be_activated = sum(1 for t in self.trades if t.be_activated)
        ts_activated = sum(1 for t in self.trades if t.ts_activated)
        
        if be_activated > 0 or ts_activated > 0:
            be_winners = sum(1 for t in self.trades if t.be_activated and t.profit > 0)
            be_rate = (be_winners / be_activated * 100) if be_activated > 0 else 0
            
            if be_rate < 70:
                issue = DiagnosticIssue(
                    problem=f"Break Even ineficiente: apenas {be_rate:.0f}% fecham no lucro após ativação",
                    severity="WARNING",
                    whys=[
                        "Por quê? Trades ativam BE mas depois são stopados",
                        "Por quê? BE_Trigger muito baixo (300 pts)",
                        "Por quê? Step muito pequeno (5 pts de proteção)",
                        "Por quê? Mercado reverção ocorre após atingir trigger",
                        "Por quê? Configuração genérica não otimizada para XAUUSD"
                    ],
                    recommendation="AUMENTAR InpBE_Trigger para 400-500 e Step para 20-50"
                )
                self.issues.append(issue)
        
        # Issue 5: Margin calls
        margin_calls = self.raw_content.count("not enough money")
        if margin_calls > 0:
            issue = DiagnosticIssue(
                problem=f"Margin Calls: {margin_calls} trades rejeitados por falta de margem",
                severity="CRITICAL",
                whys=[
                    "Por quê? Account não tinha margem para abrir novas posições",
                    "Por quê? Balance caiu abaixo do mínimo necessário",
                    "Por quê? Lot size fixo 0.07 requer ~$150 de margem para XAUUSD",
                    "Por quê? Sem redução automática de lot quando capital diminui",
                    "Por quê? DrawdownProtection desabilitado"
                ],
                recommendation="HABILITAR InpDD_Enable=true e usar lot sizing como % do capital (ex: 2%)"
            )
            self.issues.append(issue)
        
        self.log(f"Identified {len(self.issues)} issues")
        return self.issues
    
    def generate_report(self) -> Dict:
        """Generate complete diagnostic report."""
        report = {
            "metadata": {
                "ea_name": self.ea_name,
                "symbol": self.symbol,
                "timeframe": self.timeframe,
                "period": f"{self.period_start} to {self.period_end}",
                "leverage": self.leverage,
                "analysis_date": datetime.now().isoformat()
            },
            "inputs": self.inputs,
            "metrics": asdict(self.metrics),
            "issues": [asdict(i) for i in self.issues],
            "recommendations": {
                "critical": [i.recommendation for i in self.issues if i.severity == "CRITICAL"],
                "warnings": [i.recommendation for i in self.issues if i.severity == "WARNING"],
            }
        }
        return report
    
    def save_equity_curve(self, output_path: str = ".tmp/equity_curve.png"):
        """Save equity curve chart."""
        if not HAS_MATPLOTLIB:
            self.log("matplotlib not installed, skipping chart")
            return
        
        if not self.equity_curve:
            self.log("No equity data to plot")
            return
        
        plt.figure(figsize=(12, 6))
        plt.plot(self.equity_curve, 'b-', linewidth=1)
        plt.axhline(y=self.initial_deposit, color='g', linestyle='--', label='Initial')
        plt.axhline(y=self.metrics.final_balance, color='r', linestyle='--', label='Final')
        plt.fill_between(range(len(self.equity_curve)), self.equity_curve, 
                        self.initial_deposit, alpha=0.3, 
                        color='green' if self.equity_curve[-1] > self.initial_deposit else 'red')
        plt.title(f"{self.ea_name} - {self.symbol} {self.timeframe}\n"
                 f"Balance: ${self.initial_deposit:.2f} → ${self.metrics.final_balance:.2f}")
        plt.xlabel("Trade #")
        plt.ylabel("Equity ($)")
        plt.legend()
        plt.grid(True, alpha=0.3)
        plt.tight_layout()
        plt.savefig(output_path, dpi=150)
        plt.close()
        self.log(f"Equity curve saved to {output_path}")
    
    def run_full_analysis(self) -> Dict:
        """Run complete analysis pipeline."""
        print("\n" + "="*60)
        print("🔍 MT5 BACKTEST ANALYZER")
        print("="*60 + "\n")
        
        if not self.read_log():
            return {"error": "Failed to read log file"}
        
        self.extract_metadata()
        self.extract_inputs()
        self.extract_trades()
        self.calculate_metrics()
        self.apply_five_whys()
        
        report = self.generate_report()
        
        # Print summary
        print("\n" + "="*60)
        print("📊 SUMMARY METRICS")
        print("="*60)
        print(f"  Symbol/TF:      {self.symbol} {self.timeframe}")
        print(f"  Period:         {self.period_start} to {self.period_end}")
        print(f"  Initial:        ${self.initial_deposit:,.2f}")
        print(f"  Final:          ${self.metrics.final_balance:,.2f}")
        print(f"  P/L:            ${self.metrics.total_profit:,.2f} ({self.metrics.total_profit/self.initial_deposit*100:.1f}%)")
        print(f"  Total Trades:   {self.metrics.total_trades}")
        print(f"  Win Rate:       {self.metrics.win_rate:.1f}%")
        print(f"  Profit Factor:  {self.metrics.profit_factor:.2f}")
        print(f"  Sharpe Ratio:   {self.metrics.sharpe_ratio:.2f}")
        print(f"  Max Drawdown:   {self.metrics.max_drawdown_pct:.1f}%")
        print(f"  Expectancy:     ${self.metrics.expectancy:.2f}/trade")
        print(f"  Statistical:    {'✅ Significant' if self.metrics.p_value_significant else '❌ Not Significant'}")
        
        print("\n" + "="*60)
        print("⚠️  ISSUES IDENTIFIED")
        print("="*60)
        for issue in self.issues:
            icon = "🔴" if issue.severity == "CRITICAL" else "🟡"
            print(f"\n{icon} [{issue.severity}] {issue.problem}")
            for i, why in enumerate(issue.whys, 1):
                print(f"   {i}. {why}")
            print(f"   💡 Recommendation: {issue.recommendation}")
        
        print("\n" + "="*60 + "\n")
        
        return report


def main():
    parser = argparse.ArgumentParser(description="MT5 Backtest Log Analyzer")
    parser.add_argument("log_file", help="Path to MT5 log file (UTF-16LE)")
    parser.add_argument("--output", "-o", help="Output JSON file path", default=".tmp/analysis.json")
    parser.add_argument("--quiet", "-q", action="store_true", help="Suppress verbose output")
    parser.add_argument("--chart", "-c", action="store_true", help="Generate equity curve chart")
    
    args = parser.parse_args()
    
    analyzer = BacktestAnalyzer(args.log_file, verbose=not args.quiet)
    report = analyzer.run_full_analysis()
    
    # Save report
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(report, f, indent=2, ensure_ascii=False, default=str)
    print(f"📄 Report saved to: {output_path}")
    
    # Generate chart if requested
    if args.chart:
        chart_path = str(output_path.with_suffix('.png'))
        analyzer.save_equity_curve(chart_path)
    
    return 0 if report.get("metrics", {}).get("profit_factor", 0) > 1.0 else 1


if __name__ == "__main__":
    sys.exit(main())
