//+------------------------------------------------------------------+//+------------------------------------------------------------------+//+------------------------------------------------------------------+//+------------------------------------------------------------------+

//| NexusConfluenceEA.mq5                                            |

//| Copyright 2024, Nexus Confluence System                         |//| NexusConfluenceEA.mq5                                            |

//| https://nexusconfluence.com                                     |

//+------------------------------------------------------------------+//| Copyright 2024, Nexus Confluence System                         |//| NexusConfluenceEA.mq5                                            |//| Nexus Confluence EA v4.0 - Sistema Universal de Trading          |

#property copyright "Nexus Confluence System"

#property link      "https://nexusconfluence.com"//| https://nexusconfluence.com                                     |

#property version   "4.00"

#property description "EA Nexus Confluence - Sistema Universal Multi-Ativo"//+------------------------------------------------------------------+//| Copyright 2024, Nexus Confluence System                         |//| Expert Advisor Corrigido - Caminhos dos Indicadores Atualizados  |



//+------------------------------------------------------------------+#property copyright "Nexus Confluence System"

//| Includes                                                         |

//+------------------------------------------------------------------+#property link      "https://nexusconfluence.com"//| https://nexusconfluence.com                                     |//|                                                                  |

#include <Trade\Trade.mqh>

#property version   "4.00"

//+------------------------------------------------------------------+

//| Enumerações                                                      |#property description "EA Nexus Confluence - Sistema Universal Multi-Ativo"//+------------------------------------------------------------------+//| Autor: Sistema Nexus Confluence                                  |

//+------------------------------------------------------------------+

enum ASSET_CLASS

{

    FOREX_MAJOR,//+------------------------------------------------------------------+#property copyright "Nexus Confluence System"//| Data: Outubro 2024                                              |

    FOREX_MINOR, 

    FOREX_EXOTIC,//| Includes                                                         |

    INDEX_US,

    INDEX_EU,//+------------------------------------------------------------------+#property link      "https://nexusconfluence.com"//| Versão: 4.0 - Fixed                                             |

    INDEX_B3,

    CURRENCY_B3,#include <Trade\Trade.mqh>

    METALS,

    CRYPTO,#property version   "4.00"//+------------------------------------------------------------------+

    UNKNOWN

};//+------------------------------------------------------------------+



enum TRADE_DIRECTION//| Enumerações                                                      |#property description "EA Nexus Confluence - Sistema Universal Multi-Ativo"

{

    TRADE_BUY,//+------------------------------------------------------------------+

    TRADE_SELL,

    TRADE_NONEenum ASSET_CLASS#property copyright "Nexus Confluence System v4.0"

};

{

enum SETUP_CLASSIFICATION

{    FOREX_MAJOR,//+------------------------------------------------------------------+#property link      "https://nexusconfluence.com"

    PREMIUM,

    GOOD,    FOREX_MINOR, 

    REJECT

};    FOREX_EXOTIC,//| Includes necessários                                             |#property version   "4.0"



//+------------------------------------------------------------------+    INDEX_US,

//| Estruturas                                                       |

//+------------------------------------------------------------------+    INDEX_EU,//+------------------------------------------------------------------+#property description "Sistema Universal Multi-Ativo - CORRIGIDO"

struct TMSignal

{    INDEX_B3,

    bool isValid;

    TRADE_DIRECTION direction;    CURRENCY_B3,#include <Trade\Trade.mqh>

    double strength;

    int lastChangeBar;    METALS,

};

    CRYPTO,//+------------------------------------------------------------------+

struct CSSignal

{    UNKNOWN

    bool isValid;

    bool isAligned;};//+------------------------------------------------------------------+//| CONFIGURAÇÕES E ENUMS                                            |

    double baseStrength;

    double quoteStrength;

    bool isInverse;

};enum TRADE_DIRECTION//| Enumerações                                                      |//+------------------------------------------------------------------+



struct RSISignal{

{

    bool isValid;    TRADE_BUY,//+------------------------------------------------------------------+

    bool isAligned;

    double redValue;    TRADE_SELL,

    double blueValue;

    double slope;    TRADE_NONEenum ASSET_CLASSconst int EA_MAGIC_NUMBER = 20241015;

};

};

struct WAESignal

{{const string EA_VERSION = "4.0";

    bool isValid;

    bool isAligned;enum SETUP_CLASSIFICATION

    double mainValue;

    bool isExpanding;{    FOREX_MAJOR,

    bool hasStrength;

};    PREMIUM,



struct MultiTFResult    GOOD,    FOREX_MINOR, enum ASSET_CLASS {

{

    bool isValid;    REJECT

    bool H4_aligned;

    bool H1_aligned;};    FOREX_EXOTIC,    FOREX_MAJOR, FOREX_MINOR, FOREX_EXOTIC,

    bool M30_aligned;

    bool structure_valid;

    TRADE_DIRECTION direction;

    int quality_score;//+------------------------------------------------------------------+    INDEX_US,    INDEX_US, INDEX_EU, INDEX_B3, 

    string analysis_notes;

};//| Estruturas                                                       |



struct SetupScore//+------------------------------------------------------------------+    INDEX_EU,    CURRENCY_B3, METALS, CRYPTO, UNKNOWN

{

    int traderMagicPoints;struct TMSignal

    int currencyStrengthPoints;

    int rsiomaPoints;{    INDEX_B3,};

    int waePoints;

    int totalPoints;    bool isValid;

    int requiredPoints;

    SETUP_CLASSIFICATION classification;    TRADE_DIRECTION direction;    CURRENCY_B3,

    string reasoning;

};    double strength;



//+------------------------------------------------------------------+    int lastChangeBar;    METALS,enum TRADE_DIRECTION {

//| PARÂMETROS DE ENTRADA - TODOS OS INDICADORES                    |

//+------------------------------------------------------------------+};

input group "=== CONFIGURAÇÕES GERAIS ==="

input bool EnableAutoTrading = true;    CRYPTO,    TRADE_BUY, TRADE_SELL, TRADE_NONE

input double AccountRiskPercent = 1.5;

input int MaxSimultaneousTrades = 3;struct CSSignal

input int LogLevel = 2;

{    UNKNOWN};

input group "=== TREND MAGIC - PARÂMETROS ==="

input int TM_CCI_Period = 50;           // TrendMagic: CCI Period    bool isValid;

input int TM_ATR_Period = 5;            // TrendMagic: ATR Period  

input double TM_ATR_Multiplier = 1.0;   // TrendMagic: ATR Multiplier    bool isAligned;};



input group "=== CURRENCY STRENGTH - PARÂMETROS ==="    double baseStrength;

input int CS_CalculationPeriod = 24;    // CurrencyStrength: Calculation Period

input int CS_SmoothingPeriod = 5;       // CurrencyStrength: Smoothing Period    double quoteStrength;enum SETUP_CLASSIFICATION {

input bool CS_ShowInPercent = true;     // CurrencyStrength: Show in Percentage

    bool isInverse;

input group "=== RSI OMA - PARÂMETROS ==="

input int RSI_Period = 14;              // RSI OMA: RSI Period};enum TRADE_DIRECTION    PREMIUM, GOOD, REJECT

input int RSI_MA_Period = 9;            // RSI OMA: Moving Average Period

input ENUM_MA_METHOD RSI_MA_Method = MODE_SMA; // RSI OMA: MA Method

input double RSI_HighLevel = 70.0;      // RSI OMA: High Level

input double RSI_LowLevel = 30.0;       // RSI OMA: Low Levelstruct RSISignal{};

input bool RSI_ShowLevels = true;       // RSI OMA: Show Levels

{

input group "=== WAE - PARÂMETROS ==="

input int WAE_FastMA = 20;              // WAE: Fast MA Period    bool isValid;    TRADE_BUY,

input int WAE_SlowMA = 40;              // WAE: Slow MA Period

input int WAE_BBLength = 20;            // WAE: Bollinger Bands Length    bool isAligned;

input double WAE_BBMultiplier = 2.0;    // WAE: BB Multiplier

input int WAE_Sensitivity = 150;        // WAE: Sensitivity    double redValue;    TRADE_SELL,//+------------------------------------------------------------------+



input group "=== INDICADORES - NOMES DOS ARQUIVOS ==="    double blueValue;

input string TrendMagicIndicator = "TrendMagic_MT5";

input string CurrencyStrengthIndicator = "CurrencyStrengthMeter_MT5";    double slope;    TRADE_NONE//| ESTRUTURAS PRINCIPAIS                                            |

input string RSIOMAIndicator = "RSIOMA_v2HHLSX_MT5";

input string WAEIndicator = "WaddahAttarExplosion_Professional";};



input group "=== ALERTAS ==="};//+------------------------------------------------------------------+

input bool SendAlerts = true;

input bool EnableDetailedLogs = true;struct WAESignal

input bool SaveTradeHistory = true;

{

//+------------------------------------------------------------------+

//| Variáveis globais                                                |    bool isValid;

//+------------------------------------------------------------------+

const int EA_MAGIC_NUMBER = 20241015;    bool isAligned;enum SETUP_CLASSIFICATIONstruct TMSignal {

CTrade trade;

bool g_InitializationComplete = false;    double mainValue;



// Handles dos indicadores por timeframe    bool isExpanding;{    bool isValid;

struct IndicatorHandles

{    bool hasStrength;

    int tm_h4, tm_h1, tm_m30, tm_m15;

    int cs_m15;};    PREMIUM,    TRADE_DIRECTION direction;

    int rsi_h4, rsi_h1, rsi_m30, rsi_m15;

    int wae_h4, wae_h1, wae_m30, wae_m15;

};

struct MultiTFResult    GOOD,    double strength;

IndicatorHandles g_handles;

{

//+------------------------------------------------------------------+

//| Função de log                                                    |    bool isValid;    REJECT    int lastChangeBar;

//+------------------------------------------------------------------+

void WriteLog(int level, string message)    bool H4_aligned;

{

    if(level > LogLevel) return;    bool H1_aligned;};};

    

    string prefix;    bool M30_aligned;

    switch(level)

    {    bool structure_valid;

        case 0: prefix = "ERROR"; break;

        case 1: prefix = "INFO"; break;    TRADE_DIRECTION direction;

        case 2: prefix = "DEBUG"; break;

        case 3: prefix = "TRACE"; break;    int quality_score;//+------------------------------------------------------------------+struct CSSignal {

        default: prefix = "LOG"; break;

    }    string analysis_notes;

    

    string fullMessage = StringFormat("[%s] %s: %s", };//| Estruturas                                                       |    bool isValid;

                        TimeToString(TimeCurrent()), prefix, message);

    Print(fullMessage);

}

struct SetupScore//+------------------------------------------------------------------+    bool isAligned;

//+------------------------------------------------------------------+

//| Inicializar todos os handles dos indicadores                    |{

//+------------------------------------------------------------------+

bool InitializeIndicatorHandles(string symbol)    int traderMagicPoints;struct TMSignal    double baseStrength;

