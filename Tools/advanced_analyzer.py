#!/usr/bin/env python3
"""
Advanced Analyzer - Sistema Avançado de Análise v5.0

Funcionalidades:
- Detecção e tratamento de outliers (IQR, Z-score, MAD, Winsorization)
- Walk-forward analysis (prevenção de overfitting)
- Market regime analysis (volatilidade, tendência)
- Temporal patterns (hora, dia, duração)
- Trade characteristics (streaks, BE/TS aggressiveness)
- Rogers-Satchell volatility
- ATR normalization
- Monte Carlo simulation

Autor: Sistema Nexus Confluence
Data: Janeiro 2025
Versão: 5.0 (Sprint 2)
"""

import sys
import os
from typing import List, Dict, Tuple, Optional
from datetime import datetime, timedelta
from dataclasses import dataclass, field
import numpy as np
from scipy import stats

# Import from production_analyzer
sys.path.insert(0, os.path.dirname(__file__))
from production_analyzer import Trade, PerformanceMetrics, MetricsCalculator


# ============================================================================
# DATA STRUCTURES
# ============================================================================

@dataclass
class OutlierReport:
    """Relatório de análise de outliers"""
    method: str  # 'IQR', 'Z-score', 'Modified Z-score'
    n_outliers: int
    outlier_indices: List[int]
    outlier_values: List[float]
    threshold_lower: float
    threshold_upper: float
    pct_outliers: float


@dataclass
class WalkForwardResult:
    """Resultado de walk-forward analysis"""
    period: int
    train_start: datetime
    train_end: datetime
    test_start: datetime
    test_end: datetime
    train_metrics: PerformanceMetrics
    test_metrics: PerformanceMetrics
    degradation: Dict[str, float]
    is_overfitted: bool


@dataclass
class RegimeAnalysis:
    """Análise por regime de mercado"""
    regime_name: str  # 'low_vol', 'medium_vol', 'high_vol', etc
    n_trades: int
    metrics: PerformanceMetrics
    atr_range: Tuple[float, float]


@dataclass
class TemporalPattern:
    """Padrão temporal identificado"""
    pattern_type: str  # 'hour', 'weekday', 'duration'
    category: str  # '09', 'Monday', 'short', etc
    n_trades: int
    metrics: PerformanceMetrics


@dataclass
class StreakAnalysis:
    """Análise de sequências win/loss"""
    max_win_streak: int
    max_loss_streak: int
    avg_win_streak: float
    avg_loss_streak: float
    current_streak_type: str
    current_streak_length: int
    streaks: List[Tuple[str, int]]


# ============================================================================
# OUTLIER DETECTION
# ============================================================================

