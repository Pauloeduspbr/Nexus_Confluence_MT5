//+------------------------------------------------------------------+
//| Parametros.mqh                                                    |
//| Nexus Confluence EA v4.36 - Sistema Multi-Timeframe Universal    |
//|                                                                   |
//| PROPÓSITO: Centralizar TODOS os inputs e enumerações do EA       |
//| 🔥 v4.36: CORREÇÃO CRÍTICA - DAR ESPAÇO PARA TENDÊNCIAS!        |
//|                                                                   |
//| CHANGELOG v4.36 (CORRIGIDO):                                     |
//|   - SL_MinDistancePoints: 65 → 100 pts (+54%, DAR ESPAÇO!)      |
//|   - SL_MaxDistancePoints: 156 → 250 pts (+60%, RESPIRAR!)       |
//|   - TP1_RR: 0.7 → 0.5 (fechar parcial MÍNIMO, 20% posição)      |
//|   - TP2_RR: 1.5 → 8.0 (+433%, PEGAR TENDÊNCIAS MÉDIAS!)         |
//|   - TP3_RR: 3.0 → 18.0 (+500%, TENDÊNCIAS GRANDES +110 pips!)   |
//|   - TrailingActivationRR: 3.5 → 5.0 (+43%, aguardar mais!)       |
//|   - TrailingATRMultiplier: 4.5 → 6.0 (+33%, MUITO mais espaço!) |
//|   - BreakevenAfterRR: 1.5 → 4.0 (+167%, NÃO cortar cedo!)       |
//|   - TP parciais: 40/40/20 → 20/30/30 (80% para tendência!)      |
//|                                                                   |
//| PROBLEMA RESOLVIDO v4.36:                                        |
//|   ❌ SL muito curto = stop em correções normais                  |
//|   ❌ TP muito curto = sai antes da tendência completar           |
//|   ❌ BE muito cedo = corta trade lucrativo prematuramente        |
//|   ✅ RESULTADO: Pegar tendências de +110 pips (gráfico!)         |
//|                                                                   |
//| AUTOR: GitHub Copilot + Desenvolvedor                            |
//| DATA: Outubro 2025                                               |
//| VERSÃO: 4.36 - DAR ESPAÇO PARA TENDÊNCIAS!                      |
//+------------------------------------------------------------------+
#property copyright "Nexus Confluence EA v4.36"
#property version   "4.36"
#property strict

//+------------------------------------------------------------------+
//| SEÇÃO 1: ENUMERAÇÕES (ENUMS)                                     |
//+------------------------------------------------------------------+

//--- Direção do trade
enum TRADE_DIRECTION
{
   TRADE_DIRECTION_NONE = -1,  // Sem direção (indeciso/amarelo)
   TRADE_DIRECTION_BUY  = 0,   // Compra
   TRADE_DIRECTION_SELL = 1    // Venda
};

//--- Classificação do setup
enum SETUP_CLASS
{
   SETUP_REJECT  = 0,  // Rejeitado (não operar)
   SETUP_GOOD    = 1,  // Bom (2/3 filtros ou 2/2 + condições)
   SETUP_PREMIUM = 2   // Premium (3/3 filtros ou 2/2 todos alinhados)
};

//--- Classe de ativo
enum ASSET_CLASS
{
   ASSET_CLASS_UNKNOWN      = 0,  // Desconhecido
   ASSET_CLASS_FOREX_MAJOR  = 1,  // Forex Major (EUR/USD, GBP/USD, etc)
   ASSET_CLASS_FOREX_MINOR  = 2,  // Forex Minor (EUR/GBP, EUR/JPY, etc)
   ASSET_CLASS_FOREX_EXOTIC = 3,  // Forex Exotic (USD/BRL, USD/MXN, etc)
   ASSET_CLASS_CURRENCY_B3  = 4,  // WDO (Mini Dólar B3)
   ASSET_CLASS_INDEX_B3     = 5,  // WIN (Mini Índice Bovespa)
   ASSET_CLASS_INDEX_US     = 6,  // Índices US (S&P500, Nasdaq, Dow)
   ASSET_CLASS_INDEX_EU     = 7,  // Índices Europa (DAX, FTSE, CAC)
   ASSET_CLASS_METALS       = 8,  // Metais (Ouro, Prata)
   ASSET_CLASS_CRYPTO       = 9,  // Criptomoedas (BTC, ETH)
   ASSET_CLASS_TOTAL        = 10  // Total de classes (controle)
};

