//+------------------------------------------------------------------+
//| Nexus Confluence EA v4.0 - Sistema Universal de Trading          |
//| Baseado no Sistema de Trading Profissional v4.0                  |
//|                                                                  |
//| Descrição: Expert Advisor completo que implementa sistema        |
//| multi-ativo com gestão de risco baseada em estrutura             |
//|                                                                  |
//| Autor: GitHub Copilot                                            |
//| Data: Outubro 2025                                               |
//| Versão: 4.0                                                      |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| ARQUIVO: NexusConfluenceEA.mq5                                   |
//| PROPÓSITO: Execução automatizada do Sistema Nexus Confluence     |
//| DEPENDÊNCIAS: Indicators/NexusConfluenceEA/*.mq5                 |
//| VERSÃO: 4.0                                                      |
//+------------------------------------------------------------------+
#property strict

#include <Trade\Trade.mqh>

//--- Constantes globais
input group "=== CONFIGURAÇÕES GERAIS ==="
input double AccountRiskPercent       = 1.5;   // Risco padrão (setup BOM)
input double MaxRiskPremium           = 2.0;   // Risco máximo setup PREMIUM
input double MaxDrawdownPercent       = 15.0;  // Drawdown máximo permitido (%)
input int    MaxSimultaneousTrades    = 3;     // Máximo de trades simultâneos
input bool   EnableSecondaryHours     = true;  // Habilitar horários secundários Forex
input bool   EnableMorningB3          = false; // Habilitar sessão da manhã B3
input bool   AvoidNews                = true;  // Evitar operar em notícias
input bool   ValidateATRRange         = true;  // Validar ATR por ativo
input bool   SendAlerts               = true;  // Enviar notificações push
input bool   EnablePartialTP          = true;  // Habilitar saídas parciais
input bool   EnableTrailing           = true;  // Habilitar trailing stop
input double TP1_RR                   = 1.0;   // RR para realização parcial 1
input double TP2_RR                   = 2.0;   // RR para realização parcial 2
input double TrailingDistanceMultiplier = 1.0; // Multiplicador distância trailing
input int    MaxSlippagePoints        = 30;    // Desvio máximo em pontos
input int    LookbackStructureBars    = 80;    // Candles para buscar estrutura M15
input int    BrokerGMTOffset          = 2;     // Fuso horário do broker (horário de inverno)

input group "=== TREND MAGIC - PARÂMETROS ==="
input int    TM_CCI_Period            = 50;
input int    TM_ATR_Period            = 5;
input double TM_ATR_Multiplier        = 1.0;

input group "=== CURRENCY STRENGTH - PARÂMETROS ==="
input int    CS_CalculationPeriod     = 24;
input int    CS_SmoothingPeriod       = 5;
input bool   CS_ShowInPercent         = true;

input group "=== RSI OMA - PARÂMETROS ==="
input int         RSI_Period          = 14;
input int         RSI_MA_Period       = 9;
input ENUM_MA_METHOD RSI_MA_Method    = MODE_SMA;
input double      RSI_HighLevel       = 70.0;
input double      RSI_LowLevel        = 30.0;
input bool        RSI_ShowLevels      = true;

input group "=== WAE - PARÂMETROS ==="
input int    WAE_FastMA               = 20;
input int    WAE_SlowMA               = 40;
input int    WAE_BBLength             = 20;
input double WAE_BBMultiplier         = 2.0;
input int    WAE_Sensitivity          = 150;

input group "=== GG TRENDBAR - PARÂMETROS ==="
input int    GG_ADX_Period            = 14;           // ADX period
input ENUM_APPLIED_PRICE GG_ADX_Price = PRICE_CLOSE;  // Price for PSAR comparison
input double GG_Step_Psar             = 0.02;         // PSAR step
input double GG_Max_Psar              = 0.20;         // PSAR maximum

input group "=== INDICADORES - NOMES DOS ARQUIVOS ==="
input string IndicatorsBasePath       = "NexusConfluenceEA\\"; // Pasta relativa em MQL5/Indicators
input string GGTrendBarIndicator      = "GG_TrendBar_Indicator";
input string TrendMagicIndicator      = "TrendMagic_MT5";
input string CurrencyStrengthIndicator= "CurrencyStrengthMeter_MT5";
input string RSIOMAIndicator          = "RSIOMA_v2HHLSX_MT5";
input string WAEIndicator             = "WaddahAttarExplosion_Professional";

//--- Enumeradores do sistema
enum TRADE_DIRECTION
  {
   TRADE_DIRECTION_NONE = -1,
   TRADE_DIRECTION_BUY  = 0,
   TRADE_DIRECTION_SELL = 1
  };

enum SETUP_CLASS
  {
   SETUP_REJECT = 0,
   SETUP_GOOD   = 1,
   SETUP_PREMIUM= 2
  };

enum ASSET_CLASS
  {
   ASSET_CLASS_UNKNOWN = 0,
   ASSET_CLASS_FOREX_MAJOR,
   ASSET_CLASS_FOREX_MINOR,
   ASSET_CLASS_FOREX_EXOTIC,
   ASSET_CLASS_CURRENCY_B3,
   ASSET_CLASS_INDEX_B3,
   ASSET_CLASS_INDEX_US,
   ASSET_CLASS_INDEX_EU,
   ASSET_CLASS_METALS,
   ASSET_CLASS_CRYPTO,
   ASSET_CLASS_TOTAL
  };

//--- Estruturas de dados
struct TMSignal
  {
   bool            isValid;
   TRADE_DIRECTION direction;
   double          strength;
   ENUM_TIMEFRAMES timeframe;
   bool            turnedRecently;
  };

struct CSSignal
  {
   bool  isValid;
   bool  isAligned;
   double strength;
  };

struct RSISignal
  {
   bool  isValid;
   bool  isAligned;
   double strength;
   double slope;
  };

struct WAESignal
  {
   bool  isValid;
   bool  isAligned;
   bool  isExpanding;
   double strength;
  };

struct GGTrendBarSignal
  {
   bool            isValid;
   int             m1Value;      // +1 bullish, 0 neutral, -1 bearish
   int             m5Value;
   int             m15Value;
   int             m30Value;
   int             h1Value;
   int             h4Value;
   int             d1Value;
   int             w1Value;
   int             mn1Value;
   bool            h4Bullish;
   bool            h1Bullish;
   bool            m30Bullish;
   bool            m15Bullish;
   TRADE_DIRECTION overallDirection;
  };

struct MultiTFResult
  {
   bool            isValid;
   TRADE_DIRECTION direction;
   bool            h4Aligned;
   bool            h1Aligned;
   bool            m30Aligned;
   bool            structureValid;
  };

struct SetupScore
  {
   SETUP_CLASS classification;
   int         requiredPoints;
   int         totalPoints;
   int         traderMagicPoints;
   int         currencyStrengthPoints;
   int         rsiomaPoints;
   int         waePoints;
   TRADE_DIRECTION direction;
  };

struct RiskCalculation
  {
   bool            isValid;
   string          errorMessage;
   TRADE_DIRECTION direction;
   SETUP_CLASS     classification;
   double          entryPrice;
   double          stopLoss;
   double          slDistance;
   double          positionSize;
   double          riskAmount;
   double          tp1;
   double          tp2;
   double          trailingStart;
  };

struct AssetConfig
  {
   bool   useCurrencyStrength;
   int    requiredFilters;
   int    minFiltersForTrade;
   double idealSLMinPips;
   double idealSLMaxPips;
   double slBufferPips;
   double minATR;
   double maxATR;
   double maxSpreadPips;
   double trailingDistancePips;
   double pipValueOverride;
   int    primeHourStart;
   int    primeHourEnd;
   double premiumRiskPercent;
   double goodRiskPercent;
  };

struct IndicatorHandles
  {
   int tm_h4;
   int tm_h1;
   int tm_m30;
   int tm_m15;
   int cs_m15;
   int rsi_h4;
   int rsi_h1;
   int rsi_m30;
   int rsi_m15;
   int wae_h4;
   int wae_h1;
   int wae_m30;
   int wae_m15;
  };

struct TradeRecord
  {
   datetime        openTime;
   datetime        closeTime;
   string          symbol;
   TRADE_DIRECTION direction;
   double          openPrice;
   double          closePrice;
   double          profit;
   double          riskAmount;
   double          rr;
   SETUP_CLASS     setupClass;
   string          closeReason;
   bool            tp1Hit;
   bool            tp2Hit;
  };

//--- Variáveis globais
const int    EA_MAGIC_NUMBER = 20241015;
const string EA_VERSION      = "4.0";
const string EA_NAME         = "Nexus Confluence Universal";

CTrade g_trade;
double g_initialBalance = 0.0;
bool   g_tradingPaused  = false;
int    g_lastReportMonth = -1;
int    g_lastCleanupDay  = -1;

double g_pointValueCache = 0.0;

//--- Forward declarations de classes
class CAssetManager;
class CIndicatorManager;
class CTimeFrameAnalyzer;
class CSetupScorer;
class CRiskManager;
class CTradeManager;
class CHoursManager;
class CStatistics;
class CProtectionSystem;

//--- Prototipagem de funções auxiliares
string  BoolToText(const bool value);
string  ComposeIndicatorPath(const string fileName);
double  ConvertPipsToPrice(const string symbol,const double pips);
double  ConvertPriceToPips(const string symbol,const double priceDistance);
string  SetupClassToString(const SETUP_CLASS cls);
string  DirectionToString(const TRADE_DIRECTION dir);
void    CleanupOldLogs();
void    ValidateSystemIntegrity();