class OutlierDetector:
    """
    Detector de outliers com múltiplos métodos
    
    Métodos:
    1. IQR (Interquartile Range): Q1-1.5*IQR, Q3+1.5*IQR
    2. Z-score: |z| > threshold (padrão 3.0)
    3. Modified Z-score: MAD-based (mais robusto)
    4. Winsorization: Clip em percentis
    """
    
    def __init__(self):
        self.reports = []
    
    def detect_iqr(self, data: np.ndarray, multiplier: float = 1.5) -> OutlierReport:
        """
        Detecta outliers usando IQR method
        
        Args:
            data: Array de valores
            multiplier: Multiplicador do IQR (padrão 1.5, use 3.0 para extremos)
        
        Returns:
            OutlierReport com detalhes
        """
        if len(data) < 4:
            return OutlierReport('IQR', 0, [], [], 0, 0, 0)
        
        Q1 = np.percentile(data, 25)
        Q3 = np.percentile(data, 75)
        IQR = Q3 - Q1
        
        lower_bound = Q1 - multiplier * IQR
        upper_bound = Q3 + multiplier * IQR
        
        outlier_mask = (data < lower_bound) | (data > upper_bound)
        outlier_indices = np.where(outlier_mask)[0].tolist()
        outlier_values = data[outlier_mask].tolist()
        
        return OutlierReport(
            method='IQR',
            n_outliers=len(outlier_indices),
            outlier_indices=outlier_indices,
            outlier_values=outlier_values,
            threshold_lower=lower_bound,
            threshold_upper=upper_bound,
            pct_outliers=len(outlier_indices) / len(data) * 100
        )
    
    def detect_zscore(self, data: np.ndarray, threshold: float = 3.0) -> OutlierReport:
        """
        Detecta outliers usando Z-score
        
        Args:
            data: Array de valores
            threshold: Threshold para |z| (padrão 3.0)
        
        Returns:
            OutlierReport com detalhes
        """
        if len(data) < 3:
            return OutlierReport('Z-score', 0, [], [], 0, 0, 0)
        
        mean = np.mean(data)
        std = np.std(data, ddof=1)
        
        if std == 0:
            return OutlierReport('Z-score', 0, [], [], mean, mean, 0)
        
        z_scores = np.abs((data - mean) / std)
        outlier_mask = z_scores > threshold
        outlier_indices = np.where(outlier_mask)[0].tolist()
        outlier_values = data[outlier_mask].tolist()
        
        lower_bound = mean - threshold * std
        upper_bound = mean + threshold * std
        
        return OutlierReport(
            method='Z-score',
            n_outliers=len(outlier_indices),
            outlier_indices=outlier_indices,
            outlier_values=outlier_values,
            threshold_lower=lower_bound,
            threshold_upper=upper_bound,
            pct_outliers=len(outlier_indices) / len(data) * 100
        )
    
    def detect_modified_zscore(self, data: np.ndarray, threshold: float = 3.5) -> OutlierReport:
        """
        Detecta outliers usando Modified Z-score (MAD-based)
        
        Mais robusto que Z-score tradicional pois usa mediana
        
        Args:
            data: Array de valores
            threshold: Threshold (padrão 3.5, equivalente a 3.0 do Z-score)
        
        Returns:
            OutlierReport com detalhes
        """
        if len(data) < 3:
            return OutlierReport('Modified Z-score', 0, [], [], 0, 0, 0)
        
        median = np.median(data)
        mad = np.median(np.abs(data - median))
        
        if mad == 0:
            return OutlierReport('Modified Z-score', 0, [], [], median, median, 0)
        
        # Modified Z-score = 0.6745 * (x - median) / MAD
        modified_z_scores = np.abs(0.6745 * (data - median) / mad)
        outlier_mask = modified_z_scores > threshold
        outlier_indices = np.where(outlier_mask)[0].tolist()
        outlier_values = data[outlier_mask].tolist()
        
        # Aproximar bounds
        lower_bound = median - threshold * mad / 0.6745
        upper_bound = median + threshold * mad / 0.6745
        
        return OutlierReport(
            method='Modified Z-score',
            n_outliers=len(outlier_indices),
            outlier_indices=outlier_indices,
            outlier_values=outlier_values,
            threshold_lower=lower_bound,
            threshold_upper=upper_bound,
            pct_outliers=len(outlier_indices) / len(data) * 100
        )
    
    def winsorize(self, data: np.ndarray, limits: Tuple[float, float] = (0.05, 0.95)) -> np.ndarray:
        """
        Winsoriza dados limitando extremos
        
        Args:
            data: Array de valores
            limits: Tuple (lower_percentile, upper_percentile)
        
        Returns:
            Array winsorizado
        """
        lower = np.percentile(data, limits[0] * 100)
        upper = np.percentile(data, limits[1] * 100)
        return np.clip(data, lower, upper)
    
    def analyze_trades_outliers(self, trades: List[Trade]) -> Dict:
        """
        Análise completa de outliers em trades
        
        Args:
            trades: Lista de trades
        
        Returns:
            Dict com análises de profit e R-multiple
        """
        if len(trades) < 10:
            return {'error': 'Insufficient data (need >= 10 trades)'}
        
        # Extrair dados
        profits = np.array([t.profit for t in trades if t.profit is not None])
        r_multiples = np.array([t.r_multiple for t in trades if t.r_multiple is not None])
        
        results = {
            'profit_analysis': {},
            'r_multiple_analysis': {},
            'outlier_trades': []
        }
        
        # Análise de profits
        if len(profits) >= 10:
            results['profit_analysis'] = {
                'iqr': self.detect_iqr(profits),
                'zscore': self.detect_zscore(profits),
                'modified_zscore': self.detect_modified_zscore(profits),
                'winsorized_mean': np.mean(self.winsorize(profits)),
                'original_mean': np.mean(profits),
                'impact': abs(np.mean(self.winsorize(profits)) - np.mean(profits))
            }
        
        # Análise de R-multiples
        if len(r_multiples) >= 10:
            results['r_multiple_analysis'] = {
                'iqr': self.detect_iqr(r_multiples),
                'zscore': self.detect_zscore(r_multiples),
                'modified_zscore': self.detect_modified_zscore(r_multiples),
                'winsorized_mean': np.mean(self.winsorize(r_multiples)),
                'original_mean': np.mean(r_multiples),
                'impact': abs(np.mean(self.winsorize(r_multiples)) - np.mean(r_multiples))
            }
        
        # Identificar trades outliers (união de todos métodos)
        outlier_indices_set = set()
        if len(profits) >= 10:
            outlier_indices_set.update(results['profit_analysis']['iqr'].outlier_indices)
            outlier_indices_set.update(results['profit_analysis']['zscore'].outlier_indices)
        
        results['outlier_trades'] = [trades[i] for i in sorted(outlier_indices_set) if i < len(trades)]
        results['n_outlier_trades'] = len(results['outlier_trades'])
        results['pct_outlier_trades'] = len(results['outlier_trades']) / len(trades) * 100
        
        return results


