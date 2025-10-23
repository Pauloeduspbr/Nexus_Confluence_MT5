#!/usr/bin/env python3
"""
complete_set_generator.py
Gerador COMPLETO de arquivos .set com TODOS OS 90+ PARÂMETROS do EA
Nexus Confluence v4.30
"""

from pathlib import Path
from datetime import datetime
from typing import Dict, Any
import json


class CompleteSetGenerator:
    """Gerador completo de .set files com TODOS os parâmetros do EA"""
    
    # ========================================================================
    # TEMPLATE COMPLETO - TODOS OS 90+ PARÂMETROS
    # ========================================================================
    
    COMPLETE_TEMPLATE = """; Nexus Confluence EA v4.34 - {profile} Profile
; saved on {timestamp}
; this file contains input parameters for testing/optimizing NexusConfluenceEA expert advisor
; to use it in the strategy tester, click Load in the context menu of the Inputs tab
;
; Symbol: {symbol} | Quality Score: {quality_score}/100 | Trades Analyzed: {total_trades}
; 🔥 v4.34: CONFIG_SET tracking para análise separada CONSERVATIVE/MODERATE/AGGRESSIVE
;
ConfigSetName={ConfigSetName}||"MODERATE"||||N
AccountRiskPercent={AccountRiskPercent}||1.5||0.1||5.0||N
MaxRiskPremium={MaxRiskPremium}||2.0||0.1||5.0||N
MaxDailyDrawdown={MaxDailyDrawdown}||3.0||1.0||10.0||N
MaxWeeklyDrawdown={MaxWeeklyDrawdown}||5.0||2.0||15.0||N
MaxConsecutiveLosses={MaxConsecutiveLosses}||3||1||10||N
MaxSimultaneousTrades={MaxSimultaneousTrades}||3||1||10||N
EnableSecondaryHours={EnableSecondaryHours}||false||0||true||N
EnableMorningB3={EnableMorningB3}||false||0||true||N
AvoidNews={AvoidNews}||false||0||true||N
ValidateATRRange={ValidateATRRange}||false||0||true||N
SendAlerts={SendAlerts}||false||0||true||N
AllowCautiousSetups={AllowCautiousSetups}||false||0||true||N
AllowGoodSetups={AllowGoodSetups}||false||0||true||N
HourBlacklist={HourBlacklist}||""||||N
FixedLotSize={FixedLotSize}||0.0||0.0||10.0||Y
UseVolatilityMetric={UseVolatilityMetric}||0||0||2||N
ATR_Period={ATR_Period}||5||3||50||Y
RS_Period={RS_Period}||14||10||30||Y
RS_EMAPeriod={RS_EMAPeriod}||5||3||20||N
RS_Multiplier_Supertrend={RS_Multiplier_Supertrend}||1.2||0.5||3.0||Y
RS_Multiplier_Trailing={RS_Multiplier_Trailing}||3.0||1.0||5.0||Y
RS_Multiplier_TP1={RS_Multiplier_TP1}||12.0||5.0||20.0||Y
RS_Multiplier_TP2={RS_Multiplier_TP2}||18.0||10.0||30.0||Y
RS_Multiplier_TP3={RS_Multiplier_TP3}||24.0||15.0||40.0||Y
TradeOnMonday={TradeOnMonday}||false||0||true||N
TradeOnTuesday={TradeOnTuesday}||false||0||true||N
TradeOnWednesday={TradeOnWednesday}||false||0||true||N
TradeOnThursday={TradeOnThursday}||false||0||true||N
TradeOnFriday={TradeOnFriday}||false||0||true||N
TradeOnSaturday={TradeOnSaturday}||false||0||true||N
TradeOnSunday={TradeOnSunday}||false||0||true||N
UseCustomTradingHours={UseCustomTradingHours}||false||0||true||N
CustomStartHour={CustomStartHour}||10||0||23||Y
CustomStartMinute={CustomStartMinute}||0||0||59||N
CustomEndHour={CustomEndHour}||18||0||23||Y
CustomEndMinute={CustomEndMinute}||0||0||59||N
SL_BufferPoints={SL_BufferPoints}||10.0||0.0||100.0||Y
SL_FallbackPercent={SL_FallbackPercent}||0.3||0.1||2.0||N
SL_MinDistancePoints={SL_MinDistancePoints}||50.0||10.0||500.0||Y
SL_MaxDistancePoints={SL_MaxDistancePoints}||300.0||100.0||1000.0||Y
SL_UseStructure={SL_UseStructure}||false||0||true||N
SL_StructureCandles={SL_StructureCandles}||50||10||200||Y
SL_StructureStrength={SL_StructureStrength}||2.0||0.5||5.0||Y
SL_SafetyMultiplier={SL_SafetyMultiplier}||1.2||1.0||2.0||Y
EnablePartialTP={EnablePartialTP}||false||0||true||N
TP1_RR={TP1_RR}||2.0||0.5||10.0||Y
TP2_RR={TP2_RR}||4.0||1.0||20.0||Y
TP3_RR={TP3_RR}||6.0||2.0||30.0||Y
UseTP3={UseTP3}||false||0||true||N
TP1_ClosePercent={TP1_ClosePercent}||30.0||10.0||90.0||Y
TP2_ClosePercent={TP2_ClosePercent}||50.0||10.0||90.0||Y
TP3_ClosePercent={TP3_ClosePercent}||20.0||10.0||90.0||Y
TP_UseATR={TP_UseATR}||false||0||true||N
TP1_ATRMultiplier={TP1_ATRMultiplier}||2.0||0.5||10.0||Y
TP2_ATRMultiplier={TP2_ATRMultiplier}||4.0||1.0||20.0||Y
TP3_ATRMultiplier={TP3_ATRMultiplier}||6.0||2.0||30.0||Y
TP_MinRRRatio={TP_MinRRRatio}||1.2||0.5||5.0||Y
EnableTrailing={EnableTrailing}||false||0||true||N
TrailingDistancePoints={TrailingDistancePoints}||200.0||10.0||1000.0||Y
TrailingStepPoints={TrailingStepPoints}||50.0||5.0||500.0||Y
TrailingActivationRR={TrailingActivationRR}||1.5||0.5||5.0||Y
TrailingUseATR={TrailingUseATR}||false||0||true||N
TrailingATRMultiplier={TrailingATRMultiplier}||2.5||0.5||10.0||Y
TrailingStartAfterTP={TrailingStartAfterTP}||false||0||true||N
TrailingMinProfit={TrailingMinProfit}||0.5||0.0||5.0||Y
TrailingMaxRisk={TrailingMaxRisk}||0.2||0.0||2.0||Y
MaxSlippagePoints={MaxSlippagePoints}||30||1||100||N
LookbackStructureBars={LookbackStructureBars}||80||20||200||Y
BrokerGMTOffset={BrokerGMTOffset}||2||(-12)||12||N
MaxSpreadMultiplier={MaxSpreadMultiplier}||5.0||1.0||20.0||Y
MinFreeMarginPercent={MinFreeMarginPercent}||20.0||5.0||50.0||Y
EnableBreakeven={EnableBreakeven}||false||0||true||N
BreakevenAfterRR={BreakevenAfterRR}||1.0||0.5||5.0||Y
BreakevenPlusPoints={BreakevenPlusPoints}||5.0||0.0||50.0||Y
EnableProfitLock={EnableProfitLock}||false||0||true||N
LockProfitAfterRR={LockProfitAfterRR}||2.0||1.0||10.0||Y
LockProfitPercent={LockProfitPercent}||50.0||10.0||90.0||Y
UseAdaptiveSizing={UseAdaptiveSizing}||false||0||true||N
WinStreakMultiplier={WinStreakMultiplier}||1.2||1.0||3.0||Y
WinStreakThreshold={WinStreakThreshold}||2||1||10||Y
LossStreakDivisor={LossStreakDivisor}||0.5||0.1||1.0||Y
LossStreakThreshold={LossStreakThreshold}||2||1||10||Y
MaxPositionMultiplier={MaxPositionMultiplier}||2.0||1.0||5.0||Y
MaxDailyLoss={MaxDailyLoss}||5.0||1.0||20.0||Y
MaxWeeklyLoss={MaxWeeklyLoss}||10.0||5.0||50.0||Y
ReduceRiskAfterLoss={ReduceRiskAfterLoss}||false||0||true||N
RiskReductionFactor={RiskReductionFactor}||0.5||0.1||1.0||Y
RecoveryMode={RecoveryMode}||false||0||true||N
UseADXFilter={UseADXFilter}||false||0||true||N
ADX_Period={ADX_Period}||14||5||50||Y
ADX_MinTrend={ADX_MinTrend}||25.0||10.0||50.0||Y
MinConfluenceScore={MinConfluenceScore}||60||0||100||Y
RequireSupertrend={RequireSupertrend}||false||0||true||N
RequireADXConfirmation={RequireADXConfirmation}||false||0||true||N
MinADXStrength={MinADXStrength}||20.0||10.0||50.0||Y
RequireVolumeConfirm={RequireVolumeConfirm}||false||0||true||N
VolumeMultiplier={VolumeMultiplier}||1.2||1.0||3.0||Y
PositionControlMode={PositionControlMode}||0||0||2||N
IndicatorsBasePath=NexusConfluenceEA\\
GGTrendBarIndicator=GG_TrendBar_Indicator
TrendMagicIndicator=TrendMagic_MT5
CurrencyStrengthIndicator=CurrencyStrengthMeter_MT5
RSIOMAIndicator=RSIOMA_v2HHLSX_MT5
WAEIndicator=WaddahAttarExplosion_Professional
ST_OPER_CCI_Period={ST_OPER_CCI_Period}||50||10||200||Y
ST_OPER_ATR_Period={ST_OPER_ATR_Period}||5||3||50||Y
ST_OPER_ATR_Multiplier={ST_OPER_ATR_Multiplier}||1.0||0.5||5.0||Y
CS_CalculationPeriod={CS_CalculationPeriod}||24||10||100||Y
CS_SmoothingPeriod={CS_SmoothingPeriod}||5||3||20||Y
CS_ShowInPercent={CS_ShowInPercent}||false||0||true||N
RSI_OPER_Period={RSI_OPER_Period}||14||5||50||Y
RSI_OPER_MA_Period={RSI_OPER_MA_Period}||9||3||30||Y
RSI_OPER_MA_Method={RSI_OPER_MA_Method}||0||0||3||N
RSI_OPER_HighLevel={RSI_OPER_HighLevel}||70.0||50.0||90.0||Y
RSI_OPER_LowLevel={RSI_OPER_LowLevel}||30.0||10.0||50.0||Y
RSI_OPER_ShowLevels={RSI_OPER_ShowLevels}||false||0||true||N
WAE_OPER_FastMA={WAE_OPER_FastMA}||20||5||50||Y
WAE_OPER_SlowMA={WAE_OPER_SlowMA}||40||10||100||Y
WAE_OPER_BBLength={WAE_OPER_BBLength}||20||10||50||Y
WAE_OPER_BBMultiplier={WAE_OPER_BBMultiplier}||2.0||1.0||5.0||Y
WAE_OPER_Sensitivity={WAE_OPER_Sensitivity}||150||50||300||Y
GG_UpColor=65280
GG_DownColor=255
GG_FlatColor=65535
GG_TextColor=16776960
GG_Corner={GG_Corner}||0||0||3||N
GG_CreateVisualObjects={GG_CreateVisualObjects}||false||0||true||N
GG_ADX_Period={GG_ADX_Period}||14||5||50||Y
GG_ADX_Price={GG_ADX_Price}||0||0||6||N
GG_Step_Psar={GG_Step_Psar}||0.02||0.01||0.1||Y
GG_Max_Psar={GG_Max_Psar}||0.20||0.1||0.5||Y
EA_MAGIC_NUMBER={EA_MAGIC_NUMBER}||20241015||1||999999||N
"""

    PROFILE_DESCRIPTIONS = {
        'CONSERVATIVE': 'Risco baixo (0.5%), trailing conservador, proteções rígidas',
        'MODERATE': 'Risco médio (1.0%), trailing balanceado, proteções moderadas',
        'AGGRESSIVE': 'Risco alto (1.5%), trailing dinâmico, proteções flexíveis'
    }
    
    PROFILE_PARAMS = {
        'CONSERVATIVE': {
            'ConfigSetName': '"CONSERVATIVE"',  # 🔥 v4.34: Identificação do .set!
            'AccountRiskPercent': 0.2,  # 🔥 v4.34: 0.5→0.2 (análise: DD 112%)
            'MaxRiskPremium': 0.3,  # 🔥 v4.34: 1.0→0.3 (proporção mantida)
            'TrailingActivationRR': 3.5,  # 🔥 v4.34: 1.5→3.5 (aguardar mais lucro)
            'TrailingATRMultiplier': 4.5,  # 🔥 v4.34: 3.0→4.5 (mais espaço)
            'EnableBreakeven': 'true',
            'BreakevenAfterRR': 1.5,  # 🔥 v4.33: 0.8→1.5
            'MinConfluenceScore': 85,  # 🔥 v4.34: 75→85 (mais rigoroso)
            'AllowGoodSetups': 'false',  # 🔥 v4.34: apenas PREMIUM
            'HourBlacklist': '"0,3,7,9,12,16,18,19,20,21"',  # 🔥 v4.34: 10 piores horas
            'MaxDailyDrawdown': 3.0,
            'MaxWeeklyDrawdown': 5.0,
            'MaxConsecutiveLosses': 3,  # 🔥 v4.34: 2→3
        },
        'MODERATE': {
            'ConfigSetName': '"MODERATE"',  # 🔥 v4.34: Identificação do .set!
            'AccountRiskPercent': 0.3,  # 🔥 v4.34: 1.0→0.3 (+50% vs CONSERVATIVE)
            'MaxRiskPremium': 0.45,  # 🔥 v4.34: 1.5→0.45 (proporção)
            'TrailingActivationRR': 3.0,  # 🔥 v4.34: Menos conservador
            'TrailingATRMultiplier': 4.0,  # 🔥 v4.34: Menos espaço que CONSERVATIVE
            'EnableBreakeven': 'true',
            'BreakevenAfterRR': 1.3,  # 🔥 v4.34: Intermediário
            'MinConfluenceScore': 80,  # 🔥 v4.34: 75→80 (mais rigoroso que antes)
            'AllowGoodSetups': 'false',  # 🔥 v4.34: apenas PREMIUM
            'HourBlacklist': '"0,3,7,9,12,16,18,19,20,21"',  # 🔥 v4.34: Mesmas piores horas
            'MaxDailyDrawdown': 5.0,
            'MaxWeeklyDrawdown': 8.0,
            'MaxConsecutiveLosses': 3,  # 🔥 v4.34: Mantido
        },
        'AGGRESSIVE': {
            'ConfigSetName': '"AGGRESSIVE"',  # 🔥 v4.34: Identificação do .set!
            'AccountRiskPercent': 0.5,  # 🔥 v4.34: 1.5→0.5 (+67% vs MODERATE, mas controlado)
            'MaxRiskPremium': 0.75,  # 🔥 v4.34: 2.0→0.75 (proporção mantida)
            'TrailingActivationRR': 2.5,  # 🔥 v4.34: Mais agressivo
            'TrailingATRMultiplier': 3.5,  # 🔥 v4.34: Menos espaço (aceita mais risco)
            'EnableBreakeven': 'true',
            'BreakevenAfterRR': 1.0,  # 🔥 v4.34: BE mais rápido
            'MinConfluenceScore': 75,  # 🔥 v4.34: Mantido (menos rigoroso = mais trades)
            'AllowGoodSetups': 'true',  # 🔥 v4.34: PERMITE GOOD (mais trades)
            'HourBlacklist': '"0,3,7"',  # 🔥 v4.34: Apenas piores 3 horas (mais liberdade)
            'MaxDailyDrawdown': 8.0,
            'MaxWeeklyDrawdown': 12.0,
            'MaxConsecutiveLosses': 4,  # 🔥 v4.34: Mais tolerante
        }
    }
    
    DEFAULT_PARAMS = {
        'ConfigSetName': '"MODERATE"',  # 🔥 v4.34: DEFAULT = MODERATE
        'AccountRiskPercent': 0.3,  # 🔥 v4.34: 0.5→0.3 (reduzir exposição)
        'MaxRiskPremium': 0.45,  # 🔥 v4.34: 1.0→0.45 (proporção)
        'MaxDailyDrawdown': 5.0,  # 🔥 v4.34: 3.0→5.0 (MODERATE mais tolerante)
        'MaxWeeklyDrawdown': 8.0,  # 🔥 v4.34: 5.0→8.0
        'MaxConsecutiveLosses': 3,  # 🔥 v4.34: Mantido
        'MaxSimultaneousTrades': 1,  # 🔥 v4.31: 3→1 (CRÍTICO)
        'EnableSecondaryHours': 'true',
        'EnableMorningB3': 'false',
        'AvoidNews': 'true',
        'ValidateATRRange': 'true',
        'SendAlerts': 'true',
        'AllowCautiousSetups': 'false',
        'AllowGoodSetups': 'false',  # 🔥 v4.34: true→false (apenas PREMIUM por padrão)
        'HourBlacklist': '"0,3,7,9,12,16,18,19,20,21"',  # 🔥 v4.34: NOVO!
        'FixedLotSize': 0.0,
        'UseVolatilityMetric': 0,
        'ATR_Period': 5,
        'RS_Period': 14,
        'RS_EMAPeriod': 5,
        'RS_Multiplier_Supertrend': 1.2,
        'RS_Multiplier_Trailing': 3.0,
        'RS_Multiplier_TP1': 12.0,
        'RS_Multiplier_TP2': 18.0,
        'RS_Multiplier_TP3': 24.0,
        'TradeOnMonday': 'true',
        'TradeOnTuesday': 'true',
        'TradeOnWednesday': 'true',
        'TradeOnThursday': 'true',
        'TradeOnFriday': 'true',
        'TradeOnSaturday': 'false',
        'TradeOnSunday': 'false',
        'UseCustomTradingHours': 'true',
        'CustomStartHour': 10,
        'CustomStartMinute': 0,
        'CustomEndHour': 16,
        'CustomEndMinute': 0,
        'SL_BufferPoints': 10.0,
        'SL_FallbackPercent': 0.3,
        'SL_MinDistancePoints': 50.0,
        'SL_MaxDistancePoints': 150.0,  # 🔥 v4.30: 300→150 (CRÍTICO: -20% drawdown)
        'SL_UseStructure': 'true',
        'SL_StructureCandles': 50,
        'SL_StructureStrength': 2.0,
        'SL_SafetyMultiplier': 1.1,  # 🔥 v4.30: 1.2→1.1 (SLs menores)
        'EnablePartialTP': 'true',
        'TP1_RR': 2.0,
        'TP2_RR': 4.0,
        'TP3_RR': 6.0,
        'UseTP3': 'false',
        'TP1_ClosePercent': 30.0,
        'TP2_ClosePercent': 50.0,
        'TP3_ClosePercent': 20.0,
        'TP_UseATR': 'true',
        'TP1_ATRMultiplier': 2.0,
        'TP2_ATRMultiplier': 4.0,
        'TP3_ATRMultiplier': 6.0,
        'TP_MinRRRatio': 1.2,
        'EnableTrailing': 'true',
        'TrailingDistancePoints': 200.0,
        'TrailingStepPoints': 50.0,
        'TrailingActivationRR': 3.0,  # 🔥 v4.34: 1.5→3.0 (MODERADO, aguardar mais lucro)
        'TrailingUseATR': 'true',
        'TrailingATRMultiplier': 4.0,  # 🔥 v4.34: 2.5→4.0 (mais espaço)
        'TrailingStartAfterTP': 'true',
        'TrailingMinProfit': 0.5,
        'TrailingMaxRisk': 0.2,
        'MaxSlippagePoints': 30,
        'LookbackStructureBars': 80,
        'BrokerGMTOffset': 2,
        'MaxSpreadMultiplier': 5.0,
        'MinFreeMarginPercent': 20.0,
        'EnableBreakeven': 'true',
        'BreakevenAfterRR': 1.5,  # 🔥 v4.33/v4.34: 1.0→1.5 (aguardar mais lucro)
        'BreakevenPlusPoints': 10.0,  # 🔥 v4.33: 5.0→10.0 (mais folga)
        'EnableProfitLock': 'true',
        'LockProfitAfterRR': 2.0,
        'LockProfitPercent': 50.0,
        'UseAdaptiveSizing': 'false',
        'WinStreakMultiplier': 1.2,
        'WinStreakThreshold': 2,
        'LossStreakDivisor': 0.5,
        'LossStreakThreshold': 2,
        'MaxPositionMultiplier': 2.0,
        'MaxDailyLoss': 5.0,
        'MaxWeeklyLoss': 10.0,
        'ReduceRiskAfterLoss': 'true',
        'RiskReductionFactor': 0.5,
        'RecoveryMode': 'false',
        'UseADXFilter': 'false',
        'ADX_Period': 14,
        'ADX_MinTrend': 25.0,
        'MinConfluenceScore': 80,  # 🔥 v4.34: 75→80 (MODERATE = intermediário)
        'RequireSupertrend': 'false',
        'RequireADXConfirmation': 'false',
        'MinADXStrength': 20.0,
        'RequireVolumeConfirm': 'false',
        'VolumeMultiplier': 1.2,
        'PositionControlMode': 0,
        'ST_OPER_CCI_Period': 50,
        'ST_OPER_ATR_Period': 5,
        'ST_OPER_ATR_Multiplier': 1.0,
        'CS_CalculationPeriod': 24,
        'CS_SmoothingPeriod': 5,
        'CS_ShowInPercent': 'true',
        'RSI_OPER_Period': 14,
        'RSI_OPER_MA_Period': 9,
        'RSI_OPER_MA_Method': 0,
        'RSI_OPER_HighLevel': 70.0,
        'RSI_OPER_LowLevel': 30.0,
        'RSI_OPER_ShowLevels': 'true',
        'WAE_OPER_FastMA': 20,
        'WAE_OPER_SlowMA': 40,
        'WAE_OPER_BBLength': 20,
        'WAE_OPER_BBMultiplier': 2.0,
        'WAE_OPER_Sensitivity': 150,
        'GG_Corner': 0,
        'GG_CreateVisualObjects': 'true',
        'GG_ADX_Period': 14,
        'GG_ADX_Price': 0,
        'GG_Step_Psar': 0.02,
        'GG_Max_Psar': 0.20,
        'EA_MAGIC_NUMBER': 20241015,
    }
    
    def __init__(self, output_dir: Path):
        self.output_dir = output_dir
        self.output_dir.mkdir(parents=True, exist_ok=True)
    
    def generate_complete_set(
        self,
        analysis_data: Dict[str, Any],
        profile: str = 'MODERATE'
    ) -> str:
        """Gera arquivo .set COMPLETO com todos os 90+ parâmetros"""
        
        # Extrair dados da análise
        metadata = analysis_data.get('metadata', {})
        symbol = metadata.get('symbol', analysis_data.get('symbol', 'UNKNOWN'))
        total_trades = metadata.get('n_trades', analysis_data.get('total_trades', 0))
        
        metrics = analysis_data.get('production', {}).get('metrics', {})
        win_rate = metrics.get('win_rate', 0.0)
        sharpe = metrics.get('sharpe_ratio', 0.0)
        dd = metrics.get('max_drawdown_pct', metrics.get('max_drawdown_percent', 0.0))
        pf = metrics.get('profit_factor', 0.0)
        quality = analysis_data.get('quality_score', 0)
        
        # Combinar parâmetros
        params = self.DEFAULT_PARAMS.copy()
        params.update(self.PROFILE_PARAMS.get(profile, {}))
        
        # 🔥 APLICAR OTIMIZAÇÕES DA ANÁLISE (CRÍTICO!)
        if 'recommendations' in analysis_data:
            recs = analysis_data['recommendations']
            
            # 1. Aplicar ajustes de Risk Management
            if 'optimizations' in recs:
                opts = recs['optimizations']
                if 'risk_management' in opts and 'parameters' in opts['risk_management']:
                    risk_params = opts['risk_management']['parameters']
                    # Aplicar apenas para perfil CONSERVATIVE (mais seguro)
                    if profile == 'CONSERVATIVE':
                        params.update(risk_params)
                    # Perfis mais altos mantêm valores originais
                
                # 2. Aplicar ajustes de Trailing Stop
                if 'trailing_stop' in opts and 'parameters' in opts['trailing_stop']:
                    ts_params = opts['trailing_stop']['parameters']
                    # Aplicar para TODOS os perfis se recomendado
                    if 'TrailingDistanceMultiplier' in ts_params:
                        # CONSERVATIVE: usa recomendação + 0.5
                        # MODERATE: usa recomendação
                        # AGGRESSIVE: usa recomendação - 0.5
                        base_mult = ts_params.get('TrailingDistanceMultiplier', 2.5)
                        if profile == 'CONSERVATIVE':
                            params['TrailingATRMultiplier'] = min(base_mult + 0.5, 5.0)
                        elif profile == 'MODERATE':
                            params['TrailingATRMultiplier'] = base_mult
                        else:  # AGGRESSIVE
                            params['TrailingATRMultiplier'] = max(base_mult - 0.5, 1.5)
            
            # 3. 🔥 AJUSTAR HORÁRIOS BASEADO EM worst_hours (CRÍTICO!)
            if 'avoid_conditions' in recs and 'worst_hours' in recs['avoid_conditions']:
                worst_hours = recs['avoid_conditions']['worst_hours']
                if worst_hours and len(worst_hours) > 0:
                    # Encontrar melhor janela de horários (evitando piores)
                    all_hours = list(range(0, 24))
                    good_hours = [h for h in all_hours if h not in worst_hours]
                    
                    if good_hours:
                        # Encontrar maior sequência contínua de boas horas
                        best_start = good_hours[0]
                        best_end = good_hours[0]
                        
                        for h in good_hours:
                            if h >= 8 and h <= 18:  # Preferir horário comercial
                                if best_start == good_hours[0]:  # Primeiro bom
                                    best_start = h
                                best_end = h
                        
                        # Aplicar
                        params['CustomStartHour'] = best_start
                        params['CustomEndHour'] = min(best_end, best_start + 8)  # Máx 8h
        
        # Gerar conteúdo do .set
        content = self.COMPLETE_TEMPLATE.format(
            symbol=symbol,
            profile=profile,
            timestamp=datetime.now().strftime('%Y.%m.%d %H:%M:%S'),
            quality_score=quality,
            total_trades=total_trades,
            **params
        )
        
        return content
    
    def save_set_file(self, content: str, symbol: str, profile: str, version: str = "v4.34") -> Path:
        """Salva arquivo .set com versão no nome"""
        timestamp = datetime.now().strftime('%Y%m%d')
        filename = f"NexusConfluence_{symbol}_{profile}_{version}_{timestamp}.set"
        filepath = self.output_dir / filename
        
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        
        return filepath


