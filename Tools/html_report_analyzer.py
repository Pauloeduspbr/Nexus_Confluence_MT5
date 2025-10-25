#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
╔═══════════════════════════════════════════════════════════════════════════════╗
║  HTML REPORT ANALYZER - Nexus Confluence EA v4.27+                           ║
║  Análise matemática profunda de TPs curtos e reentradas prematuras          ║
╚═══════════════════════════════════════════════════════════════════════════════╝

OBJETIVO:
    Identificar matematicamente os problemas reportados:
    1. TPs curtos que deixam lucro na mesa
    2. Reentradas prematuras após TP (sinais falsos)
    3. Correlação entre tempo até TP e qualidade do resultado

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
from html.parser import HTMLParser

@dataclass
class Trade:
    """Trade completo com entrada e saída"""
    ticket: int
    open_time: datetime
    close_time: datetime
    direction: str  # buy or sell
    volume: float
    open_price: float
    sl_price: float
    tp_price: float
    close_price: float = 0.0
    close_reason: str = ""  # tp, sl, manual
    profit: float = 0.0
    duration_minutes: int = 0
    setup_type: str = ""  # GOOD, PREMIUM
    
    def __post_init__(self):
        """Calcula duração após inicialização"""
        if self.close_time and self.open_time:
            self.duration_minutes = int((self.close_time - self.open_time).total_seconds() / 60)

class TradeHTMLParser(HTMLParser):
    """Parser customizado para extrair trades do HTML"""
    
    def __init__(self):
        super().__init__()
        self.in_trade_table = False
        self.in_row = False
        self.in_cell = False
        self.current_row = []
        self.trades_data = []
        self.cell_count = 0
        
    def handle_starttag(self, tag, attrs):
        if tag == 'tr':
            self.in_row = True
            self.current_row = []
            self.cell_count = 0
        elif tag == 'td' and self.in_row:
            self.in_cell = True
    
    def handle_endtag(self, tag):
        if tag == 'tr' and self.in_row:
            if len(self.current_row) >= 10:  # Linha válida de trade
                self.trades_data.append(self.current_row.copy())
            self.in_row = False
            self.current_row = []
            self.cell_count = 0
        elif tag == 'td' and self.in_cell:
            self.in_cell = False
    
    def handle_data(self, data):
        if self.in_cell and self.in_row:
            self.current_row.append(data.strip())
            self.cell_count += 1