# ============================================================================
# OVERFITTING PREVENTION
# ============================================================================

class WalkForwardAnalyzer:
    """
    Walk-Forward Analysis para validação out-of-sample
    
    Implementa:
    - Train/test split temporal
    - Rolling window analysis
    - Degradation detection
    - Monte Carlo simulation
    """
    
    def __init__(self, train_pct: float = 0.7):
        """
        Args:
            train_pct: Percentual para treino (padrão 70%)
        """
        self.train_pct = train_pct
    
    def split_temporal(self, trades: List[Trade]) -> Tuple[List[Trade], List[Trade]]:
        """
        Split temporal em train/test
        
        Args:
            trades: Lista de trades
        
        Returns:
            Tuple (train_trades, test_trades)
        """
        sorted_trades = sorted(trades, key=lambda t: t.open_time)
        split_idx = int(len(sorted_trades) * self.train_pct)
        
        return sorted_trades[:split_idx], sorted_trades[split_idx:]
    
    def rolling_window_analysis(
        self, 
        trades: List[Trade],
        train_months: int = 6,
        test_months: int = 2
    ) -> List[WalkForwardResult]:
        """
        Análise rolling window
        
        Args:
            trades: Lista de trades
            train_months: Meses para treino
            test_months: Meses para teste
        
        Returns:
            Lista de WalkForwardResult
        """
        sorted_trades = sorted(trades, key=lambda t: t.open_time)
        
        if len(sorted_trades) < 20:
            return []
        
        # Agrupar por mês
        trades_by_month = self._group_by_month(sorted_trades)
        
        results = []
        calc = MetricsCalculator()
        
        for i in range(len(trades_by_month) - train_months - test_months + 1):
            # Dados de treino
            train_trades_nested = trades_by_month[i:i+train_months]
            train_trades = [t for month in train_trades_nested for t in month]
            
            # Dados de teste
            test_trades_nested = trades_by_month[i+train_months:i+train_months+test_months]
            test_trades = [t for month in test_trades_nested for t in month]
            
            if len(train_trades) < 10 or len(test_trades) < 5:
                continue
            
            # Calcular métricas
            train_metrics = calc.calculate_all_metrics(train_trades)
            test_metrics = calc.calculate_all_metrics(test_trades)
            
            # Calcular degradação
            degradation = {
                'win_rate': test_metrics.win_rate - train_metrics.win_rate,
                'sharpe': test_metrics.sharpe_ratio - train_metrics.sharpe_ratio,
                'expectancy_r': test_metrics.expectancy_r - train_metrics.expectancy_r,
                'profit_factor': test_metrics.profit_factor - train_metrics.profit_factor
            }
            
            # Detectar overfitting (degradação > 20% em múltiplas métricas)
            degradation_flags = [
                abs(degradation['win_rate']) > 20,
                abs(degradation['sharpe']) > 0.5,
                degradation['expectancy_r'] < -0.2
            ]
            is_overfitted = sum(degradation_flags) >= 2
            
            results.append(WalkForwardResult(
                period=i,
                train_start=train_trades[0].open_time,
                train_end=train_trades[-1].open_time,
                test_start=test_trades[0].open_time,
                test_end=test_trades[-1].open_time,
                train_metrics=train_metrics,
                test_metrics=test_metrics,
                degradation=degradation,
                is_overfitted=is_overfitted
            ))
        
        return results
    
    def monte_carlo_simulation(
        self, 
        trades: List[Trade], 
        n_simulations: int = 10000,
        seed: int = 42
    ) -> Dict:
        """
        Monte Carlo simulation para testar luck vs skill
        
        Null hypothesis: Sem skill, resultados são aleatórios
        
        Args:
            trades: Lista de trades
            n_simulations: Número de simulações
            seed: Seed para reprodutibilidade
        
        Returns:
            Dict com resultados e p-value
        """
        if len(trades) < 20:
            return {'error': 'Insufficient data (need >= 20 trades)'}
        
        rng = np.random.default_rng(seed)
        profits = np.array([t.profit for t in trades if t.profit is not None])
        
        if len(profits) < 20:
            return {'error': 'Insufficient profit data'}
        
        # Métricas reais
        actual_sharpe = MetricsCalculator.calculate_sharpe_ratio(profits)
        actual_expectancy = np.mean(profits)
        actual_wr = np.mean(profits > 0) * 100
        
        # Simulações
        simulated_sharpes = []
        simulated_expectancies = []
        simulated_wrs = []
        
        print(f"  Monte Carlo: {n_simulations:,} simulations...", end='', flush=True)
        
        for _ in range(n_simulations):
            # Embaralhar (null hypothesis: sem skill)
            shuffled = rng.permutation(profits)
            
            sim_sharpe = MetricsCalculator.calculate_sharpe_ratio(shuffled)
            sim_exp = np.mean(shuffled)
            sim_wr = np.mean(shuffled > 0) * 100
            
            simulated_sharpes.append(sim_sharpe)
            simulated_expectancies.append(sim_exp)
            simulated_wrs.append(sim_wr)
        
        print(" Done!")
        
        # P-values (one-tailed: métricas atuais melhores que aleatório?)
        p_value_sharpe = np.mean([s >= actual_sharpe for s in simulated_sharpes])
        p_value_exp = np.mean([e >= actual_expectancy for e in simulated_expectancies])
        p_value_wr = np.mean([w >= actual_wr for w in simulated_wrs])
        
        return {
            'n_simulations': n_simulations,
            'actual': {
                'sharpe': actual_sharpe,
                'expectancy': actual_expectancy,
                'win_rate': actual_wr
            },
            'simulated': {
                'sharpe_mean': np.mean(simulated_sharpes),
                'sharpe_std': np.std(simulated_sharpes),
                'expectancy_mean': np.mean(simulated_expectancies),
                'expectancy_std': np.std(simulated_expectancies),
                'wr_mean': np.mean(simulated_wrs),
                'wr_std': np.std(simulated_wrs)
            },
            'p_values': {
                'sharpe': p_value_sharpe,
                'expectancy': p_value_exp,
                'win_rate': p_value_wr
            },
            'is_significant': {
                'sharpe': p_value_sharpe < 0.05,
                'expectancy': p_value_exp < 0.05,
                'win_rate': p_value_wr < 0.05
            },
            'confidence_level': {
                'sharpe': 'HIGH' if p_value_sharpe < 0.01 else 'MEDIUM' if p_value_sharpe < 0.05 else 'LOW',
                'expectancy': 'HIGH' if p_value_exp < 0.01 else 'MEDIUM' if p_value_exp < 0.05 else 'LOW',
                'win_rate': 'HIGH' if p_value_wr < 0.01 else 'MEDIUM' if p_value_wr < 0.05 else 'LOW'
            }
        }
    
    def _group_by_month(self, trades: List[Trade]) -> List[List[Trade]]:
        """Agrupa trades por mês"""
        if not trades:
            return []
        
        trades_by_month = []
        current_month = []
        current_key = None
        
        for trade in trades:
            month_key = (trade.open_time.year, trade.open_time.month)
            
            if current_key is None:
                current_key = month_key
                current_month = [trade]
            elif month_key == current_key:
                current_month.append(trade)
            else:
                trades_by_month.append(current_month)
                current_month = [trade]
                current_key = month_key
        
        if current_month:
            trades_by_month.append(current_month)
        
        return trades_by_month


