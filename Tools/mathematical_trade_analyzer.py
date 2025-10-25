#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
╔═══════════════════════════════════════════════════════════════════════════════╗
║  MATHEMATICAL TRADE ANALYZER - Nexus Confluence EA v4.27+                    ║
║  Análise matemática profunda para detectar problemas de TP e reentradas      ║
╚═══════════════════════════════════════════════════════════════════════════════╝

OBJETIVO:
    Identificar matematicamente o problema reportado:
    - TPs curtos que deixam lucro na mesa
    - Reentradas prematuras após TP (sinais falsos)
    - Correlação entre qualidade do sinal e resultado

METODOLOGIA:
    1. Parse completo do log de debug
    2. Extração de trades com todos os sinais
    3. Cálculos estatísticos e financeiros
    4. Identificação de padrões de reentrada
    5. Análise de "lucro perdido" vs "prejuízo por reentrada"

AUTOR: GitHub Copilot + Paulo Eduardo
DATA: 25 Outubro 2025
"""

import re
import sys
from pathlib import Path
from datetime import datetime, timedelta
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass, field
from collections import defaultdict
import statistics

@dataclass
class TradeSignal:
    """Sinais dos indicadores no momento da entrada"""
    gg_macro1: str = "UNKNOWN"
    gg_macro2: str = "UNKNOWN"
    gg_macro3: str = "UNKNOWN"
    supertrend: str = "UNKNOWN"
    wae_aligned: bool = False
    rsi_aligned: bool = False
    cs_aligned: bool = False
    score: int = 0
    max_score: int = 3
    setup_class: str = "UNKNOWN"

@dataclass
class TradeEntry:
    """Dados de entrada do trade"""
    timestamp: datetime
    direction: str  # BUY or SELL
    price: float
    lot_size: float
    sl_price: float
    tp1_price: float
    tp2_price: float
    tp3_price: float
    signal: TradeSignal
    ticket: int = 0

@dataclass
class TradeExit:
    """Dados de saída do trade"""
    timestamp: datetime
    exit_price: float
    exit_type: str  # TP1, TP2, TP3, SL, TRAILING
    profit_pips: float
    profit_dollars: float
    duration_minutes: int

@dataclass
class CompleteTrade:
    """Trade completo com entrada e saída"""
    entry: TradeEntry
    exit: TradeExit
    time_until_tp: int  # minutos até atingir TP
    peak_profit_pips: float = 0.0  # Maior lucro atingido antes da saída
    signal_quality_score: float = 0.0  # Score normalizado 0-100

class MathematicalTradeAnalyzer:
    """Analisador matemático avançado de trades"""
    
    def __init__(self, log_file: Path):
        self.log_file = log_file
        self.trades: List[CompleteTrade] = []
        self.raw_entries: List[TradeEntry] = []
        self.raw_exits: List[TradeExit] = []
        
        # Estatísticas calculadas
        self.stats = {
            'total_trades': 0,
            'winning_trades': 0,
            'losing_trades': 0,
            'avg_winner_pips': 0.0,
            'avg_loser_pips': 0.0,
            'avg_time_to_tp': 0.0,
            'reentry_within_1h': 0,
            'reentry_within_2h': 0,
            'avg_signal_quality_winner': 0.0,
            'avg_signal_quality_loser': 0.0,
            'tp_too_short_count': 0,
            'profit_left_on_table': 0.0,
            'losses_from_premature_reentry': 0.0
        }
    
    def parse_log_file(self) -> None:
        """Parse completo do arquivo de log"""
        print(f"📂 Analisando log: {self.log_file.name}")
        print(f"📊 Tamanho: {self.log_file.stat().st_size / 1024 / 1024:.2f} MB")
        
        with open(self.log_file, 'r', encoding='utf-8', errors='ignore') as f:
            lines = f.readlines()
        
        print(f"📝 Total de linhas: {len(lines):,}")
        
        # Parse em múltiplas passagens
        print("\n🔍 FASE 1: Extraindo entradas de trades...")
        self._extract_entries(lines)
        
        print(f"✅ Entradas encontradas: {len(self.raw_entries)}")
        
        print("\n🔍 FASE 2: Extraindo saídas de trades...")
        self._extract_exits(lines)
        
        print(f"✅ Saídas encontradas: {len(self.raw_exits)}")
        
        print("\n🔍 FASE 3: Correlacionando entradas e saídas...")
        self._correlate_trades()
        
        print(f"✅ Trades completos: {len(self.trades)}")
    
    def _extract_entries(self, lines: List[str]) -> None:
        """Extrai todas as entradas de trades do log"""
        
        # Padrões regex para capturar dados
        entry_pattern = re.compile(
            r'(\d{4}\.\d{2}\.\d{2}\s+\d{2}:\d{2}:\d{2}\.\d{3}).*'
            r'(BUY|SELL).*'
            r'Entry:\s*([0-9.]+).*'
            r'SL:\s*([0-9.]+).*'
            r'TP1:\s*([0-9.]+)'
        )
        
        score_pattern = re.compile(r'Score:\s*(\d+)/(\d+)')
        setup_pattern = re.compile(r'Setup:\s*(PREMIUM|GOOD|REJECT)')
        
        current_signal = None
        
        for i, line in enumerate(lines):
            # Detectar início de análise de sinal
            if 'Analisando sinal' in line or 'Setup encontrado' in line:
                current_signal = TradeSignal()
                
                # Extrair score
                score_match = score_pattern.search(line)
                if score_match:
                    current_signal.score = int(score_match.group(1))
                    current_signal.max_score = int(score_match.group(2))
                
                # Extrair setup class
                setup_match = setup_pattern.search(line)
                if setup_match:
                    current_signal.setup_class = setup_match.group(1)
            
            # Detectar indicadores alinhados
            if current_signal:
                if 'GG TrendBar MACRO1' in line:
                    if 'ALINHADO' in line:
                        current_signal.gg_macro1 = "ALIGNED"
                if 'GG TrendBar MACRO2' in line:
                    if 'ALINHADO' in line:
                        current_signal.gg_macro2 = "ALIGNED"
                if 'GG TrendBar MACRO3' in line:
                    if 'ALINHADO' in line:
                        current_signal.gg_macro3 = "ALIGNED"
                if 'WAE' in line and 'ALINHADO' in line:
                    current_signal.wae_aligned = True
                if 'RSI' in line and 'ALINHADO' in line:
                    current_signal.rsi_aligned = True
                if 'Currency Strength' in line and 'ALINHADO' in line:
                    current_signal.cs_aligned = True
            
            # Detectar entrada de trade
            entry_match = entry_pattern.search(line)
            if entry_match and 'Ordem enviada' in line:
                try:
                    timestamp_str = entry_match.group(1)
                    timestamp = datetime.strptime(timestamp_str, '%Y.%m.%d %H:%M:%S.%f')
                    direction = entry_match.group(2)
                    entry_price = float(entry_match.group(3))
                    sl_price = float(entry_match.group(4))
                    tp1_price = float(entry_match.group(5))
                    
                    # Buscar TP2 e TP3 nas próximas linhas
                    tp2_price = 0.0
                    tp3_price = 0.0
                    for j in range(i, min(i+10, len(lines))):
                        if 'TP2:' in lines[j]:
                            tp2_match = re.search(r'TP2:\s*([0-9.]+)', lines[j])
                            if tp2_match:
                                tp2_price = float(tp2_match.group(1))
                        if 'TP3:' in lines[j]:
                            tp3_match = re.search(r'TP3:\s*([0-9.]+)', lines[j])
                            if tp3_match:
                                tp3_price = float(tp3_match.group(1))
                    
                    entry = TradeEntry(
                        timestamp=timestamp,
                        direction=direction,
                        price=entry_price,
                        lot_size=0.01,  # Placeholder
                        sl_price=sl_price,
                        tp1_price=tp1_price,
                        tp2_price=tp2_price,
                        tp3_price=tp3_price,
                        signal=current_signal if current_signal else TradeSignal()
                    )
                    
                    self.raw_entries.append(entry)
                    current_signal = None  # Reset para próximo trade
                
                except Exception as e:
                    print(f"⚠️  Erro ao parsear entrada (linha {i}): {e}")
                    continue
    
    def _extract_exits(self, lines: List[str]) -> None:
        """Extrai todas as saídas de trades do log"""
        
        exit_pattern = re.compile(
            r'(\d{4}\.\d{2}\.\d{2}\s+\d{2}:\d{2}:\d{2}\.\d{3}).*'
            r'(fechado|closed|TP1|TP2|TP3|SL|TRAILING).*'
            r'Profit:\s*([+-]?[0-9.]+).*pips'
        )
        
        for i, line in enumerate(lines):
            if 'Trade fechado' in line or 'Position closed' in line:
                exit_match = exit_pattern.search(line)
                if exit_match:
                    try:
                        timestamp_str = exit_match.group(1)
                        timestamp = datetime.strptime(timestamp_str, '%Y.%m.%d %H:%M:%S.%f')
                        exit_type = exit_match.group(2).upper()
                        profit_pips = float(exit_match.group(3))
                        
                        # Buscar profit em dólares
                        profit_dollars = 0.0
                        for j in range(i, min(i+5, len(lines))):
                            dollar_match = re.search(r'\$\s*([+-]?[0-9.]+)', lines[j])
                            if dollar_match:
                                profit_dollars = float(dollar_match.group(1))
                                break
                        
                        exit = TradeExit(
                            timestamp=timestamp,
                            exit_price=0.0,  # Calcular depois
                            exit_type=exit_type,
                            profit_pips=profit_pips,
                            profit_dollars=profit_dollars,
                            duration_minutes=0  # Calcular depois
                        )
                        
                        self.raw_exits.append(exit)
                    
                    except Exception as e:
                        print(f"⚠️  Erro ao parsear saída (linha {i}): {e}")
                        continue
    
    def _correlate_trades(self) -> None:
        """Correlaciona entradas com saídas para formar trades completos"""
        
        # Ordenar por timestamp
        self.raw_entries.sort(key=lambda x: x.timestamp)
        self.raw_exits.sort(key=lambda x: x.timestamp)
        
        used_exits = set()
        
        for entry in self.raw_entries:
            # Encontrar saída correspondente (próxima no tempo)
            best_exit = None
            min_time_diff = timedelta(hours=24)  # Max 24h
            
            for idx, exit_trade in enumerate(self.raw_exits):
                if idx in used_exits:
                    continue
                
                if exit_trade.timestamp > entry.timestamp:
                    time_diff = exit_trade.timestamp - entry.timestamp
                    if time_diff < min_time_diff:
                        min_time_diff = time_diff
                        best_exit = (idx, exit_trade)
            
            if best_exit:
                idx, exit_trade = best_exit
                used_exits.add(idx)
                
                # Calcular duração
                duration = (exit_trade.timestamp - entry.timestamp).total_seconds() / 60
                exit_trade.duration_minutes = int(duration)
                
                # Calcular exit price
                if entry.direction == "BUY":
                    exit_trade.exit_price = entry.price + (exit_trade.profit_pips * 0.001)
                else:
                    exit_trade.exit_price = entry.price - (exit_trade.profit_pips * 0.001)
                
                # Calcular signal quality score (0-100)
                signal_quality = (entry.signal.score / entry.signal.max_score) * 100 if entry.signal.max_score > 0 else 0
                
                # Calcular peak profit (lucro que poderia ter sido obtido)
                # Simplificado: assumir que TP3 seria o máximo
                peak_profit = 0.0
                if entry.direction == "BUY" and entry.tp3_price > 0:
                    peak_profit = (entry.tp3_price - entry.price) * 1000  # pips
                elif entry.direction == "SELL" and entry.tp3_price > 0:
                    peak_profit = (entry.price - entry.tp3_price) * 1000  # pips
                
                complete_trade = CompleteTrade(
                    entry=entry,
                    exit=exit_trade,
                    time_until_tp=int(duration),
                    peak_profit_pips=peak_profit,
                    signal_quality_score=signal_quality
                )
                
                self.trades.append(complete_trade)
    
    def calculate_statistics(self) -> None:
        """Calcula todas as estatísticas matemáticas"""
        
        if not self.trades:
            print("❌ Nenhum trade completo para analisar!")
            return
        
        print("\n📊 CALCULANDO ESTATÍSTICAS MATEMÁTICAS...\n")
        
        winners = [t for t in self.trades if t.exit.profit_pips > 0]
        losers = [t for t in self.trades if t.exit.profit_pips <= 0]
        
        self.stats['total_trades'] = len(self.trades)
        self.stats['winning_trades'] = len(winners)
        self.stats['losing_trades'] = len(losers)
        
        # Médias de pips
        if winners:
            self.stats['avg_winner_pips'] = statistics.mean([t.exit.profit_pips for t in winners])
            self.stats['avg_signal_quality_winner'] = statistics.mean([t.signal_quality_score for t in winners])
        
        if losers:
            self.stats['avg_loser_pips'] = statistics.mean([t.exit.profit_pips for t in losers])
            self.stats['avg_signal_quality_loser'] = statistics.mean([t.signal_quality_score for t in losers])
        
        # Tempo médio até TP
        tp_times = [t.time_until_tp for t in winners if t.exit.exit_type in ['TP1', 'TP2', 'TP3']]
        if tp_times:
            self.stats['avg_time_to_tp'] = statistics.mean(tp_times)
        
        # Análise de reentradas
        self._analyze_reentries()
        
        # Análise de TP curto
        self._analyze_tp_length()
        
        # Análise financeira
        self._analyze_financial_impact()
    
    def _analyze_reentries(self) -> None:
        """Detecta reentradas prematuras após TP"""
        
        reentry_1h = 0
        reentry_2h = 0
        
        for i in range(len(self.trades) - 1):
            current_trade = self.trades[i]
            next_trade = self.trades[i + 1]
            
            # Verificar se current_trade foi fechado em TP
            if current_trade.exit.exit_type in ['TP1', 'TP2', 'TP3']:
                time_between = (next_trade.entry.timestamp - current_trade.exit.timestamp).total_seconds() / 60
                
                if time_between <= 60:  # 1 hora
                    reentry_1h += 1
                if time_between <= 120:  # 2 horas
                    reentry_2h += 1
        
        self.stats['reentry_within_1h'] = reentry_1h
        self.stats['reentry_within_2h'] = reentry_2h
    
    def _analyze_tp_length(self) -> None:
        """Analisa se TPs estão muito curtos"""
        
        tp_too_short = 0
        
        for trade in self.trades:
            # Considerar TP curto se fechou em TP1 mas poderia ter ido até TP3
            if trade.exit.exit_type == 'TP1':
                # Verificar se o movimento continuou (peak > TP1)
                if trade.peak_profit_pips > (trade.exit.profit_pips * 1.5):
                    tp_too_short += 1
        
        self.stats['tp_too_short_count'] = tp_too_short
    
    def _analyze_financial_impact(self) -> None:
        """Calcula impacto financeiro do problema"""
        
        profit_left = 0.0
        losses_reentry = 0.0
        
        for i, trade in enumerate(self.trades):
            # Lucro deixado na mesa (TP curto)
            if trade.exit.exit_type == 'TP1' and trade.peak_profit_pips > 0:
                potential_profit = trade.peak_profit_pips - trade.exit.profit_pips
                if potential_profit > 0:
                    profit_left += potential_profit
            
            # Perdas por reentrada prematura
            if i > 0:
                prev_trade = self.trades[i - 1]
                if prev_trade.exit.exit_type in ['TP1', 'TP2', 'TP3']:
                    time_between = (trade.entry.timestamp - prev_trade.exit.timestamp).total_seconds() / 60
                    
                    if time_between <= 120 and trade.exit.profit_pips < 0:
                        losses_reentry += abs(trade.exit.profit_pips)
        
        self.stats['profit_left_on_table'] = profit_left
        self.stats['losses_from_premature_reentry'] = losses_reentry
    
    def generate_report(self, output_file: Path) -> None:
        """Gera relatório matemático completo"""
        
        report_lines = []
        
        report_lines.append("╔═══════════════════════════════════════════════════════════════════════════════╗")
        report_lines.append("║  RELATÓRIO MATEMÁTICO - DIAGNÓSTICO DE TPs E REENTRADAS                      ║")
        report_lines.append("║  Nexus Confluence EA v4.27+ - Análise Profunda                               ║")
        report_lines.append("╚═══════════════════════════════════════════════════════════════════════════════╝")
        report_lines.append("")
        report_lines.append(f"📅 Data da análise: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        report_lines.append(f"📂 Log analisado: {self.log_file.name}")
        report_lines.append("")
        
        # SEÇÃO 1: ESTATÍSTICAS GERAIS
        report_lines.append("═" * 80)
        report_lines.append("1️⃣  ESTATÍSTICAS GERAIS")
        report_lines.append("═" * 80)
        report_lines.append("")
        report_lines.append(f"Total de trades completos analisados: {self.stats['total_trades']}")
        report_lines.append(f"Trades vencedores: {self.stats['winning_trades']} ({self.stats['winning_trades']/self.stats['total_trades']*100:.1f}%)")
        report_lines.append(f"Trades perdedores: {self.stats['losing_trades']} ({self.stats['losing_trades']/self.stats['total_trades']*100:.1f}%)")
        report_lines.append("")
        report_lines.append(f"📈 Ganho médio: {self.stats['avg_winner_pips']:.2f} pips")
        report_lines.append(f"📉 Perda média: {self.stats['avg_loser_pips']:.2f} pips")
        report_lines.append(f"⏱️  Tempo médio até TP: {self.stats['avg_time_to_tp']:.0f} minutos ({self.stats['avg_time_to_tp']/60:.1f} horas)")
        report_lines.append("")
        
        # SEÇÃO 2: QUALIDADE DOS SINAIS
        report_lines.append("═" * 80)
        report_lines.append("2️⃣  QUALIDADE DOS SINAIS (SCORE)")
        report_lines.append("═" * 80)
        report_lines.append("")
        report_lines.append(f"📊 Score médio em trades VENCEDORES: {self.stats['avg_signal_quality_winner']:.1f}/100")
        report_lines.append(f"📊 Score médio em trades PERDEDORES: {self.stats['avg_signal_quality_loser']:.1f}/100")
        report_lines.append("")
        
        quality_diff = self.stats['avg_signal_quality_winner'] - self.stats['avg_signal_quality_loser']
        if quality_diff > 10:
            report_lines.append(f"✅ DIFERENÇA SIGNIFICATIVA: {quality_diff:.1f} pontos")
            report_lines.append("   → Sinais com score alto realmente têm melhor resultado")
        elif quality_diff > 0:
            report_lines.append(f"⚠️  DIFERENÇA PEQUENA: {quality_diff:.1f} pontos")
            report_lines.append("   → Filtros podem não estar discriminando bem")
        else:
            report_lines.append(f"❌ DIFERENÇA NEGATIVA: {quality_diff:.1f} pontos")
            report_lines.append("   → ALERTA: Sinais com score baixo estão tendo melhor resultado!")
        report_lines.append("")
        
        # SEÇÃO 3: PROBLEMA DE REENTRADAS
        report_lines.append("═" * 80)
        report_lines.append("3️⃣  ANÁLISE DE REENTRADAS PREMATURAS")
        report_lines.append("═" * 80)
        report_lines.append("")
        report_lines.append(f"🔄 Reentradas em até 1 hora após TP: {self.stats['reentry_within_1h']}")
        report_lines.append(f"🔄 Reentradas em até 2 horas após TP: {self.stats['reentry_within_2h']}")
        report_lines.append("")
        
        reentry_rate = (self.stats['reentry_within_2h'] / self.stats['winning_trades'] * 100) if self.stats['winning_trades'] > 0 else 0
        report_lines.append(f"📊 Taxa de reentrada: {reentry_rate:.1f}%")
        report_lines.append("")
        
        if reentry_rate > 30:
            report_lines.append("🚨 PROBLEMA CRÍTICO IDENTIFICADO:")
            report_lines.append("   → Taxa de reentrada MUITO ALTA (>30%)")
            report_lines.append("   → EA está reentrando muito rápido após fechar TP")
            report_lines.append("   → Provável causa: Sinais ainda presentes após TP")
        elif reentry_rate > 15:
            report_lines.append("⚠️  PROBLEMA MODERADO:")
            report_lines.append("   → Taxa de reentrada elevada (>15%)")
            report_lines.append("   → Considerar cooldown após TP ou filtros mais rigorosos")
        else:
            report_lines.append("✅ Taxa de reentrada aceitável (<15%)")
        report_lines.append("")
        
        # SEÇÃO 4: PROBLEMA DE TP CURTO
        report_lines.append("═" * 80)
        report_lines.append("4️⃣  ANÁLISE DE TPs CURTOS (Lucro Deixado na Mesa)")
        report_lines.append("═" * 80)
        report_lines.append("")
        report_lines.append(f"📏 Trades com TP aparentemente curto: {self.stats['tp_too_short_count']}")
        report_lines.append(f"📊 Percentual de TPs curtos: {(self.stats['tp_too_short_count']/self.stats['winning_trades']*100):.1f}%")
        report_lines.append("")
        
        # SEÇÃO 5: IMPACTO FINANCEIRO
        report_lines.append("═" * 80)
        report_lines.append("5️⃣  IMPACTO FINANCEIRO")
        report_lines.append("═" * 80)
        report_lines.append("")
        report_lines.append(f"💰 Lucro deixado na mesa (TPs curtos): {self.stats['profit_left_on_table']:.2f} pips")
        report_lines.append(f"💸 Perdas por reentradas prematuras: {self.stats['losses_from_premature_reentry']:.2f} pips")
        report_lines.append("")
        
        net_impact = self.stats['profit_left_on_table'] - self.stats['losses_from_premature_reentry']
        report_lines.append(f"🎯 IMPACTO LÍQUIDO: {net_impact:.2f} pips")
        report_lines.append("")
        
        if net_impact > 0:
            report_lines.append("📊 CONCLUSÃO FINANCEIRA:")
            report_lines.append(f"   → Lucro deixado na mesa ({self.stats['profit_left_on_table']:.2f} pips)")
            report_lines.append(f"   → SUPERA perdas por reentrada ({self.stats['losses_from_premature_reentry']:.2f} pips)")
            report_lines.append("   → RECOMENDAÇÃO: Aumentar TPs ou implementar trailing mais agressivo")
        else:
            report_lines.append("📊 CONCLUSÃO FINANCEIRA:")
            report_lines.append(f"   → Perdas por reentrada ({self.stats['losses_from_premature_reentry']:.2f} pips)")
            report_lines.append(f"   → SUPERAM lucro deixado na mesa ({self.stats['profit_left_on_table']:.2f} pips)")
            report_lines.append("   → RECOMENDAÇÃO: Implementar cooldown após TP ou filtros mais rigorosos")
        report_lines.append("")
        
        # SEÇÃO 6: RECOMENDAÇÕES
        report_lines.append("═" * 80)
        report_lines.append("6️⃣  RECOMENDAÇÕES BASEADAS EM DADOS")
        report_lines.append("═" * 80)
        report_lines.append("")
        
        # Analisar problema principal
        if reentry_rate > 25 and self.stats['losses_from_premature_reentry'] > self.stats['profit_left_on_table']:
            report_lines.append("🎯 PROBLEMA PRINCIPAL IDENTIFICADO: REENTRADAS PREMATURAS")
            report_lines.append("")
            report_lines.append("SOLUÇÕES PROPOSTAS:")
            report_lines.append("")
            report_lines.append("1. IMPLEMENTAR COOLDOWN APÓS TP:")
            report_lines.append("   - Aguardar 1-2 horas após fechar em TP antes de permitir nova entrada")
            report_lines.append("   - Cooldown proporcional ao timeframe operacional")
            report_lines.append("   - Evitar reentradas na mesma direção por período mínimo")
            report_lines.append("")
            report_lines.append("2. AUMENTAR RIGOR DOS FILTROS PÓS-TP:")
            report_lines.append("   - Exigir score 3/3 (PREMIUM) para reentradas dentro de 2h")
            report_lines.append("   - Verificar se momentum ainda está forte (WAE expandindo)")
            report_lines.append("   - Confirmar que macro continua alinhado em TODOS os níveis")
            report_lines.append("")
            report_lines.append("3. IMPLEMENTAR 'DECAY' DE QUALIDADE DO SINAL:")
            report_lines.append("   - Penalizar sinais que ocorrem logo após TP")
            report_lines.append("   - Score diminui progressivamente após fechamento")
            report_lines.append("   - Força recalibração dos indicadores antes de reentrar")
            report_lines.append("")
        
        elif self.stats['profit_left_on_table'] > 100:
            report_lines.append("🎯 PROBLEMA PRINCIPAL IDENTIFICADO: TPs MUITO CURTOS")
            report_lines.append("")
            report_lines.append("SOLUÇÕES PROPOSTAS:")
            report_lines.append("")
            report_lines.append("1. AUMENTAR TARGETS DE TP:")
            report_lines.append("   - TP1: 2:1 → 3:1 (50% mais longe)")
            report_lines.append("   - TP2: 4:1 → 6:1")
            report_lines.append("   - TP3: 6:1 → 9:1")
            report_lines.append("")
            report_lines.append("2. IMPLEMENTAR TRAILING MAIS AGRESSIVO:")
            report_lines.append("   - Ativar trailing em 1.5:1 ao invés de 2:1")
            report_lines.append("   - Multiplicador ATR: 2.5 → 3.0 (mais espaço)")
            report_lines.append("   - Permitir que lucro corra mais antes de apertar trailing")
            report_lines.append("")
            report_lines.append("3. USAR TPs DINÂMICOS BASEADOS EM VOLATILIDADE:")
            report_lines.append("   - ATR alto = TPs mais distantes")
            report_lines.append("   - Sessão com alto momentum = TPs maiores")
            report_lines.append("   - Ajustar TPs conforme condições de mercado")
            report_lines.append("")
        
        else:
            report_lines.append("✅ BALANÇO RAZOÁVEL:")
            report_lines.append("   Problema não é crítico, mas pode ser otimizado")
            report_lines.append("")
            report_lines.append("OTIMIZAÇÕES SUGERIDAS:")
            report_lines.append("   - Fine-tuning de TPs baseado em dados históricos")
            report_lines.append("   - A/B testing de cooldowns após TP")
            report_lines.append("   - Monitoramento contínuo de reentradas")
            report_lines.append("")
        
        # SEÇÃO 7: DADOS DETALHADOS
        report_lines.append("═" * 80)
        report_lines.append("7️⃣  AMOSTRA DE TRADES (Últimos 20)")
        report_lines.append("═" * 80)
        report_lines.append("")
        
        for i, trade in enumerate(self.trades[-20:], 1):
            report_lines.append(f"Trade #{i}:")
            report_lines.append(f"  Entrada: {trade.entry.timestamp.strftime('%Y-%m-%d %H:%M')} | {trade.entry.direction} @ {trade.entry.price:.5f}")
            report_lines.append(f"  Saída: {trade.exit.timestamp.strftime('%Y-%m-%d %H:%M')} | {trade.exit.exit_type} | {trade.exit.profit_pips:+.2f} pips")
            report_lines.append(f"  Sinal: Score {trade.entry.signal.score}/{trade.entry.signal.max_score} ({trade.signal_quality_score:.0f}%) | {trade.entry.signal.setup_class}")
            report_lines.append(f"  Duração: {trade.time_until_tp} min | Peak: {trade.peak_profit_pips:.2f} pips")
            report_lines.append("")
        
        # Salvar relatório
        output_file.write_text('\n'.join(report_lines), encoding='utf-8')
        print(f"\n✅ Relatório salvo em: {output_file}")
        
        # Imprimir resumo no console
        print("\n" + "═" * 80)
        print("📊 RESUMO EXECUTIVO")
        print("═" * 80)
        print(f"\n🎯 Taxa de reentrada: {reentry_rate:.1f}%")
        print(f"💰 Lucro na mesa: {self.stats['profit_left_on_table']:.2f} pips")
        print(f"💸 Perdas reentrada: {self.stats['losses_from_premature_reentry']:.2f} pips")
        print(f"📊 Impacto líquido: {net_impact:+.2f} pips")
        
        if reentry_rate > 25:
            print("\n🚨 PROBLEMA CRÍTICO: Reentradas prematuras")
            print("   → Implementar cooldown após TP!")
        elif self.stats['profit_left_on_table'] > 100:
            print("\n⚠️  PROBLEMA: TPs muito curtos")
            print("   → Aumentar targets ou trailing!")
        else:
            print("\n✅ Sistema balanceado - otimizações menores sugeridas")

def main():
    """Função principal"""
    
    print("\n" + "═" * 80)
    print("  MATHEMATICAL TRADE ANALYZER - Nexus Confluence EA")
    print("  Diagnóstico Matemático de TPs e Reentradas")
    print("═" * 80 + "\n")
    
    # Localizar log file
    log_dir = Path(__file__).parent.parent / 'log'
    log_files = sorted(log_dir.glob('*.log'), key=lambda x: x.stat().st_mtime, reverse=True)
    
    if not log_files:
        print("❌ Nenhum arquivo .log encontrado!")
        return 1
    
    latest_log = log_files[0]
    
    # Criar analisador
    analyzer = MathematicalTradeAnalyzer(latest_log)
    
    # Parse log
    analyzer.parse_log_file()
    
    # Calcular estatísticas
    analyzer.calculate_statistics()
    
    # Gerar relatório
    output_dir = Path(__file__).parent.parent / 'analysis_output'
    output_dir.mkdir(exist_ok=True)
    
    output_file = output_dir / f'DIAGNOSTICO_MATEMATICO_{datetime.now().strftime("%Y%m%d_%H%M%S")}.txt'
    analyzer.generate_report(output_file)
    
    print("\n✅ Análise concluída com sucesso!")
    return 0

if __name__ == '__main__':
    sys.exit(main())