//--- Modo de controle de posições
enum POSITION_CONTROL_MODE
{
   POSITION_MODE_SINGLE    = 0,  // Uma posição por vez
   POSITION_MODE_MULTIPLE  = 1,  // Múltiplas posições permitidas
   POSITION_MODE_PROTECTED = 2   // Múltiplas após lucro protegido
};

//+------------------------------------------------------------------+
//| SEÇÃO 2: ESTRUTURAS DE DADOS (STRUCTS)                           |
//+------------------------------------------------------------------+

//--- Sinal do Trend Magic
struct TMSignal
{
   bool            isValid;         // Sinal válido?
   TRADE_DIRECTION direction;       // Direção (BUY/SELL/NONE)
   double          strength;        // Força do sinal
   ENUM_TIMEFRAMES timeframe;       // Timeframe do sinal
   bool            turnedRecently;  // Virou recentemente (2 candles)
};

//--- Sinal do Currency Strength
struct CSSignal
{
   bool   isValid;    // Sinal válido?
   bool   isAligned;  // Alinhado com direção pretendida?
   double strength;   // Diferença de força entre moedas
};

//--- Sinal do RSI OMA
struct RSISignal
{
   bool   isValid;    // Sinal válido?
   bool   isAligned;  // Alinhado com direção pretendida?
   double strength;   // Força do RSI
   double slope;      // Inclinação da linha vermelha
};

//--- Sinal do WAE
struct WAESignal
{
   bool   isValid;      // Sinal válido?
   bool   isAligned;    // Alinhado com direção pretendida?
   bool   isExpanding;  // Histograma expandindo?
   double strength;     // Força do histograma
};

//--- Sinal do GG TrendBar
struct GGTrendBarSignal
{
   bool            isValid;           // Sinal válido?
   int             m1Value;           // +1 bullish, 0 neutral, -1 bearish
   int             m5Value;
   int             m15Value;
   int             m30Value;
   int             h1Value;
   int             h4Value;
   int             d1Value;
   int             w1Value;
   int             mn1Value;
   bool            h4Bullish;         // H4 altista?
   bool            h1Bullish;         // H1 altista?
   bool            m30Bullish;        // M30 altista?
   bool            m15Bullish;        // M15 altista?
   TRADE_DIRECTION overallDirection;  // Direção geral
};

//--- Resultado análise multi-timeframe
struct MultiTFResult
{
   bool            isValid;         // Análise válida?
   TRADE_DIRECTION direction;       // Direção do alinhamento
   bool            h4Aligned;       // MACRO-1 alinhado (representação abstrata)
   bool            h1Aligned;       // MACRO-2 alinhado
   bool            m30Aligned;      // MACRO-3 alinhado (se aplicável)
   bool            structureValid;  // Estrutura de preços válida?
};

//--- Pontuação do setup
struct SetupScore
{
   SETUP_CLASS     classification;          // Classificação final
   int             requiredPoints;          // Pontos requeridos (2 ou 3)
   int             totalPoints;             // Total de pontos obtidos
   int             traderMagicPoints;       // TM (sempre 1 se válido)
   int             currencyStrengthPoints;  // CS (0 ou 1)
   int             rsiomaPoints;            // RSI (0 ou 1)
   int             waePoints;               // WAE (0 ou 1)
   TRADE_DIRECTION direction;               // Direção do setup
};

//--- Cálculo de risco
struct RiskCalculation
{
   bool            isValid;            // Cálculo válido?
   string          errorMessage;       // Mensagem de erro (se houver)
   double          positionSize;       // Tamanho da posição (lotes)
   double          stopLoss;           // Stop Loss
   double          takeProfit1;        // Take Profit 1 (TP1)
   double          takeProfit2;        // Take Profit 2 (TP2)
   double          takeProfit3;        // Take Profit 3 (TP3)
   double          slDistance;         // Distância até SL
   double          riskAmount;         // Valor em risco (moeda da conta)
   double          potentialProfit1;   // Lucro potencial TP1
   double          potentialProfit2;   // Lucro potencial TP2
   double          potentialProfit3;   // Lucro potencial TP3
};

