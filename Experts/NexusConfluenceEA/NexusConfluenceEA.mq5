//+------------------------------------------------------------------+
//| NexusConfluenceEA.mq5                                            |
//| Copyright 2024, Nexus Confluence System                          |
//| https://nexusconfluence.com                                      |
//+------------------------------------------------------------------+
#property copyright "Nexus Confluence System"
#property link      "https://nexusconfluence.com"
#property version   "4.00"
#property description "EA Nexus Confluence - Sistema Universal Multi-Ativo com GG TrendBar"

//+------------------------------------------------------------------+
//| Includes                                                         |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Enumerações                                                      |
//+------------------------------------------------------------------+
enum ASSET_CLASS
{
    FOREX_MAJOR,
    FOREX_MINOR,
    FOREX_EXOTIC,
    INDEX_US,
    INDEX_EU,
    INDEX_B3,
    CURRENCY_B3,
    METALS,
    CRYPTO,
    UNKNOWN
};

enum TRADE_DIRECTION
{
    TRADE_BUY,
    TRADE_SELL,
    TRADE_NONE
};

enum SETUP_CLASSIFICATION
{
    PREMIUM,
    GOOD,
    REJECT
};

//+------------------------------------------------------------------+
//| Estruturas                                                       |
//+------------------------------------------------------------------+
struct TMSignal
{
    bool isValid;
    TRADE_DIRECTION direction;
    double strength;
    int lastChangeBar;
};

struct CSSignal
{
    bool isValid;
    bool isAligned;
    double baseStrength;
    double quoteStrength;
    bool isInverse;
};

struct RSISignal
{
    bool isValid;
    bool isAligned;
    double redValue;
    double blueValue;
    double slope;
};

struct WAESignal
{
    bool isValid;
    bool isAligned;
    double mainValue;
    bool isExpanding;
    bool hasStrength;
};

struct GGTrendBarSignal
{
    bool isValid;
    bool isAligned;
    int bullishCount;
    int bearishCount;
    double alignmentPercent;
    bool strongTrend;
    string analysis;
};

struct MultiTFResult
{
    bool isValid;
    bool H4_aligned;
    bool H1_aligned;
    bool M30_aligned;
    bool structure_valid;
    TRADE_DIRECTION direction;
    int quality_score;
    string analysis_notes;
};

struct SetupScore
{
    int traderMagicPoints;
    int currencyStrengthPoints;
    int rsiomaPoints;
    int waePoints;
    int ggTrendBarPoints;
    int totalPoints;
    int requiredPoints;
    SETUP_CLASSIFICATION classification;
    string reasoning;
};

//+------------------------------------------------------------------+
//| Estrutura de Handles dos Indicadores                            |
//+------------------------------------------------------------------+
struct IndicatorHandles
{
    int tm_h4, tm_h1, tm_m30, tm_m15;
    int cs_m15;
    int rsi_h4, rsi_h1, rsi_m30, rsi_m15;
    int wae_h4, wae_h1, wae_m30, wae_m15;
    int gg_trendbar;
};

//+------------------------------------------------------------------+
//| PARÂMETROS DE ENTRADA                                           |
//+------------------------------------------------------------------+
input group "=== CONFIGURAÇÕES GERAIS ==="
input bool EnableAutoTrading = true;
input double AccountRiskPercent = 1.5;
input int MaxSimultaneousTrades = 3;
input int LogLevel = 2;

input group "=== TREND MAGIC - PARÂMETROS ==="
input int TM_CCI_Period = 50;
input int TM_ATR_Period = 5;
input double TM_ATR_Multiplier = 1.0;

input group "=== CURRENCY STRENGTH - PARÂMETROS ==="
input int CS_CalculationPeriod = 24;
input int CS_SmoothingPeriod = 5;
input bool CS_ShowInPercent = true;

input group "=== RSI OMA - PARÂMETROS ==="
input int RSI_Period = 14;
input int RSI_MA_Period = 9;
input ENUM_MA_METHOD RSI_MA_Method = MODE_SMA;
input double RSI_HighLevel = 70.0;
input double RSI_LowLevel = 30.0;
input bool RSI_ShowLevels = true;

input group "=== WAE - PARÂMETROS ==="
input int WAE_FastMA = 20;
input int WAE_SlowMA = 40;
input int WAE_BBLength = 20;
input double WAE_BBMultiplier = 2.0;
input int WAE_Sensitivity = 150;

input group "=== GG TRENDBAR - PARÂMETROS ==="
input int GG_ADX_Period = 14;
input ENUM_APPLIED_PRICE GG_ADX_Price = PRICE_CLOSE;
input double GG_Step_Psar = 0.02;
input double GG_Max_Psar = 0.2;
input double GG_MinAlignmentPercent = 60.0;

input group "=== INDICADORES - NOMES DOS ARQUIVOS ==="
input string TrendMagicIndicator = "TrendMagic_MT5";
input string CurrencyStrengthIndicator = "CurrencyStrengthMeter_MT5";
input string RSIOMAIndicator = "RSIOMA_v2HHLSX_MT5";
input string WAEIndicator = "WaddahAttarExplosion_Professional";
input string GGTrendBarIndicator = "GG_TrendBar_Indicator";

input group "=== ALERTAS ==="
input bool SendAlerts = true;
input bool EnableDetailedLogs = true;
input bool SaveTradeHistory = true;

//+------------------------------------------------------------------+
//| Variáveis globais                                                |
//+------------------------------------------------------------------+
const int EA_MAGIC_NUMBER = 20241015;
const string GG_TRENDBAR_SHORTNAME = "GG TrendBar";
CTrade trade;
bool g_InitializationComplete = false;
IndicatorHandles g_handles;
bool g_GGTrendBarAttached = false;
int g_trendMagicWindow = -1;
int g_currencyStrengthWindow = -1;
int g_rsiomaWindow = -1;
int g_waeWindow = -1;
string g_trendMagicShortName;
string g_currencyStrengthShortName;
string g_rsiomaShortName;
string g_waeShortName;

// Padrões de nomes dos indicadores conforme definidos em seus códigos fonte
const string HINT_TRENDMAGIC = "trendmagic mt5";
const string HINT_CURRENCY_STRENGTH = "currency strength:";
const string HINT_RSIOMA = "rsioma v2";
const string HINT_WAE = "wae [";

//+------------------------------------------------------------------+
//| Função de log                                                    |
//+------------------------------------------------------------------+
void WriteLog(int level, string message)
{
    if(level > LogLevel) return;
    
    string prefix;
    switch(level)
    {
        case 0: prefix = "ERROR"; break;
        case 1: prefix = "INFO"; break;
        case 2: prefix = "DEBUG"; break;
        case 3: prefix = "TRACE"; break;
        default: prefix = "LOG"; break;
    }
    
    string fullMessage = StringFormat("[%s] %s: %s", 
                        TimeToString(TimeCurrent()), prefix, message);
    Print(fullMessage);
}

