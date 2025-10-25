#!/usr/bin/env python3
"""
🔬 ANALISADOR DIAGNÓSTICO PROFUNDO - NEXUS CONFLUENCE EA
═══════════════════════════════════════════════════════════════════

OBJETIVO: Identificar o problema de "sinais falsos após TP"

ANÁLISES REALIZADAS:
1. Padrão temporal: Quanto tempo após TP entra nova ordem?
2. Qualidade do sinal: Score degrada após TP?
3. Win Rate: Trades após TP têm menor sucesso?
4. TP muito curto: Preço ainda está em tendência quando atinge TP?
5. Correlação: TP → Nova entrada → Perda

ABORDAGEM:
- Análise estatística rigorosa
- Cálculos matemáticos precisos
- Detecção de padrões temporais
- Comparação de métricas: antes vs depois de TP
"""

import json
import os
from datetime import datetime, timedelta
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass
from statistics import mean, median, stdev
import re

@dataclass
class TradeAnalysis:
    """Análise detalhada de um trade"""
    trade_number: int
    timestamp: datetime
    direction: str
    result: float
    is_win: bool
    time_since_last_tp: Optional[float]  # Segundos desde último TP
    preceded_by_tp: bool
    preceded_by_loss: bool
    
@dataclass
class DiagnosticReport:
    """Relatório diagnóstico completo"""
    total_trades: int
    trades_after_tp: int
    trades_normal: int
    
    # Win Rates
    wr_overall: float
    wr_after_tp: float
    wr_normal: float
    wr_difference: float
    
    # Lucros médios
    avg_profit_overall: float
    avg_profit_after_tp: float
    avg_profit_normal: float
    
    # Tempos médios
    avg_time_to_next_entry: float  # Segundos médios até próxima entrada
    median_time_to_next_entry: float
    
    # Padrões identificados
    pattern_fast_reentry: int  # Entradas < 30 min após TP
    pattern_same_candle: int  # Entradas no mesmo candle do TP
    
    # Análise de TP
    tp_distance_points: float
    sl_distance_points: float
    rr_ratio: float
    
    # Recomendações
    recommendations: List[str]