{

    WriteLog(1, "Inicializando handles dos indicadores para " + symbol);    int currencyStrengthPoints;

    

    string basePath = "Indicators\\NexusConfluenceEA\\";    int rsiomaPoints;{    double quoteStrength;

    

    // TrendMagic para todos os timeframes    int waePoints;

    g_handles.tm_h4 = iCustom(symbol, PERIOD_H4, basePath + TrendMagicIndicator, 

                             TM_CCI_Period, TM_ATR_Period, TM_ATR_Multiplier);    int totalPoints;    bool isValid;    bool isInverse;

    g_handles.tm_h1 = iCustom(symbol, PERIOD_H1, basePath + TrendMagicIndicator, 

                             TM_CCI_Period, TM_ATR_Period, TM_ATR_Multiplier);    int requiredPoints;

    g_handles.tm_m30 = iCustom(symbol, PERIOD_M30, basePath + TrendMagicIndicator, 

                              TM_CCI_Period, TM_ATR_Period, TM_ATR_Multiplier);    SETUP_CLASSIFICATION classification;    TRADE_DIRECTION direction;};

    g_handles.tm_m15 = iCustom(symbol, PERIOD_M15, basePath + TrendMagicIndicator, 

                              TM_CCI_Period, TM_ATR_Period, TM_ATR_Multiplier);    string reasoning;

    

    // Currency Strength apenas M15};    double strength;

    g_handles.cs_m15 = iCustom(symbol, PERIOD_M15, basePath + CurrencyStrengthIndicator,

                              CS_CalculationPeriod, CS_SmoothingPeriod, CS_ShowInPercent);

    

    // RSI OMA para todos os timeframes//+------------------------------------------------------------------+    int lastChangeBar;struct RSISignal {

    g_handles.rsi_h4 = iCustom(symbol, PERIOD_H4, basePath + RSIOMAIndicator,

                              RSI_Period, RSI_MA_Period, RSI_MA_Method, RSI_HighLevel, RSI_LowLevel, RSI_ShowLevels);//| Parâmetros de entrada                                            |

    g_handles.rsi_h1 = iCustom(symbol, PERIOD_H1, basePath + RSIOMAIndicator,

                              RSI_Period, RSI_MA_Period, RSI_MA_Method, RSI_HighLevel, RSI_LowLevel, RSI_ShowLevels);//+------------------------------------------------------------------+};    bool isValid;

    g_handles.rsi_m30 = iCustom(symbol, PERIOD_M30, basePath + RSIOMAIndicator,

                               RSI_Period, RSI_MA_Period, RSI_MA_Method, RSI_HighLevel, RSI_LowLevel, RSI_ShowLevels);input group "=== CONFIGURAÇÕES GERAIS ==="

    g_handles.rsi_m15 = iCustom(symbol, PERIOD_M15, basePath + RSIOMAIndicator,

                               RSI_Period, RSI_MA_Period, RSI_MA_Method, RSI_HighLevel, RSI_LowLevel, RSI_ShowLevels);input bool EnableAutoTrading = true;    bool isAligned;

    

    // WAE para todos os timeframesinput double AccountRiskPercent = 1.5;

    g_handles.wae_h4 = iCustom(symbol, PERIOD_H4, basePath + WAEIndicator,

                              WAE_FastMA, WAE_SlowMA, WAE_BBLength, WAE_BBMultiplier, WAE_Sensitivity);input int MaxSimultaneousTrades = 3;struct CSSignal    double redValue;

    g_handles.wae_h1 = iCustom(symbol, PERIOD_H1, basePath + WAEIndicator,

                              WAE_FastMA, WAE_SlowMA, WAE_BBLength, WAE_BBMultiplier, WAE_Sensitivity);input int LogLevel = 2;

    g_handles.wae_m30 = iCustom(symbol, PERIOD_M30, basePath + WAEIndicator,

                               WAE_FastMA, WAE_SlowMA, WAE_BBLength, WAE_BBMultiplier, WAE_Sensitivity);{    double blueValue;

    g_handles.wae_m15 = iCustom(symbol, PERIOD_M15, basePath + WAEIndicator,

                               WAE_FastMA, WAE_SlowMA, WAE_BBLength, WAE_BBMultiplier, WAE_Sensitivity);input group "=== INDICADORES - CAMINHOS CORRIGIDOS ==="

    

    // Verificar se todos os handles foram criados com sucessoinput string TrendMagicIndicator = "TrendMagic_MT5";    bool isValid;    double slope;

    if(g_handles.tm_h4 == INVALID_HANDLE || g_handles.tm_h1 == INVALID_HANDLE ||

       g_handles.tm_m30 == INVALID_HANDLE || g_handles.tm_m15 == INVALID_HANDLE ||input string CurrencyStrengthIndicator = "CurrencyStrengthMeter_MT5";

       g_handles.cs_m15 == INVALID_HANDLE ||

       g_handles.rsi_h4 == INVALID_HANDLE || g_handles.rsi_h1 == INVALID_HANDLE ||input string RSIOMAIndicator = "RSIOMA_v2HHLSX_MT5";    bool isAligned;};

       g_handles.rsi_m30 == INVALID_HANDLE || g_handles.rsi_m15 == INVALID_HANDLE ||

       g_handles.wae_h4 == INVALID_HANDLE || g_handles.wae_h1 == INVALID_HANDLE ||input string WAEIndicator = "WaddahAttarExplosion_Professional";

       g_handles.wae_m30 == INVALID_HANDLE || g_handles.wae_m15 == INVALID_HANDLE)

    {    double baseStrength;

        WriteLog(0, "ERRO: Falha ao criar um ou mais handles dos indicadores");

        return false;input group "=== ALERTAS ==="

    }

    input bool SendAlerts = true;    double quoteStrength;struct WAESignal {

    WriteLog(1, "Todos os handles dos indicadores criados com sucesso");

    return true;input bool EnableDetailedLogs = true;

}

input bool SaveTradeHistory = true;    bool isInverse;    bool isValid;

//+------------------------------------------------------------------+

//| Liberar todos os handles dos indicadores                        |

//+------------------------------------------------------------------+

void ReleaseIndicatorHandles()//+------------------------------------------------------------------+};    bool isAligned;

{

    WriteLog(1, "Liberando handles dos indicadores");//| Variáveis globais                                                |

    

    if(g_handles.tm_h4 != INVALID_HANDLE) IndicatorRelease(g_handles.tm_h4);//+------------------------------------------------------------------+    double mainValue;

    if(g_handles.tm_h1 != INVALID_HANDLE) IndicatorRelease(g_handles.tm_h1);

    if(g_handles.tm_m30 != INVALID_HANDLE) IndicatorRelease(g_handles.tm_m30);const int EA_MAGIC_NUMBER = 20241015;

    if(g_handles.tm_m15 != INVALID_HANDLE) IndicatorRelease(g_handles.tm_m15);

    CTrade trade;struct RSISignal    bool isExpanding;

    if(g_handles.cs_m15 != INVALID_HANDLE) IndicatorRelease(g_handles.cs_m15);

    bool g_InitializationComplete = false;

    if(g_handles.rsi_h4 != INVALID_HANDLE) IndicatorRelease(g_handles.rsi_h4);

    if(g_handles.rsi_h1 != INVALID_HANDLE) IndicatorRelease(g_handles.rsi_h1);{    bool hasStrength;

    if(g_handles.rsi_m30 != INVALID_HANDLE) IndicatorRelease(g_handles.rsi_m30);

    if(g_handles.rsi_m15 != INVALID_HANDLE) IndicatorRelease(g_handles.rsi_m15);//+------------------------------------------------------------------+

    

    if(g_handles.wae_h4 != INVALID_HANDLE) IndicatorRelease(g_handles.wae_h4);//| Função de log                                                    |    bool isValid;};

    if(g_handles.wae_h1 != INVALID_HANDLE) IndicatorRelease(g_handles.wae_h1);

    if(g_handles.wae_m30 != INVALID_HANDLE) IndicatorRelease(g_handles.wae_m30);//+------------------------------------------------------------------+

    if(g_handles.wae_m15 != INVALID_HANDLE) IndicatorRelease(g_handles.wae_m15);

}void WriteLog(int level, string message)    bool isAligned;



//+------------------------------------------------------------------+{

//| Obter handle do TrendMagic por timeframe                        |

//+------------------------------------------------------------------+    if(level > LogLevel) return;    double redValue;struct MultiTFResult {

int GetTrendMagicHandle(ENUM_TIMEFRAMES timeframe)

{    

    switch(timeframe)

    {    string prefix;    double blueValue;    bool isValid;

        case PERIOD_H4:  return g_handles.tm_h4;

        case PERIOD_H1:  return g_handles.tm_h1;    switch(level)

        case PERIOD_M30: return g_handles.tm_m30;

        case PERIOD_M15: return g_handles.tm_m15;    {    double slope;    bool H4_aligned;

        default: return INVALID_HANDLE;

    }        case 0: prefix = "ERROR"; break;

}

        case 1: prefix = "INFO"; break;};    bool H1_aligned;

//+------------------------------------------------------------------+

//| Obter handle do RSI OMA por timeframe                           |        case 2: prefix = "DEBUG"; break;

//+------------------------------------------------------------------+

int GetRSIHandle(ENUM_TIMEFRAMES timeframe)        case 3: prefix = "TRACE"; break;    bool M30_aligned;

{

    switch(timeframe)        default: prefix = "LOG"; break;

    {

        case PERIOD_H4:  return g_handles.rsi_h4;    }struct WAESignal    bool structure_valid;

        case PERIOD_H1:  return g_handles.rsi_h1;

        case PERIOD_M30: return g_handles.rsi_m30;    

        case PERIOD_M15: return g_handles.rsi_m15;

        default: return INVALID_HANDLE;    string fullMessage = StringFormat("[%s] %s: %s", {    TRADE_DIRECTION direction;

    }

}                        TimeToString(TimeCurrent()), prefix, message);



//+------------------------------------------------------------------+    Print(fullMessage);    bool isValid;    int quality_score;

//| Obter handle do WAE por timeframe                               |

//+------------------------------------------------------------------+}

int GetWAEHandle(ENUM_TIMEFRAMES timeframe)

{    bool isAligned;    string analysis_notes;

    switch(timeframe)

    {//+------------------------------------------------------------------+

        case PERIOD_H4:  return g_handles.wae_h4;

        case PERIOD_H1:  return g_handles.wae_h1;//| Função GetTraderMagicSignal - CAMINHO CORRIGIDO                 |    double mainValue;};

        case PERIOD_M30: return g_handles.wae_m30;

        case PERIOD_M15: return g_handles.wae_m15;//+------------------------------------------------------------------+

        default: return INVALID_HANDLE;

    }TMSignal GetTraderMagicSignal(string symbol, ENUM_TIMEFRAMES timeframe)    bool isExpanding;

}

{

//+------------------------------------------------------------------+

//| Função GetTraderMagicSignal - COM HANDLES CORRETOS              |    TMSignal signal;    bool hasStrength;struct SetupScore {

//+------------------------------------------------------------------+

TMSignal GetTraderMagicSignal(string symbol, ENUM_TIMEFRAMES timeframe)    ZeroMemory(signal);

{

    TMSignal signal;    };    int traderMagicPoints;

    ZeroMemory(signal);

        // CAMINHO CORRIGIDO: Indicators\NexusConfluenceEA\

    int handle = GetTrendMagicHandle(timeframe);

        string indicatorPath = "Indicators\\NexusConfluenceEA\\" + TrendMagicIndicator;    int currencyStrengthPoints;

    if(handle == INVALID_HANDLE)

    {    

        WriteLog(0, StringFormat("ERRO: Handle TM inválido para %s", EnumToString(timeframe)));

        signal.isValid = false;    WriteLog(3, StringFormat("Carregando TM: %s", indicatorPath));struct MultiTFResult    int rsiomaPoints;

        return signal;

    }    

    

    double tmUp[], tmDown[];    int tmHandle = iCustom(symbol, timeframe, indicatorPath, 14, 2.0, true, true, false);{    int waePoints;

    ArraySetAsSeries(tmUp, true);

    ArraySetAsSeries(tmDown, true);    

    

    if(CopyBuffer(handle, 0, 0, 3, tmUp) < 3 ||    if(tmHandle == INVALID_HANDLE)    bool isValid;    int totalPoints;

       CopyBuffer(handle, 1, 0, 3, tmDown) < 3)

    {    {

        WriteLog(0, "ERRO: Falha ao copiar buffers TM");

        signal.isValid = false;        WriteLog(0, StringFormat("ERRO: Handle TM inválido - Caminho: %s", indicatorPath));    bool H4_aligned;    int requiredPoints;

        return signal;

    }        signal.isValid = false;

    

    signal.isValid = true;        return signal;    bool H1_aligned;    SETUP_CLASSIFICATION classification;

    

    // Análise da mudança de cor    }

    bool currentBullish = (tmUp[0] != EMPTY_VALUE && tmDown[0] == EMPTY_VALUE);

    bool currentBearish = (tmDown[0] != EMPTY_VALUE && tmUp[0] == EMPTY_VALUE);        bool M30_aligned;    string reasoning;

    

    if(currentBullish)    double tmUp[], tmDown[];

    {

        signal.direction = TRADE_BUY;    ArraySetAsSeries(tmUp, true);    bool structure_valid;};

        signal.strength = 0.8;

    }    ArraySetAsSeries(tmDown, true);

    else if(currentBearish)

    {        TRADE_DIRECTION direction;

        signal.direction = TRADE_SELL;

        signal.strength = 0.8;    if(CopyBuffer(tmHandle, 0, 0, 3, tmUp) < 3 ||

    }

    else       CopyBuffer(tmHandle, 1, 0, 3, tmDown) < 3)    int quality_score;//+------------------------------------------------------------------+

    {

        signal.direction = TRADE_NONE;    {

        signal.strength = 0.0;

    }        WriteLog(0, "ERRO: Falha ao copiar buffers TM");    string analysis_notes;//| PARÂMETROS DE ENTRADA                                            |

    

    WriteLog(3, StringFormat("TM %s %s: %s (força=%.2f)",         IndicatorRelease(tmHandle);

        symbol, EnumToString(timeframe), EnumToString(signal.direction), signal.strength));

            signal.isValid = false;};//+------------------------------------------------------------------+

    return signal;

}        return signal;



//+------------------------------------------------------------------+    }

//| Função GetCurrencyStrengthSignal - COM HANDLES CORRETOS         |

//+------------------------------------------------------------------+    

CSSignal GetCurrencyStrengthSignal(string symbol, TRADE_DIRECTION direction, ASSET_CLASS assetType)

{    signal.isValid = true;struct SetupScoreinput group "=== CONFIGURAÇÕES GERAIS ==="

    CSSignal signal;

    ZeroMemory(signal);    

    

    // CS só para Forex, WDO e Metais    // Análise da mudança de cor{input bool EnableAutoTrading = true;

    if(assetType != FOREX_MAJOR && assetType != FOREX_MINOR && 

       assetType != FOREX_EXOTIC && assetType != CURRENCY_B3 && assetType != METALS)    bool currentBullish = (tmUp[0] != EMPTY_VALUE && tmDown[0] == EMPTY_VALUE);

    {

        signal.isValid = false;    bool currentBearish = (tmDown[0] != EMPTY_VALUE && tmUp[0] == EMPTY_VALUE);    int traderMagicPoints;input double AccountRiskPercent = 1.5;

        return signal;

    }    

    

    if(g_handles.cs_m15 == INVALID_HANDLE)    if(currentBullish)    int currencyStrengthPoints;input int MaxSimultaneousTrades = 3;

    {

        WriteLog(0, "ERRO: Handle CS inválido");    {

        signal.isValid = false;

        return signal;        signal.direction = TRADE_BUY;    int rsiomaPoints;input int LogLevel = 2;

    }

            signal.strength = 0.8;

    double csBuffer[];

    ArraySetAsSeries(csBuffer, true);    }    int waePoints;

    

    if(CopyBuffer(g_handles.cs_m15, 0, 0, 3, csBuffer) < 3)    else if(currentBearish)

    {

        WriteLog(0, "ERRO: Falha ao copiar buffer CS");    {    int totalPoints;input group "=== INDICADORES ==="

        signal.isValid = false;

        return signal;        signal.direction = TRADE_SELL;

    }

            signal.strength = 0.8;    int requiredPoints;input string TrendMagicIndicator = "TrendMagic_MT5";

    signal.isValid = true;

    signal.baseStrength = csBuffer[0];    }

    signal.quoteStrength = (ArraySize(csBuffer) > 1) ? csBuffer[1] : csBuffer[0];

    signal.isInverse = (assetType == METALS);    else    SETUP_CLASSIFICATION classification;input string CurrencyStrengthIndicator = "CurrencyStrengthMeter_MT5";

    

    if(signal.isInverse)    {

    {

        signal.isAligned = (direction == TRADE_BUY) ?         signal.direction = TRADE_NONE;    string reasoning;input string RSIOMAIndicator = "RSIOMA_v2HHLSX_MT5";

            (signal.quoteStrength < signal.baseStrength) : 

            (signal.quoteStrength > signal.baseStrength);        signal.strength = 0.0;

    }

    else    }};input string WAEIndicator = "WaddahAttarExplosion_Professional";

    {

        signal.isAligned = (direction == TRADE_BUY) ?     

            (signal.baseStrength > signal.quoteStrength) : 

            (signal.baseStrength < signal.quoteStrength);    IndicatorRelease(tmHandle);

    }

        WriteLog(3, StringFormat("TM %s: %s (força=%.2f)", 

    WriteLog(3, StringFormat("CS: Base=%.2f Quote=%.2f Alinhado=%s", 

        signal.baseStrength, signal.quoteStrength, signal.isAligned ? "SIM" : "NÃO"));        symbol, EnumToString(signal.direction), signal.strength));//+------------------------------------------------------------------+input group "=== ALERTAS ==="

    

    return signal;    

}

    return signal;//| Parâmetros de entrada                                            |input bool SendAlerts = true;

//+------------------------------------------------------------------+

//| Função GetRSIOMASignal - COM HANDLES CORRETOS                   |}

//+------------------------------------------------------------------+

RSISignal GetRSIOMASignal(string symbol, ENUM_TIMEFRAMES timeframe, TRADE_DIRECTION direction)//+------------------------------------------------------------------+input bool EnableDetailedLogs = true;

{

    RSISignal signal;//+------------------------------------------------------------------+

    ZeroMemory(signal);

    //| Função GetCurrencyStrengthSignal - CAMINHO CORRIGIDO            |input group "=== CONFIGURAÇÕES GERAIS ==="input bool SaveTradeHistory = true;

    int handle = GetRSIHandle(timeframe);

    //+------------------------------------------------------------------+

    if(handle == INVALID_HANDLE)

    {CSSignal GetCurrencyStrengthSignal(string symbol, TRADE_DIRECTION direction, ASSET_CLASS assetType)input bool EnableAutoTrading = true;

        WriteLog(0, StringFormat("ERRO: Handle RSI inválido para %s", EnumToString(timeframe)));

        signal.isValid = false;{

        return signal;

    }    CSSignal signal;input double AccountRiskPercent = 1.5;//+------------------------------------------------------------------+

    

    double rsiRed[], rsiBlue[];    ZeroMemory(signal);

    ArraySetAsSeries(rsiRed, true);

    ArraySetAsSeries(rsiBlue, true);    input int MaxSimultaneousTrades = 3;//| VARIÁVEIS GLOBAIS                                                |

    

    if(CopyBuffer(handle, 0, 0, 3, rsiRed) < 3 ||    // CS só para Forex, WDO e Metais

       CopyBuffer(handle, 1, 0, 3, rsiBlue) < 3)

    {    if(assetType != FOREX_MAJOR && assetType != FOREX_MINOR && input int LogLevel = 2;//+------------------------------------------------------------------+

        WriteLog(0, "ERRO: Falha ao copiar buffers RSI");

        signal.isValid = false;       assetType != FOREX_EXOTIC && assetType != CURRENCY_B3 && assetType != METALS)

        return signal;

    }    {

    

    signal.isValid = true;        signal.isValid = false;

    signal.redValue = rsiRed[0];

    signal.blueValue = rsiBlue[0];        return signal;input group "=== INDICADORES ==="bool g_InitializationComplete = false;

    signal.slope = (rsiRed[0] - rsiRed[2]) * 50.0;

        }

    if(direction == TRADE_BUY)

    {    input string TrendMagicIndicator = "TrendMagic_MT5";

        signal.isAligned = (signal.redValue > signal.blueValue) && (signal.slope > 0.1);

    }    // CAMINHO CORRIGIDO

    else

    {    string indicatorPath = "Indicators\\NexusConfluenceEA\\" + CurrencyStrengthIndicator;input string CurrencyStrengthIndicator = "CurrencyStrengthMeter_MT5";//+------------------------------------------------------------------+

        signal.isAligned = (signal.redValue < signal.blueValue) && (signal.slope < -0.1);

    }    

    

    WriteLog(3, StringFormat("RSI %s: Red=%.2f Blue=%.2f Slope=%.2f Alinhado=%s",     WriteLog(3, StringFormat("Carregando CS: %s", indicatorPath));input string RSIOMAIndicator = "RSIOMA_v2HHLSX_MT5";//| FUNÇÕES DE LOG                                                   |

        EnumToString(timeframe), signal.redValue, signal.blueValue, signal.slope, signal.isAligned ? "SIM" : "NÃO"));

        

    return signal;

}    int csHandle = iCustom(symbol, PERIOD_M15, indicatorPath);input string WAEIndicator = "WaddahAttarExplosion_Professional";//+------------------------------------------------------------------+



//+------------------------------------------------------------------+    

//| Função GetWAESignal - COM HANDLES CORRETOS                      |

//+------------------------------------------------------------------+    if(csHandle == INVALID_HANDLE)

WAESignal GetWAESignal(string symbol, ENUM_TIMEFRAMES timeframe, TRADE_DIRECTION direction)

{    {

    WAESignal signal;

    ZeroMemory(signal);        WriteLog(0, StringFormat("ERRO: Handle CS inválido - Caminho: %s", indicatorPath));input group "=== ALERTAS ==="void WriteLog(int level, string message) {

    

    int handle = GetWAEHandle(timeframe);        signal.isValid = false;

    

    if(handle == INVALID_HANDLE)        return signal;input bool SendAlerts = true;    if (level > LogLevel) return;

    {

        WriteLog(0, StringFormat("ERRO: Handle WAE inválido para %s", EnumToString(timeframe)));    }

        signal.isValid = false;

        return signal;    input bool EnableDetailedLogs = true;    

    }

        double csBuffer[];

    double waeMain[];

    ArraySetAsSeries(waeMain, true);    ArraySetAsSeries(csBuffer, true);input bool SaveTradeHistory = true;    string prefix;

    

    if(CopyBuffer(handle, 0, 0, 3, waeMain) < 3)    

    {

        WriteLog(0, "ERRO: Falha ao copiar buffer WAE");    if(CopyBuffer(csHandle, 0, 0, 3, csBuffer) < 3)    switch (level) {

        signal.isValid = false;

        return signal;    {

    }

            WriteLog(0, "ERRO: Falha ao copiar buffer CS");//+------------------------------------------------------------------+        case 0: prefix = "ERROR"; break;

    signal.isValid = true;

    signal.mainValue = waeMain[0];        IndicatorRelease(csHandle);

    signal.isExpanding = (MathAbs(waeMain[0]) > MathAbs(waeMain[1]));

    signal.hasStrength = (MathAbs(signal.mainValue) > 10.0);        signal.isValid = false;//| Variáveis globais                                                |        case 1: prefix = "INFO"; break;  

    

    if(direction == TRADE_BUY)        return signal;

    {

        signal.isAligned = (signal.mainValue > 0) && signal.isExpanding && signal.hasStrength;    }//+------------------------------------------------------------------+        case 2: prefix = "DEBUG"; break;

    }

    else    

    {

        signal.isAligned = (signal.mainValue < 0) && signal.isExpanding && signal.hasStrength;    signal.isValid = true;const int EA_MAGIC_NUMBER = 20241015;        case 3: prefix = "TRACE"; break;

    }

        signal.baseStrength = csBuffer[0];

    WriteLog(3, StringFormat("WAE %s: Main=%.2f Expandindo=%s Força=%s Alinhado=%s", 

        EnumToString(timeframe), signal.mainValue, signal.isExpanding ? "SIM" : "NÃO",     signal.quoteStrength = (ArraySize(csBuffer) > 1) ? csBuffer[1] : csBuffer[0];CTrade trade;        default: prefix = "LOG"; break;

        signal.hasStrength ? "SIM" : "NÃO", signal.isAligned ? "SIM" : "NÃO"));

        signal.isInverse = (assetType == METALS);

    return signal;

}    bool g_InitializationComplete = false;    }



//+------------------------------------------------------------------+    if(signal.isInverse)

//| Análise Multi-Timeframe                                         |

//+------------------------------------------------------------------+    {    

MultiTFResult AnalyzeTimeframes(string symbol, TRADE_DIRECTION direction)

{        signal.isAligned = (direction == TRADE_BUY) ? 

    MultiTFResult result;

    ZeroMemory(result);            (signal.quoteStrength < signal.baseStrength) : //+------------------------------------------------------------------+    string fullMessage = StringFormat("[%s] %s: %s", 

    

    WriteLog(3, StringFormat("Analisando MTF para %s direção %s", symbol, EnumToString(direction)));            (signal.quoteStrength > signal.baseStrength);

    

    TMSignal tmH4 = GetTraderMagicSignal(symbol, PERIOD_H4);    }//| Função de log                                                    |                        TimeToString(TimeCurrent()), prefix, message);

    TMSignal tmH1 = GetTraderMagicSignal(symbol, PERIOD_H1);

    TMSignal tmM30 = GetTraderMagicSignal(symbol, PERIOD_M30);    else

    

    result.H4_aligned = (tmH4.isValid && tmH4.direction == direction);    {//+------------------------------------------------------------------+    Print(fullMessage);

    result.H1_aligned = (tmH1.isValid && tmH1.direction == direction);

    result.M30_aligned = (tmM30.isValid && tmM30.direction == direction);        signal.isAligned = (direction == TRADE_BUY) ? 

    

    result.structure_valid = true;            (signal.baseStrength > signal.quoteStrength) : void WriteLog(int level, string message)}

    result.direction = direction;

    result.isValid = result.H4_aligned && result.H1_aligned;            (signal.baseStrength < signal.quoteStrength);

    

    result.quality_score = 0;    }{

    if(result.H4_aligned) result.quality_score++;

    if(result.H1_aligned) result.quality_score++;    

    if(result.M30_aligned) result.quality_score++;

    if(result.structure_valid) result.quality_score++;    IndicatorRelease(csHandle);    if(level > LogLevel) return;//+------------------------------------------------------------------+

    

    result.analysis_notes = StringFormat("H4:%s H1:%s M30:%s Score:%d",     WriteLog(3, StringFormat("CS: Base=%.2f Quote=%.2f Alinhado=%s", 

        result.H4_aligned ? "OK" : "FAIL",

        result.H1_aligned ? "OK" : "FAIL",         signal.baseStrength, signal.quoteStrength, signal.isAligned ? "SIM" : "NÃO"));    //| FUNÇÕES DOS INDICADORES - CAMINHOS CORRIGIDOS                   |

        result.M30_aligned ? "OK" : "WEAK",

        result.quality_score);    

    

    WriteLog(2, StringFormat("MTF %s: %s", symbol, result.analysis_notes));    return signal;    string prefix;//+------------------------------------------------------------------+

    

    return result;}

}

    switch(level)

//+------------------------------------------------------------------+

//| Classificação de ativos                                          |//+------------------------------------------------------------------+

//+------------------------------------------------------------------+

ASSET_CLASS ClassifyAsset(string symbol)//| Função GetRSIOMASignal - CAMINHO CORRIGIDO                      |    {TMSignal GetTraderMagicSignal(string symbol, ENUM_TIMEFRAMES timeframe)

{

    if(symbol == "EURUSD" || symbol == "GBPUSD" || symbol == "USDJPY" || //+------------------------------------------------------------------+

       symbol == "AUDUSD" || symbol == "USDCAD" || symbol == "NZDUSD")

    {RSISignal GetRSIOMASignal(string symbol, ENUM_TIMEFRAMES timeframe, TRADE_DIRECTION direction)        case 0: prefix = "ERROR"; break;{

        return FOREX_MAJOR;

    }{

    if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "XAG") >= 0)

    {    RSISignal signal;        case 1: prefix = "INFO"; break;    TMSignal signal;

        return METALS;

    }    ZeroMemory(signal);

    return FOREX_MAJOR;

}            case 2: prefix = "DEBUG"; break;    ZeroMemory(signal);



//+------------------------------------------------------------------+    // CAMINHO CORRIGIDO

//| Sistema de pontuação                                             |

//+------------------------------------------------------------------+    string indicatorPath = "Indicators\\NexusConfluenceEA\\" + RSIOMAIndicator;        case 3: prefix = "TRACE"; break;    

SetupScore CalculateSetupScore(string symbol, ASSET_CLASS assetType, TRADE_DIRECTION direction)

{    

    SetupScore score;

    ZeroMemory(score);    WriteLog(3, StringFormat("Carregando RSI: %s", indicatorPath));        default: prefix = "LOG"; break;    // CAMINHO CORRIGIDO - Indicadores agora estão em Indicators\NexusConfluenceEA\

    

    WriteLog(3, StringFormat("Calculando score para %s %s", symbol, EnumToString(direction)));    

    

    // 1. Trader Magic (obrigatório)    int rsiHandle = iCustom(symbol, timeframe, indicatorPath);    }    string indicatorPath = "Indicators\\NexusConfluenceEA\\" + TrendMagicIndicator + ".ex5";

    TMSignal tm = GetTraderMagicSignal(symbol, PERIOD_M15);

    if(tm.isValid && tm.direction == direction)    

    {

        score.traderMagicPoints = 1;    if(rsiHandle == INVALID_HANDLE)        

    }

        {

    // 2. Currency Strength (se aplicável)

    CSSignal cs = GetCurrencyStrengthSignal(symbol, direction, assetType);        WriteLog(0, StringFormat("ERRO: Handle RSI inválido - Caminho: %s", indicatorPath));    string fullMessage = StringFormat("[%s] %s: %s",     WriteLog(3, StringFormat("Carregando TM: %s", indicatorPath));

    if(cs.isValid && cs.isAligned)

    {        signal.isValid = false;

        score.currencyStrengthPoints = 1;

    }        return signal;                        TimeToString(TimeCurrent()), prefix, message);    

    

    // 3. RSI OMA    }

    RSISignal rsi = GetRSIOMASignal(symbol, PERIOD_M15, direction);

    if(rsi.isValid && rsi.isAligned)        Print(fullMessage);    int tmHandle = iCustom(symbol, timeframe, indicatorPath, 14, 2.0, true, true, false);

    {

        score.rsiomaPoints = 1;    double rsiRed[], rsiBlue[];

    }

        ArraySetAsSeries(rsiRed, true);}    

    // 4. WAE

    WAESignal wae = GetWAESignal(symbol, PERIOD_M15, direction);    ArraySetAsSeries(rsiBlue, true);

    if(wae.isValid && wae.isAligned)

    {        if(tmHandle == INVALID_HANDLE)

        score.waePoints = 1;

    }    if(CopyBuffer(rsiHandle, 0, 0, 3, rsiRed) < 3 ||

    

    score.totalPoints = score.traderMagicPoints + score.currencyStrengthPoints +        CopyBuffer(rsiHandle, 1, 0, 3, rsiBlue) < 3)//+------------------------------------------------------------------+    {

                       score.rsiomaPoints + score.waePoints;

        {

    // Classificação conforme tipo de ativo

    if(assetType == FOREX_MAJOR || assetType == FOREX_MINOR ||         WriteLog(0, "ERRO: Falha ao copiar buffers RSI");//| Função para obter sinal do Trader Magic                         |        WriteLog(0, StringFormat("ERRO: Handle TM inválido para %s %s - Caminho: %s", 

       assetType == FOREX_EXOTIC || assetType == CURRENCY_B3 || assetType == METALS)

    {        IndicatorRelease(rsiHandle);

        score.requiredPoints = 2;

        if(score.totalPoints >= 3) score.classification = PREMIUM;        signal.isValid = false;//+------------------------------------------------------------------+            symbol, EnumToString(timeframe), indicatorPath));

        else if(score.totalPoints >= 2) score.classification = GOOD;

        else score.classification = REJECT;        return signal;

    }

    else    }TMSignal GetTraderMagicSignal(string symbol, ENUM_TIMEFRAMES timeframe)        signal.isValid = false;

    {

        score.requiredPoints = 2;    

        if(score.rsiomaPoints + score.waePoints >= 2) score.classification = PREMIUM;

        else score.classification = REJECT;    signal.isValid = true;{        return signal;

    }

        signal.redValue = rsiRed[0];

    score.reasoning = StringFormat("TM:%d CS:%d RSI:%d WAE:%d = %d pontos - %s",

        score.traderMagicPoints, score.currencyStrengthPoints,     signal.blueValue = rsiBlue[0];    TMSignal signal;    }

        score.rsiomaPoints, score.waePoints,

        score.totalPoints, EnumToString(score.classification));    signal.slope = (rsiRed[0] - rsiRed[2]) * 50.0;

    

    return score;        ZeroMemory(signal);    

}

    if(direction == TRADE_BUY)

//+------------------------------------------------------------------+

//| Funções auxiliares                                               |    {        double tmUp[], tmDown[];

//+------------------------------------------------------------------+

string EnumToString(ASSET_CLASS assetClass)        signal.isAligned = (signal.redValue > signal.blueValue) && (signal.slope > 0.1);

{

    switch(assetClass)    }    // CAMINHO CORRIGIDO: Indicators\NexusConfluenceEA\    ArraySetAsSeries(tmUp, true);

    {

        case FOREX_MAJOR: return "FOREX_MAJOR";    else

        case FOREX_MINOR: return "FOREX_MINOR";

        case METALS: return "METALS";    {    string indicatorPath = "Indicators\\NexusConfluenceEA\\" + TrendMagicIndicator;    ArraySetAsSeries(tmDown, true);

        default: return "UNKNOWN";

    }        signal.isAligned = (signal.redValue < signal.blueValue) && (signal.slope < -0.1);

}

    }        

string EnumToString(TRADE_DIRECTION direction)

{    

    switch(direction)

    {    IndicatorRelease(rsiHandle);    WriteLog(3, StringFormat("Carregando TM: %s", indicatorPath));    if(CopyBuffer(tmHandle, 0, 0, 3, tmUp) < 3 ||

        case TRADE_BUY: return "BUY";

        case TRADE_SELL: return "SELL";    WriteLog(3, StringFormat("RSI: Red=%.2f Blue=%.2f Slope=%.2f Alinhado=%s", 

        default: return "NONE";

    }        signal.redValue, signal.blueValue, signal.slope, signal.isAligned ? "SIM" : "NÃO"));           CopyBuffer(tmHandle, 1, 0, 3, tmDown) < 3)

}

    

string EnumToString(SETUP_CLASSIFICATION classification)

{    return signal;    int tmHandle = iCustom(symbol, timeframe, indicatorPath, 14, 2.0, true, true, false);    {

    switch(classification)

    {}

        case PREMIUM: return "PREMIUM";

        case GOOD: return "GOOD";            WriteLog(0, "ERRO: Falha ao copiar buffers TM");

        default: return "REJECT";

    }//+------------------------------------------------------------------+

}

//| Função GetWAESignal - CAMINHO CORRIGIDO                         |    if(tmHandle == INVALID_HANDLE)        IndicatorRelease(tmHandle);

bool IsSetupValid(SetupScore score)

{//+------------------------------------------------------------------+

    return (score.classification == PREMIUM || score.classification == GOOD);

}WAESignal GetWAESignal(string symbol, ENUM_TIMEFRAMES timeframe, TRADE_DIRECTION direction)    {        signal.isValid = false;



//+------------------------------------------------------------------+{

//| Expert initialization function                                   |

//+------------------------------------------------------------------+    WAESignal signal;        WriteLog(0, StringFormat("ERRO: Handle TM inválido para %s %s - Caminho: %s",         return signal;

int OnInit()

{    ZeroMemory(signal);

    WriteLog(1, "=== INICIALIZANDO NEXUS CONFLUENCE EA v4.0 ===");

                    symbol, EnumToString(timeframe), indicatorPath));    }

    WriteLog(1, "PARÂMETROS DOS INDICADORES:");

    WriteLog(1, StringFormat("- TrendMagic: CCI=%d, ATR=%d, Mult=%.1f", TM_CCI_Period, TM_ATR_Period, TM_ATR_Multiplier));    // CAMINHO CORRIGIDO

    WriteLog(1, StringFormat("- CurrencyStrength: Calc=%d, Smooth=%d", CS_CalculationPeriod, CS_SmoothingPeriod));

    WriteLog(1, StringFormat("- RSI OMA: Period=%d, MA=%d", RSI_Period, RSI_MA_Period));    string indicatorPath = "Indicators\\NexusConfluenceEA\\" + WAEIndicator;        signal.isValid = false;    

    WriteLog(1, StringFormat("- WAE: Fast=%d, Slow=%d, BB=%d", WAE_FastMA, WAE_SlowMA, WAE_BBLength));

        

    // Inicializar handles dos indicadores

    if(!InitializeIndicatorHandles(_Symbol))    WriteLog(3, StringFormat("Carregando WAE: %s", indicatorPath));        return signal;    signal.isValid = true;

    {

        WriteLog(0, "ERRO: Falha ao inicializar handles dos indicadores");    

        return INIT_FAILED;

    }    int waeHandle = iCustom(symbol, timeframe, indicatorPath);    }    

    

    trade.SetExpertMagicNumber(EA_MAGIC_NUMBER);    

    g_InitializationComplete = true;

        if(waeHandle == INVALID_HANDLE)        // Análise simplificada da mudança de cor

    WriteLog(1, "EA inicializado com sucesso!");

        {

    if(SendAlerts)

    {        WriteLog(0, StringFormat("ERRO: Handle WAE inválido - Caminho: %s", indicatorPath));    double tmUp[], tmDown[];    bool currentBullish = (tmUp[0] != EMPTY_VALUE && tmDown[0] == EMPTY_VALUE);

        SendNotification("Nexus Confluence EA v4.0 iniciado em " + _Symbol);

    }        signal.isValid = false;

    

    return(INIT_SUCCEEDED);        return signal;    ArraySetAsSeries(tmUp, true);    bool currentBearish = (tmDown[0] != EMPTY_VALUE && tmUp[0] == EMPTY_VALUE);

}

    }