//+------------------------------------------------------------------+
//| Inicializar handles dos indicadores                             |
//+------------------------------------------------------------------+
bool InitializeIndicatorHandles(string symbol)
{
    WriteLog(1, "Inicializando handles dos indicadores para " + symbol);
    WriteLog(1, "Diretório indicadores: MQL5\\Indicators\\NexusConfluenceEA\\");
    
    // CRÍTICO: Caminho relativo a partir de MQL5/Indicators/
    string basePath = "NexusConfluenceEA\\";
    
    // TrendMagic para todos os timeframes
    WriteLog(2, "Carregando TrendMagic...");
    g_handles.tm_h4 = iCustom(symbol, PERIOD_H4, basePath + TrendMagicIndicator, 
                             TM_CCI_Period, TM_ATR_Period, TM_ATR_Multiplier);
    if(g_handles.tm_h4 == INVALID_HANDLE) {
        WriteLog(0, "ERRO: TM H4 falhou - Verifique: " + basePath + TrendMagicIndicator + ".ex5");
        return false;
    }
    
    g_handles.tm_h1 = iCustom(symbol, PERIOD_H1, basePath + TrendMagicIndicator, 
                             TM_CCI_Period, TM_ATR_Period, TM_ATR_Multiplier);
    if(g_handles.tm_h1 == INVALID_HANDLE) {
        WriteLog(0, "ERRO: TM H1 falhou");
        return false;
    }
    
    g_handles.tm_m30 = iCustom(symbol, PERIOD_M30, basePath + TrendMagicIndicator, 
                              TM_CCI_Period, TM_ATR_Period, TM_ATR_Multiplier);
    if(g_handles.tm_m30 == INVALID_HANDLE) {
        WriteLog(0, "ERRO: TM M30 falhou");
        return false;
    }
    
    g_handles.tm_m15 = iCustom(symbol, PERIOD_M15, basePath + TrendMagicIndicator, 
                              TM_CCI_Period, TM_ATR_Period, TM_ATR_Multiplier);
    if(g_handles.tm_m15 == INVALID_HANDLE) {
        WriteLog(0, "ERRO: TM M15 falhou");
        return false;
    }
    WriteLog(1, "✓ TrendMagic carregado com sucesso");
    
    // Currency Strength apenas M15
    WriteLog(2, "Carregando Currency Strength...");
    g_handles.cs_m15 = iCustom(symbol, PERIOD_M15, basePath + CurrencyStrengthIndicator,
                              CS_CalculationPeriod, CS_SmoothingPeriod, CS_ShowInPercent);
    if(g_handles.cs_m15 == INVALID_HANDLE) {
        WriteLog(0, "ERRO: CS M15 falhou - Verifique: " + basePath + CurrencyStrengthIndicator + ".ex5");
        return false;
    }
    WriteLog(1, "✓ Currency Strength carregado com sucesso");
    
    // RSI OMA para todos os timeframes
    WriteLog(2, "Carregando RSI OMA...");
    g_handles.rsi_h4 = iCustom(symbol, PERIOD_H4, basePath + RSIOMAIndicator,
                              RSI_Period, RSI_MA_Period, RSI_MA_Method, RSI_HighLevel, RSI_LowLevel, RSI_ShowLevels);
    if(g_handles.rsi_h4 == INVALID_HANDLE) {
        WriteLog(0, "ERRO: RSI H4 falhou - Verifique: " + basePath + RSIOMAIndicator + ".ex5");
        return false;
    }
    
    g_handles.rsi_h1 = iCustom(symbol, PERIOD_H1, basePath + RSIOMAIndicator,
                              RSI_Period, RSI_MA_Period, RSI_MA_Method, RSI_HighLevel, RSI_LowLevel, RSI_ShowLevels);
    if(g_handles.rsi_h1 == INVALID_HANDLE) {
        WriteLog(0, "ERRO: RSI H1 falhou");
        return false;
    }
    
    g_handles.rsi_m30 = iCustom(symbol, PERIOD_M30, basePath + RSIOMAIndicator,
                               RSI_Period, RSI_MA_Period, RSI_MA_Method, RSI_HighLevel, RSI_LowLevel, RSI_ShowLevels);
    if(g_handles.rsi_m30 == INVALID_HANDLE) {
        WriteLog(0, "ERRO: RSI M30 falhou");
        return false;
    }
    
    g_handles.rsi_m15 = iCustom(symbol, PERIOD_M15, basePath + RSIOMAIndicator,
                               RSI_Period, RSI_MA_Period, RSI_MA_Method, RSI_HighLevel, RSI_LowLevel, RSI_ShowLevels);
    if(g_handles.rsi_m15 == INVALID_HANDLE) {
        WriteLog(0, "ERRO: RSI M15 falhou");
        return false;
    }
    WriteLog(1, "✓ RSI OMA carregado com sucesso");
    
    // WAE para todos os timeframes
    WriteLog(2, "Carregando WAE...");
    g_handles.wae_h4 = iCustom(symbol, PERIOD_H4, basePath + WAEIndicator,
                              WAE_FastMA, WAE_SlowMA, WAE_BBLength, WAE_BBMultiplier, WAE_Sensitivity);
    if(g_handles.wae_h4 == INVALID_HANDLE) {
        WriteLog(0, "ERRO: WAE H4 falhou - Verifique: " + basePath + WAEIndicator + ".ex5");
        WriteLog(0, "NOTA: Se o arquivo se chama diferente, ajuste o parâmetro WAEIndicator");
        return false;
    }
    
    g_handles.wae_h1 = iCustom(symbol, PERIOD_H1, basePath + WAEIndicator,
                              WAE_FastMA, WAE_SlowMA, WAE_BBLength, WAE_BBMultiplier, WAE_Sensitivity);
    if(g_handles.wae_h1 == INVALID_HANDLE) {
        WriteLog(0, "ERRO: WAE H1 falhou");
        return false;
    }
    
    g_handles.wae_m30 = iCustom(symbol, PERIOD_M30, basePath + WAEIndicator,
                               WAE_FastMA, WAE_SlowMA, WAE_BBLength, WAE_BBMultiplier, WAE_Sensitivity);
    if(g_handles.wae_m30 == INVALID_HANDLE) {
        WriteLog(0, "ERRO: WAE M30 falhou");
        return false;
    }
    
    g_handles.wae_m15 = iCustom(symbol, PERIOD_M15, basePath + WAEIndicator,
                               WAE_FastMA, WAE_SlowMA, WAE_BBLength, WAE_BBMultiplier, WAE_Sensitivity);
    if(g_handles.wae_m15 == INVALID_HANDLE) {
        WriteLog(0, "ERRO: WAE M15 falhou");
        return false;
    }
    WriteLog(1, "✓ WAE carregado com sucesso");
    
    // GG TrendBar
    WriteLog(2, "Carregando GG TrendBar...");
    g_handles.gg_trendbar = iCustom(symbol, PERIOD_M15, basePath + GGTrendBarIndicator,
                                   GG_ADX_Period, GG_ADX_Price, GG_Step_Psar, GG_Max_Psar);
    if(g_handles.gg_trendbar == INVALID_HANDLE) {
        WriteLog(0, "ERRO: GG TrendBar falhou - Verifique: " + basePath + GGTrendBarIndicator + ".ex5");
        return false;
    }
    WriteLog(1, "✓ GG TrendBar carregado com sucesso");

    if(AttachGGTrendBarToChart())
        WriteLog(1, "GG TrendBar anexado ao gráfico principal");
    else
        WriteLog(0, "Falha ao anexar o GG TrendBar ao gráfico principal");

    AttachVisualIndicators();
    
    WriteLog(1, "========================================");
    WriteLog(1, "TODOS OS INDICADORES CARREGADOS!");
    WriteLog(1, "========================================");
    return true;
}