def main():
    """Teste standalone"""
    import sys
    
    if len(sys.argv) < 2:
        print("Usage: python complete_set_generator.py <analysis_json_file>")
        sys.exit(1)
    
    analysis_file = Path(sys.argv[1])
    
    if not analysis_file.exists():
        print(f"ERROR: File not found: {analysis_file}")
        sys.exit(1)
    
    # Carregar análise
    with open(analysis_file, 'r') as f:
        analysis_data = json.load(f)
    
    # Gerar .set files no diretório correto do workspace
    generator = CompleteSetGenerator(Path("Presets"))  # Relativo ao workspace atual
    
    # Extrair símbolo correto do metadata
    symbol = analysis_data.get('metadata', {}).get('symbol', analysis_data.get('symbol', 'UNKNOWN'))
    
    # Detectar versão atual do EA (baseado nas correções aplicadas)
    version = "v4.32"  # Versão atual após correções
    
    for profile in ['CONSERVATIVE', 'MODERATE', 'AGGRESSIVE']:
        content = generator.generate_complete_set(analysis_data, profile)
        filepath = generator.save_set_file(
            content,
            symbol,
            profile,
            version  # Incluir versão
        )
        print(f"✅ Generated: {filepath}")
        print(f"   Size: {filepath.stat().st_size:,} bytes")
        print(f"   Parameters: 90+ complete")
        print()


if __name__ == '__main__':
    main()
