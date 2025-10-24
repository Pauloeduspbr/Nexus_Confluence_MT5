#!/usr/bin/env python3
"""
🚀 NEXUS CONFLUENCE EA - PRODUCTION ANALYZER v1.0
================================================
Sistema profissional de análise de trades com métricas avançadas

Funcionalidades:
- Reconstrução completa de trades do log
- Métricas profissionais (Sharpe, Sortino, VaR, ES)
- Bootstrap com intervalos de confiança 95%
- Testes de hipótese estatísticos
- Sistema de rastreabilidade completo

Autor: Nexus Confluence Analysis System
Data: 23 de Outubro de 2025
Versão: 1.0.0 (Production Grade)
"""

import re
import json
import hashlib
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass, asdict, field
from collections import defaultdict

import numpy as np
from scipy import stats


# ============================================================================
# DATA STRUCTURES
# ============================================================================

@dataclass
class Trade:
    """Estrutura completa de um trade"""
    ticket: int
    symbol: str
    trade_type: str  # 'BUY' or 'SELL'
    
    # Timing
    open_time: datetime
    close_time: Optional[datetime] = None
    duration_minutes: Optional[float] = None
    
    # Prices and volume
    entry_price: float = 0.0
    close_price: Optional[float] = None
    volume: float = 0.0
    
    # Risk management
    initial_sl: float = 0.0
    current_sl: float = 0.0
    tp1: Optional[float] = None
    tp2: Optional[float] = None
    
    # Execution tracking
    tp1_hit: bool = False
    tp2_hit: bool = False
    be_activated: bool = False
    ts_activated: bool = False
    
    be_trigger_price: Optional[float] = None
    ts_trigger_price: Optional[float] = None
    
    # Performance metrics
    profit: Optional[float] = None
    profit_pips: Optional[float] = None
    r_multiple: Optional[float] = None
    
    max_favorable_excursion: float = 0.0  # MFE
    max_adverse_excursion: float = 0.0    # MAE
    
    # Classification
    setup_class: Optional[str] = None  # 'PREMIUM', 'GOOD', etc
    config_set_name: Optional[str] = None  # 🔥 v4.34: 'CONSERVATIVE', 'MODERATE', 'AGGRESSIVE'
    
    # Status
    is_closed: bool = False
    close_reason: Optional[str] = None  # 'TP1', 'TP2', 'SL', 'TS', 'MANUAL'
    
    # Metadata
    modifications: List[Dict] = field(default_factory=list)


@dataclass
class PerformanceMetrics:
    """Métricas de performance profissionais"""
    # Basic metrics
    total_trades: int = 0
    winning_trades: int = 0
    losing_trades: int = 0
    win_rate: float = 0.0
    
    # Profit metrics
    total_profit: float = 0.0
    total_loss: float = 0.0
    profit_factor: float = 0.0
    
    # Expectancy
    expectancy: float = 0.0
    expectancy_r: float = 0.0
    
    # Drawdown
    max_drawdown: float = 0.0
    max_drawdown_pct: float = 0.0
    avg_drawdown: float = 0.0
    
    # R-multiples
    r_mean: float = 0.0
    r_median: float = 0.0
    r_std: float = 0.0
    r_p10: float = 0.0
    r_p90: float = 0.0
    
    # Advanced metrics
    sharpe_ratio: float = 0.0
    sortino_ratio: float = 0.0
    var_95: float = 0.0
    var_99: float = 0.0
    es_95: float = 0.0
    es_99: float = 0.0
    
    # Distribution
    returns: List[float] = field(default_factory=list)
    r_multiples: List[float] = field(default_factory=list)


@dataclass
class BootstrapResult:
    """Resultado de bootstrap para uma métrica"""
    point_estimate: float
    ci_lower: float
    ci_upper: float
    std_error: float
    confidence: float = 0.95


# ============================================================================
# TRADE RECONSTRUCTOR
# ============================================================================