//+------------------------------------------------------------------+
//| Liberar handles                                                  |
//+------------------------------------------------------------------+
void ReleaseIndicatorHandles()
{
    if(g_handles.tm_h4 != INVALID_HANDLE) IndicatorRelease(g_handles.tm_h4);
    if(g_handles.tm_h1 != INVALID_HANDLE) IndicatorRelease(g_handles.tm_h1);
    if(g_handles.tm_m30 != INVALID_HANDLE) IndicatorRelease(g_handles.tm_m30);
    if(g_handles.tm_m15 != INVALID_HANDLE) IndicatorRelease(g_handles.tm_m15);
    if(g_handles.cs_m15 != INVALID_HANDLE) IndicatorRelease(g_handles.cs_m15);
    if(g_handles.rsi_h4 != INVALID_HANDLE) IndicatorRelease(g_handles.rsi_h4);
    if(g_handles.rsi_h1 != INVALID_HANDLE) IndicatorRelease(g_handles.rsi_h1);
    if(g_handles.rsi_m30 != INVALID_HANDLE) IndicatorRelease(g_handles.rsi_m30);
    if(g_handles.rsi_m15 != INVALID_HANDLE) IndicatorRelease(g_handles.rsi_m15);
    if(g_handles.wae_h4 != INVALID_HANDLE) IndicatorRelease(g_handles.wae_h4);
    if(g_handles.wae_h1 != INVALID_HANDLE) IndicatorRelease(g_handles.wae_h1);
    if(g_handles.wae_m30 != INVALID_HANDLE) IndicatorRelease(g_handles.wae_m30);
    if(g_handles.wae_m15 != INVALID_HANDLE) IndicatorRelease(g_handles.wae_m15);
    if(g_handles.gg_trendbar != INVALID_HANDLE) IndicatorRelease(g_handles.gg_trendbar);
}

//+------------------------------------------------------------------+
//| Anexar GG TrendBar ao gráfico principal                          |
//+------------------------------------------------------------------+
bool AttachGGTrendBarToChart()
{
    if(g_handles.gg_trendbar == INVALID_HANDLE)
        return false;

    long chart_id = ChartID();
    
    // Em backtest, ChartIndicatorAdd pode não funcionar visualmente
    // Mas o handle já está criado e funcionando para leitura de dados
    bool isTesting = MQLInfoInteger(MQL_TESTER);
    
    if(!isTesting)
    {
        int existingWindow = -1;
        string existingName = "";
        if(LocateIndicatorByHandle(chart_id, g_handles.gg_trendbar, existingWindow, existingName))
            ChartIndicatorDelete(chart_id, existingWindow, existingName);
        else
            ChartIndicatorDelete(chart_id, 0, GG_TRENDBAR_SHORTNAME);

        if(!ChartIndicatorAdd(chart_id, 0, g_handles.gg_trendbar))
            return false;

        int total = ChartIndicatorsTotal(chart_id, 0);
        string names;
        for(int i = 0; i < total; i++)
        {
            string indicator_name = ChartIndicatorName(chart_id, 0, i);
            if(i > 0) names += ", ";
            names += indicator_name;
        }
        WriteLog(1, "Indicadores anexados janela 0: " + (names == "" ? "(nenhum)" : names));
    }
    else
    {
        WriteLog(1, "Modo backtest: GG TrendBar handle criado, anexação visual desabilitada");
    }
    
    g_GGTrendBarAttached = true;
    return true;
}

//+------------------------------------------------------------------+
//| Localizar indicador no gráfico por palavras-chave                |
//+------------------------------------------------------------------+
bool LocateIndicatorByHints(const long chart_id, const string hints, int &windowIndex, string &indicatorName)
{
    windowIndex = -1;
    indicatorName = "";

    if(StringLen(hints) == 0)
        return false;

    string lowerHints = hints;
    StringToLower(lowerHints);
    string tokens[];
    int tokenCount = StringSplit(lowerHints, (ushort)'|', tokens);
    if(tokenCount <= 0)
        return false;

    int totalWindows = (int)ChartGetInteger(chart_id, CHART_WINDOWS_TOTAL);
    for(int w = 0; w < totalWindows; ++w)
    {
        int indicatorCount = ChartIndicatorsTotal(chart_id, w);
        for(int i = 0; i < indicatorCount; ++i)
        {
            string name = ChartIndicatorName(chart_id, w, i);
            string nameLower = StringToLower(name);

            for(int t = 0; t < tokenCount; ++t)
            {
                string token = tokens[t];
                StringTrimLeft(token);
                StringTrimRight(token);
                if(StringLen(token) == 0)
                    continue;

                if(StringFind(nameLower, token) != -1)
                {
                    windowIndex = w;
                    indicatorName = name;
                    return true;
                }
            }
        }
    }

    return false;
}

//+------------------------------------------------------------------+
//| Localizar indicador no gráfico pelo handle                       |
//+------------------------------------------------------------------+
bool LocateIndicatorByHandle(const long chart_id, const int handle, int &windowIndex, string &indicatorName)
{
    windowIndex = -1;
    indicatorName = "";

    if(handle == INVALID_HANDLE)
        return false;

    // Padrões de nomes reais dos indicadores conforme definido em seus códigos fonte:
    // - TrendMagic: "TrendMagic MT5 (50,5)" 
    // - Currency Strength: "Currency Strength: USD vs JPY"
    // - RSIOMA: "RSIOMA v2 (14,9)"
    // - WAE: "WAE [Fast:20 | Slow:40 | Sens:150]"
    // - GG TrendBar: "GG TrendBar"
    
    int totalWindows = (int)ChartGetInteger(chart_id, CHART_WINDOWS_TOTAL);
    for(int w = 0; w < totalWindows; ++w)
    {
        int indicatorCount = ChartIndicatorsTotal(chart_id, w);
        for(int i = 0; i < indicatorCount; ++i)
        {
            string name = ChartIndicatorName(chart_id, w, i);
            
            // GG TrendBar: nome fixo "GG TrendBar"
            if(handle == g_handles.gg_trendbar && name == "GG TrendBar")
            {
                windowIndex = w;
                indicatorName = name;
                WriteLog(3, StringFormat("GG TrendBar localizado: '%s' na janela %d", name, w));
                return true;
            }
            // TrendMagic: começa com "TrendMagic MT5"
            else if(handle == g_handles.tm_m15 && StringFind(name, "TrendMagic MT5") == 0)
            {
                windowIndex = w;
                indicatorName = name;
                WriteLog(3, StringFormat("TrendMagic localizado: '%s' na janela %d", name, w));
                return true;
            }
            // Currency Strength: começa com "Currency Strength:"
            else if(handle == g_handles.cs_m15 && StringFind(name, "Currency Strength:") == 0)
            {
                windowIndex = w;
                indicatorName = name;
                WriteLog(3, StringFormat("CurrencyStrength localizado: '%s' na janela %d", name, w));
                return true;
            }
            // RSIOMA: começa com "RSIOMA v2"
            else if(handle == g_handles.rsi_m15 && StringFind(name, "RSIOMA v2") == 0)
            {
                windowIndex = w;
                indicatorName = name;
                WriteLog(3, StringFormat("RSIOMA localizado: '%s' na janela %d", name, w));
                return true;
            }
            // WAE: começa com "WAE ["
            else if(handle == g_handles.wae_m15 && StringFind(name, "WAE [") == 0)
            {
                windowIndex = w;
                indicatorName = name;
                WriteLog(3, StringFormat("WAE localizado: '%s' na janela %d", name, w));
                return true;
            }
        }
    }

    return false;
}

