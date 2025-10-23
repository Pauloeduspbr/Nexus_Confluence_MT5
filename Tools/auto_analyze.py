#!/usr/bin/env python3
"""
🤖 NEXUS CONFLUENCE EA - AUTOMATED ANALYSIS & DIAGNOSTICS
=========================================================
Sistema completo de análise automatizada com diagnóstico de problemas

Funcionalidades:
1. Setup automático de ambiente
2. Execução da análise com captura completa de output
3. Parse de resultados e identificação de problemas
4. Geração de relatório de diagnóstico
5. Recomendações de correção

Uso:
    python auto_analyze.py
    
Autor: Sistema de Diagnóstico Automatizado Nexus
Data: 2025-10-22
Versão: 1.0.0 (Production Grade)
"""

import subprocess
import sys
import os
import json
import re
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass, asdict
from collections import defaultdict


@dataclass
class Problem:
    """Estrutura de problema identificado"""
    severity: str  # CRITICAL/HIGH/MEDIUM/LOW
    category: str  # PERFORMANCE/RISK/EXECUTION/DATA/CONFIG
    title: str
    description: str
    evidence: List[str]
    root_cause: str
    impact: str
    recommendation: str
    code_location: Optional[str] = None


@dataclass
class DiagnosticReport:
    """Relatório de diagnóstico completo"""
    timestamp: str
    execution_status: str
    total_trades: int
    problems_found: int
    problems: List[Problem]
    summary: Dict
    recommendations: List[str]