//+------------------------------------------------------------------+

//| Expert deinitialization function                                 |        ArraySetAsSeries(tmDown, true);    

//+------------------------------------------------------------------+

void OnDeinit(const int reason)    double waeMain[];

{

    WriteLog(1, "=== FINALIZANDO NEXUS CONFLUENCE EA ===");    ArraySetAsSeries(waeMain, true);        if(currentBullish) {

    WriteLog(1, "Razão: " + IntegerToString(reason));

        

    // Liberar todos os handles

    ReleaseIndicatorHandles();    if(CopyBuffer(waeHandle, 0, 0, 3, waeMain) < 3)    if(CopyBuffer(tmHandle, 0, 0, 3, tmUp) < 3 ||        signal.direction = TRADE_BUY;

    

    if(SendAlerts)    {

    {

        SendNotification("Nexus Confluence EA finalizado");        WriteLog(0, "ERRO: Falha ao copiar buffer WAE");       CopyBuffer(tmHandle, 1, 0, 3, tmDown) < 3)        signal.strength = 0.8;

    }

}        IndicatorRelease(waeHandle);



//+------------------------------------------------------------------+        signal.isValid = false;    {    }

//| Expert tick function                                             |

//+------------------------------------------------------------------+        return signal;

void OnTick()

{    }        WriteLog(0, "ERRO: Falha ao copiar buffers TM");    else if(currentBearish) {

    if(!g_InitializationComplete) return;

        

    static datetime lastTest = 0;

    if(TimeCurrent() - lastTest >= 60)    signal.isValid = true;        IndicatorRelease(tmHandle);        signal.direction = TRADE_SELL;

    {

        lastTest = TimeCurrent();    signal.mainValue = waeMain[0];

        

        ASSET_CLASS assetType = ClassifyAsset(_Symbol);    signal.isExpanding = (MathAbs(waeMain[0]) > MathAbs(waeMain[1]));        signal.isValid = false;        signal.strength = 0.8;

        

        SetupScore scoreBuy = CalculateSetupScore(_Symbol, assetType, TRADE_BUY);    signal.hasStrength = (MathAbs(signal.mainValue) > 10.0);

        SetupScore scoreSell = CalculateSetupScore(_Symbol, assetType, TRADE_SELL);

                    return signal;    }

        WriteLog(1, StringFormat("=== ANÁLISE %s ===", _Symbol));

        WriteLog(1, "BUY: " + scoreBuy.reasoning);    if(direction == TRADE_BUY)

        WriteLog(1, "SELL: " + scoreSell.reasoning);

            {    }    else {

        if(IsSetupValid(scoreBuy))

        {        signal.isAligned = (signal.mainValue > 0) && signal.isExpanding && signal.hasStrength;

            WriteLog(0, StringFormat("*** SETUP BUY VÁLIDO: %s ***", scoreBuy.reasoning));

            if(SendAlerts)    }            signal.direction = TRADE_NONE;

            {

                SendNotification(StringFormat("Nexus: Setup BUY %s - %s", _Symbol, EnumToString(scoreBuy.classification)));    else

            }

        }    {    signal.isValid = true;        signal.strength = 0.0;

        

        if(IsSetupValid(scoreSell))        signal.isAligned = (signal.mainValue < 0) && signal.isExpanding && signal.hasStrength;

        {

            WriteLog(0, StringFormat("*** SETUP SELL VÁLIDO: %s ***", scoreSell.reasoning));    }        }

            if(SendAlerts)

            {    

                SendNotification(StringFormat("Nexus: Setup SELL %s - %s", _Symbol, EnumToString(scoreSell.classification)));

            }    IndicatorRelease(waeHandle);    // Análise da mudança de cor    

        }

    }    WriteLog(3, StringFormat("WAE: Main=%.2f Expandindo=%s Força=%s Alinhado=%s", 

}

//+------------------------------------------------------------------+        signal.mainValue, signal.isExpanding ? "SIM" : "NÃO",     bool currentBullish = (tmUp[0] != EMPTY_VALUE && tmDown[0] == EMPTY_VALUE);    signal.lastChangeBar = 0;

        signal.hasStrength ? "SIM" : "NÃO", signal.isAligned ? "SIM" : "NÃO"));

        bool currentBearish = (tmDown[0] != EMPTY_VALUE && tmUp[0] == EMPTY_VALUE);    

    return signal;

}        IndicatorRelease(tmHandle);