//+------------------------------------------------------------------+
//| Anexar indicador visual a uma janela específica                  |
//+------------------------------------------------------------------+
bool AttachVisualIndicator(int handle, int targetWindow, const string fallbackHints, const string displayName, int &storedWindow, string &storedName)
{
    if(handle == INVALID_HANDLE)
        return false;

    long chart_id = ChartID();

    int existingWindow = -1;
    string existingName = "";
    if(LocateIndicatorByHandle(chart_id, handle, existingWindow, existingName))
    {
        if(existingWindow == targetWindow)
        {
            storedWindow = existingWindow;
            storedName = existingName;
            WriteLog(2, StringFormat("Indicador %s já presente na janela %d", displayName, existingWindow));
            return true;
        }
        ChartIndicatorDelete(chart_id, existingWindow, existingName);
    }
    else if(storedWindow >= 0 && StringLen(storedName) > 0)
    {
        ChartIndicatorDelete(chart_id, storedWindow, storedName);
    }
    else if(LocateIndicatorByHints(chart_id, fallbackHints, existingWindow, existingName))
    {
        ChartIndicatorDelete(chart_id, existingWindow, existingName);
    }

    if(!ChartIndicatorAdd(chart_id, targetWindow, handle))
        return false;

    if(LocateIndicatorByHandle(chart_id, handle, storedWindow, storedName))
    {
        WriteLog(1, StringFormat("Indicador %s anexado na janela %d", storedName, storedWindow));
    }
    else
    {
        storedWindow = targetWindow;
        storedName = displayName;
        WriteLog(1, StringFormat("Indicador %s anexado (nome dinâmico não identificado)", displayName));
    }

    return true;
}

//+------------------------------------------------------------------+
//| Remover indicador visual                                          |
//+------------------------------------------------------------------+
void DetachVisualIndicator(int handle, int &storedWindow, string &storedName, const string fallbackHints)
{
    long chart_id = ChartID();
    bool removed = false;

    if(handle != INVALID_HANDLE)
    {
        int locatedWindow = -1;
        string locatedName = "";
        if(LocateIndicatorByHandle(chart_id, handle, locatedWindow, locatedName))
        {
            removed = ChartIndicatorDelete(chart_id, locatedWindow, locatedName);
        }
    }

    if(storedWindow != -1 && StringLen(storedName) > 0)
    {
        removed = ChartIndicatorDelete(chart_id, storedWindow, storedName) || removed;
    }

    if(!removed)
    {
        int locatedWindow = -1;
        string locatedName = "";
        if(LocateIndicatorByHints(chart_id, fallbackHints, locatedWindow, locatedName))
        {
            ChartIndicatorDelete(chart_id, locatedWindow, locatedName);
        }
    }

    storedWindow = -1;
    storedName = "";
}

//+------------------------------------------------------------------+
//| Garantir que indicador auxiliar permaneça anexado                |
//+------------------------------------------------------------------+
void EnsureVisualIndicatorAttached(int handle, int preferredWindow, const string fallbackHints, const string displayName, int &storedWindow, string &storedName)
{
    if(handle == INVALID_HANDLE)
        return;

    long chart_id = ChartID();
    int currentWindow = -1;
    string currentName = "";

    if(LocateIndicatorByHandle(chart_id, handle, currentWindow, currentName))
    {
        storedWindow = currentWindow;
        storedName = currentName;

        if(preferredWindow >= 0 && currentWindow != preferredWindow)
        {
            WriteLog(2, StringFormat("Indicador %s na janela %d (esperado %d). Reposicionando...", displayName, currentWindow, preferredWindow));
            AttachVisualIndicator(handle, preferredWindow, fallbackHints, displayName, storedWindow, storedName);
        }
        return;
    }

    WriteLog(2, StringFormat("Indicador %s ausente. Reanexando...", displayName));
    if(AttachVisualIndicator(handle, preferredWindow, fallbackHints, displayName, storedWindow, storedName))
        WriteLog(2, StringFormat("Indicador %s reanexado na janela %d", storedName, storedWindow));
    else
        WriteLog(0, StringFormat("Falha ao reanexar indicador %s", displayName));
}

//+------------------------------------------------------------------+
//| Anexar indicadores auxiliares (TrendMagic/CS/RSI/WAE)             |
//+------------------------------------------------------------------+
void AttachVisualIndicators()
{
    AttachVisualIndicator(g_handles.tm_m15, 0, HINT_TRENDMAGIC, "TrendMagic M15", g_trendMagicWindow, g_trendMagicShortName);
    AttachVisualIndicator(g_handles.cs_m15, 1, HINT_CURRENCY_STRENGTH, "Currency Strength M15", g_currencyStrengthWindow, g_currencyStrengthShortName);
    AttachVisualIndicator(g_handles.rsi_m15, 2, HINT_RSIOMA, "RSIOMA M15", g_rsiomaWindow, g_rsiomaShortName);
    AttachVisualIndicator(g_handles.wae_m15, 3, HINT_WAE, "WAE M15", g_waeWindow, g_waeShortName);
}