//--- Configuração por classe de ativo
struct AssetConfig
{
   bool   useCurrencyStrength;      // Usar Currency Strength?
   int    requiredFilters;          // Total de filtros (2 ou 3)
   int    minFiltersForTrade;       // Mínimo para trade (2)
   double idealSLMinPips;           // SL mínimo ideal (pips)
   double idealSLMaxPips;           // SL máximo ideal (pips)
   double slBufferPips;             // Buffer adicional (pips)
   double minATR;                   // ATR mínimo
   double maxATR;                   // ATR máximo
   double maxSpreadPips;            // Spread máximo permitido (pips)
   double trailingDistancePips;     // Distância trailing (pips)
   double pipValueOverride;         // Valor pip override (0 = auto)
   int    primeHourStart;           // Horário prime início (HHMM)
   int    primeHourEnd;             // Horário prime fim (HHMM)
   double premiumRiskPercent;       // Risco % setup premium
   double goodRiskPercent;          // Risco % setup good
};

//--- Handles dos indicadores
struct IndicatorHandles
{
   // GG TrendBar - FILTRO MESTRE (analisa todos os TFs internamente)
   int gg_global;         // GG TrendBar Global Multi-TF
   
   // FILTROS MICRO - APENAS OPERACIONAL (TF atual do gráfico)
   int st_oper;           // Supertrend (Trend Magic) Operacional - tendência local
   int wae_oper;          // WAE Operacional - momentum/explosão
   int rsi_oper;          // RSI OMA Operacional - força relativa
   int cs_oper;           // Currency Strength Operacional - contexto moedas
};

//--- Registro de trade
struct TradeRecord
{
   datetime        openTime;      // Hora abertura
   datetime        closeTime;     // Hora fechamento
   string          symbol;        // Símbolo
   TRADE_DIRECTION direction;     // Direção
   double          openPrice;     // Preço abertura
   double          closePrice;    // Preço fechamento
   double          profit;        // Lucro/Prejuízo
   double          riskAmount;    // Valor arriscado
   double          rr;            // Risk/Reward real
   SETUP_CLASS     setupClass;    // Classificação setup
   string          closeReason;   // Razão fechamento
   bool            tp1Hit;        // TP1 atingido?
   bool            tp2Hit;        // TP2 atingido?
};

//+------------------------------------------------------------------+
//| SEÇÃO 3: INPUTS GERAIS DO EA                                     |
//+------------------------------------------------------------------+

input group "════════════════════════════════════════════════════════"
input group "          🎯 NEXUS CONFLUENCE v4.1 - MULTI-TF          "
input group "════════════════════════════════════════════════════════"

input group "=== 🏷️ IDENTIFICAÇÃO DO BACKTEST - v4.36 ==="
input string ConfigSetName            = "CONSERVATIVE"; // 🔥 v4.36: Nome do .set rodando (CONSERVATIVE/MODERATE/AGGRESSIVE) - CRÍTICO para análise separada!

input group "=== ⚙️ CONFIGURAÇÕES GERAIS ==="
input double AccountRiskPercent       = 0.2;    // � % Conta em risco por trade (CONSERVADOR) - 🔥 v4.34: 0.3→0.2 (Análise: DD 112%, reduzir exposição)
input double MaxRiskPremium           = 0.3;    // 💎 Máx % risco para setups PREMIUM - 🔥 v4.34: 0.5→0.3 (Análise: mesma proporção 0.2→0.3)
// 🔥 REMOVIDO v4.9: input double MaxDrawdownPercent = 15.0; // Bloqueio por drawdown DESABILITADO
// 🔥 v4.15: PROTEÇÕES DE DRAWDOWN REATIVADAS (versão melhorada)
// 🔥 v4.31: PROTEÇÃO CRÍTICA - Análise mostrou DD 929.8% com risco 0.5-1.0%
// 🔥 v4.35: PROTEÇÃO AGRESSIVA - Análise 230947: DD 130.89%, Sharpe 0.01, PF 1.03
input double MaxDailyDrawdown         = 2.5;   // 🛡️ Drawdown máximo diário (%) - 🔥 v4.35: 3.0→2.5 (reduzir limite)
input double MaxWeeklyDrawdown        = 5.0;   // 🛡️ Drawdown máximo semanal (%) - pausa trading
input int    MaxConsecutiveLosses     = 3;     // 🛡️ Máximo perdas consecutivas - 🔥 v4.34: 2→3 (Análise: balancear proteção/oportunidades)
input int    MaxSimultaneousTrades    = 1;     // 🔢 Máximo de trades simultâneos - 🔥 v4.31: 3→1 (CRÍTICO: reduzir exposição)
input bool   EnableSecondaryHours     = true;  // 🕐 Habilitar horários secundários Forex
input bool   EnableMorningB3          = false; // 🇧🇷 Habilitar sessão da manhã B3
input bool   AvoidNews                = true;  // 📰 Evitar operar próximo a notícias
input bool   ValidateATRRange         = true;  // 📏 Validar ATR ideal por ativo
input bool   SendAlerts               = true;  // 🔔 Enviar notificações push
input bool   AllowCautiousSetups      = false; // ⚠️ Permitir setups CAUTELOSOS (2/2 + MACRO-3 oposto)
input bool   AllowGoodSetups          = false; // 🔥 v4.34: DESABILITADO (Análise: GOOD tem WR 35-40%, apenas PREMIUM 50-55%)
input string HourBlacklist            = "0,18"; // ⏰ v4.35: Horas a evitar (0=00:00 WR 0%, 18=18:00 PF 0.59)
input bool   EnableHourFilter         = true;  // 🔥 v4.35: Ativar filtro de horários críticos
input string TradingStartHour         = "01:00"; // 🔥 v4.35: Hora início (evitar 00:00 WR=0%)
input string TradingEndHour           = "22:59"; // 🔥 v4.35: Hora fim (evitar 23:00+)