//--- Classes principais
class CAssetManager
  {
private:
   AssetConfig m_configs[ASSET_CLASS_TOTAL];
public:
   CAssetManager()
     {
      InitializeConfigs();
     }

   ASSET_CLASS ClassifyAsset(const string symbol) const
     {
  string sym = symbol;
  StringToUpper(sym);

      if(sym == "XAUUSD" || sym == "XAGUSD" || StringFind(sym,"XAU") == 0 || StringFind(sym,"XAG") == 0)
         return ASSET_CLASS_METALS;

      if(StringFind(sym,"WIN") == 0 || StringFind(sym,"IND") == 0)
         return ASSET_CLASS_INDEX_B3;

      if(StringFind(sym,"WDO") == 0 || StringFind(sym,"DOL") == 0)
         return ASSET_CLASS_CURRENCY_B3;

      if(StringFind(sym,"US500") == 0 || StringFind(sym,"NAS100") == 0 || StringFind(sym,"US30") == 0)
         return ASSET_CLASS_INDEX_US;

      if(StringFind(sym,"GER") == 0 || StringFind(sym,"UK") == 0 || StringFind(sym,"FRA") == 0)
         return ASSET_CLASS_INDEX_EU;

      if(StringFind(sym,"BTC") == 0 || StringFind(sym,"ETH") == 0)
         return ASSET_CLASS_CRYPTO;

      if(StringLen(sym) >= 6)
        {
         string base = StringSubstr(sym,0,3);
         string quote = StringSubstr(sym,3,3);
         if(StringFind(sym,"USD") >= 0)
           {
            if((base == "EUR" && quote == "USD") ||
               (base == "GBP" && quote == "USD") ||
               (base == "USD" && (quote == "JPY" || quote == "CHF")) ||
               (base == "AUD" && quote == "USD") ||
               (base == "NZD" && quote == "USD") ||
               (base == "USD" && quote == "CAD"))
               return ASSET_CLASS_FOREX_MAJOR;

            if(StringFind(sym,"BRL") >= 0 || StringFind(sym,"MXN") >= 0 || StringFind(sym,"ZAR") >= 0)
               return ASSET_CLASS_FOREX_EXOTIC;

            return ASSET_CLASS_FOREX_MINOR;
           }
         else if(IsAlphabet(base) && IsAlphabet(quote))
           {
            return ASSET_CLASS_FOREX_MINOR;
           }
        }

      return ASSET_CLASS_UNKNOWN;
     }

   bool GetConfig(const ASSET_CLASS cls, AssetConfig &config) const
     {
      int index = (int)cls;
      if(index <= (int)ASSET_CLASS_UNKNOWN || index >= (int)ASSET_CLASS_TOTAL)
         return false;
      config = m_configs[index];
      return true;
     }

   bool IsAssetSupported(const ASSET_CLASS cls) const
     {
      return (cls != ASSET_CLASS_UNKNOWN && cls < ASSET_CLASS_TOTAL);
     }

private:
   static bool IsAlphabet(const string txt)
     {
      for(int i=0; i<StringLen(txt); ++i)
        {
         ushort ch = StringGetCharacter(txt,i);
         if(ch < 'A' || ch > 'Z')
            return false;
        }
      return true;
     }

   void InitializeConfigs()
     {
      for(int i=0; i<ASSET_CLASS_TOTAL; ++i)
        {
         m_configs[i].useCurrencyStrength = false;
         m_configs[i].requiredFilters     = 2;
         m_configs[i].minFiltersForTrade  = 2;
         m_configs[i].idealSLMinPips      = 20;
         m_configs[i].idealSLMaxPips      = 40;
         m_configs[i].slBufferPips        = 5;
         m_configs[i].minATR              = 0;
         m_configs[i].maxATR              = 1000;
         m_configs[i].maxSpreadPips       = 5;
         m_configs[i].trailingDistancePips= 20;
         m_configs[i].pipValueOverride    = 0;
         m_configs[i].primeHourStart      = 1000;
         m_configs[i].primeHourEnd        = 1400;
         m_configs[i].premiumRiskPercent  = MaxRiskPremium;
         m_configs[i].goodRiskPercent     = AccountRiskPercent;
        }

  m_configs[ASSET_CLASS_FOREX_MAJOR].useCurrencyStrength = true;
  m_configs[ASSET_CLASS_FOREX_MAJOR].requiredFilters     = 3;
  m_configs[ASSET_CLASS_FOREX_MAJOR].minFiltersForTrade  = 2;
  m_configs[ASSET_CLASS_FOREX_MAJOR].idealSLMinPips      = 20;
  m_configs[ASSET_CLASS_FOREX_MAJOR].idealSLMaxPips      = 45;
  m_configs[ASSET_CLASS_FOREX_MAJOR].slBufferPips        = 5;
  m_configs[ASSET_CLASS_FOREX_MAJOR].minATR              = 15;
  m_configs[ASSET_CLASS_FOREX_MAJOR].maxATR              = 50;
  m_configs[ASSET_CLASS_FOREX_MAJOR].maxSpreadPips       = 2;
  m_configs[ASSET_CLASS_FOREX_MAJOR].trailingDistancePips= 25;
  m_configs[ASSET_CLASS_FOREX_MAJOR].primeHourStart      = 1000;
  m_configs[ASSET_CLASS_FOREX_MAJOR].primeHourEnd        = 1400;

  m_configs[ASSET_CLASS_FOREX_MINOR].useCurrencyStrength = true;
  m_configs[ASSET_CLASS_FOREX_MINOR].requiredFilters     = 3;
  m_configs[ASSET_CLASS_FOREX_MINOR].minFiltersForTrade  = 2;
  m_configs[ASSET_CLASS_FOREX_MINOR].idealSLMinPips      = 25;
  m_configs[ASSET_CLASS_FOREX_MINOR].idealSLMaxPips      = 50;
  m_configs[ASSET_CLASS_FOREX_MINOR].slBufferPips        = 7;
  m_configs[ASSET_CLASS_FOREX_MINOR].minATR              = 20;
  m_configs[ASSET_CLASS_FOREX_MINOR].maxATR              = 60;
  m_configs[ASSET_CLASS_FOREX_MINOR].maxSpreadPips       = 3;
  m_configs[ASSET_CLASS_FOREX_MINOR].trailingDistancePips= 30;
  m_configs[ASSET_CLASS_FOREX_MINOR].primeHourStart      = 1000;
  m_configs[ASSET_CLASS_FOREX_MINOR].primeHourEnd        = 1400;

  m_configs[ASSET_CLASS_FOREX_EXOTIC].useCurrencyStrength = true;
  m_configs[ASSET_CLASS_FOREX_EXOTIC].requiredFilters     = 3;
  m_configs[ASSET_CLASS_FOREX_EXOTIC].minFiltersForTrade  = 2;
  m_configs[ASSET_CLASS_FOREX_EXOTIC].idealSLMinPips      = 40;
  m_configs[ASSET_CLASS_FOREX_EXOTIC].idealSLMaxPips      = 90;
  m_configs[ASSET_CLASS_FOREX_EXOTIC].slBufferPips        = 15;
  m_configs[ASSET_CLASS_FOREX_EXOTIC].minATR              = 25;
  m_configs[ASSET_CLASS_FOREX_EXOTIC].maxATR              = 120;
  m_configs[ASSET_CLASS_FOREX_EXOTIC].maxSpreadPips       = 15;
  m_configs[ASSET_CLASS_FOREX_EXOTIC].trailingDistancePips= 45;
  m_configs[ASSET_CLASS_FOREX_EXOTIC].primeHourStart      = 1000;
  m_configs[ASSET_CLASS_FOREX_EXOTIC].primeHourEnd        = 1400;

  m_configs[ASSET_CLASS_CURRENCY_B3].useCurrencyStrength = true;
  m_configs[ASSET_CLASS_CURRENCY_B3].requiredFilters     = 3;
  m_configs[ASSET_CLASS_CURRENCY_B3].minFiltersForTrade  = 2;
  m_configs[ASSET_CLASS_CURRENCY_B3].idealSLMinPips      = 15;
  m_configs[ASSET_CLASS_CURRENCY_B3].idealSLMaxPips      = 35;
  m_configs[ASSET_CLASS_CURRENCY_B3].slBufferPips        = 5;
  m_configs[ASSET_CLASS_CURRENCY_B3].minATR              = 10;
  m_configs[ASSET_CLASS_CURRENCY_B3].maxATR              = 40;
  m_configs[ASSET_CLASS_CURRENCY_B3].maxSpreadPips       = 3;
  m_configs[ASSET_CLASS_CURRENCY_B3].trailingDistancePips= 30;
  m_configs[ASSET_CLASS_CURRENCY_B3].primeHourStart      = 1400;
  m_configs[ASSET_CLASS_CURRENCY_B3].primeHourEnd        = 1600;

  m_configs[ASSET_CLASS_INDEX_B3].useCurrencyStrength = false;
  m_configs[ASSET_CLASS_INDEX_B3].requiredFilters     = 2;
  m_configs[ASSET_CLASS_INDEX_B3].minFiltersForTrade  = 2;
  m_configs[ASSET_CLASS_INDEX_B3].idealSLMinPips      = 200;
  m_configs[ASSET_CLASS_INDEX_B3].idealSLMaxPips      = 450;
  m_configs[ASSET_CLASS_INDEX_B3].slBufferPips        = 50;
  m_configs[ASSET_CLASS_INDEX_B3].minATR              = 200;
  m_configs[ASSET_CLASS_INDEX_B3].maxATR              = 600;
  m_configs[ASSET_CLASS_INDEX_B3].maxSpreadPips       = 15;
  m_configs[ASSET_CLASS_INDEX_B3].trailingDistancePips= 300;
  m_configs[ASSET_CLASS_INDEX_B3].primeHourStart      = 1400;
  m_configs[ASSET_CLASS_INDEX_B3].primeHourEnd        = 1600;

  m_configs[ASSET_CLASS_INDEX_US].useCurrencyStrength = false;
  m_configs[ASSET_CLASS_INDEX_US].requiredFilters     = 2;
  m_configs[ASSET_CLASS_INDEX_US].minFiltersForTrade  = 2;
  m_configs[ASSET_CLASS_INDEX_US].idealSLMinPips      = 15;
  m_configs[ASSET_CLASS_INDEX_US].idealSLMaxPips      = 40;
  m_configs[ASSET_CLASS_INDEX_US].slBufferPips        = 5;
  m_configs[ASSET_CLASS_INDEX_US].minATR              = 8;
  m_configs[ASSET_CLASS_INDEX_US].maxATR              = 25;
  m_configs[ASSET_CLASS_INDEX_US].maxSpreadPips       = 3;
  m_configs[ASSET_CLASS_INDEX_US].trailingDistancePips= 30;
  m_configs[ASSET_CLASS_INDEX_US].primeHourStart      = 1130;
  m_configs[ASSET_CLASS_INDEX_US].primeHourEnd        = 1800;

  m_configs[ASSET_CLASS_INDEX_EU].useCurrencyStrength = false;
  m_configs[ASSET_CLASS_INDEX_EU].requiredFilters     = 2;
  m_configs[ASSET_CLASS_INDEX_EU].minFiltersForTrade  = 2;
  m_configs[ASSET_CLASS_INDEX_EU].idealSLMinPips      = 15;
  m_configs[ASSET_CLASS_INDEX_EU].idealSLMaxPips      = 40;
  m_configs[ASSET_CLASS_INDEX_EU].slBufferPips        = 5;
  m_configs[ASSET_CLASS_INDEX_EU].minATR              = 8;
  m_configs[ASSET_CLASS_INDEX_EU].maxATR              = 25;
  m_configs[ASSET_CLASS_INDEX_EU].maxSpreadPips       = 3;
  m_configs[ASSET_CLASS_INDEX_EU].trailingDistancePips= 25;
  m_configs[ASSET_CLASS_INDEX_EU].primeHourStart      = 500;
  m_configs[ASSET_CLASS_INDEX_EU].primeHourEnd        = 900;

  m_configs[ASSET_CLASS_METALS].useCurrencyStrength = true;
  m_configs[ASSET_CLASS_METALS].requiredFilters     = 3;
  m_configs[ASSET_CLASS_METALS].minFiltersForTrade  = 2;
  m_configs[ASSET_CLASS_METALS].idealSLMinPips      = 5;
  m_configs[ASSET_CLASS_METALS].idealSLMaxPips      = 15;
  m_configs[ASSET_CLASS_METALS].slBufferPips        = 1.5;
  m_configs[ASSET_CLASS_METALS].minATR              = 4;
  m_configs[ASSET_CLASS_METALS].maxATR              = 15;
  m_configs[ASSET_CLASS_METALS].maxSpreadPips       = 1;
  m_configs[ASSET_CLASS_METALS].trailingDistancePips= 12;
  m_configs[ASSET_CLASS_METALS].primeHourStart      = 500;
  m_configs[ASSET_CLASS_METALS].primeHourEnd        = 1400;

  m_configs[ASSET_CLASS_CRYPTO].useCurrencyStrength = false;
  m_configs[ASSET_CLASS_CRYPTO].requiredFilters     = 2;
  m_configs[ASSET_CLASS_CRYPTO].minFiltersForTrade  = 2;
  m_configs[ASSET_CLASS_CRYPTO].idealSLMinPips      = 150;
  m_configs[ASSET_CLASS_CRYPTO].idealSLMaxPips      = 400;
  m_configs[ASSET_CLASS_CRYPTO].slBufferPips        = 30;
  m_configs[ASSET_CLASS_CRYPTO].minATR              = 80;
  m_configs[ASSET_CLASS_CRYPTO].maxATR              = 300;
  m_configs[ASSET_CLASS_CRYPTO].maxSpreadPips       = 10;
  m_configs[ASSET_CLASS_CRYPTO].trailingDistancePips= 180;
  m_configs[ASSET_CLASS_CRYPTO].primeHourStart      = 0;
  m_configs[ASSET_CLASS_CRYPTO].primeHourEnd        = 2359;
     }
  };

//--- Gerenciador de horários globais
class CHoursManager
  {
public:
   bool IsValidTradingTime(const ASSET_CLASS assetClass) const
     {
      MqlDateTime serverTime;
      TimeToStruct(TimeCurrent(),serverTime);
      int brazilTime = ConvertToBrazilTime(serverTime);

      switch(assetClass)
        {
         case ASSET_CLASS_FOREX_MAJOR:
         case ASSET_CLASS_FOREX_MINOR:
         case ASSET_CLASS_FOREX_EXOTIC:
         case ASSET_CLASS_METALS:
            return IsForexTime(brazilTime);

         case ASSET_CLASS_CURRENCY_B3:
         case ASSET_CLASS_INDEX_B3:
            return IsB3Time(brazilTime);

         case ASSET_CLASS_INDEX_US:
            return IsUsIndexTime(brazilTime);

         case ASSET_CLASS_INDEX_EU:
            return IsEuIndexTime(brazilTime);

         case ASSET_CLASS_CRYPTO:
            return true; // 24/7

         default:
            return false;
        }
     }

private:
   static int ConvertToBrazilTime(const MqlDateTime &serverTime)
     {
      int offset = BrokerGMTOffset;

      datetime dtServer = StructToTime(serverTime);
      datetime dtBrazil = dtServer - (offset + 3) * 3600; // Broker . GMT, depois GMT . Brasil
      MqlDateTime dt;
      TimeToStruct(dtBrazil,dt);
      return dt.hour * 100 + dt.min;
     }

   static bool InRange(const int value,const int start,const int end)
     {
      if(start <= end)
         return (value >= start && value <= end);
      return (value >= start || value <= end);
     }

   bool IsForexTime(const int brazilTime) const
     {
      if(InRange(brazilTime,1000,1400))
         return true;
      if(EnableSecondaryHours && InRange(brazilTime,500,930))
         return true;
      if(InRange(brazilTime,2200,2359) || InRange(brazilTime,0,200))
         return false;
      return false;
     }

   bool IsB3Time(const int brazilTime) const
     {
      if(!InRange(brazilTime,930,1730))
         return false;
      if(InRange(brazilTime,1400,1600))
         return true;
      if(EnableMorningB3 && InRange(brazilTime,930,1130))
         return true;
      return false;
     }

   bool IsUsIndexTime(const int brazilTime) const
     {
      return InRange(brazilTime,1130,1800);
     }

   bool IsEuIndexTime(const int brazilTime) const
     {
      if(InRange(brazilTime,500,900))
         return true;
      if(InRange(brazilTime,1130,1330))
         return true;
      return false;
     }
  };