class AutomatedAnalyzer:
    """Orquestrador de análise automatizada"""
    
    def __init__(self, project_root: Path):
        self.project_root = project_root
        self.tools_dir = project_root / "Tools"
        self.output_dir = project_root / "analysis_output"
        self.venv_dir = project_root / "venv"
        
        self.execution_log = []
        self.problems = []
        
    def run_complete_analysis(self) -> DiagnosticReport:
        """Executa análise completa e retorna diagnóstico"""
        
        print("=" * 100)
        print("🤖 NEXUS CONFLUENCE EA - AUTOMATED ANALYSIS & DIAGNOSTICS")
        print("=" * 100)
        print(f"⏰ Started at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"📁 Project root: {self.project_root}")
        print("=" * 100)
        
        # Fase 1: Setup
        print("\n[FASE 1/5] 🔧 SETUP AUTOMÁTICO")
        print("-" * 100)
        setup_ok = self._setup_environment()
        
        if not setup_ok:
            print("❌ Setup falhou. Abortando.")
            return self._generate_failure_report("SETUP_FAILED")
        
        # Fase 2: Execução
        print("\n[FASE 2/5] ▶️  EXECUÇÃO DA ANÁLISE")
        print("-" * 100)
        exec_result = self._execute_analysis()
        
        # Fase 3: Parse de resultados
        print("\n[FASE 3/5] 📊 PARSE DE RESULTADOS")
        print("-" * 100)
        results = self._parse_results()
        
        # Fase 4: Diagnóstico
        print("\n[FASE 4/5] 🔍 DIAGNÓSTICO DE PROBLEMAS")
        print("-" * 100)
        self._diagnose_problems(exec_result, results)
        
        # Fase 5: Relatório
        print("\n[FASE 5/5] 📄 GERAÇÃO DE RELATÓRIO")
        print("-" * 100)
        report = self._generate_report(exec_result, results)
        
        self._save_report(report)
        
        print("\n" + "=" * 100)
        print("✅ ANÁLISE AUTOMATIZADA CONCLUÍDA")
        print(f"📊 Problemas encontrados: {len(self.problems)}")
        print(f"📁 Relatório: {self.output_dir / 'DIAGNOSTIC_REPORT.md'}")
        print("=" * 100)
        
        return report
    
    def _setup_environment(self) -> bool:
        """Setup automático de ambiente"""
        
        try:
            # Verificar Python
            print("   🐍 Verificando Python...")
            python_version = subprocess.run(
                [sys.executable, "--version"],
                capture_output=True,
                text=True
            )
            print(f"      ✓ {python_version.stdout.strip()}")
            
            # Criar venv se não existir
            if not self.venv_dir.exists():
                print("   📦 Criando ambiente virtual...")
                subprocess.run(
                    [sys.executable, "-m", "venv", str(self.venv_dir)],
                    check=True
                )
                print("      ✓ Ambiente virtual criado")
            else:
                print("   ✓ Ambiente virtual já existe")
            
            # Determinar executável Python do venv
            if sys.platform == "win32":
                venv_python = self.venv_dir / "Scripts" / "python.exe"
                venv_pip = self.venv_dir / "Scripts" / "pip.exe"
            else:
                venv_python = self.venv_dir / "bin" / "python"
                venv_pip = self.venv_dir / "bin" / "pip"
            
            # Verificar/instalar dependências
            print("   📦 Verificando dependências...")
            deps_check = subprocess.run(
                [str(venv_python), "-c", "import numpy, pandas, scipy, sklearn, tqdm"],
                capture_output=True
            )
            
            if deps_check.returncode != 0:
                print("   📦 Instalando dependências...")
                
                # Upgrade pip
                subprocess.run(
                    [str(venv_pip), "install", "--upgrade", "pip", "--quiet"],
                    check=True
                )
                
                # Instalar pacotes
                packages = ["numpy", "pandas", "scipy", "scikit-learn", "tqdm"]
                for pkg in packages:
                    print(f"      Instalando {pkg}...")
                    subprocess.run(
                        [str(venv_pip), "install", pkg, "--quiet"],
                        check=True
                    )
                
                print("      ✓ Todas as dependências instaladas")
            else:
                print("      ✓ Dependências já instaladas")
            
            return True
            
        except Exception as e:
            print(f"   ❌ Erro no setup: {e}")
            self.problems.append(Problem(
                severity="CRITICAL",
                category="CONFIG",
                title="Falha no setup do ambiente",
                description=f"Não foi possível configurar o ambiente: {str(e)}",
                evidence=[str(e)],
                root_cause="Ambiente Python não configurado corretamente",
                impact="Análise não pode ser executada",
                recommendation="Verifique instalação do Python 3.7+ e permissões"
            ))
            return False
    
    def _execute_analysis(self) -> Dict:
        """Executa análise e captura output completo"""
        
        # Criar diretório de output se não existir
        self.output_dir.mkdir(exist_ok=True)
        
        # Determinar executável Python do venv
        if sys.platform == "win32":
            venv_python = self.venv_dir / "Scripts" / "python.exe"
        else:
            venv_python = self.venv_dir / "bin" / "python"
        
        # Verificar se existe parse_mt5_log.py (usar esse ao invés)
        parse_script = self.tools_dir / "parse_mt5_log.py"
        
        if not parse_script.exists():
            print(f"   ❌ parse_mt5_log.py não encontrado em {parse_script}")
            return {"status": "ERROR", "message": "parse_mt5_log.py não encontrado"}
        
        # Procurar log file
        log_file = self.project_root / "log" / "20251022.log"
        if not log_file.exists():
            print(f"   ❌ Log file não encontrado: {log_file}")
            return {"status": "ERROR", "message": f"Log file não encontrado: {log_file}"}
        
        print(f"   ▶️  Executando análise do log: {log_file}")
        print("   ⏱️  Aguarde, isso pode levar alguns minutos...")
        
        try:
            # Executar parse do log
            result = subprocess.run(
                [str(venv_python), str(parse_script), str(log_file)],
                cwd=str(self.project_root),
                capture_output=True,
                text=True,
                timeout=600  # 10 minutos timeout
            )
            
            # Salvar logs
            self.execution_log = result.stdout.split('\n')
            
            # Salvar output completo
            output_file = self.output_dir / "execution_output.log"
            self.output_dir.mkdir(exist_ok=True)
            with open(output_file, 'w', encoding='utf-8') as f:
                f.write("=== STDOUT ===\n")
                f.write(result.stdout)
                f.write("\n\n=== STDERR ===\n")
                f.write(result.stderr)
            
            print(f"   ✓ Output salvo em: {output_file}")
            
            if result.returncode == 0:
                print("   ✅ Análise executada com sucesso")
                return {
                    "status": "SUCCESS",
                    "returncode": result.returncode,
                    "stdout": result.stdout,
                    "stderr": result.stderr
                }
            else:
                print(f"   ⚠️  Análise retornou código {result.returncode}")
                return {
                    "status": "WARNING",
                    "returncode": result.returncode,
                    "stdout": result.stdout,
                    "stderr": result.stderr
                }
                
        except subprocess.TimeoutExpired:
            print("   ❌ Timeout: Análise demorou mais de 10 minutos")
            return {"status": "TIMEOUT", "message": "Análise excedeu 10 minutos"}
            
        except Exception as e:
            print(f"   ❌ Erro na execução: {e}")
            return {"status": "ERROR", "message": str(e)}
    
    def _parse_results(self) -> Dict:
        """Parse dos resultados JSON gerados"""
        
        # Usar clean_stats.json que já existe
        stats_file = self.project_root / "log" / "clean_stats.json"
        
        if not stats_file.exists():
            print(f"   ⚠️  Arquivo de stats não encontrado: {stats_file}")
            return {}
        
        try:
            with open(stats_file, 'r', encoding='utf-8') as f:
                stats = json.load(f)
            
            print(f"   ✓ Estatísticas carregadas: {stats_file}")
            print(f"   📊 Dados:")
            print(f"      - Candles processados: {stats.get('candles', 0):,}")
            print(f"      - MTF Aprovados: {stats.get('mtf_approved', 0):,}")
            print(f"      - MTF Rejeitados: {stats.get('mtf_rejected', 0):,}")
            print(f"      - Setups GOOD: {stats.get('setups_good', 0):,}")
            print(f"      - Setups PREMIUM: {stats.get('setups_premium', 0):,}")
            print(f"      - Cálculos de risco: {stats.get('risk_calc', 0):,}")
            print(f"      - Valores ATR coletados: {len(stats.get('atr_values', [])):,}")
            
            return stats
            
        except json.JSONDecodeError as e:
            print(f"   ❌ Erro ao parsear JSON: {e}")
            return {}
        except Exception as e:
            print(f"   ❌ Erro ao ler resultados: {e}")
            return {}
    
    def _diagnose_problems(self, exec_result: Dict, results: Dict):
        """Diagnostica problemas do EA baseado nos resultados"""
        
        print("   🔍 Analisando performance e identificando problemas...")
        
        # 1. Problemas de execução
        self._check_execution_problems(exec_result)
        
        # 2. Problemas de performance
        self._check_performance_problems(results)
        
        # 3. Problemas de risco
        self._check_risk_problems(results)
        
        # 4. Problemas de execução de trades
        self._check_trade_execution_problems(results)
        
        # 5. Problemas de dados
        self._check_data_problems(results)
        
        # 6. Problemas de BE/TS
        self._check_be_ts_problems(results)
        
        print(f"   ✓ Diagnóstico concluído: {len(self.problems)} problemas identificados")
    
    def _check_execution_problems(self, exec_result: Dict):
        """Verifica problemas na execução da análise"""
        
        if exec_result.get("status") == "ERROR":
            self.problems.append(Problem(
                severity="CRITICAL",
                category="EXECUTION",
                title="Falha na execução da análise",
                description="A análise não pode ser completada devido a erros",
                evidence=[exec_result.get("message", "")],
                root_cause="Erro no código de análise ou ambiente",
                impact="Dados de performance não disponíveis",
                recommendation="Revisar logs de erro e corrigir problemas de código"
            ))
        
        elif exec_result.get("status") == "TIMEOUT":
            self.problems.append(Problem(
                severity="HIGH",
                category="PERFORMANCE",
                title="Análise excedeu tempo limite",
                description="Processamento demorou mais de 10 minutos",
                evidence=["Timeout após 10 minutos"],
                root_cause="Volume excessivo de dados ou código ineficiente",
                impact="Análise incompleta",
                recommendation="Otimizar código ou processar em lotes menores"
            ))
    
    def _check_performance_problems(self, results: Dict):
        """Verifica problemas de performance do EA"""
        
        # Análise baseada em estatísticas do log
        candles = results.get('candles', 0)
        mtf_approved = results.get('mtf_approved', 0)
        mtf_rejected = results.get('mtf_rejected', 0)
        setups_good = results.get('setups_good', 0)
        setups_premium = results.get('setups_premium', 0)
        risk_calc = results.get('risk_calc', 0)
        rejections = results.get('rejections', {})
        atr_values = results.get('atr_values', [])
        
        if candles == 0:
            return
        
        # 1. Taxa de aprovação MTF muito baixa
        mtf_total = mtf_approved + mtf_rejected
        if mtf_total > 0:
            mtf_approval_rate = (mtf_approved / mtf_total) * 100
            
            if mtf_approval_rate < 30:
                self.problems.append(Problem(
                    severity="HIGH",
                    category="PERFORMANCE",
                    title="Taxa de aprovação MTF muito baixa",
                    description=f"Apenas {mtf_approval_rate:.1f}% dos multi-timeframes são aprovados",
                    evidence=[
                        f"MTF Aprovados: {mtf_approved:,}",
                        f"MTF Rejeitados: {mtf_rejected:,}",
                        f"Taxa: {mtf_approval_rate:.1f}%"
                    ],
                    root_cause="Filtros MTF muito restritivos ou mercado sem tendência clara",
                    impact="Poucas oportunidades de trade geradas",
                    recommendation="Revisar configurações de alinhamento MTF ou considerar timeframes alternativos"
                ))
        
        # 2. Conversão de setups para execução muito baixa
        total_setups = setups_good + setups_premium
        if total_setups > 0:
            execution_rate = (risk_calc / total_setups) * 100
            
            if execution_rate < 20:
                self.problems.append(Problem(
                    severity="HIGH",
                    category="EXECUTION",
                    title="Taxa de execução de setups muito baixa",
                    description=f"Apenas {execution_rate:.1f}% dos setups são executados",
                    evidence=[
                        f"Setups identificados: {total_setups:,}",
                        f"Trades executados: {risk_calc:,}",
                        f"Taxa: {execution_rate:.1f}%"
                    ],
                    root_cause="Rejeições por margem ou gestão de risco muito conservadora",
                    impact="Oportunidades perdidas, sistema pouco ativo",
                    recommendation="Revisar gestão de margem ou reduzir tamanho de posições"
                ))
        
        # 3. Margem insuficiente recorrente
        margin_rejections = rejections.get('margem', 0)
        if risk_calc > 0:
            margin_rejection_rate = (margin_rejections / risk_calc) * 100
            
            if margin_rejection_rate > 30:
                self.problems.append(Problem(
                    severity="CRITICAL",
                    category="RISK",
                    title="Alto índice de rejeições por margem",
                    description=f"{margin_rejection_rate:.1f}% dos cálculos são rejeitados por margem",
                    evidence=[
                        f"Rejeições por margem: {margin_rejections:,}",
                        f"Total cálculos: {risk_calc:,}",
                        f"Taxa: {margin_rejection_rate:.1f}%"
                    ],
                    root_cause="Capital insuficiente ou tamanho de posições muito grande",
                    impact="Sistema não consegue operar adequadamente",
                    recommendation="Aumentar capital ou reduzir risco% por trade"
                ))
        
        # 4. Poucos setups PREMIUM
        if total_setups > 0:
            premium_rate = (setups_premium / total_setups) * 100
            
            if premium_rate < 10:
                self.problems.append(Problem(
                    severity="MEDIUM",
                    category="PERFORMANCE",
                    title="Poucos setups PREMIUM identificados",
                    description=f"Apenas {premium_rate:.1f}% dos setups são PREMIUM",
                    evidence=[
                        f"Setups PREMIUM: {setups_premium:,}",
                        f"Setups GOOD: {setups_good:,}",
                        f"Taxa PREMIUM: {premium_rate:.1f}%"
                    ],
                    root_cause="Filtros não estão confluindo adequadamente",
                    impact="Maioria dos trades com qualidade inferior",
                    recommendation="Revisar filtros RSI, WAE e Currency Strength para melhor confluência"
                ))
        
        # 5. ATR analysis
        if atr_values:
            import numpy as np
            atr_mean = np.mean(atr_values)
            atr_std = np.std(atr_values)
            atr_min = np.min(atr_values)
            atr_max = np.max(atr_values)
            
            # ATR muito alto indica alta volatilidade
            if atr_mean > 0.15:
                self.problems.append(Problem(
                    severity="MEDIUM",
                    category="RISK",
                    title="ATR médio muito alto",
                    description=f"ATR médio de {atr_mean:.5f} indica alta volatilidade",
                    evidence=[
                        f"ATR médio: {atr_mean:.5f}",
                        f"ATR máximo: {atr_max:.5f}",
                        f"Desvio padrão: {atr_std:.5f}"
                    ],
                    root_cause="Mercado em alta volatilidade",
                    impact="Stops mais largos, maior risco por trade",
                    recommendation="Considerar reduzir tamanho de posições ou aguardar normalização"
                ))
            
            # ATR muito baixo indica baixa volatilidade
            elif atr_mean < 0.05:
                self.problems.append(Problem(
                    severity="LOW",
                    category="PERFORMANCE",
                    title="ATR médio muito baixo",
                    description=f"ATR médio de {atr_mean:.5f} indica baixa volatilidade",
                    evidence=[
                        f"ATR médio: {atr_mean:.5f}",
                        f"ATR mínimo: {atr_min:.5f}"
                    ],
                    root_cause="Mercado em baixa volatilidade/consolidação",
                    impact="Movimentos pequenos, TPs demoram mais",
                    recommendation="Considerar ajustar TPs ou aguardar aumento de volatilidade"
                ))
        
        # 6. Volume de processamento
        processing_efficiency = (mtf_approved / candles) * 100 if candles > 0 else 0
        
        if processing_efficiency < 10:
            self.problems.append(Problem(
                severity="MEDIUM",
                category="PERFORMANCE",
                title="Baixa eficiência de processamento",
                description=f"Apenas {processing_efficiency:.1f}% dos candles geram análise MTF",
                evidence=[
                    f"Candles processados: {candles:,}",
                    f"MTF analisados: {mtf_approved:,}",
                    f"Eficiência: {processing_efficiency:.1f}%"
                ],
                root_cause="Muitos filtros pré-MTF ou horários muito restritivos",
                impact="Sistema muito seletivo, pode perder oportunidades",
                recommendation="Revisar filtros de horário e condições de mercado"
            ))
            
            # Win Rate baixo
            win_rate = metrics.get('win_rate_%', 0)
            if win_rate < 40:
                self.problems.append(Problem(
                    severity="CRITICAL",
                    category="PERFORMANCE",
                    title=f"Win Rate crítico em {set_name}",
                    description=f"Win rate de {win_rate:.1f}% está abaixo do mínimo aceitável (40%)",
                    evidence=[f"Win Rate: {win_rate:.1f}%"],
                    root_cause="Filtros muito permissivos ou estratégia não funcional",
                    impact="Alta probabilidade de perda de capital",
                    recommendation="Revisar filtros de entrada e aumentar requisitos de confluência"
                ))
            elif win_rate < 50:
                self.problems.append(Problem(
                    severity="HIGH",
                    category="PERFORMANCE",
                    title=f"Win Rate abaixo da meta em {set_name}",
                    description=f"Win rate de {win_rate:.1f}% está abaixo da meta (50%)",
                    evidence=[f"Win Rate: {win_rate:.1f}%"],
                    root_cause="Qualidade de setups pode ser melhorada",
                    impact="Performance subótima",
                    recommendation="Aumentar rigor dos filtros ou ajustar horários de trading"
                ))
            
            # Profit Factor baixo
            pf = metrics.get('profit_factor', 0)
            if pf < 1.0:
                self.problems.append(Problem(
                    severity="CRITICAL",
                    category="PERFORMANCE",
                    title=f"Profit Factor negativo em {set_name}",
                    description=f"PF de {pf:.2f} indica perdas sistêmicas",
                    evidence=[f"Profit Factor: {pf:.2f}"],
                    root_cause="Sistema não lucrativo neste ativo/configuração",
                    impact="Perda garantida de capital",
                    recommendation="PARAR trading imediatamente. Revisar estratégia completa."
                ))
            elif pf < 1.3:
                self.problems.append(Problem(
                    severity="HIGH",
                    category="PERFORMANCE",
                    title=f"Profit Factor baixo em {set_name}",
                    description=f"PF de {pf:.2f} está abaixo do mínimo (1.3)",
                    evidence=[f"Profit Factor: {pf:.2f}"],
                    root_cause="Relação risco/recompensa desfavorável",
                    impact="Lucro marginal, vulnerável a custos",
                    recommendation="Melhorar gestão de saídas (TP/TS) ou filtros de entrada"
                ))
            
            # Expectância negativa
            er = metrics.get('expectancy_E_R', 0)
            if er < 0:
                self.problems.append(Problem(
                    severity="CRITICAL",
                    category="PERFORMANCE",
                    title=f"Expectância negativa em {set_name}",
                    description=f"E_R de {er:.4f} indica perda esperada por trade",
                    evidence=[f"Expectancy: {er:.4f}"],
                    root_cause="Sistema estruturalmente não lucrativo",
                    impact="Perda sistemática de capital",
                    recommendation="PARAR trading. Sistema precisa ser redesenhado."
                ))
            elif er < 0.01:
                self.problems.append(Problem(
                    severity="MEDIUM",
                    category="PERFORMANCE",
                    title=f"Expectância muito baixa em {set_name}",
                    description=f"E_R de {er:.4f} é marginalmente positiva",
                    evidence=[f"Expectancy: {er:.4f}"],
                    root_cause="Vantagem estatística muito pequena",
                    impact="Lucro marginal, vulnerável a variações",
                    recommendation="Aumentar qualidade de setups ou ajustar R:R"
                ))
            
            # Sharpe Ratio baixo
            sharpe = metrics.get('sharpe_r', 0)
            if sharpe < 0.5:
                self.problems.append(Problem(
                    severity="MEDIUM",
                    category="RISK",
                    title=f"Sharpe Ratio baixo em {set_name}",
                    description=f"Sharpe de {sharpe:.2f} indica retorno/risco desfavorável",
                    evidence=[f"Sharpe Ratio: {sharpe:.2f}"],
                    root_cause="Alta volatilidade de resultados",
                    impact="Retornos inconsistentes",
                    recommendation="Filtrar setups de menor qualidade ou reduzir risco"
                ))
    
    def _check_risk_problems(self, results: Dict):
        """Verifica problemas de gestão de risco"""
        
        # Análise simplificada baseada em rejeições
        rejections = results.get('rejections', {})
        risk_calc = results.get('risk_calc', 0)
        
        # Rejeições por risco inválido
        risk_rejections = rejections.get('risco', 0)
        if risk_rejections > 10:
            self.problems.append(Problem(
                severity="HIGH",
                category="RISK",
                title="Muitas rejeições por risco inválido",
                description=f"{risk_rejections} cálculos de risco foram rejeitados",
                evidence=[f"Rejeições por risco: {risk_rejections}"],
                root_cause="SL muito largo ou validações de risco muito restritivas",
                impact="Oportunidades de trade perdidas",
                recommendation="Revisar cálculo de SL baseado em estrutura"
            ))
    
    def _check_trade_execution_problems(self, results: Dict):
        """Verifica problemas de execução de trades"""
        
        # Análise básica
        risk_calc = results.get('risk_calc', 0)
        
        if risk_calc == 0:
            self.problems.append(Problem(
                severity="CRITICAL",
                category="EXECUTION",
                title="Nenhum trade executado",
                description="Sistema não executou nenhum trade no período analisado",
                evidence=["Total de cálculos de risco: 0"],
                root_cause="Filtros muito restritivos ou problema de configuração",
                impact="Sistema inativo, sem geração de resultados",
                recommendation="Revisar configurações e reduzir rigor dos filtros"
            ))
        elif risk_calc < 10:
            self.problems.append(Problem(
                severity="HIGH",
                category="EXECUTION",
                title="Muito poucos trades executados",
                description=f"Apenas {risk_calc} trades foram calculados/executados",
                evidence=[f"Total trades: {risk_calc}"],
                root_cause="Filtros muito restritivos",
                impact="Amostra insuficiente para análise estatística",
                recommendation="Reduzir requisitos de confluência ou ampliar horários"
            ))
    
    def _check_data_problems(self, results: Dict):
        """Verifica problemas com dados"""
        
        candles = results.get('candles', 0)
        risk_calc = results.get('risk_calc', 0)
        
        # Poucos dados processados
        if candles < 1000:
            self.problems.append(Problem(
                severity="MEDIUM",
                category="DATA",
                title="Poucos dados processados",
                description=f"Apenas {candles:,} candles foram analisados",
                evidence=[f"Total candles: {candles:,}"],
                root_cause="Log file muito pequeno ou período curto",
                impact="Análise pode não ser representativa",
                recommendation="Coletar dados de período mais longo"
            ))
        
        # Amostra de trades pequena
        if 0 < risk_calc < 30:
            self.problems.append(Problem(
                severity="MEDIUM",
                category="DATA",
                title="Amostra de trades pequena",
                description=f"Apenas {risk_calc} trades para análise",
                evidence=[f"Total trades: {risk_calc}"],
                root_cause="Poucos trades executados",
                impact="Estatísticas podem não ser confiáveis",
                recommendation="Coletar mais dados (60+ trades) antes de conclusões definitivas"
            ))
    
    def _check_be_ts_problems(self, results: Dict):
        """Verifica problemas com BE/TS"""
        
        # Análise será feita quando tivermos dados de trades executados
        # Por enquanto, apenas placeholder
        pass
    
    def _generate_report(self, exec_result: Dict, results: Dict) -> DiagnosticReport:
        """Gera relatório de diagnóstico"""
        
        # Extrair total de trades das estatísticas
        total_trades = results.get('risk_calc', 0)
        
        # Categorizar problemas
        problems_by_severity = defaultdict(int)
        problems_by_category = defaultdict(int)
        
        for problem in self.problems:
            problems_by_severity[problem.severity] += 1
            problems_by_category[problem.category] += 1
        
        # Gerar recomendações principais
        recommendations = self._generate_top_recommendations()
        
        # Summary
        summary = {
            'total_trades': total_trades,
            'problems_by_severity': dict(problems_by_severity),
            'problems_by_category': dict(problems_by_category),
            'critical_issues': problems_by_severity.get('CRITICAL', 0),
            'high_issues': problems_by_severity.get('HIGH', 0),
            'execution_status': exec_result.get('status', 'UNKNOWN')
        }
        
        return DiagnosticReport(
            timestamp=datetime.now().isoformat(),
            execution_status=exec_result.get('status', 'UNKNOWN'),
            total_trades=total_trades,
            problems_found=len(self.problems),
            problems=self.problems,
            summary=summary,
            recommendations=recommendations
        )
    
    def _generate_top_recommendations(self) -> List[str]:
        """Gera recomendações principais baseadas nos problemas"""
        
        recs = []
        
        # Contar por categoria
        critical = [p for p in self.problems if p.severity == 'CRITICAL']
        high = [p for p in self.problems if p.severity == 'HIGH']
        
        if critical:
            recs.append("🚨 AÇÃO IMEDIATA: " + critical[0].recommendation)
        
        if len(critical) > 1:
            recs.append(f"🚨 Resolver {len(critical)} problemas CRÍTICOS antes de continuar trading")
        
        if high:
            recs.append("⚠️  ALTA PRIORIDADE: " + high[0].recommendation)
        
        # Recomendações por categoria
        perf_problems = [p for p in self.problems if p.category == 'PERFORMANCE']
        if len(perf_problems) >= 2:
            recs.append("📊 Revisar estratégia: múltiplos problemas de performance detectados")
        
        risk_problems = [p for p in self.problems if p.category == 'RISK']
        if len(risk_problems) >= 2:
            recs.append("🛡️  Ajustar gestão de risco: DD e VaR fora dos limites")
        
        if not recs:
            recs.append("✅ Nenhuma ação crítica necessária no momento")
        
        return recs
    
    def _save_report(self, report: DiagnosticReport):
        """Salva relatório em arquivo Markdown"""
        
        # Garantir que diretório existe
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
        md_file = self.output_dir / "DIAGNOSTIC_REPORT.md"
        
        md = []
        md.append("# 🔍 NEXUS CONFLUENCE EA - RELATÓRIO DE DIAGNÓSTICO AUTOMATIZADO")
        md.append("")
        md.append(f"**Data:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        md.append(f"**Status Execução:** {report.execution_status}")
        md.append(f"**Total de Trades Analisados:** {report.total_trades}")
        md.append(f"**Problemas Encontrados:** {report.problems_found}")
        md.append("")
        md.append("---")
        md.append("")
        
        # Executive Summary
        md.append("## 📊 SUMÁRIO EXECUTIVO")
        md.append("")
        md.append(f"- **Problemas Críticos:** {report.summary['problems_by_severity'].get('CRITICAL', 0)}")
        md.append(f"- **Problemas Alta Prioridade:** {report.summary['problems_by_severity'].get('HIGH', 0)}")
        md.append(f"- **Problemas Média Prioridade:** {report.summary['problems_by_severity'].get('MEDIUM', 0)}")
        md.append(f"- **Problemas Baixa Prioridade:** {report.summary['problems_by_severity'].get('LOW', 0)}")
        md.append("")
        
        # Problemas por categoria
        md.append("### Distribuição por Categoria")
        md.append("")
        for cat, count in report.summary['problems_by_category'].items():
            md.append(f"- **{cat}:** {count}")
        md.append("")
        md.append("---")
        md.append("")
        
        # Recomendações Principais
        md.append("## 💡 RECOMENDAÇÕES PRINCIPAIS")
        md.append("")
        for i, rec in enumerate(report.recommendations, 1):
            md.append(f"{i}. {rec}")
        md.append("")
        md.append("---")
        md.append("")
        
        # Detalhamento dos Problemas
        md.append("## 🚨 PROBLEMAS IDENTIFICADOS (DETALHADO)")
        md.append("")
        
        # Agrupar por severidade
        for severity in ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW']:
            problems = [p for p in report.problems if p.severity == severity]
            
            if not problems:
                continue
            
            emoji = {
                'CRITICAL': '🔴',
                'HIGH': '🟠',
                'MEDIUM': '🟡',
                'LOW': '🟢'
            }
            
            md.append(f"### {emoji[severity]} {severity} ({len(problems)})")
            md.append("")
            
            for i, problem in enumerate(problems, 1):
                md.append(f"#### {i}. {problem.title}")
                md.append("")
                md.append(f"**Categoria:** {problem.category}")
                md.append("")
                md.append(f"**Descrição:** {problem.description}")
                md.append("")
                md.append("**Evidências:**")
                for ev in problem.evidence:
                    md.append(f"- {ev}")
                md.append("")
                md.append(f"**Causa Raiz:** {problem.root_cause}")
                md.append("")
                md.append(f"**Impacto:** {problem.impact}")
                md.append("")
                md.append(f"**Recomendação:** {problem.recommendation}")
                md.append("")
                if problem.code_location:
                    md.append(f"**Localização no Código:** `{problem.code_location}`")
                    md.append("")
                md.append("---")
                md.append("")
        
        # Salvar JSON também
        json_file = self.output_dir / "diagnostic_report.json"
        with open(json_file, 'w', encoding='utf-8') as f:
            json.dump(asdict(report), f, indent=2, ensure_ascii=False, default=str)
        
        # Salvar Markdown
        with open(md_file, 'w', encoding='utf-8') as f:
            f.write('\n'.join(md))
        
        print(f"   ✓ Relatório Markdown: {md_file}")
        print(f"   ✓ Relatório JSON: {json_file}")
    
    def _generate_failure_report(self, reason: str) -> DiagnosticReport:
        """Gera relatório de falha"""
        
        return DiagnosticReport(
            timestamp=datetime.now().isoformat(),
            execution_status="FAILED",
            total_trades=0,
            problems_found=len(self.problems),
            problems=self.problems,
            summary={'failure_reason': reason},
            recommendations=["Resolver problemas de setup antes de executar análise"]
        )


def main():
    """Ponto de entrada principal"""
    
    # Determinar projeto root
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    
    # Executar análise automatizada
    analyzer = AutomatedAnalyzer(project_root)
    
    try:
        report = analyzer.run_complete_analysis()
        
        # Mostrar sumário
        print("\n" + "=" * 100)
        print("📋 SUMÁRIO DO DIAGNÓSTICO")
        print("=" * 100)
        print(f"Problemas Críticos: {report.summary.get('problems_by_severity', {}).get('CRITICAL', 0)}")
        print(f"Problemas Alta Prioridade: {report.summary.get('problems_by_severity', {}).get('HIGH', 0)}")
        print(f"Total de Problemas: {report.problems_found}")
        print("")
        print("Principais Recomendações:")
        for rec in report.recommendations[:3]:
            print(f"  • {rec}")
        print("=" * 100)
        
        # Exit code baseado em severidade
        if report.summary.get('problems_by_severity', {}).get('CRITICAL', 0) > 0:
            sys.exit(2)  # Problemas críticos
        elif report.summary.get('problems_by_severity', {}).get('HIGH', 0) > 0:
            sys.exit(1)  # Problemas altos
        else:
            sys.exit(0)  # OK
            
    except KeyboardInterrupt:
        print("\n\n⚠️  Análise interrompida pelo usuário")
        sys.exit(130)
    except Exception as e:
        print(f"\n\n❌ Erro fatal: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