input group "=== 💰 GESTÃO DE LOTE ==="
input double FixedLotSize             = 0.0;   // 📌 Lote Fixo (0 = cálculo automático por risco %)
                                               // Forex: 0.01 | B3: 1.0 | Índices: 0.1

input group "=== 📊 MÉTRICA DE VOLATILIDADE - v4.28 ==="
enum VOLATILITY_METRIC
{
   VOLATILITY_ATR = 0,              // ATR Tradicional (5 períodos, rápido)
   VOLATILITY_ROGERS_SATCHELL = 1,  // Rogers-Satchell (14 períodos, +35% estável)
   VOLATILITY_SATR_BLEND = 2        // SATR Blend (10+5, balanceado) - FUTURO
};
input VOLATILITY_METRIC UseVolatilityMetric = VOLATILITY_ATR;  // 📊 Métrica de volatilidade
input int    ATR_Period                     = 5;      // 📊 Período ATR (padrão: 5)
input int    RS_Period                      = 14;     // 📊 Período Rogers-Satchell (recomendado: 14)
input int    RS_EMAPeriod                   = 5;      // 📊 Suavização EMA para RS (trailing)
input double RS_Multiplier_Supertrend       = 1.2;    // 📊 RS Multiplicador Supertrend (+20% vs ATR)
input double RS_Multiplier_Trailing         = 3.0;    // 📊 RS Multiplicador Trailing (+20% vs ATR)
input double RS_Multiplier_TP1              = 12.0;   // 📊 RS Multiplicador TP1 (+20% vs ATR)
input double RS_Multiplier_TP2              = 18.0;   // 📊 RS Multiplicador TP2 (+20% vs ATR)
input double RS_Multiplier_TP3              = 24.0;   // 📊 RS Multiplicador TP3 (+33% vs ATR)

input group "=== 📅 FILTRO SEMANAL - Dias da Semana ==="
input bool   TradeOnMonday            = true;  // 📅 Operar na Segunda-feira
input bool   TradeOnTuesday           = true;  // 📅 Operar na Terça-feira
input bool   TradeOnWednesday         = true;  // 📅 Operar na Quarta-feira
input bool   TradeOnThursday          = true;  // 📅 Operar na Quinta-feira
input bool   TradeOnFriday            = true;  // 📅 Operar na Sexta-feira
input bool   TradeOnSaturday          = false; // 📅 Operar no Sábado (Cripto 24/7)
input bool   TradeOnSunday            = false; // 📅 Operar no Domingo (Cripto 24/7)

input group "=== ⏰ HORÁRIOS CUSTOMIZÁVEIS (para otimização) ==="
input bool   UseCustomTradingHours    = true;  // ⏰ Usar horários customizados - 🔥 v4.15: ATIVADO
input int    CustomStartHour          = 11;    // ⏰ Horário início (hora) - 🔥 v4.31: 10→11 (evitar worst hours da análise)
input int    CustomStartMinute        = 0;     // ⏰ Horário início (minuto)
input int    CustomEndHour            = 17;    // ⏰ Horário fim (hora) - 🔥 v4.31: 16→17 (estender janela NY)
input int    CustomEndMinute          = 0;     // ⏰ Horário fim (minuto)