//--- Classes de indicadores específicos
//--- GG TrendBar - Indicador Multi-Timeframe Principal
class CGGTrendBar
  {
private:
   int      m_handle;
   string   m_symbol;
   bool     m_initialized;

public:
   CGGTrendBar():m_initialized(false),m_handle(INVALID_HANDLE){}

   bool Initialize(const string symbol)
     {
      m_symbol = symbol;
      string path = ComposeIndicatorPath(GGTrendBarIndicator);
      
      // IMPORTANTE: Passar CreateVisualObjects=false para evitar duplicação
      // O EA criará seus próprios objetos visuais no canto direito
      m_handle = iCustom(symbol, PERIOD_M1, path, 
                         clrLime,              // UpColor
                         clrRed,               // DownColor
                         clrYellow,            // FlatColor
                         clrAqua,              // TextColor
                         CORNER_LEFT_UPPER,    // Corner (não usado, mas necessário)
                         false,                // CreateVisualObjects = FALSE!
                         GG_ADX_Period,        // ADX_Period
                         GG_ADX_Price,         // ADX_Price
                         GG_Step_Psar,         // Step_Psar
                         GG_Max_Psar);         // Max_Psar
                         
      if(m_handle == INVALID_HANDLE)
        {
         Print("[GG_TrendBar] Falha ao criar handle");
         m_initialized = false;
         return false;
        }
        
      m_initialized = true;
      Print("[GG_TrendBar] Inicializado com sucesso - Visual objects disabled");
      return true;
     }

   void Release()
     {
      if(m_handle != INVALID_HANDLE)
         IndicatorRelease(m_handle);
      m_initialized = false;
     }

   bool GetSignal(GGTrendBarSignal &signal) const
     {
      signal.isValid = false;
      
      if(m_handle == INVALID_HANDLE)
         return false;

      // Buffers do GG_TrendBar:
      // 0=M1, 1=M5, 2=M15, 3=M30, 4=H1, 5=H4, 6=D1, 7=W1, 8=MN1
      // Valores: +1 (bullish), 0 (neutral), -1 (bearish)
      
      double m1[1], m5[1], m15[1], m30[1], h1[1], h4[1], d1[1], w1[1], mn1[1];
      
      // Copiar valores de todos os timeframes
      if(CopyBuffer(m_handle, 0, 0, 1, m1) != 1 ||
         CopyBuffer(m_handle, 1, 0, 1, m5) != 1 ||
         CopyBuffer(m_handle, 2, 0, 1, m15) != 1 ||
         CopyBuffer(m_handle, 3, 0, 1, m30) != 1 ||
         CopyBuffer(m_handle, 4, 0, 1, h1) != 1 ||
         CopyBuffer(m_handle, 5, 0, 1, h4) != 1 ||
         CopyBuffer(m_handle, 6, 0, 1, d1) != 1 ||
         CopyBuffer(m_handle, 7, 0, 1, w1) != 1 ||
         CopyBuffer(m_handle, 8, 0, 1, mn1) != 1)
        {
         Print("[GG_TrendBar] Erro ao copiar buffers");
         return false;
        }

      // Preencher estrutura de sinal
      signal.m1Value  = (int)m1[0];
      signal.m5Value  = (int)m5[0];
      signal.m15Value = (int)m15[0];
      signal.m30Value = (int)m30[0];
      signal.h1Value  = (int)h1[0];
      signal.h4Value  = (int)h4[0];
      signal.d1Value  = (int)d1[0];
      signal.w1Value  = (int)w1[0];
      signal.mn1Value = (int)mn1[0];

      // Determinar direção booleana para timeframes principais
      signal.h4Bullish  = (signal.h4Value == 1);
      signal.h1Bullish  = (signal.h1Value == 1);
      signal.m30Bullish = (signal.m30Value == 1);
      signal.m15Bullish = (signal.m15Value == 1);

      // Determinar direção geral (baseada em H4 como diretor)
      if(signal.h4Value == 1)
         signal.overallDirection = TRADE_DIRECTION_BUY;
      else if(signal.h4Value == -1)
         signal.overallDirection = TRADE_DIRECTION_SELL;
      else
         signal.overallDirection = TRADE_DIRECTION_NONE;

      signal.isValid = true;
      return true;
     }

   // Verificar alinhamento multi-timeframe (H4 + H1 obrigatório)
   bool IsMultiTFAligned(const GGTrendBarSignal &signal, bool &isPremium) const
     {
      isPremium = false;
      
      if(!signal.isValid)
         return false;

      // H4 e H1 devem estar alinhados (mesma direção não-neutra)
      if(signal.h4Value == 0 || signal.h1Value == 0)
         return false; // Neutro = aguardar
         
      if(signal.h4Value != signal.h1Value)
         return false; // Cores opostas = rejeitado

      // Setup BOM: H4 + H1 alinhados
      bool goodSetup = true;
      
      // Setup PREMIUM: H4 + H1 + M30 alinhados
      if(signal.m30Value == signal.h4Value)
         isPremium = true;

      return goodSetup;
     }
  };

//+------------------------------------------------------------------+
//| Classe para gerenciar objetos visuais do GG_TrendBar             |
//+------------------------------------------------------------------+
class CVisualManager
  {
private:
   string m_timeframes[9];
   color  m_upColor;
   color  m_downColor;
   color  m_flatColor;
   int    m_corner;

public:
   CVisualManager()
     {
      // Inicializar timeframes
      m_timeframes[0] = "M1";
      m_timeframes[1] = "M5";
      m_timeframes[2] = "M15";
      m_timeframes[3] = "M30";
      m_timeframes[4] = "H1";
      m_timeframes[5] = "H4";
      m_timeframes[6] = "D1";
      m_timeframes[7] = "W1";
      m_timeframes[8] = "MN1";
      
      // Cores padrão (podem ser configuradas)
      m_upColor = clrLime;
      m_downColor = clrRed;
      m_flatColor = clrYellow;
      m_corner = CORNER_RIGHT_UPPER;
     }

   // Criar objetos visuais do GG_TrendBar
   void CreateGGTrendBarVisuals()
     {
      // PRIMEIRO: Deletar objetos criados pelo indicador original (se existirem)
      DeleteOriginalIndicatorObjects();
      
      // Criar headers dos timeframes
      for(int i = 0; i < 9; i++)
        {
         string label_name = "EA_TF_" + m_timeframes[i];
         
         if(ObjectFind(0, label_name) >= 0)
            ObjectDelete(0, label_name);
         
         if(ObjectCreate(0, label_name, OBJ_LABEL, 0, 0, 0))
           {
            ObjectSetInteger(0, label_name, OBJPROP_CORNER, m_corner);
            ObjectSetInteger(0, label_name, OBJPROP_XDISTANCE, i * 40 + 15);
            ObjectSetInteger(0, label_name, OBJPROP_YDISTANCE, 20);
            ObjectSetInteger(0, label_name, OBJPROP_BACK, false);
            ObjectSetInteger(0, label_name, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, label_name, OBJPROP_HIDDEN, false);
            ObjectSetString(0, label_name, OBJPROP_TEXT, m_timeframes[i]);
            ObjectSetString(0, label_name, OBJPROP_FONT, "Tahoma");
            ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, 8);
            ObjectSetInteger(0, label_name, OBJPROP_COLOR, clrWhite);
           }
        }
      
      // Criar indicadores (quadrados coloridos)
      for(int i = 0; i < 9; i++)
        {
         string ind_name = "EA_Ind_" + IntegerToString(i);
         
         if(ObjectFind(0, ind_name) >= 0)
            ObjectDelete(0, ind_name);
         
         if(ObjectCreate(0, ind_name, OBJ_LABEL, 0, 0, 0))
           {
            ObjectSetInteger(0, ind_name, OBJPROP_CORNER, m_corner);
            ObjectSetInteger(0, ind_name, OBJPROP_XDISTANCE, i * 40 + 15);
            ObjectSetInteger(0, ind_name, OBJPROP_YDISTANCE, 35);
            ObjectSetInteger(0, ind_name, OBJPROP_BACK, false);
            ObjectSetInteger(0, ind_name, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, ind_name, OBJPROP_HIDDEN, false);
            ObjectSetString(0, ind_name, OBJPROP_TEXT, "n"); // Wingdings 'n' = quadrado
            ObjectSetString(0, ind_name, OBJPROP_FONT, "Wingdings");
            ObjectSetInteger(0, ind_name, OBJPROP_FONTSIZE, 12);
            ObjectSetInteger(0, ind_name, OBJPROP_COLOR, m_flatColor); // Inicialmente amarelo
           }
        }
      
      ChartRedraw(0);
      Print("[VisualManager] GG_TrendBar objetos visuais criados no canto superior direito");
     }

   // Deletar objetos criados pelo indicador original
   void DeleteOriginalIndicatorObjects()
     {
      // Deletar headers do indicador original (sem prefix "EA_")
      for(int i = 0; i < 9; i++)
        {
         string label_name = "TF_" + m_timeframes[i];
         if(ObjectFind(0, label_name) >= 0)
           {
            ObjectDelete(0, label_name);
            Print("[VisualManager] Removido objeto duplicado: ", label_name);
           }
        }
      
      // Deletar indicadores do indicador original
      for(int i = 0; i < 9; i++)
        {
         string ind_name = "Ind_" + IntegerToString(i);
         if(ObjectFind(0, ind_name) >= 0)
           {
            ObjectDelete(0, ind_name);
            Print("[VisualManager] Removido objeto duplicado: ", ind_name);
           }
        }
      
      ChartRedraw(0);
     }

   // Atualizar cores dos indicadores com base nos valores
   void UpdateGGTrendBarColors(const GGTrendBarSignal &signal)
     {
      if(!signal.isValid)
         return;
      
      int values[9];
      values[0] = signal.m1Value;
      values[1] = signal.m5Value;
      values[2] = signal.m15Value;
      values[3] = signal.m30Value;
      values[4] = signal.h1Value;
      values[5] = signal.h4Value;
      values[6] = signal.d1Value;
      values[7] = signal.w1Value;
      values[8] = signal.mn1Value;
      
      for(int i = 0; i < 9; i++)
        {
         string ind_name = "EA_Ind_" + IntegerToString(i);
         
         if(ObjectFind(0, ind_name) >= 0)
           {
            color trend_color = m_flatColor;
            
            if(values[i] == 1)
               trend_color = m_upColor;    // Verde - bullish
            else if(values[i] == -1)
               trend_color = m_downColor;  // Vermelho - bearish
            else
               trend_color = m_flatColor;  // Amarelo - neutro
            
            ObjectSetInteger(0, ind_name, OBJPROP_COLOR, trend_color);
           }
        }
      
      ChartRedraw(0);
     }

   // Remover todos os objetos visuais
   void RemoveAllVisuals()
     {
      // Remover headers do EA
      for(int i = 0; i < 9; i++)
        {
         string label_name = "EA_TF_" + m_timeframes[i];
         if(ObjectFind(0, label_name) >= 0)
            ObjectDelete(0, label_name);
        }
      
      // Remover indicadores do EA
      for(int i = 0; i < 9; i++)
        {
         string ind_name = "EA_Ind_" + IntegerToString(i);
         if(ObjectFind(0, ind_name) >= 0)
            ObjectDelete(0, ind_name);
        }
      
      // Remover também objetos do indicador original (caso existam)
      DeleteOriginalIndicatorObjects();
      
      ChartRedraw(0);
      Print("[VisualManager] Objetos visuais removidos");
     }

   // Anexar indicadores ao gráfico usando abordagem correta
   bool AttachIndicatorsToChart()
     {
      long chartID = ChartID();
      bool allSuccess = true;
      
      Print("============================================================");
      Print("[VisualManager] Iniciando anexação de indicadores...");
      Print("============================================================");
      
      // 1. SUPERTREND - Gráfico Principal (Window 0)
      string superTrendPath = "NexusConfluenceEA\\" + TrendMagicIndicator;
      Print("[VisualManager] Tentando anexar SuperTrend: ", superTrendPath);
      
      int tempHandle = iCustom(_Symbol, PERIOD_CURRENT, superTrendPath, 
                               TM_CCI_Period, TM_ATR_Period, TM_ATR_Multiplier);
      
      if(tempHandle != INVALID_HANDLE)
        {
         // Adicionar ao gráfico principal (window 0)
         int window = ChartIndicatorAdd(chartID, 0, tempHandle);
         if(window == 0)
           {
            Print("[VisualManager] ✅ SuperTrend anexado ao gráfico principal (window 0)");
           }
         else
           {
            Print("[VisualManager] ❌ Erro ao anexar SuperTrend. Window retornada: ", window, " Erro: ", GetLastError());
            allSuccess = false;
           }
        }
      else
        {
         Print("[VisualManager] ❌ Erro ao criar handle SuperTrend: ", GetLastError());
         allSuccess = false;
        }
      
      // Pequeno delay para garantir processamento
      Sleep(100);
      
      // 2. RSI OMA - Nova Subjanela (forçar criação de window 1)
      string rsiPath = "NexusConfluenceEA\\" + RSIOMAIndicator;
      Print("[VisualManager] Tentando anexar RSI OMA: ", rsiPath);
      
      tempHandle = iCustom(_Symbol, PERIOD_CURRENT, rsiPath,
                          RSI_Period, RSI_MA_Period, RSI_MA_Method, 
                          RSI_HighLevel, RSI_LowLevel, RSI_ShowLevels);
      
      if(tempHandle != INVALID_HANDLE)
        {
         // Forçar nova subjanela usando número de janelas atuais + 1
         long totalWindows = ChartGetInteger(chartID, CHART_WINDOWS_TOTAL);
         int window = ChartIndicatorAdd(chartID, (int)totalWindows, tempHandle);
         
         if(window > 0)
           {
            Print("[VisualManager] ✅ RSI OMA anexado em subjanela ", window);
           }
         else
           {
            Print("[VisualManager] ❌ Erro ao anexar RSI OMA. Window retornada: ", window, " Erro: ", GetLastError());
            allSuccess = false;
           }
        }
      else
        {
         Print("[VisualManager] ❌ Erro ao criar handle RSI OMA: ", GetLastError());
         allSuccess = false;
        }
      
      // Pequeno delay para garantir processamento
      Sleep(100);
      
      // 3. WAE - Nova Subjanela (forçar criação de window 2)
      string waePath = "NexusConfluenceEA\\" + WAEIndicator;
      Print("[VisualManager] Tentando anexar WAE: ", waePath);
      
      tempHandle = iCustom(_Symbol, PERIOD_CURRENT, waePath,
                          WAE_FastMA, WAE_SlowMA, WAE_BBLength, 
                          WAE_BBMultiplier, WAE_Sensitivity);
      
      if(tempHandle != INVALID_HANDLE)
        {
         // Forçar nova subjanela usando número de janelas atuais + 1
         long totalWindows = ChartGetInteger(chartID, CHART_WINDOWS_TOTAL);
         int window = ChartIndicatorAdd(chartID, (int)totalWindows, tempHandle);
         
         if(window > 0)
           {
            Print("[VisualManager] ✅ WAE anexado em subjanela ", window);
           }
         else
           {
            Print("[VisualManager] ❌ Erro ao anexar WAE. Window retornada: ", window, " Erro: ", GetLastError());
            allSuccess = false;
           }
        }
      else
        {
         Print("[VisualManager] ❌ Erro ao criar handle WAE: ", GetLastError());
         allSuccess = false;
        }
      
      ChartRedraw(chartID);
      
      Print("============================================================");
      if(allSuccess)
         Print("[VisualManager] ✅ TODOS os indicadores anexados com sucesso!");
      else
         Print("[VisualManager] ⚠️ Alguns indicadores tiveram problemas na anexação");
      Print("============================================================");
      
      return allSuccess;
     }
  };