class TradeReconstructor:
    """Reconstrói trades completos do log MT5"""
    
    def __init__(self, log_file: str):
        self.log_file = Path(log_file)
        self.trades: Dict[str, Trade] = {}  # 🔥 v4.34 FIX: Chave = "CONFIG_ticket" para evitar sobrescrita
        self.open_positions: Dict[str, Trade] = {}  # 🔥 v4.34 FIX: Chave = "CONFIG_ticket"
        self.current_config_set: Optional[str] = None  # 🔥 v4.34: Rastreia CONFIG_SET atual
    
    def _get_trade_key(self, ticket: int) -> str:
        """
        🔥 v4.34 FIX: Gera chave única para trade baseada em CONFIG_SET + ticket
        Isso evita que trades com mesmo ticket de diferentes backtests se sobrescrevam
        """
        config = self.current_config_set or 'UNKNOWN'
        return f"{config}_{ticket}"
        
        # Regex patterns
        self.patterns = {
            # Pattern para log de backtest MT5 (deal #X buy/sell)
            'deal_backtest': re.compile(
                r'(\d{4}\.\d{2}\.\d{2}\s\d{2}:\d{2}:\d{2}).*'
                r'deal\s+#(\d+)\s+'
                r'(buy|sell)\s+'
                r'([\d.]+)\s+'
                r'(\w+)\s+'
                r'at\s+([\d.]+)',
                re.IGNORECASE
            ),
            # Pattern para posição fechada (backtest)
            'position_closed': re.compile(
                r'(\d{4}\.\d{2}\.\d{2}\s\d{2}:\d{2}:\d{2}).*'
                r'position\s+closed.*?at\s+([\d.]+).*?'
                r'\[#(\d+)\s+(buy|sell)\s+([\d.]+)\s+(\w+)\s+([\d.]+)\s+sl:\s*([\d.]+)',
                re.IGNORECASE
            ),
            'order_open': re.compile(
                r'(\d{4}\.\d{2}\.\d{2}\s\d{2}:\d{2}:\d{2}).*'
                r'order\s+#(\d+).*'
                r'(buy|sell).*'
                r'(\w+).*'
                r'at\s+([\d.]+).*'
                r'sl:\s*([\d.]+).*'
                r'volume\s+([\d.]+)',
                re.IGNORECASE
            ),
            'order_modify': re.compile(
                r'(\d{4}\.\d{2}\.\d{2}\s\d{2}:\d{2}:\d{2}).*'
                r'modify\s+#(\d+).*'
                r'sl:\s*([\d.]+)',
                re.IGNORECASE
            ),
            'order_close': re.compile(
                r'(\d{4}\.\d{2}\.\d{2}\s\d{2}:\d{2}:\d{2}).*'
                r'close\s+#(\d+).*'
                r'at\s+([\d.]+).*'
                r'profit:\s*([-\d.]+)',
                re.IGNORECASE
            ),
            'tp1_hit': re.compile(
                r'TP1\s+atingido.*ticket\s+#?(\d+)',
                re.IGNORECASE
            ),
            'tp2_hit': re.compile(
                r'TP2\s+atingido.*ticket\s+#?(\d+)',
                re.IGNORECASE
            ),
            'be_activated': re.compile(
                r'Breakeven\s+ativado.*ticket\s+#?(\d+)',
                re.IGNORECASE
            ),
            # 🔥 v4.34: Extrai CONFIG_SET dos parâmetros de entrada (início do backtest)
            'config_set_param': re.compile(
                r'ConfigSetName=(\w+)',
                re.IGNORECASE
            ),
            # 🔥 v4.34: Também detecta no log do trade (se existir)
            'config_set_log': re.compile(
                r'CONFIG_SET:\s*(\w+)',
                re.IGNORECASE
            ),
            'ts_activated': re.compile(
                r'Trailing\s+Stop\s+ativado.*ticket\s+#?(\d+)',
                re.IGNORECASE
            ),
        }
    
    def parse_log_streaming(self, chunk_size: int = 50 * 1024 * 1024) -> List[Trade]:
        """
        Parse log em chunks para escalabilidade
        
        Args:
            chunk_size: Tamanho do chunk em bytes (default: 50MB)
        
        Returns:
            Lista de trades reconstruídos
        """
        print(f"📄 Parsing log: {self.log_file.name}")
        print(f"💾 Chunk size: {chunk_size / (1024*1024):.1f}MB")
        
        if not self.log_file.exists():
            raise FileNotFoundError(f"Log file not found: {self.log_file}")
        
        file_size = self.log_file.stat().st_size
        print(f"📊 File size: {file_size / (1024*1024):.1f}MB")
        
        lines_processed = 0
        trades_found = 0
        
        with open(self.log_file, 'r', encoding='utf-16-le', errors='ignore') as f:
            buffer = ""
            start_time = datetime.now()
            
            while True:
                chunk = f.read(chunk_size)
                if not chunk:
                    break
                
                # Processar linhas completas
                buffer += chunk
                lines = buffer.split('\n')
                buffer = lines[-1]  # Guardar linha incompleta
                
                for line in lines[:-1]:
                    lines_processed += 1
                    self._process_line(line)
                
                # ⭐ PROGRESSO MELHORADO: Mostrar a cada 50k linhas
                if lines_processed % 50000 == 0:
                    elapsed = (datetime.now() - start_time).total_seconds()
                    rate = lines_processed / elapsed if elapsed > 0 else 0
                    eta_seconds = (file_size / (1024*1024) / (chunk_size / (1024*1024)) * elapsed / (lines_processed / 100000)) if lines_processed > 0 else 0
                    
                    print(f"  ⏳ Processado: {lines_processed:,} linhas | {len(self.trades):,} trades | "
                          f"Taxa: {rate:,.0f} linhas/seg | "
                          f"Tempo: {elapsed:.0f}s | ETA: ~{eta_seconds:.0f}s")
        
        # Processar última linha
        if buffer:
            self._process_line(buffer)
        
        print(f"✅ Parsing complete!")
        print(f"  Total lines: {lines_processed:,}")
        print(f"  Total trades: {len(self.trades):,}")
        print(f"  Open positions: {len(self.open_positions):,}")
        
        # 🔥 v4.34: Mostrar distribuição por CONFIG_SET
        config_set_dist = {}
        for trade in self.trades.values():
            config = trade.config_set_name or 'UNKNOWN'
            config_set_dist[config] = config_set_dist.get(config, 0) + 1
        
        if config_set_dist:
            print(f"\n  📊 Distribuição por CONFIG_SET:")
            for config_name, count in sorted(config_set_dist.items()):
                pct = (count / len(self.trades) * 100) if self.trades else 0
                print(f"     - {config_name}: {count:,} trades ({pct:.1f}%)")
        
        return list(self.trades.values())
    
    def _process_line(self, line: str):
        """Processa uma linha do log"""
        # Deal backtest (MT5 backtest format)
        match = self.patterns['deal_backtest'].search(line)
        if match:
            self._handle_deal_backtest(match)
            return
        
        # Position closed (backtest)
        match = self.patterns['position_closed'].search(line)
        if match:
            self._handle_position_closed(match)
            return
        
        # Order open
        match = self.patterns['order_open'].search(line)
        if match:
            self._handle_order_open(match)
            return
        
        # Order modify
        match = self.patterns['order_modify'].search(line)
        if match:
            self._handle_order_modify(match)
            return
        
        # Order close
        match = self.patterns['order_close'].search(line)
        if match:
            self._handle_order_close(match)
            return
        
        # TP1 hit
        match = self.patterns['tp1_hit'].search(line)
        if match:
            ticket = int(match.group(1))
            if ticket in self.open_positions:
                self.open_positions[ticket].tp1_hit = True
            return
        
        # TP2 hit
        match = self.patterns['tp2_hit'].search(line)
        if match:
            ticket = int(match.group(1))
            if ticket in self.open_positions:
                self.open_positions[ticket].tp2_hit = True
            return
        
        # 🔥 v4.34: CONFIG_SET nos parâmetros (início de cada backtest)
        match = self.patterns['config_set_param'].search(line)
        if match:
            config_set_name = match.group(1)
            old_config = self.current_config_set
            self.current_config_set = config_set_name
            
            # Debug: Mostrar mudança de contexto
            if old_config != config_set_name:
                print(f"  🏷️  Detectado CONFIG_SET: {config_set_name} (anterior: {old_config or 'None'})")
                print(f"      Trades até agora: {len(self.trades)}")
            
            return
        
        # 🔥 v4.34: CONFIG_SET no log do trade (formato alternativo)
        match = self.patterns['config_set_log'].search(line)
        if match:
            config_set_name = match.group(1)
            # Associar ao último trade aberto (heurística: CONFIG_SET vem logo após trade aberto)
            if self.open_positions:
                last_ticket = max(self.open_positions.keys())
                self.open_positions[last_ticket].config_set_name = config_set_name
            return
        
        # BE activated
        match = self.patterns['be_activated'].search(line)
        if match:
            ticket = int(match.group(1))
            if ticket in self.open_positions:
                self.open_positions[ticket].be_activated = True
            return
        
        # TS activated
        match = self.patterns['ts_activated'].search(line)
        if match:
            ticket = int(match.group(1))
            if ticket in self.open_positions:
                self.open_positions[ticket].ts_activated = True
            return
    
    def _handle_order_open(self, match):
        """Trata abertura de ordem"""
        timestamp_str = match.group(1)
        ticket = int(match.group(2))
        trade_type = match.group(3).upper()
        symbol = match.group(4)
        entry_price = float(match.group(5))
        sl = float(match.group(6)) if match.group(6) else 0.0
        volume = float(match.group(7))
        
        trade = Trade(
            ticket=ticket,
            symbol=symbol,
            trade_type=trade_type,
            open_time=datetime.strptime(timestamp_str, '%Y.%m.%d %H:%M:%S'),
            entry_price=entry_price,
            initial_sl=sl,
            current_sl=sl,
            volume=volume,
            config_set_name=self.current_config_set  # 🔥 v4.34: Aplicar CONFIG_SET atual
        )
        
        # 🔥 v4.34 FIX: Usar chave única config_ticket
        trade_key = self._get_trade_key(ticket)
        self.open_positions[trade_key] = trade
        self.trades[trade_key] = trade
    
    def _handle_order_modify(self, match):
        """Trata modificação de ordem"""
        timestamp_str = match.group(1)
        ticket = int(match.group(2))
        new_sl = float(match.group(3))
        
        trade_key = self._get_trade_key(ticket)  # 🔥 v4.34 FIX
        if trade_key in self.open_positions:
            trade = self.open_positions[trade_key]
            trade.current_sl = new_sl
            trade.modifications.append({
                'time': timestamp_str,
                'sl': new_sl
            })
    
    def _handle_order_close(self, match):
        """Trata fechamento de ordem"""
        timestamp_str = match.group(1)
        ticket = int(match.group(2))
        close_price = float(match.group(3))
        profit = float(match.group(4))
        
        trade_key = self._get_trade_key(ticket)  # 🔥 v4.34 FIX
        if trade_key in self.open_positions:
            trade = self.open_positions[trade_key]
            trade.close_time = datetime.strptime(timestamp_str, '%Y.%m.%d %H:%M:%S')
            trade.close_price = close_price
            trade.profit = profit
            trade.is_closed = True
            
            # Calcular duração
            if trade.open_time and trade.close_time:
                duration = (trade.close_time - trade.open_time).total_seconds() / 60
                trade.duration_minutes = duration
            
            # Calcular R-multiple
            risk = abs(trade.entry_price - trade.initial_sl)
            if risk > 0:
                if trade.trade_type == 'BUY':
                    trade.r_multiple = (close_price - trade.entry_price) / risk
                else:
                    trade.r_multiple = (trade.entry_price - close_price) / risk
            
            # Determinar motivo fechamento
            if trade.tp2_hit:
                trade.close_reason = 'TP2'
            elif trade.tp1_hit:
                trade.close_reason = 'TP1'
            elif trade.ts_activated:
                trade.close_reason = 'TS'
            elif profit < 0:
                trade.close_reason = 'SL'
            else:
                trade.close_reason = 'MANUAL'
            
            # Remover de posições abertas
            del self.open_positions[trade_key]  # 🔥 v4.34 FIX
    
    def _handle_deal_backtest(self, match):
        """Trata deal de backtest MT5 (abertura/fechamento de posição)"""
        # Grupos: 1=timestamp, 2=ticket, 3=type, 4=volume, 5=symbol, 6=price
        timestamp_str = match.group(1)
        ticket = int(match.group(2))
        trade_type = match.group(3).upper()
        volume = float(match.group(4))
        symbol = match.group(5)
        price = float(match.group(6))
        
        # Verificar se há posição aberta OPOSTA
        open_tickets = list(self.open_positions.keys())
        for open_ticket in open_tickets:
            open_trade = self.open_positions[open_ticket]
            
            # Se o tipo do deal é OPOSTO ao da posição aberta, é um fechamento
            if (open_trade.trade_type == 'BUY' and trade_type == 'SELL') or \
               (open_trade.trade_type == 'SELL' and trade_type == 'BUY'):
                # Fechar a posição aberta
                open_trade.close_time = datetime.strptime(timestamp_str, '%Y.%m.%d %H:%M:%S')
                open_trade.close_price = price
                
                # Calcular profit em pips
                if open_trade.trade_type == 'BUY':
                    open_trade.profit = (price - open_trade.entry_price) * 10000  # pips USDJPY
                else:
                    open_trade.profit = (open_trade.entry_price - price) * 10000  # pips
                
                open_trade.is_closed = True
                
                # Calcular duração
                if open_trade.open_time and open_trade.close_time:
                    duration = (open_trade.close_time - open_trade.open_time).total_seconds() / 60
                    open_trade.duration_minutes = duration
                
                # Calcular R-multiple (usar 30 pips como SL padrão se não tiver)
                risk = abs(open_trade.entry_price - open_trade.initial_sl) * 10000 if open_trade.initial_sl else 30
                if risk > 0:
                    open_trade.r_multiple = open_trade.profit / risk
                
                # Determinar motivo
                if open_trade.profit > 0:
                    open_trade.close_reason = 'TP'
                else:
                    open_trade.close_reason = 'SL'
                
                # Remover de posições abertas
                del self.open_positions[open_ticket]
                break
        
        # Sempre criar nova posição com este deal
        new_trade = Trade(
            ticket=ticket,
            symbol=symbol,
            trade_type=trade_type,
            open_time=datetime.strptime(timestamp_str, '%Y.%m.%d %H:%M:%S'),
            entry_price=price,
            volume=volume,
            initial_sl=0.0,  # Backtest não mostra SL nos deals
            config_set_name=self.current_config_set  # 🔥 v4.34: Aplicar CONFIG_SET atual
        )
        
        # 🔥 DEBUG v4.34: Log do primeiro trade de cada CONFIG_SET
        if self.current_config_set and len([t for t in self.trades.values() if t.config_set_name == self.current_config_set]) == 0:
            print(f"      📍 Primeiro trade do CONFIG_SET '{self.current_config_set}': Ticket #{ticket}")
        
        self.open_positions[ticket] = new_trade
        self.trades[ticket] = new_trade
    
    def _handle_position_closed(self, match):
        """Trata fechamento de posição no backtest"""
        # Grupos: 1=timestamp, 2=close_price, 3=ticket, 4=type, 5=volume, 6=symbol, 7=entry, 8=sl
        timestamp_str = match.group(1)
        close_price = float(match.group(2))
        ticket = int(match.group(3))
        trade_type = match.group(4).upper()
        volume = float(match.group(5))
        symbol = match.group(6)
        entry_price = float(match.group(7))
        sl = float(match.group(8)) if match.group(8) else 0.0
        
        if ticket in self.open_positions:
            trade = self.open_positions[ticket]
            trade.close_time = datetime.strptime(timestamp_str, '%Y.%m.%d %H:%M:%S')
            trade.close_price = close_price
            trade.initial_sl = sl
            trade.current_sl = sl
            
            # Calcular profit
            if trade.trade_type == 'BUY':
                trade.profit = (close_price - entry_price) * volume * 100
            else:
                trade.profit = (entry_price - close_price) * volume * 100
            
            trade.is_closed = True
            
            # Calcular duração
            if trade.open_time and trade.close_time:
                duration = (trade.close_time - trade.open_time).total_seconds() / 60
                trade.duration_minutes = duration
            
            # Calcular R-multiple
            risk = abs(entry_price - sl) if sl else 0
            if risk > 0:
                if trade.trade_type == 'BUY':
                    trade.r_multiple = (close_price - entry_price) / risk
                else:
                    trade.r_multiple = (entry_price - close_price) / risk
            
            # Determinar motivo
            if trade.profit < 0:
                trade.close_reason = 'SL'
            else:
                trade.close_reason = 'TP'
            
            # Remover de posições abertas
            del self.open_positions[ticket]