input group "=== ⚠️ CONFIGURAÇÃO DE STOP LOSS ==="
input double SL_BufferPoints          = 15.0;   // 📏 Buffer adicional SL (pontos) - 🔥 v4.36: 10→15 (mais espaço)
input double SL_FallbackPercent       = 0.5;    // 📉 SL fallback (% do preço se estrutura falhar) - 🔥 v4.36: 0.3→0.5
input double SL_MinDistancePoints     = 100.0;  // 📊 Distância mínima SL (pontos) - 🔥 v4.36: 65→100 CRÍTICO (+54%, DAR ESPAÇO!)
input double SL_MaxDistancePoints     = 250.0;  // 📊 Distância máxima SL (pontos) - 🔥 v4.36: 156→250 CRÍTICO (+60%, PEGAR TENDÊNCIAS!)
input bool   SL_UseStructure          = true;   // 🏗️ Usar estrutura de preço para SL
input int    SL_StructureCandles      = 80;     // 🔍 Quantos candles analisar para estrutura - 🔥 v4.36: 50→80 (estrutura mais sólida)
input double SL_StructureStrength     = 1.5;    // 💪 Força mínima do swing (ATR multiplicador) - 🔥 v4.36: 2.0→1.5 (menos rigoroso)
input double SL_SafetyMultiplier      = 1.10;   // 🛡️ Margem de segurança - 🔥 v4.36: 1.05→1.10 (mais espaço para volatilidade)

input group "=== 🎯 CONFIGURAÇÃO DE TAKE PROFIT ==="
input bool   EnablePartialTP          = true;   // ✂️ Habilitar saídas parciais
input double TP1_RR                   = 0.5;    // 🎯 TP1 Risk/Reward - 🔥 v4.36: 0.7→0.5 (fechar parcial MUITO CEDO, proteger)
input double TP2_RR                   = 8.0;    // 🎯 TP2 Risk/Reward - 🔥 v4.36: 1.5→8.0 CRÍTICO (+433%, PEGAR TENDÊNCIAS!)
input double TP3_RR                   = 18.0;   // 🎯 TP3 Risk/Reward - 🔥 v4.36: 3.0→18.0 CRÍTICO (+500%, TENDÊNCIAS GRANDES!)
input bool   UseTP3                   = true;   // 🎯 Ativar TP3 - 🔥 v4.31: ATIVADO (necessário para PF >1.3)
input double TP1_ClosePercent         = 20.0;   // 📊 % posição fechar no TP1 - 🔥 v4.36: 40→20 (MÍNIMO, deixar 80% para tendência!)
input double TP2_ClosePercent         = 30.0;   // 📊 % posição fechar no TP2 - 🔥 v4.36: 40→30 (proteger lucro)
input double TP3_ClosePercent         = 30.0;   // 📊 % posição fechar no TP3 - 🔥 v4.36: 20→30 (deixar 20% para trailing!)
input bool   TP_UseATR                = true;   // 📊 Usar ATR para cálculo de TP (dinâmico)
input double TP1_ATRMultiplier        = 2.5;    // 📊 TP1 = X vezes ATR (se TP_UseATR=true)
input double TP2_ATRMultiplier        = 10.0;   // 📊 TP2 = X vezes ATR - 🔥 v4.36: 5.0→10.0 (tendências médias)
input double TP3_ATRMultiplier        = 20.0;   // 📊 TP3 = X vezes ATR - 🔥 v4.36: 8.0→20.0 (tendências grandes)
input double TP_MinRRRatio            = 1.2;    // 🎯 RR mínimo aceitável - 🔥 v4.36: 1.5→1.2 (aceitar mais setups)

input group "=== 📈 CONFIGURAÇÃO DE TRAILING STOP ==="
input bool   EnableTrailing           = true;   // 📈 Habilitar trailing stop
input double TrailingDistancePoints   = 300.0;  // 📏 Distância trailing (pontos) - 🔥 v4.36: 200→300 (mais espaço)
input double TrailingStepPoints       = 75.0;   // 📏 Passo mínimo trailing (pontos) - 🔥 v4.36: 50→75 (menos ajustes)
input double TrailingActivationRR     = 5.0;    // 🎯 Ativar após RR - 🔥 v4.36: 3.5→5.0 (+43%, aguardar mais lucro!)
input bool   TrailingUseATR           = true;   // 📊 Usar ATR para calcular trailing - 🔥 v4.15: ATIVADO
input double TrailingATRMultiplier    = 6.0;    // 📊 Multiplicador ATR - 🔥 v4.36: 4.5→6.0 (+33%, MUITO mais espaço!)
input bool   TrailingStartAfterTP     = true;   // 🎯 Iniciar trailing apenas após TP1 fechado
input double TrailingMinProfit        = 0.3;    // 💰 Lucro mínimo % para ativar trailing - 🔥 v4.36: 0.5→0.3 (ativar antes)
input double TrailingMaxRisk          = 0.1;    // 🛡️ Risco máximo % permitido no trailing - 🔥 v4.36: 0.2→0.1 (mais conservador)

