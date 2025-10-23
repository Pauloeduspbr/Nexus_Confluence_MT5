#!/usr/bin/env python3
"""
Master Analyzer - Pipeline Completo v5.0

Orquestra análise completa end-to-end:
1. Validação de dados
2. Production analysis (métricas básicas + avançadas)
3. Advanced analysis (outliers, overfitting, regimes, temporal)
4. Correlação de resultados
5. Detecção de anomalias
6. Geração de recomendações automáticas
7. Geração de arquivo .set otimizado
8. Export JSON estruturado
9. Logs detalhados
10. Finalização e summary

Autor: Sistema Nexus Confluence
Data: Janeiro 2025
Versão: 5.0 (Sprint 3)
"""

import sys
import os
import json
import argparse
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from datetime import datetime
import hashlib

# Imports internos
sys.path.insert(0, os.path.dirname(__file__))
from production_analyzer import (
    Trade, TradeReconstructor, MetricsCalculator, 
    BootstrapAnalyzer, HypothesisTests, ProductionAnalyzer
)
from advanced_analyzer import (
    AdvancedAnalyzer, OutlierDetector, WalkForwardAnalyzer,
    MarketRegimeAnalyzer, TemporalPatternAnalyzer, 
    TradeCharacteristicsAnalyzer
)


# ============================================================================
# CONFIGURATION
# ============================================================================

class AnalyzerConfig:
    """Configuração do pipeline de análise"""
    
    def __init__(self):
        # Paths
        self.log_dir = Path("log")
        self.output_dir = Path("analysis_output")
        self.presets_dir = Path("Presets")
        
        # Análise
        self.min_trades = 20
        self.train_pct = 0.7
        self.bootstrap_iterations = 10000
        self.monte_carlo_iterations = 10000
        self.seed = 42
        
        # Validação
        self.max_allowed_degradation = 0.20  # 20%
        self.min_sharpe_ratio = 0.5
        self.min_win_rate = 45.0
        self.max_drawdown_pct = 20.0
        
        # Geração de .set
        self.generate_optimized_sets = True
        self.set_templates = {
            'CONSERVATIVE': {'MaxRiskPremium': 1.0, 'TrailingDistanceMultiplier': 1.5},
            'MODERATE': {'MaxRiskPremium': 1.5, 'TrailingDistanceMultiplier': 1.2},
            'AGGRESSIVE': {'MaxRiskPremium': 2.0, 'TrailingDistanceMultiplier': 1.0}
        }
    
    def create_dirs(self):
        """Cria diretórios necessários"""
        self.output_dir.mkdir(exist_ok=True)
        self.presets_dir.mkdir(exist_ok=True)


# ============================================================================
# RECOMMENDATION ENGINE
# ============================================================================

