//+------------------------------------------------------------------+
//|                        NexusV3Inputs.mqh                          |
//|                  Nexus Confluence V3 - Input Parameters            |
//|                     Copyright 2024-2026, Nexus EA                 |
//+------------------------------------------------------------------+
#property copyright "Nexus Confluence V3"
#property version   "3.00"

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+

input group "=== GESTAO DE RISCO ==="
input double   InpLotSize        = 0.01;      // Tamanho do Lote
input int      InpMaxSlippage    = 10;        // Slippage Maximo (pontos)

input group "=== PARAMETROS BUY ==="
input bool     InpEnableBuy      = true;      // Habilitar BUY
input int      InpStopLossBuy    = 400;       // Stop Loss BUY (distancia preco)
input int      InpTakeProfitBuy  = 900;       // Take Profit BUY (distancia preco)
input int      InpMinScoreBuy    = 2;         // Score Minimo BUY (1-4)

input group "=== PARAMETROS SELL ==="
input bool     InpEnableSell     = true;      // Habilitar SELL
input int      InpStopLossSell   = 200;       // Stop Loss SELL (distancia preco)
input int      InpTakeProfitSell = 500;       // Take Profit SELL (distancia preco)
input int      InpMinScoreSell   = 4;         // Score Minimo SELL (1-4)

input group "=== BREAK EVEN BUY ==="
input bool     InpBE_Buy_Enable  = true;      // BE BUY Habilitado
input int      InpBE_Buy_Trigger = 300;       // BE BUY Trigger (distancia)
input int      InpBE_Buy_Step    = 50;        // BE BUY Step (distancia)

input group "=== BREAK EVEN SELL ==="
input bool     InpBE_Sell_Enable = true;      // BE SELL Habilitado
input int      InpBE_Sell_Trigger= 150;       // BE SELL Trigger (distancia)
input int      InpBE_Sell_Step   = 30;        // BE SELL Step (distancia)

input group "=== TRAILING STOP BUY ==="
input bool     InpTS_Buy_Enable  = false;     // TS BUY Habilitado
input int      InpTS_Buy_Trigger = 400;       // TS BUY Trigger (distancia)
input int      InpTS_Buy_Step    = 200;       // TS BUY Step (distancia)

input group "=== TRAILING STOP SELL ==="
input bool     InpTS_Sell_Enable = false;     // TS SELL Habilitado
input int      InpTS_Sell_Trigger= 200;       // TS SELL Trigger (distancia)
input int      InpTS_Sell_Step   = 100;       // TS SELL Step (distancia)

input group "=== PROTECAO DRAWDOWN ==="
input bool     InpDD_Enable      = true;      // DD Protection Habilitado
input double   InpDD_DailyMax    = 5.0;       // DD Maximo Diario (%)
input int      InpDD_ConsecLoss  = 7;         // Perdas Consecutivas Max
input double   InpDD_LotReduce   = 0.5;       // Fator Reducao Lote (0.0-1.0)

input group "=== FILTRO DE SPREAD ==="
input bool     InpEnableSpreadFilter = true;  // Spread Filter Habilitado
input int      InpMaxSpread      = 20;        // Spread Maximo (pontos)
input double   InpSpreadMulti    = 1.5;       // Multiplicador Spread Dinamico
input int      InpSpreadPeriod   = 20;        // Periodo Calculo Mediana

input group "=== FILTRO DE HORARIO ==="
input bool     InpUseTimeFilter  = false;     // Usar Filtro de Horario
input string   InpStartTime      = "09:00";   // Horario Inicial
input string   InpEndTime        = "17:00";   // Horario Final

input group "=== FILTRO SEMANAL ==="
input bool     InpTradeOnSunday  = false;     // Operar Domingo
input bool     InpTradeOnMonday  = true;      // Operar Segunda
input bool     InpTradeOnTuesday = true;      // Operar Terca
input bool     InpTradeOnWednesday = true;    // Operar Quarta
input bool     InpTradeOnThursday = true;     // Operar Quinta
input bool     InpTradeOnFriday  = true;      // Operar Sexta
input bool     InpTradeOnSaturday = false;    // Operar Sabado

input group "=== TIMEFRAMES ==="
input ENUM_TIMEFRAMES InpMacro1TF      = PERIOD_H4;   // Macro 1 TF
input ENUM_TIMEFRAMES InpMacro2TF      = PERIOD_H1;   // Macro 2 TF
input ENUM_TIMEFRAMES InpMacro3TF      = PERIOD_M30;  // Macro 3 TF
input ENUM_TIMEFRAMES InpOperationalTF = PERIOD_M15;  // Operational TF