//+------------------------------------------------------------------+
//| Verificar se o GG TrendBar continua anexado                      |
//+------------------------------------------------------------------+
void EnsureGGTrendBarAttached()
{
    if(g_handles.gg_trendbar == INVALID_HANDLE)
        return;

    bool isTesting = MQLInfoInteger(MQL_TESTER);
    
    // Em modo backtest, pular verificação visual (não funciona)
    if(isTesting)
        return;

    long chart_id = ChartID();
    int currentWindow = -1;
    string indicatorName = "";

    bool ggFound = LocateIndicatorByHandle(chart_id, g_handles.gg_trendbar, currentWindow, indicatorName);
    
    if(ggFound && currentWindow == 0)
    {
        g_GGTrendBarAttached = true;
    }
    else if(ggFound && currentWindow != 0)
    {
        WriteLog(1, StringFormat("GG TrendBar na janela %d (esperado 0). Reposicionando...", currentWindow));
        ChartIndicatorDelete(chart_id, currentWindow, indicatorName);
        g_GGTrendBarAttached = false;
        if(AttachGGTrendBarToChart())
            WriteLog(1, "GG TrendBar reposicionado para janela 0.");
    }
    else
    {
        g_GGTrendBarAttached = false;
        WriteLog(2, "GG TrendBar ausente. Anexando...");
        if(AttachGGTrendBarToChart())
            WriteLog(2, "GG TrendBar anexado.");
    }

    // Verifica indicadores auxiliares
    EnsureVisualIndicatorAttached(g_handles.tm_m15, 0, HINT_TRENDMAGIC, "TrendMagic M15", g_trendMagicWindow, g_trendMagicShortName);
    EnsureVisualIndicatorAttached(g_handles.cs_m15, 1, HINT_CURRENCY_STRENGTH, "Currency Strength M15", g_currencyStrengthWindow, g_currencyStrengthShortName);
    EnsureVisualIndicatorAttached(g_handles.rsi_m15, 2, HINT_RSIOMA, "RSIOMA M15", g_rsiomaWindow, g_rsiomaShortName);
    EnsureVisualIndicatorAttached(g_handles.wae_m15, 3, HINT_WAE, "WAE M15", g_waeWindow, g_waeShortName);
}

//+------------------------------------------------------------------+
//| Obter handle TM por timeframe                                   |
//+------------------------------------------------------------------+
int GetTrendMagicHandle(ENUM_TIMEFRAMES timeframe)
{
    switch(timeframe)
    {
        case PERIOD_H4:  return g_handles.tm_h4;
        case PERIOD_H1:  return g_handles.tm_h1;
        case PERIOD_M30: return g_handles.tm_m30;
        case PERIOD_M15: return g_handles.tm_m15;
        default: return INVALID_HANDLE;
    }
}

//+------------------------------------------------------------------+
//| Obter handle RSI por timeframe                                  |
//+------------------------------------------------------------------+
int GetRSIHandle(ENUM_TIMEFRAMES timeframe)
{
    switch(timeframe)
    {
        case PERIOD_H4:  return g_handles.rsi_h4;
        case PERIOD_H1:  return g_handles.rsi_h1;
        case PERIOD_M30: return g_handles.rsi_m30;
        case PERIOD_M15: return g_handles.rsi_m15;
        default: return INVALID_HANDLE;
    }
}

//+------------------------------------------------------------------+
//| Obter handle WAE por timeframe                                  |
//+------------------------------------------------------------------+
int GetWAEHandle(ENUM_TIMEFRAMES timeframe)
{
    switch(timeframe)
    {
        case PERIOD_H4:  return g_handles.wae_h4;
        case PERIOD_H1:  return g_handles.wae_h1;
        case PERIOD_M30: return g_handles.wae_m30;
        case PERIOD_M15: return g_handles.wae_m15;
        default: return INVALID_HANDLE;
    }
}

//+------------------------------------------------------------------+
//| Classificar ativo                                                |
//+------------------------------------------------------------------+
ASSET_CLASS ClassifyAsset(string symbol)
{
    if(symbol == "EURUSD" || symbol == "GBPUSD" || symbol == "USDJPY" || 
       symbol == "AUDUSD" || symbol == "USDCAD" || symbol == "NZDUSD")
        return FOREX_MAJOR;
    
    if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "XAG") >= 0)
        return METALS;
    
    return FOREX_MAJOR;
}

//+------------------------------------------------------------------+
//| Obter sinal Trader Magic                                         |
//+------------------------------------------------------------------+
void GetTraderMagicSignal(string symbol, ENUM_TIMEFRAMES timeframe, TMSignal &signal)
{
    ZeroMemory(signal);
    
    int handle = GetTrendMagicHandle(timeframe);
    if(handle == INVALID_HANDLE)
    {
        WriteLog(0, StringFormat("ERRO: Handle TM inválido para %s", EnumToString(timeframe)));
        signal.isValid = false;
        return;
    }
    
    double tmUp[], tmDown[];
    ArraySetAsSeries(tmUp, true);
    ArraySetAsSeries(tmDown, true);
    
    if(CopyBuffer(handle, 0, 0, 3, tmUp) < 3 || CopyBuffer(handle, 1, 0, 3, tmDown) < 3)
    {
        WriteLog(0, "ERRO: Falha ao copiar buffers TM");
        signal.isValid = false;
        return;
    }
    
    signal.isValid = true;
    
    // Detectar direção baseado em qual buffer tem valor
    bool currentBullish = (tmUp[0] != EMPTY_VALUE && tmDown[0] == EMPTY_VALUE);
    bool currentBearish = (tmDown[0] != EMPTY_VALUE && tmUp[0] == EMPTY_VALUE);
    
    if(currentBullish)
    {
        signal.direction = TRADE_BUY;
        signal.strength = 0.8;
    }
    else if(currentBearish)
    {
        signal.direction = TRADE_SELL;
        signal.strength = 0.8;
    }
    else
    {
        signal.direction = TRADE_NONE;
        signal.strength = 0.0;
    }
    
    WriteLog(3, StringFormat("TM %s %s: %s (força=%.2f)", 
        symbol, EnumToString(timeframe), EnumToString(signal.direction), signal.strength));
}

//+------------------------------------------------------------------+
//| Obter sinal Currency Strength                                    |
//+------------------------------------------------------------------+
void GetCurrencyStrengthSignal(string symbol, TRADE_DIRECTION direction, ASSET_CLASS assetType, CSSignal &signal)
{
    ZeroMemory(signal);
    
    // CS só para Forex, WDO e Metais
    if(assetType != FOREX_MAJOR && assetType != FOREX_MINOR && 
       assetType != FOREX_EXOTIC && assetType != CURRENCY_B3 && assetType != METALS)
    {
        signal.isValid = false;
        return;
    }
    
    if(g_handles.cs_m15 == INVALID_HANDLE)
    {
        WriteLog(0, "ERRO: Handle CS inválido");
        signal.isValid = false;
        return;
    }
    
    double csBuffer[];
    ArraySetAsSeries(csBuffer, true);
    
    if(CopyBuffer(g_handles.cs_m15, 0, 0, 3, csBuffer) < 3)
    {
        WriteLog(0, "ERRO: Falha ao copiar buffer CS");
        signal.isValid = false;
        return;
    }
    
    signal.isValid = true;
    signal.baseStrength = csBuffer[0];
    signal.quoteStrength = (ArraySize(csBuffer) > 1) ? csBuffer[1] : csBuffer[0];
    signal.isInverse = (assetType == METALS);
    
    // Lógica de alinhamento
    if(signal.isInverse)
    {
        // Metais: interpretação inversa (USD fraco = ouro forte)
        signal.isAligned = (direction == TRADE_BUY) ? 
            (signal.quoteStrength < signal.baseStrength) : 
            (signal.quoteStrength > signal.baseStrength);
    }
    else
    {
        // Forex normal
        signal.isAligned = (direction == TRADE_BUY) ? 
            (signal.baseStrength > signal.quoteStrength) : 
            (signal.baseStrength < signal.quoteStrength);
    }
    
    WriteLog(3, StringFormat("CS: Base=%.2f Quote=%.2f Alinhado=%s", 
        signal.baseStrength, signal.quoteStrength, signal.isAligned ? "SIM" : "NÃO"));
}