class RecommendationEngine:
    """
    Engine de recomendações baseado em análises
    
    Gera insights acionáveis e parâmetros otimizados
    """
    
    def __init__(self):
        self.recommendations = []
        self.warnings = []
        self.optimizations = []
    
    def analyze_results(
        self, 
        production_results: Dict,
        advanced_results: Dict
    ) -> Dict:
        """
        Analisa resultados e gera recomendações
        
        Args:
            production_results: Resultados do production_analyzer
            advanced_results: Resultados do advanced_analyzer
        
        Returns:
            Dict com recomendações estruturadas
        """
        recommendations = {
            'critical': [],
            'important': [],
            'suggestions': [],
            'optimizations': {},
            'best_conditions': {},
            'avoid_conditions': {}
        }
        
        # 1. Análise de Overfitting
        if 'walk_forward' in advanced_results:
            wf = advanced_results['walk_forward']
            if 'degradation' in wf:
                deg = wf['degradation']
                
                if abs(deg.get('win_rate', 0)) > 20:
                    recommendations['critical'].append({
                        'issue': 'Overfitting Detectado',
                        'description': f"Win Rate degradou {deg['win_rate']:+.1f}% (train→test)",
                        'action': 'Reduzir complexidade do sistema ou aumentar dados de treino',
                        'priority': 'HIGH'
                    })
                
                if deg.get('sharpe', 0) < -0.5:
                    recommendations['important'].append({
                        'issue': 'Degradação de Sharpe',
                        'description': f"Sharpe degradou {deg['sharpe']:+.2f}",
                        'action': 'Revisar critérios de entrada e gestão de risco',
                        'priority': 'MEDIUM'
                    })
        
        # 2. Análise de Monte Carlo
        if 'monte_carlo' in advanced_results:
            mc = advanced_results['monte_carlo']
            if 'p_values' in mc:
                if mc['p_values'].get('sharpe', 1) > 0.05:
                    recommendations['critical'].append({
                        'issue': 'Edge Não Comprovado',
                        'description': f"P-value Sharpe = {mc['p_values']['sharpe']:.4f} (>0.05)",
                        'action': 'Sistema pode estar operando por sorte, não skill',
                        'priority': 'HIGH'
                    })
                else:
                    recommendations['suggestions'].append({
                        'issue': 'Edge Estatisticamente Significante',
                        'description': f"P-value Sharpe = {mc['p_values']['sharpe']:.4f}",
                        'action': 'Manter estratégia atual, edge comprovado',
                        'priority': 'LOW'
                    })
        
        # 3. Análise de Regimes
        if 'regimes' in advanced_results:
            best_regime = None
            worst_regime = None
            best_sharpe = -999
            worst_sharpe = 999
            
            for regime_name, regime_data in advanced_results['regimes'].items():
                sharpe = regime_data.metrics.sharpe_ratio
                if sharpe > best_sharpe:
                    best_sharpe = sharpe
                    best_regime = regime_name
                if sharpe < worst_sharpe:
                    worst_sharpe = sharpe
                    worst_regime = regime_name
            
            if best_regime:
                recommendations['best_conditions'][best_regime] = {
                    'sharpe': best_sharpe,
                    'win_rate': advanced_results['regimes'][best_regime].metrics.win_rate,
                    'trades': advanced_results['regimes'][best_regime].n_trades
                }
                
                recommendations['optimizations']['regime'] = {
                    'recommendation': f"Priorizar operações em {best_regime}",
                    'expected_improvement': f"+{(best_sharpe - worst_sharpe) * 100:.0f}% Sharpe",
                    'implementation': f"Adicionar filtro de volatilidade para operar preferencialmente em {best_regime}"
                }
            
            if worst_regime:
                recommendations['avoid_conditions'][worst_regime] = {
                    'sharpe': worst_sharpe,
                    'win_rate': advanced_results['regimes'][worst_regime].metrics.win_rate,
                    'trades': advanced_results['regimes'][worst_regime].n_trades
                }
                
                recommendations['important'].append({
                    'issue': f'Performance Ruim em {worst_regime}',
                    'description': f'Sharpe={worst_sharpe:.2f}, considerar evitar',
                    'action': f'Adicionar filtro para não operar em {worst_regime}',
                    'priority': 'MEDIUM'
                })
        
        # 4. Análise Temporal
        if 'temporal' in advanced_results and 'by_hour' in advanced_results['temporal']:
            best_hours = []
            worst_hours = []
            
            for hour, pattern in advanced_results['temporal']['by_hour'].items():
                if pattern.n_trades >= 5:
                    if pattern.metrics.win_rate > 60 and pattern.metrics.sharpe_ratio > 1.0:
                        best_hours.append((hour, pattern.metrics.win_rate, pattern.metrics.sharpe_ratio))
                    elif pattern.metrics.win_rate < 40 or pattern.metrics.sharpe_ratio < 0:
                        worst_hours.append((hour, pattern.metrics.win_rate, pattern.metrics.sharpe_ratio))
            
            if best_hours:
                best_hours.sort(key=lambda x: x[2], reverse=True)
                top_hour = best_hours[0]
                recommendations['best_conditions']['best_hours'] = [h[0] for h in best_hours[:3]]
                
                recommendations['optimizations']['timing'] = {
                    'recommendation': f"Priorizar operações às {top_hour[0]:02d}:00",
                    'expected_improvement': f"WR={top_hour[1]:.1f}%, Sharpe={top_hour[2]:.2f}",
                    'implementation': "Configurar horários prime no EA"
                }
            
            if worst_hours:
                recommendations['avoid_conditions']['worst_hours'] = [h[0] for h in worst_hours]
                recommendations['suggestions'].append({
                    'issue': 'Horários com Performance Ruim',
                    'description': f'Evitar operar nas horas: {[h[0] for h in worst_hours]}',
                    'action': 'Desabilitar trading nestes horários',
                    'priority': 'LOW'
                })
        
        # 5. Análise de Outliers
        if 'outliers' in advanced_results:
            n_outliers = advanced_results['outliers'].get('n_outlier_trades', 0)
            pct_outliers = advanced_results['outliers'].get('pct_outlier_trades', 0)
            
            if pct_outliers > 10:
                recommendations['important'].append({
                    'issue': 'Muitos Outliers',
                    'description': f'{n_outliers} trades outliers ({pct_outliers:.1f}%)',
                    'action': 'Investigar causas: slippage, gaps, notícias',
                    'priority': 'MEDIUM'
                })
        
        # 6. Análise de Streaks
        if 'characteristics' in advanced_results and 'streaks' in advanced_results['characteristics']:
            streaks = advanced_results['characteristics']['streaks']
            
            if streaks.max_loss_streak > 5:
                recommendations['important'].append({
                    'issue': 'Sequência de Perdas Alta',
                    'description': f'Máximo de {streaks.max_loss_streak} perdas consecutivas',
                    'action': 'Considerar pausar após 3-4 perdas consecutivas',
                    'priority': 'MEDIUM'
                })
        
        # 7. Otimizações de Parâmetros
        recommendations['optimizations']['risk_management'] = self._optimize_risk_parameters(
            production_results, advanced_results
        )
        
        recommendations['optimizations']['trailing_stop'] = self._optimize_trailing_parameters(
            production_results, advanced_results
        )
        
        return recommendations
    
    def _optimize_risk_parameters(self, prod_results: Dict, adv_results: Dict) -> Dict:
        """Otimiza parâmetros de gestão de risco"""
        
        # Analisar drawdown atual
        current_dd = prod_results.get('metrics', {}).get('max_drawdown_pct', 0)
        current_sharpe = prod_results.get('metrics', {}).get('sharpe_ratio', 0)
        
        # Recomendação baseada em Sharpe e Drawdown
        if current_sharpe < 1.0 or current_dd > 15:
            return {
                'recommendation': 'Reduzir Risco',
                'current_risk': '1.5-2.0%',
                'suggested_risk': '0.5-1.0%',
                'reason': 'Sharpe baixo ou drawdown alto',
                'parameters': {
                    'AccountRiskPercent': 0.5,
                    'MaxRiskPremium': 1.0
                }
            }
        elif current_sharpe > 2.0 and current_dd < 10:
            return {
                'recommendation': 'Pode Aumentar Risco Moderadamente',
                'current_risk': '1.5%',
                'suggested_risk': '2.0%',
                'reason': 'Sharpe alto e drawdown baixo',
                'parameters': {
                    'AccountRiskPercent': 2.0,
                    'MaxRiskPremium': 2.5
                }
            }
        else:
            return {
                'recommendation': 'Manter Risco Atual',
                'current_risk': '1.5%',
                'suggested_risk': '1.5%',
                'reason': 'Performance balanceada',
                'parameters': {
                    'AccountRiskPercent': 1.5,
                    'MaxRiskPremium': 2.0
                }
            }
    
    def _optimize_trailing_parameters(self, prod_results: Dict, adv_results: Dict) -> Dict:
        """Otimiza parâmetros de trailing stop"""
        
        # Analisar efetividade de TS atual
        if 'characteristics' in adv_results and 'be_ts_effectiveness' in adv_results['characteristics']:
            ts_stats = adv_results['characteristics']['be_ts_effectiveness'].get('ts_stats', {})
            ts_wr = ts_stats.get('win_rate', 0)
            ts_pct = ts_stats.get('pct_of_total', 0)
            
            if ts_wr > 80 and ts_pct > 10:
                return {
                    'recommendation': 'TS Muito Efetivo - Pode Ser Mais Agressivo',
                    'current_multiplier': 1.2,
                    'suggested_multiplier': 1.0,
                    'reason': f'TS com {ts_wr:.1f}% WR em {ts_pct:.1f}% dos trades',
                    'parameters': {
                        'TrailingDistanceMultiplier': 1.0,
                        'TrailingUseATR': True
                    }
                }
            elif ts_wr < 60:
                return {
                    'recommendation': 'TS Sendo Acionado Cedo Demais',
                    'current_multiplier': 1.2,
                    'suggested_multiplier': 1.5,
                    'reason': f'TS com apenas {ts_wr:.1f}% WR',
                    'parameters': {
                        'TrailingDistanceMultiplier': 1.5,
                        'TrailingUseATR': True
                    }
                }
        
        return {
            'recommendation': 'Manter Configuração Atual',
            'current_multiplier': 1.2,
            'suggested_multiplier': 1.2,
            'reason': 'Performance balanceada',
            'parameters': {
                'TrailingDistanceMultiplier': 1.2,
                'TrailingUseATR': True
            }
        }