input group "=== PERFIS DE SINAL ==="
input bool     InpBuyPremiumEnable  = true;   // Aceitar BUY PREMIUM
input bool     InpBuyGoodEnable     = true;   // Aceitar BUY GOOD
input bool     InpSellPremiumEnable = true;   // Aceitar SELL PREMIUM
input bool     InpSellGoodEnable    = true;   // Aceitar SELL GOOD

input group "=== GG TRENDBAR ==="
input int      InpGG_ADX_Period  = 14;        // ADX Period
input double   InpGG_PSAR_Step   = 0.02;      // PSAR Step
input double   InpGG_PSAR_Max    = 0.20;      // PSAR Maximum
input double   InpGG_DI_Sep     = 3.0;        // DI Min Separacao (confirmacao trend)

input group "=== SUPERTREND ADAPTIVE ==="
input int      InpST_CCI_Period  = 50;        // CCI Period
input int      InpST_ER_Period   = 10;        // Efficiency Ratio Period
input int      InpST_Vol_Period  = 5;         // True Range EMA Period
input double   InpST_BandMult   = 1.5;       // Band Multiplier
input double   InpST_BandTrendF = 0.5;        // Band Trend Factor (0.0-1.0, estreitamento)

input group "=== OBV MACD ==="
input int      InpMACD_FastEMA   = 5;         // Fast EMA Period
input int      InpMACD_SlowEMA   = 13;        // Slow EMA Period
input int      InpMACD_SignalSMA = 4;         // Signal SMA Period
input int      InpMACD_ObvWindow = 20;        // OBV Lookback Window
input bool     InpMACD_UseTickVol= true;      // Usar Tick Volume
input int      InpMACD_ThreshPrd = 14;        // Threshold Period
input double   InpMACD_ThreshMlt = 0.4;       // Threshold Multiplier

input group "=== RSI OMA ==="
input int      InpRSI_Period     = 14;        // RSI Period
input int      InpRSI_MA_Period  = 9;         // MA Period
input ENUM_MA_METHOD InpRSI_MA_Method = MODE_SMA; // MA Method
input double   InpRSI_Hysteresis = 0.01;      // Histerese RSI vs MA (limiar cruzamento)

input group "=== CURRENCY STRENGTH ==="
input bool     InpCS_Enable      = true;      // CS Habilitado
input int      InpCS_CalcPeriod  = 24;        // Periodo de Calculo
input int      InpCS_Smoothing   = 5;         // Suavizacao

input group "=== COOLDOWN ANTI-CHURN ==="
input bool     InpCooldownEnable = true;      // Cooldown Habilitado
input int      InpCooldownCandles= 3;         // Candles de Bloqueio apos SL

input group "=== GATE 4 RSI EXTREMOS ==="
input double   InpG4_RSI_OB      = 75.0;      // RSI Overbought (rejeita BUY acima)
input double   InpG4_RSI_OS      = 25.0;      // RSI Oversold (rejeita SELL abaixo)

input group "=== FILTRO QUALIDADE TREND ==="
input double   InpG5_ER_Min       = 0.35;    // ER Minimo (0.0-1.0, trend quality)
input double   InpG5_ER_Decline   = 0.65;    // Ratio Max Queda ER (0.65=rejeita 35% queda)
input double   InpG5_MomentumRatio= 1.5;     // Histograma > Threshold x Ratio
input int      InpG5_MacroFlipCD  = 4;        // Cooldown Macro Flip (candles, 0=off)

input group "=== SL/TP DINAMICO ==="
input double   InpDynSL_Max      = 1.5;       // SL Multiplicador ER=0 (ranging)
input double   InpDynSL_Min      = 0.7;       // SL Multiplicador ER=1 (trending)
input double   InpDynTP_Min      = 0.8;       // TP Multiplicador ER=0 (ranging)
input double   InpDynTP_Max      = 1.5;       // TP Multiplicador ER=1 (trending)
input int      InpMinSLTP_Steps  = 10;        // SL/TP Minimo (steps)

input group "=== MULTI-POSICAO ==="
input int      InpMaxPositions   = 1;         // Max Posicoes Simultaneas (1=classico)
input double   InpLotScaleFactor = 0.5;       // Fator Reducao Lote por posicao (0.5=50%)

input group "=== GERAL ==="
input int      InpMagicNumber    = 20261024;  // Magic Number
input int      InpLogLevel       = 2;         // Nivel Log (1=Exec, 2=Oper, 3=Debug)

//+------------------------------------------------------------------+
//| Parse time string "HH:MM" into hour and minute                    |
//+------------------------------------------------------------------+
bool ParseTimeInput(string time_str, int &hour, int &minute)
{
    int colon_pos = StringFind(time_str, ":");
    if(colon_pos < 0) return false;

    hour   = (int)StringToInteger(StringSubstr(time_str, 0, colon_pos));
    minute = (int)StringToInteger(StringSubstr(time_str, colon_pos + 1));

    return (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59);
}