//+------------------------------------------------------------------+
//| Obter sinal RSI OMA                                              |
//+------------------------------------------------------------------+
void GetRSIOMASignal(string symbol, ENUM_TIMEFRAMES timeframe, TRADE_DIRECTION direction, RSISignal &signal)
{
    ZeroMemory(signal);
    
    int handle = GetRSIHandle(timeframe);
    if(handle == INVALID_HANDLE)
    {
        WriteLog(0, StringFormat("ERRO: Handle RSI inválido para %s", EnumToString(timeframe)));
        signal.isValid = false;
        return;
    }
    
    double rsiRed[], rsiBlue[];
    ArraySetAsSeries(rsiRed, true);
    ArraySetAsSeries(rsiBlue, true);
    
    if(CopyBuffer(handle, 0, 0, 3, rsiRed) < 3 || CopyBuffer(handle, 1, 0, 3, rsiBlue) < 3)
    {
        WriteLog(0, "ERRO: Falha ao copiar buffers RSI");
        signal.isValid = false;
        return;
    }
    
    signal.isValid = true;
    signal.redValue = rsiRed[0];
    signal.blueValue = rsiBlue[0];
    signal.slope = (rsiRed[0] - rsiRed[2]) * 50.0;
    
    if(direction == TRADE_BUY)
        signal.isAligned = (signal.redValue > signal.blueValue) && (signal.slope > 0.1);
    else
        signal.isAligned = (signal.redValue < signal.blueValue) && (signal.slope < -0.1);
    
    WriteLog(3, StringFormat("RSI %s: Red=%.2f Blue=%.2f Slope=%.2f Alinhado=%s", 
        EnumToString(timeframe), signal.redValue, signal.blueValue, signal.slope, 
        signal.isAligned ? "SIM" : "NÃO"));
}

//+------------------------------------------------------------------+
//| Obter sinal WAE                                                  |
//+------------------------------------------------------------------+
void GetWAESignal(string symbol, ENUM_TIMEFRAMES timeframe, TRADE_DIRECTION direction, WAESignal &signal)
{
    ZeroMemory(signal);
    
    int handle = GetWAEHandle(timeframe);
    if(handle == INVALID_HANDLE)
    {
        WriteLog(0, StringFormat("ERRO: Handle WAE inválido para %s", EnumToString(timeframe)));
        signal.isValid = false;
        return;
    }
    
    double waeMain[];
    ArraySetAsSeries(waeMain, true);
    
    if(CopyBuffer(handle, 0, 0, 3, waeMain) < 3)
    {
        WriteLog(0, "ERRO: Falha ao copiar buffer WAE");
        signal.isValid = false;
        return;
    }
    
    signal.isValid = true;
    signal.mainValue = waeMain[0];
    signal.isExpanding = (MathAbs(waeMain[0]) > MathAbs(waeMain[1]));
    signal.hasStrength = (MathAbs(signal.mainValue) > 10.0);
    
    if(direction == TRADE_BUY)
        signal.isAligned = (signal.mainValue > 0) && signal.isExpanding && signal.hasStrength;
    else
        signal.isAligned = (signal.mainValue < 0) && signal.isExpanding && signal.hasStrength;
    
    WriteLog(3, StringFormat("WAE %s: Main=%.2f Expandindo=%s Força=%s Alinhado=%s", 
        EnumToString(timeframe), signal.mainValue, signal.isExpanding ? "SIM" : "NÃO", 
        signal.hasStrength ? "SIM" : "NÃO", signal.isAligned ? "SIM" : "NÃO"));
}

//+------------------------------------------------------------------+
//| Obter sinal GG TrendBar - VERSÃO CORRIGIDA COM BUFFERS          |
//+------------------------------------------------------------------+
void GetGGTrendBarSignal(string symbol, TRADE_DIRECTION direction, GGTrendBarSignal &signal)
{
    ZeroMemory(signal);
    
    if(g_handles.gg_trendbar == INVALID_HANDLE)
    {
        WriteLog(0, "ERRO: Handle GG TrendBar inválido");
        signal.isValid = false;
        return;
    }
    
    // Ler buffers do indicador GG TrendBar
    // Buffer 0=M1, 1=M5, 2=M15, 3=M30, 4=H1, 5=H4, 6=D1, 7=W1, 8=MN1
    // Valores: 1 = Bullish, 0 = Neutral, -1 = Bearish
    
    double values[9];  // Array para armazenar todos os timeframes
    signal.bullishCount = 0;
    signal.bearishCount = 0;
    signal.isValid = true;
    
    // DEBUG: Log detalhado da leitura dos buffers
    string bufferDebug = "GG Buffers: ";
    
    // Ler cada buffer individualmente
    for(int i = 0; i < 9; i++)
    {
        double buffer[1];
        if(CopyBuffer(g_handles.gg_trendbar, i, 0, 1, buffer) > 0)
        {
            values[i] = buffer[0];
            
            if(values[i] == 1.0)
                signal.bullishCount++;
            else if(values[i] == -1.0)
                signal.bearishCount++;
                
            bufferDebug += StringFormat("[%d]=%.0f ", i, values[i]);
        }
        else
        {
            values[i] = 0.0; // Neutro se não conseguir ler
            bufferDebug += StringFormat("[%d]=ERR ", i);
            WriteLog(0, StringFormat("ERRO: Não foi possível ler buffer %d do GG TrendBar", i));
        }
    }
    
    WriteLog(2, bufferDebug);
    
    // Focar nos timeframes principais para o sinal: M15(2), M30(3), H1(4), H4(5)
    int relevantBullish = 0;
    int relevantBearish = 0;
    int relevantIndices[] = {2, 3, 4, 5}; // M15, M30, H1, H4
    
    for(int j = 0; j < 4; j++)
    {
        int idx = relevantIndices[j];
        if(values[idx] == 1.0) relevantBullish++;
        else if(values[idx] == -1.0) relevantBearish++;
    }
    
    // Calcular porcentagem de alinhamento baseada nos 9 timeframes
    int totalSignals = signal.bullishCount + signal.bearishCount;
    if(totalSignals > 0)
    {
        if(signal.bullishCount > signal.bearishCount)
            signal.alignmentPercent = (double)signal.bullishCount / 9.0 * 100.0;
        else
            signal.alignmentPercent = -(double)signal.bearishCount / 9.0 * 100.0;
    }
    else
    {
        signal.alignmentPercent = 0.0;
    }
    
    // Verificar alinhamento com direção desejada (usar timeframes relevantes)
    if(direction == TRADE_BUY)
    {
        // Precisa de pelo menos 3 dos 4 TFs principais altistas (75%)
        signal.isAligned = (relevantBullish >= 3);
        signal.strongTrend = (relevantBullish >= 4); // Todos 4 altistas
    }
    else if(direction == TRADE_SELL)
    {
        // Precisa de pelo menos 3 dos 4 TFs principais baixistas (75%)
        signal.isAligned = (relevantBearish >= 3);
        signal.strongTrend = (relevantBearish >= 4); // Todos 4 baixistas
    }
    else
    {
        signal.isAligned = false;
        signal.strongTrend = false;
    }
    
    // Análise detalhada incluindo valores individuais dos TFs principais
    signal.analysis = StringFormat("Bull:%d Bear:%d (M15:%+.0f M30:%+.0f H1:%+.0f H4:%+.0f) Align:%.1f%% Strong:%s", 
        signal.bullishCount, signal.bearishCount,
        values[2], values[3], values[4], values[5], // M15, M30, H1, H4
        signal.alignmentPercent, 
        signal.strongTrend ? "SIM" : "NÃO");
    
    WriteLog(2, StringFormat("GG TrendBar %s dir=%s: %s | Alinhado=%s | RelBull=%d RelBear=%d", 
        symbol, 
        direction == TRADE_BUY ? "BUY" : "SELL",
        signal.analysis, 
        signal.isAligned ? "SIM" : "NÃO",
        relevantBullish,
        relevantBearish));
}