class CTraderMagic
  {
private:
   IndicatorHandles  m_handles;
   string            m_symbol;
   bool              m_initialized;
public:
   CTraderMagic():m_initialized(false)
     {
      m_handles.tm_h4 = INVALID_HANDLE;
      m_handles.tm_h1 = INVALID_HANDLE;
      m_handles.tm_m30 = INVALID_HANDLE;
      m_handles.tm_m15 = INVALID_HANDLE;
     }

   bool Initialize(const string symbol)
     {
      m_symbol = symbol;
      string path = ComposeIndicatorPath(TrendMagicIndicator);
      m_handles.tm_h4  = iCustom(symbol,PERIOD_H4,path,TM_CCI_Period,TM_ATR_Period,TM_ATR_Multiplier);
      m_handles.tm_h1  = iCustom(symbol,PERIOD_H1,path,TM_CCI_Period,TM_ATR_Period,TM_ATR_Multiplier);
      m_handles.tm_m30 = iCustom(symbol,PERIOD_M30,path,TM_CCI_Period,TM_ATR_Period,TM_ATR_Multiplier);
      m_handles.tm_m15 = iCustom(symbol,PERIOD_M15,path,TM_CCI_Period,TM_ATR_Period,TM_ATR_Multiplier);

      if(m_handles.tm_h4 == INVALID_HANDLE || m_handles.tm_h1 == INVALID_HANDLE ||
         m_handles.tm_m30 == INVALID_HANDLE || m_handles.tm_m15 == INVALID_HANDLE)
        {
         Print("[TraderMagic] Falha ao criar handles");
         m_initialized = false;
         return false;
        }
      m_initialized = true;
      return true;
     }

   void Release()
     {
      if(m_handles.tm_h4 != INVALID_HANDLE) IndicatorRelease(m_handles.tm_h4);
      if(m_handles.tm_h1 != INVALID_HANDLE) IndicatorRelease(m_handles.tm_h1);
      if(m_handles.tm_m30 != INVALID_HANDLE) IndicatorRelease(m_handles.tm_m30);
      if(m_handles.tm_m15 != INVALID_HANDLE) IndicatorRelease(m_handles.tm_m15);
      m_initialized = false;
     }

   bool GetSignal(const ENUM_TIMEFRAMES timeframe,TMSignal &signal) const
     {
      signal.isValid   = false;
      signal.direction = TRADE_DIRECTION_NONE;
      signal.strength  = 0.0;
      signal.timeframe = timeframe;
      signal.turnedRecently = false;

      int handle = GetHandle(timeframe);
      if(handle == INVALID_HANDLE)
         return false;

      double bufferUp[5];
      double bufferDn[5];
      ArrayInitialize(bufferUp,EMPTY_VALUE);
      ArrayInitialize(bufferDn,EMPTY_VALUE);

      if(CopyBuffer(handle,0,0,5,bufferUp) != 5)
         return false;
      if(CopyBuffer(handle,1,0,5,bufferDn) != 5)
         return false;

      bool isUp    = (bufferUp[0] != EMPTY_VALUE);
      bool wasDown = (bufferDn[1] != EMPTY_VALUE || bufferDn[2] != EMPTY_VALUE);
      bool isDown  = (bufferDn[0] != EMPTY_VALUE);
      bool wasUp   = (bufferUp[1] != EMPTY_VALUE || bufferUp[2] != EMPTY_VALUE);

      if(isUp)
        {
         signal.direction = TRADE_DIRECTION_BUY;
         signal.strength  = MathAbs(bufferUp[0] - (bufferDn[0] == EMPTY_VALUE ? bufferUp[0] : bufferDn[0]));
         signal.isValid   = true;
         signal.turnedRecently = wasDown;
        }
      else if(isDown)
        {
         signal.direction = TRADE_DIRECTION_SELL;
         signal.strength  = MathAbs(bufferDn[0] - (bufferUp[0] == EMPTY_VALUE ? bufferDn[0] : bufferUp[0]));
         signal.isValid   = true;
         signal.turnedRecently = wasUp;
        }

      return signal.isValid;
     }

private:
   int GetHandle(const ENUM_TIMEFRAMES timeframe) const
     {
      switch(timeframe)
        {
         case PERIOD_H4:  return m_handles.tm_h4;
         case PERIOD_H1:  return m_handles.tm_h1;
         case PERIOD_M30: return m_handles.tm_m30;
         case PERIOD_M15: return m_handles.tm_m15;
         default:         return INVALID_HANDLE;
        }
     }
  };

class CCurrencyStrength
  {
private:
   IndicatorHandles  m_handles;
   string            m_symbol;
   bool              m_initialized;
public:
   CCurrencyStrength():m_initialized(false)
     {
      m_handles.cs_m15 = INVALID_HANDLE;
     }

   bool Initialize(const string symbol)
     {
      m_symbol = symbol;
      string path = ComposeIndicatorPath(CurrencyStrengthIndicator);
      m_handles.cs_m15 = iCustom(symbol,PERIOD_M15,path,CS_CalculationPeriod,CS_SmoothingPeriod,CS_ShowInPercent);
      if(m_handles.cs_m15 == INVALID_HANDLE)
        {
         Print("[CurrencyStrength] Falha ao criar handle");
         m_initialized = false;
         return false;
        }
      m_initialized = true;
      return true;
     }

   void Release()
     {
      if(m_handles.cs_m15 != INVALID_HANDLE) IndicatorRelease(m_handles.cs_m15);
      m_initialized = false;
     }

   CSSignal GetSignal(const bool isBuy,const ASSET_CLASS assetType) const
     {
      CSSignal result;
      result.isValid   = false;
      result.isAligned = false;
      result.strength  = 0.0;

      if(m_handles.cs_m15 == INVALID_HANDLE)
         return result;

      if(!(assetType == ASSET_CLASS_FOREX_MAJOR || assetType == ASSET_CLASS_FOREX_MINOR ||
           assetType == ASSET_CLASS_FOREX_EXOTIC || assetType == ASSET_CLASS_CURRENCY_B3 ||
           assetType == ASSET_CLASS_METALS))
        {
         return result;
        }

      double base[3];
      double quote[3];
    if(CopyBuffer(m_handles.cs_m15,0,0,3,base) != 3)
         return result;
    if(CopyBuffer(m_handles.cs_m15,1,0,3,quote) != 3)
         return result;

      double baseStrength  = base[0];
      double quoteStrength = quote[0];

      if(assetType == ASSET_CLASS_METALS)
        {
         result.isAligned = (isBuy ? (quoteStrength < baseStrength) : (quoteStrength > baseStrength));
        }
      else
        {
         result.isAligned = (isBuy ? (baseStrength > quoteStrength) : (baseStrength < quoteStrength));
        }

      result.strength = MathAbs(baseStrength - quoteStrength);
      result.isValid  = true;
      return result;
     }
  };

