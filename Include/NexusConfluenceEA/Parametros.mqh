//+------------------------------------------------------------------+
//| Parametros.mqh - VERSÃO SIMPLIFICADA                             |
//| Nexus Confluence EA v4.44 - Sistema Básico Corrigido            |
//|                                                                   |
//| PROPÓSITO: Inputs básicos - sem gestão de risco complexa        |
//|                                                                   |
//| 🔥 v4.44: CORREÇÃO CRÍTICA - VALIDAÇÃO TF OPERACIONAL            |
//|   - PROBLEMA: M15 operacional nunca validado no macro           |
//|   - CORREÇÃO: Adicionado campo operationalAligned na struct     |
//|   - CORREÇÃO: Adicionado campo classification na struct         |
//|   - IMPACTO: EA não abrirá mais trades contra TF operacional    |
//|                                                                   |
//| AUTOR: GitHub Copilot + Desenvolvedor                            |
//| DATA: Outubro 2025                                               |
//| VERSÃO: 4.44 - CORREÇÃO CRÍTICA                                 |
//+------------------------------------------------------------------+
#property copyright "Nexus Confluence EA v4.44"
#property version   "4.44"

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
   bool            isValid;             // Análise válida?
   TRADE_DIRECTION direction;           // Direção do alinhamento
   bool            h4Aligned;           // MACRO-1 alinhado (representação abstrata)
   bool            h1Aligned;           // MACRO-2 alinhado
   bool            m30Aligned;          // MACRO-3 alinhado (se aplicável)
   bool            operationalAligned;  // 🔥 v4.44: TF OPERACIONAL alinhado (CRÍTICO!)
   bool            structureValid;      // Estrutura de preços válida?
   SETUP_CLASS     classification;      // 🔥 v4.44: Classificação (PREMIUM/GOOD) definida aqui
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
//| SEÇÃO 3: INPUTS SIMPLIFICADOS DO EA v4.40                        |
//+------------------------------------------------------------------+

input group "════════════════════════════════════════════════════════"
input group "     🎯 NEXUS CONFLUENCE v4.40 - SIMPLIFICADO          "
input group "════════════════════════════════════════════════════════"

input group "=== 📅 FILTRO SEMANAL - Dias da Semana ==="
input bool   TradeOnMonday            = true;  // 📅 Operar na Segunda-feira
input bool   TradeOnTuesday           = true;  // 📅 Operar na Terça-feira
input bool   TradeOnWednesday         = true;  // 📅 Operar na Quarta-feira
input bool   TradeOnThursday          = true;  // 📅 Operar na Quinta-feira
input bool   TradeOnFriday            = true;  // 📅 Operar na Sexta-feira
input bool   TradeOnSaturday          = false; // 📅 Operar no Sábado (Cripto 24/7)
input bool   TradeOnSunday            = false; // 📅 Operar no Domingo (Cripto 24/7)

input group "=== ⏰ HORÁRIOS DE OPERAÇÃO ==="
input bool   UseCustomTradingHours    = true;  // ⏰ Usar horários customizados
input int    CustomStartHour          = 9;     // ⏰ Horário início (hora)
input int    CustomStartMinute        = 0;     // ⏰ Horário início (minuto)
input int    CustomEndHour            = 17;    // ⏰ Horário fim (hora)
input int    CustomEndMinute          = 0;     // ⏰ Horário fim (minuto)

input group "=== ⚠️ STOP LOSS FIXO (em pontos/pips) ==="
input double SL_Points                = 100.0; // 📏 Stop Loss em pontos (Forex: 100 pts = 10 pips | B3: 100 pts)

input group "=== 🎯 TAKE PROFIT FIXO (em pontos/pips) ==="
input double TP_Points                = 200.0; // 🎯 Take Profit em pontos (Forex: 200 pts = 20 pips | B3: 200 pts)

input group "=== 💰 LOTE FIXO ==="
input double FixedLotSize             = 0.01;  // 📌 Lote Fixo (Forex: 0.01 | B3: 1.0 | Índices: 0.1)

input group "=== � INDICADORES - Caminhos dos Arquivos ==="
input string IndicatorsBasePath       = "NexusConfluenceEA\\"; // 📂 Pasta relativa em MQL5/Indicators
input string GGTrendBarIndicator      = "GG_TrendBar_Indicator";
input string TrendMagicIndicator      = "TrendMagic_MT5";
input string CurrencyStrengthIndicator= "CurrencyStrengthMeter_MT5";
input string RSIOMAIndicator          = "RSIOMA_v2HHLSX_MT5";
input string WAEIndicator             = "WaddahAttarExplosion_Professional";