//+------------------------------------------------------------------+    if(currentBullish)    WriteLog(3, StringFormat("TM %s %s: %s (força=%.2f)", 

//| Análise Multi-Timeframe                                         |

//+------------------------------------------------------------------+    {        symbol, EnumToString(timeframe), EnumToString(signal.direction), signal.strength));

MultiTFResult AnalyzeTimeframes(string symbol, TRADE_DIRECTION direction)

{        signal.direction = TRADE_BUY;    

    MultiTFResult result;

    ZeroMemory(result);        signal.strength = 0.8;    return signal;

    

    WriteLog(3, StringFormat("Analisando MTF para %s direção %s", symbol, EnumToString(direction)));    }}

    

    TMSignal tmH4 = GetTraderMagicSignal(symbol, PERIOD_H4);    else if(currentBearish)

    TMSignal tmH1 = GetTraderMagicSignal(symbol, PERIOD_H1);

    TMSignal tmM30 = GetTraderMagicSignal(symbol, PERIOD_M30);    {CSSignal GetCurrencyStrengthSignal(string symbol, TRADE_DIRECTION direction, ASSET_CLASS assetType)

    

    result.H4_aligned = (tmH4.isValid && tmH4.direction == direction);        signal.direction = TRADE_SELL;{

    result.H1_aligned = (tmH1.isValid && tmH1.direction == direction);

    result.M30_aligned = (tmM30.isValid && tmM30.direction == direction);        signal.strength = 0.8;    CSSignal signal;

    

    result.structure_valid = true;    }    ZeroMemory(signal);

    result.direction = direction;

    result.isValid = result.H4_aligned && result.H1_aligned;    else    

    

    result.quality_score = 0;    {    // CS só para Forex, WDO e Metais

    if(result.H4_aligned) result.quality_score++;

    if(result.H1_aligned) result.quality_score++;        signal.direction = TRADE_NONE;    if(assetType != FOREX_MAJOR && assetType != FOREX_MINOR && 

    if(result.M30_aligned) result.quality_score++;

    if(result.structure_valid) result.quality_score++;        signal.strength = 0.0;       assetType != FOREX_EXOTIC && assetType != CURRENCY_B3 && assetType != METALS)

    

    result.analysis_notes = StringFormat("H4:%s H1:%s M30:%s Score:%d",     }    {

        result.H4_aligned ? "OK" : "FAIL",

        result.H1_aligned ? "OK" : "FAIL",             signal.isValid = false;

        result.M30_aligned ? "OK" : "WEAK",

        result.quality_score);    signal.lastChangeBar = 0;        return signal;

    

    WriteLog(2, StringFormat("MTF %s: %s", symbol, result.analysis_notes));        }

    

    return result;    IndicatorRelease(tmHandle);    

}

    WriteLog(3, StringFormat("TM %s %s: %s (força=%.2f)",     // CAMINHO CORRIGIDO

//+------------------------------------------------------------------+

//| Classificação de ativos                                          |        symbol, EnumToString(timeframe), EnumToString(signal.direction), signal.strength));    string indicatorPath = "Indicators\\NexusConfluenceEA\\" + CurrencyStrengthIndicator + ".ex5";

//+------------------------------------------------------------------+

ASSET_CLASS ClassifyAsset(string symbol)        

{

    if(symbol == "EURUSD" || symbol == "GBPUSD" || symbol == "USDJPY" ||     return signal;    WriteLog(3, StringFormat("Carregando CS: %s", indicatorPath));

       symbol == "AUDUSD" || symbol == "USDCAD" || symbol == "NZDUSD")

    {}    

        return FOREX_MAJOR;

    }    int csHandle = iCustom(symbol, PERIOD_M15, indicatorPath);

    if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "XAG") >= 0)

    {//+------------------------------------------------------------------+    

        return METALS;

    }//| Função para obter sinal do Currency Strength                    |    if(csHandle == INVALID_HANDLE)

    return FOREX_MAJOR;

}//+------------------------------------------------------------------+    {