class CRSIOMA
  {
private:
   IndicatorHandles  m_handles;
   bool              m_initialized;
public:
   CRSIOMA():m_initialized(false)
     {
      m_handles.rsi_h4 = INVALID_HANDLE;
      m_handles.rsi_h1 = INVALID_HANDLE;
      m_handles.rsi_m30 = INVALID_HANDLE;
      m_handles.rsi_m15 = INVALID_HANDLE;
     }

   bool Initialize(const string symbol)
     {
      string path = ComposeIndicatorPath(RSIOMAIndicator);
      m_handles.rsi_h4  = iCustom(symbol,PERIOD_H4,path,RSI_Period,RSI_MA_Period,RSI_MA_Method,RSI_HighLevel,RSI_LowLevel,RSI_ShowLevels);
      m_handles.rsi_h1  = iCustom(symbol,PERIOD_H1,path,RSI_Period,RSI_MA_Period,RSI_MA_Method,RSI_HighLevel,RSI_LowLevel,RSI_ShowLevels);
      m_handles.rsi_m30 = iCustom(symbol,PERIOD_M30,path,RSI_Period,RSI_MA_Period,RSI_MA_Method,RSI_HighLevel,RSI_LowLevel,RSI_ShowLevels);
      m_handles.rsi_m15 = iCustom(symbol,PERIOD_M15,path,RSI_Period,RSI_MA_Period,RSI_MA_Method,RSI_HighLevel,RSI_LowLevel,RSI_ShowLevels);

      if(m_handles.rsi_h4 == INVALID_HANDLE || m_handles.rsi_h1 == INVALID_HANDLE ||
         m_handles.rsi_m30 == INVALID_HANDLE || m_handles.rsi_m15 == INVALID_HANDLE)
        {
         Print("[RSIOMA] Falha ao criar handles");
         m_initialized = false;
         return false;
        }
      m_initialized = true;
      return true;
     }

   void Release()
     {
      if(m_handles.rsi_h4 != INVALID_HANDLE) IndicatorRelease(m_handles.rsi_h4);
      if(m_handles.rsi_h1 != INVALID_HANDLE) IndicatorRelease(m_handles.rsi_h1);
      if(m_handles.rsi_m30 != INVALID_HANDLE) IndicatorRelease(m_handles.rsi_m30);
      if(m_handles.rsi_m15 != INVALID_HANDLE) IndicatorRelease(m_handles.rsi_m15);
      m_initialized = false;
     }

   bool GetSignal(const ENUM_TIMEFRAMES timeframe,const bool isBuy,RSISignal &signal) const
     {
      signal.isValid   = false;
      signal.isAligned = false;
      signal.strength  = 0.0;
      signal.slope     = 0.0;

      int handle = GetHandle(timeframe);
      if(handle == INVALID_HANDLE)
         return false;

      double rsi[4];
      double rsiMa[4];
      if(CopyBuffer(handle,0,0,4,rsi) != 4)
         return false;
      if(CopyBuffer(handle,1,0,4,rsiMa) != 4)
         return false;

      double currentRSI = rsi[0];
      double currentMA  = rsiMa[0];
      double prevRSI    = rsi[2];

      bool redAboveBlue = (currentRSI > currentMA);
      double slope      = (rsi[0] - rsi[3]) / 3.0;

      signal.isValid = true;
      signal.slope   = slope;
      signal.strength = MathAbs(rsi[0] - rsiMa[0]);

      if(isBuy)
         signal.isAligned = redAboveBlue && slope > 0.05;
      else
         signal.isAligned = !redAboveBlue && slope < -0.05;

      return true;
     }

private:
   int GetHandle(const ENUM_TIMEFRAMES timeframe) const
     {
      switch(timeframe)
        {
         case PERIOD_H4:  return m_handles.rsi_h4;
         case PERIOD_H1:  return m_handles.rsi_h1;
         case PERIOD_M30: return m_handles.rsi_m30;
         case PERIOD_M15: return m_handles.rsi_m15;
         default:         return INVALID_HANDLE;
        }
     }
  };

class CWAE
  {
private:
   IndicatorHandles  m_handles;
   bool              m_initialized;
public:
   CWAE():m_initialized(false)
     {
      m_handles.wae_h4 = INVALID_HANDLE;
      m_handles.wae_h1 = INVALID_HANDLE;
      m_handles.wae_m30 = INVALID_HANDLE;
      m_handles.wae_m15 = INVALID_HANDLE;
     }

   bool Initialize(const string symbol)
     {
      string path = ComposeIndicatorPath(WAEIndicator);
      m_handles.wae_h4  = iCustom(symbol,PERIOD_H4,path,WAE_FastMA,WAE_SlowMA,WAE_BBLength,WAE_BBMultiplier,WAE_Sensitivity);
      m_handles.wae_h1  = iCustom(symbol,PERIOD_H1,path,WAE_FastMA,WAE_SlowMA,WAE_BBLength,WAE_BBMultiplier,WAE_Sensitivity);
      m_handles.wae_m30 = iCustom(symbol,PERIOD_M30,path,WAE_FastMA,WAE_SlowMA,WAE_BBLength,WAE_BBMultiplier,WAE_Sensitivity);
      m_handles.wae_m15 = iCustom(symbol,PERIOD_M15,path,WAE_FastMA,WAE_SlowMA,WAE_BBLength,WAE_BBMultiplier,WAE_Sensitivity);

      if(m_handles.wae_h4 == INVALID_HANDLE || m_handles.wae_h1 == INVALID_HANDLE ||
         m_handles.wae_m30 == INVALID_HANDLE || m_handles.wae_m15 == INVALID_HANDLE)
        {
         Print("[WAE] Falha ao criar handles");
         m_initialized = false;
         return false;
        }
      m_initialized = true;
      return true;
     }

   void Release()
     {
      if(m_handles.wae_h4 != INVALID_HANDLE) IndicatorRelease(m_handles.wae_h4);
      if(m_handles.wae_h1 != INVALID_HANDLE) IndicatorRelease(m_handles.wae_h1);
      if(m_handles.wae_m30 != INVALID_HANDLE) IndicatorRelease(m_handles.wae_m30);
      if(m_handles.wae_m15 != INVALID_HANDLE) IndicatorRelease(m_handles.wae_m15);
      m_initialized = false;
     }

   bool GetSignal(const ENUM_TIMEFRAMES timeframe,const bool isBuy,WAESignal &signal) const
     {
      signal.isValid   = false;
      signal.isAligned = false;
      signal.isExpanding = false;
      signal.strength  = 0.0;

      int handle = GetHandle(timeframe);
      if(handle == INVALID_HANDLE)
         return false;

      double bufUp[4];
      double bufDn[4];
      double bufExplosion[4];

      if(CopyBuffer(handle,0,0,4,bufUp) != 4)
         return false;
      if(CopyBuffer(handle,1,0,4,bufDn) != 4)
         return false;
      if(CopyBuffer(handle,2,0,4,bufExplosion) != 4)
         return false;

      double currentTrend = (bufUp[0] > 0 ? bufUp[0] : -bufDn[0]);
      double prevTrend    = (bufUp[1] > 0 ? bufUp[1] : -bufDn[1]);
      bool   isGreen      = (bufUp[0] > 0);

      bool expanding = (MathAbs(currentTrend) > MathAbs(prevTrend) && MathAbs(prevTrend) > MathAbs((bufUp[2] > 0 ? bufUp[2] : -bufDn[2])));
      double minForce = bufExplosion[0];

      signal.isValid    = true;
      signal.isExpanding= expanding;
      signal.strength   = MathAbs(currentTrend);

      if(isBuy)
         signal.isAligned = (isGreen && expanding && signal.strength > minForce);
      else
         signal.isAligned = (!isGreen && expanding && signal.strength > minForce);

      return true;
     }

private:
   int GetHandle(const ENUM_TIMEFRAMES timeframe) const
     {
      switch(timeframe)
        {
         case PERIOD_H4:  return m_handles.wae_h4;
         case PERIOD_H1:  return m_handles.wae_h1;
         case PERIOD_M30: return m_handles.wae_m30;
         case PERIOD_M15: return m_handles.wae_m15;
         default:         return INVALID_HANDLE;
        }
     }
  };

//--- Gerenciador geral de indicadores
class CIndicatorManager
  {
private:
   string           m_symbol;
   CGGTrendBar      m_ggTrendBar;
   CTraderMagic     m_traderMagic;
   CCurrencyStrength m_currencyStrength;
   CRSIOMA          m_rsi;
   CWAE             m_wae;
   CVisualManager   m_visualManager;

public:
   bool Initialize(const string symbol)
     {
      m_symbol = symbol;

      bool ok = m_ggTrendBar.Initialize(symbol);
      ok = m_traderMagic.Initialize(symbol) && ok;
      ok = m_currencyStrength.Initialize(symbol) && ok;
      ok = m_rsi.Initialize(symbol) && ok;
      ok = m_wae.Initialize(symbol) && ok;
      
      if(!ok)
        {
         Print("[CIndicatorManager] Erro ao inicializar indicadores base");
         return false;
        }
      
      // PRIMEIRO: Deletar objetos duplicados do GG_TrendBar
      m_visualManager.DeleteOriginalIndicatorObjects();
      
      // SEGUNDO: Criar objetos visuais do GG_TrendBar (EA gerencia)
      m_visualManager.CreateGGTrendBarVisuals();
      
      // TERCEIRO: Anexar outros indicadores ao gráfico
      bool indicatorsAttached = m_visualManager.AttachIndicatorsToChart();
      
      if(!indicatorsAttached)
        {
         Print("[CIndicatorManager] ⚠️ Atenção: Alguns indicadores não foram anexados automaticamente");
         Print("[CIndicatorManager] Verifique os logs acima para instruções manuais");
        }
      
      return ok;
     }

   void Release()
     {
      m_ggTrendBar.Release();
      m_traderMagic.Release();
      m_currencyStrength.Release();
      m_rsi.Release();
      m_wae.Release();
      
      // Remover objetos visuais
      m_visualManager.RemoveAllVisuals();
     }
   
   // Atualizar visualização do GG_TrendBar
   void UpdateVisuals(const GGTrendBarSignal &signal)
     {
      m_visualManager.UpdateGGTrendBarColors(signal);
     }

   bool GetGGTrendBarSignal(GGTrendBarSignal &signal) const
     {
      return m_ggTrendBar.GetSignal(signal);
     }

   bool IsMultiTFAligned(const GGTrendBarSignal &signal, bool &isPremium) const
     {
      return m_ggTrendBar.IsMultiTFAligned(signal, isPremium);
     }

   bool GetTraderMagicSignal(const ENUM_TIMEFRAMES timeframe,TMSignal &signal) const
     {
      return m_traderMagic.GetSignal(timeframe,signal);
     }

   CSSignal GetCurrencyStrengthSignal(const bool isBuy,const ASSET_CLASS assetType) const
     {
      return m_currencyStrength.GetSignal(isBuy,assetType);
     }

   bool GetRSISignal(const ENUM_TIMEFRAMES timeframe,const bool isBuy,RSISignal &signal) const
     {
      return m_rsi.GetSignal(timeframe,isBuy,signal);
     }

   bool GetWAESignal(const ENUM_TIMEFRAMES timeframe,const bool isBuy,WAESignal &signal) const
     {
      return m_wae.GetSignal(timeframe,isBuy,signal);
     }
  };

//--- Analisador multi-timeframe
class CTimeFrameAnalyzer
  {
private:
   CIndicatorManager *m_indicatorManager;
   CAssetManager     *m_assetManager;
public:
   CTimeFrameAnalyzer():m_indicatorManager(NULL),m_assetManager(NULL){}

   void Attach(CIndicatorManager *ind,CAssetManager *assets)
     {
      m_indicatorManager = ind;
      m_assetManager     = assets;
     }

   MultiTFResult Analyze(const string symbol,const ASSET_CLASS assetType) const
     {
      MultiTFResult result;
      result.isValid = false;
      result.structureValid = false;
      result.direction = TRADE_DIRECTION_NONE;
      result.h4Aligned = result.h1Aligned = result.m30Aligned = false;

      if(m_indicatorManager == NULL)
         return result;

      // USAR GG_TrendBar como fonte principal de análise multi-timeframe
      GGTrendBarSignal ggSignal;
      if(!(*m_indicatorManager).GetGGTrendBarSignal(ggSignal))
        {
         Print("[MTF] Erro ao obter sinal GG_TrendBar");
         return result;
        }

      if(!ggSignal.isValid)
        {
         Print("[MTF] GG_TrendBar sinal inválido");
         return result;
        }

      // Verificar alinhamento H4 + H1 (obrigatório)
      bool isPremium = false;
      if(!(*m_indicatorManager).IsMultiTFAligned(ggSignal, isPremium))
        {
         Print("[MTF] Timeframes não alinhados - H4:", ggSignal.h4Value, " H1:", ggSignal.h1Value);
         return result;
        }

      // Definir direção baseada no H4 (timeframe diretor)
      result.direction = ggSignal.overallDirection;
      result.h4Aligned = true;
      result.h1Aligned = true;
      result.m30Aligned = isPremium; // M30 alinhado = setup premium

      Print("[MTF] Alinhamento confirmado - Dir:", result.direction, 
            " H4:", ggSignal.h4Value, " H1:", ggSignal.h1Value, 
            " M30:", ggSignal.m30Value, " Premium:", isPremium);

      // Validar estrutura de preços no H4
      result.structureValid = ValidateStructure(symbol, result.direction);
      result.isValid = result.structureValid;
      
      return result;
     }

private:
   bool ValidateStructure(const string symbol,const TRADE_DIRECTION direction) const
     {
    const int bars = 80;
    double highs[];
    double lows[];
    ArraySetAsSeries(highs,true);
    ArraySetAsSeries(lows,true);

    if(CopyHigh(symbol,PERIOD_H4,1,bars,highs) != bars)
         return false;
    if(CopyLow(symbol,PERIOD_H4,1,bars,lows) != bars)
         return false;

    if(bars <= 10)
      return false;

      if(direction == TRADE_DIRECTION_BUY)
        {
         double highestRecent = highs[0];
         double lowestRecent  = lows[0];
         for(int i=1; i<bars; ++i)
           {
            highestRecent = MathMax(highestRecent,highs[i]);
            lowestRecent  = MathMin(lowestRecent,lows[i]);
           }
         bool higherHighs = (highs[0] >= highs[5] && highs[5] >= highs[10]);
         bool higherLows  = (lows[0] >= lows[5] && lows[5] >= lows[10]);
         return (higherHighs && higherLows);
        }
      else if(direction == TRADE_DIRECTION_SELL)
        {
         bool lowerHighs = (highs[0] <= highs[5] && highs[5] <= highs[10]);
         bool lowerLows  = (lows[0] <= lows[5] && lows[5] <= lows[10]);
         return (lowerHighs && lowerLows);
        }

      return false;
     }
  };