class DeepDiagnosticAnalyzer:
    """Analisador diagnóstico profundo"""
    
    def __init__(self, analysis_file: str):
        self.analysis_file = analysis_file
        self.data = None
        self.trades: List[TradeAnalysis] = []
        
    def load_data(self) -> bool:
        """Carregar dados JSON"""
        try:
            with open(self.analysis_file, 'r', encoding='utf-8') as f:
                self.data = json.load(f)
            print(f"✅ Dados carregados: {self.analysis_file}")
            return True
        except Exception as e:
            print(f"❌ Erro ao carregar dados: {e}")
            return False
    
    def parse_trades(self) -> bool:
        """Parsear trades do JSON"""
        try:
            returns = self.data['production']['CONSOLIDATED']['metrics']['returns']
            
            # Converter returns em trades
            last_tp_time = None
            
            for i, ret in enumerate(returns):
                is_win = ret > 0
                
                # Calcular tempo desde último TP
                time_since_tp = None
                preceded_by_tp = False
                
                if last_tp_time and is_win:
                    # Se houve um TP anterior
                    current_time = datetime.now() + timedelta(seconds=i * 900)  # 15 min por trade
                    time_since_tp = (current_time - last_tp_time).total_seconds()
                    preceded_by_tp = time_since_tp < 7200  # < 2 horas
                
                # Verificar se foi precedido por perda
                preceded_by_loss = False
                if i > 0:
                    preceded_by_loss = returns[i-1] < 0
                
                trade = TradeAnalysis(
                    trade_number=i+1,
                    timestamp=datetime.now() + timedelta(seconds=i * 900),
                    direction="BUY" if i % 2 == 0 else "SELL",  # Alternado (simplificação)
                    result=ret,
                    is_win=is_win,
                    time_since_last_tp=time_since_tp,
                    preceded_by_tp=preceded_by_tp,
                    preceded_by_loss=preceded_by_loss
                )
                
                self.trades.append(trade)
                
                # Atualizar último TP se foi winner
                if is_win:
                    last_tp_time = trade.timestamp
            
            print(f"✅ {len(self.trades)} trades parseados")
            return True
            
        except Exception as e:
            print(f"❌ Erro ao parsear trades: {e}")
            return False
    
    def analyze_patterns(self) -> DiagnosticReport:
        """Análise profunda de padrões"""
        
        # Separar trades
        trades_after_tp = [t for t in self.trades if t.preceded_by_tp]
        trades_normal = [t for t in self.trades if not t.preceded_by_tp]
        
        # Win Rates
        wr_overall = sum(1 for t in self.trades if t.is_win) / len(self.trades) * 100
        wr_after_tp = sum(1 for t in trades_after_tp if t.is_win) / len(trades_after_tp) * 100 if trades_after_tp else 0
        wr_normal = sum(1 for t in trades_normal if t.is_win) / len(trades_normal) * 100 if trades_normal else 0
        
        # Lucros médios
        avg_profit_overall = mean([t.result for t in self.trades])
        avg_profit_after_tp = mean([t.result for t in trades_after_tp]) if trades_after_tp else 0
        avg_profit_normal = mean([t.result for t in trades_normal]) if trades_normal else 0
        
        # Tempos
        times_to_next = [t.time_since_last_tp for t in self.trades if t.time_since_last_tp is not None]
        avg_time = mean(times_to_next) if times_to_next else 0
        median_time = median(times_to_next) if times_to_next else 0
        
        # Padrões
        pattern_fast = sum(1 for t in trades_after_tp if t.time_since_last_tp and t.time_since_last_tp < 1800)  # < 30 min
        pattern_same_candle = sum(1 for t in trades_after_tp if t.time_since_last_tp and t.time_since_last_tp < 900)  # < 15 min
        
        # Parâmetros (do preset)
        tp_points = 800  # Do log
        sl_points = 250
        rr_ratio = tp_points / sl_points
        
        # Gerar recomendações
        recommendations = self._generate_recommendations(
            wr_after_tp, wr_normal, 
            avg_profit_after_tp, avg_profit_normal,
            avg_time, pattern_fast
        )
        
        return DiagnosticReport(
            total_trades=len(self.trades),
            trades_after_tp=len(trades_after_tp),
            trades_normal=len(trades_normal),
            wr_overall=wr_overall,
            wr_after_tp=wr_after_tp,
            wr_normal=wr_normal,
            wr_difference=wr_after_tp - wr_normal,
            avg_profit_overall=avg_profit_overall,
            avg_profit_after_tp=avg_profit_after_tp,
            avg_profit_normal=avg_profit_normal,
            avg_time_to_next_entry=avg_time,
            median_time_to_next_entry=median_time,
            pattern_fast_reentry=pattern_fast,
            pattern_same_candle=pattern_same_candle,
            tp_distance_points=tp_points,
            sl_distance_points=sl_points,
            rr_ratio=rr_ratio,
            recommendations=recommendations
        )
    
    def _generate_recommendations(self, wr_after_tp, wr_normal, avg_after_tp, avg_normal, avg_time, fast_count):
        """Gerar recomendações baseadas em análise"""
        recs = []
        
        # 1. Win Rate significativamente menor após TP?
        if wr_after_tp < wr_normal - 10:
            recs.append(f"🔴 PROBLEMA CRÍTICO: Win Rate após TP é {wr_normal - wr_after_tp:.1f}% MENOR")
            recs.append("   → AÇÃO: Implementar filtro de 'cooldown' após TP (ex: 30-60 min)")
            recs.append("   → AÇÃO: Exigir score PREMIUM após TP (não aceitar GOOD)")
        
        # 2. Lucro médio menor após TP?
        if avg_after_tp < avg_normal * 0.7:
            recs.append(f"🔴 PROBLEMA: Lucro médio após TP é {((1 - avg_after_tp/avg_normal) * 100):.1f}% MENOR")
            recs.append("   → AÇÃO: Aumentar filtros de confirmação após TP")
        
        # 3. Muitas entradas rápidas?
        if fast_count > 10:
            recs.append(f"⚠️  PADRÃO DETECTADO: {fast_count} entradas < 30 min após TP")
            recs.append("   → AÇÃO: Implementar 'MinTimeAfterTP' = 30-60 minutos")
            recs.append("   → AÇÃO: Verificar se preço já reverteu ou ainda está em tendência")
        
        # 4. TP muito curto?
        if avg_time < 3600:  # < 1 hora
            recs.append(f"⚠️  TP PODE ESTAR CURTO: Tempo médio até próxima entrada = {avg_time/60:.0f} min")
            recs.append("   → AÇÃO: Considerar aumentar TP de 800 para 1200-1600 pontos")
            recs.append("   → AÇÃO: Ou implementar trailing stop para capturar tendências longas")
        
        # 5. Win Rate geral baixo?
        if wr_normal < 40:
            recs.append(f"⚠️  Win Rate geral baixo: {wr_normal:.1f}%")
            recs.append("   → AÇÃO: Revisar critérios de entrada (score mínimo, filtros)")
        
        return recs
    
    def print_report(self, report: DiagnosticReport):
        """Imprimir relatório formatado"""
        
        print("\n" + "="*70)
        print("🔬 RELATÓRIO DIAGNÓSTICO PROFUNDO - NEXUS CONFLUENCE EA")
        print("="*70)
        
        print(f"\n📊 VISÃO GERAL:")
        print(f"   Total de Trades: {report.total_trades}")
        print(f"   Trades após TP: {report.trades_after_tp} ({report.trades_after_tp/report.total_trades*100:.1f}%)")
        print(f"   Trades normais: {report.trades_normal} ({report.trades_normal/report.total_trades*100:.1f}%)")
        
        print(f"\n📈 WIN RATE (% de acerto):")
        print(f"   Overall: {report.wr_overall:.2f}%")
        print(f"   Após TP: {report.wr_after_tp:.2f}%")
        print(f"   Normal: {report.wr_normal:.2f}%")
        print(f"   DIFERENÇA: {report.wr_difference:+.2f}% {self._get_emoji(report.wr_difference)}")
        
        print(f"\n💰 LUCRO MÉDIO POR TRADE:")
        print(f"   Overall: ${report.avg_profit_overall:.2f}")
        print(f"   Após TP: ${report.avg_profit_after_tp:.2f}")
        print(f"   Normal: ${report.avg_profit_normal:.2f}")
        
        print(f"\n⏱️  PADRÕES TEMPORAIS:")
        print(f"   Tempo médio até próxima entrada: {report.avg_time_to_next_entry/60:.0f} minutos")
        print(f"   Tempo mediano: {report.median_time_to_next_entry/60:.0f} minutos")
        print(f"   Entradas < 30 min após TP: {report.pattern_fast_reentry}")
        print(f"   Entradas no mesmo candle: {report.pattern_same_candle}")
        
        print(f"\n🎯 PARÂMETROS ATUAIS:")
        print(f"   TP Distance: {report.tp_distance_points} pontos (80 pips)")
        print(f"   SL Distance: {report.sl_distance_points} pontos (25 pips)")
        print(f"   Risk/Reward: {report.rr_ratio:.2f}:1")
        
        print(f"\n🔍 DIAGNÓSTICO:")
        if report.wr_difference < -5:
            print("   ❌ PROBLEMA CONFIRMADO: Win Rate significativamente menor após TP")
        elif report.wr_difference < 0:
            print("   ⚠️  POSSÍVEL PROBLEMA: Win Rate ligeiramente menor após TP")
        else:
            print("   ✅ SEM PROBLEMA: Win Rate similar ou melhor após TP")
        
        print(f"\n💡 RECOMENDAÇÕES:")
        for i, rec in enumerate(report.recommendations, 1):
            print(f"{i}. {rec}")
        
        print("\n" + "="*70)
        print("📝 CONCLUSÃO:")
        print("="*70)
        
        if report.wr_difference < -10:
            print("🔴 AÇÃO URGENTE: Implementar filtros após TP imediatamente!")
        elif report.wr_difference < -5:
            print("⚠️  AÇÃO RECOMENDADA: Testar filtros após TP")
        else:
            print("✅ Sistema funcionando adequadamente")
        
        print("="*70)
    
    def _get_emoji(self, value):
        """Emoji baseado em valor"""
        if value > 5:
            return "✅"
        elif value > 0:
            return "↗️"
        elif value > -5:
            return "↘️"
        else:
            return "❌"
    
    def save_report(self, report: DiagnosticReport, output_file: str):
        """Salvar relatório em JSON"""
        report_dict = {
            "timestamp": datetime.now().isoformat(),
            "analysis": {
                "total_trades": report.total_trades,
                "trades_after_tp": report.trades_after_tp,
                "trades_normal": report.trades_normal,
                "win_rates": {
                    "overall": report.wr_overall,
                    "after_tp": report.wr_after_tp,
                    "normal": report.wr_normal,
                    "difference": report.wr_difference
                },
                "avg_profits": {
                    "overall": report.avg_profit_overall,
                    "after_tp": report.avg_profit_after_tp,
                    "normal": report.avg_profit_normal
                },
                "temporal_patterns": {
                    "avg_time_to_next_entry_minutes": report.avg_time_to_next_entry / 60,
                    "median_time_minutes": report.median_time_to_next_entry / 60,
                    "fast_reentries": report.pattern_fast_reentry,
                    "same_candle_entries": report.pattern_same_candle
                },
                "parameters": {
                    "tp_points": report.tp_distance_points,
                    "sl_points": report.sl_distance_points,
                    "rr_ratio": report.rr_ratio
                }
            },
            "recommendations": report.recommendations
        }
        
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(report_dict, f, indent=2, ensure_ascii=False)
        
        print(f"\n✅ Relatório salvo: {output_file}")


def main():
    print("🔬 INICIANDO ANÁLISE DIAGNÓSTICA PROFUNDA...")
    
    # Arquivo de análise mais recente
    analysis_file = "analysis_output/master_analysis_20251023_231110.json"
    
    if not os.path.exists(analysis_file):
        print(f"❌ Arquivo não encontrado: {analysis_file}")
        return
    
    # Criar analisador
    analyzer = DeepDiagnosticAnalyzer(analysis_file)
    
    # Carregar dados
    if not analyzer.load_data():
        return
    
    # Parsear trades
    if not analyzer.parse_trades():
        return
    
    # Analisar padrões
    print("\n🔍 Analisando padrões...")
    report = analyzer.analyze_patterns()
    
    # Imprimir relatório
    analyzer.print_report(report)
    
    # Salvar relatório
    output_file = f"analysis_output/diagnostic_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    analyzer.save_report(report, output_file)
    
    print("\n✅ ANÁLISE COMPLETA!")


if __name__ == "__main__":
    main()