//+------------------------------------------------------------------+CSSignal GetCurrencyStrengthSignal(string symbol, TRADE_DIRECTION direction, ASSET_CLASS assetType)        WriteLog(0, StringFormat("ERRO: Handle CS inválido - Caminho: %s", indicatorPath));

//| Sistema de pontuação                                             |

//+------------------------------------------------------------------+{        signal.isValid = false;

SetupScore CalculateSetupScore(string symbol, ASSET_CLASS assetType, TRADE_DIRECTION direction)

{    CSSignal signal;        return signal;

    SetupScore score;

    ZeroMemory(score);    ZeroMemory(signal);    }

    

    WriteLog(3, StringFormat("Calculando score para %s %s", symbol, EnumToString(direction)));        

    

    // 1. Trader Magic (obrigatório)    // CS só para Forex, WDO e Metais    double csBuffer[];

    TMSignal tm = GetTraderMagicSignal(symbol, PERIOD_M15);

    if(tm.isValid && tm.direction == direction)    if(assetType != FOREX_MAJOR && assetType != FOREX_MINOR &&     ArraySetAsSeries(csBuffer, true);

    {

        score.traderMagicPoints = 1;       assetType != FOREX_EXOTIC && assetType != CURRENCY_B3 && assetType != METALS)    

    }

        {    if(CopyBuffer(csHandle, 0, 0, 3, csBuffer) < 3)

    // 2. Currency Strength (se aplicável)

    CSSignal cs = GetCurrencyStrengthSignal(symbol, direction, assetType);        signal.isValid = false;    {

    if(cs.isValid && cs.isAligned)

    {        return signal;        WriteLog(0, "ERRO: Falha ao copiar buffer CS");

        score.currencyStrengthPoints = 1;

    }    }        IndicatorRelease(csHandle);

    

    // 3. RSI OMA            signal.isValid = false;

    RSISignal rsi = GetRSIOMASignal(symbol, PERIOD_M15, direction);

    if(rsi.isValid && rsi.isAligned)    // CAMINHO CORRIGIDO        return signal;

    {

        score.rsiomaPoints = 1;    string indicatorPath = "Indicators\\NexusConfluenceEA\\" + CurrencyStrengthIndicator;    }

    }

            

    // 4. WAE

    WAESignal wae = GetWAESignal(symbol, PERIOD_M15, direction);    WriteLog(3, StringFormat("Carregando CS: %s", indicatorPath));    signal.isValid = true;

    if(wae.isValid && wae.isAligned)

    {        signal.baseStrength = csBuffer[0];

        score.waePoints = 1;

    }    int csHandle = iCustom(symbol, PERIOD_M15, indicatorPath);    signal.quoteStrength = csBuffer[1];

    

    score.totalPoints = score.traderMagicPoints + score.currencyStrengthPoints +         signal.isInverse = (assetType == METALS);

                       score.rsiomaPoints + score.waePoints;

        if(csHandle == INVALID_HANDLE)    

    // Classificação conforme tipo de ativo

    if(assetType == FOREX_MAJOR || assetType == FOREX_MINOR ||     {    // Lógica simplificada de alinhamento

       assetType == FOREX_EXOTIC || assetType == CURRENCY_B3 || assetType == METALS)

    {        WriteLog(0, StringFormat("ERRO: Handle CS inválido - Caminho: %s", indicatorPath));    if(signal.isInverse) {

        score.requiredPoints = 2;

        if(score.totalPoints >= 3) score.classification = PREMIUM;        signal.isValid = false;        signal.isAligned = (direction == TRADE_BUY) ? 

        else if(score.totalPoints >= 2) score.classification = GOOD;

        else score.classification = REJECT;        return signal;            (signal.quoteStrength < signal.baseStrength) : 

    }

    else    }            (signal.quoteStrength > signal.baseStrength);

    {

        score.requiredPoints = 2;        } else {

        if(score.rsiomaPoints + score.waePoints >= 2) score.classification = PREMIUM;

        else score.classification = REJECT;    double csBuffer[];        signal.isAligned = (direction == TRADE_BUY) ? 

    }

        ArraySetAsSeries(csBuffer, true);            (signal.baseStrength > signal.quoteStrength) : 

    score.reasoning = StringFormat("TM:%d CS:%d RSI:%d WAE:%d = %d pontos - %s",

        score.traderMagicPoints, score.currencyStrengthPoints,                 (signal.baseStrength < signal.quoteStrength);

        score.rsiomaPoints, score.waePoints,

        score.totalPoints, EnumToString(score.classification));    if(CopyBuffer(csHandle, 0, 0, 3, csBuffer) < 3)    }

    

    return score;    {    

}

        WriteLog(0, "ERRO: Falha ao copiar buffer CS");    IndicatorRelease(csHandle);

