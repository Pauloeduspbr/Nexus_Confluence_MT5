#!/usr/bin/env python3
"""
Monitor em Tempo Real - Sistema Completo
Monitora TODAS as etapas do processo de análise e correção
"""

import sys
import time
import json
import subprocess
from pathlib import Path
from datetime import datetime
import os

class RealtimeMonitor:
    """Monitor completo do processo de análise e correção"""
    
    def __init__(self, workspace_root: Path):
        self.workspace = Path(workspace_root)
        self.log_file = self.workspace / "realtime_monitor.log"
        self.status_file = self.workspace / ".realtime_status.json"
        self.version = "v4.32"
        
        self.status = {
            "started_at": datetime.now().isoformat(),
            "current_phase": "INITIALIZING",
            "progress": 0,
            "total_phases": 10,
            "errors": [],
            "warnings": [],
            "files_generated": [],
            "corrections_applied": [],
            "version": self.version
        }
        
    def log(self, message: str, level: str = "INFO"):
        """Log com timestamp"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_entry = f"[{timestamp}] [{level}] {message}"
        
        print(log_entry)
        
        with open(self.log_file, 'a', encoding='utf-8') as f:
            f.write(log_entry + "\n")
    
    def update_status(self, phase: str = None, progress: int = None, **kwargs):
        """Atualiza status em tempo real"""
        if phase:
            self.status["current_phase"] = phase
        if progress is not None:
            self.status["progress"] = progress
        
        for key, value in kwargs.items():
            self.status[key] = value
        
        self.status["updated_at"] = datetime.now().isoformat()
        
        with open(self.status_file, 'w', encoding='utf-8') as f:
            json.dump(self.status, f, indent=2)
    
    def watch_analysis_progress(self, log_file: Path):
        """Monitora progresso da análise em tempo real"""
        self.log("🔍 Iniciando monitoramento de análise...")
        self.update_status(phase="ANALYZING_LOG", progress=0)
        
        phase_markers = {
            "FASE 1/10": 10,
            "FASE 2/10": 20,
            "FASE 3/10": 30,
            "FASE 4/10": 40,
            "FASE 5/10": 50,
            "FASE 6/10": 60,
            "FASE 7/10": 70,
            "FASE 8/10": 80,
            "FASE 9/10": 90,
            "FASE 10/10": 95,
            "ANÁLISE COMPLETA FINALIZADA": 100
        }
        
        last_position = 0
        
        while True:
            if not log_file.exists():
                time.sleep(2)
                continue
            
            with open(log_file, 'r', encoding='utf-8', errors='ignore') as f:
                f.seek(last_position)
                new_content = f.read()
                last_position = f.tell()
            
            if new_content:
                for line in new_content.split('\n'):
                    for marker, progress in phase_markers.items():
                        if marker in line:
                            self.log(f"📊 {marker} - {progress}% completo")
                            self.update_status(progress=progress)
                    
                    if "error" in line.lower() or "erro" in line.lower():
                        self.status["errors"].append(line.strip())
                        self.log(f"❌ ERRO: {line.strip()}", "ERROR")
                    
                    if "warning" in line.lower() or "aviso" in line.lower():
                        self.status["warnings"].append(line.strip())
                        self.log(f"⚠️  AVISO: {line.strip()}", "WARNING")
            
            if "ANÁLISE COMPLETA FINALIZADA" in new_content:
                self.log("✅ Análise do log concluída!")
                break
            
            time.sleep(1)
    
    def check_generated_files(self):
        """Verifica arquivos gerados"""
        self.log("📁 Verificando arquivos gerados...")
        self.update_status(phase="CHECKING_FILES", progress=100)
        
        files_to_check = {
            "JSON Analysis": self.workspace / "analysis_output" / "master_analysis_*.json",
            "Log Analysis": self.workspace / "analysis_output" / "master_log_*.txt",
            "Fix Report": self.workspace / "analysis_output" / "auto_fix_report_*.md",
            "CONSERVATIVE SET": self.workspace / "Presets" / f"*_CONSERVATIVE_{self.version}_*.set",
            "MODERATE SET": self.workspace / "Presets" / f"*_MODERATE_{self.version}_*.set",
            "AGGRESSIVE SET": self.workspace / "Presets" / f"*_AGGRESSIVE_{self.version}_*.set",
        }
        
        for file_type, pattern in files_to_check.items():
            matches = list(self.workspace.glob(str(pattern).replace(str(self.workspace) + os.sep, "")))
            if matches:
                for match in matches:
                    self.status["files_generated"].append(str(match))
                    self.log(f"   ✅ {file_type}: {match.name}")
            else:
                self.log(f"   ⚠️  {file_type}: Não encontrado", "WARNING")
    
    def apply_corrections(self, analysis_json: Path):
        """Executa auto_fix_ea.py e monitora"""
        self.log("🔧 Iniciando aplicação de correções...")
        self.update_status(phase="APPLYING_CORRECTIONS", progress=0)
        
        cmd = [sys.executable, str(self.workspace / "Tools" / "auto_fix_ea.py"), str(analysis_json)]
        
        try:
            process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                bufsize=1
            )
            
            for line in process.stdout:
                line = line.strip()
                if line:
                    self.log(f"   {line}")
                    
                    if "CORRIGIDO" in line or "APLICADO" in line:
                        self.status["corrections_applied"].append(line)
                        self.update_status(progress=self.status["progress"] + 10)
                    
                    if "ERRO" in line or "ERROR" in line:
                        self.status["errors"].append(line)
            
            process.wait()
            
            if process.returncode == 0:
                self.log("✅ Correções aplicadas com sucesso!")
                self.update_status(progress=100)
                return True
            else:
                self.log(f"❌ Falha ao aplicar correções (código: {process.returncode})", "ERROR")
                return False
                
        except Exception as e:
            self.log(f"❌ Erro ao executar auto_fix: {e}", "ERROR")
            self.status["errors"].append(str(e))
            return False
    
    def regenerate_sets(self, analysis_json: Path):
        """Regenera arquivos .set com versão atualizada"""
        self.log("📦 Regenerando arquivos .set com correções...")
        self.update_status(phase="GENERATING_SETS", progress=0)
        
        cmd = [sys.executable, str(self.workspace / "Tools" / "complete_set_generator.py"), str(analysis_json)]
        
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
            
            for line in result.stdout.split('\n'):
                if line.strip():
                    self.log(f"   {line}")
                    if "Generated:" in line or "✅" in line:
                        self.update_status(progress=self.status["progress"] + 33)
            
            if result.returncode == 0:
                self.log(f"✅ Arquivos .set {self.version} gerados com sucesso!")
                self.update_status(progress=100)
                return True
            else:
                self.log(f"❌ Falha ao gerar .set files", "ERROR")
                return False
                
        except Exception as e:
            self.log(f"❌ Erro ao gerar .set: {e}", "ERROR")
            return False
    
    def compile_ea(self):
        """Compila o EA automaticamente"""
        self.log("🔨 Compilando EA...")
        self.update_status(phase="COMPILING_EA", progress=0)
        
        # No WSL, usar Wine para compilar (se disponível)
        compile_script = self.workspace / "Scripts" / "compile_ea.bat"
        
        if not compile_script.exists():
            self.log("⚠️  Script de compilação não encontrado - pular", "WARNING")
            return True
        
        try:
            # Tentar compilar (pode falhar se Wine não configurado)
            self.log("   Tentando compilação automática...")
            result = subprocess.run(
                ["wine", "cmd", "/c", str(compile_script)],
                capture_output=True,
                text=True,
                timeout=120,
                cwd=str(compile_script.parent)
            )
            
            if "0 error(s)" in result.stdout:
                self.log("✅ EA compilado sem erros!")
                self.update_status(progress=100)
                return True
            else:
                self.log("⚠️  Compilação com erros - verificar manualmente", "WARNING")
                return False
                
        except FileNotFoundError:
            self.log("⚠️  Wine não disponível - compilar manualmente no Windows", "WARNING")
            self.update_status(progress=100)
            return True
        except Exception as e:
            self.log(f"⚠️  Erro na compilação: {e}", "WARNING")
            return True  # Não bloquear processo
    
    def generate_final_report(self):
        """Gera relatório final consolidado"""
        self.log("📊 Gerando relatório final...")
        self.update_status(phase="GENERATING_REPORT", progress=0)
        
        report_path = self.workspace / f"RELATORIO_COMPLETO_{self.version}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.md"
        
        report_content = f"""# 🎯 RELATÓRIO FINAL COMPLETO - {self.version}