# ============================================================================
# MARKET REGIME ANALYSIS
# ============================================================================

class MarketRegimeAnalyzer:
    """
    Análise por regimes de mercado
    
    Classifica por:
    - Volatilidade (low/medium/high via ATR terciles)
    - Tendência (up/down/sideways)
    - Normaliza distâncias por ATR
    - Calcula Rogers-Satchell volatility
    """
    
    def __init__(self):
        pass
    
    def classify_volatility_regimes(
        self, 
        trades: List[Trade], 
        atr_data: Dict[str, float]
    ) -> Dict[str, RegimeAnalysis]:
        """
        Classifica trades por regime de volatilidade
        
        Args:
            trades: Lista de trades
            atr_data: Dict {date_str: atr_value}
        
        Returns:
            Dict de RegimeAnalysis por regime
        """
        if len(trades) < 30:
            return {}
        
        # Calcular tercis de ATR
        atr_values = list(atr_data.values())
        if len(atr_values) < 10:
            return {}
        
        p33 = np.percentile(atr_values, 33)
        p66 = np.percentile(atr_values, 66)
        
        regimes = {
            'low_volatility': [],
            'medium_volatility': [],
            'high_volatility': []
        }
        
        for trade in trades:
            date_key = trade.open_time.strftime('%Y-%m-%d')
            atr = atr_data.get(date_key, 0)
            
            if atr == 0:
                continue
            
            if atr < p33:
                regimes['low_volatility'].append(trade)
            elif atr < p66:
                regimes['medium_volatility'].append(trade)
            else:
                regimes['high_volatility'].append(trade)
        
        # Calcular métricas por regime
        results = {}
        calc = MetricsCalculator()
        
        for regime_name, regime_trades in regimes.items():
            if len(regime_trades) >= 10:
                metrics = calc.calculate_all_metrics(regime_trades)
                
                # Determinar ATR range
                atr_range_values = [
                    atr_data.get(t.open_time.strftime('%Y-%m-%d'), 0) 
                    for t in regime_trades
                ]
                atr_range_values = [a for a in atr_range_values if a > 0]
                
                if atr_range_values:
                    atr_range = (min(atr_range_values), max(atr_range_values))
                else:
                    atr_range = (0, 0)
                
                results[regime_name] = RegimeAnalysis(
                    regime_name=regime_name,
                    n_trades=len(regime_trades),
                    metrics=metrics,
                    atr_range=atr_range
                )
        
        return results
    
    @staticmethod
    def normalize_by_atr(distance: float, atr: float) -> float:
        """
        Normaliza distância por ATR
        
        Args:
            distance: Distância em preço/pips
            atr: ATR do período
        
        Returns:
            Distância normalizada (múltiplos de ATR)
        """
        return distance / atr if atr > 0 else 0
    
    @staticmethod
    def calculate_rogers_satchell(
        high: float, 
        low: float, 
        close: float, 
        open_price: float
    ) -> float:
        """
        Rogers-Satchell Volatility Estimator
        
        σ_RS = sqrt(E[ln(H/C)*ln(H/O) + ln(L/C)*ln(L/O)])
        
        Usa toda informação intraday, mais robusto que close-to-close
        
        Args:
            high: Máxima do período
            low: Mínima do período
            close: Fechamento
            open_price: Abertura
        
        Returns:
            Volatilidade Rogers-Satchell
        """
        if high <= 0 or low <= 0 or close <= 0 or open_price <= 0:
            return 0.0
        
        if high == low:  # Sem movimento
            return 0.0
        
        try:
            term1 = np.log(high / close) * np.log(high / open_price)
            term2 = np.log(low / close) * np.log(low / open_price)
            
            sum_terms = term1 + term2
            
            if sum_terms < 0:
                return 0.0
            
            return np.sqrt(sum_terms)
        except:
            return 0.0
    
    def classify_be_ts_aggressiveness(
        self, 
        be_distance: float, 
        atr: float
    ) -> str:
        """
        Classifica agressividade de BE/TS
        
        Args:
            be_distance: Distância até BE/TS em pips
            atr: ATR do período
        
        Returns:
            'aggressive', 'moderate', 'conservative'
        """
        normalized = self.normalize_by_atr(be_distance, atr)
        
        if normalized < 0.8:
            return 'aggressive'  # <0.8 ATR - muito próximo
        elif normalized < 1.5:
            return 'moderate'    # 0.8-1.5 ATR - balanceado
        else:
            return 'conservative'  # >1.5 ATR - distante