//+------------------------------------------------------------------+
//| Análise Multi-Timeframe                                         |
//+------------------------------------------------------------------+
void AnalyzeTimeframes(string symbol, TRADE_DIRECTION direction, MultiTFResult &result)
{
    ZeroMemory(result);
    
    WriteLog(3, StringFormat("Analisando MTF para %s direção %s", symbol, EnumToString(direction)));
    
    TMSignal tmH4, tmH1, tmM30;
    GetTraderMagicSignal(symbol, PERIOD_H4, tmH4);
    GetTraderMagicSignal(symbol, PERIOD_H1, tmH1);
    GetTraderMagicSignal(symbol, PERIOD_M30, tmM30);
    
    result.H4_aligned = (tmH4.isValid && tmH4.direction == direction);
    result.H1_aligned = (tmH1.isValid && tmH1.direction == direction);
    result.M30_aligned = (tmM30.isValid && tmM30.direction == direction);
    
    result.structure_valid = true;
    result.direction = direction;
    result.isValid = result.H4_aligned && result.H1_aligned;
    
    result.quality_score = 0;
    if(result.H4_aligned) result.quality_score++;
    if(result.H1_aligned) result.quality_score++;
    if(result.M30_aligned) result.quality_score++;
    if(result.structure_valid) result.quality_score++;
    
    result.analysis_notes = StringFormat("H4:%s H1:%s M30:%s Score:%d", 
        result.H4_aligned ? "OK" : "FAIL",
        result.H1_aligned ? "OK" : "FAIL", 
        result.M30_aligned ? "OK" : "WEAK",
        result.quality_score);
    
    WriteLog(2, StringFormat("MTF %s: %s", symbol, result.analysis_notes));
}

//+------------------------------------------------------------------+
//| Converter enum para string                                       |
//+------------------------------------------------------------------+
string EnumToString(ASSET_CLASS assetClass)
{
    switch(assetClass)
    {
        case FOREX_MAJOR: return "FOREX_MAJOR";
        case FOREX_MINOR: return "FOREX_MINOR";
        case METALS: return "METALS";
        default: return "UNKNOWN";
    }
}

string EnumToString(TRADE_DIRECTION direction)
{
    switch(direction)
    {
        case TRADE_BUY: return "BUY";
        case TRADE_SELL: return "SELL";
        default: return "NONE";
    }
}

string EnumToString(SETUP_CLASSIFICATION classification)
{
    switch(classification)
    {
        case PREMIUM: return "PREMIUM";
        case GOOD: return "GOOD";
        default: return "REJECT";
    }
}

//+------------------------------------------------------------------+
//| Sistema de pontuação completo                                    |
//+------------------------------------------------------------------+
void CalculateSetupScore(string symbol, ASSET_CLASS assetType, TRADE_DIRECTION direction, SetupScore &score)
{
    ZeroMemory(score);
    
    WriteLog(3, StringFormat("Calculando score para %s %s", symbol, EnumToString(direction)));
    
    // 1. Trader Magic (obrigatório)
    TMSignal tm;
    GetTraderMagicSignal(symbol, PERIOD_M15, tm);
    if(tm.isValid && tm.direction == direction)
        score.traderMagicPoints = 1;
    
    // 2. Currency Strength (se aplicável)
    CSSignal cs;
    GetCurrencyStrengthSignal(symbol, direction, assetType, cs);
    if(cs.isValid && cs.isAligned)
        score.currencyStrengthPoints = 1;
    
    // 3. RSI OMA
    RSISignal rsi;
    GetRSIOMASignal(symbol, PERIOD_M15, direction, rsi);
    if(rsi.isValid && rsi.isAligned)
        score.rsiomaPoints = 1;
    
    // 4. WAE
    WAESignal wae;
    GetWAESignal(symbol, PERIOD_M15, direction, wae);
    if(wae.isValid && wae.isAligned)
        score.waePoints = 1;
    
    // 5. GG TrendBar
    GGTrendBarSignal gg;
    GetGGTrendBarSignal(symbol, direction, gg);
    bool ggPass = (gg.isValid && gg.isAligned && MathAbs(gg.alignmentPercent) >= GG_MinAlignmentPercent);
    if(ggPass)
        score.ggTrendBarPoints = 1;
    
    score.totalPoints = score.traderMagicPoints + score.currencyStrengthPoints + 
                       score.rsiomaPoints + score.waePoints + score.ggTrendBarPoints;
    
    // Classificação conforme tipo de ativo
    if(assetType == FOREX_MAJOR || assetType == FOREX_MINOR || 
       assetType == FOREX_EXOTIC || assetType == CURRENCY_B3 || assetType == METALS)
    {
        // Forex/Metais: 4 filtros (CS+RSI+WAE+GG), precisa 3 de 4 para PREMIUM
        score.requiredPoints = 3;
        if(score.totalPoints >= 4) score.classification = PREMIUM;
        else if(score.totalPoints >= 3) score.classification = GOOD;
        else score.classification = REJECT;
    }
    else
    {
        // Índices: 3 filtros (RSI+WAE+GG), precisa 2 de 3 para GOOD
        score.requiredPoints = 2;
        int indexPoints = score.rsiomaPoints + score.waePoints + score.ggTrendBarPoints;
        if(indexPoints >= 3) score.classification = PREMIUM;
        else if(indexPoints >= 2) score.classification = GOOD;
        else score.classification = REJECT;
    }
    
    score.reasoning = StringFormat("TM:%d CS:%d RSI:%d WAE:%d GG:%d = %d pontos - %s",
        score.traderMagicPoints, score.currencyStrengthPoints,
        score.rsiomaPoints, score.waePoints, score.ggTrendBarPoints,
        score.totalPoints, EnumToString(score.classification));
}