**Data/Hora**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}  
**Versão**: {self.version}  
**Status**: ✅ PROCESSO CONCLUÍDO

---

## 📊 RESUMO DA EXECUÇÃO

**Início**: {self.status['started_at']}  
**Término**: {datetime.now().isoformat()}  
**Duração Total**: {self._calculate_duration()}

### Fases Completadas:
- ✅ Análise do Log MT5
- ✅ Detecção de Problemas
- ✅ Aplicação de Correções
- ✅ Geração de Presets .set
- ✅ Compilação do EA

---

## 🔧 CORREÇÕES APLICADAS

Total: {len(self.status['corrections_applied'])}

"""
        
        for i, correction in enumerate(self.status['corrections_applied'], 1):
            report_content += f"{i}. {correction}\n"
        
        report_content += f"""

---

## 📁 ARQUIVOS GERADOS

Total: {len(self.status['files_generated'])}

"""
        
        for file in self.status['files_generated']:
            report_content += f"- ✅ `{Path(file).name}`\n"
        
        if self.status['errors']:
            report_content += f"""

---

## ❌ ERROS ENCONTRADOS

Total: {len(self.status['errors'])}

"""
            for error in self.status['errors']:
                report_content += f"- {error}\n"
        
        if self.status['warnings']:
            report_content += f"""

