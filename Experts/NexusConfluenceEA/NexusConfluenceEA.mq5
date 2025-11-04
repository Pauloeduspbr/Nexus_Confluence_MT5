//+------------------------------------------------------------------+
//|                                          NexusConfluenceEA.mq5   |
//|                                      Nexus Confluence EA v2.03   |
//|                         Multi-Timeframe Confluence Trading System |
//|                                6-Gate Validation | Score System  |
//|                          + Break Even + Trailing Stop + DD Prot  |
//|                                                                    |
//| v2.03 (04/11/2025): Robustness fixes                             |
//|   - Gate 3: GOOD requires ST aligned (sem neutro); PREMIUM strict|
//|   - AsymmetricRisk: removido +1 p/ PREMIUM (alinhado ao módulo)  |
//|   - Execução: usar RiskExecution (retry + lote normalizado)      |
//|   - MarketAccess: spread dinâmico com aquecimento + hora wrap    |
//|   - Entrada: removido realtime momentum guard (shift=0)          |
//+------------------------------------------------------------------+
#property copyright "Nexus Confluence EA"
#property link      "https://github.com/nexusconfluence"
#property version   "2.03"
#property description "Production EA - 6-Gate MTF Confluence System"
#property description "ALWAYS shift=1 | Score ≥+2 BUY | Score ≤-2 SELL"
#property description "v2.03: Gate3 stricter; RiskExec; spread warm-up; no RT guard"
#property strict

// Include MQL5 standard libraries
#include <Trade\Trade.mqh>

// Include Nexus Confluence v2.00 INPUT CONFIG (MUST BE FIRST!)
#include <NexusConfluenceEA\Modules\NexusInputsConfig.mqh>

// Include Nexus Confluence ORIGINAL modules
#include <NexusConfluenceEA\Modules\Core.mqh>
#include <NexusConfluenceEA\Modules\MarketAccess.mqh>
#include <NexusConfluenceEA\Modules\IndicatorHub.mqh>
#include <NexusConfluenceEA\Modules\SignalEngine.mqh>
#include <NexusConfluenceEA\Modules\RiskExecution.mqh>

// Include Nexus Confluence v2.00 NEW modules
#include <NexusConfluenceEA\Modules\BreakEvenManager.mqh>
#include <NexusConfluenceEA\Modules\TrailingStopManager.mqh>
#include <NexusConfluenceEA\Modules\AsymmetricRisk.mqh>
#include <NexusConfluenceEA\Modules\DrawdownProtection.mqh>

//+------------------------------------------------------------------+
//| GLOBAL OBJECTS - Original + v2.00 New Modules                    |
//+------------------------------------------------------------------+
// Original modules
CCore           *g_core;
CMarketAccess   *g_market;
CIndicatorHub   *g_indicators;
CSignalEngine   *g_signals;
CRiskExecution  *g_executor;