# ============================================================================
# METRICS CALCULATOR
# ============================================================================

class MetricsCalculator:
    """Calcula métricas profissionais de performance"""
    
    @staticmethod
    def calculate_all_metrics(trades: List[Trade]) -> PerformanceMetrics:
        """
        Calcula todas as métricas de performance
        
        Args:
            trades: Lista de trades completos
        
        Returns:
            PerformanceMetrics com todas as métricas calculadas
        """
        metrics = PerformanceMetrics()
        
        # Filtrar apenas trades fechados
        closed_trades = [t for t in trades if t.is_closed and t.profit is not None]
        
        if not closed_trades:
            return metrics
        
        # Basic metrics
        metrics.total_trades = len(closed_trades)
        metrics.winning_trades = sum(1 for t in closed_trades if t.profit > 0)
        metrics.losing_trades = sum(1 for t in closed_trades if t.profit < 0)
        metrics.win_rate = (metrics.winning_trades / metrics.total_trades * 100) if metrics.total_trades > 0 else 0.0
        
        # Profit metrics
        profits = [t.profit for t in closed_trades]
        metrics.returns = profits
        metrics.total_profit = sum(p for p in profits if p > 0)
        metrics.total_loss = abs(sum(p for p in profits if p < 0))
        metrics.profit_factor = (metrics.total_profit / metrics.total_loss) if metrics.total_loss > 0 else float('inf')
        
        # Expectancy
        metrics.expectancy = np.mean(profits) if profits else 0.0
        
        # R-multiples
        r_multiples = [t.r_multiple for t in closed_trades if t.r_multiple is not None]
        if r_multiples:
            metrics.r_multiples = r_multiples
            metrics.r_mean = np.mean(r_multiples)
            metrics.r_median = np.median(r_multiples)
            metrics.r_std = np.std(r_multiples, ddof=1)
            metrics.r_p10 = np.percentile(r_multiples, 10)
            metrics.r_p90 = np.percentile(r_multiples, 90)
            metrics.expectancy_r = metrics.r_mean
        
        # Sharpe Ratio
        if len(profits) > 1:
            metrics.sharpe_ratio = MetricsCalculator.calculate_sharpe_ratio(profits)
        
        # Sortino Ratio
        if len(profits) > 1:
            metrics.sortino_ratio = MetricsCalculator.calculate_sortino_ratio(profits)
        
        # VaR and ES
        if len(profits) > 10:
            metrics.var_95, metrics.es_95 = MetricsCalculator.calculate_var_es(profits, 0.95)
            metrics.var_99, metrics.es_99 = MetricsCalculator.calculate_var_es(profits, 0.99)
        
        # Drawdown
        metrics.max_drawdown, metrics.max_drawdown_pct, metrics.avg_drawdown = \
            MetricsCalculator.calculate_drawdown(profits)
        
        return metrics
    
    @staticmethod
    def calculate_sharpe_ratio(returns: List[float], risk_free_rate: float = 0.0) -> float:
        """
        Sharpe Ratio = (E[R] - Rf) / σ[R]
        
        Args:
            returns: Lista de retornos
            risk_free_rate: Taxa livre de risco
        
        Returns:
            Sharpe Ratio
        """
        if len(returns) < 2:
            return 0.0
        
        mean_return = np.mean(returns)
        std_return = np.std(returns, ddof=1)
        
        if std_return == 0:
            return 0.0
        
        return (mean_return - risk_free_rate) / std_return
    
    @staticmethod
    def calculate_sortino_ratio(returns: List[float], risk_free_rate: float = 0.0) -> float:
        """
        Sortino Ratio = (E[R] - Rf) / σ_downside[R]
        
        Considera apenas volatilidade negativa (downside risk)
        
        Args:
            returns: Lista de retornos
            risk_free_rate: Taxa livre de risco
        
        Returns:
            Sortino Ratio
        """
        if len(returns) < 2:
            return 0.0
        
        mean_return = np.mean(returns)
        downside_returns = [r for r in returns if r < 0]
        
        if len(downside_returns) == 0:
            return float('inf')
        
        downside_std = np.std(downside_returns, ddof=1)
        
        if downside_std == 0:
            return float('inf')
        
        return (mean_return - risk_free_rate) / downside_std
    
    @staticmethod
    def calculate_var_es(returns: List[float], confidence: float = 0.95) -> Tuple[float, float]:
        """
        VaR (Value at Risk) e ES (Expected Shortfall)
        
        VaR: Percentil (1-confidence) da distribuição
        ES: Média dos retornos piores que VaR
        
        Args:
            returns: Lista de retornos
            confidence: Nível de confiança (0.95 ou 0.99)
        
        Returns:
            tuple: (VaR, ES)
        """
        if len(returns) < 10:
            return 0.0, 0.0
        
        sorted_returns = np.sort(returns)
        var_index = int(len(sorted_returns) * (1 - confidence))
        
        if var_index >= len(sorted_returns):
            var_index = len(sorted_returns) - 1
        
        var = sorted_returns[var_index]
        
        # ES: média dos retornos piores que VaR
        if var_index > 0:
            es = np.mean(sorted_returns[:var_index])
        else:
            es = sorted_returns[0]
        
        return var, es
    
    @staticmethod
    def calculate_drawdown(returns: List[float]) -> Tuple[float, float, float]:
        """
        Calcula drawdown máximo e médio
        
        Args:
            returns: Lista de retornos
        
        Returns:
            tuple: (max_dd, max_dd_pct, avg_dd)
        """
        if not returns:
            return 0.0, 0.0, 0.0
        
        # Calcular equity curve
        equity = [sum(returns[:i+1]) for i in range(len(returns))]
        
        # Calcular drawdowns
        peak = equity[0]
        drawdowns = []
        
        for value in equity:
            if value > peak:
                peak = value
            dd = peak - value
            drawdowns.append(dd)
        
        max_dd = max(drawdowns) if drawdowns else 0.0
        avg_dd = np.mean(drawdowns) if drawdowns else 0.0
        
        # DD percentual
        max_dd_pct = (max_dd / peak * 100) if peak > 0 else 0.0
        
        return max_dd, max_dd_pct, avg_dd