# Continua na parte 2...

# ============================================================================
# TEMPORAL PATTERN ANALYSIS
# ============================================================================

class TemporalPatternAnalyzer:
    """
    Análise de padrões temporais
    
    Analisa performance por:
    - Hora do dia
    - Dia da semana
    - Duração de trade
    - Mês (sazonalidade)
    """
    
    def __init__(self):
        pass
    
    def analyze_by_hour(self, trades: List[Trade]) -> Dict[int, TemporalPattern]:
        """
        Performance por hora do dia
        
        Args:
            trades: Lista de trades
        
        Returns:
            Dict {hour: TemporalPattern}
        """
        by_hour = {}
        for trade in trades:
            hour = trade.open_time.hour
            if hour not in by_hour:
                by_hour[hour] = []
            by_hour[hour].append(trade)
        
        results = {}
        calc = MetricsCalculator()
        
        for hour, hour_trades in by_hour.items():
            if len(hour_trades) >= 5:
                metrics = calc.calculate_all_metrics(hour_trades)
                results[hour] = TemporalPattern(
                    pattern_type='hour',
                    category=f'{hour:02d}:00',
                    n_trades=len(hour_trades),
                    metrics=metrics
                )
        
        return results
    
    def analyze_by_weekday(self, trades: List[Trade]) -> Dict[str, TemporalPattern]:
        """
        Performance por dia da semana
        
        Args:
            trades: Lista de trades
        
        Returns:
            Dict {weekday_name: TemporalPattern}
        """
        weekday_names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
        by_weekday = {day: [] for day in weekday_names}
        
        for trade in trades:
            weekday = weekday_names[trade.open_time.weekday()]
            by_weekday[weekday].append(trade)
        
        results = {}
        calc = MetricsCalculator()
        
        for day, day_trades in by_weekday.items():
            if len(day_trades) >= 5:
                metrics = calc.calculate_all_metrics(day_trades)
                results[day] = TemporalPattern(
                    pattern_type='weekday',
                    category=day,
                    n_trades=len(day_trades),
                    metrics=metrics
                )
        
        return results
    
    def analyze_by_duration(self, trades: List[Trade]) -> Dict[str, TemporalPattern]:
        """
        Performance por duração de trade
        
        Categorias:
        - short: <1h
        - medium: 1-4h
        - long: >4h
        
        Args:
            trades: Lista de trades
        
        Returns:
            Dict {duration_category: TemporalPattern}
        """
        durations = {'short': [], 'medium': [], 'long': []}
        
        for trade in trades:
            if trade.duration_minutes is None:
                # Calcular duração se não existir
                if trade.close_time and trade.open_time:
                    duration_minutes = (trade.close_time - trade.open_time).total_seconds() / 60
                else:
                    continue
            else:
                duration_minutes = trade.duration_minutes
            
            if duration_minutes < 60:  # <1h
                durations['short'].append(trade)
            elif duration_minutes < 240:  # 1-4h
                durations['medium'].append(trade)
            else:  # >4h
                durations['long'].append(trade)
        
        results = {}
        calc = MetricsCalculator()
        
        for duration_cat, duration_trades in durations.items():
            if len(duration_trades) >= 5:
                metrics = calc.calculate_all_metrics(duration_trades)
                results[duration_cat] = TemporalPattern(
                    pattern_type='duration',
                    category=duration_cat,
                    n_trades=len(duration_trades),
                    metrics=metrics
                )
        
        return results
    
    def analyze_by_month(self, trades: List[Trade]) -> Dict[str, TemporalPattern]:
        """
        Performance por mês (sazonalidade)
        
        Args:
            trades: Lista de trades
        
        Returns:
            Dict {month_name: TemporalPattern}
        """
        month_names = ['January', 'February', 'March', 'April', 'May', 'June',
                      'July', 'August', 'September', 'October', 'November', 'December']
        
        by_month = {month: [] for month in month_names}
        
        for trade in trades:
            month = month_names[trade.open_time.month - 1]
            by_month[month].append(trade)
        
        results = {}
        calc = MetricsCalculator()
        
        for month, month_trades in by_month.items():
            if len(month_trades) >= 5:
                metrics = calc.calculate_all_metrics(month_trades)
                results[month] = TemporalPattern(
                    pattern_type='month',
                    category=month,
                    n_trades=len(month_trades),
                    metrics=metrics
                )
        
        return results