// v2.00 New modules
CBreakEvenManager    *g_break_even = NULL;
CTrailingStopManager *g_trailing_stop = NULL;
CAsymmetricRisk      *g_asymmetric = NULL;
CDrawdownProtection  *g_dd_protection = NULL;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("==========================================");
    Print("    NEXUS CONFLUENCE EA v2.03 STARTING    ");
    Print("  • Fixes: Gate3 stricter, Exec retry, MA  ");
    Print("==========================================");
    
    // ══════════════════════════════════════════════════════════════
    // STEP 1: Validate ALL inputs (including new v2.00 inputs)
    // ══════════════════════════════════════════════════════════════
    if(!ValidateInputs())
    {
        Print("❌ CRITICAL ERROR: Input validation failed!");
        return(INIT_PARAMETERS_INCORRECT);
    }
    
    // ══════════════════════════════════════════════════════════════
    // STEP 2: Create ORIGINAL module objects
    // ══════════════════════════════════════════════════════════════
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
    
    // ══════════════════════════════════════════════════════════════
    // STEP 3: Initialize ORIGINAL modules
    // ══════════════════════════════════════════════════════════════
    if(!g_core.Init(InpMagicNumber, InpLogLevel))
    {
        Print("❌ CRITICAL ERROR: Core initialization failed");
        CleanupModules();
        return(INIT_FAILED);
    }
    
    if(!g_market.Init(_Symbol, InpSpreadPeriod, InpSpreadMulti, InpMaxSpread,
                      InpUseTimeFilter, InpStartTime, InpEndTime,
                      InpTradeOnSunday, InpTradeOnMonday, InpTradeOnTuesday,
                      InpTradeOnWednesday, InpTradeOnThursday, InpTradeOnFriday,
                      InpTradeOnSaturday))
    {
        Print("❌ CRITICAL ERROR: MarketAccess initialization failed");
        CleanupModules();
        return(INIT_FAILED);
    }
    
    if(!g_indicators.Init(_Symbol, InpOperationalTF,
                          // GG TrendBar
                          InpGG_UpColor, InpGG_DownColor, InpGG_FlatColor, InpGG_TextColor,
                          InpGG_Corner, InpGG_CreateObjects,
                          InpGG_ADX_Period, InpGG_ADX_Price, InpGG_PSAR_Step, InpGG_PSAR_Max,
                          // Supertrend (TrendMagic)
                          InpST_CCI_Period, InpST_ATR_Period, InpST_ATR_Multiplier,
                          // WAE
                          InpWAE_FastMA, InpWAE_SlowMA, InpWAE_BBLength, InpWAE_BBMultiplier, InpWAE_Sensitivity,
                          // RSI OMA
                          InpRSI_Period, InpRSI_MA_Period, InpRSI_MA_Method, InpRSI_HighLevel, InpRSI_LowLevel, InpRSI_ShowLevels,
                          // Currency Strength
                          InpCS_CalcPeriod, InpCS_Smoothing, InpCS_ShowPercent))
    {
        Print("❌ CRITICAL ERROR: IndicatorHub initialization failed");
        CleanupModules();
        return(INIT_FAILED);
    }
    
    if(!g_signals.Init(g_core, g_market, g_indicators, 
                       InpMacro1TF, InpMacro2TF, InpMacro3TF, InpOperationalTF,
                       InpMinScore))
    {
        Print("❌ CRITICAL ERROR: SignalEngine initialization failed");
        CleanupModules();
        return(INIT_FAILED);
    }
    
    // Note: RiskExecution will use basic SL/TP for compatibility
    // Asymmetric values will be applied in OnTick()
    if(!g_executor.Init(g_core, g_market, InpMagicNumber, InpLotSize, 
                        InpStopLossBuy, InpTakeProfitBuy, InpMaxSlippage))
    {
        Print("❌ CRITICAL ERROR: RiskExecution initialization failed");
        CleanupModules();
        return(INIT_FAILED);
    }
    
    // ══════════════════════════════════════════════════════════════
    // STEP 4: Initialize NEW v2.00 modules
    // ══════════════════════════════════════════════════════════════
    if(!InitializeNewModules())
    {
        Print("❌ CRITICAL ERROR: Failed to initialize v2.00 modules");
        CleanupModules();
        return(INIT_FAILED);
    }
    
    // ══════════════════════════════════════════════════════════════
    // STEP 5: Print configuration summary
    // ══════════════════════════════════════════════════════════════
    PrintConfiguration();
    
    Print("==========================================");
    Print("  ✅ NEXUS CONFLUENCE EA v2.03 READY     ");
    Print("  📊 Gate3 stricter; Exec via RiskExec    ");
    Print("==========================================");
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("==========================================");
    Print("      NEXUS CONFLUENCE EA v2.03 STOPPING ");
    Print("      Reason: ", GetDeinitReasonText(reason));
    Print("==========================================");
    
    // Print statistics from v2.00 modules
    if(g_break_even != NULL)
        g_break_even.PrintStats();
    
    if(g_trailing_stop != NULL)
        g_trailing_stop.PrintStats();
    
    if(g_asymmetric != NULL)
        g_asymmetric.PrintStats();
    
    if(g_dd_protection != NULL)
        g_dd_protection.PrintStats();
    
    CleanupModules();
    
    Print("==========================================");
    Print("      EA STOPPED SUCCESSFULLY            ");
    Print("==========================================");
}