# ============================================================================
# BOOTSTRAP ANALYZER
# ============================================================================

class BootstrapAnalyzer:
    """Bootstrap para intervalos de confiança"""
    
    def __init__(self, seed: int = 42):
        """
        Args:
            seed: Seed para reprodutibilidade
        """
        self.random_seed = seed
        self.seed = seed
    
    def bootstrap_metric(
        self,
        data: np.ndarray,
        metric_func: callable,
        n_iterations: int = 10000,
        confidence: float = 0.95
    ) -> BootstrapResult:
        """
        Bootstrap genérico com IC
        
        Args:
            data: Dados de entrada
            metric_func: Função que calcula métrica
            n_iterations: Número de iterações (default: 10k)
            confidence: Nível de confiança (default: 95%)
        
        Returns:
            BootstrapResult com estimativa pontual e IC
        """
        if len(data) < 2:
            return BootstrapResult(0.0, 0.0, 0.0, 0.0, confidence)
        
        # Usar Generator explícito para reprodutibilidade total
        rng = np.random.default_rng(self.random_seed)
        
        bootstrap_samples = []
        
        print(f"  Bootstrap: {n_iterations:,} iterations...", end='', flush=True)
        
        for i in range(n_iterations):
            # Resample com reposição usando o generator
            sample = rng.choice(data, size=len(data), replace=True)
            
            try:
                metric = metric_func(sample)
                if not np.isnan(metric) and not np.isinf(metric):
                    bootstrap_samples.append(metric)
            except:
                continue
        
        print(" Done!")
        
        if not bootstrap_samples:
            return BootstrapResult(0.0, 0.0, 0.0, 0.0, confidence)
        
        bootstrap_samples = np.array(bootstrap_samples)
        
        # Calcular IC
        alpha = 1 - confidence
        lower = np.percentile(bootstrap_samples, alpha / 2 * 100)
        upper = np.percentile(bootstrap_samples, (1 - alpha / 2) * 100)
        
        return BootstrapResult(
            point_estimate=np.mean(bootstrap_samples),
            ci_lower=lower,
            ci_upper=upper,
            std_error=np.std(bootstrap_samples, ddof=1),
            confidence=confidence
        )
    
    def bootstrap_all_metrics(self, trades: List[Trade]) -> Dict[str, BootstrapResult]:
        """
        Bootstrap para todas as métricas principais
        
        Args:
            trades: Lista de trades
        
        Returns:
            Dicionário com resultados de bootstrap
        """
        closed_trades = [t for t in trades if t.is_closed and t.profit is not None]
        
        if not closed_trades:
            return {}
        
        returns = np.array([t.profit for t in closed_trades])
        
        print(f"\n🔄 Bootstrap Analysis ({len(returns)} trades):")
        
        results = {}
        
        # Win Rate
        results['win_rate'] = self.bootstrap_metric(
            returns,
            lambda x: np.mean(x > 0) * 100,
            n_iterations=10000
        )
        
        # Expectancy
        results['expectancy'] = self.bootstrap_metric(
            returns,
            lambda x: np.mean(x),
            n_iterations=10000
        )
        
        # Sharpe Ratio
        results['sharpe'] = self.bootstrap_metric(
            returns,
            lambda x: (np.mean(x) / np.std(x, ddof=1)) if np.std(x, ddof=1) > 0 else 0,
            n_iterations=10000
        )
        
        # Profit Factor
        results['profit_factor'] = self.bootstrap_metric(
            returns,
            lambda x: np.sum(x[x > 0]) / abs(np.sum(x[x < 0])) if np.sum(x[x < 0]) != 0 else np.inf,
            n_iterations=10000
        )
        
        return results