# ============================================================================
# SET FILE GENERATOR
# ============================================================================

class SetFileGenerator:
    """
    Gerador de arquivos .set otimizados para MT5
    
    Cria presets baseados em análise completa
    """
    
    def __init__(self, config: AnalyzerConfig):
        self.config = config
    
    def generate_optimized_set(
        self,
        symbol: str,
        recommendations: Dict,
        profile: str = 'MODERATE'
    ) -> str:
        """
        Gera arquivo .set otimizado
        
        Args:
            symbol: Símbolo do ativo
            recommendations: Recomendações do engine
            profile: 'CONSERVATIVE', 'MODERATE', 'AGGRESSIVE'
        
        Returns:
            Conteúdo do arquivo .set
        """
        timestamp = datetime.now().strftime('%Y.%m.%d %H:%M')
        
        # Base template
        base_params = self.config.set_templates.get(profile, self.config.set_templates['MODERATE'])
        
        # Aplicar otimizações das recomendações
        if 'optimizations' in recommendations:
            if 'risk_management' in recommendations['optimizations']:
                risk_opt = recommendations['optimizations']['risk_management']
                if 'parameters' in risk_opt:
                    base_params.update(risk_opt['parameters'])
            
            if 'trailing_stop' in recommendations['optimizations']:
                ts_opt = recommendations['optimizations']['trailing_stop']
                if 'parameters' in ts_opt:
                    base_params.update(ts_opt['parameters'])
        
        # Gerar conteúdo .set
        set_content = f"""; Nexus Confluence EA v4.30 - Optimized for {symbol}
; Generated by Master Analyzer v5.0
; Profile: {profile}
; Date: {timestamp}
;
; Based on comprehensive analysis:
; - Production metrics (Sharpe, Sortino, VaR, ES)
; - Walk-forward validation
; - Monte Carlo simulation
; - Market regime analysis
; - Temporal pattern analysis
;
"""
        
        # Parâmetros de risco
        set_content += "; === RISK MANAGEMENT ===\n"
        set_content += f"AccountRiskPercent={base_params.get('AccountRiskPercent', 1.5)}||1.5||0.1||5.0||N\n"
        set_content += f"MaxRiskPremium={base_params.get('MaxRiskPremium', 2.0)}||2.0||0.1||5.0||N\n"
        set_content += "MinFreeMarginPercent=20.0||20.0||10.0||50.0||N\n"
        set_content += "\n"
        
        # Trailing Stop
        set_content += "; === TRAILING STOP ===\n"
        set_content += "EnableTrailing=true||false||0||true||N\n"
        set_content += f"TrailingUseATR={str(base_params.get('TrailingUseATR', True)).lower()}||false||0||true||N\n"
        set_content += f"TrailingDistanceMultiplier={base_params.get('TrailingDistanceMultiplier', 1.2)}||1.2||0.5||3.0||Y\n"
        set_content += "\n"
        
        # Horários (baseado em melhores horários)
        set_content += "; === TIMING ===\n"
        if 'best_conditions' in recommendations and 'best_hours' in recommendations['best_conditions']:
            best_hours = recommendations['best_conditions']['best_hours']
            if best_hours:
                set_content += f"; Best hours identified: {best_hours}\n"
                set_content += f"CustomStartHour={best_hours[0]}||10||0||23||N\n"
        else:
            set_content += "CustomStartHour=10||10||0||23||N\n"
        set_content += "CustomEndHour=18||18||0||23||N\n"
        set_content += "\n"
        
        # Filtros
        set_content += "; === FILTERS ===\n"
        set_content += "EnableWAEFilter=true||false||0||true||N\n"
        set_content += "EnableRSIOMAFilter=true||false||0||true||N\n"
        set_content += "EnableCurrencyStrengthFilter=true||false||0||true||N\n"
        set_content += "\n"
        
        # Gestão de Ordem
        set_content += "; === ORDER MANAGEMENT ===\n"
        set_content += "MaxOrdens=1||1||1||5||N\n"
        set_content += "MagicNumber=20241015||20241015||1||999999||N\n"
        set_content += "\n"
        
        # Comentários finais
        set_content += "; === RECOMMENDATIONS ===\n"
        if 'critical' in recommendations and recommendations['critical']:
            set_content += "; CRITICAL ISSUES:\n"
            for rec in recommendations['critical'][:3]:
                set_content += f";   - {rec['issue']}: {rec['description']}\n"
        
        if 'optimizations' in recommendations:
            set_content += "; OPTIMIZATIONS APPLIED:\n"
            for opt_name, opt_data in recommendations['optimizations'].items():
                if isinstance(opt_data, dict) and 'recommendation' in opt_data:
                    set_content += f";   - {opt_name}: {opt_data['recommendation']}\n"
        
        return set_content
    
    def save_set_file(self, symbol: str, content: str, profile: str) -> Path:
        """Salva arquivo .set"""
        filename = f"NexusConfluence_{symbol}_{profile}_{datetime.now().strftime('%Y%m%d')}.set"
        filepath = self.config.presets_dir / filename
        
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        
        return filepath
    
    def extract_set_parameters(self, content: str) -> Dict:
        """Extrai parâmetros principais do .set"""
        params = {}
        for line in content.split('\n'):
            if '=' in line and not line.startswith(';'):
                parts = line.split('=')
                if len(parts) >= 2:
                    key = parts[0].strip()
                    value = parts[1].split('||')[0].strip()
                    params[key] = value
        return params