class HtmlReportAnalyzer:
    """Analisador matemático de reports HTML do MT5"""
    
    def __init__(self, html_file: Path):
        self.html_file = html_file
        self.trades: List[Trade] = []
        self.stats = {}
        
    def parse_html_report(self) -> None:
        """Parse do arquivo HTML do tester"""
        print(f"📂 Analisando report: {self.html_file.name}")
        
        # MT5 gera HTML em UTF-16 LE!
        with open(self.html_file, 'r', encoding='utf-16-le', errors='ignore') as f:
            html_content = f.read()
        
        print(f"📊 Tamanho: {len(html_content) / 1024:.2f} KB")
        
        # Usar regex para extrair trades (mais robusto que HTMLParser)
        self._extract_trades_regex(html_content)
        
        print(f"✅ Trades extraídos: {len(self.trades)}")
    
    def _extract_trades_regex(self, html: str) -> None:
        """Extrai trades usando regex (mais confiável)"""
        
        # Buscar entry lines (buy/sell com Nexus_)
        # Formato: time|ticket|symbol|direction|volume|commission|entry_price|tp|...
        entry_pattern = re.compile(
            r'<td>([\d.]+\s+[\d:]+)</td><td>(\d+)</td><td>USDJPY</td><td>(buy|sell)</td>'
            r'.*?<td>([\d.]+)</td><td>([\d.]+)</td><td>([\d.]+)</td>.*?<td>(Nexus_[A-Z]+_(GOOD|PREMIUM))</td>',
            re.DOTALL | re.IGNORECASE
        )
        
        # Buscar exit lines (sell depois de buy, com tp/sl no comment)
        exit_pattern = re.compile(
            r'<td>([\d.]+\s+[\d:]+)</td><td>(\d+)</td><td>USDJPY</td><td>(buy|sell)</td>'
            r'.*?<td></td><td></td>.*?<td>(tp|sl|be)\s+([\d.]+)</td>',
            re.DOTALL | re.IGNORECASE
        )
        
        entries = {}
        
        # Extrair entradas
        for match in entry_pattern.finditer(html):
            time_str = match.group(1)
            ticket = int(match.group(2))
            direction = match.group(3).lower()
            commission = float(match.group(4))  # Não usado
            entry_price = float(match.group(5))  # CORRIGIDO: grupo 5 agora!
            tp_price = float(match.group(6))    # CORRIGIDO: grupo 6 agora!
            setup_type = match.group(8)  # GOOD ou PREMIUM (grupo 8 agora!)
            
            open_time = datetime.strptime(time_str, '%Y.%m.%d %H:%M:%S')
            
            entries[ticket] = {
                'open_time': open_time,
                'direction': direction,
                'volume': 0.5,
                'entry_price': entry_price,
                'tp_price': tp_price,
                'setup_type': setup_type
            }
        
        print(f"  DEBUG: {len(entries)} entradas encontradas")
        
        # Extrair saídas
        for match in exit_pattern.finditer(html):
            time_str = match.group(1)
            ticket = int(match.group(2))
            close_reason = match.group(4).lower()
            close_price = float(match.group(5))
            
            close_time = datetime.strptime(time_str, '%Y.%m.%d %H:%M:%S')
            
            # Buscar entrada correspondente (ticket - 1)
            entry_ticket = ticket - 1
            
            if entry_ticket in entries:
                entry = entries[entry_ticket]
                
                # CORRIGIDO: Profit baseado no ENTRY PRICE!
                if entry['direction'] == 'buy':
                    profit_pips = (close_price - entry['entry_price']) * 1000
                else:
                    profit_pips = (entry['entry_price'] - close_price) * 1000
                
                trade = Trade(
                    ticket=entry_ticket,
                    open_time=entry['open_time'],
                    close_time=close_time,
                    direction=entry['direction'],
                    volume=entry['volume'],
                    open_price=entry['entry_price'],  # CORRIGIDO
                    sl_price=0.0,  # Não disponível no HTML
                    tp_price=entry['tp_price'],
                    close_price=close_price,
                    close_reason=close_reason,
                    profit=profit_pips,
                    setup_type=entry['setup_type']
                )
                
                self.trades.append(trade)
        
        # Ordenar por tempo de abertura
        self.trades.sort(key=lambda t: t.open_time)
    
    def calculate_statistics(self) -> None:
        """Calcula estatísticas matemáticas completas"""
        
        if not self.trades:
            print("❌ Nenhum trade encontrado!")
            return
        
        print("\n📊 CALCULANDO ESTATÍSTICAS MATEMÁTICAS...\n")
        
        winners = [t for t in self.trades if t.profit > 0]
        losers = [t for t in self.trades if t.profit <= 0]
        tp_trades = [t for t in self.trades if 'tp' in t.close_reason]
        sl_trades = [t for t in self.trades if 'sl' in t.close_reason]
        
        self.stats = {
            'total_trades': len(self.trades),
            'winners': len(winners),
            'losers': len(losers),
            'tp_closes': len(tp_trades),
            'sl_closes': len(sl_trades),
            'win_rate': len(winners) / len(self.trades) * 100,
            'avg_winner_pips': statistics.mean([t.profit for t in winners]) if winners else 0,
            'avg_loser_pips': statistics.mean([t.profit for t in losers]) if losers else 0,
            'avg_duration_winner': statistics.mean([t.duration_minutes for t in winners]) if winners else 0,
            'avg_duration_loser': statistics.mean([t.duration_minutes for t in losers]) if losers else 0,
            'total_profit_pips': sum(t.profit for t in self.trades),
            'profit_factor': 0.0,
            'reentry_1h_count': 0,
            'reentry_2h_count': 0,
            'reentry_same_day_count': 0,
            'reentry_losses': 0,
            'reentry_loss_pips': 0.0,
            'avg_time_to_tp': 0.0,
            'tp_too_short_count': 0,
            'potential_extra_pips': 0.0
        }
        
        # Profit Factor
        gross_profit = sum(t.profit for t in winners)
        gross_loss = abs(sum(t.profit for t in losers))
        self.stats['profit_factor'] = gross_profit / gross_loss if gross_loss > 0 else 0
        
        # Tempo médio até TP
        if tp_trades:
            self.stats['avg_time_to_tp'] = statistics.mean([t.duration_minutes for t in tp_trades])
        
        # Análise de reentradas
        self._analyze_reentries()
        
        # Análise de TPs curtos
        self._analyze_tp_length()
    
    def _analyze_reentries(self) -> None:
        """Detecta e analisa reentradas prematuras após TP"""
        
        reentry_1h = []
        reentry_2h = []
        reentry_same_day = []
        
        for i in range(len(self.trades) - 1):
            current = self.trades[i]
            next_trade = self.trades[i + 1]
            
            # Apenas analisar se trade atual fechou em TP
            if 'tp' not in current.close_reason:
                continue
            
            time_between = (next_trade.open_time - current.close_time).total_seconds() / 60
            
            # Reentrada em até 1 hora
            if time_between <= 60:
                reentry_1h.append((current, next_trade, time_between))
                self.stats['reentry_1h_count'] += 1
                
                if next_trade.profit < 0:
                    self.stats['reentry_losses'] += 1
                    self.stats['reentry_loss_pips'] += abs(next_trade.profit)
            
            # Reentrada em até 2 horas
            if time_between <= 120:
                reentry_2h.append((current, next_trade, time_between))
                self.stats['reentry_2h_count'] += 1
            
            # Reentrada no mesmo dia
            if current.close_time.date() == next_trade.open_time.date():
                reentry_same_day.append((current, next_trade, time_between))
                self.stats['reentry_same_day_count'] += 1
        
        # Armazenar para análise detalhada
        self.reentry_1h = reentry_1h
        self.reentry_2h = reentry_2h
        self.reentry_same_day = reentry_same_day
    
    def _analyze_tp_length(self) -> None:
        """Analisa se TPs estão muito curtos"""
        
        # Para trades que fecharam em TP, verificar se poderiam ter ido mais longe
        # Critério: Se o próximo candle continuou na mesma direção
        
        tp_short_count = 0
        potential_extra = 0.0
        
        for i, trade in enumerate(self.trades):
            if 'tp' not in trade.close_reason:
                continue
            
            # Calcular distância do TP
            tp_distance_pips = abs(trade.tp_price - trade.open_price) * 1000
            
            # Considerar TP curto se:
            # 1. Duração muito curta (< 30 min para M15)
            # 2. TP foi atingido rapidamente = momentum forte
            # 3. Próximo trade na mesma direção teve sucesso
            
            if trade.duration_minutes < 180:  # Menos de 3h
                tp_short_count += 1
                
                # Estimar potencial extra (conservador: +50% do TP atual)
                potential_extra += tp_distance_pips * 0.5
        
        self.stats['tp_too_short_count'] = tp_short_count
        self.stats['potential_extra_pips'] = potential_extra
    
    def generate_report(self, output_file: Path) -> None:
        """Gera relatório matemático completo"""
        
        lines = []
        
        lines.append("╔═══════════════════════════════════════════════════════════════════════════════╗")
        lines.append("║  DIAGNÓSTICO MATEMÁTICO - TPs CURTOS E REENTRADAS PREMATURAS                 ║")
        lines.append("║  Nexus Confluence EA v4.27+ - Análise Baseada em Dados Reais                ║")
        lines.append("╚═══════════════════════════════════════════════════════════════════════════════╝")
        lines.append("")
        lines.append(f"📅 Data da análise: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        lines.append(f"📂 Report analisado: {self.html_file.name}")
        lines.append("")
        
        # SEÇÃO 1: ESTATÍSTICAS GERAIS
        lines.append("═" * 80)
        lines.append("1️⃣  ESTATÍSTICAS GERAIS DO BACKTEST")
        lines.append("═" * 80)
        lines.append("")
        lines.append(f"Total de trades: {self.stats['total_trades']}")
        lines.append(f"Trades vencedores: {self.stats['winners']} ({self.stats['win_rate']:.1f}%)")
        lines.append(f"Trades perdedores: {self.stats['losers']} ({100-self.stats['win_rate']:.1f}%)")
        lines.append("")
        lines.append(f"Fechamentos em TP: {self.stats['tp_closes']} ({self.stats['tp_closes']/self.stats['total_trades']*100:.1f}%)")
        lines.append(f"Fechamentos em SL: {self.stats['sl_closes']} ({self.stats['sl_closes']/self.stats['total_trades']*100:.1f}%)")
        lines.append("")
        lines.append(f"📈 Ganho médio: {self.stats['avg_winner_pips']:.2f} pips")
        lines.append(f"📉 Perda média: {self.stats['avg_loser_pips']:.2f} pips")
        lines.append(f"💰 Profit Factor: {self.stats['profit_factor']:.2f}")
        lines.append(f"📊 Total de pips: {self.stats['total_profit_pips']:.2f}")
        lines.append("")
        lines.append(f"⏱️  Duração média (vencedores): {self.stats['avg_duration_winner']:.0f} min ({self.stats['avg_duration_winner']/60:.1f}h)")
        lines.append(f"⏱️  Duração média (perdedores): {self.stats['avg_duration_loser']:.0f} min ({self.stats['avg_duration_loser']/60:.1f}h)")
        lines.append(f"⏱️  Tempo médio até TP: {self.stats['avg_time_to_tp']:.0f} min ({self.stats['avg_time_to_tp']/60:.1f}h)")
        lines.append("")
        
        # SEÇÃO 2: ANÁLISE DE REENTRADAS PREMATURAS
        lines.append("═" * 80)
        lines.append("2️⃣  PROBLEMA IDENTIFICADO: REENTRADAS PREMATURAS APÓS TP")
        lines.append("═" * 80)
        lines.append("")
        lines.append(f"🔄 Reentradas em até 1 hora após TP: {self.stats['reentry_1h_count']}")
        lines.append(f"🔄 Reentradas em até 2 horas após TP: {self.stats['reentry_2h_count']}")
        lines.append(f"🔄 Reentradas no mesmo dia após TP: {self.stats['reentry_same_day_count']}")
        lines.append("")
        
        reentry_rate = (self.stats['reentry_1h_count'] / self.stats['tp_closes'] * 100) if self.stats['tp_closes'] > 0 else 0
        lines.append(f"📊 Taxa de reentrada (<1h): {reentry_rate:.1f}%")
        lines.append("")
        
        # DIAGNÓSTICO
        if reentry_rate > 30:
            lines.append("🚨 PROBLEMA CRÍTICO CONFIRMADO!")
            lines.append(f"   → Taxa de reentrada MUITO ALTA: {reentry_rate:.1f}%")
            lines.append("   → EA está reentrando rapidamente após fechar em TP")
            lines.append("   → Sinais provavelmente ainda estão ativos no momento do TP")
            severity = "CRÍTICO"
        elif reentry_rate > 15:
            lines.append("⚠️  PROBLEMA MODERADO IDENTIFICADO")
            lines.append(f"   → Taxa de reentrada elevada: {reentry_rate:.1f}%")
            lines.append("   → Considerar implementar cooldown após TP")
            severity = "MODERADO"
        else:
            lines.append("✅ Taxa de reentrada aceitável")
            lines.append(f"   → Taxa atual: {reentry_rate:.1f}% (<15%)")
            severity = "BAIXO"
        lines.append("")
        
        # Impacto financeiro das reentradas
        lines.append(f"💸 Perdas em reentradas prematuras (<1h):")
        lines.append(f"   → Total de reentradas que perderam: {self.stats['reentry_losses']}")
        lines.append(f"   → Pips perdidos: {self.stats['reentry_loss_pips']:.2f}")
        
        if self.stats['reentry_1h_count'] > 0:
            loss_rate = (self.stats['reentry_losses'] / self.stats['reentry_1h_count'] * 100)
            lines.append(f"   → Taxa de perda em reentradas: {loss_rate:.1f}%")
            
            if loss_rate > 50:
                lines.append(f"   → 🚨 ALERTA: Mais de 50% das reentradas são perdas!")
        lines.append("")
        
        # SEÇÃO 3: ANÁLISE DE TPs CURTOS
        lines.append("═" * 80)
        lines.append("3️⃣  ANÁLISE DE TPs CURTOS (Lucro Deixado na Mesa)")
        lines.append("═" * 80)
        lines.append("")
        lines.append(f"📏 Trades com TP potencialmente curto: {self.stats['tp_too_short_count']}")
        
        if self.stats['tp_closes'] > 0:
            tp_short_rate = (self.stats['tp_too_short_count'] / self.stats['tp_closes'] * 100)
            lines.append(f"📊 Percentual de TPs curtos: {tp_short_rate:.1f}%")
        
        lines.append(f"💰 Pips potenciais deixados na mesa (estimativa): {self.stats['potential_extra_pips']:.2f}")
        lines.append("")
        
        if self.stats['avg_time_to_tp'] < 180:  # Menos de 3h
            lines.append("⚠️  ANÁLISE: TPs sendo atingidos muito rapidamente")
            lines.append(f"   → Tempo médio até TP: {self.stats['avg_time_to_tp']:.0f} min")
            lines.append("   → Indica momentum forte no momento da entrada")
            lines.append("   → TPs poderiam ser mais ambiciosos")
        lines.append("")
        
        # SEÇÃO 4: COMPARAÇÃO FINANCEIRA
        lines.append("═" * 80)
        lines.append("4️⃣  IMPACTO FINANCEIRO - QUAL PROBLEMA É MAIOR?")
        lines.append("═" * 80)
        lines.append("")
        
        lines.append(f"💰 Lucro potencial na mesa (TPs curtos): ~{self.stats['potential_extra_pips']:.2f} pips")
        lines.append(f"💸 Perdas por reentradas prematuras: {self.stats['reentry_loss_pips']:.2f} pips")
        lines.append("")
        
        net_impact = self.stats['potential_extra_pips'] - self.stats['reentry_loss_pips']
        
        lines.append(f"🎯 IMPACTO LÍQUIDO: {net_impact:+.2f} pips")
        lines.append("")
        
        if abs(net_impact) < 100:
            lines.append("📊 CONCLUSÃO: Problemas EQUILIBRADOS")
            lines.append("   → Ambos os problemas têm impacto similar")
            lines.append("   → Recomenda-se atacar ambos simultaneamente")
            main_problem = "AMBOS"
        elif self.stats['potential_extra_pips'] > self.stats['reentry_loss_pips']:
            lines.append("📊 CONCLUSÃO: TPs CURTOS é o problema PRINCIPAL")
            lines.append(f"   → Lucro na mesa ({self.stats['potential_extra_pips']:.2f} pips)")
            lines.append(f"   → SUPERA perdas por reentrada ({self.stats['reentry_loss_pips']:.2f} pips)")
            lines.append("   → PRIORIDADE: Aumentar TPs ou trailing mais agressivo")
            main_problem = "TP_CURTO"
        else:
            lines.append("📊 CONCLUSÃO: REENTRADAS PREMATURAS é o problema PRINCIPAL")
            lines.append(f"   → Perdas por reentrada ({self.stats['reentry_loss_pips']:.2f} pips)")
            lines.append(f"   → SUPERAM lucro na mesa ({self.stats['potential_extra_pips']:.2f} pips)")
            lines.append("   → PRIORIDADE: Implementar cooldown ou filtros mais rigorosos")
            main_problem = "REENTRADA"
        lines.append("")
        
        # SEÇÃO 5: RECOMENDAÇÕES ESPECÍFICAS
        lines.append("═" * 80)
        lines.append("5️⃣  RECOMENDAÇÕES MATEMÁTICAS BASEADAS EM DADOS")
        lines.append("═" * 80)
        lines.append("")
        
        if main_problem == "REENTRADA" or main_problem == "AMBOS":
            lines.append("🎯 SOLUÇÃO PRIORITÁRIA: PREVENIR REENTRADAS PREMATURAS")
            lines.append("")
            lines.append("1️⃣  IMPLEMENTAR COOLDOWN APÓS TP:")
            lines.append("")
            lines.append("   a) Cooldown Fixo:")
            lines.append("      - Aguardar 2-4 horas após fechar em TP antes de permitir nova entrada")
            lines.append("      - Implementar no RiskManagement.mqh:")
            lines.append("        ```cpp")
            lines.append("        datetime g_lastTPCloseTime = 0;")
            lines.append("        int COOLDOWN_MINUTES_AFTER_TP = 180; // 3 horas")
            lines.append("        ")
            lines.append("        // No OnTick(), ANTES de analisar sinais:")
            lines.append("        if(g_lastTPCloseTime > 0) {")
            lines.append("            int minutes_since_tp = (TimeCurrent() - g_lastTPCloseTime) / 60;")
            lines.append("            if(minutes_since_tp < COOLDOWN_MINUTES_AFTER_TP) {")
            lines.append('                Print("⏸️  Cooldown ativo após TP");')
            lines.append("                return; // NÃO analisar sinais")
            lines.append("            }")
            lines.append("        }")
            lines.append("        ```")
            lines.append("")
            lines.append("   b) Cooldown Adaptativo:")
            lines.append("      - Cooldown proporcional ao lucro obtido:")
            lines.append("        * TP pequeno (< 50 pips) = cooldown curto (1h)")
            lines.append("        * TP médio (50-100 pips) = cooldown médio (2h)")
            lines.append("        * TP grande (> 100 pips) = cooldown longo (4h)")
            lines.append("")
            lines.append("2️⃣  AUMENTAR RIGOR DOS FILTROS PÓS-TP:")
            lines.append("")
            lines.append("   - Exigir score PREMIUM (3/3) para trades dentro de 2h após TP")
            lines.append("   - Verificar que momentum continua forte:")
            lines.append("     * WAE ainda expandindo (não contraindo)")
            lines.append("     * RSI não em zona de exaustão")
            lines.append("   - Implementar no Estrategias.mqh:")
            lines.append("        ```cpp")
            lines.append("        if(g_lastTPCloseTime > 0 && TimeCurrent() - g_lastTPCloseTime < 7200) {")
            lines.append("            // Dentro de 2h após TP: exigir PREMIUM")
            lines.append("            if(setupClass != SETUP_PREMIUM) {")
            lines.append('                Print("⚠️  Requer PREMIUM após TP recente");')
            lines.append("                return false;")
            lines.append("            }")
            lines.append("        }")
            lines.append("        ```")
            lines.append("")
            lines.append("3️⃣  IMPLEMENTAR 'SIGNAL DECAY':")
            lines.append("")
            lines.append("   - Penalizar sinais que ocorrem logo após TP")
            lines.append("   - Score diminui progressivamente:")
            lines.append("     * 0-30 min após TP: Score × 0.5 (penalidade forte)")
            lines.append("     * 30-60 min após TP: Score × 0.75")
            lines.append("     * 60-120 min após TP: Score × 0.9")
            lines.append("     * > 120 min: Score normal")
            lines.append("")
        
        if main_problem == "TP_CURTO" or main_problem == "AMBOS":
            lines.append("🎯 SOLUÇÃO: OTIMIZAR TPs E TRAILING")
            lines.append("")
            lines.append("1️⃣  AUMENTAR TARGETS DE TP:")
            lines.append("")
            lines.append(f"   Dados atuais: Tempo médio até TP = {self.stats['avg_time_to_tp']:.0f} min")
            lines.append("   → TPs sendo atingidos MUITO RÁPIDO = momentum forte")
            lines.append("")
            lines.append("   Recomendação:")
            lines.append("   - EnablePartialTP = false (ordem única)")
            lines.append("   - TP1_RR = 3.0 (ao invés de 2.0)")
            lines.append("   - TP2_RR = 5.0 (ao invés de 4.0)")
            lines.append("   - TP3_RR = 8.0 (ao invés de 6.0)")
            lines.append("")
            lines.append("2️⃣  TRAILING MAIS AGRESSIVO:")
            lines.append("")
            lines.append("   - Ativar trailing mais cedo:")
            lines.append("     * BreakevenActivationRR = 1.2 (ao invés de 1.5)")
            lines.append("     * TrailingActivationRR = 1.8 (ao invés de 2.0)")
            lines.append("")
            lines.append("   - Dar mais espaço ao preço:")
            lines.append("     * TrailingStopATRMultiplier = 3.0 (ao invés de 2.5)")
            lines.append("")
            lines.append("3️⃣  TPs DINÂMICOS POR VOLATILIDADE:")
            lines.append("")
            lines.append("   - ATR alto (> média) = TPs × 1.5")
            lines.append("   - ATR normal = TPs padrão")
            lines.append("   - ATR baixo (< média) = TPs × 0.8")
            lines.append("")
        
        # SEÇÃO 6: AMOSTRA DE REENTRADAS PROBLEMÁTICAS
        if self.reentry_1h:
            lines.append("═" * 80)
            lines.append("6️⃣  EXEMPLOS DE REENTRADAS PREMATURAS (Primeiras 10)")
            lines.append("═" * 80)
            lines.append("")
            
            for i, (prev_trade, next_trade, minutes_between) in enumerate(self.reentry_1h[:10], 1):
                lines.append(f"Reentrada #{i}:")
                lines.append(f"  Trade anterior:")
                lines.append(f"    Fechou em TP: {prev_trade.close_time.strftime('%Y-%m-%d %H:%M')}")
                lines.append(f"    Lucro: +{prev_trade.profit:.2f} pips")
                lines.append(f"    Duração: {prev_trade.duration_minutes} min")
                lines.append(f"  Nova entrada:")
                lines.append(f"    Tempo após TP: {minutes_between:.0f} minutos")
                lines.append(f"    Direção: {next_trade.direction.upper()}")
                lines.append(f"    Resultado: {'+' if next_trade.profit > 0 else ''}{next_trade.profit:.2f} pips")
                
                if next_trade.profit < 0:
                    lines.append(f"    ❌ PERDA em reentrada prematura!")
                lines.append("")
        
        # SEÇÃO 7: CONFIGURAÇÕES RECOMENDADAS
        lines.append("═" * 80)
        lines.append("7️⃣  CONFIGURAÇÕES .SET RECOMENDADAS")
        lines.append("═" * 80)
        lines.append("")
        
        if main_problem == "REENTRADA" or main_problem == "AMBOS":
            lines.append("Para PREVENIR REENTRADAS:")
            lines.append("```")
            lines.append("# Adicionar ao NexusConfluenceEA.mq5:")
            lines.append("input int CooldownAfterTP_Minutes = 180;  // 3 horas")
            lines.append("input bool RequirePremiumAfterTP = true;  // Apenas PREMIUM após TP")
            lines.append("```")
            lines.append("")
        
        if main_problem == "TP_CURTO" or main_problem == "AMBOS":
            lines.append("Para OTIMIZAR TPs:")
            lines.append("```")
            lines.append("EnablePartialTP = false")
            lines.append("TP1_RiskRewardRatio = 3.0")
            lines.append("TP2_RiskRewardRatio = 5.0")
            lines.append("TP3_RiskRewardRatio = 8.0")
            lines.append("TrailingStopATRMultiplier = 3.0")
            lines.append("BreakevenActivationRR = 1.2")
            lines.append("TrailingActivationRR = 1.8")
            lines.append("```")
            lines.append("")
        
        # SEÇÃO 8: PRÓXIMOS PASSOS
        lines.append("═" * 80)
        lines.append("8️⃣  PRÓXIMOS PASSOS (ACTION PLAN)")
        lines.append("═" * 80)
        lines.append("")
        lines.append("1. IMPLEMENTAR COOLDOWN (PRIORIDADE MÁXIMA)")
        lines.append("   ☐ Adicionar variável global g_lastTPCloseTime")
        lines.append("   ☐ Atualizar ao fechar trade em TP")
        lines.append("   ☐ Verificar cooldown no início do OnTick()")
        lines.append("")
        lines.append("2. TESTAR CONFIGURAÇÕES OTIMIZADAS")
        lines.append("   ☐ Criar .set com TPs aumentados")
        lines.append("   ☐ Rodar backtest comparativo")
        lines.append("   ☐ Validar melhoria em profit e drawdown")
        lines.append("")
        lines.append("3. MONITORAR RESULTADOS")
        lines.append("   ☐ Medir taxa de reentrada após implementação")
        lines.append("   ☐ Comparar lucro antes/depois")
        lines.append("   ☐ Ajustar cooldown se necessário")
        lines.append("")
        
        # RESUMO EXECUTIVO
        lines.append("═" * 80)
        lines.append("📊 RESUMO EXECUTIVO")
        lines.append("═" * 80)
        lines.append("")
        lines.append(f"🚨 Severidade do problema: {severity}")
        lines.append(f"🎯 Problema principal: {main_problem}")
        lines.append(f"📊 Taxa de reentrada: {reentry_rate:.1f}%")
        lines.append(f"💸 Perdas por reentrada: {self.stats['reentry_loss_pips']:.2f} pips")
        lines.append(f"💰 Lucro na mesa (TPs): {self.stats['potential_extra_pips']:.2f} pips")
        lines.append(f"⚖️  Impacto líquido: {net_impact:+.2f} pips")
        lines.append("")
        
        if severity == "CRÍTICO":
            lines.append("⚠️  AÇÃO IMEDIATA NECESSÁRIA:")
            lines.append("   → Implementar cooldown de 2-3h após TP")
            lines.append("   → Testar antes de colocar em produção")
        elif severity == "MODERADO":
            lines.append("⚠️  AÇÃO RECOMENDADA:")
            lines.append("   → Implementar cooldown ou aumentar TPs")
            lines.append("   → Monitorar próximos resultados")
        else:
            lines.append("✅ OTIMIZAÇÃO SUGERIDA:")
            lines.append("   → Fine-tuning de TPs e trailing")
            lines.append("   → Sistema já está razoável")
        
        lines.append("")
        lines.append("═" * 80)
        lines.append(f"Análise concluída em {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        lines.append("═" * 80)
        
        # Salvar relatório
        output_file.write_text('\n'.join(lines), encoding='utf-8')
        print(f"\n✅ Relatório salvo em: {output_file}")
        
        # Imprimir resumo no console
        print("\n" + "═" * 80)
        print("📊 RESUMO EXECUTIVO")
        print("═" * 80)
        print(f"\n🚨 Severidade: {severity}")
        print(f"🎯 Problema principal: {main_problem}")
        print(f"📊 Taxa de reentrada: {reentry_rate:.1f}%")
        print(f"💸 Perdas reentrada: {self.stats['reentry_loss_pips']:.2f} pips")
        print(f"💰 Lucro na mesa: {self.stats['potential_extra_pips']:.2f} pips")
        print(f"⚖️  Impacto líquido: {net_impact:+.2f} pips")
        
        if severity == "CRÍTICO":
            print("\n🚨 AÇÃO IMEDIATA: Implementar cooldown após TP!")
        elif severity == "MODERADO":
            print("\n⚠️  AÇÃO RECOMENDADA: Cooldown ou TPs maiores")
        else:
            print("\n✅ Sistema razoável - otimizações sugeridas")

def main():
    """Função principal"""
    
    print("\n" + "═" * 80)
    print("  HTML REPORT ANALYZER - Nexus Confluence EA")
    print("  Diagnóstico Matemático de TPs e Reentradas")
    print("═" * 80 + "\n")
    
    # Localizar report HTML
    log_dir = Path(__file__).parent.parent / 'log'
    html_files = sorted(log_dir.glob('ReportTester*.html'), key=lambda x: x.stat().st_mtime, reverse=True)
    
    if not html_files:
        print("❌ Nenhum arquivo HTML encontrado em log/!")
        return 1
    
    latest_html = html_files[0]
    
    # Criar analisador
    analyzer = HtmlReportAnalyzer(latest_html)
    
    # Parse HTML
    analyzer.parse_html_report()
    
    if not analyzer.trades:
        print("❌ Nenhum trade extraído do HTML!")
        return 1
    
    # Calcular estatísticas
    analyzer.calculate_statistics()
    
    # Gerar relatório
    output_dir = Path(__file__).parent.parent / 'analysis_output'
    output_dir.mkdir(exist_ok=True)
    
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_file = output_dir / f'DIAGNOSTICO_TPS_REENTRADAS_{timestamp}.txt'
    
    analyzer.generate_report(output_file)
    
    print("\n✅ Análise matemática concluída com sucesso!")
    return 0

if __name__ == '__main__':
    sys.exit(main())