# ============================================================================
# TRADE CHARACTERISTICS ANALYSIS
# ============================================================================

class TradeCharacteristicsAnalyzer:
    """
    Análise de características dos trades
    
    Analisa:
    - Win/Loss streaks
    - Performance por setup class
    - Performance por exit type (TP1, TP2, SL, TS)
    - BE/TS aggressiveness impact
    """
    
    def __init__(self):
        pass
    
    def analyze_win_loss_streaks(self, trades: List[Trade]) -> StreakAnalysis:
        """
        Analisa sequências de wins/losses
        
        Args:
            trades: Lista de trades
        
        Returns:
            StreakAnalysis com detalhes
        """
        if len(trades) < 2:
            return StreakAnalysis(0, 0, 0, 0, 'UNKNOWN', 0, [])
        
        sorted_trades = sorted(trades, key=lambda t: t.open_time)
        
        current_streak = 0
        streak_type = None
        max_win_streak = 0
        max_loss_streak = 0
        streaks = []
        
        for trade in sorted_trades:
            if trade.profit is None:
                continue
            
            is_win = trade.profit > 0
            
            if streak_type is None:
                streak_type = 'win' if is_win else 'loss'
                current_streak = 1
            elif (is_win and streak_type == 'win') or (not is_win and streak_type == 'loss'):
                current_streak += 1
            else:
                # Streak quebrou
                streaks.append((streak_type, current_streak))
                
                if streak_type == 'win':
                    max_win_streak = max(max_win_streak, current_streak)
                else:
                    max_loss_streak = max(max_loss_streak, current_streak)
                
                streak_type = 'win' if is_win else 'loss'
                current_streak = 1
        
        # Última streak
        if current_streak > 0:
            streaks.append((streak_type, current_streak))
            if streak_type == 'win':
                max_win_streak = max(max_win_streak, current_streak)
            else:
                max_loss_streak = max(max_loss_streak, current_streak)
        
        # Calcular médias
        win_streaks = [s[1] for s in streaks if s[0] == 'win']
        loss_streaks = [s[1] for s in streaks if s[0] == 'loss']
        
        avg_win_streak = np.mean(win_streaks) if win_streaks else 0
        avg_loss_streak = np.mean(loss_streaks) if loss_streaks else 0
        
        return StreakAnalysis(
            max_win_streak=max_win_streak,
            max_loss_streak=max_loss_streak,
            avg_win_streak=avg_win_streak,
            avg_loss_streak=avg_loss_streak,
            current_streak_type=streak_type if streak_type else 'UNKNOWN',
            current_streak_length=current_streak,
            streaks=streaks
        )
    
    def analyze_by_setup_class(self, trades: List[Trade]) -> Dict[str, PerformanceMetrics]:
        """
        Performance por setup class (PREMIUM vs GOOD)
        
        Args:
            trades: Lista de trades
        
        Returns:
            Dict {setup_class: PerformanceMetrics}
        """
        by_class = {}
        for trade in trades:
            if trade.setup_class:
                if trade.setup_class not in by_class:
                    by_class[trade.setup_class] = []
                by_class[trade.setup_class].append(trade)
        
        results = {}
        calc = MetricsCalculator()
        
        for setup_class, class_trades in by_class.items():
            if len(class_trades) >= 5:
                results[setup_class] = calc.calculate_all_metrics(class_trades)
        
        return results
    
    def analyze_by_exit_type(self, trades: List[Trade]) -> Dict[str, PerformanceMetrics]:
        """
        Performance por tipo de saída (TP1, TP2, SL, TS, MANUAL)
        
        Args:
            trades: Lista de trades
        
        Returns:
            Dict {exit_type: PerformanceMetrics}
        """
        by_exit = {}
        for trade in trades:
            if trade.close_reason:
                if trade.close_reason not in by_exit:
                    by_exit[trade.close_reason] = []
                by_exit[trade.close_reason].append(trade)
        
        results = {}
        calc = MetricsCalculator()
        
        for exit_type, exit_trades in by_exit.items():
            if len(exit_trades) >= 3:
                results[exit_type] = calc.calculate_all_metrics(exit_trades)
        
        return results
    
    def analyze_be_ts_effectiveness(self, trades: List[Trade]) -> Dict:
        """
        Analisa efetividade de BE/TS
        
        Args:
            trades: Lista de trades
        
        Returns:
            Dict com estatísticas
        """
        be_activated = [t for t in trades if t.be_activated]
        ts_activated = [t for t in trades if t.ts_activated]
        tp2_hit = [t for t in trades if t.tp2_hit]
        
        results = {
            'be_stats': {
                'n_trades': len(be_activated),
                'pct_of_total': len(be_activated) / len(trades) * 100 if trades else 0,
                'avg_profit': np.mean([t.profit for t in be_activated if t.profit is not None]) if be_activated else 0,
                'win_rate': np.mean([t.profit > 0 for t in be_activated if t.profit is not None]) * 100 if be_activated else 0
            },
            'ts_stats': {
                'n_trades': len(ts_activated),
                'pct_of_total': len(ts_activated) / len(trades) * 100 if trades else 0,
                'avg_profit': np.mean([t.profit for t in ts_activated if t.profit is not None]) if ts_activated else 0,
                'win_rate': np.mean([t.profit > 0 for t in ts_activated if t.profit is not None]) * 100 if ts_activated else 0
            },
            'tp2_stats': {
                'n_trades': len(tp2_hit),
                'pct_of_total': len(tp2_hit) / len(trades) * 100 if trades else 0,
                'avg_profit': np.mean([t.profit for t in tp2_hit if t.profit is not None]) if tp2_hit else 0
            }
        }
        
        return results


