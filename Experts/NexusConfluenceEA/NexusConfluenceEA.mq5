//+------------------------------------------------------------------+
//|                                          NexusConfluenceEA.mq5   |
//|                                      Nexus Confluence EA v1.00   |
//|                         Multi-Timeframe Confluence Trading System |
//|                                6-Gate Validation | Score System  |
//+------------------------------------------------------------------+
#property copyright "Nexus Confluence EA"
#property link      "https://github.com/nexusconfluence"
#property version   "1.00"
#property description "Production EA - 6-Gate MTF Confluence System"
#property description "ALWAYS shift=1 | Score ≥+2 BUY | Score ≤-2 SELL"
#property strict

// Include MQL5 standard libraries
#include <Trade\Trade.mqh>

// Include Nexus Confluence modules
#include <NexusConfluenceEA\Modules\Core.mqh>
#include <NexusConfluenceEA\Modules\MarketAccess.mqh>
#include <NexusConfluenceEA\Modules\IndicatorHub.mqh>
#include <NexusConfluenceEA\Modules\SignalEngine.mqh>
#include <NexusConfluenceEA\Modules\RiskExecution.mqh>

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== GENERAL SETTINGS ==="
input int      InpMagicNumber    = 20241024;  // Magic Number
input int      InpLogLevel       = 2;         // Log Level (1=Executive, 2=Operational, 3=Debug)

input group "=== RISK MANAGEMENT ==="
input double   InpLotSize        = 0.01;      // Fixed Lot Size
input int      InpStopLoss       = 100;       // Stop Loss (points)
input int      InpTakeProfit     = 200;       // Take Profit (points)
input int      InpMaxSlippage    = 10;        // Max Slippage (points)

input group "=== SPREAD FILTER ==="
input int      InpMaxSpread      = 20;        // Max Spread (points)
input double   InpSpreadMulti    = 1.5;       // Spread Multiplier (vs median)
input int      InpSpreadPeriod   = 20;        // Spread Calculation Period (candles)

input group "=== TIME FILTER ==="
input bool     InpUseTimeFilter  = false;     // Use Time Filter
input string   InpStartTime      = "09:00";   // Start Time (HH:MM)
input string   InpEndTime        = "17:00";   // End Time (HH:MM)
input bool     InpSkipMonday     = true;      // Skip Monday Open (Forex/Metals/Indices)

input group "=== MULTI-TIMEFRAME SETTINGS ==="
input ENUM_TIMEFRAMES InpMacro1TF      = PERIOD_H4;  // Macro 1 Timeframe (Highest)
input ENUM_TIMEFRAMES InpMacro2TF      = PERIOD_H1;  // Macro 2 Timeframe
input ENUM_TIMEFRAMES InpMacro3TF      = PERIOD_M30; // Macro 3 Timeframe
input ENUM_TIMEFRAMES InpOperationalTF = PERIOD_M15; // Operational Timeframe
input int             InpMinScore      = 2;          // Minimum MTF Score (≥+2 BUY, ≤-2 SELL)