# ============================================================================
# HYPOTHESIS TESTS
# ============================================================================

class HypothesisTests:
    """Testes estatísticos de hipótese"""
    
    @staticmethod
    def compare_two_sets(
        set1_returns: List[float],
        set2_returns: List[float],
        set1_name: str = "Set 1",
        set2_name: str = "Set 2"
    ) -> Dict:
        """
        Compara dois sets (ex: Conservative vs RogersSatchell)
        
        H0: E[R_set1] = E[R_set2]
        H1: E[R_set1] ≠ E[R_set2]
        
        Args:
            set1_returns: Retornos do set 1
            set2_returns: Retornos do set 2
            set1_name: Nome do set 1
            set2_name: Nome do set 2
        
        Returns:
            Dict com resultados do teste
        """
        # T-test para médias
        t_stat, p_value = stats.ttest_ind(set1_returns, set2_returns)
        
        mean1 = np.mean(set1_returns)
        mean2 = np.mean(set2_returns)
        delta = mean1 - mean2
        
        # Determinar winner
        if p_value > 0.05:
            winner = 'tie'
            confidence = 'baixa'
        elif abs(t_stat) > 3:
            winner = set1_name if delta > 0 else set2_name
            confidence = 'alta'
        else:
            winner = set1_name if delta > 0 else set2_name
            confidence = 'média'
        
        # Effect size (Cohen's d)
        pooled_std = np.sqrt((np.var(set1_returns, ddof=1) + np.var(set2_returns, ddof=1)) / 2)
        effect_size = delta / pooled_std if pooled_std > 0 else 0
        
        return {
            'winner': winner,
            'confidence': confidence,
            'delta_expectancy': delta,
            'p_value': p_value,
            't_statistic': t_stat,
            'effect_size': effect_size,
            'mean_set1': mean1,
            'mean_set2': mean2,
            'set1_name': set1_name,
            'set2_name': set2_name
        }