# ============================================================================
# MAIN ADVANCED ANALYZER
# ============================================================================

class AdvancedAnalyzer:
    """
    Analisador avançado completo
    
    Orquestra todas análises:
    - Outliers
    - Walk-forward
    - Market regimes
    - Temporal patterns
    - Trade characteristics
    """
    
    def __init__(self, seed: int = 42):
        """
        Args:
            seed: Seed para reprodutibilidade
        """
        self.seed = seed
        self.outlier_detector = OutlierDetector()
        self.walkforward_analyzer = WalkForwardAnalyzer()
        self.regime_analyzer = MarketRegimeAnalyzer()
        self.temporal_analyzer = TemporalPatternAnalyzer()
        self.characteristics_analyzer = TradeCharacteristicsAnalyzer()
    
    def analyze_complete(
        self, 
        trades: List[Trade],
        atr_data: Optional[Dict[str, float]] = None
    ) -> Dict:
        """
        Análise completa de todos aspectos
        
        Args:
            trades: Lista de trades
            atr_data: Dados de ATR por data (opcional)
        
        Returns:
            Dict com todas análises
        """
        if len(trades) < 20:
            return {'error': 'Insufficient data (need >= 20 trades)'}
        
        print("\n" + "="*70)
        print("🔬 ADVANCED ANALYSIS - Sistema v5.0")
        print("="*70)
        
        results = {
            'metadata': {
                'timestamp': datetime.now().isoformat(),
                'n_trades': len(trades),
                'seed': self.seed
            }
        }
        
        # 1. Outlier Analysis
        print("\n📊 Phase 1: Outlier Detection")
        print("-" * 70)
        results['outliers'] = self.outlier_detector.analyze_trades_outliers(trades)
        print(f"  Outliers detected: {results['outliers'].get('n_outlier_trades', 0)} trades")
        print(f"  ({results['outliers'].get('pct_outlier_trades', 0):.1f}% of total)")
        
        # 2. Walk-Forward Analysis
        print("\n📈 Phase 2: Walk-Forward Analysis")
        print("-" * 70)
        train, test = self.walkforward_analyzer.split_temporal(trades)
        print(f"  Train set: {len(train)} trades")
        print(f"  Test set: {len(test)} trades")
        
        if len(train) >= 10 and len(test) >= 5:
            train_metrics = MetricsCalculator().calculate_all_metrics(train)
            test_metrics = MetricsCalculator().calculate_all_metrics(test)
            
            results['walk_forward'] = {
                'train_metrics': train_metrics,
                'test_metrics': test_metrics,
                'degradation': {
                    'win_rate': test_metrics.win_rate - train_metrics.win_rate,
                    'sharpe': test_metrics.sharpe_ratio - train_metrics.sharpe_ratio,
                    'expectancy_r': test_metrics.expectancy_r - train_metrics.expectancy_r
                }
            }
            
            print(f"  Degradation:")
            print(f"    Win Rate: {results['walk_forward']['degradation']['win_rate']:+.1f}%")
            print(f"    Sharpe: {results['walk_forward']['degradation']['sharpe']:+.2f}")
            print(f"    Expectancy R: {results['walk_forward']['degradation']['expectancy_r']:+.3f}R")
        
        # 3. Monte Carlo Simulation
        print("\n🎲 Phase 3: Monte Carlo Simulation")
        print("-" * 70)
        results['monte_carlo'] = self.walkforward_analyzer.monte_carlo_simulation(trades, seed=self.seed)
        
        if 'p_values' in results['monte_carlo']:
            print(f"  P-values:")
            print(f"    Win Rate: {results['monte_carlo']['p_values']['win_rate']:.4f} " +
                  f"({results['monte_carlo']['confidence_level']['win_rate']})")
            print(f"    Sharpe: {results['monte_carlo']['p_values']['sharpe']:.4f} " +
                  f"({results['monte_carlo']['confidence_level']['sharpe']})")
            print(f"    Expectancy: {results['monte_carlo']['p_values']['expectancy']:.4f} " +
                  f"({results['monte_carlo']['confidence_level']['expectancy']})")
        
        # 4. Market Regime Analysis (se tiver ATR data)
        if atr_data and len(atr_data) > 0:
            print("\n🌐 Phase 4: Market Regime Analysis")
            print("-" * 70)
            results['regimes'] = self.regime_analyzer.classify_volatility_regimes(trades, atr_data)
            
            for regime_name, regime_analysis in results['regimes'].items():
                print(f"  {regime_name}: {regime_analysis.n_trades} trades, " +
                      f"WR={regime_analysis.metrics.win_rate:.1f}%, " +
                      f"Sharpe={regime_analysis.metrics.sharpe_ratio:.2f}")
        
        # 5. Temporal Patterns
        print("\n⏰ Phase 5: Temporal Pattern Analysis")
        print("-" * 70)
        results['temporal'] = {}
        
        results['temporal']['by_hour'] = self.temporal_analyzer.analyze_by_hour(trades)
        print(f"  Hours analyzed: {len(results['temporal']['by_hour'])}")
        
        results['temporal']['by_weekday'] = self.temporal_analyzer.analyze_by_weekday(trades)
        print(f"  Weekdays analyzed: {len(results['temporal']['by_weekday'])}")
        
        results['temporal']['by_duration'] = self.temporal_analyzer.analyze_by_duration(trades)
        print(f"  Duration categories: {len(results['temporal']['by_duration'])}")
        
        # 6. Trade Characteristics
        print("\n🎯 Phase 6: Trade Characteristics Analysis")
        print("-" * 70)
        results['characteristics'] = {}
        
        results['characteristics']['streaks'] = self.characteristics_analyzer.analyze_win_loss_streaks(trades)
        print(f"  Max win streak: {results['characteristics']['streaks'].max_win_streak}")
        print(f"  Max loss streak: {results['characteristics']['streaks'].max_loss_streak}")
        
        results['characteristics']['by_setup'] = self.characteristics_analyzer.analyze_by_setup_class(trades)
        print(f"  Setup classes analyzed: {len(results['characteristics']['by_setup'])}")
        
        results['characteristics']['by_exit'] = self.characteristics_analyzer.analyze_by_exit_type(trades)
        print(f"  Exit types analyzed: {len(results['characteristics']['by_exit'])}")
        
        results['characteristics']['be_ts_effectiveness'] = self.characteristics_analyzer.analyze_be_ts_effectiveness(trades)
        
        print("\n" + "="*70)
        print("✅ Advanced Analysis Complete!")
        print("="*70)
        
        return results


# ============================================================================
# MAIN EXECUTION
# ============================================================================

if __name__ == '__main__':
    print("Advanced Analyzer - Sistema v5.0")
    print("Use: from advanced_analyzer import AdvancedAnalyzer")
    print("\nExample:")
    print("  analyzer = AdvancedAnalyzer()")
    print("  results = analyzer.analyze_complete(trades, atr_data)")