# ============================================================================
# MASTER ANALYZER - PIPELINE ORCHESTRATOR
# ============================================================================

class MasterAnalyzer:
    """
    Orquestrador completo de análise
    
    Pipeline de 10 fases:
    1. Validação de dados
    2. Production analysis
    3. Advanced analysis
    4. Correlação
    5. Anomalias
    6. Recomendações
    7. Geração .set
    8. Export JSON
    9. Logs
    10. Finalização
    """
    
    def __init__(self, config: Optional[AnalyzerConfig] = None):
        self.config = config or AnalyzerConfig()
        self.config.create_dirs()
        
        self.recommendation_engine = RecommendationEngine()
        self.set_generator = SetFileGenerator(self.config)
        
        self.results = {
            'metadata': {},
            'production': {},
            'advanced': {},
            'recommendations': {},
            'optimized_sets': {},
            'validation': {},
            'summary': {}
        }
        
        self.log_messages = []
    
    def log(self, message: str, level: str = 'INFO'):
        """Log interno com timestamp"""
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        log_entry = f"[{timestamp}] [{level}] {message}"
        self.log_messages.append(log_entry)
        print(log_entry)
    
    def run_full_analysis(
        self,
        log_file: str,
        symbol: Optional[str] = None,
        generate_sets: bool = True
    ) -> Dict:
        """
        Executa pipeline completo de análise
        
        Args:
            log_file: Caminho para arquivo de log MT5
            symbol: Símbolo do ativo (detectado automaticamente se None)
            generate_sets: Se deve gerar arquivos .set otimizados
        
        Returns:
            Dict com todos os resultados
        """
        self.log("="*80)
        self.log("MASTER ANALYZER v5.0 - Pipeline Completo")
        self.log("="*80)
        
        try:
            # FASE 1: Validação de Dados
            self.log("\n[FASE 1/10] Validação de Dados", "INFO")
            trades, symbol = self._phase1_validate_data(log_file, symbol)  # CORREÇÃO: Receber símbolo detectado
            
            # FASE 2: Production Analysis
            self.log("\n[FASE 2/10] Production Analysis", "INFO")
            prod_results = self._phase2_production_analysis(trades)
            
            # FASE 3: Advanced Analysis
            self.log("\n[FASE 3/10] Advanced Analysis", "INFO")
            adv_results = self._phase3_advanced_analysis(trades)
            
            # FASE 4: Correlação de Resultados
            self.log("\n[FASE 4/10] Correlação de Resultados", "INFO")
            correlations = self._phase4_correlate_results(prod_results, adv_results)
            
            # FASE 5: Detecção de Anomalias
            self.log("\n[FASE 5/10] Detecção de Anomalias", "INFO")
            anomalies = self._phase5_detect_anomalies(prod_results, adv_results)
            
            # FASE 6: Geração de Recomendações
            self.log("\n[FASE 6/10] Geração de Recomendações", "INFO")
            recommendations = self._phase6_generate_recommendations(prod_results, adv_results)
            
            # FASE 7: Geração de Arquivos .set
            if generate_sets:
                self.log("\n[FASE 7/10] Geração de Arquivos .set Otimizados", "INFO")
                set_files = self._phase7_generate_sets(symbol or "UNKNOWN", recommendations)
            else:
                set_files = {}
                self.log("\n[FASE 7/10] Pulada (generate_sets=False)", "INFO")
            
            # FASE 8: Export JSON
            self.log("\n[FASE 8/10] Export JSON Estruturado", "INFO")
            json_path = self._phase8_export_json()
            
            # FASE 9: Geração de Logs Detalhados
            self.log("\n[FASE 9/10] Geração de Logs", "INFO")
            log_path = self._phase9_save_logs()
            
            # FASE 10: Finalização
            self.log("\n[FASE 10/10] Finalização e Summary", "INFO")
            summary = self._phase10_finalize(trades, prod_results, adv_results, recommendations)
            
            self.log("\n" + "="*80)
            self.log("ANÁLISE COMPLETA FINALIZADA COM SUCESSO", "SUCCESS")
            self.log("="*80)
            
            return self.results
        
        except Exception as e:
            self.log(f"ERRO CRÍTICO no pipeline: {e}", "ERROR")
            import traceback
            self.log(traceback.format_exc(), "ERROR")
            raise
    
    def _phase1_validate_data(self, log_file: str, symbol: Optional[str]) -> List[Trade]:
        """Fase 1: Validação e carregamento de dados"""
        
        # Verificar arquivo existe
        if not os.path.exists(log_file):
            raise FileNotFoundError(f"Arquivo não encontrado: {log_file}")
        
        self.log(f"  Arquivo: {log_file}")
        
        # Carregar trades
        reconstructor = TradeReconstructor(log_file)
        trades = reconstructor.parse_log_streaming()
        
        self.log(f"  ✓ {len(trades)} trades carregados")
        
        # Validação mínima
        if len(trades) < self.config.min_trades:
            raise ValueError(f"Trades insuficientes: {len(trades)} < {self.config.min_trades}")
        
        # Detectar símbolo se não fornecido
        if not symbol and trades:
            symbol = trades[0].symbol
            self.log(f"  ✓ Símbolo detectado: {symbol}")
        
        # Salvar metadata
        self.results['metadata'] = {
            'log_file': log_file,
            'symbol': symbol,
            'n_trades': len(trades),
            'analysis_timestamp': datetime.now().isoformat(),
            'config': {
                'min_trades': self.config.min_trades,
                'bootstrap_iterations': self.config.bootstrap_iterations,
                'seed': self.config.seed
            }
        }
        
        self.log(f"  ✓ Validação concluída")
        return trades, symbol  # CORREÇÃO: Retornar símbolo também
    
    def _phase2_production_analysis(self, trades: List[Trade]) -> Dict:
        """Fase 2: Análise production (métricas principais)"""
        
        # Calcular métricas básicas
        from production_analyzer import MetricsCalculator
        metrics = MetricsCalculator.calculate_all_metrics(trades)
        
        # Bootstrap analysis
        from production_analyzer import BootstrapAnalyzer
        bootstrap_analyzer = BootstrapAnalyzer(seed=self.config.seed)
        bootstrap_results = bootstrap_analyzer.bootstrap_all_metrics(trades)
        
        results = {
            'metrics': metrics.__dict__ if hasattr(metrics, '__dict__') else metrics,
            'bootstrap': {k: v.__dict__ if hasattr(v, '__dict__') else v 
                         for k, v in bootstrap_results.items()}
        }
        
        self.results['production'] = results
        
        # Log principais métricas
        if 'metrics' in results:
            m = results['metrics']
            self.log(f"  Win Rate: {m['win_rate']:.1f}%")
            self.log(f"  Profit Factor: {m['profit_factor']:.2f}")
            self.log(f"  Sharpe Ratio: {m['sharpe_ratio']:.2f}")
            self.log(f"  Max Drawdown: {m['max_drawdown_pct']:.1f}%")
        
        self.log(f"  ✓ Production analysis concluída")
        return results
    
    def _phase3_advanced_analysis(self, trades: List[Trade]) -> Dict:
        """Fase 3: Análise avançada (outliers, overfitting, regimes)"""
        
        from advanced_analyzer import AdvancedAnalyzer
        analyzer = AdvancedAnalyzer(seed=self.config.seed)
        
        results = analyzer.analyze_complete(trades)
        
        self.results['advanced'] = results
        
        # Log principais descobertas (com proteção de erros)
        try:
            if 'outliers' in results:
                n_outliers = results['outliers'].get('n_outlier_trades', 0)
                self.log(f"  Outliers detectados: {n_outliers}")
            
            if 'walk_forward' in results and isinstance(results['walk_forward'], dict):
                if 'degradation' in results['walk_forward']:
                    deg = results['walk_forward']['degradation']
                    wr_deg = deg.get('win_rate', 0) if isinstance(deg, dict) else 0
                    self.log(f"  Degradação WR: {wr_deg:+.1f}%")
            
            if 'regimes' in results:
                self.log(f"  Regimes analisados: {len(results['regimes'])}")
        except Exception as e:
            self.log(f"  ⚠ Erro ao logar resultados avançados: {e}", "WARNING")
        
        self.log(f"  ✓ Advanced analysis concluída")
        return results
    
    def _phase4_correlate_results(self, prod_results: Dict, adv_results: Dict) -> Dict:
        """Fase 4: Correlaciona resultados de ambas análises"""
        
        correlations = {
            'consistency_check': {},
            'cross_validation': {}
        }
        
        try:
            # Acessar métricas corretamente (pode ser dict ou objeto)
            metrics = prod_results.get('metrics', {})
            if hasattr(metrics, 'win_rate'):
                prod_wr = metrics.win_rate
            elif isinstance(metrics, dict):
                prod_wr = metrics.get('win_rate', 0)
            else:
                prod_wr = 0
            
            if 'walk_forward' in adv_results:
                wf_data = adv_results['walk_forward']
                if isinstance(wf_data, dict):
                    train_metrics = wf_data.get('train_metrics', {})
                    if hasattr(train_metrics, 'win_rate'):
                        train_wr = train_metrics.win_rate
                    elif isinstance(train_metrics, dict):
                        train_wr = train_metrics.get('win_rate', 0)
                    else:
                        train_wr = 0
                    
                    consistency = abs(prod_wr - train_wr) < 1.0
                    correlations['consistency_check']['win_rate'] = {
                        'production': prod_wr,
                        'walk_forward_train': train_wr,
                        'is_consistent': consistency
                    }
                    
                    if consistency:
                        self.log(f"  ✓ Win Rate consistente")
                    else:
                        self.log(f"  ⚠ Divergência detectada", "WARNING")
        except Exception as e:
            self.log(f"  ⚠ Erro na correlação: {e}", "WARNING")
        
        self.log(f"  ✓ Correlação concluída")
        return correlations
    
    def _phase5_detect_anomalies(self, prod_results: Dict, adv_results: Dict) -> Dict:
        """Fase 5: Detecta anomalias e problemas"""
        
        anomalies = {
            'critical': [],
            'warnings': [],
            'info': []
        }
        
        try:
            # Extrair métricas de forma segura
            metrics = prod_results.get('metrics', {})
            if hasattr(metrics, 'sharpe_ratio'):
                sharpe = metrics.sharpe_ratio
                wr = metrics.win_rate
                dd = metrics.max_drawdown_pct
            elif isinstance(metrics, dict):
                sharpe = metrics.get('sharpe_ratio', 0)
                wr = metrics.get('win_rate', 0)
                dd = metrics.get('max_drawdown_pct', 0)
            else:
                sharpe = wr = dd = 0
            
            # 1. Verificar Sharpe muito baixo
            if sharpe < self.config.min_sharpe_ratio:
                anomalies['critical'].append({
                    'type': 'LOW_SHARPE',
                    'value': sharpe,
                    'threshold': self.config.min_sharpe_ratio,
                    'message': f'Sharpe {sharpe:.2f} abaixo do mínimo'
                })
                self.log(f"  ⚠ CRITICAL: Sharpe baixo ({sharpe:.2f})", "ERROR")
            
            # 2. Verificar Win Rate muito baixo
            if wr < self.config.min_win_rate:
                anomalies['critical'].append({
                    'type': 'LOW_WIN_RATE',
                    'value': wr,
                    'threshold': self.config.min_win_rate,
                    'message': f'Win Rate {wr:.1f}% abaixo do mínimo'
                })
                self.log(f"  ⚠ CRITICAL: Win Rate baixo ({wr:.1f}%)", "ERROR")
            
            # 3. Verificar Drawdown alto
            if dd > self.config.max_drawdown_pct:
                anomalies['warnings'].append({
                    'type': 'HIGH_DRAWDOWN',
                    'value': dd,
                    'threshold': self.config.max_drawdown_pct,
                    'message': f'Drawdown {dd:.1f}% acima do máximo'
                })
                self.log(f"  ⚠ WARNING: Drawdown alto ({dd:.1f}%)", "WARNING")
            
            # 4. Verificar degradação walk-forward
            if 'walk_forward' in adv_results and isinstance(adv_results['walk_forward'], dict):
                wf = adv_results['walk_forward']
                if 'degradation' in wf and isinstance(wf['degradation'], dict):
                    deg_wr = wf['degradation'].get('win_rate', 0)
                    if abs(deg_wr) > self.config.max_allowed_degradation * 100:
                        anomalies['critical'].append({
                            'type': 'OVERFITTING',
                            'value': deg_wr,
                            'threshold': self.config.max_allowed_degradation * 100,
                            'message': 'Overfitting detectado'
                        })
                        self.log(f"  ⚠ CRITICAL: Overfitting", "ERROR")
        except Exception as e:
            self.log(f"  ⚠ Erro na detecção de anomalias: {e}", "WARNING")
        
        # Log summary
        self.log(f"  Críticos: {len(anomalies['critical'])}, Avisos: {len(anomalies['warnings'])}")
        self.log(f"  ✓ Detecção de anomalias concluída")
        
        self.results['anomalies'] = anomalies
        return anomalies
        n_critical = len(anomalies['critical'])
        n_warnings = len(anomalies['warnings'])
        
        if n_critical == 0 and n_warnings == 0:
            self.log(f"  ✓ Nenhuma anomalia detectada")
        else:
            self.log(f"  ⚠ {n_critical} críticas, {n_warnings} avisos")
        
        return anomalies
    
    def _phase6_generate_recommendations(self, prod_results: Dict, adv_results: Dict) -> Dict:
        """Fase 6: Gera recomendações baseadas em análises"""
        
        recommendations = self.recommendation_engine.analyze_results(prod_results, adv_results)
        
        self.results['recommendations'] = recommendations
        
        # Log resumo
        n_critical = len(recommendations.get('critical', []))
        n_important = len(recommendations.get('important', []))
        n_suggestions = len(recommendations.get('suggestions', []))
        
        self.log(f"  Recomendações geradas:")
        self.log(f"    - {n_critical} críticas")
        self.log(f"    - {n_important} importantes")
        self.log(f"    - {n_suggestions} sugestões")
        
        # Log principais recomendações
        if n_critical > 0:
            self.log(f"  ⚠ ATENÇÃO: {n_critical} issues críticos detectados", "WARNING")
            for rec in recommendations['critical'][:2]:
                self.log(f"    → {rec['issue']}: {rec['description']}", "WARNING")
        
        self.log(f"  ✓ Recomendações geradas")
        return recommendations
    
    def _phase7_generate_sets(self, symbol: str, recommendations: Dict) -> Dict:
        """Fase 7: Gera arquivos .set otimizados"""
        
        set_files = {}
        
        profiles = ['CONSERVATIVE', 'MODERATE', 'AGGRESSIVE']
        
        for profile in profiles:
            content = self.set_generator.generate_optimized_set(
                symbol, recommendations, profile
            )
            
            filepath = self.set_generator.save_set_file(symbol, content, profile)
            
            set_files[profile] = {
                'path': str(filepath),
                'size_bytes': len(content),
                'parameters': self.set_generator.extract_set_parameters(content)
            }
            
            self.log(f"  ✓ {profile}: {filepath.name}")
        
        self.results['optimized_sets'] = set_files
        
        self.log(f"  ✓ {len(set_files)} arquivos .set gerados")
        return set_files
    
    def _phase8_export_json(self) -> Path:
        """Fase 8: Exporta resultados completos em JSON"""
        
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        json_path = self.config.output_dir / f"master_analysis_{timestamp}.json"
        
        # Serializar resultados
        with open(json_path, 'w', encoding='utf-8') as f:
            json.dump(self.results, f, indent=2, default=str)
        
        file_size = json_path.stat().st_size
        self.log(f"  ✓ JSON exportado: {json_path.name} ({file_size:,} bytes)")
        
        return json_path
    
    def _phase9_save_logs(self) -> Path:
        """Fase 9: Salva logs detalhados"""
        
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        log_path = self.config.output_dir / f"master_log_{timestamp}.txt"
        
        with open(log_path, 'w', encoding='utf-8') as f:
            for msg in self.log_messages:
                f.write(msg + '\n')
        
        self.log(f"  ✓ Log salvo: {log_path.name}")
        return log_path
    
    def _phase10_finalize(
        self, 
        trades: List[Trade],
        prod_results: Dict,
        adv_results: Dict,
        recommendations: Dict
    ) -> Dict:
        """Fase 10: Finalização e summary executivo"""
        
        summary = {
            'analysis_date': datetime.now().isoformat(),
            'total_trades': len(trades),
            'analysis_duration_seconds': 0,  # TODO: track real time
            'key_metrics': {
                'win_rate': prod_results.get('metrics', {}).get('win_rate', 0),
                'profit_factor': prod_results.get('metrics', {}).get('profit_factor', 0),
                'sharpe_ratio': prod_results.get('metrics', {}).get('sharpe_ratio', 0),
                'max_drawdown_pct': prod_results.get('metrics', {}).get('max_drawdown_pct', 0)
            },
            'quality_score': self._calculate_quality_score(prod_results, adv_results),
            'recommendation_summary': {
                'n_critical': len(recommendations.get('critical', [])),
                'n_important': len(recommendations.get('important', [])),
                'n_suggestions': len(recommendations.get('suggestions', []))
            },
            'overfitting_risk': self._assess_overfitting_risk(adv_results),
            'best_regime': self._identify_best_regime(adv_results),
            'actionable_insights': self._extract_top_insights(recommendations)
        }
        
        self.results['summary'] = summary
        
        # Log summary executivo
        self.log("\n" + "="*80)
        self.log("SUMMARY EXECUTIVO")
        self.log("="*80)
        self.log(f"Trades Analisados: {summary['total_trades']}")
        self.log(f"Win Rate: {summary['key_metrics']['win_rate']:.1f}%")
        self.log(f"Sharpe Ratio: {summary['key_metrics']['sharpe_ratio']:.2f}")
        self.log(f"Quality Score: {summary['quality_score']:.1f}/100")
        self.log(f"Overfitting Risk: {summary['overfitting_risk']}")
        if summary['best_regime']:
            self.log(f"Best Regime: {summary['best_regime']}")
        self.log("="*80)
        
        return summary
    
    def _calculate_quality_score(self, prod_results: Dict, adv_results: Dict) -> float:
        """Calcula score de qualidade 0-100"""
        
        score = 0.0
        
        # Win Rate (0-25 points)
        wr = prod_results.get('metrics', {}).get('win_rate', 0)
        if wr >= 60:
            score += 25
        elif wr >= 50:
            score += 20
        elif wr >= 45:
            score += 15
        else:
            score += max(0, wr / 2)
        
        # Sharpe Ratio (0-25 points)
        sharpe = prod_results.get('metrics', {}).get('sharpe_ratio', 0)
        if sharpe >= 2.0:
            score += 25
        elif sharpe >= 1.0:
            score += 20
        elif sharpe >= 0.5:
            score += 10
        else:
            score += max(0, sharpe * 10)
        
        # Drawdown (0-25 points)
        dd = prod_results.get('metrics', {}).get('max_drawdown_pct', 100)
        if dd <= 10:
            score += 25
        elif dd <= 15:
            score += 20
        elif dd <= 20:
            score += 10
        else:
            score += max(0, 25 - dd)
        
        # Overfitting check (0-25 points)
        if 'walk_forward' in adv_results and 'degradation' in adv_results['walk_forward']:
            deg = abs(adv_results['walk_forward']['degradation'].get('win_rate', 0))
            if deg < 5:
                score += 25
            elif deg < 10:
                score += 20
            elif deg < 20:
                score += 10
            else:
                score += 0
        else:
            score += 15  # Neutral if no walk-forward
        
        return min(100, max(0, score))
    
    def _assess_overfitting_risk(self, adv_results: Dict) -> str:
        """Avalia risco de overfitting: LOW, MEDIUM, HIGH"""
        
        if 'walk_forward' not in adv_results:
            return 'UNKNOWN'
        
        deg = adv_results['walk_forward'].get('degradation', {})
        wr_deg = abs(deg.get('win_rate', 0))
        
        if wr_deg > 20:
            return 'HIGH'
        elif wr_deg > 10:
            return 'MEDIUM'
        else:
            return 'LOW'
    
    def _identify_best_regime(self, adv_results: Dict) -> Optional[str]:
        """Identifica melhor regime de mercado"""
        
        if 'regimes' not in adv_results:
            return None
        
        best_regime = None
        best_sharpe = -999
        
        for regime_name, regime_data in adv_results['regimes'].items():
            sharpe = regime_data.metrics.sharpe_ratio
            if sharpe > best_sharpe:
                best_sharpe = sharpe
                best_regime = regime_name
        
        return best_regime
    
    def _extract_top_insights(self, recommendations: Dict) -> List[str]:
        """Extrai top 5 insights acionáveis"""
        
        insights = []
        
        # Critical issues primeiro
        for rec in recommendations.get('critical', [])[:2]:
            insights.append(f"⚠ {rec['issue']}: {rec['action']}")
        
        # Best conditions
        if 'best_conditions' in recommendations and recommendations['best_conditions']:
            for key, value in list(recommendations['best_conditions'].items())[:2]:
                if isinstance(value, dict):
                    insights.append(f"✓ Best {key}: {value}")
                else:
                    insights.append(f"✓ {key}: {value}")
        
        # Otimizações
        for opt_name, opt_data in list(recommendations.get('optimizations', {}).items())[:2]:
            if isinstance(opt_data, dict) and 'recommendation' in opt_data:
                insights.append(f"→ {opt_name}: {opt_data['recommendation']}")
        
        return insights[:5]