# ============================================================================
# MAIN PRODUCTION ANALYZER
# ============================================================================

class ProductionAnalyzer:
    """Analisador principal de produção"""
    
    def __init__(self, log_file: str, seed: int = 42):
        """
        Args:
            log_file: Caminho para arquivo de log
            seed: Seed para reprodutibilidade
        """
        self.log_file = log_file
        self.seed = seed
        self.trades: List[Trade] = []
        self.metrics: Optional[PerformanceMetrics] = None
        self.bootstrap_results: Dict[str, BootstrapResult] = {}
        
        # Rastreabilidade
        self.analysis_timestamp = datetime.now()
        self.git_commit = self._get_git_commit()
        self.data_hash = ""
    
    def _get_git_commit(self) -> str:
        """Obter hash do commit Git atual"""
        try:
            result = subprocess.run(
                ['git', 'rev-parse', 'HEAD'],
                capture_output=True,
                text=True,
                check=True
            )
            return result.stdout.strip()
        except:
            return "unknown"
    
    def _calculate_data_hash(self) -> str:
        """Calcular hash SHA256 dos dados"""
        if not self.trades:
            return ""
        
        # Serializar trades
        data_str = json.dumps([asdict(t) for t in self.trades], sort_keys=True, default=str)
        return hashlib.sha256(data_str.encode()).hexdigest()
    
    def run_full_analysis(self) -> Dict:
        """
        Executa análise completa
        
        Returns:
            Dicionário com todos os resultados
        """
        print("=" * 70)
        print("🚀 NEXUS CONFLUENCE - PRODUCTION ANALYZER v1.0")
        print("=" * 70)
        print(f"📅 Analysis timestamp: {self.analysis_timestamp.isoformat()}")
        print(f"🔧 Git commit: {self.git_commit[:8]}")
        print(f"🎲 Random seed: {self.seed}")
        print()
        
        # 1. Reconstruir trades
        print("📊 PHASE 1: Trade Reconstruction")
        print("-" * 70)
        reconstructor = TradeReconstructor(self.log_file)
        self.trades = reconstructor.parse_log_streaming()
        self.data_hash = self._calculate_data_hash()
        print(f"🔐 Data hash: {self.data_hash[:16]}...")
        print()
        
        # 2. Calcular métricas básicas
        print("📈 PHASE 2: Metrics Calculation")
        print("-" * 70)
        self.metrics = MetricsCalculator.calculate_all_metrics(self.trades)
        self._print_metrics(self.metrics)
        print()
        
        # 3. Bootstrap
        print("🔄 PHASE 3: Bootstrap Analysis")
        print("-" * 70)
        bootstrap_analyzer = BootstrapAnalyzer(seed=self.seed)
        self.bootstrap_results = bootstrap_analyzer.bootstrap_all_metrics(self.trades)
        self._print_bootstrap_results(self.bootstrap_results)
        print()
        
        # 4. Gerar resultado final
        result = {
            'metadata': {
                'analysis_timestamp': self.analysis_timestamp.isoformat(),
                'git_commit': self.git_commit,
                'data_hash': self.data_hash,
                'seed': self.seed,
                'log_file': str(self.log_file)
            },
            'trades': {
                'total': len(self.trades),
                'closed': sum(1 for t in self.trades if t.is_closed),
                'open': sum(1 for t in self.trades if not t.is_closed)
            },
            'metrics': asdict(self.metrics) if self.metrics else {},
            'bootstrap': {k: asdict(v) for k, v in self.bootstrap_results.items()}
        }
        
        print("=" * 70)
        print("✅ Analysis Complete!")
        print("=" * 70)
        
        return result
    
    def _print_metrics(self, metrics: PerformanceMetrics):
        """Imprime métricas de forma formatada"""
        print(f"  Total Trades: {metrics.total_trades}")
        print(f"  Win Rate: {metrics.win_rate:.1f}%")
        print(f"  Profit Factor: {metrics.profit_factor:.2f}")
        print(f"  Expectancy: ${metrics.expectancy:.2f}")
        print(f"  Expectancy R: {metrics.expectancy_r:.2f}R")
        print(f"  Sharpe Ratio: {metrics.sharpe_ratio:.2f}")
        print(f"  Sortino Ratio: {metrics.sortino_ratio:.2f}")
        print(f"  VaR 95%: ${metrics.var_95:.2f}")
        print(f"  ES 95%: ${metrics.es_95:.2f}")
        print(f"  Max Drawdown: ${metrics.max_drawdown:.2f} ({metrics.max_drawdown_pct:.1f}%)")
    
    def _print_bootstrap_results(self, results: Dict[str, BootstrapResult]):
        """Imprime resultados de bootstrap"""
        for metric_name, result in results.items():
            print(f"  {metric_name.title()}:")
            print(f"    Point Estimate: {result.point_estimate:.4f}")
            print(f"    CI 95%: [{result.ci_lower:.4f}, {result.ci_upper:.4f}]")
            print(f"    Std Error: {result.std_error:.4f}")