bool IsSetupValid(SetupScore &score)
{
    return (score.classification == PREMIUM || score.classification == GOOD);
}

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
    WriteLog(1, "========================================");
    WriteLog(1, "NEXUS CONFLUENCE EA v4.0 - INICIALIZANDO");
    WriteLog(1, "========================================");
    
    WriteLog(1, "Verificando arquivos necessários...");
    WriteLog(1, "");
    WriteLog(1, "INDICADORES NECESSÁRIOS em MQL5\\Indicators\\NexusConfluenceEA\\:");
    WriteLog(1, "  1. TrendMagic_MT5.ex5");
    WriteLog(1, "  2. CurrencyStrengthMeter_MT5.ex5");
    WriteLog(1, "  3. RSIOMA_v2HHLSX_MT5.ex5");
    WriteLog(1, "  4. WaddahAttarExplosion_Professional.ex5");
    WriteLog(1, "  5. GG_TrendBar_Indicator.ex5");
    WriteLog(1, "");
    WriteLog(1, "Se algum arquivo tiver nome diferente, ajuste nos inputs!");
    WriteLog(1, "");
    
    if(!InitializeIndicatorHandles(_Symbol))
    {
        WriteLog(0, "========================================");
        WriteLog(0, "ERRO CRÍTICO: Falha ao inicializar indicadores!");
        WriteLog(0, "========================================");
        WriteLog(0, "");
        WriteLog(0, "VERIFIQUE:");
        WriteLog(0, "1. Todos os 5 arquivos .ex5 estão na pasta correta");
        WriteLog(0, "2. Nomes dos arquivos correspondem aos inputs");
        WriteLog(0, "3. Indicadores compilam sem erros");
        WriteLog(0, "4. Terminal MT5 foi reiniciado após copiar arquivos");
        WriteLog(0, "");
        WriteLog(0, "Caminho esperado:");
        WriteLog(0, "C:\\Users\\[USER]\\AppData\\Roaming\\MetaQuotes\\Terminal\\");
        WriteLog(0, "[BROKER_ID]\\MQL5\\Indicators\\NexusConfluenceEA\\");
        WriteLog(0, "");
        
        Alert("ERRO: Indicadores não carregados! Verifique os logs.");
        return INIT_FAILED;
    }
    
    trade.SetExpertMagicNumber(EA_MAGIC_NUMBER);
    g_InitializationComplete = true;
    
    WriteLog(1, "");
    WriteLog(1, "========================================");
    WriteLog(1, "✓✓✓ EA INICIALIZADO COM SUCESSO! ✓✓✓");
    WriteLog(1, "========================================");
    WriteLog(1, "");
    WriteLog(1, "Configurações ativas:");
    WriteLog(1, StringFormat("  - Símbolo: %s", _Symbol));
    WriteLog(1, StringFormat("  - Timeframe: %s", EnumToString(_Period)));
    WriteLog(1, StringFormat("  - Risco: %.1f%%", AccountRiskPercent));
    WriteLog(1, StringFormat("  - Max trades: %d", MaxSimultaneousTrades));
    WriteLog(1, StringFormat("  - Magic Number: %d", EA_MAGIC_NUMBER));
    WriteLog(1, "");
    WriteLog(1, "Sistema pronto para análise de setups!");
    WriteLog(1, "Aguardando próximo candle para análise...");
    WriteLog(1, "");
    
    if(SendAlerts)
        SendNotification("✓ Nexus Confluence EA v4.0 iniciado em " + _Symbol);
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    WriteLog(1, "=== FINALIZANDO NEXUS CONFLUENCE EA ===");

    if(g_handles.gg_trendbar != INVALID_HANDLE)
    {
        int ggWindow = -1;
        string ggName = "";
        if(!LocateIndicatorByHandle(ChartID(), g_handles.gg_trendbar, ggWindow, ggName))
            ChartIndicatorDelete(ChartID(), 0, GG_TRENDBAR_SHORTNAME);
        else
            ChartIndicatorDelete(ChartID(), ggWindow, ggName);
        g_GGTrendBarAttached = false;
    }

    DetachVisualIndicator(g_handles.tm_m15, g_trendMagicWindow, g_trendMagicShortName, HINT_TRENDMAGIC);
    DetachVisualIndicator(g_handles.cs_m15, g_currencyStrengthWindow, g_currencyStrengthShortName, HINT_CURRENCY_STRENGTH);
    DetachVisualIndicator(g_handles.rsi_m15, g_rsiomaWindow, g_rsiomaShortName, HINT_RSIOMA);
    DetachVisualIndicator(g_handles.wae_m15, g_waeWindow, g_waeShortName, HINT_WAE);

    ReleaseIndicatorHandles();
    
    if(SendAlerts)
        SendNotification("Nexus Confluence EA finalizado");
}

//+------------------------------------------------------------------+
//| Expert tick                                                      |
//+------------------------------------------------------------------+
void OnTick()
{
    if(!g_InitializationComplete) return;
    
    bool isTesting = MQLInfoInteger(MQL_TESTER);
    
    // Verificar indicadores apenas em modo real (não em backtest)
    if(!isTesting)
    {
        static datetime lastPanelCheck = 0;
        if(TimeCurrent() - lastPanelCheck >= 300) // 5 minutos
        {
            EnsureGGTrendBarAttached();
            lastPanelCheck = TimeCurrent();
        }
    }

    static datetime lastTest = 0;
    if(TimeCurrent() - lastTest >= 60)
    {
        lastTest = TimeCurrent();
        
        ASSET_CLASS assetType = ClassifyAsset(_Symbol);
        
        SetupScore scoreBuy, scoreSell;
        CalculateSetupScore(_Symbol, assetType, TRADE_BUY, scoreBuy);
        CalculateSetupScore(_Symbol, assetType, TRADE_SELL, scoreSell);
        
        WriteLog(1, StringFormat("=== ANÁLISE %s ===", _Symbol));
        WriteLog(1, "BUY: " + scoreBuy.reasoning);
        WriteLog(1, "SELL: " + scoreSell.reasoning);
        
        if(IsSetupValid(scoreBuy))
        {
            WriteLog(0, StringFormat("*** SETUP BUY VÁLIDO: %s ***", scoreBuy.reasoning));
            if(SendAlerts && !isTesting)
                SendNotification(StringFormat("Nexus: Setup BUY %s - %s", _Symbol, EnumToString(scoreBuy.classification)));
        }
        
        if(IsSetupValid(scoreSell))
        {
            WriteLog(0, StringFormat("*** SETUP SELL VÁLIDO: %s ***", scoreSell.reasoning));
            if(SendAlerts && !isTesting)
                SendNotification(StringFormat("Nexus: Setup SELL %s - %s", _Symbol, EnumToString(scoreSell.classification)));
        }
    }
}
//+------------------------------------------------------------------+