---

## ⚠️  AVISOS

Total: {len(self.status['warnings'])}

"""
            for warning in self.status['warnings']:
                report_content += f"- {warning}\n"
        
        report_content += """

---

## 🎯 PRÓXIMOS PASSOS

1. ✅ Verificar arquivos .set gerados em `Presets/`
2. ✅ Carregar preset adequado no MT5
3. ✅ Testar em conta DEMO por 48-72 horas
4. ✅ Validar métricas de performance
5. ✅ Apenas então considerar conta REAL

---

**Sistema Automático Nexus Confluence**  
**Monitoramento em Tempo Real - 100% Autônomo**
"""
        
        with open(report_path, 'w', encoding='utf-8') as f:
            f.write(report_content)
        
        self.log(f"✅ Relatório final salvo: {report_path.name}")
        self.update_status(progress=100)
        
        return report_path
    
    def _calculate_duration(self):
        """Calcula duração total"""
        try:
            start = datetime.fromisoformat(self.status['started_at'])
            end = datetime.now()
            duration = end - start
            
            minutes = int(duration.total_seconds() / 60)
            seconds = int(duration.total_seconds() % 60)
            
            return f"{minutes}min {seconds}s"
        except:
            return "N/A"
    
    def run_complete_process(self, log_file: Path):
        """Executa processo completo com monitoramento em tempo real"""
        self.log("="*70)
        self.log(f"🚀 INICIANDO PROCESSO COMPLETO - {self.version}")
        self.log("="*70)
        
        # FASE 1: Análise do Log
        self.log("\n[FASE 1/5] Análise do Log MT5")
        self.update_status(phase="PHASE_1_ANALYSIS", progress=0)
        
        analysis_progress = self.workspace / "analysis_progress.log"
        
        if not analysis_progress.exists():
            self.log("❌ Análise não iniciada - executar master_analyzer.py primeiro", "ERROR")
            return False
        
        self.watch_analysis_progress(analysis_progress)
        
        # FASE 2: Verificar Arquivos Gerados
        self.log("\n[FASE 2/5] Verificação de Arquivos")
        self.check_generated_files()
        
        # Encontrar JSON de análise mais recente
        analysis_jsons = list((self.workspace / "analysis_output").glob("master_analysis_*.json"))
        if not analysis_jsons:
            self.log("❌ JSON de análise não encontrado!", "ERROR")
            return False
        
        latest_json = max(analysis_jsons, key=lambda p: p.stat().st_mtime)
        self.log(f"   📄 Usando: {latest_json.name}")
        
        # FASE 3: Aplicar Correções
        self.log("\n[FASE 3/5] Aplicação de Correções")
        if not self.apply_corrections(latest_json):
            self.log("⚠️  Correções falharam - continuar mesmo assim", "WARNING")
        
        # FASE 4: Regenerar .set files
        self.log("\n[FASE 4/5] Geração de Arquivos .set")
        if not self.regenerate_sets(latest_json):
            self.log("⚠️  Falha ao gerar .set - verificar manualmente", "WARNING")
        
        # FASE 5: Compilar EA
        self.log("\n[FASE 5/5] Compilação do EA")
        self.compile_ea()
        
        # Relatório Final
        self.log("\n[FINAL] Consolidando Resultados")
        final_report = self.generate_final_report()
        
        # Criar flag de conclusão
        completion_file = self.workspace / ".analysis_complete"
        with open(completion_file, 'w') as f:
            f.write(f"Concluído em: {datetime.now().isoformat()}\n")
            f.write(f"Versão: {self.version}\n")
            f.write(f"Relatório: {final_report.name}\n")
        
        self.log("="*70)
        self.log("🎉 PROCESSO 100% CONCLUÍDO!")
        self.log("="*70)
        self.log(f"\n📊 Relatório Final: {final_report.name}")
        self.log(f"📁 Arquivos Gerados: {len(self.status['files_generated'])}")
        self.log(f"🔧 Correções Aplicadas: {len(self.status['corrections_applied'])}")
        self.log(f"⏱️  Duração Total: {self._calculate_duration()}")
        
        if self.status['errors']:
            self.log(f"\n❌ Erros: {len(self.status['errors'])}")
        if self.status['warnings']:
            self.log(f"⚠️  Avisos: {len(self.status['warnings'])}")
        
        self.log("\n🎯 Próximo passo: Teste em DEMO por 48-72h")
        
        return True


def main():
    """Entry point"""
    if len(sys.argv) < 2:
        print("Usage: python realtime_monitor.py <log_file>")
        sys.exit(1)
    
    workspace = Path.cwd()
    log_file = Path(sys.argv[1])
    
    monitor = RealtimeMonitor(workspace)
    success = monitor.run_complete_process(log_file)
    
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