input group "=== 🛡️ PROTEÇÕES ==="
input int    MaxSlippagePoints        = 30;    // 🎚️ Desvio máximo em pontos
input int    LookbackStructureBars    = 80;    // 📊 Candles para buscar estrutura M15
input int    BrokerGMTOffset          = 2;     // 🌍 Fuso horário do broker (horário inverno)
input double MaxSpreadMultiplier      = 5.0;   // 🎯 Multiplicador spread máximo (5x = muito tolerante para testes)

input group "=== 🏦 PROTEÇÕES DE MARGEM - v4.30 ==="
input double MinFreeMarginPercent     = 20.0;  // 🏦 % Margem mínima livre após trade (20% = seguro, 10% = arriscado)

input group "=== 🎯 BREAKEVEN E PROTEÇÃO DE LUCRO ==="
input bool   EnableBreakeven          = true;   // 🛡️ Mover SL para breakeven
input double BreakevenAfterRR         = 4.0;    // 🎯 Mover BE após X:1 RR - 🔥 v4.36: 1.5→4.0 (+167%, NÃO cortar prematuramente!)
input double BreakevenPlusPoints      = 15.0;   // 📏 BE + X pontos (garantir lucro mínimo) - 🔥 v4.36: 10→15 (maior margem)
input bool   EnableProfitLock         = true;   // 🔒 Travar lucro parcial
input double LockProfitAfterRR        = 6.0;    // 🎯 Travar lucro após X:1 RR - 🔥 v4.36: 2.0→6.0 (aguardar mais lucro)
input double LockProfitPercent        = 50.0;   // 📊 % do lucro flutuante a travar

input group "=== 💰 CONTROLE DE RISCO AVANÇADO ==="
input bool   UseAdaptiveSizing        = false;  // 📊 Tamanho de posição adaptativo
input double WinStreakMultiplier      = 1.2;    // 📈 Multiplicar lote após X ganhos seguidos
input int    WinStreakThreshold       = 2;      // 🎯 Quantos ganhos para aumentar lote
input double LossStreakDivisor        = 0.5;    // 📉 Dividir lote após X perdas seguidas
input int    LossStreakThreshold      = 2;      // 🎯 Quantas perdas para reduzir lote
input double MaxPositionMultiplier    = 2.0;    // 🛡️ Limite máximo de multiplicação (2x = dobro do lote base)
input double MaxDailyLoss             = 5.0;    // 🛑 Perda máxima diária % (pausa trading)
input double MaxWeeklyLoss            = 10.0;   // 🛑 Perda máxima semanal % (pausa trading)
input bool   ReduceRiskAfterLoss      = true;   // 📉 Reduzir risco após perdas consecutivas
input double RiskReductionFactor      = 0.5;    // 📊 Fator de redução (0.5 = metade do risco)
input bool   RecoveryMode             = false;  // 🔄 Modo recuperação gradual após drawdown

input group "=== 📊 FILTRO ADX (Trending Markets) - 🔥 v4.15 ==="
input bool   UseADXFilter             = false; // 📊 Habilitar filtro ADX (mercados trending)
input int    ADX_Period               = 14;    // 📊 Período ADX
input double ADX_MinTrend             = 25.0;  // 📊 ADX mínimo para tendência (< 25 = ranging)

input group "=== 🎯 QUALIDADE DE SETUP (Confluência) ==="
input int    MinConfluenceScore       = 70;    // 📊 Pontuação mínima 0-100 - 🔥 v4.34: 75→70 (Análise: apenas setups 70+ têm WR>45%)
input bool   RequireSupertrend        = true;  // ⚠️ Supertrend obrigatório - 🔥 v4.31: REATIVADO (filtro adicional crítico)
input bool   RequireADXConfirmation   = false; // 📊 ADX deve confirmar direção
input double MinADXStrength           = 20.0;  // 💪 Força mínima ADX se RequireADX=true
input bool   RequireVolumeConfirm     = false; // 📊 Requer volume acima da média
input double VolumeMultiplier         = 1.2;   // 📊 Volume deve ser X vezes a média