//+------------------------------------------------------------------+
//| Expert tick function - v2.00 with BE/TS/Asymmetric/DD            |
//+------------------------------------------------------------------+
void OnTick()
{
    // ══════════════════════════════════════════════════════════════
    // PART A: MANAGE OPEN POSITIONS (Break Even + Trailing Stop)
    // ══════════════════════════════════════════════════════════════
    
    // Check if already has open position
    if(g_executor.HasOpenPosition())
    {
        // Get current position for this EA on this symbol (robust selection)
        ulong ticket = 0;
        ENUM_POSITION_TYPE pos_type = POSITION_TYPE_BUY;
        
        if(PositionSelect(_Symbol))
        {
            // Ensure the position belongs to this EA (magic filter)
            if((int)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            {
                ticket = (ulong)PositionGetInteger(POSITION_TICKET);
                pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            }
        }
        
        if(ticket > 0)
        {
            // ─────────────────────────────────────────────────────
            // Apply Break Even and Trailing Stop with ordering
            // TS only after BE is active to avoid conflicts
            // ─────────────────────────────────────────────────────
            bool be_enabled = ((pos_type == POSITION_TYPE_BUY && InpBE_Buy_Enable) ||
                               (pos_type == POSITION_TYPE_SELL && InpBE_Sell_Enable));
            bool ts_enabled = ((pos_type == POSITION_TYPE_BUY && InpTS_Buy_Enable) ||
                               (pos_type == POSITION_TYPE_SELL && InpTS_Sell_Enable));

            bool be_active = false;
            if(g_break_even != NULL && be_enabled)
            {
                // First ensure BE is applied/active
                be_active = g_break_even.IsBEActivated(ticket);
                if(!be_active)
                {
                    g_break_even.CheckAndApply(ticket);
                    be_active = g_break_even.IsBEActivated(ticket);
                }
            }

            if(g_trailing_stop != NULL && ts_enabled)
            {
                // Only start/continue TS if BE is already active
                if(be_active)
                {
                    g_trailing_stop.Update(ticket);
                }
            }
        }
        
        // Update state if needed
        if(g_core.GetCurrentState() != STATE_WAITING_CLOSE)
        {
            g_core.UpdateStateMachine(STATE_WAITING_CLOSE);
        }
        
        return;  // Don't process new signals while position is open
    }
    
    // ══════════════════════════════════════════════════════════════
    // PART B: PROCESS NEW SIGNALS (Only if no position open)
    // ══════════════════════════════════════════════════════════════
    
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
    
    // ──────────────────────────────────────────────────────────────
    // v2.00: Check Drawdown Protection (Circuit Breaker)
    // ──────────────────────────────────────────────────────────────
    if(g_dd_protection != NULL && InpDD_Enable)
    {
        if(!g_dd_protection.CanTrade())
        {
            g_core.LogMessage(1, "🔴 Circuit Breaker ACTIVE - Trading paused");
            return;
        }
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

    // ──────────────────────────────────────────────────────────────
    // NOVO: Controle por PERFIL (PREMIUM/GOOD) por direção
    // Apenas permite abrir ordem se o perfil correspondente estiver ATIVO
    // ──────────────────────────────────────────────────────────────
    bool profile_allowed = false;
    if(signal_direction == SIGNAL_DIR_BUY)
    {
        if(signal_class == SIGNAL_PREMIUM)
            profile_allowed = InpBuyPremiumEnable;
        else if(signal_class == SIGNAL_GOOD)
            profile_allowed = InpBuyGoodEnable;
    }
    else if(signal_direction == SIGNAL_DIR_SELL)
    {
        if(signal_class == SIGNAL_PREMIUM)
            profile_allowed = InpSellPremiumEnable;
        else if(signal_class == SIGNAL_GOOD)
            profile_allowed = InpSellGoodEnable;
    }
    else
    {
        profile_allowed = false;
    }

    if(!profile_allowed)
    {
        g_core.LogMessage(1, StringFormat("⏭️ Perfil DESATIVADO: %s %s não permitido pelos inputs de perfil",
                         EnumToString(signal_class),
                         EnumToString(signal_direction)));
        return;
    }
    
    // ──────────────────────────────────────────────────────────────
    // v2.00: Determine position type
    // ──────────────────────────────────────────────────────────────
    ENUM_POSITION_TYPE trade_type;
    if(signal_direction == SIGNAL_DIR_BUY)
        trade_type = POSITION_TYPE_BUY;
    else
        trade_type = POSITION_TYPE_SELL;
    
    // ──────────────────────────────────────────────────────────────
    // v2.00: Asymmetric Risk - Check if direction is allowed
    // ──────────────────────────────────────────────────────────────
    if(g_asymmetric != NULL)
    {
        if(!g_asymmetric.IsDirectionAllowed(trade_type))
        {
            g_core.LogMessage(2, StringFormat("⏭️ Direction %s is DISABLED by Asymmetric Risk",
                             EnumToString(trade_type)));
            return;
        }
        
        // Validate score
        if(!g_asymmetric.IsScoreValid(trade_type, MathAbs(mtf_score), (signal_class == SIGNAL_PREMIUM)))
        {
            int base_min = g_asymmetric.GetMinScore(trade_type);
            int required = base_min + ((signal_class == SIGNAL_PREMIUM) ? 1 : 0);
            g_core.LogMessage(2, StringFormat("⏭️ Score insufficient: %d (required: %d for %s, class=%s)",
                             MathAbs(mtf_score), required, EnumToString(trade_type), EnumToString(signal_class)));
            return;
        }
    }
    
    // Update state machine
    g_core.UpdateStateMachine(STATE_SIGNAL_DETECTED);
    
    // ══════════════════════════════════════════════════════════════
    // PART C: PREPARE TRADE PARAMETERS
    // ══════════════════════════════════════════════════════════════
    
    // ──────────────────────────────────────────────────────────────
    // v2.00: Get ASYMMETRIC SL/TP values
    // ──────────────────────────────────────────────────────────────
    int sl_points, tp_points;
    
    if(g_asymmetric != NULL)
    {
        sl_points = g_asymmetric.GetSL(trade_type);
        tp_points = g_asymmetric.GetTP(trade_type);
    }
    else
    {
        // Fallback to basic values
        sl_points = (trade_type == POSITION_TYPE_BUY) ? InpStopLossBuy : InpStopLossSell;
        tp_points = (trade_type == POSITION_TYPE_BUY) ? InpTakeProfitBuy : InpTakeProfitSell;
    }
    
    // ──────────────────────────────────────────────────────────────
    // v2.00: Get ADJUSTED LOT SIZE (Drawdown Protection)
    // ──────────────────────────────────────────────────────────────
    double lot_size = InpLotSize;
    
    if(g_dd_protection != NULL && InpDD_Enable)
    {
        lot_size = g_dd_protection.GetAdjustedLot(InpLotSize);
    }
    
    // ──────────────────────────────────────────────────────────────
    // Calculate actual SL/TP prices
    // ──────────────────────────────────────────────────────────────
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    
    double current_price, sl_price, tp_price;
    
    if(trade_type == POSITION_TYPE_BUY)
    {
        current_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        sl_price = NormalizeDouble(current_price - (sl_points * point), digits);
        tp_price = NormalizeDouble(current_price + (tp_points * point), digits);
    }
    else // SELL
    {
        current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        sl_price = NormalizeDouble(current_price + (sl_points * point), digits);
        tp_price = NormalizeDouble(current_price - (tp_points * point), digits);
    }
    
    // Prepare trade comment
    string comment = StringFormat("%s_%s_S%+d_SL%d_TP%d", 
                     EnumToString(signal_class),
                     EnumToString(signal_direction),
                     mtf_score,
                     sl_points,
                     tp_points);
    
    // ══════════════════════════════════════════════════════════════
    // PART D: EXECUTE TRADE (Using CTrade directly for v2.00)
    // ══════════════════════════════════════════════════════════════
    
    // Entrada: removido realtime momentum guard (shift=0) para manter
    // consistência com a regra de shift=1 em toda a geração do sinal.

    // Execução robusta via RiskExecution (retry + normalização de lote)
    // Normalizar lote antes de enviar
    lot_size = g_market.NormalizeLot(lot_size);
    g_executor.SetLotSize(lot_size);
    g_executor.SetStopLoss(sl_points);
    g_executor.SetTakeProfit(tp_points);

    bool trade_result = false;
    if(trade_type == POSITION_TYPE_BUY)
        trade_result = g_executor.ExecuteBuy(comment);
    else
        trade_result = g_executor.ExecuteSell(comment);
    
    // ══════════════════════════════════════════════════════════════
    // PART E: LOG RESULT
    // ══════════════════════════════════════════════════════════════
    
    if(trade_result)
    {
    ulong ticket = g_executor.GetLastTicket();
        
        g_core.LogMessage(1, "════════════════════════════════════");
        g_core.LogMessage(1, "✅ TRADE EXECUTED SUCCESSFULLY");
        g_core.LogMessage(1, "════════════════════════════════════");
        g_core.LogMessage(1, StringFormat("📋 Ticket: %I64u", ticket));
        g_core.LogMessage(1, StringFormat("%s Direction: %s",
                         (trade_type == POSITION_TYPE_BUY ? "📈" : "📉"),
                         EnumToString(trade_type)));
        g_core.LogMessage(1, StringFormat("💰 Lot: %.2f", lot_size));
        g_core.LogMessage(1, StringFormat("📊 Score: %+d", mtf_score));
    g_core.LogMessage(1, StringFormat("🎯 SL: %d points | TP: %d points", sl_points, tp_points));
        g_core.LogMessage(1, StringFormat("📐 R:R: 1:%.2f", (double)tp_points / sl_points));
        g_core.LogMessage(1, "════════════════════════════════════");
        
        // Update state
        g_core.UpdateStateMachine(STATE_WAITING_CLOSE);
    }
    else
    {
        // Trade execution failed - reset state
        g_core.UpdateStateMachine(STATE_IDLE);
        
        g_core.LogMessage(1, "════════════════════════════════════");
        g_core.LogMessage(1, "❌ TRADE EXECUTION FAILED");
        g_core.LogMessage(1, "════════════════════════════════════");
    // O módulo RiskExecution já loga o retcode ao falhar
        g_core.LogMessage(1, "════════════════════════════════════");
    }
}

//+------------------------------------------------------------------+
//| Trade transaction function - v2.00 (for DD Protection)           |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
    // Detect position closures and update Drawdown Protection
    if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
    {
        ulong deal_ticket = trans.deal;
        
        if(!HistoryDealSelect(deal_ticket))
            return;
        
        // Check if it's an exit deal (closure)
        if(HistoryDealGetInteger(deal_ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT)
            return;
        
        // Check if it's from this EA
        if(HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) != InpMagicNumber)
            return;
        
        // Get trade result
        double profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
        double swap = HistoryDealGetDouble(deal_ticket, DEAL_SWAP);
        double commission = HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);
        
        double total_pl = profit + swap + commission;
        bool is_win = (total_pl > 0);
        
        // Notify Drawdown Protection
        if(g_dd_protection != NULL && InpDD_Enable)
        {
            g_dd_protection.OnTradeResult(is_win, total_pl);
        }
        
        // Log result
        g_core.LogMessage(1, StringFormat("%s Trade Closed | P/L: $%.2f | %s",
                         (is_win ? "✅" : "❌"),
                         total_pl,
                         (is_win ? "WIN" : "LOSS")));
    }
}