//+------------------------------------------------------------------+
//| GLOBAL OBJECTS                                                   |
//+------------------------------------------------------------------+
CCore           *g_core;
CMarketAccess   *g_market;
CIndicatorHub   *g_indicators;
CSignalEngine   *g_signals;
CRiskExecution  *g_executor;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("==========================================");
    Print("    NEXUS CONFLUENCE EA v1.00 STARTING    ");
    Print("==========================================");
    
    // Create module objects
    g_core = new CCore();
    g_market = new CMarketAccess();
    g_indicators = new CIndicatorHub();
    g_signals = new CSignalEngine();
    g_executor = new CRiskExecution();
    
    if(g_core == NULL || g_market == NULL || g_indicators == NULL || 
       g_signals == NULL || g_executor == NULL)
    {
        Print("❌ CRITICAL ERROR: Failed to create module objects");
        CleanupModules();
        return(INIT_FAILED);
    }
    
    // Initialize Core module
    if(!g_core.Init(InpMagicNumber, InpLogLevel))
    {
        Print("❌ CRITICAL ERROR: Core initialization failed");
        CleanupModules();
        return(INIT_FAILED);
    }
    
    // Initialize MarketAccess module
    if(!g_market.Init(_Symbol, InpSpreadPeriod, InpSpreadMulti, InpMaxSpread,
                      InpSkipMonday, InpUseTimeFilter, InpStartTime, InpEndTime))
    {
        Print("❌ CRITICAL ERROR: MarketAccess initialization failed");
        CleanupModules();
        return(INIT_FAILED);
    }
    
    // Initialize IndicatorHub module
    if(!g_indicators.Init(_Symbol, InpOperationalTF))
    {
        Print("❌ CRITICAL ERROR: IndicatorHub initialization failed");
        CleanupModules();
        return(INIT_FAILED);
    }
    
    // Initialize SignalEngine module
    if(!g_signals.Init(g_core, g_market, g_indicators, 
                       InpMacro1TF, InpMacro2TF, InpMacro3TF, InpOperationalTF,
                       InpMinScore))
    {
        Print("❌ CRITICAL ERROR: SignalEngine initialization failed");
        CleanupModules();
        return(INIT_FAILED);
    }
    
    // Initialize RiskExecution module
    if(!g_executor.Init(g_core, g_market, InpMagicNumber, InpLotSize, 
                        InpStopLoss, InpTakeProfit, InpMaxSlippage))
    {
        Print("❌ CRITICAL ERROR: RiskExecution initialization failed");
        CleanupModules();
        return(INIT_FAILED);
    }
    
    // Print configuration summary
    PrintConfiguration();
    
    Print("==========================================");
    Print("  ✅ NEXUS CONFLUENCE EA READY TO TRADE  ");
    Print("==========================================");
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("==========================================");
    Print("      NEXUS CONFLUENCE EA STOPPING       ");
    Print("      Reason: ", GetDeinitReasonText(reason));
    Print("==========================================");
    
    CleanupModules();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // GATE 0: Check for new candle (shift=1 enforcement)
    if(!g_core.IsNewCandle())
        return;
    
    g_core.LogMessage(3, "=== NEW CANDLE - Processing Gates ===");
    
    // Get closed bar time for synchronization
    datetime closed_bar_time = iTime(_Symbol, InpOperationalTF, 1);
    if(closed_bar_time == 0)
    {
        g_core.LogMessage(1, "❌ ERROR: Failed to get closed bar time");
        return;
    }
    
    // Update indicator buffer cache (ONCE per candle, shift=1)
    if(!g_indicators.UpdateBufferCache(closed_bar_time))
    {
        g_core.LogMessage(1, "❌ ERROR: Failed to update indicator buffers");
        return;
    }
    
    // Set buffer sync time in Core
    g_core.SetBufferSyncTime(closed_bar_time);
    
    // Check if already has open position
    if(g_executor.HasOpenPosition())
    {
        g_core.LogMessage(3, "⏸️ Position already open - waiting for close");
        
        // Update state if needed
        if(g_core.GetCurrentState() != STATE_WAITING_CLOSE)
        {
            g_core.UpdateStateMachine(STATE_WAITING_CLOSE);
        }
        
        return;
    }
    
    // Reset state to IDLE if no position
    if(g_core.GetCurrentState() != STATE_IDLE)
    {
        g_core.UpdateStateMachine(STATE_IDLE);
    }
    
    // Check if can process new signal
    if(!g_core.CanProcessSignal())
    {
        g_core.LogMessage(3, "⏸️ State machine blocks new signal processing");
        return;
    }
    
    // Check if can trade on this candle (anti-duplication)
    if(!g_executor.CanTradeOnNewCandle(closed_bar_time))
    {
        g_core.LogMessage(3, "⏸️ Trade already executed on this candle");
        return;
    }
    
    // Process all 6 gates sequentially
    if(!g_signals.ProcessAllGates())
    {
        // Signal rejected by one of the gates
        // Already logged by SignalEngine
        return;
    }
    
    // All gates passed - get signal details
    ENUM_SIGNAL_CLASS signal_class = g_signals.GetSignalClass();
    ENUM_SIGNAL_DIRECTION signal_direction = g_signals.GetSignalDirection();
    int mtf_score = g_signals.GetMTFScore();
    
    // Validate signal
    if(signal_class == SIGNAL_NONE || signal_class == SIGNAL_REJECT)
    {
        g_core.LogMessage(2, "⚠️ Signal validation failed after gates passed");
        return;
    }
    
    if(signal_direction == SIGNAL_DIR_NONE)
    {
        g_core.LogMessage(2, "⚠️ Signal direction is NONE after gates passed");
        return;
    }
    
    // Update state machine
    g_core.UpdateStateMachine(STATE_SIGNAL_DETECTED);
    
    // Prepare trade comment
    string comment = StringFormat("%s_%s_S%+d", 
                     EnumToString(signal_class),
                     EnumToString(signal_direction),
                     mtf_score);
    
    // Execute trade
    bool trade_result = false;
    
    if(signal_direction == SIGNAL_DIR_BUY)
    {
        trade_result = g_executor.ExecuteBuy(comment);
    }
    else if(signal_direction == SIGNAL_DIR_SELL)
    {
        trade_result = g_executor.ExecuteSell(comment);
    }
    
    if(trade_result)
    {
        // Trade executed successfully
        g_core.LogMessage(1, StringFormat("✅ %s %s EXECUTED | Score: %+d | Symbol: %s",
                          EnumToString(signal_class),
                          EnumToString(signal_direction),
                          mtf_score,
                          _Symbol));
    }
    else
    {
        // Trade execution failed - reset state
        g_core.UpdateStateMachine(STATE_IDLE);
        g_core.LogMessage(1, "❌ Trade execution FAILED - State reset to IDLE");
    }
}