input group "=== 📊 CONTROLE DE POSIÇÕES ==="
input POSITION_CONTROL_MODE PositionControlMode = POSITION_MODE_SINGLE; // 🔢 Modo de controle de posições

input group "=== 📁 INDICADORES - Caminhos dos Arquivos ==="
input string IndicatorsBasePath       = "NexusConfluenceEA\\"; // 📂 Pasta relativa em MQL5/Indicators
input string GGTrendBarIndicator      = "GG_TrendBar_Indicator";
input string TrendMagicIndicator      = "TrendMagic_MT5";
input string CurrencyStrengthIndicator= "CurrencyStrengthMeter_MT5";
input string RSIOMAIndicator          = "RSIOMA_v2HHLSX_MT5";
input string WAEIndicator             = "WaddahAttarExplosion_Professional";

//+------------------------------------------------------------------+
//| SEÇÃO 4: INPUTS DOS INDICADORES - ORGANIZADOS POR TIMEFRAME     |
//+------------------------------------------------------------------+

//╔══════════════════════════════════════════════════════════════════╗
//║         📊 SUPERTREND (Trend Magic) - APENAS OPERACIONAL         ║
//║                                                                  ║
//║  NOTA: GG TrendBar analisa TODOS os timeframes macro (M1-MN1)   ║
//║        Trend Magic usado apenas no TF operacional para confirmar ║
//║        tendência LOCAL (Supertrend = linha azul/vermelha)       ║
//╚══════════════════════════════════════════════════════════════════╝

input group "=== 📈 SUPERTREND (Trend Magic Operacional) - Tendência Local ==="
input int    ST_OPER_CCI_Period       = 50;    // CCI Period
input int    ST_OPER_ATR_Period       = 5;     // ATR Period
input double ST_OPER_ATR_Multiplier   = 1.0;   // ATR Multiplier

//╔══════════════════════════════════════════════════════════════════╗
//║              💱 CURRENCY STRENGTH - APENAS OPERACIONAL           ║
//║  (Analisa força das moedas, não depende de timeframe macro)     ║
//╚══════════════════════════════════════════════════════════════════╝

input group "=== 💱 CURRENCY STRENGTH - OPERACIONAL ==="
input int    CS_CalculationPeriod     = 24;    // Período de cálculo
input int    CS_SmoothingPeriod       = 5;     // Período de suavização
input bool   CS_ShowInPercent         = true;  // Exibir em porcentagem

//╔══════════════════════════════════════════════════════════════════╗
//║              📊 RSI OMA - APENAS OPERACIONAL (Força Relativa)    ║
//║                                                                  ║
//║  NOTA: GG TrendBar valida alinhamento macro em TODOS os TFs     ║
//║        RSI OMA usado apenas no TF operacional para confirmar    ║
//║        FORÇA do movimento (linha vermelha vs azul + inclinação) ║
//╚══════════════════════════════════════════════════════════════════╝

input group "=== 📊 RSI OMA (Operacional) - Força Relativa ==="
input int              RSI_OPER_Period      = 14;        // RSI Period
input int              RSI_OPER_MA_Period   = 9;         // Moving Average Period
input ENUM_MA_METHOD   RSI_OPER_MA_Method   = MODE_SMA;  // MA Method
input double           RSI_OPER_HighLevel   = 70.0;      // High Level (sobrecompra)
input double           RSI_OPER_LowLevel    = 30.0;      // Low Level (sobrevenda)
input bool             RSI_OPER_ShowLevels  = true;      // Show Levels

//╔══════════════════════════════════════════════════════════════════╗
//║              💥 WAE - APENAS OPERACIONAL (Momentum/Explosão)     ║
//║                                                                  ║
//║  NOTA: GG TrendBar valida alinhamento macro em TODOS os TFs     ║
//║        WAE usado apenas no TF operacional para confirmar        ║
//║        MOMENTUM (histograma verde/vermelho acima linha amarela) ║
//╚══════════════════════════════════════════════════════════════════╝

input group "=== 💥 WAE (Operacional) - Momentum ==="
input int    WAE_OPER_FastMA          = 20;    // Fast MA Period
input int    WAE_OPER_SlowMA          = 40;    // Slow MA Period
input int    WAE_OPER_BBLength        = 20;    // Bollinger Bands Length
input double WAE_OPER_BBMultiplier    = 2.0;   // Bollinger Bands Multiplier
input int    WAE_OPER_Sensitivity     = 150;   // Sensitivity