//+------------------------------------------------------------------+
//| Initialize v2.00 new modules                                     |
//+------------------------------------------------------------------+
bool InitializeNewModules()
{
    Print("🔧 Initializing v2.00 modules...");
    
    // ──────────────────────────────────────────────────────────────
    // 1. Break Even Manager
    // ──────────────────────────────────────────────────────────────
    g_break_even = new CBreakEvenManager();
    
    if(!g_break_even.Init(InpBE_Buy_Enable, InpBE_Buy_Trigger, InpBE_Buy_Step,
                          InpBE_Sell_Enable, InpBE_Sell_Trigger, InpBE_Sell_Step))
    {
        Print("❌ Failed to initialize Break Even Manager");
        return false;
    }
    
    // ──────────────────────────────────────────────────────────────
    // 2. Trailing Stop Manager
    // ──────────────────────────────────────────────────────────────
    g_trailing_stop = new CTrailingStopManager();
    
    if(!g_trailing_stop.Init(InpTS_Buy_Enable, InpTS_Buy_Trigger, InpTS_Buy_Step,
                             InpTS_Sell_Enable, InpTS_Sell_Trigger, InpTS_Sell_Step))
    {
        Print("❌ Failed to initialize Trailing Stop Manager");
        return false;
    }
    
    // ──────────────────────────────────────────────────────────────
    // 3. Asymmetric Risk Manager
    // ──────────────────────────────────────────────────────────────
    g_asymmetric = new CAsymmetricRisk();
    
    if(!g_asymmetric.Init(InpEnableBuy, InpEnableSell,
                          InpStopLossBuy, InpTakeProfitBuy, InpMinScoreBuy,
                          InpStopLossSell, InpTakeProfitSell, InpMinScoreSell))
    {
        Print("❌ Failed to initialize Asymmetric Risk Manager");
        return false;
    }
    
    // ──────────────────────────────────────────────────────────────
    // 4. Drawdown Protection
    // ──────────────────────────────────────────────────────────────
    g_dd_protection = new CDrawdownProtection();
    
    if(!g_dd_protection.Init(InpDD_Enable, InpDD_DailyMax, InpDD_ConsecLoss, InpDD_LotReduce))
    {
        Print("❌ Failed to initialize Drawdown Protection");
        return false;
    }
    
    Print("✅ All v2.00 modules initialized successfully!");

    // Avisos de consistência BE/TS: TS só roda após BE ativo
    if((InpBE_Buy_Enable && InpTS_Buy_Enable) && (InpTS_Buy_Trigger < InpBE_Buy_Trigger))
        Print("⚠️ AVISO: TS_Buy_Trigger (", InpTS_Buy_Trigger, ") < BE_Buy_Trigger (", InpBE_Buy_Trigger, ") — TS só inicia após BE estar ativo; verifique se pretende este comportamento.");
    if((InpBE_Sell_Enable && InpTS_Sell_Enable) && (InpTS_Sell_Trigger < InpBE_Sell_Trigger))
        Print("⚠️ AVISO: TS_Sell_Trigger (", InpTS_Sell_Trigger, ") < BE_Sell_Trigger (", InpBE_Sell_Trigger, ") — TS só inicia após BE estar ativo; verifique se pretende este comportamento.");
    return true;
}