# ============================================================================
# MAIN
# ============================================================================

def main():
    """Função principal"""
    import sys
    import argparse
    
    parser = argparse.ArgumentParser(
        description='🚀 Nexus Confluence - Production Analyzer v1.0',
        epilog="""
Exemplos de uso:
  python production_analyzer.py log/20251023.log
  python production_analyzer.py log/20251023.log --seed 123
  python production_analyzer.py log/20251023.log --output analysis_output/custom/

NOTA: Para análise completa com geração de .set, use master_analyzer.py
        """
    )
    
    parser.add_argument('log_file', help='Caminho para arquivo de log MT5')
    parser.add_argument('--seed', type=int, default=42, help='Seed para reprodutibilidade (default: 42)')
    parser.add_argument('--output', help='Arquivo de saída JSON (default: analysis_output/production_analysis_complete.json)')
    
    args = parser.parse_args()
    
    log_file = args.log_file
    
    analyzer = ProductionAnalyzer(log_file, seed=args.seed)
    results = analyzer.run_full_analysis()
    
    # Salvar resultados
    if args.output:
        output_file = Path(args.output)
    else:
        output_file = Path('analysis_output') / 'production_analysis_complete.json'
    
    output_file.parent.mkdir(exist_ok=True, parents=True)
    
    with open(output_file, 'w') as f:
        json.dump(results, f, indent=2, default=str)
    
    print(f"\n💾 Results saved to: {output_file}")


if __name__ == '__main__':
    main()