//--- Sistema de pontuação de setups
class CSetupScorer
  {
private:
   CIndicatorManager *m_indicatorManager;
   CAssetManager     *m_assetManager;
public:
   CSetupScorer():m_indicatorManager(NULL),m_assetManager(NULL){}

   void Attach(CIndicatorManager *ind,CAssetManager *assets)
     {
      m_indicatorManager = ind;
      m_assetManager     = assets;
     }

   SetupScore Evaluate(const string symbol,const ASSET_CLASS assetType,const TRADE_DIRECTION direction) const
     {
      SetupScore score;
      score.classification = SETUP_REJECT;
      score.totalPoints = 0;
      score.traderMagicPoints = score.currencyStrengthPoints = score.rsiomaPoints = score.waePoints = 0;
      score.direction = direction;
      score.requiredPoints = 0;

  if(m_indicatorManager == NULL || m_assetManager == NULL)
         return score;

      bool isBuy = (direction == TRADE_DIRECTION_BUY);

      TMSignal tm;
  if(!(*m_indicatorManager).GetTraderMagicSignal(PERIOD_M15,tm) || !tm.isValid || tm.direction != direction)
         return score;

      score.traderMagicPoints = 1;

      if(assetType == ASSET_CLASS_FOREX_MAJOR || assetType == ASSET_CLASS_FOREX_MINOR ||
         assetType == ASSET_CLASS_FOREX_EXOTIC || assetType == ASSET_CLASS_CURRENCY_B3 ||
         assetType == ASSET_CLASS_METALS)
        {
         score.requiredPoints = 2;
  CSSignal cs = (*m_indicatorManager).GetCurrencyStrengthSignal(isBuy,assetType);
         if(cs.isValid && cs.isAligned)
            score.currencyStrengthPoints = 1;

         RSISignal rsi;
  if((*m_indicatorManager).GetRSISignal(PERIOD_M15,isBuy,rsi) && rsi.isValid && rsi.isAligned)
            score.rsiomaPoints = 1;

         WAESignal wae;
  if((*m_indicatorManager).GetWAESignal(PERIOD_M15,isBuy,wae) && wae.isValid && wae.isAligned)
            score.waePoints = 1;

         score.totalPoints = score.currencyStrengthPoints + score.rsiomaPoints + score.waePoints;
        }
      else if(assetType == ASSET_CLASS_INDEX_US || assetType == ASSET_CLASS_INDEX_EU || assetType == ASSET_CLASS_INDEX_B3)
        {
         score.requiredPoints = 2;
         RSISignal rsi;
  if((*m_indicatorManager).GetRSISignal(PERIOD_M15,isBuy,rsi) && rsi.isValid && rsi.isAligned)
            score.rsiomaPoints = 1;
         WAESignal wae;
  if((*m_indicatorManager).GetWAESignal(PERIOD_M15,isBuy,wae) && wae.isValid && wae.isAligned)
            score.waePoints = 1;
         score.totalPoints = score.rsiomaPoints + score.waePoints;
        }
      else
        {
         score.totalPoints = score.rsiomaPoints + score.waePoints + score.currencyStrengthPoints;
         score.requiredPoints = 2;
        }

    if(score.totalPoints >= score.requiredPoints)
      {
      if(assetType == ASSET_CLASS_INDEX_US || assetType == ASSET_CLASS_INDEX_EU || assetType == ASSET_CLASS_INDEX_B3)
        score.classification = SETUP_PREMIUM;
      else if(score.totalPoints >= 3)
        score.classification = SETUP_PREMIUM;
      else
        score.classification = SETUP_GOOD;
      }

      return score;
     }
  };

//--- Gestão de risco baseada em estrutura
class CRiskManager
  {
private:
   CAssetManager *m_assetManager;
public:
   CRiskManager():m_assetManager(NULL){}

   void Attach(CAssetManager *assets)
     {
      m_assetManager = assets;
     }

   RiskCalculation Calculate(const string symbol,const SetupScore &score,const ASSET_CLASS assetClass) const
     {
      RiskCalculation calc;
      calc.isValid       = false;
      calc.errorMessage  = "";
      calc.classification= score.classification;
      calc.direction     = score.direction;
      calc.entryPrice    = (score.direction == TRADE_DIRECTION_BUY) ? SymbolInfoDouble(symbol,SYMBOL_ASK) : SymbolInfoDouble(symbol,SYMBOL_BID);
      calc.stopLoss      = 0.0;
      calc.slDistance    = 0.0;
      calc.positionSize  = 0.0;
      calc.riskAmount    = 0.0;
      calc.tp1           = 0.0;
      calc.tp2           = 0.0;
      calc.trailingStart = 0.0;

      if(m_assetManager == NULL)
        {
         calc.errorMessage = "Asset manager não inicializado";
         return calc;
        }

      AssetConfig config;
      if(!(*m_assetManager).GetConfig(assetClass, config))
        {
         calc.errorMessage = "Configuração de ativo inválida";
         return calc;
        }

      double stopLevel = FindStructureStop(symbol,score.direction,config);
      if(stopLevel <= 0.0)
        {
         calc.errorMessage = "Sem estrutura válida para SL";
         return calc;
        }

      calc.stopLoss = stopLevel;
      calc.slDistance = MathAbs(calc.entryPrice - calc.stopLoss);

      double point = SymbolInfoDouble(symbol,SYMBOL_POINT);
      double slPips = calc.slDistance/point;
      if(slPips < config.idealSLMinPips || slPips > config.idealSLMaxPips)
        {
         calc.errorMessage = "SL fora do range ideal";
         return calc;
        }

      double riskPercent = (score.classification == SETUP_PREMIUM) ? config.premiumRiskPercent : config.goodRiskPercent;
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskAmount = balance * (riskPercent/100.0);

      double lotStep   = SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP);
      double lotMin    = SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN);
      double lotMax    = SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX);
      double tickVal   = SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE);
      double tickSize  = SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
      double pipValue  = (tickSize > 0.0) ? (tickVal * point / tickSize) : tickVal;
    if(config.pipValueOverride > 0)
      pipValue = config.pipValueOverride;

      if(pipValue <= 0.0)
        {
         calc.errorMessage = "Pip value inválido";
         return calc;
        }

      double riskPerLot = (calc.slDistance/point) * pipValue;
      if(riskPerLot <= 0.0)
        {
         calc.errorMessage = "Risco por lote inválido";
         return calc;
        }

      double positionSize = riskAmount / riskPerLot;
      positionSize = MathMax(positionSize,lotMin);
      positionSize = MathMin(positionSize,lotMax);
      positionSize = NormalizeLot(symbol,positionSize,lotStep);

      if(positionSize < lotMin - 1e-6)
        {
         calc.errorMessage = "Volume insuficiente";
         return calc;
        }

      if((assetClass == ASSET_CLASS_INDEX_B3 || assetClass == ASSET_CLASS_CURRENCY_B3) && !ValidateB3Margin(symbol,positionSize))
        {
         calc.errorMessage = "Margem insuficiente";
         return calc;
        }

      calc.positionSize = positionSize;
      calc.riskAmount   = riskAmount;
      calc.isValid      = true;

      if(EnablePartialTP)
        {
         double directionFactor = (score.direction == TRADE_DIRECTION_BUY) ? 1.0 : -1.0;
         calc.tp1 = calc.entryPrice + directionFactor * calc.slDistance * TP1_RR;
         calc.tp2 = calc.entryPrice + directionFactor * calc.slDistance * TP2_RR;
        }

      calc.trailingStart = (score.direction == TRADE_DIRECTION_BUY) ? (calc.entryPrice + calc.slDistance * TP2_RR) : (calc.entryPrice - calc.slDistance * TP2_RR);

      return calc;
     }

private:
   static double NormalizeLot(const string symbol,double lot,const double step)
     {
      double normalized = MathFloor(lot/step + 0.5) * step;
      double min = SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN);
      if(normalized < min)
         normalized = min;
      return normalized;
     }

  double FindStructureStop(const string symbol,const TRADE_DIRECTION direction,const AssetConfig &config) const
     {
      double buffer = ConvertPipsToPrice(symbol,config.slBufferPips);
    double lows[];
    double highs[];
      int bars = MathMin(LookbackStructureBars,120);

    ArraySetAsSeries(lows,true);
    ArraySetAsSeries(highs,true);

    if(CopyLow(symbol,PERIOD_M15,1,bars,lows) != bars)
         return 0.0;
    if(CopyHigh(symbol,PERIOD_M15,1,bars,highs) != bars)
         return 0.0;

      if(direction == TRADE_DIRECTION_BUY)
        {
         for(int i=2; i<bars-2; ++i)
           {
            double candidate = lows[i];
            bool isSwing = true;
            for(int j=-2; j<=2; ++j)
              {
               if(j == 0) continue;
               if(lows[i+j] <= candidate)
                 {
                  isSwing = false;
                  break;
                 }
              }
            if(isSwing)
               return candidate - buffer;
           }
        }
      else if(direction == TRADE_DIRECTION_SELL)
        {
         for(int i=2; i<bars-2; ++i)
           {
            double candidate = highs[i];
            bool isSwing = true;
            for(int j=-2; j<=2; ++j)
              {
               if(j == 0) continue;
               if(highs[i+j] >= candidate)
                 {
                  isSwing = false;
                  break;
                 }
              }
            if(isSwing)
               return candidate + buffer;
           }
        }

      return 0.0;
     }

   static bool ValidateB3Margin(const string symbol,const double lots)
     {
      double marginRequired = 0.0;
      double price = SymbolInfoDouble(symbol,SYMBOL_ASK);
      if(!OrderCalcMargin(ORDER_TYPE_BUY,symbol,lots,price,marginRequired))
         return false;

      double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      double balance    = AccountInfoDouble(ACCOUNT_BALANCE);
      double safety     = balance * 0.3;
      return (freeMargin - marginRequired) > safety;
     }
  };

//--- Estatísticas e logging
class CStatistics
  {
private:
   TradeRecord m_records[];
public:
   void RecordTrade(const TradeRecord &record)
     {
      int size = ArraySize(m_records);
      ArrayResize(m_records,size+1);
      m_records[size] = record;
      AppendStringToFile("Nexus_TradeHistory.log",FormatRecord(record));
     }

   void RecordClosedDeal(const ulong deal)
     {
      TradeRecord record;
      ZeroMemory(record);
  record.closeTime = (datetime)HistoryDealGetInteger(deal,DEAL_TIME);
  record.openTime  = record.closeTime;
      record.symbol    = HistoryDealGetString(deal,DEAL_SYMBOL);
  double exitPrice = HistoryDealGetDouble(deal,DEAL_PRICE);
  record.openPrice = exitPrice;
  record.closePrice= exitPrice;
      record.profit    = HistoryDealGetDouble(deal,DEAL_PROFIT);
      record.riskAmount= 0.0;
      record.rr        = (record.profit != 0.0 && record.riskAmount != 0.0) ? (record.profit/record.riskAmount) : 0.0;
      string comment   = HistoryDealGetString(deal,DEAL_COMMENT);
      if(StringFind(comment,"PREMIUM") >= 0)
         record.setupClass = SETUP_PREMIUM;
      else if(StringFind(comment,"GOOD") >= 0)
         record.setupClass = SETUP_GOOD;
      else
         record.setupClass = SETUP_REJECT;

      record.direction = (StringFind(comment,"BUY") >= 0) ? TRADE_DIRECTION_BUY : TRADE_DIRECTION_SELL;
      record.closeReason = "Deal fechado";
      record.tp1Hit = false;
      record.tp2Hit = false;

      RecordTrade(record);
     }

   void GenerateMonthlyReport()
     {
      datetime now = TimeCurrent();
      MqlDateTime dt;
      TimeToStruct(now,dt);
      string filename = StringFormat("Nexus_Report_%04d_%02d.txt",dt.year,dt.mon);
      int total = ArraySize(m_records);
      if(total == 0)
         return;

      double profit = 0.0;
      double loss   = 0.0;
      int winners = 0;

      for(int i=0; i<total; ++i)
        {
         if(m_records[i].profit >= 0)
           {
            profit += m_records[i].profit;
            winners++;
           }
         else
            loss += MathAbs(m_records[i].profit);
        }

      double winRate = (total > 0) ? (double)winners/total*100.0 : 0.0;
      double profitFactor = (loss > 0) ? profit/loss : 0.0;

      string report = StringFormat("=== RELATÓRIO MENSAL - %s ===\n",TimeToString(now,TIME_DATE));
      report += StringFormat("Trades: %d\n",total);
      report += StringFormat("Win Rate: %.2f%%\n",winRate);
      report += StringFormat("Profit Factor: %.2f\n",profitFactor);
      report += StringFormat("Lucro líquido: %.2f\n",profit-loss);

      SaveStringToFile(filename,report);
     }

private:
   static string FormatRecord(const TradeRecord &record)
     {
      string line = StringFormat("%s;%s;%s;%.5f;%.5f;%.2f;%.2f;%s\n",
                                 TimeToString(record.openTime,TIME_DATE|TIME_MINUTES),
                                 TimeToString(record.closeTime,TIME_DATE|TIME_MINUTES),
                                 record.symbol,
                                 record.openPrice,
                                 record.closePrice,
                                 record.profit,
                                 record.rr,
                                 record.closeReason);
      return line;
     }

   static void SaveStringToFile(const string filename,const string content)
     {
      int handle = FileOpen(filename,FILE_WRITE|FILE_TXT|FILE_COMMON);
      if(handle == INVALID_HANDLE)
        {
         Print("[Statistics] Falha ao salvar arquivo: ",filename);
         return;
        }
      FileWrite(handle,content);
      FileClose(handle);
     }

   static void AppendStringToFile(const string filename,const string content)
     {
      int handle = FileOpen(filename,FILE_READ|FILE_WRITE|FILE_TXT|FILE_COMMON);
      if(handle == INVALID_HANDLE)
         handle = FileOpen(filename,FILE_WRITE|FILE_TXT|FILE_COMMON);
      if(handle == INVALID_HANDLE)
        {
         Print("[Statistics] Falha ao abrir arquivo: ",filename);
         return;
        }
      FileSeek(handle,0,SEEK_END);
      FileWriteString(handle,content);
      FileClose(handle);
     }
  };