//+------------------------------------------------------------------+
//| Cleanup module objects - v2.00                                   |
//+------------------------------------------------------------------+
void CleanupModules()
{
    // Cleanup v2.00 modules
    if(g_dd_protection != NULL)
    {
        delete g_dd_protection;
        g_dd_protection = NULL;
    }
    
    if(g_asymmetric != NULL)
    {
        delete g_asymmetric;
        g_asymmetric = NULL;
    }
    
    if(g_trailing_stop != NULL)
    {
        delete g_trailing_stop;
        g_trailing_stop = NULL;
    }
    
    if(g_break_even != NULL)
    {
        delete g_break_even;
        g_break_even = NULL;
    }
    
    // Cleanup original modules
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
//| Print configuration summary - v2.00                              |
//+------------------------------------------------------------------+
void PrintConfiguration()
{
    Print("\n=== EA CONFIGURATION v2.03 ===");
    Print("═══════════════════════════════════════");
    Print("Symbol: ", _Symbol);
    Print("Magic Number: ", InpMagicNumber);
    Print("Log Level: ", InpLogLevel, " (1=Executive, 2=Operational, 3=Debug)");
    Print("• v2.03: Gate3 stricter; RiskExec; spread warm-up; no RT guard");
    
    Print("\n=== ASYMMETRIC RISK MANAGEMENT ===");
    Print("📈 BUY: ", (InpEnableBuy ? "ENABLED" : "DISABLED"));
    if(InpEnableBuy)
    {
        Print("   ├─ Lot Size: ", InpLotSize);
        Print("   ├─ Stop Loss: ", InpStopLossBuy, " points");
        Print("   ├─ Take Profit: ", InpTakeProfitBuy, " points");
        Print("   ├─ Min Score: ", InpMinScoreBuy);
        Print("   └─ R:R Ratio: 1:", DoubleToString((double)InpTakeProfitBuy / InpStopLossBuy, 2));
    }
    
    Print("📉 SELL: ", (InpEnableSell ? "ENABLED" : "DISABLED"));
    if(InpEnableSell)
    {
        Print("   ├─ Lot Size: ", InpLotSize);
        Print("   ├─ Stop Loss: ", InpStopLossSell, " points");
        Print("   ├─ Take Profit: ", InpTakeProfitSell, " points");
        Print("   ├─ Min Score: ", InpMinScoreSell);
        Print("   └─ R:R Ratio: 1:", DoubleToString((double)InpTakeProfitSell / InpStopLossSell, 2));
    }
    
    Print("\n=== BREAK EVEN ===");
    Print("📈 BUY BE: ", (InpBE_Buy_Enable ? "ENABLED" : "DISABLED"));
    if(InpBE_Buy_Enable)
    {
        Print("   ├─ Trigger: ", InpBE_Buy_Trigger, " ", GetUnitName());
        Print("   └─ Step: ", InpBE_Buy_Step, " ", GetUnitName());
    }
    Print("📉 SELL BE: ", (InpBE_Sell_Enable ? "ENABLED" : "DISABLED"));
    if(InpBE_Sell_Enable)
    {
        Print("   ├─ Trigger: ", InpBE_Sell_Trigger, " ", GetUnitName());
        Print("   └─ Step: ", InpBE_Sell_Step, " ", GetUnitName());
    }
    
    Print("\n=== TRAILING STOP ===");
    Print("📈 BUY TS: ", (InpTS_Buy_Enable ? "ENABLED" : "DISABLED"));
    if(InpTS_Buy_Enable)
    {
        Print("   ├─ Trigger: ", InpTS_Buy_Trigger, " ", GetUnitName());
        Print("   └─ Step: ", InpTS_Buy_Step, " ", GetUnitName());
    }
    Print("📉 SELL TS: ", (InpTS_Sell_Enable ? "ENABLED" : "DISABLED"));
    if(InpTS_Sell_Enable)
    {
        Print("   ├─ Trigger: ", InpTS_Sell_Trigger, " ", GetUnitName());
        Print("   └─ Step: ", InpTS_Sell_Step, " ", GetUnitName());
    }
    
    Print("\n=== DRAWDOWN PROTECTION ===");
    Print("Status: ", (InpDD_Enable ? "ENABLED" : "DISABLED"));
    if(InpDD_Enable)
    {
        Print("├─ Daily Max DD: ", InpDD_DailyMax, "%");
        Print("├─ Max Consecutive Loss: ", InpDD_ConsecLoss);
        Print("└─ Lot Reduction: ", DoubleToString(InpDD_LotReduce * 100, 0), "%");
    }
    
    Print("\n=== MARKET ACCESS ===");
    Print("Max Spread: ", InpMaxSpread, " points");
    Print("Spread Multiplier: ", InpSpreadMulti);
    Print("Max Slippage: ", InpMaxSlippage, " points");
    Print("Time Filter: ", InpUseTimeFilter ? "Enabled" : "Disabled");
    if(InpUseTimeFilter)
    {
        Print("Trading Hours: ", InpStartTime, " - ", InpEndTime);
    }
    
    Print("\n=== WEEKLY FILTER ===");
    Print("Sun: ", InpTradeOnSunday ? "✓" : "✗", " | ",
          "Mon: ", InpTradeOnMonday ? "✓" : "✗", " | ",
          "Tue: ", InpTradeOnTuesday ? "✓" : "✗", " | ",
          "Wed: ", InpTradeOnWednesday ? "✓" : "✗");
    Print("Thu: ", InpTradeOnThursday ? "✓" : "✗", " | ",
          "Fri: ", InpTradeOnFriday ? "✓" : "✗", " | ",
          "Sat: ", InpTradeOnSaturday ? "✓" : "✗");
    
    Print("\n=== MTF CONFIGURATION ===");
    Print("Macro 1: ", EnumToString(InpMacro1TF));
    Print("Macro 2: ", EnumToString(InpMacro2TF));
    Print("Macro 3: ", EnumToString(InpMacro3TF));
    Print("Operational: ", EnumToString(InpOperationalTF));
    Print("Min Score: ", InpMinScore);
    
    Print("\n=== INDICATORS (INPUTS) ===");
    Print("GG TrendBar: ADX=", InpGG_ADX_Period, 
        " | Price=", InpGG_ADX_Price,
        " | PSAR Step=", DoubleToString(InpGG_PSAR_Step, 2),
        " | PSAR Max=", DoubleToString(InpGG_PSAR_Max, 2),
        " | Objects=", (InpGG_CreateObjects ? "ON" : "OFF"));
    Print("TrendMagic: CCI=", InpST_CCI_Period,
        " | ATR=", InpST_ATR_Period,
        " | Mult=", DoubleToString(InpST_ATR_Multiplier, 2));
    Print("WAE: Fast=", InpWAE_FastMA,
        " | Slow=", InpWAE_SlowMA,
        " | BB Len=", InpWAE_BBLength,
        " | BB Mult=", DoubleToString(InpWAE_BBMultiplier, 2),
        " | Sens=", InpWAE_Sensitivity);
    Print("RSI OMA: RSI=", InpRSI_Period,
        " | MA=", InpRSI_MA_Period,
        " | Method=", InpRSI_MA_Method,
        " | High=", DoubleToString(InpRSI_HighLevel, 1),
        " | Low=", DoubleToString(InpRSI_LowLevel, 1),
        " | Levels=", (InpRSI_ShowLevels ? "ON" : "OFF"));
    Print("Currency Strength: Period=", InpCS_CalcPeriod,
        " | Smooth=", InpCS_Smoothing,
        " | Percent=", (InpCS_ShowPercent ? "ON" : "OFF"));
    
    Print("\n=== PERFIS POR CLASSE ===");
    Print("BUY → PREMIUM: ", (InpBuyPremiumEnable ? "ATIVO" : "INATIVO"),
        " | GOOD: ", (InpBuyGoodEnable ? "ATIVO" : "INATIVO"));
    Print("SELL → PREMIUM: ", (InpSellPremiumEnable ? "ATIVO" : "INATIVO"),
        " | GOOD: ", (InpSellGoodEnable ? "ATIVO" : "INATIVO"));
    
    Print("═══════════════════════════════════════");
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