//+------------------------------------------------------------------+
//| Cleanup module objects                                           |
//+------------------------------------------------------------------+
void CleanupModules()
{
    if(g_executor != NULL)
    {
        delete g_executor;
        g_executor = NULL;
    }
    
    if(g_signals != NULL)
    {
        delete g_signals;
        g_signals = NULL;
    }
    
    if(g_indicators != NULL)
    {
        delete g_indicators;
        g_indicators = NULL;
    }
    
    if(g_market != NULL)
    {
        delete g_market;
        g_market = NULL;
    }
    
    if(g_core != NULL)
    {
        delete g_core;
        g_core = NULL;
    }
}

//+------------------------------------------------------------------+
//| Print configuration summary                                      |
//+------------------------------------------------------------------+
void PrintConfiguration()
{
    Print("=== EA CONFIGURATION ===");
    Print("Symbol: ", _Symbol);
    Print("Magic Number: ", InpMagicNumber);
    Print("Lot Size: ", InpLotSize);
    Print("Stop Loss: ", InpStopLoss, " points");
    Print("Take Profit: ", InpTakeProfit, " points");
    Print("Max Slippage: ", InpMaxSlippage, " points");
    Print("Max Spread: ", InpMaxSpread, " points");
    Print("Spread Multiplier: ", InpSpreadMulti);
    Print("Skip Monday Open: ", InpSkipMonday ? "Yes" : "No");
    Print("Time Filter: ", InpUseTimeFilter ? "Enabled" : "Disabled");
    if(InpUseTimeFilter)
    {
        Print("Trading Hours: ", InpStartTime, " - ", InpEndTime);
    }
    Print("=== MTF CONFIGURATION ===");
    Print("Macro 1: ", EnumToString(InpMacro1TF));
    Print("Macro 2: ", EnumToString(InpMacro2TF));
    Print("Macro 3: ", EnumToString(InpMacro3TF));
    Print("Operational: ", EnumToString(InpOperationalTF));
    Print("Min Score: ", InpMinScore);
    Print("Log Level: ", InpLogLevel, " (1=Executive, 2=Operational, 3=Debug)");
    Print("========================");
}

//+------------------------------------------------------------------+
//| Get deinit reason text                                           |
//+------------------------------------------------------------------+
string GetDeinitReasonText(int reason)
{
    switch(reason)
    {
        case REASON_PROGRAM:     return "Expert removed from chart";
        case REASON_REMOVE:      return "Expert removed from chart";
        case REASON_RECOMPILE:   return "Expert recompiled";
        case REASON_CHARTCHANGE: return "Chart symbol or period changed";
        case REASON_CHARTCLOSE:  return "Chart closed";
        case REASON_PARAMETERS:  return "Input parameters changed";
        case REASON_ACCOUNT:     return "Account changed";
        case REASON_TEMPLATE:    return "New template applied";
        case REASON_INITFAILED:  return "Initialization failed";
        case REASON_CLOSE:       return "Terminal closed";
        default:                 return "Unknown reason";
    }
}
//+------------------------------------------------------------------+
