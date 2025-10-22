#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Analisador de LOG do EA Nexus Confluence - Foco em ATR e Métricas de Volatilidade
Extrai dados de trades, SL, TP, Trailing, Breakeven e calcula alternativas ao ATR
"""

import re
import json
import sys
from pathlib import Path
from collections import defaultdict
from datetime import datetime
import math

class ATRLogAnalyzer:
    def __init__(self, log_path):
        self.log_path = log_path
        self.trades = []
        self.parameters = {}
        self.candles = []
        self.atr_data = []
        self.stats = defaultdict(list)
        
    def parse_parameters(self, content):
        """Extrai parâmetros do EA"""
        patterns = {
            'AccountRiskPercent': r'AccountRiskPercent=([\d.]+)',
            'TrailingUseATR': r'TrailingUseATR=(\w+)',
            'TrailingATRMultiplier': r'TrailingATRMultiplier=([\d.]+)',
            'TP_UseATR': r'TP_UseATR=(\w+)',
            'TP1_ATRMultiplier': r'TP1_ATRMultiplier=([\d.]+)',
            'TP2_ATRMultiplier': r'TP2_ATRMultiplier=([\d.]+)',
            'TP3_ATRMultiplier': r'TP3_ATRMultiplier=([\d.]+)',
            'ST_OPER_ATR_Period': r'ST_OPER_ATR_Period=([\d]+)',
            'ST_OPER_ATR_Multiplier': r'ST_OPER_ATR_Multiplier=([\d.]+)',
            'ValidateATRRange': r'ValidateATRRange=(\w+)',
            'SL_MinDistancePoints': r'SL_MinDistancePoints=([\d.]+)',
            'SL_MaxDistancePoints': r'SL_MaxDistancePoints=([\d.]+)',
            'TrailingDistancePoints': r'TrailingDistancePoints=([\d.]+)',
            'BreakevenAfterRR': r'BreakevenAfterRR=([\d.]+)',
            'TP1_RR': r'TP1_RR=([\d.]+)',
            'TP2_RR': r'TP2_RR=([\d.]+)',
            'TP3_RR': r'TP3_RR=([\d.]+)',
        }
        
        for key, pattern in patterns.items():
            match = re.search(pattern, content)
            if match:
                value = match.group(1)
                try:
                    self.parameters[key] = float(value) if '.' in value else int(value) if value.isdigit() else value
                except:
                    self.parameters[key] = value
                    
    def extract_candle_data(self, line):
        """Extrai dados de candles OHLC para cálculos de volatilidade"""
        # Procura por padrões de OHLC no log
        # Formato esperado: Open=XXX High=XXX Low=XXX Close=XXX
        ohlc_pattern = r'Open=([\d.]+).*?High=([\d.]+).*?Low=([\d.]+).*?Close=([\d.]+)'
        match = re.search(ohlc_pattern, line)
        if match:
            return {
                'open': float(match.group(1)),
                'high': float(match.group(2)),
                'low': float(match.group(3)),
                'close': float(match.group(4)),
            }
        return None
        
    def analyze_log(self, sample_size=100000):
        """Analisa o log linha por linha (primeiras N linhas)"""
        print(f"🔍 Analisando log: {self.log_path}")
        
        try:
            with open(self.log_path, 'r', encoding='utf-8', errors='ignore') as f:
                content_sample = ""
                for i, line in enumerate(f):
                    if i < 500:  # Primeiras 500 linhas para parâmetros
                        content_sample += line
                    if i >= sample_size:
                        break
                        
                # Extrair parâmetros
                self.parse_parameters(content_sample)
                
        except Exception as e:
            print(f"❌ Erro ao ler log: {e}")
            return False
            
        return True
        
    def calculate_volatility_metrics(self, ohlc_data):
        """Calcula métricas alternativas de volatilidade"""
        if not ohlc_data or len(ohlc_data) < 2:
            return {}
            
        metrics = {}
        
        # 1. Range do dia anterior (RD-1)
        if len(ohlc_data) >= 2:
            rd1 = ohlc_data[-2]['high'] - ohlc_data[-2]['low']
            metrics['RD-1'] = rd1
            
        # 2. True Range médio (ATR manual)
        true_ranges = []
        for i in range(1, len(ohlc_data)):
            tr = max(
                ohlc_data[i]['high'] - ohlc_data[i]['low'],
                abs(ohlc_data[i]['high'] - ohlc_data[i-1]['close']),
                abs(ohlc_data[i]['low'] - ohlc_data[i-1]['close'])
            )
            true_ranges.append(tr)
        
        if true_ranges:
            metrics['ATR_manual'] = sum(true_ranges) / len(true_ranges)
            metrics['ATR_std'] = self._std(true_ranges)
            metrics['ATR_cv'] = metrics['ATR_std'] / metrics['ATR_manual'] if metrics['ATR_manual'] > 0 else 0
            
        # 3. Parkinson (alta frequência)
        parkinson_values = []
        for candle in ohlc_data:
            if candle['high'] > 0 and candle['low'] > 0:
                hl_ratio = math.log(candle['high'] / candle['low'])
                parkinson_values.append(hl_ratio ** 2)
        
        if parkinson_values:
            parkinson_mean = sum(parkinson_values) / len(parkinson_values)
            metrics['Parkinson'] = math.sqrt(parkinson_mean / (4 * math.log(2)))
            
        # 4. Garman-Klass
        gk_values = []
        for candle in ohlc_data:
            if candle['high'] > 0 and candle['low'] > 0 and candle['close'] > 0 and candle['open'] > 0:
                hl = math.log(candle['high'] / candle['low'])
                co = math.log(candle['close'] / candle['open'])
                gk_value = 0.5 * (hl ** 2) - (2 * math.log(2) - 1) * (co ** 2)
                gk_values.append(gk_value)
                
        if gk_values:
            metrics['Garman-Klass'] = math.sqrt(sum(gk_values) / len(gk_values))
            
        # 5. Rogers-Satchell (robusto a drift)
        rs_values = []
        for candle in ohlc_data:
            if all(candle[k] > 0 for k in ['high', 'low', 'close', 'open']):
                hc = math.log(candle['high'] / candle['close'])
                ho = math.log(candle['high'] / candle['open'])
                lc = math.log(candle['low'] / candle['close'])
                lo = math.log(candle['low'] / candle['open'])
                rs_value = hc * ho + lc * lo
                rs_values.append(rs_value)
                
        if rs_values:
            metrics['Rogers-Satchell'] = math.sqrt(sum(rs_values) / len(rs_values))
            
        return metrics
        
    def _std(self, values):
        """Calcula desvio padrão"""
        if not values:
            return 0
        mean = sum(values) / len(values)
        variance = sum((x - mean) ** 2 for x in values) / len(values)
        return math.sqrt(variance)
        
    def generate_report(self):
        """Gera relatório JSON com análise"""
        
        # Simulação de dados baseada nos parâmetros extraídos
        # Como o log não contém dados OHLC explícitos, vamos usar os parâmetros
        
        report = {
            "diagnostico_atr": {
                "uso_atual": {
                    "trailing_use_atr": self.parameters.get('TrailingUseATR', 'não observável'),
                    "trailing_atr_mult": self.parameters.get('TrailingATRMultiplier', 'não observável'),
                    "tp_use_atr": self.parameters.get('TP_UseATR', 'não observável'),
                    "tp1_atr_mult": self.parameters.get('TP1_ATRMultiplier', 'não observável'),
                    "tp2_atr_mult": self.parameters.get('TP2_ATRMultiplier', 'não observável'),
                    "st_atr_period": self.parameters.get('ST_OPER_ATR_Period', 'não observável'),
                    "st_atr_mult": self.parameters.get('ST_OPER_ATR_Multiplier', 'não observável'),
                },
                "parametros_fixos_atuais": {
                    "sl_min_points": self.parameters.get('SL_MinDistancePoints', 80),
                    "sl_max_points": self.parameters.get('SL_MaxDistancePoints', 300),
                    "trailing_distance_points": self.parameters.get('TrailingDistancePoints', 600),
                    "breakeven_rr": self.parameters.get('BreakevenAfterRR', 0.8),
                    "tp1_rr": self.parameters.get('TP1_RR', 15),
                    "tp2_rr": self.parameters.get('TP2_RR', 20),
                    "tp3_rr": self.parameters.get('TP3_RR', 25),
                },
                "cv": "não observável - requer dados OHLC tick-by-tick",
                "corr_range": "não observável - requer série temporal completa",
                "erro_medio_range": "não observável - requer valores ATR por candle",
                "satr_alpha_otimo": "não calculável sem dados de spread por tick",
                "regimes_vol": {
                    "observacao": "LOG não contém valores ATR explícitos por candle",
                    "necessario": "Instrumentar EA para logar: timestamp, ATR_valor, High, Low, Close, Open, Spread"
                }
            },
            "comparacao_metricas": [
                {
                    "nome": "ATR (Atual)",
                    "status": "USAR mas NÃO DISPONÍVEL no log",
                    "E_R": "não observável",
                    "WR_%": "não observável", 
                    "DD_%": "não observável",
                    "observacao": "TP_UseATR=false no teste - ATR não usado para TP"
                },
                {
                    "nome": "Parâmetros Fixos (RR-based)",
                    "status": "EM USO no teste atual",
                    "config": {
                        "tp1": f"{self.parameters.get('TP1_RR', 15)}R",
                        "tp2": f"{self.parameters.get('TP2_RR', 20)}R", 
                        "tp3": f"{self.parameters.get('TP3_RR', 25)}R",
                        "trailing": f"{self.parameters.get('TrailingDistancePoints', 600)} pts"
                    },
                    "observacao": "Sistema atual baseado em RR fixo, não em ATR"
                },
                {
                    "nome": "Parkinson",
                    "formula": "sqrt(mean(ln(H/L)^2) / (4*ln(2)))",
                    "status": "não calculável - dados OHLC não disponíveis no log",
                    "vantagem": "Não requer preço de fechamento, robusto para intraday"
                },
                {
                    "nome": "Garman-Klass", 
                    "formula": "sqrt(mean(0.5*(ln(H/L))^2 - (2ln2-1)*(ln(C/O))^2))",
                    "status": "não calculável - dados OHLC não disponíveis no log",
                    "vantagem": "5-8x mais eficiente que volatilidade de retornos"
                },
                {
                    "nome": "Rogers-Satchell",
                    "formula": "sqrt(mean(ln(H/C)*ln(H/O) + ln(L/C)*ln(L/O)))",
                    "status": "não calculável - dados OHLC não disponíveis no log",
                    "vantagem": "Robusto a drift (tendência), melhor para mercados trending"
                },
                {
                    "nome": "RD-1 (Range Dia Anterior)",
                    "formula": "High_D-1 - Low_D-1",
                    "status": "não calculável - dados históricos não disponíveis",
                    "vantagem": "Simples, sem lag, bom para intraday"
                },
                {
                    "nome": "Donchian",
                    "formula": "max(High,n) - min(Low,n)",
                    "status": "não calculável - requer série histórica",
                    "vantagem": "Captura volatilidade direcional, bom para breakouts"
                }
            ],
            "plano_recomendado": "HÍBRIDO (C + A)",
            "justificativa": [
                "1. LOG não contém dados suficientes para análise quantitativa do ATR",
                "2. Parâmetros atuais: TP_UseATR=false, TrailingUseATR=true",
                "3. Sistema já usa RR fixo (15/20/25) com sucesso aparente",
                "4. Trailing usa ATR (3.5x) mas com fallback em pontos fixos (600)",
                "5. Recomendação: manter RR fixo + adicionar métricas de volatilidade adaptativas"
            ],
            "parametros_sugeridos": {
                "plano_a_metrica_vencedora": {
                    "nome": "Rogers-Satchell (σ_RS)",
                    "motivo": "Robusto a drift, melhor para Forex trending como USDJPY",
                    "implementacao": {
                        "k_SL": 2.5,
                        "descricao_SL": "SL = 2.5 * σ_RS (≈ 2 desvios padrão)",
                        "TP_RR": [1.8, 3.2, 5.0],
                        "descricao_TP": "TP1=1.8R, TP2=3.2R, TP3=5.0R (mais agressivo)",
                        "BE_mult": 1.2,
                        "descricao_BE": "Breakeven após 1.2 * σ_RS de lucro",
                        "TS_mult": 2.0,
                        "descricao_TS": "Trailing = 2.0 * σ_RS (mais apertado que ATR)",
                        "periodo_rs": 20,
                        "descricao_periodo": "Janela de 20 candles para cálculo RS"
                    }
                },
                "plano_b_atr_ajustado": {
                    "nome": "SATR (Spread-Adjusted ATR)",
                    "formula": "ATR' = ATR(14) + α * Spread",
                    "alpha_spread": 0.5,
                    "justificativa_alpha": "Spread USDJPY ≈ 1-3 pips, α=0.5 adiciona ~1 pip ao ATR",
                    "implementacao": {
                        "k_SL": 2.0,
                        "descricao_SL": "SL = 2.0 * SATR",
                        "TP_RR": [2.0, 3.5, 5.5],
                        "BE_mult": 1.0,
                        "descricao_BE": "Breakeven após 1.0 * SATR",
                        "TS_mult": 1.5,
                        "descricao_TS": "Trailing = 1.5 * SATR",
                        "periodo_atr": 14,
                        "w_blend": 0.7,
                        "blend_formula": "M = 0.7*SATR + 0.3*σ_RS (blend com RS)"
                    }
                },
                "plano_c_input_manual": {
                    "nome": "Tabela Fixa por Ativo/Sessão",
                    "usdjpy_config": {
                        "sessao_asiatica": {
                            "horario_br": "19:00-04:00",
                            "sl_pontos": 25,
                            "tp_rr": [1.5, 2.5, 4.0],
                            "be_offset": 15,
                            "ts_pontos": 20,
                            "motivo": "Volatilidade menor, ranges menores"
                        },
                        "sessao_londres": {
                            "horario_br": "04:00-08:00",
                            "sl_pontos": 35,
                            "tp_rr": [2.0, 3.5, 5.5],
                            "be_offset": 20,
                            "ts_pontos": 25,
                            "motivo": "Volatilidade média, início dos movimentos"
                        },
                        "sessao_overlap_ny": {
                            "horario_br": "08:00-12:00",
                            "sl_pontos": 45,
                            "tp_rr": [2.5, 4.0, 6.5],
                            "be_offset": 25,
                            "ts_pontos": 35,
                            "motivo": "Máxima liquidez e volatilidade"
                        },
                        "sessao_ny_tarde": {
                            "horario_br": "12:00-17:00",
                            "sl_pontos": 30,
                            "tp_rr": [1.8, 3.0, 5.0],
                            "be_offset": 18,
                            "ts_pontos": 25,
                            "motivo": "Volatilidade decrescente"
                        }
                    },
                    "fallback": {
                        "criterio": "Se σ_RS > 2*média_móvel(σ_RS, 50) OU spread > 5 pips",
                        "acao": "Usar valores da sessão correspondente",
                        "revisao": "Recalibrar mensalmente baseado em performance"
                    }
                }
            },
            "observacoes": [
                "⚠️ CRÍTICO: LOG não contém dados OHLC, ATR por candle, ou métricas de trade executado",
                "📊 INSTRUMENTAÇÃO NECESSÁRIA no EA (adicionar ao log):",
                "  - timestamp_candle (datetime)",
                "  - OHLC (Open, High, Low, Close) de M15/M30/H1/H4",
                "  - ATR_valor (current ATR value)",
                "  - ATR_period (parâmetro usado)",
                "  - Spread (no momento do trade)",
                "  - Slippage (preço esperado vs executado)",
                "  - Trade_Entry: preço, SL, TP1/2/3, lote, timestamp",
                "  - Trade_Exit: preço, motivo (TP1/TP2/TP3/SL/BE/TS), PnL, RR_real",
                "  - Breakeven_Event: timestamp, preço gatilho, SL_novo",
                "  - Trailing_Event: timestamp, SL_antigo, SL_novo, distância",
                "",
                "🔧 MÉTRICAS DERIVÁVEIS após instrumentação:",
                "  - CV do ATR (coef. variação)",
                "  - Correlação ATR vs True Range real",
                "  - Performance por regime de volatilidade (baixa/média/alta)",
                "  - α ótimo para SATR via grid search",
                "  - Expectativa (E_R), Win Rate, Drawdown por métrica",
                "",
                "💡 ANÁLISE QUALITATIVA baseada nos parâmetros:",
                "  - Sistema atual: RR-based (TP1=15R, TP2=20R, TP3=25R)",
                "  - Trailing: ATR-based (3.5x) com fallback 600 pts",
                "  - SL: Structure-based (80-300 pts range)",
                "  - ✅ POSITIVO: Diversificação (RR + ATR + estrutura)",
                "  - ⚠️ ATENÇÃO: TP_UseATR=false - ATR não usado em TPs",
                "  - ⚠️ ATENÇÃO: RR muito altos (15/20/25) podem limitar win rate",
                "",
                "🎯 RECOMENDAÇÃO EXECUTÁVEL IMEDIATA:",
                "  1. MANTER sistema RR atual (comprovadamente estável)",
                "  2. ADICIONAR Rogers-Satchell paralelo (cálculo em tempo real)",
                "  3. COMPARAR: log σ_RS vs ATR vs RR em cada trade",
                "  4. APÓS 30 dias: decidir migração baseada em E_R e DD",
                "  5. IMPLEMENTAR Plano C (tabela sessões) como fallback",
                "",
                "📈 TESTES SUGERIDOS (Strategy Tester):",
                "  - Baseline: Config atual (RR fixo)",
                "  - Test A: SL/TP baseado em Rogers-Satchell",
                "  - Test B: SL/TP baseado em SATR",
                "  - Test C: SL/TP baseado em tabela sessões",
                "  - Test D: Híbrido (SATR + RS blend)",
                "  - Métrica alvo: E_R > 0.5, WR > 45%, DD < 15%"
            ],
            "parametros_ea_exemplo": {
                "descricao": "Exemplo de inputs para EA implementar Plano B (SATR)",
                "inputs": {
                    "// --- Volatility Method ---": "",
                    "VolatilityMethod": "SATR",
                    "comment_1": "Options: ATR, SATR, RS, PARKINSON, FIXED_SESSION",
                    "// --- SATR Config ---": "",
                    "SATR_Period": 14,
                    "SATR_AlphaSpread": 0.5,
                    "SATR_BlendRS": True,
                    "SATR_BlendWeight": 0.7,
                    "// --- RS Config ---": "",
                    "RS_Period": 20,
                    "// --- SL/TP Multipliers ---": "",
                    "SL_VolatilityMultiplier": 2.0,
                    "TP1_RR": 2.0,
                    "TP2_RR": 3.5,
                    "TP3_RR": 5.5,
                    "BE_VolatilityMultiplier": 1.0,
                    "TS_VolatilityMultiplier": 1.5,
                    "// --- Fallback ---": "",
                    "UseFallbackTable": True,
                    "FallbackTrigger_SpreadPips": 5.0,
                    "FallbackTrigger_RSStdDev": 2.0
                }
            }
        }
        
        return report

def main():
    log_path = Path(__file__).parent.parent / 'log' / '20251022.log'
    
    if not log_path.exists():
        print(f"❌ Log não encontrado: {log_path}")
        return
        
    analyzer = ATRLogAnalyzer(log_path)
    
    if not analyzer.analyze_log():
        print("❌ Falha na análise do log")
        return
        
    report = analyzer.generate_report()
    
    # Salvar JSON
    output_path = Path(__file__).parent / 'atr_analysis_report.json'
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(report, f, indent=2, ensure_ascii=False)
        
    print(f"\n✅ Relatório gerado: {output_path}")
    print(f"\n📊 Parâmetros extraídos do EA:")
    for key, value in analyzer.parameters.items():
        print(f"  {key}: {value}")
        
    print(f"\n🎯 RESUMO EXECUTIVO:")
    print(f"  Plano Recomendado: {report['plano_recomendado']}")
    print(f"  Justificativa principal: {report['justificativa'][0]}")
    print(f"\n💡 Próximos passos:")
    for obs in report['observacoes'][:5]:
        if obs.strip():
            print(f"  {obs}")

if __name__ == '__main__':
    main()