//╔══════════════════════════════════════════════════════════════════╗
//║              📊 GG TRENDBAR - GLOBAL (Interno Multi-TF)          ║
//║  (Indicador analisa todos os timeframes internamente)           ║
//╚══════════════════════════════════════════════════════════════════╝

input group "=== 📊 GG TRENDBAR - GLOBAL ==="
input color              GG_UpColor       = clrLime;      // Up Trend Color
input color              GG_DownColor     = clrRed;       // Down Trend Color
input color              GG_FlatColor     = clrYellow;    // Flat/Neutral Color
input color              GG_TextColor     = clrAqua;      // Text Color
input ENUM_BASE_CORNER   GG_Corner        = CORNER_LEFT_UPPER; // Corner for Display
input bool               GG_CreateVisualObjects = true;   // Create Visual Objects
input int                GG_ADX_Period = 14;           // ADX Period
input ENUM_APPLIED_PRICE GG_ADX_Price  = PRICE_CLOSE;  // Price Type
input double             GG_Step_Psar  = 0.02;         // PSAR Step
input double             GG_Max_Psar   = 0.20;         // PSAR Maximum

input group "════════════════════════════════════════════════════════"
input group "  �️ LIMITES DE VALIDAÇÃO (ANTI-HARDCODE)             "
input group "════════════════════════════════════════════════════════"
// 🔥 v4.36: TODOS os limites de validação agora são INPUTS configuráveis!
// ❌ PROIBIDO usar valores hardcoded nas validações
// ✅ OBRIGATÓRIO: Tudo via parâmetros
input double MaxAccountRiskPercent     = 10.0;   // 📊 Máximo risco % conta permitido
input double MaxRiskPremiumLimit       = 10.0;   // 💎 Máximo risco % premium permitido
input int    MaxSimultaneousTradesLimit = 10;    // 🔢 Máximo trades simultâneos permitido
input double MaxSL_BufferPoints        = 1000.0; // 📏 Máximo buffer SL (pontos)
input double MaxSL_FallbackPercent     = 10.0;   // 📉 Máximo SL fallback %
input double MaxSL_DistancePoints      = 10000.0;// 📊 Máximo distância SL (pontos)
input double MaxSL_MaxDistanceLimit    = 50000.0;// 📊 Limite superior SL_MaxDistancePoints
input double MaxTP_RR                  = 50.0;   // 🎯 Máximo Risk/Reward permitido (TP1/TP2/TP3)
input double MinTP_RR                  = 0.1;    // 🎯 Mínimo Risk/Reward permitido
input double MaxTP_ClosePercent        = 100.0;  // 📊 Máximo % fechamento em TP
input double MaxTrailingDistancePoints = 10000.0;// 📈 Máximo trailing distance (pontos)
input double MaxTrailingActivationRR   = 10.0;   // 🎯 Máximo RR para ativar trailing
input double MinTrailingATRMultiplier  = 0.1;    // 📊 Mínimo multiplicador ATR trailing
input double MaxTrailingATRMultiplier  = 10.0;   // 📊 Máximo multiplicador ATR trailing
input int    MaxPauseTimeSeconds       = 43200;  // ⏰ Tempo máximo de pausa (12h = 43200s)
input double MaxATRVariation           = 3.0;    // 📊 Máxima variação ATR tolerada (300%)
input double MinVolatilityPips         = 1.0;    // 📊 Mínima volatilidade em pips
input double MaxVolatilityPips         = 50.0;   // 📊 Máxima volatilidade em pips
input int    LogWarningIntervalSeconds = 900;    // ⏰ Intervalo entre warnings (15min = 900s)
input int    SessionStartMarginMinutes = 15;     // ⏰ Margem início de sessão (minutos)

input group "════════════════════════════════════════════════════════"
input group "  �🔐 IDENTIFICAÇÃO DO EA                              "
input group "════════════════════════════════════════════════════════"
input int    EA_MAGIC_NUMBER = 20241015;  // 🔐 Magic Number (único por instância!)

input group "════════════════════════════════════════════════════════"
input group "     ✅ FIM DOS PARÂMETROS - TOTAL: 90+ INPUTS         "
input group "════════════════════════════════════════════════════════"

//+------------------------------------------------------------------+
//| CONSTANTES GLOBAIS                                               |
//+------------------------------------------------------------------+
const string EA_VERSION = "4.31";    // 🔥 v4.31: CORREÇÕES CRÍTICAS ANÁLISE (WR 34.5%→50%+, DD 929%→<200%)
const string EA_NAME         = "Nexus Confluence Universal Multi-TF";

//+------------------------------------------------------------------+