//--- Sistema de proteções
class CProtectionSystem
  {
private:
   CAssetManager   *m_assetManager;
   CHoursManager   *m_hoursManager;
public:
   CProtectionSystem():m_assetManager(NULL),m_hoursManager(NULL){}

   void Attach(CAssetManager *assets,CHoursManager *hours)
     {
      m_assetManager = assets;
      m_hoursManager = hours;
     }

   bool ValidateBasicConditions(const ASSET_CLASS assetClass)
     {
      if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
        {
         Print("[Protection] Trading não permitido");
         return false;
        }

      if(!TerminalInfoInteger(TERMINAL_CONNECTED))
        {
         Print("[Protection] Terminal desconectado");
         return false;
        }

      if(g_tradingPaused)
        {
         Print("[Protection] Trading pausado por risco");
         return false;
        }

  if(m_hoursManager == NULL || !(*m_hoursManager).IsValidTradingTime(assetClass))
         return false;

      if(CheckMaxDrawdown())
        {
         g_tradingPaused = true;
         return false;
        }

      if(GetActiveTradesCount() >= MaxSimultaneousTrades)
         return false;

      return true;
     }

   bool ValidateMarketConditions(const string symbol,const ASSET_CLASS assetClass) const
     {
      double spreadPoints = (double)SymbolInfoInteger(symbol,SYMBOL_SPREAD);
      double spreadPips = spreadPoints;
      AssetConfig config;
      if(m_assetManager == NULL || !(*m_assetManager).GetConfig(assetClass, config))
         return false;

      if(spreadPips > config.maxSpreadPips)
        {
         PrintFormat("[Protection] Spread alto %.2f pips",spreadPips);
         return false;
        }

      if(ValidateATRRange && !IsATRInRange(symbol,assetClass))
        {
         Print("[Protection] ATR fora de range");
         return false;
        }

      if(AvoidNews && IsNewsTime())
        {
         Print("[Protection] Próximo de notícia importante");
         return false;
        }

      return true;
     }

   static void ResetPause()
     {
      g_tradingPaused = false;
     }

private:
   bool CheckMaxDrawdown() const
     {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      if(g_initialBalance <= 0)
         return false;
      double dd = (g_initialBalance - equity)/g_initialBalance*100.0;
      return (dd >= MaxDrawdownPercent);
     }

   static int GetActiveTradesCount()
     {
      int count = 0;
      int total = PositionsTotal();
      for(int i=0; i<total; ++i)
        {
         if(PositionGetTicket(i))
           {
            if(PositionGetInteger(POSITION_MAGIC) == EA_MAGIC_NUMBER)
               count++;
           }
        }
      return count;
     }

   bool IsATRInRange(const string symbol,const ASSET_CLASS assetClass) const
     {
      int handle = iATR(symbol,PERIOD_M15,14);
      if(handle == INVALID_HANDLE)
         return true;
      double atr[1];
      if(CopyBuffer(handle,0,0,1,atr) != 1)
        {
         IndicatorRelease(handle);
         return true;
        }
      IndicatorRelease(handle);
      AssetConfig config;
      if(m_assetManager == NULL || !(*m_assetManager).GetConfig(assetClass, config))
         return true;

      double atrPips = atr[0]/SymbolInfoDouble(symbol,SYMBOL_POINT);
      return (atrPips >= config.minATR && atrPips <= config.maxATR);
     }

   static bool IsNewsTime()
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(),dt);
      if(dt.day_of_week == 5 && dt.hour == 15 && dt.min >= 0 && dt.min <= 60 && dt.day <= 7)
         return true;
      return false;
     }
  };

