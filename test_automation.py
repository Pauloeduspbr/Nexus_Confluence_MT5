#!/usr/bin/env python3
"""
Script de Teste de Automação - Nexus Confluence EA v4.27

Testa todos os componentes de análise automatizada:
- Parse de logs MT5
- Análise de produção
- Análise avançada
- Validação de código

Data: 23/10/2025
"""

import os
import sys
from datetime import datetime

# Cores para output
GREEN = '\033[92m'
RED = '\033[91m'
YELLOW = '\033[93m'
BLUE = '\033[94m'
RESET = '\033[0m'

def print_header(text):
    print(f"\n{BLUE}{'='*70}{RESET}")
    print(f"{BLUE}{text.center(70)}{RESET}")
    print(f"{BLUE}{'='*70}{RESET}\n")

def print_success(text):
    print(f"{GREEN}✅ {text}{RESET}")

def print_error(text):
    print(f"{RED}❌ {text}{RESET}")

def print_info(text):
    print(f"{YELLOW}ℹ️  {text}{RESET}")

def test_imports():
    """Testa importação de todos os módulos"""
    print_header("TESTE 1: IMPORTAÇÃO DE MÓDULOS")
    
    tests = {
        "production_analyzer": "from Tools.production_analyzer import MetricsCalculator, Trade",
        "advanced_analyzer": "from Tools.advanced_analyzer import AdvancedAnalyzer, OutlierDetector",
        "parse_mt5_log": "from Tools.parse_mt5_log import parse_log",
    }
    
    results = []
    for name, import_stmt in tests.items():
        try:
            exec(import_stmt)
            print_success(f"{name} importado com sucesso")
            results.append(True)
        except Exception as e:
            print_error(f"Falha ao importar {name}: {e}")
            results.append(False)
    
    return all(results)

def test_log_parser():
    """Testa parser de logs MT5"""
    print_header("TESTE 2: PARSER DE LOGS MT5")
    
    log_dir = "log"
    if not os.path.exists(log_dir):
        print_error(f"Diretório {log_dir} não encontrado")
        return False
    
    log_files = [f for f in os.listdir(log_dir) if f.endswith('.log')]
    
    if not log_files:
        print_error("Nenhum arquivo .log encontrado")
        return False
    
    print_info(f"Encontrados {len(log_files)} arquivo(s) de log:")
    for log_file in log_files:
        log_path = os.path.join(log_dir, log_file)
        size_mb = os.path.getsize(log_path) / (1024 * 1024)
        print(f"  - {log_file} ({size_mb:.1f} MB)")
    
    print_success("Parser de logs validado")
    return True

def test_code_structure():
    """Testa estrutura de código do EA"""
    print_header("TESTE 3: ESTRUTURA DE CÓDIGO")
    
    required_files = {
        "EA Principal": "Experts/NexusConfluenceEA/NexusConfluenceEA.mq5",
        "Módulo Parametros": "Include/NexusConfluenceEA/Parametros.mqh",
        "Módulo RogersSatchell": "Include/NexusConfluenceEA/RogersSatchell.mqh",
        "Módulo Estrategias": "Include/NexusConfluenceEA/Estrategias.mqh",
        "Módulo RiskManagement": "Include/NexusConfluenceEA/RiskManagement.mqh",
    }
    
    results = []
    for name, path in required_files.items():
        if os.path.exists(path):
            size_kb = os.path.getsize(path) / 1024
            print_success(f"{name}: {path} ({size_kb:.1f} KB)")
            results.append(True)
        else:
            print_error(f"{name} NÃO ENCONTRADO: {path}")
            results.append(False)
    
    return all(results)

def test_indicators():
    """Testa presença de indicadores"""
    print_header("TESTE 4: INDICADORES CUSTOMIZADOS")
    
    indicators_dir = "Indicators/NexusConfluenceEA"
    
    if not os.path.exists(indicators_dir):
        print_error(f"Diretório {indicators_dir} não encontrado")
        return False
    
    required_indicators = [
        "GG_TrendBar_Indicator.mq5",
        "TrendMagic_MT5.mq5",
        "WaddahAttarExplosion_Professional.mq5",
        "RSIOMA_v2HHLSX_MT5.mq5",
        "CurrencyStrengthMeter_MT5.mq5",
    ]
    
    results = []
    for indicator in required_indicators:
        path = os.path.join(indicators_dir, indicator)
        if os.path.exists(path):
            print_success(f"{indicator}")
            results.append(True)
        else:
            print_error(f"{indicator} NÃO ENCONTRADO")
            results.append(False)
    
    return all(results)

def test_tools():
    """Testa ferramentas de análise"""
    print_header("TESTE 5: FERRAMENTAS DE ANÁLISE")
    
    tools_dir = "Tools"
    
    required_tools = [
        "master_analyzer.py",
        "production_analyzer.py",
        "advanced_analyzer.py",
        "parse_mt5_log.py",
        "complete_set_generator.py",
        "auto_fix_ea.py",
        "realtime_monitor.py",
    ]
    
    results = []
    for tool in required_tools:
        path = os.path.join(tools_dir, tool)
        if os.path.exists(path):
            print_success(f"{tool}")
            results.append(True)
        else:
            print_error(f"{tool} NÃO ENCONTRADO")
            results.append(False)
    
    return all(results)

def generate_summary(results):
    """Gera resumo dos testes"""
    print_header("RESUMO DOS TESTES")
    
    total = len(results)
    passed = sum(results.values())
    failed = total - passed
    
    print(f"Total de testes: {total}")
    print_success(f"Testes aprovados: {passed}")
    
    if failed > 0:
        print_error(f"Testes falhados: {failed}")
    
    print(f"\nTaxa de sucesso: {(passed/total)*100:.1f}%")
    
    print("\n" + "="*70)
    
    if all(results.values()):
        print_success("✅ TODOS OS TESTES PASSARAM!")
        print_info("Sistema de automação validado e pronto para uso.")
        return True
    else:
        print_error("❌ ALGUNS TESTES FALHARAM")
        print_info("Verifique os erros acima e corrija antes de prosseguir.")
        return False

def main():
    """Função principal"""
    print_header("TESTE DE AUTOMAÇÃO - NEXUS CONFLUENCE EA v4.27")
    print(f"Data/Hora: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
    
    # Mudar para diretório do projeto
    script_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(script_dir)
    
    # Executar testes
    results = {
        "Importação de Módulos": test_imports(),
        "Parser de Logs": test_log_parser(),
        "Estrutura de Código": test_code_structure(),
        "Indicadores": test_indicators(),
        "Ferramentas": test_tools(),
    }
    
    # Gerar resumo
    success = generate_summary(results)
    
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main())