# ============================================================================
# CLI INTERFACE
# ============================================================================

def main():
    """Interface de linha de comando"""
    
    parser = argparse.ArgumentParser(
        description='Master Analyzer v5.0 - Pipeline Completo de Análise',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Exemplos de uso:
  
  # Análise completa com geração de .set
  python master_analyzer.py log/NexusEA.log
  
  # Sem geração de .set
  python master_analyzer.py log/NexusEA.log --no-sets
  
  # Especificar símbolo manualmente
  python master_analyzer.py log/NexusEA.log --symbol EURUSD
  
  # Configuração customizada
  python master_analyzer.py log/NexusEA.log --min-trades 30 --seed 123
        """
    )
    
    parser.add_argument('log_file', help='Caminho para arquivo de log MT5')
    parser.add_argument('--symbol', help='Símbolo do ativo (auto-detectado se omitido)')
    parser.add_argument('--no-sets', action='store_true', help='Não gerar arquivos .set')
    parser.add_argument('--min-trades', type=int, default=20, help='Mínimo de trades (default: 20)')
    parser.add_argument('--seed', type=int, default=42, help='Seed para reprodutibilidade (default: 42)')
    parser.add_argument('--output-dir', help='Diretório de saída (default: analysis_output)')
    
    args = parser.parse_args()
    
    # Configuração
    config = AnalyzerConfig()
    config.min_trades = args.min_trades
    config.seed = args.seed
    if args.output_dir:
        config.output_dir = Path(args.output_dir)
    
    # Executar análise
    analyzer = MasterAnalyzer(config)
    
    try:
        results = analyzer.run_full_analysis(
            log_file=args.log_file,
            symbol=args.symbol,
            generate_sets=not args.no_sets
        )
        
        print("\n✓ Análise completa finalizada com sucesso!")
        print(f"✓ Resultados salvos em: {config.output_dir}")
        
        if not args.no_sets:
            print(f"✓ Arquivos .set salvos em: {config.presets_dir}")
        
        return 0
    
    except Exception as e:
        print(f"\n✗ ERRO: {e}")
        import traceback
        traceback.print_exc()
        return 1


if __name__ == '__main__':
    sys.exit(main())