//--- Gestão de trades
class CTradeManager
  {
private:
   class ActiveTrade
     {
     public:
      string          symbol;
      double          volume;
      double          entryPrice;
      double          stopLoss;
      double          tp1Level;
      double          tp2Level;
      double          trailingDistance;
      bool            tp1Hit;
      bool            tp2Hit;
      bool            trailingActive;
      datetime        entryTime;
      SETUP_CLASS     setupClass;
      TRADE_DIRECTION direction;
     };

   ActiveTrade m_trades[];
   CAssetManager     *m_assetManager;
   CIndicatorManager *m_indicatorManager;
   CHoursManager     *m_hoursManager;
   CStatistics       *m_statistics;
public:
   CTradeManager():m_assetManager(NULL),m_indicatorManager(NULL),m_hoursManager(NULL),m_statistics(NULL){}

   void Attach(CAssetManager *assets,CIndicatorManager *ind,CHoursManager *hours,CStatistics *stats)
     {
      m_assetManager     = assets;
      m_indicatorManager = ind;
      m_hoursManager     = hours;
      m_statistics       = stats;
     }

   bool ExecuteTrade(const string symbol,const RiskCalculation &risk,const ASSET_CLASS assetClass)
     {
      if(risk.positionSize <= 0.0)
         return false;

      if(PositionSelect(symbol) && PositionGetInteger(POSITION_MAGIC) == EA_MAGIC_NUMBER)
        {
         return false;
        }

      MqlTradeRequest request;
      MqlTradeResult  result;
      ZeroMemory(request);
      ZeroMemory(result);

      request.action   = TRADE_ACTION_DEAL;
      request.symbol   = symbol;
      request.magic    = EA_MAGIC_NUMBER;
      request.volume   = risk.positionSize;
      request.sl       = risk.stopLoss;
      request.tp       = 0.0;
      request.deviation= MaxSlippagePoints;
      request.type     = (risk.direction == TRADE_DIRECTION_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      request.price    = (risk.direction == TRADE_DIRECTION_BUY) ? SymbolInfoDouble(symbol,SYMBOL_ASK) : SymbolInfoDouble(symbol,SYMBOL_BID);
      request.comment  = StringFormat("Nexus_%s_%s",DirectionToString(risk.direction),SetupClassToString(risk.classification));

      if(!OrderSend(request,result))
        {
         PrintFormat("[TradeManager] Falha ao enviar ordem (%s): %d - %s",symbol,result.retcode,result.comment);
         return false;
        }

      RegisterTrade(symbol,risk,assetClass);
      LogTradeExecution(symbol,risk,result);

      if(SendAlerts)
        {
         string msg = StringFormat("Nexus: %s %s %.5f",(risk.direction == TRADE_DIRECTION_BUY) ? "COMPRA" : "VENDA",symbol,result.price);
         SendNotification(msg);
        }

      return true;
     }

   void ManageOpenTrades()
     {
      for(int i=ArraySize(m_trades)-1; i>=0; --i)
        ManageSingleTrade(i);
     }

private:
   void RegisterTrade(const string symbol,const RiskCalculation &risk,const ASSET_CLASS assetClass)
     {
      ActiveTrade trade;
      ZeroMemory(trade);
      trade.symbol       = symbol;
      trade.volume       = risk.positionSize;
      trade.entryPrice   = risk.entryPrice;
      trade.stopLoss     = risk.stopLoss;
      trade.tp1Level     = risk.tp1;
      trade.tp2Level     = risk.tp2;
      AssetConfig config;
      double trailingBase = 0.0;
      if(m_assetManager != NULL && (*m_assetManager).GetConfig(assetClass, config))
         trailingBase = config.trailingDistancePips;
      trade.trailingDistance = ConvertPipsToPrice(symbol,trailingBase) * TrailingDistanceMultiplier;
      trade.tp1Hit       = false;
      trade.tp2Hit       = false;
      trade.trailingActive = false;
      trade.entryTime    = TimeCurrent();
      trade.setupClass   = risk.classification;
      trade.direction    = risk.direction;

      if(PositionSelect(symbol) && PositionGetInteger(POSITION_MAGIC) == EA_MAGIC_NUMBER)
        {
         trade.entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         trade.stopLoss   = PositionGetDouble(POSITION_SL);
        }

      int size = ArraySize(m_trades);
      ArrayResize(m_trades,size+1);
      m_trades[size] = trade;
     }

   void ManageSingleTrade(const int index)
     {
      if(index < 0 || index >= ArraySize(m_trades))
         return;

      if(!PositionSelect(m_trades[index].symbol) || PositionGetInteger(POSITION_MAGIC) != EA_MAGIC_NUMBER)
        {
         RemoveTrade(index);
         return;
        }

      double currentPrice = SymbolInfoDouble(m_trades[index].symbol,(m_trades[index].direction == TRADE_DIRECTION_BUY) ? SYMBOL_BID : SYMBOL_ASK);

      if(EnablePartialTP && !m_trades[index].tp1Hit && m_trades[index].tp1Level > 0.0)
        {
         if((m_trades[index].direction == TRADE_DIRECTION_BUY && currentPrice >= m_trades[index].tp1Level) ||
            (m_trades[index].direction == TRADE_DIRECTION_SELL && currentPrice <= m_trades[index].tp1Level))
           {
            double currentVolume = PositionGetDouble(POSITION_VOLUME);
            double closeVolume   = MathMin(currentVolume,m_trades[index].volume * 0.5);
            if(closeVolume > 0 && g_trade.PositionClosePartial(m_trades[index].symbol,closeVolume))
              {
               MoveToBreakeven(index);
               m_trades[index].tp1Hit = true;
               LogTakeProfit(m_trades[index].symbol,1,currentPrice);
              }
           }
        }

      if(EnablePartialTP && m_trades[index].tp1Hit && !m_trades[index].tp2Hit && m_trades[index].tp2Level > 0.0)
        {
         if((m_trades[index].direction == TRADE_DIRECTION_BUY && currentPrice >= m_trades[index].tp2Level) ||
            (m_trades[index].direction == TRADE_DIRECTION_SELL && currentPrice <= m_trades[index].tp2Level))
           {
            double currentVolume = PositionGetDouble(POSITION_VOLUME);
            double closeVolume   = MathMin(currentVolume,m_trades[index].volume * 0.5);
            if(closeVolume > 0 && g_trade.PositionClosePartial(m_trades[index].symbol,closeVolume))
              {
               m_trades[index].tp2Hit = true;
               if(EnableTrailing)
                  m_trades[index].trailingActive = true;
               LogTakeProfit(m_trades[index].symbol,2,currentPrice);
              }
           }
        }

      if(m_trades[index].trailingActive && EnableTrailing)
        UpdateTrailing(index,currentPrice);

      if(CheckEarlyExit(index))
        {
         if(g_trade.PositionClose(m_trades[index].symbol))
           {
            Print("[TradeManager] Saída antecipada: ",m_trades[index].symbol);
            RemoveTrade(index);
           }
        }
     }

   void MoveToBreakeven(const int index)
     {
      double entry = m_trades[index].entryPrice;
      if(g_trade.PositionModify(m_trades[index].symbol,entry,0))
        {
         m_trades[index].stopLoss = entry;
         Print("[TradeManager] SL movido para BE em ",m_trades[index].symbol);
        }
     }

   void UpdateTrailing(const int index,const double currentPrice)
     {
      double newSL = m_trades[index].stopLoss;
      if(m_trades[index].direction == TRADE_DIRECTION_BUY)
        {
         double candidate = currentPrice - m_trades[index].trailingDistance;
         if(candidate > m_trades[index].stopLoss && g_trade.PositionModify(m_trades[index].symbol,candidate,0))
            m_trades[index].stopLoss = candidate;
        }
      else
        {
         double candidate = currentPrice + m_trades[index].trailingDistance;
         if(candidate < m_trades[index].stopLoss && g_trade.PositionModify(m_trades[index].symbol,candidate,0))
            m_trades[index].stopLoss = candidate;
        }
     }

   bool CheckEarlyExit(const int index)
     {
      if(m_indicatorManager == NULL)
         return false;

      TMSignal h4Signal;
      if((*m_indicatorManager).GetTraderMagicSignal(PERIOD_H4,h4Signal) && h4Signal.isValid)
        {
         if(m_trades[index].direction == TRADE_DIRECTION_BUY && h4Signal.direction == TRADE_DIRECTION_SELL)
            return true;
         if(m_trades[index].direction == TRADE_DIRECTION_SELL && h4Signal.direction == TRADE_DIRECTION_BUY)
            return true;
        }

      TMSignal m15Signal;
      if((*m_indicatorManager).GetTraderMagicSignal(PERIOD_M15,m15Signal) && m15Signal.isValid)
        {
         if(m_trades[index].direction == TRADE_DIRECTION_BUY && m15Signal.direction == TRADE_DIRECTION_SELL)
            return true;
         if(m_trades[index].direction == TRADE_DIRECTION_SELL && m15Signal.direction == TRADE_DIRECTION_BUY)
            return true;
        }

      ASSET_CLASS asset = (m_assetManager != NULL) ? (*m_assetManager).ClassifyAsset(m_trades[index].symbol) : ASSET_CLASS_UNKNOWN;
      if(m_hoursManager == NULL || !(*m_hoursManager).IsValidTradingTime(asset))
         return true;

      MqlDateTime dt;
      TimeToStruct(TimeCurrent(),dt);
      if(dt.day_of_week == 5 && dt.hour >= 16)
         return true;

      return false;
     }

   void RemoveTrade(const int index)
     {
      if(index < 0 || index >= ArraySize(m_trades))
         return;
      if(index == ArraySize(m_trades)-1)
         ArrayResize(m_trades,index);
      else
        {
         m_trades[index] = m_trades[ArraySize(m_trades)-1];
         ArrayResize(m_trades,ArraySize(m_trades)-1);
        }
     }

   static void LogTradeExecution(const string symbol,const RiskCalculation &risk,const MqlTradeResult &result)
     {
      PrintFormat("[TradeManager] Ordem %s %s volume %.2f SL %.5f",symbol,DirectionToString(risk.direction),risk.positionSize,risk.stopLoss);
     }

   static void LogTakeProfit(const string symbol,const int tpNumber,const double price)
     {
      PrintFormat("[TradeManager] %s atingiu TP%d @ %.5f",symbol,tpNumber,price);
     }
  };

//--- Instâncias globais das classes
CAssetManager     *assetManager      = NULL;
CIndicatorManager *indicatorManager  = NULL;
CTimeFrameAnalyzer *tfAnalyzer       = NULL;
CSetupScorer      *setupScorer       = NULL;
CRiskManager      *riskManager       = NULL;
CTradeManager     *tradeManager      = NULL;
CHoursManager     *hoursManager      = NULL;
CStatistics       *statistics        = NULL;
CProtectionSystem *protectionSystem  = NULL;

//--- Funções auxiliares
string BoolToText(const bool value)
  {
   return value ? "Sim" : "Não";
  }

string ComposeIndicatorPath(const string fileName)
  {
   string trimmed = fileName;
   if(StringFind(trimmed,".ex5") < 0 && StringFind(trimmed,".mq5") < 0)
      trimmed += ".ex5";
   return IndicatorsBasePath + trimmed;
  }

double ConvertPipsToPrice(const string symbol,const double pips)
  {
   double point = SymbolInfoDouble(symbol,SYMBOL_POINT);
   return pips * point;
  }

double ConvertPriceToPips(const string symbol,const double priceDistance)
  {
   double point = SymbolInfoDouble(symbol,SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;
   return priceDistance/point;
  }

string SetupClassToString(const SETUP_CLASS cls)
  {
   switch(cls)
     {
      case SETUP_PREMIUM: return "PREMIUM";
      case SETUP_GOOD:    return "GOOD";
      default:            return "REJECT";
     }
  }

string DirectionToString(const TRADE_DIRECTION dir)
  {
   return (dir == TRADE_DIRECTION_BUY) ? "BUY" : "SELL";
  }

void CleanupOldLogs()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int currentDay = dt.day;
   if(g_lastCleanupDay == currentDay)
      return;
   g_lastCleanupDay = currentDay;
  }

void ValidateSystemIntegrity()
  {
   if(indicatorManager == NULL)
      return;
  }

bool ValidateInputParameters()
  {
   if(AccountRiskPercent <= 0.0 || MaxRiskPremium <= 0.0)
     {
      Print("Parâmetros de risco inválidos");
      return false;
     }
   if(TP1_RR <= 0.0 || TP2_RR <= 0.0)
     {
      Print("RR inválido");
      return false;
     }
   return true;
  }

void PrintConfiguration(const ASSET_CLASS asset)
  {
   Print("=== Configurações Ativas ===");
   PrintFormat("Conta: Bal %.2f Equity %.2f",AccountInfoDouble(ACCOUNT_BALANCE),AccountInfoDouble(ACCOUNT_EQUITY));
   PrintFormat("Risco BOM: %.2f%% | Risco PREMIUM: %.2f%%",AccountRiskPercent,MaxRiskPremium);
   PrintFormat("Asset class: %d",asset);
  }

void SetupGlobalObjects()
  {
   assetManager     = new CAssetManager();
   indicatorManager = new CIndicatorManager();
   tfAnalyzer       = new CTimeFrameAnalyzer();
   setupScorer      = new CSetupScorer();
   riskManager      = new CRiskManager();
   tradeManager     = new CTradeManager();
   hoursManager     = new CHoursManager();
   statistics       = new CStatistics();
   protectionSystem = new CProtectionSystem();

  if(tfAnalyzer != NULL)
    (*tfAnalyzer).Attach(indicatorManager,assetManager);
  if(setupScorer != NULL)
    (*setupScorer).Attach(indicatorManager,assetManager);
  if(riskManager != NULL)
    (*riskManager).Attach(assetManager);
  if(tradeManager != NULL)
    (*tradeManager).Attach(assetManager,indicatorManager,hoursManager,statistics);
  if(protectionSystem != NULL)
    (*protectionSystem).Attach(assetManager,hoursManager);
  }

void DestroyGlobalObjects()
  {
   if(indicatorManager != NULL)
     {
    (*indicatorManager).Release();
      delete indicatorManager;
      indicatorManager = NULL;
     }

   if(tradeManager != NULL)
     {
      delete tradeManager;
      tradeManager = NULL;
     }

   if(tfAnalyzer != NULL)
     {
      delete tfAnalyzer;
      tfAnalyzer = NULL;
     }

   if(setupScorer != NULL)
     {
      delete setupScorer;
      setupScorer = NULL;
     }

   if(riskManager != NULL)
     {
      delete riskManager;
      riskManager = NULL;
     }

   if(hoursManager != NULL)
     {
      delete hoursManager;
      hoursManager = NULL;
     }

   if(statistics != NULL)
     {
      delete statistics;
      statistics = NULL;
     }

   if(protectionSystem != NULL)
     {
      delete protectionSystem;
      protectionSystem = NULL;
     }

   if(assetManager != NULL)
     {
      delete assetManager;
      assetManager = NULL;
     }
  }

//--- Funções do ciclo de vida do EA
int OnInit()
  {
   PrintFormat("=== INICIANDO %s v%s ===",EA_NAME,EA_VERSION);

   if(!ValidateInputParameters())
      return INIT_PARAMETERS_INCORRECT;

   SetupGlobalObjects();

  if(indicatorManager == NULL || !(*indicatorManager).Initialize(_Symbol))
     {
      Print("Falha ao inicializar indicadores");
      return INIT_FAILED;
     }

   if(assetManager == NULL)
     {
      Print("Asset manager não disponível");
      return INIT_FAILED;
     }
  ASSET_CLASS currentAsset = (*assetManager).ClassifyAsset(_Symbol);
  if(!(*assetManager).IsAssetSupported(currentAsset))
     {
      Print("Ativo não suportado");
      return INIT_FAILED;
     }

   g_initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   PrintConfiguration(currentAsset);

   EventSetTimer(3600);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   Print("=== FINALIZANDO NEXUS CONFLUENCE EA ===");
   PrintFormat("Razão: %d",reason);

   EventKillTimer();
   DestroyGlobalObjects();
  }

void OnTimer()
  {
   CleanupOldLogs();

   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now,dt);
   if(g_lastReportMonth != dt.mon)
     {
    if(statistics != NULL)
      (*statistics).GenerateMonthlyReport();
      g_lastReportMonth = dt.mon;
     }

   ValidateSystemIntegrity();
   
   // Remover objetos duplicados criados pelo indicador GG_TrendBar original
   if(indicatorManager != NULL)
     {
      static int cleanupCounter = 0;
      cleanupCounter++;
      // Limpar a cada 10 segundos (timer está em 1 segundo)
      if(cleanupCounter >= 10)
        {
         RemoveDuplicateGGTrendBarObjects();
         cleanupCounter = 0;
        }
     }
  }

// Função auxiliar para remover objetos duplicados
void RemoveDuplicateGGTrendBarObjects()
  {
   string timeframes[] = {"M1", "M5", "M15", "M30", "H1", "H4", "D1", "W1", "MN1"};
   
   for(int i = 0; i < 9; i++)
     {
      // Deletar headers do indicador original (sem prefix "EA_")
      string label_name = "TF_" + timeframes[i];
      if(ObjectFind(0, label_name) >= 0)
         ObjectDelete(0, label_name);
      
      // Deletar indicadores do indicador original
      string ind_name = "Ind_" + IntegerToString(i);
      if(ObjectFind(0, ind_name) >= 0)
         ObjectDelete(0, ind_name);
     }
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
  {
   if(statistics == NULL)
      return;
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
     {
      ulong dealTicket = trans.deal;
      if(HistoryDealGetInteger(dealTicket,DEAL_MAGIC) == EA_MAGIC_NUMBER && HistoryDealGetInteger(dealTicket,DEAL_ENTRY) == DEAL_ENTRY_OUT)
         (*statistics).RecordClosedDeal(dealTicket);
     }
  }

void ProcessNewSetup(const ASSET_CLASS assetClass)
  {
  if(tfAnalyzer == NULL || setupScorer == NULL || protectionSystem == NULL || riskManager == NULL || tradeManager == NULL)
    return;

  MultiTFResult mtf = (*tfAnalyzer).Analyze(_Symbol,assetClass);
  if(!mtf.isValid)
    return;

  SetupScore score = (*setupScorer).Evaluate(_Symbol,assetClass,mtf.direction);
  if(score.classification == SETUP_REJECT)
    return;

  if(!(*protectionSystem).ValidateMarketConditions(_Symbol,assetClass))
    return;

  RiskCalculation risk = (*riskManager).Calculate(_Symbol,score,assetClass);
  if(!risk.isValid)
    {
    if(risk.errorMessage != "")
      Print("[RiskManager] ",risk.errorMessage);
    return;
    }

  (*tradeManager).ExecuteTrade(_Symbol,risk,assetClass);
  }

void OnTick()
  {
  if(assetManager == NULL || protectionSystem == NULL)
    return;

  // Atualizar visualização do GG_TrendBar
  if(indicatorManager != NULL)
    {
    GGTrendBarSignal ggSignal;
    if((*indicatorManager).GetGGTrendBarSignal(ggSignal) && ggSignal.isValid)
      {
      (*indicatorManager).UpdateVisuals(ggSignal);
      }
    }

  ASSET_CLASS assetClass = (*assetManager).ClassifyAsset(_Symbol);
  if(!(*protectionSystem).ValidateBasicConditions(assetClass))
    {
    if(tradeManager != NULL)
      (*tradeManager).ManageOpenTrades();
    return;
    }

  ProcessNewSetup(assetClass);
  if(tradeManager != NULL)
    (*tradeManager).ManageOpenTrades();
  }