//+------------------------------------------------------------------+

//| Funções auxiliares                                               |        IndicatorRelease(csHandle);    WriteLog(3, StringFormat("CS: Base=%.2f Quote=%.2f Alinhado=%s", 

//+------------------------------------------------------------------+

string EnumToString(ASSET_CLASS assetClass)        signal.isValid = false;        signal.baseStrength, signal.quoteStrength, signal.isAligned ? "SIM" : "NÃO"));

{

    switch(assetClass)        return signal;    

    {

        case FOREX_MAJOR: return "FOREX_MAJOR";    }    return signal;

        case FOREX_MINOR: return "FOREX_MINOR";

        case METALS: return "METALS";    }

        default: return "UNKNOWN";

    }    signal.isValid = true;

}

    signal.baseStrength = csBuffer[0];RSISignal GetRSIOMASignal(string symbol, ENUM_TIMEFRAMES timeframe, TRADE_DIRECTION direction)

string EnumToString(TRADE_DIRECTION direction)

{    signal.quoteStrength = csBuffer[1];{

    switch(direction)

    {    signal.isInverse = (assetType == METALS);    RSISignal signal;

        case TRADE_BUY: return "BUY";

        case TRADE_SELL: return "SELL";        ZeroMemory(signal);

        default: return "NONE";

    }    // Lógica de alinhamento    

}

    if(signal.isInverse)    // CAMINHO CORRIGIDO

string EnumToString(SETUP_CLASSIFICATION classification)

{    {    string indicatorPath = "Indicators\\NexusConfluenceEA\\" + RSIOMAIndicator + ".ex5";

    switch(classification)

    {        signal.isAligned = (direction == TRADE_BUY) ?     

        case PREMIUM: return "PREMIUM";

        case GOOD: return "GOOD";            (signal.quoteStrength < signal.baseStrength) :     WriteLog(3, StringFormat("Carregando RSI: %s", indicatorPath));

        default: return "REJECT";

    }            (signal.quoteStrength > signal.baseStrength);    

}

    }    int rsiHandle = iCustom(symbol, timeframe, indicatorPath);

bool IsSetupValid(SetupScore score)

{    else    

    return (score.classification == PREMIUM || score.classification == GOOD);

}    {    if(rsiHandle == INVALID_HANDLE)



//+------------------------------------------------------------------+        signal.isAligned = (direction == TRADE_BUY) ?     {

//| Expert initialization function                                   |

//+------------------------------------------------------------------+            (signal.baseStrength > signal.quoteStrength) :         WriteLog(0, StringFormat("ERRO: Handle RSI inválido - Caminho: %s", indicatorPath));

int OnInit()

{            (signal.baseStrength < signal.quoteStrength);        signal.isValid = false;

    WriteLog(1, "=== INICIALIZANDO NEXUS CONFLUENCE EA v4.0 ===");

        }        return signal;

    WriteLog(1, "CAMINHOS DOS INDICADORES CORRIGIDOS:");

    WriteLog(1, "- TrendMagic: Indicators\\NexusConfluenceEA\\" + TrendMagicIndicator);        }

    WriteLog(1, "- CurrencyStrength: Indicators\\NexusConfluenceEA\\" + CurrencyStrengthIndicator);

    WriteLog(1, "- RSIOMA: Indicators\\NexusConfluenceEA\\" + RSIOMAIndicator);    IndicatorRelease(csHandle);    

    WriteLog(1, "- WAE: Indicators\\NexusConfluenceEA\\" + WAEIndicator);

        WriteLog(3, StringFormat("CS: Base=%.2f Quote=%.2f Alinhado=%s",     double rsiRed[], rsiBlue[];

    trade.SetExpertMagicNumber(EA_MAGIC_NUMBER);

    g_InitializationComplete = true;        signal.baseStrength, signal.quoteStrength, signal.isAligned ? "SIM" : "NÃO"));    ArraySetAsSeries(rsiRed, true);

    

    WriteLog(1, "EA inicializado com sucesso!");        ArraySetAsSeries(rsiBlue, true);

    

    if(SendAlerts)    return signal;    

    {

        SendNotification("Nexus Confluence EA v4.0 iniciado em " + _Symbol);}    if(CopyBuffer(rsiHandle, 0, 0, 3, rsiRed) < 3 ||

    }

           CopyBuffer(rsiHandle, 1, 0, 3, rsiBlue) < 3)

    return(INIT_SUCCEEDED);

}//+------------------------------------------------------------------+    {



//+------------------------------------------------------------------+//| Função para obter sinal do RSI OMA                              |        WriteLog(0, "ERRO: Falha ao copiar buffers RSI");

//| Expert deinitialization function                                 |

//+------------------------------------------------------------------+//+------------------------------------------------------------------+        IndicatorRelease(rsiHandle);

void OnDeinit(const int reason)

{RSISignal GetRSIOMASignal(string symbol, ENUM_TIMEFRAMES timeframe, TRADE_DIRECTION direction)        signal.isValid = false;

    WriteLog(1, "=== FINALIZANDO NEXUS CONFLUENCE EA ===");

    WriteLog(1, "Razão: " + IntegerToString(reason));{        return signal;

    

    if(SendAlerts)    RSISignal signal;    }

    {

        SendNotification("Nexus Confluence EA finalizado");    ZeroMemory(signal);    

    }

}        signal.isValid = true;



//+------------------------------------------------------------------+    // CAMINHO CORRIGIDO    signal.redValue = rsiRed[0];

//| Expert tick function                                             |

//+------------------------------------------------------------------+    string indicatorPath = "Indicators\\NexusConfluenceEA\\" + RSIOMAIndicator;    signal.blueValue = rsiBlue[0];

void OnTick()

{        signal.slope = (rsiRed[0] - rsiRed[2]) * 50.0;

    if(!g_InitializationComplete) return;

        WriteLog(3, StringFormat("Carregando RSI: %s", indicatorPath));    

    static datetime lastTest = 0;

    if(TimeCurrent() - lastTest >= 60)        if(direction == TRADE_BUY) {

    {

        lastTest = TimeCurrent();    int rsiHandle = iCustom(symbol, timeframe, indicatorPath);        signal.isAligned = (signal.redValue > signal.blueValue) && (signal.slope > 0.1);

        

        ASSET_CLASS assetType = ClassifyAsset(_Symbol);        } else {

        

        SetupScore scoreBuy = CalculateSetupScore(_Symbol, assetType, TRADE_BUY);    if(rsiHandle == INVALID_HANDLE)        signal.isAligned = (signal.redValue < signal.blueValue) && (signal.slope < -0.1);

        SetupScore scoreSell = CalculateSetupScore(_Symbol, assetType, TRADE_SELL);

            {    }

        WriteLog(1, StringFormat("=== ANÁLISE %s ===", _Symbol));

        WriteLog(1, "BUY: " + scoreBuy.reasoning);        WriteLog(0, StringFormat("ERRO: Handle RSI inválido - Caminho: %s", indicatorPath));    

        WriteLog(1, "SELL: " + scoreSell.reasoning);

                signal.isValid = false;    IndicatorRelease(rsiHandle);

        if(IsSetupValid(scoreBuy))

        {        return signal;    WriteLog(3, StringFormat("RSI: Red=%.2f Blue=%.2f Slope=%.2f Alinhado=%s", 

            WriteLog(0, StringFormat("*** SETUP BUY VÁLIDO: %s ***", scoreBuy.reasoning));

            if(SendAlerts)    }        signal.redValue, signal.blueValue, signal.slope, signal.isAligned ? "SIM" : "NÃO"));

            {

                SendNotification(StringFormat("Nexus: Setup BUY %s - %s", _Symbol, EnumToString(scoreBuy.classification)));        

            }

        }    double rsiRed[], rsiBlue[];    return signal;

        

        if(IsSetupValid(scoreSell))    ArraySetAsSeries(rsiRed, true);}

        {

            WriteLog(0, StringFormat("*** SETUP SELL VÁLIDO: %s ***", scoreSell.reasoning));    ArraySetAsSeries(rsiBlue, true);

            if(SendAlerts)

            {    WAESignal GetWAESignal(string symbol, ENUM_TIMEFRAMES timeframe, TRADE_DIRECTION direction)

                SendNotification(StringFormat("Nexus: Setup SELL %s - %s", _Symbol, EnumToString(scoreSell.classification)));

            }    if(CopyBuffer(rsiHandle, 0, 0, 3, rsiRed) < 3 ||{

        }

    }       CopyBuffer(rsiHandle, 1, 0, 3, rsiBlue) < 3)    WAESignal signal;

}

