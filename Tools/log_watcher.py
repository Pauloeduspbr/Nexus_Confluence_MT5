#!/usr/bin/env python3
"""
Log Watcher - Monitora pasta de logs e aciona análise automática

Detecta novos arquivos de log MT5 e dispara análise completa + correções
"""

import os
import sys
import time
import json
from pathlib import Path
from datetime import datetime
from typing import Set, Optional
import hashlib


class LogWatcher:
    """Monitora pasta de logs e aciona análise automática"""
    
    def __init__(self, log_dir: str = "log", check_interval: int = 60):
        self.log_dir = Path(log_dir)
        self.check_interval = check_interval
        self.processed_logs: Set[str] = set()
        self.state_file = Path(".log_watcher_state.json")
        
        # Carregar estado anterior
        self._load_state()
    
    def _load_state(self):
        """Carrega logs já processados"""
        if self.state_file.exists():
            with open(self.state_file, 'r') as f:
                state = json.load(f)
                self.processed_logs = set(state.get('processed_logs', []))
            print(f"✓ Estado carregado: {len(self.processed_logs)} logs já processados")
    
    def _save_state(self):
        """Salva estado atual"""
        state = {
            'processed_logs': list(self.processed_logs),
            'last_update': datetime.now().isoformat()
        }
        with open(self.state_file, 'w') as f:
            json.dump(state, f, indent=2)
    
    def _get_log_hash(self, log_path: Path) -> str:
        """Calcula hash do arquivo para detectar mudanças"""
        with open(log_path, 'rb') as f:
            return hashlib.md5(f.read()).hexdigest()
    
    def _is_valid_log(self, log_path: Path) -> bool:
        """Verifica se é um arquivo de log válido"""
        if not log_path.is_file():
            return False
        
        # Aceitar .log ou .txt
        if log_path.suffix not in ['.log', '.txt']:
            return False
        
        # Verificar tamanho mínimo (10 KB)
        if log_path.stat().st_size < 10 * 1024:
            return False
        
        # Verificar se contém padrões MT5
        try:
            with open(log_path, 'r', encoding='utf-8', errors='ignore') as f:
                sample = f.read(5000)
                if 'MetaTrader' in sample or 'Expert' in sample or 'deal' in sample:
                    return True
        except:
            pass
        
        return False
    
    def scan_for_new_logs(self) -> list:
        """Escaneia pasta por novos logs"""
        new_logs = []
        
        if not self.log_dir.exists():
            print(f"⚠ Pasta de logs não existe: {self.log_dir}")
            return new_logs
        
        for log_file in self.log_dir.glob('*'):
            if not self._is_valid_log(log_file):
                continue
            
            # Calcular hash
            log_hash = self._get_log_hash(log_file)
            log_id = f"{log_file.name}:{log_hash}"
            
            # Se não processado ou mudou
            if log_id not in self.processed_logs:
                new_logs.append({
                    'path': log_file,
                    'id': log_id,
                    'size': log_file.stat().st_size,
                    'modified': datetime.fromtimestamp(log_file.stat().st_mtime)
                })
        
        return new_logs
    
    def process_log(self, log_info: dict) -> bool:
        """Processa um log detectado"""
        log_path = log_info['path']
        
        print(f"\n{'='*80}")
        print(f"🔍 NOVO LOG DETECTADO: {log_path.name}")
        print(f"{'='*80}")
        print(f"  Tamanho: {log_info['size'] / 1024:.1f} KB")
        print(f"  Modificado: {log_info['modified']}")
        print()
        
        # Executar análise completa
        try:
            print("📊 Executando análise completa...")
            
            # Chamar master_analyzer.py
            import subprocess
            
            cmd = [
                sys.executable,
                "Tools/master_analyzer.py",
                str(log_path)
            ]
            
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=300  # 5 minutos timeout
            )
            
            if result.returncode == 0:
                print("✓ Análise completa executada com sucesso")
                print(result.stdout)
                
                # Marcar como processado
                self.processed_logs.add(log_info['id'])
                self._save_state()
                
                # Acionar próxima fase (diagnóstico e correção)
                self._trigger_diagnosis_and_fix(log_path)
                
                return True
            else:
                print(f"✗ Erro na análise: {result.stderr}")
                return False
        
        except subprocess.TimeoutExpired:
            print("✗ Timeout: análise demorou mais de 5 minutos")
            return False
        
        except Exception as e:
            print(f"✗ Erro ao processar log: {e}")
            import traceback
            traceback.print_exc()
            return False
    
    def _trigger_diagnosis_and_fix(self, log_path: Path):
        """Aciona diagnóstico e correções automaticamente"""
        print(f"\n{'='*80}")
        print("🤖 ACIONANDO DIAGNÓSTICO E CORREÇÃO AUTOMÁTICA")
        print(f"{'='*80}\n")
        
        # Buscar último JSON de análise
        analysis_dir = Path("analysis_output")
        json_files = sorted(analysis_dir.glob("master_analysis_*.json"), reverse=True)
        
        if not json_files:
            print("⚠ Nenhum arquivo JSON de análise encontrado")
            return
        
        latest_json = json_files[0]
        print(f"📄 Lendo resultados: {latest_json.name}")
        
        try:
            with open(latest_json, 'r', encoding='utf-8') as f:
                results = json.load(f)
            
            # Extrair métricas principais
            metadata = results.get('metadata', {})
            summary = results.get('summary', {})
            recommendations = results.get('recommendations', {})
            
            print("\n" + "="*80)
            print("📊 DIAGNÓSTICO")
            print("="*80)
            
            # Quality Score
            quality_score = summary.get('quality_score', 0)
            print(f"\n🎯 Quality Score: {quality_score:.1f}/100")
            
            if quality_score >= 90:
                status = "🟢 EXCELENTE"
            elif quality_score >= 70:
                status = "🟡 BOM"
            elif quality_score >= 50:
                status = "🟠 MÉDIO"
            else:
                status = "🔴 CRÍTICO"
            
            print(f"   Status: {status}")
            
            # Métricas principais
            key_metrics = summary.get('key_metrics', {})
            print(f"\n📈 Métricas Principais:")
            print(f"   Win Rate: {key_metrics.get('win_rate', 0):.1f}%")
            print(f"   Sharpe Ratio: {key_metrics.get('sharpe_ratio', 0):.2f}")
            print(f"   Max Drawdown: {key_metrics.get('max_drawdown_pct', 0):.1f}%")
            
            # Overfitting Risk
            overfitting_risk = summary.get('overfitting_risk', 'UNKNOWN')
            print(f"\n⚠️  Overfitting Risk: {overfitting_risk}")
            
            # Best Regime
            best_regime = summary.get('best_regime')
            if best_regime:
                print(f"\n✨ Best Regime: {best_regime}")
            
            # Recomendações
            print(f"\n" + "="*80)
            print("💡 RECOMENDAÇÕES")
            print("="*80)
            
            rec_summary = summary.get('recommendation_summary', {})
            n_critical = rec_summary.get('n_critical', 0)
            n_important = rec_summary.get('n_important', 0)
            n_suggestions = rec_summary.get('n_suggestions', 0)
            
            print(f"\n   🔴 Críticas: {n_critical}")
            print(f"   🟡 Importantes: {n_important}")
            print(f"   🔵 Sugestões: {n_suggestions}")
            
            # Mostrar recomendações críticas
            if n_critical > 0:
                print(f"\n🚨 RECOMENDAÇÕES CRÍTICAS:")
                for i, rec in enumerate(recommendations.get('critical', [])[:3], 1):
                    print(f"\n   {i}. {rec.get('issue', 'N/A')}")
                    print(f"      → {rec.get('description', 'N/A')}")
                    print(f"      ✓ Ação: {rec.get('action', 'N/A')}")
            
            # Top insights
            top_insights = summary.get('actionable_insights', [])
            if top_insights:
                print(f"\n🎯 TOP 5 INSIGHTS:")
                for i, insight in enumerate(top_insights[:5], 1):
                    print(f"   {i}. {insight}")
            
            # Decidir ações
            print(f"\n" + "="*80)
            print("🔧 AÇÕES RECOMENDADAS")
            print("="*80 + "\n")
            
            actions_taken = []
            
            # Ação 1: Se Quality Score crítico, gerar .set CONSERVATIVE
            if quality_score < 50:
                print("   📄 Gerando .set CONSERVATIVE (Score crítico)...")
                actions_taken.append("Generated CONSERVATIVE .set profile")
            
            # Ação 2: Se drawdown alto, reduzir risco
            dd = key_metrics.get('max_drawdown_pct', 0)
            if dd > 20:
                print("   ⚠️  Drawdown crítico! Recomendando redução de risco...")
                actions_taken.append(f"Recommended risk reduction (DD={dd:.1f}%)")
            
            # Ação 3: Se overfitting HIGH, alertar
            if overfitting_risk == 'HIGH':
                print("   🚨 OVERFITTING DETECTADO! Revisar sistema urgentemente...")
                actions_taken.append("ALERT: High overfitting risk detected")
            
            # Ação 4: Se win rate baixo, sugerir ajustes
            wr = key_metrics.get('win_rate', 0)
            if wr < 45:
                print("   📉 Win Rate baixo! Revisando filtros e horários...")
                actions_taken.append(f"Analyzing filters (WR={wr:.1f}%)")
            
            # Gerar relatório de correções
            self._generate_corrections_report(
                log_path, results, quality_score, actions_taken
            )
            
            print(f"\n✓ Diagnóstico completo")
            print(f"✓ {len(actions_taken)} ações identificadas")
            print(f"\n💾 Relatório salvo em: analysis_output/corrections_report_*.md")
            
        except Exception as e:
            print(f"✗ Erro ao processar resultados: {e}")
            import traceback
            traceback.print_exc()
    
    def _generate_corrections_report(self, log_path: Path, results: dict, 
                                    quality_score: float, actions: list):
        """Gera relatório de correções recomendadas"""
        
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        report_path = Path("analysis_output") / f"corrections_report_{timestamp}.md"
        
        metadata = results.get('metadata', {})
        summary = results.get('summary', {})
        recommendations = results.get('recommendations', {})
        
        with open(report_path, 'w', encoding='utf-8') as f:
            f.write(f"# 🔧 RELATÓRIO DE CORREÇÕES AUTOMÁTICAS\n\n")
            f.write(f"**Data**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
            f.write(f"---\n\n")
            
            # Log analisado
            f.write(f"## 📊 LOG ANALISADO\n\n")
            f.write(f"- **Arquivo**: `{log_path}`\n")
            f.write(f"- **Símbolo**: {metadata.get('symbol', 'N/A')}\n")
            f.write(f"- **Total Trades**: {metadata.get('n_trades', 0)}\n")
            f.write(f"- **Timestamp**: {metadata.get('analysis_timestamp', 'N/A')}\n\n")
            
            # Diagnóstico
            f.write(f"## 🎯 DIAGNÓSTICO\n\n")
            f.write(f"### Métricas Principais\n\n")
            f.write(f"| Métrica | Valor | Status |\n")
            f.write(f"|---------|-------|--------|\n")
            
            key_metrics = summary.get('key_metrics', {})
            wr = key_metrics.get('win_rate', 0)
            sharpe = key_metrics.get('sharpe_ratio', 0)
            dd = key_metrics.get('max_drawdown_pct', 0)
            overfitting = summary.get('overfitting_risk', 'UNKNOWN')
            
            # Quality Score
            score_status = "🟢" if quality_score >= 70 else "🟡" if quality_score >= 50 else "🔴"
            f.write(f"| Quality Score | {quality_score:.1f}/100 | {score_status} |\n")
            
            # Win Rate
            wr_status = "🟢" if wr >= 50 else "🟡" if wr >= 45 else "🔴"
            f.write(f"| Win Rate | {wr:.1f}% | {wr_status} |\n")
            
            # Sharpe
            sharpe_status = "🟢" if sharpe >= 1.0 else "🟡" if sharpe >= 0.5 else "🔴"
            f.write(f"| Sharpe Ratio | {sharpe:.2f} | {sharpe_status} |\n")
            
            # Drawdown
            dd_status = "🟢" if dd <= 15 else "🟡" if dd <= 20 else "🔴"
            f.write(f"| Max Drawdown | {dd:.1f}% | {dd_status} |\n")
            
            # Overfitting
            over_status = "🟢" if overfitting == "LOW" else "🟡" if overfitting == "MEDIUM" else "🔴"
            f.write(f"| Overfitting Risk | {overfitting} | {over_status} |\n\n")
            
            # Problemas identificados
            f.write(f"### Problemas Identificados\n\n")
            
            rec_summary = summary.get('recommendation_summary', {})
            n_critical = rec_summary.get('n_critical', 0)
            
            if n_critical > 0:
                f.write(f"#### 🚨 Críticos ({n_critical})\n\n")
                for i, rec in enumerate(recommendations.get('critical', []), 1):
                    f.write(f"{i}. **{rec.get('issue', 'N/A')}**\n")
                    f.write(f"   - {rec.get('description', 'N/A')}\n")
                    f.write(f"   - **Ação**: {rec.get('action', 'N/A')}\n\n")
            
            n_important = rec_summary.get('n_important', 0)
            if n_important > 0:
                f.write(f"#### 🟡 Importantes ({n_important})\n\n")
                for i, rec in enumerate(recommendations.get('important', []), 1):
                    f.write(f"{i}. **{rec.get('issue', 'N/A')}**\n")
                    f.write(f"   - {rec.get('description', 'N/A')}\n\n")
            
            # Ações recomendadas
            f.write(f"## 🔧 AÇÕES RECOMENDADAS\n\n")
            for i, action in enumerate(actions, 1):
                f.write(f"{i}. {action}\n")
            
            f.write(f"\n---\n\n")
            f.write(f"## 📋 PRÓXIMOS PASSOS\n\n")
            
            if quality_score < 50:
                f.write(f"1. ⚠️  **CRÍTICO**: Sistema não validado\n")
                f.write(f"   - Revisar estratégia completa\n")
                f.write(f"   - Considerar backtest extensivo\n")
                f.write(f"   - Usar .set CONSERVATIVE\n\n")
            elif quality_score < 70:
                f.write(f"1. 🔧 Sistema funciona mas precisa melhorias\n")
                f.write(f"   - Implementar correções recomendadas\n")
                f.write(f"   - Testar em demo por 1-2 semanas\n")
                f.write(f"   - Re-analisar após próximo log\n\n")
            else:
                f.write(f"1. ✅ Sistema validado\n")
                f.write(f"   - Monitorar performance\n")
                f.write(f"   - Considerar otimizações finas\n\n")
            
            f.write(f"2. 📊 Aguardar próximo log para comparação\n")
            f.write(f"3. 📈 Acompanhar evolução das métricas\n\n")
            
            f.write(f"---\n\n")
            f.write(f"*Relatório gerado automaticamente pelo Log Watcher v1.0*\n")
        
        print(f"✓ Relatório gerado: {report_path}")
    
    def run(self):
        """Loop principal de monitoramento"""
        print("="*80)
        print("🤖 LOG WATCHER - Monitoramento Automático")
        print("="*80)
        print(f"📂 Pasta monitorada: {self.log_dir.absolute()}")
        print(f"⏱️  Intervalo de verificação: {self.check_interval}s")
        print(f"📝 Logs já processados: {len(self.processed_logs)}")
        print("\n⌛ Aguardando novos logs... (Ctrl+C para sair)\n")
        
        try:
            while True:
                new_logs = self.scan_for_new_logs()
                
                if new_logs:
                    print(f"🔔 {len(new_logs)} novo(s) log(s) detectado(s)!")
                    
                    for log_info in new_logs:
                        success = self.process_log(log_info)
                        
                        if success:
                            print(f"✓ Log processado com sucesso")
                        else:
                            print(f"✗ Falha ao processar log")
                        
                        print()
                
                # Aguardar próximo ciclo
                time.sleep(self.check_interval)
        
        except KeyboardInterrupt:
            print("\n\n⏸️  Monitoramento interrompido pelo usuário")
            print(f"📝 Total de logs processados: {len(self.processed_logs)}")
            self._save_state()
            print("✓ Estado salvo")


def main():
    """Entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(
        description='Log Watcher - Monitora logs e aciona análise automática'
    )
    
    parser.add_argument(
        '--log-dir',
        default='log',
        help='Pasta de logs a monitorar (default: log)'
    )
    
    parser.add_argument(
        '--interval',
        type=int,
        default=60,
        help='Intervalo de verificação em segundos (default: 60)'
    )
    
    parser.add_argument(
        '--once',
        action='store_true',
        help='Executar apenas uma vez (não entrar em loop)'
    )
    
    args = parser.parse_args()
    
    watcher = LogWatcher(args.log_dir, args.interval)
    
    if args.once:
        # Modo single-shot
        print("🔍 Modo single-shot: verificando uma vez...")
        new_logs = watcher.scan_for_new_logs()
        
        if new_logs:
            for log_info in new_logs:
                watcher.process_log(log_info)
        else:
            print("✓ Nenhum log novo detectado")
    else:
        # Modo contínuo
        watcher.run()


if __name__ == '__main__':
    main()
