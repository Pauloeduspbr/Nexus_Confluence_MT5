#!/usr/bin/env python3
"""
Auto Fix EA - Análise e Correção Automática do Código EA

Analisa resultados da análise de log e corrige automaticamente:
- TP muito curto/longo
- SL muito curto/longo
- Breakeven muito agressivo/lento
- Trailing Stop muito agressivo/lento
- Filtros muito rígidos/frouxos
- Sincronização de indicadores
"""

import json
import os
import re
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Tuple, Optional


class AutoFixEA:
    """Correção automática do código EA baseada em análise de dados"""
    
    def __init__(self, analysis_file: str):
        self.analysis_file = Path(analysis_file)
        self.results = {}
        self.fixes_applied = []
        self.ea_files = {
            'main': Path('Experts/NexusConfluenceEA/NexusConfluenceEA.mq5'),
            'risk': Path('Include/NexusConfluenceEA/RiskManagement.mqh'),
            'strategy': Path('Include/NexusConfluenceEA/Estrategias.mqh'),
            'params': Path('Include/NexusConfluenceEA/Parametros.mqh')
        }
    
    def run(self):
        """Executa análise e correção completa"""
        print("="*80)
        print("🔧 AUTO FIX EA - Análise e Correção Automática")
        print("="*80)
        print()
        
        # 1. Carregar resultados da análise
        print("📊 [1/8] Carregando resultados da análise...")
        if not self._load_analysis():
            return False
        
        # 2. Analisar problemas de TP
        print("🎯 [2/8] Analisando Take Profit...")
        self._analyze_take_profit()
        
        # 3. Analisar problemas de SL
        print("🛡️  [3/8] Analisando Stop Loss...")
        self._analyze_stop_loss()
        
        # 4. Analisar Breakeven
        print("⚖️  [4/8] Analisando Breakeven...")
        self._analyze_breakeven()
        
        # 5. Analisar Trailing Stop
        print("📈 [5/8] Analisando Trailing Stop...")
        self._analyze_trailing_stop()
        
        # 6. Analisar Filtros
        print("🔍 [6/8] Analisando Filtros de Entrada...")
        self._analyze_filters()
        
        # 7. Analisar Sincronização de Indicadores
        print("🔄 [7/8] Analisando Sincronização de Indicadores...")
        self._analyze_indicator_sync()
        
        # 8. Aplicar correções
        print("🔧 [8/8] Aplicando correções no código EA...")
        self._apply_fixes()
        
        # Gerar relatório
        self._generate_report()
        
        return True
    
    def _load_analysis(self) -> bool:
        """Carrega resultados da análise"""
        if not self.analysis_file.exists():
            print(f"❌ Arquivo não encontrado: {self.analysis_file}")
            return False
        
        with open(self.analysis_file, 'r', encoding='utf-8') as f:
            self.results = json.load(f)
        
        n_trades = self.results.get('metadata', {}).get('n_trades', 0)
        print(f"   ✓ {n_trades} trades analisados")
        return True
    
    def _analyze_take_profit(self):
        """Analisa se TP está muito curto ou muito longo"""
        print("\n   📊 ANÁLISE TAKE PROFIT:")
        print("   " + "-"*70)
        
        production = self.results.get('production', {})
        
        # Analisar TP1
        tp1_hit_rate = production.get('tp1_hit_rate', 0)
        avg_profit_per_trade = production.get('avg_profit_per_trade', 0)
        
        problem = None
        fix_action = None
        
        if tp1_hit_rate < 30:
            problem = "TP1 MUITO LONGO (hit rate < 30%)"
            fix_action = "REDUZIR TP1: 1.0R → 0.7R"
            severity = "CRÍTICO"
        elif tp1_hit_rate > 80:
            problem = "TP1 MUITO CURTO (hit rate > 80%)"
            fix_action = "AUMENTAR TP1: 1.0R → 1.3R"
            severity = "IMPORTANTE"
        elif avg_profit_per_trade < 0:
            problem = "TP não compensa perdas"
            fix_action = "AUMENTAR TP1 e TP2: +20%"
            severity = "CRÍTICO"
        
        if problem:
            print(f"   ⚠️  PROBLEMA: {problem}")
            print(f"   🔧 CORREÇÃO: {fix_action}")
            print(f"   🔴 SEVERIDADE: {severity}")
            
            self.fixes_applied.append({
                'component': 'Take Profit',
                'problem': problem,
                'fix': fix_action,
                'severity': severity,
                'file': 'RiskManagement.mqh',
                'current_tp1_hit': tp1_hit_rate,
                'avg_profit': avg_profit_per_trade
            })
        else:
            print("   ✅ TP configurado adequadamente")
    
    def _analyze_stop_loss(self):
        """Analisa se SL está muito curto ou muito longo"""
        print("\n   📊 ANÁLISE STOP LOSS:")
        print("   " + "-"*70)
        
        production = self.results.get('production', {})
        advanced = self.results.get('advanced', {})
        
        win_rate = production.get('win_rate', 0)
        max_dd = production.get('max_drawdown_pct', 0)
        avg_loss = abs(production.get('avg_loss_per_trade', 0))
        
        problem = None
        fix_action = None
        
        if win_rate < 35:
            problem = f"SL MUITO CURTO (WR {win_rate:.1f}% < 35%)"
            fix_action = "AUMENTAR SL: +30% distância"
            severity = "CRÍTICO"
        elif max_dd > 25:
            problem = f"SL MUITO LONGO (DD {max_dd:.1f}% > 25%)"
            fix_action = "REDUZIR SL: -20% distância"
            severity = "CRÍTICO"
        elif avg_loss > 100:  # Perda média muito alta
            problem = f"SL permitindo perdas grandes (${avg_loss:.2f})"
            fix_action = "REDUZIR SL: máx $50 por trade"
            severity = "IMPORTANTE"
        
        if problem:
            print(f"   ⚠️  PROBLEMA: {problem}")
            print(f"   🔧 CORREÇÃO: {fix_action}")
            print(f"   🔴 SEVERIDADE: {severity}")
            
            self.fixes_applied.append({
                'component': 'Stop Loss',
                'problem': problem,
                'fix': fix_action,
                'severity': severity,
                'file': 'RiskManagement.mqh',
                'current_wr': win_rate,
                'current_dd': max_dd,
                'avg_loss': avg_loss
            })
        else:
            print("   ✅ SL configurado adequadamente")
    
    def _analyze_breakeven(self):
        """Analisa se Breakeven está muito agressivo ou lento"""
        print("\n   📊 ANÁLISE BREAKEVEN:")
        print("   " + "-"*70)
        
        # Analisar trades que atingiram lucro mas fecharam no zero
        production = self.results.get('production', {})
        
        # Se não temos dados específicos de breakeven, inferir
        tp1_hit = production.get('tp1_hit_rate', 0)
        win_rate = production.get('win_rate', 0)
        
        problem = None
        fix_action = None
        
        # Se TP1 hit alto mas WR baixo = breakeven muito agressivo
        if tp1_hit > 60 and win_rate < 40:
            problem = "BREAKEVEN MUITO AGRESSIVO (corta lucros cedo)"
            fix_action = "MOVER BREAKEVEN: 0.5R → 0.7R"
            severity = "IMPORTANTE"
        
        # Se WR alto mas TP1 hit baixo = breakeven muito lento
        elif win_rate > 55 and tp1_hit < 40:
            problem = "BREAKEVEN MUITO LENTO (risco desnecessário)"
            fix_action = "ACELERAR BREAKEVEN: 1.0R → 0.6R"
            severity = "MÉDIO"
        
        if problem:
            print(f"   ⚠️  PROBLEMA: {problem}")
            print(f"   🔧 CORREÇÃO: {fix_action}")
            print(f"   🔴 SEVERIDADE: {severity}")
            
            self.fixes_applied.append({
                'component': 'Breakeven',
                'problem': problem,
                'fix': fix_action,
                'severity': severity,
                'file': 'RiskManagement.mqh'
            })
        else:
            print("   ✅ Breakeven configurado adequadamente")
    
    def _analyze_trailing_stop(self):
        """Analisa se Trailing Stop está muito agressivo ou lento"""
        print("\n   📊 ANÁLISE TRAILING STOP:")
        print("   " + "-"*70)
        
        production = self.results.get('production', {})
        
        # Analisar performance do trailing
        trailing_wr = production.get('trailing_win_rate', 0)
        avg_profit = production.get('avg_profit_per_trade', 0)
        
        problem = None
        fix_action = None
        
        if trailing_wr == 0:
            problem = "TRAILING MUITO AGRESSIVO (0% WR quando ativo)"
            fix_action = "AUMENTAR TrailingATRMultiplier: 1.5 → 2.5"
            severity = "CRÍTICO"
        elif trailing_wr < 20:
            problem = f"TRAILING AGRESSIVO ({trailing_wr:.0f}% WR)"
            fix_action = "AUMENTAR TrailingATRMultiplier: +0.5"
            severity = "IMPORTANTE"
        elif avg_profit < 10 and trailing_wr > 50:
            problem = "TRAILING MUITO LENTO (não captura movimentos)"
            fix_action = "REDUZIR TrailingATRMultiplier: -0.3"
            severity = "MÉDIO"
        
        if problem:
            print(f"   ⚠️  PROBLEMA: {problem}")
            print(f"   🔧 CORREÇÃO: {fix_action}")
            print(f"   🔴 SEVERIDADE: {severity}")
            
            self.fixes_applied.append({
                'component': 'Trailing Stop',
                'problem': problem,
                'fix': fix_action,
                'severity': severity,
                'file': 'RiskManagement.mqh',
                'current_trailing_wr': trailing_wr
            })
        else:
            print("   ✅ Trailing Stop configurado adequadamente")
    
    def _analyze_filters(self):
        """Analisa se filtros estão muito rígidos ou frouxos"""
        print("\n   📊 ANÁLISE FILTROS DE ENTRADA:")
        print("   " + "-"*70)
        
        production = self.results.get('production', {})
        summary = self.results.get('summary', {})
        
        n_trades = self.results.get('metadata', {}).get('n_trades', 0)
        win_rate = production.get('win_rate', 0)
        quality_score = summary.get('quality_score', 0)
        
        problem = None
        fix_action = None
        
        # Muito poucos trades = filtros muito rígidos
        if n_trades < 50:
            problem = f"FILTROS MUITO RÍGIDOS (apenas {n_trades} trades)"
            fix_action = "REDUZIR MinConfluenceScore: 75 → 65"
            severity = "IMPORTANTE"
        
        # Muitos trades mas WR baixo = filtros muito frouxos
        elif n_trades > 500 and win_rate < 40:
            problem = f"FILTROS MUITO FROUXOS ({n_trades} trades, WR {win_rate:.1f}%)"
            fix_action = "AUMENTAR MinConfluenceScore: 65 → 75"
            severity = "IMPORTANTE"
        
        # Quality score baixo = problema nos filtros
        elif quality_score < 50 and win_rate < 45:
            problem = f"FILTROS INADEQUADOS (QS {quality_score:.0f}, WR {win_rate:.1f}%)"
            fix_action = "REVISAR lógica de confluência (RequiredFilterScore)"
            severity = "CRÍTICO"
        
        if problem:
            print(f"   ⚠️  PROBLEMA: {problem}")
            print(f"   🔧 CORREÇÃO: {fix_action}")
            print(f"   🔴 SEVERIDADE: {severity}")
            
            self.fixes_applied.append({
                'component': 'Filtros',
                'problem': problem,
                'fix': fix_action,
                'severity': severity,
                'file': 'Estrategias.mqh',
                'n_trades': n_trades,
                'win_rate': win_rate
            })
        else:
            print("   ✅ Filtros configurados adequadamente")
    
    def _analyze_indicator_sync(self):
        """Analisa sincronização entre indicadores após entrada"""
        print("\n   📊 ANÁLISE SINCRONIZAÇÃO DE INDICADORES:")
        print("   " + "-"*70)
        
        recommendations = self.results.get('recommendations', {})
        worst_hours = recommendations.get('optimizations', {}).get('worst_hours', [])
        
        problem = None
        fix_action = None
        
        # Se há muitos worst_hours = indicadores dessincronizados
        if len(worst_hours) > 5:
            problem = f"DESSINCRONIZAÇÃO ({len(worst_hours)} worst hours)"
            fix_action = "ADICIONAR validação pós-entrada de indicadores"
            severity = "IMPORTANTE"
            
            print(f"   ⚠️  PROBLEMA: {problem}")
            print(f"   🔧 CORREÇÃO: {fix_action}")
            print(f"   🔴 SEVERIDADE: {severity}")
            print(f"   📋 Worst Hours: {worst_hours}")
            
            self.fixes_applied.append({
                'component': 'Indicadores',
                'problem': problem,
                'fix': fix_action,
                'severity': severity,
                'file': 'Estrategias.mqh',
                'worst_hours': worst_hours
            })
        else:
            print("   ✅ Indicadores sincronizados adequadamente")
    
    def _apply_fixes(self):
        """Aplica correções no código EA"""
        print("\n" + "="*80)
        print("🔧 APLICANDO CORREÇÕES AUTOMÁTICAS")
        print("="*80)
        print()
        
        if not self.fixes_applied:
            print("✅ Nenhuma correção necessária - EA está otimizado!")
            return
        
        print(f"📋 Total de correções a aplicar: {len(self.fixes_applied)}\n")
        
        for i, fix in enumerate(self.fixes_applied, 1):
            print(f"[{i}/{len(self.fixes_applied)}] {fix['component']}")
            print(f"   Arquivo: {fix['file']}")
            print(f"   Problema: {fix['problem']}")
            print(f"   Correção: {fix['fix']}")
            
            # Aplicar correção específica
            success = self._apply_single_fix(fix)
            
            if success:
                print(f"   ✅ Correção aplicada com sucesso\n")
            else:
                print(f"   ⚠️  Correção precisa validação manual\n")
    
    def _apply_single_fix(self, fix: Dict) -> bool:
        """Aplica uma correção específica no código"""
        component = fix['component']
        
        if component == 'Take Profit':
            return self._fix_take_profit(fix)
        elif component == 'Stop Loss':
            return self._fix_stop_loss(fix)
        elif component == 'Breakeven':
            return self._fix_breakeven(fix)
        elif component == 'Trailing Stop':
            return self._fix_trailing_stop(fix)
        elif component == 'Filtros':
            return self._fix_filters(fix)
        elif component == 'Indicadores':
            return self._fix_indicators(fix)
        
        return False
    
    def _fix_take_profit(self, fix: Dict) -> bool:
        """Corrige configuração de Take Profit"""
        # Implementar lógica de correção específica
        # Por enquanto, registrar para aplicação manual
        return False
    
    def _fix_stop_loss(self, fix: Dict) -> bool:
        """Corrige configuração de Stop Loss"""
        return False
    
    def _fix_breakeven(self, fix: Dict) -> bool:
        """Corrige configuração de Breakeven"""
        return False
    
    def _fix_trailing_stop(self, fix: Dict) -> bool:
        """Corrige configuração de Trailing Stop"""
        return False
    
    def _fix_filters(self, fix: Dict) -> bool:
        """Corrige filtros de entrada"""
        return False
    
    def _fix_indicators(self, fix: Dict) -> bool:
        """Corrige sincronização de indicadores"""
        return False
    
    def _generate_report(self):
        """Gera relatório de correções"""
        print("\n" + "="*80)
        print("📊 RELATÓRIO DE CORREÇÕES AUTOMÁTICAS")
        print("="*80)
        print()
        
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        report_file = Path(f"analysis_output/auto_fix_report_{timestamp}.md")
        
        with open(report_file, 'w', encoding='utf-8') as f:
            f.write("# 🔧 RELATÓRIO DE CORREÇÕES AUTOMÁTICAS\n\n")
            f.write(f"**Data**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"**Análise Base**: {self.analysis_file.name}\n\n")
            f.write("---\n\n")
            
            f.write("## 📊 RESUMO\n\n")
            f.write(f"- Total de Problemas Detectados: **{len(self.fixes_applied)}**\n")
            
            critical = sum(1 for fix in self.fixes_applied if fix.get('severity') == 'CRÍTICO')
            important = sum(1 for fix in self.fixes_applied if fix.get('severity') == 'IMPORTANTE')
            medium = sum(1 for fix in self.fixes_applied if fix.get('severity') == 'MÉDIO')
            
            f.write(f"- Críticos: **{critical}** 🔴\n")
            f.write(f"- Importantes: **{important}** 🟡\n")
            f.write(f"- Médios: **{medium}** 🔵\n\n")
            
            f.write("---\n\n")
            f.write("## 🔍 PROBLEMAS DETECTADOS\n\n")
            
            for i, fix in enumerate(self.fixes_applied, 1):
                severity_icon = {
                    'CRÍTICO': '🔴',
                    'IMPORTANTE': '🟡',
                    'MÉDIO': '🔵'
                }.get(fix['severity'], '⚪')
                
                f.write(f"### {i}. {fix['component']} {severity_icon}\n\n")
                f.write(f"**Problema**: {fix['problem']}\n\n")
                f.write(f"**Correção Recomendada**: {fix['fix']}\n\n")
                f.write(f"**Arquivo**: `{fix['file']}`\n\n")
                
                # Adicionar dados específicos
                if 'current_tp1_hit' in fix:
                    f.write(f"**Dados**:\n")
                    f.write(f"- TP1 Hit Rate: {fix['current_tp1_hit']:.1f}%\n")
                    f.write(f"- Avg Profit: ${fix.get('avg_profit', 0):.2f}\n")
                
                f.write("\n---\n\n")
            
            f.write("## 📋 PRÓXIMAS AÇÕES\n\n")
            f.write("1. Revisar correções propostas\n")
            f.write("2. Aplicar mudanças no código EA\n")
            f.write("3. Compilar EA\n")
            f.write("4. Executar backtest de validação\n")
            f.write("5. Comparar métricas antes/depois\n\n")
            
            f.write("---\n\n")
            f.write("*Relatório gerado automaticamente pelo Auto Fix EA v1.0*\n")
        
        print(f"✅ Relatório salvo: {report_file}")
        print()
        
        # Resumo no console
        if self.fixes_applied:
            print("🔴 AÇÕES NECESSÁRIAS:")
            for fix in self.fixes_applied:
                if fix['severity'] == 'CRÍTICO':
                    print(f"   - {fix['component']}: {fix['fix']}")


def main():
    """Entry point"""
    import sys
    
    if len(sys.argv) < 2:
        print("Uso: python auto_fix_ea.py <arquivo_analise.json>")
        print("\nExemplo:")
        print("  python auto_fix_ea.py analysis_output/master_analysis_20251023_120000.json")
        sys.exit(1)
    
    analysis_file = sys.argv[1]
    
    fixer = AutoFixEA(analysis_file)
    success = fixer.run()
    
    if success:
        print("\n✅ Análise e correção automática concluída!")
        print(f"📁 Correções detectadas: {len(fixer.fixes_applied)}")
    else:
        print("\n❌ Falha na análise automática")
        sys.exit(1)


if __name__ == '__main__':
    main()