//+------------------------------------------------------------------+    {    ZeroMemory(signal);

        WriteLog(0, "ERRO: Falha ao copiar buffers RSI");    

        IndicatorRelease(rsiHandle);    // CAMINHO CORRIGIDO

        signal.isValid = false;    string indicatorPath = "Indicators\\NexusConfluenceEA\\" + WAEIndicator + ".ex5";

        return signal;    

    }    WriteLog(3, StringFormat("Carregando WAE: %s", indicatorPath));

        

    signal.isValid = true;    int waeHandle = iCustom(symbol, timeframe, indicatorPath);

    signal.redValue = rsiRed[0];    

    signal.blueValue = rsiBlue[0];    if(waeHandle == INVALID_HANDLE)

    signal.slope = (rsiRed[0] - rsiRed[2]) * 50.0;    {

            WriteLog(0, StringFormat("ERRO: Handle WAE inválido - Caminho: %s", indicatorPath));

    if(direction == TRADE_BUY)        signal.isValid = false;

    {        return signal;

        signal.isAligned = (signal.redValue > signal.blueValue) && (signal.slope > 0.1);    }

    }    

    else    double waeMain[];

    {    ArraySetAsSeries(waeMain, true);

        signal.isAligned = (signal.redValue < signal.blueValue) && (signal.slope < -0.1);    

    }    if(CopyBuffer(waeHandle, 0, 0, 3, waeMain) < 3)

        {

    IndicatorRelease(rsiHandle);        WriteLog(0, "ERRO: Falha ao copiar buffer WAE");

    WriteLog(3, StringFormat("RSI: Red=%.2f Blue=%.2f Slope=%.2f Alinhado=%s",         IndicatorRelease(waeHandle);

        signal.redValue, signal.blueValue, signal.slope, signal.isAligned ? "SIM" : "NÃO"));        signal.isValid = false;

            return signal;

    return signal;    }

}    

    signal.isValid = true;

//+------------------------------------------------------------------+    signal.mainValue = waeMain[0];

//| Função para obter sinal do WAE                                  |    signal.isExpanding = (MathAbs(waeMain[0]) > MathAbs(waeMain[1]));

//+------------------------------------------------------------------+    signal.hasStrength = (MathAbs(signal.mainValue) > 10.0);

WAESignal GetWAESignal(string symbol, ENUM_TIMEFRAMES timeframe, TRADE_DIRECTION direction)    

{    if(direction == TRADE_BUY) {

    WAESignal signal;        signal.isAligned = (signal.mainValue > 0) && signal.isExpanding && signal.hasStrength;

    ZeroMemory(signal);    } else {

            signal.isAligned = (signal.mainValue < 0) && signal.isExpanding && signal.hasStrength;

    // CAMINHO CORRIGIDO    }

    string indicatorPath = "Indicators\\NexusConfluenceEA\\" + WAEIndicator;    

        IndicatorRelease(waeHandle);

    WriteLog(3, StringFormat("Carregando WAE: %s", indicatorPath));    WriteLog(3, StringFormat("WAE: Main=%.2f Expandindo=%s Força=%s Alinhado=%s", 

            signal.mainValue, signal.isExpanding ? "SIM" : "NÃO", 

    int waeHandle = iCustom(symbol, timeframe, indicatorPath);        signal.hasStrength ? "SIM" : "NÃO", signal.isAligned ? "SIM" : "NÃO"));

        

    if(waeHandle == INVALID_HANDLE)    return signal;

    {}

        WriteLog(0, StringFormat("ERRO: Handle WAE inválido - Caminho: %s", indicatorPath));

        signal.isValid = false;//+------------------------------------------------------------------+

        return signal;//| ANÁLISE MULTI-TIMEFRAME                                         |

    }//+------------------------------------------------------------------+

    

    double waeMain[];MultiTFResult AnalyzeTimeframes(string symbol, TRADE_DIRECTION direction)

    ArraySetAsSeries(waeMain, true);{

        MultiTFResult result;

    if(CopyBuffer(waeHandle, 0, 0, 3, waeMain) < 3)    ZeroMemory(result);

    {    

        WriteLog(0, "ERRO: Falha ao copiar buffer WAE");    WriteLog(3, StringFormat("Analisando MTF para %s direção %s", symbol, EnumToString(direction)));

        IndicatorRelease(waeHandle);    

        signal.isValid = false;    TMSignal tmH4 = GetTraderMagicSignal(symbol, PERIOD_H4);

        return signal;    TMSignal tmH1 = GetTraderMagicSignal(symbol, PERIOD_H1);

    }    TMSignal tmM30 = GetTraderMagicSignal(symbol, PERIOD_M30);

        

    signal.isValid = true;    result.H4_aligned = (tmH4.isValid && tmH4.direction == direction && tmH4.strength >= 0.7);

    signal.mainValue = waeMain[0];    result.H1_aligned = (tmH1.isValid && tmH1.direction == direction && tmH1.strength >= 0.6);

    signal.isExpanding = (MathAbs(waeMain[0]) > MathAbs(waeMain[1]));    result.M30_aligned = (tmM30.isValid && tmM30.direction == direction && tmM30.strength >= 0.5);

    signal.hasStrength = (MathAbs(signal.mainValue) > 10.0);    

        result.structure_valid = true; // Simplificado

    if(direction == TRADE_BUY)    result.direction = direction;

    {    result.isValid = result.H4_aligned && result.H1_aligned;

        signal.isAligned = (signal.mainValue > 0) && signal.isExpanding && signal.hasStrength;    

    }    result.quality_score = 0;

    else    if(result.H4_aligned) result.quality_score++;

    {    if(result.H1_aligned) result.quality_score++;

        signal.isAligned = (signal.mainValue < 0) && signal.isExpanding && signal.hasStrength;    if(result.M30_aligned) result.quality_score++;

    }    if(result.structure_valid) result.quality_score++;

        

    IndicatorRelease(waeHandle);    string reasoning = StringFormat("H4:%s H1:%s M30:%s Struct:%s - Score:%d", 

    WriteLog(3, StringFormat("WAE: Main=%.2f Expandindo=%s Força=%s Alinhado=%s",         result.H4_aligned ? "OK" : "FAIL",

        signal.mainValue, signal.isExpanding ? "SIM" : "NÃO",         result.H1_aligned ? "OK" : "FAIL", 

        signal.hasStrength ? "SIM" : "NÃO", signal.isAligned ? "SIM" : "NÃO"));        result.M30_aligned ? "OK" : "WEAK",

            result.structure_valid ? "OK" : "WEAK",

    return signal;        result.quality_score);

}    

    result.analysis_notes = reasoning;

//+------------------------------------------------------------------+    

//| Análise Multi-Timeframe                                         |    WriteLog(2, StringFormat("MTF %s: %s", symbol, reasoning));

//+------------------------------------------------------------------+    

MultiTFResult AnalyzeTimeframes(string symbol, TRADE_DIRECTION direction)    return result;

{}

    MultiTFResult result;

    ZeroMemory(result);//+------------------------------------------------------------------+

    //| CLASSIFICAÇÃO DE ATIVOS                                          |

    WriteLog(3, StringFormat("Analisando MTF para %s direção %s", symbol, EnumToString(direction)));//+------------------------------------------------------------------+

    

    TMSignal tmH4 = GetTraderMagicSignal(symbol, PERIOD_H4);ASSET_CLASS ClassifyAsset(string symbol) {

    TMSignal tmH1 = GetTraderMagicSignal(symbol, PERIOD_H1);    if(symbol == "EURUSD" || symbol == "GBPUSD" || symbol == "USDJPY" || 

    TMSignal tmM30 = GetTraderMagicSignal(symbol, PERIOD_M30);       symbol == "AUDUSD" || symbol == "USDCAD" || symbol == "NZDUSD") {

            return FOREX_MAJOR;

    result.H4_aligned = (tmH4.isValid && tmH4.direction == direction && tmH4.strength >= 0.7);    }

    result.H1_aligned = (tmH1.isValid && tmH1.direction == direction && tmH1.strength >= 0.6);    if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "XAG") >= 0) {

    result.M30_aligned = (tmM30.isValid && tmM30.direction == direction && tmM30.strength >= 0.5);        return METALS;

        }

    result.structure_valid = true; // Simplificado    return FOREX_MAJOR; // Padrão

    result.direction = direction;}

    result.isValid = result.H4_aligned && result.H1_aligned;

    //+------------------------------------------------------------------+

    result.quality_score = 0;//| SISTEMA DE PONTUAÇÃO                                             |

    if(result.H4_aligned) result.quality_score++;//+------------------------------------------------------------------+

    if(result.H1_aligned) result.quality_score++;

    if(result.M30_aligned) result.quality_score++;SetupScore CalculateSetupScore(string symbol, ASSET_CLASS assetType, TRADE_DIRECTION direction)

    if(result.structure_valid) result.quality_score++;{

        SetupScore score;

    string reasoning = StringFormat("H4:%s H1:%s M30:%s Struct:%s - Score:%d",     ZeroMemory(score);

        result.H4_aligned ? "OK" : "FAIL",    

        result.H1_aligned ? "OK" : "FAIL",     WriteLog(3, StringFormat("Calculando score para %s %s", symbol, EnumToString(direction)));

        result.M30_aligned ? "OK" : "WEAK",    

        result.structure_valid ? "OK" : "WEAK",    // 1. Trader Magic (obrigatório)

        result.quality_score);    TMSignal tm = GetTraderMagicSignal(symbol, PERIOD_M15);

        if(tm.isValid && tm.direction == direction) {

    result.analysis_notes = reasoning;        score.traderMagicPoints = 1;

        }

    WriteLog(2, StringFormat("MTF %s: %s", symbol, reasoning));    

        // 2. Currency Strength (se aplicável)

    return result;    CSSignal cs = GetCurrencyStrengthSignal(symbol, direction, assetType);

}    if(cs.isValid && cs.isAligned) {

        score.currencyStrengthPoints = 1;

//+------------------------------------------------------------------+    }

//| Classificação de ativos                                          |    

//+------------------------------------------------------------------+    // 3. RSI OMA

ASSET_CLASS ClassifyAsset(string symbol)    RSISignal rsi = GetRSIOMASignal(symbol, PERIOD_M15, direction);

{    if(rsi.isValid && rsi.isAligned) {

    if(symbol == "EURUSD" || symbol == "GBPUSD" || symbol == "USDJPY" ||         score.rsiomaPoints = 1;

       symbol == "AUDUSD" || symbol == "USDCAD" || symbol == "NZDUSD")    }

    {    

        return FOREX_MAJOR;    // 4. WAE

    }    WAESignal wae = GetWAESignal(symbol, PERIOD_M15, direction);

    if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "XAG") >= 0)    if(wae.isValid && wae.isAligned) {

    {        score.waePoints = 1;

        return METALS;    }

    }    

    return FOREX_MAJOR; // Padrão    score.totalPoints = score.traderMagicPoints + score.currencyStrengthPoints + 

}                       score.rsiomaPoints + score.waePoints;

    

//+------------------------------------------------------------------+    // Determinar classificação

//| Sistema de pontuação                                             |    if(assetType == FOREX_MAJOR || assetType == FOREX_MINOR || 