input group "=== 📈 SUPERTREND (Trend Magic Operacional) ==="
input int    ST_OPER_CCI_Period       = 50;    // CCI Period
input int    ST_OPER_ATR_Period       = 5;     // ATR Period
input double ST_OPER_ATR_Multiplier   = 1.0;   // ATR Multiplier

input group "=== 💱 CURRENCY STRENGTH - OPERACIONAL ==="
input int    CS_CalculationPeriod     = 24;    // Período de cálculo
input int    CS_SmoothingPeriod       = 5;     // Período de suavização
input bool   CS_ShowInPercent         = true;  // Exibir em porcentagem

input group "=== 📊 RSI OMA (Operacional) ==="
input int              RSI_OPER_Period      = 14;        // RSI Period
input int              RSI_OPER_MA_Period   = 9;         // Moving Average Period
input ENUM_MA_METHOD   RSI_OPER_MA_Method   = MODE_SMA;  // MA Method
input double           RSI_OPER_HighLevel   = 70.0;      // High Level (sobrecompra)
input double           RSI_OPER_LowLevel    = 30.0;      // Low Level (sobrevenda)
input bool             RSI_OPER_ShowLevels  = true;      // Show Levels

input group "=== 💥 WAE (Operacional) ==="
input int    WAE_OPER_FastMA          = 20;    // Fast MA Period
input int    WAE_OPER_SlowMA          = 40;    // Slow MA Period
input int    WAE_OPER_BBLength        = 20;    // Bollinger Bands Length
input double WAE_OPER_BBMultiplier    = 2.0;   // Bollinger Bands Multiplier
input int    WAE_OPER_Sensitivity     = 150;   // Sensitivity

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

input group "=== 🔐 IDENTIFICAÇÃO ==="
input int    EA_MAGIC_NUMBER          = 20241024; // 🔐 Magic Number (único por instância!)

input group "=== 🔧 CONFIGURAÇÕES AVANÇADAS (ANTI-HARDCODE) ==="
// Execução de Ordens
input int    MaxSlippagePoints            = 30;          // 🔧 Slippage Máximo (pontos)
input ENUM_ORDER_TYPE_FILLING OrderFillingMode = ORDER_FILLING_FOK;  // 🔧 Modo de Preenchimento

// Controle de Qualidade de Setups (✅ v4.40.1: RESTAURADO)
input bool   AllowGoodSetups              = true;        // 🎯 Permitir setups GOOD (se false: apenas PREMIUM)
input bool   UseStrictFilters             = false;       // 🎯 Exigir TODOS filtros alinhados (3/3 ou 2/2)
input bool   RequireSupertrend            = false;       // 🎯 Exigir Supertrend alinhado obrigatoriamente
input int    MinConfluenceScore           = 70;          // 🎯 Score mínimo de confluência (0-100)

// Lógica de Score e Classificação
input int    MinMacroSignalsForAlignment  = 2;           // 🔧 Mín Sinais Macro Alinhados (de 3)
input int    MinScoreForexGood            = 2;           // 🔧 Score Mín FOREX GOOD (de 3)
input int    MinScoreForexPremium         = 3;           // 🔧 Score Mín FOREX PREMIUM (de 3)
input int    MinScoreIndexGood            = 2;           // 🔧 Score Mín ÍNDICE GOOD (de 2)
input int    MinScoreIndexPremium         = 2;           // 🔧 Score Mín ÍNDICE PREMIUM (de 2)
input bool   RequireM30ForPremium         = true;        // 🔧 Exigir M30 alinhado para PREMIUM?

// Robustez e Logging
input int    MaxConsecutiveIndicatorErrors = 10;         // 🔧 Máx Erros Consecutivos de Indicadores
input int    LogWarningIntervalCount       = 100;        // 🔧 Intervalo de Avisos no Log (contagem)

input group "════════════════════════════════════════════════════════"
input group "          ✅ FIM DOS PARÂMETROS SIMPLIFICADOS           "
input group "════════════════════════════════════════════════════════"

//+------------------------------------------------------------------+
//| CONSTANTES GLOBAIS                                               |
//+------------------------------------------------------------------+
const string EA_VERSION = "4.40";    // 🔥 v4.40: SIMPLIFICAÇÃO RADICAL
const string EA_NAME    = "Nexus Confluence Basic";

//+------------------------------------------------------------------+
//| NOTA: Variáveis globais g_handles e g_tfOperacional             |
//|       já estão declaradas em Estrategias.mqh                    |
//+------------------------------------------------------------------+