//+------------------------------------------------------------------+       assetType == FOREX_EXOTIC || assetType == CURRENCY_B3 || assetType == METALS) {

SetupScore CalculateSetupScore(string symbol, ASSET_CLASS assetType, TRADE_DIRECTION direction)        score.requiredPoints = 2; // Precisa 2 de 3 (TM + CS + RSI + WAE)

{        if(score.totalPoints >= 3) score.classification = PREMIUM;

    SetupScore score;        else if(score.totalPoints >= 2) score.classification = GOOD;

    ZeroMemory(score);        else score.classification = REJECT;

        } else {

    WriteLog(3, StringFormat("Calculando score para %s %s", symbol, EnumToString(direction)));        score.requiredPoints = 2; // Índices: precisa 2 de 2 (RSI + WAE)

            if(score.rsiomaPoints + score.waePoints >= 2) score.classification = PREMIUM;

    // 1. Trader Magic (obrigatório)        else score.classification = REJECT;

    TMSignal tm = GetTraderMagicSignal(symbol, PERIOD_M15);    }

    if(tm.isValid && tm.direction == direction)    

    {    score.reasoning = StringFormat("TM:%d CS:%d RSI:%d WAE:%d = %d/%d pontos - %s",

        score.traderMagicPoints = 1;        score.traderMagicPoints, score.currencyStrengthPoints, 

    }        score.rsiomaPoints, score.waePoints,

            score.totalPoints, score.requiredPoints, 

    // 2. Currency Strength (se aplicável)        EnumToString(score.classification));

    CSSignal cs = GetCurrencyStrengthSignal(symbol, direction, assetType);    

    if(cs.isValid && cs.isAligned)    WriteLog(2, StringFormat("Score %s: %s", symbol, score.reasoning));

    {    

        score.currencyStrengthPoints = 1;    return score;

    }}

    

    // 3. RSI OMA//+------------------------------------------------------------------+

    RSISignal rsi = GetRSIOMASignal(symbol, PERIOD_M15, direction);//| FUNÇÕES AUXILIARES                                               |

    if(rsi.isValid && rsi.isAligned)//+------------------------------------------------------------------+

    {

        score.rsiomaPoints = 1;string EnumToString(ASSET_CLASS assetClass) {

    }    switch(assetClass) {

            case FOREX_MAJOR: return "FOREX_MAJOR";

    // 4. WAE        case FOREX_MINOR: return "FOREX_MINOR";

    WAESignal wae = GetWAESignal(symbol, PERIOD_M15, direction);        case METALS: return "METALS";

    if(wae.isValid && wae.isAligned)        default: return "UNKNOWN";

    {    }

        score.waePoints = 1;}

    }

    string EnumToString(TRADE_DIRECTION direction) {

    score.totalPoints = score.traderMagicPoints + score.currencyStrengthPoints +     switch(direction) {

                       score.rsiomaPoints + score.waePoints;        case TRADE_BUY: return "BUY";

            case TRADE_SELL: return "SELL";

    // Determinar classificação        default: return "NONE";

    if(assetType == FOREX_MAJOR || assetType == FOREX_MINOR ||     }

       assetType == FOREX_EXOTIC || assetType == CURRENCY_B3 || assetType == METALS)}

    {

        score.requiredPoints = 2; // Precisa 2 de 3 (TM + CS + RSI + WAE)string EnumToString(SETUP_CLASSIFICATION classification) {

        if(score.totalPoints >= 3) score.classification = PREMIUM;    switch(classification) {

        else if(score.totalPoints >= 2) score.classification = GOOD;        case PREMIUM: return "PREMIUM";

        else score.classification = REJECT;        case GOOD: return "GOOD";

    }        default: return "REJECT";

    else    }

    {}

        score.requiredPoints = 2; // Índices: precisa 2 de 2 (RSI + WAE)

        if(score.rsiomaPoints + score.waePoints >= 2) score.classification = PREMIUM;bool IsSetupValid(SetupScore score) {

        else score.classification = REJECT;    return (score.classification == PREMIUM || score.classification == GOOD);

    }}

    

    score.reasoning = StringFormat("TM:%d CS:%d RSI:%d WAE:%d = %d/%d pontos - %s",//+------------------------------------------------------------------+

        score.traderMagicPoints, score.currencyStrengthPoints, //| EVENTOS PRINCIPAIS                                               |

        score.rsiomaPoints, score.waePoints,//+------------------------------------------------------------------+

        score.totalPoints, score.requiredPoints, 

        EnumToString(score.classification));int OnInit() {

        WriteLog(1, "=== INICIALIZANDO NEXUS CONFLUENCE EA v" + EA_VERSION + " CORRIGIDO ===");

    WriteLog(2, StringFormat("Score %s: %s", symbol, score.reasoning));    

        WriteLog(1, "Caminhos dos indicadores configurados:");

    return score;    WriteLog(1, "- TrendMagic: Indicators\\NexusConfluenceEA\\" + TrendMagicIndicator + ".ex5");

}    WriteLog(1, "- CurrencyStrength: Indicators\\NexusConfluenceEA\\" + CurrencyStrengthIndicator + ".ex5");

    WriteLog(1, "- RSIOMA: Indicators\\NexusConfluenceEA\\" + RSIOMAIndicator + ".ex5");

//+------------------------------------------------------------------+    WriteLog(1, "- WAE: Indicators\\NexusConfluenceEA\\" + WAEIndicator + ".ex5");

//| Funções auxiliares                                               |    

//+------------------------------------------------------------------+    g_InitializationComplete = true;

string EnumToString(ASSET_CLASS assetClass)    

{    WriteLog(1, "EA inicializado com sucesso!");

    switch(assetClass)    

    {    if(SendAlerts) {

        case FOREX_MAJOR: return "FOREX_MAJOR";        SendNotification("Nexus Confluence EA v" + EA_VERSION + " iniciado em " + _Symbol);

        case FOREX_MINOR: return "FOREX_MINOR";    }

        case METALS: return "METALS";    

        default: return "UNKNOWN";    return INIT_SUCCEEDED;

    }}

}

void OnDeinit(const int reason) {

string EnumToString(TRADE_DIRECTION direction)    WriteLog(1, "=== FINALIZANDO NEXUS CONFLUENCE EA ===");

{    WriteLog(1, "Razão: " + IntegerToString(reason));

    switch(direction)    

    {    if(SendAlerts) {

        case TRADE_BUY: return "BUY";        SendNotification("Nexus Confluence EA finalizado");

        case TRADE_SELL: return "SELL";    }

        default: return "NONE";}

    }

}void OnTick() {

    if(!g_InitializationComplete) return;

string EnumToString(SETUP_CLASSIFICATION classification)    

{    // Teste simples dos indicadores

    switch(classification)    static datetime lastTest = 0;

    {    if(TimeCurrent() - lastTest >= 60) { // A cada minuto

        case PREMIUM: return "PREMIUM";        lastTest = TimeCurrent();

        case GOOD: return "GOOD";        

        default: return "REJECT";        ASSET_CLASS assetType = ClassifyAsset(_Symbol);

    }        

}        // Teste análise MTF

        MultiTFResult mtfBuy = AnalyzeTimeframes(_Symbol, TRADE_BUY);

bool IsSetupValid(SetupScore score)        MultiTFResult mtfSell = AnalyzeTimeframes(_Symbol, TRADE_SELL);

{        

    return (score.classification == PREMIUM || score.classification == GOOD);        // Teste score

}        SetupScore scoreBuy = CalculateSetupScore(_Symbol, assetType, TRADE_BUY);

        SetupScore scoreSell = CalculateSetupScore(_Symbol, assetType, TRADE_SELL);

//+------------------------------------------------------------------+        

//| Expert initialization function                                   |        WriteLog(1, StringFormat("=== ANÁLISE %s ===", _Symbol));

//+------------------------------------------------------------------+        WriteLog(1, "BUY: " + scoreBuy.reasoning);

int OnInit()        WriteLog(1, "SELL: " + scoreSell.reasoning);

{        

    WriteLog(1, "=== INICIALIZANDO NEXUS CONFLUENCE EA v4.0 ===");        // Se setup válido, log especial

            if(IsSetupValid(scoreBuy)) {

    WriteLog(1, "Caminhos dos indicadores configurados:");            WriteLog(0, StringFormat("*** SETUP BUY VÁLIDO: %s ***", scoreBuy.reasoning));

    WriteLog(1, "- TrendMagic: Indicators\\NexusConfluenceEA\\" + TrendMagicIndicator);            if(SendAlerts) {

    WriteLog(1, "- CurrencyStrength: Indicators\\NexusConfluenceEA\\" + CurrencyStrengthIndicator);                SendNotification(StringFormat("Nexus: Setup BUY %s - %s", _Symbol, EnumToString(scoreBuy.classification)));

    WriteLog(1, "- RSIOMA: Indicators\\NexusConfluenceEA\\" + RSIOMAIndicator);            }

    WriteLog(1, "- WAE: Indicators\\NexusConfluenceEA\\" + WAEIndicator);        }

            

    trade.SetExpertMagicNumber(EA_MAGIC_NUMBER);        if(IsSetupValid(scoreSell)) {

                WriteLog(0, StringFormat("*** SETUP SELL VÁLIDO: %s ***", scoreSell.reasoning));

    g_InitializationComplete = true;            if(SendAlerts) {

                    SendNotification(StringFormat("Nexus: Setup SELL %s - %s", _Symbol, EnumToString(scoreSell.classification)));

    WriteLog(1, "EA inicializado com sucesso!");            }

            }

    if(SendAlerts)    }

    {}

        SendNotification("Nexus Confluence EA iniciado em " + _Symbol);

    }//+------------------------------------------------------------------+

    //| FIM DO EA                                                        |

    return(INIT_SUCCEEDED);//+------------------------------------------------------------------+
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    WriteLog(1, "=== FINALIZANDO NEXUS CONFLUENCE EA ===");
    WriteLog(1, "Razão: " + IntegerToString(reason));
    
    if(SendAlerts)
    {
        SendNotification("Nexus Confluence EA finalizado");
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    if(!g_InitializationComplete) return;
    
    // Teste simples dos indicadores a cada minuto
    static datetime lastTest = 0;
    if(TimeCurrent() - lastTest >= 60)
    {
        lastTest = TimeCurrent();
        
        ASSET_CLASS assetType = ClassifyAsset(_Symbol);
        
        // Teste análise MTF
        MultiTFResult mtfBuy = AnalyzeTimeframes(_Symbol, TRADE_BUY);
        MultiTFResult mtfSell = AnalyzeTimeframes(_Symbol, TRADE_SELL);
        
        // Teste score
        SetupScore scoreBuy = CalculateSetupScore(_Symbol, assetType, TRADE_BUY);
        SetupScore scoreSell = CalculateSetupScore(_Symbol, assetType, TRADE_SELL);
        
        WriteLog(1, StringFormat("=== ANÁLISE %s ===", _Symbol));
        WriteLog(1, "BUY: " + scoreBuy.reasoning);
        WriteLog(1, "SELL: " + scoreSell.reasoning);
        
        // Se setup válido, log especial
        if(IsSetupValid(scoreBuy))
        {
            WriteLog(0, StringFormat("*** SETUP BUY VÁLIDO: %s ***", scoreBuy.reasoning));
            if(SendAlerts)
            {
                SendNotification(StringFormat("Nexus: Setup BUY %s - %s", _Symbol, EnumToString(scoreBuy.classification)));
            }
        }
        
        if(IsSetupValid(scoreSell))
        {
            WriteLog(0, StringFormat("*** SETUP SELL VÁLIDO: %s ***", scoreSell.reasoning));
            if(SendAlerts)
            {
                SendNotification(StringFormat("Nexus: Setup SELL %s - %s", _Symbol, EnumToString(scoreSell.classification)));
            }
        }
    }
}
//+------------------------------------------------------------------+