//+------------------------------------------------------------------+
//|                      NexusConfluenceV3.mq5                        |
//|                  Nexus Confluence V3 - MQL5 Wrapper                |
//|                     Copyright 2024-2026, Nexus EA                 |
//+------------------------------------------------------------------+
#property copyright "Nexus Confluence V3"
#property version   "3.00"
#property description "Nexus Confluence V3 - 6-Gate Multi-TF Trading System"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

#include "..\..\Include\NexusConfluenceV3\NexusV3Inputs.mqh"
#include "..\..\Include\NexusConfluenceV3\NexusV3Bridge.mqh"

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CTrade         g_trade;
CPositionInfo  g_position;

int            g_bars_count   = 200;    // Number of bars to send to DLL
bool           g_dll_ok       = false;
string         g_symbol;
ENUM_TIMEFRAMES g_op_tf;

// New-candle gate (avoids copying 4x200 bars on every tick)
datetime        g_lastBarTime  = 0;

// Visual-only indicator handles (for chart display)
int g_hTrendMagic  = INVALID_HANDLE;
int g_hOBV_MACD    = INVALID_HANDLE;
int g_hRSI_OMA     = INVALID_HANDLE;
int g_hGG_TrendBar = INVALID_HANDLE;
int g_hCurrStr     = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit()
{
    g_symbol = _Symbol;
    g_op_tf  = InpOperationalTF;

    // Build NX_Config from inputs
    NX_Config_MQL config;
    ZeroMemory(config);
    FillConfig(config);

    // Build NX_SymbolInfo
    NX_SymbolInfo_MQL sym_info;
    FillSymbolInfo(g_symbol, sym_info);

    // Initialize DLL engine
    int init_result = NX_Init(config, sym_info);
    if(init_result != 0)
    {
        char err_buf[512];
        NX_GetLastError(err_buf, 512);
        string err_msg = CharArrayToString(err_buf);
        PrintFormat("FATAL: NX_Init failed (%d): %s", init_result, err_msg);
        return INIT_FAILED;
    }

    // Setup trade object
    g_trade.SetExpertMagicNumber(InpMagicNumber);
    g_trade.SetDeviationInPoints(InpMaxSlippage);
    g_trade.SetTypeFilling(ORDER_FILLING_FOK);

    // Timer for position management (every 1 second)
    EventSetTimer(1);

    // Create visual indicator handles (display only, not used for trading)
    CreateIndicatorHandles();

    int version = NX_GetVersion();
    PrintFormat("Nexus Confluence V3 initialized. DLL v%d.%d.%d | Symbol: %s | TF: %s",
        version / 10000, (version % 10000) / 100, version % 100,
        g_symbol, EnumToString(g_op_tf));

    g_dll_ok = true;
    g_lastBarTime = 0;  // force first tick to process
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    EventKillTimer();

    if(g_dll_ok)
    {
        NX_Deinit();
        g_dll_ok = false;
    }

    // Release visual indicator handles
    if(g_hTrendMagic  != INVALID_HANDLE) IndicatorRelease(g_hTrendMagic);
    if(g_hOBV_MACD    != INVALID_HANDLE) IndicatorRelease(g_hOBV_MACD);
    if(g_hRSI_OMA     != INVALID_HANDLE) IndicatorRelease(g_hRSI_OMA);
    if(g_hGG_TrendBar != INVALID_HANDLE) IndicatorRelease(g_hGG_TrendBar);
    if(g_hCurrStr     != INVALID_HANDLE) IndicatorRelease(g_hCurrStr);

    PrintFormat("Nexus V3 deinitialized. Reason: %d", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
    if(!g_dll_ok) return;

    // ── NEW-CANDLE GATE ──────────────────────────────────────────────
    // Only copy bars and call DLL when a new candle forms on the
    // operational timeframe. On every-tick mode MT5 fires OnTick()
    // ~5,500 times per candle — 99.98% are intra-bar ticks that the
    // DLL discards immediately anyway. By gating here we avoid
    // 4×CopyRates(200 bars) = 38 KB of needless copies per tick.
    // ─────────────────────────────────────────────────────────────────
    datetime currentBarTime = iTime(g_symbol, g_op_tf, 0);
    if(currentBarTime == g_lastBarTime)
        return;                     // same candle — nothing to do
    g_lastBarTime = currentBarTime; // new candle detected

    // Copy bars for all 4 timeframes (shift=1 enforced inside CopyBarsForDLL)
    NX_BarData_MQL bars_op[];
    NX_BarData_MQL bars_m1[];
    NX_BarData_MQL bars_m2[];
    NX_BarData_MQL bars_m3[];

    if(!CopyBarsForDLL(g_symbol, g_op_tf,       g_bars_count, bars_op))  return;
    if(!CopyBarsForDLL(g_symbol, InpMacro1TF,   g_bars_count, bars_m1))  return;
    if(!CopyBarsForDLL(g_symbol, InpMacro2TF,   g_bars_count, bars_m2))  return;
    if(!CopyBarsForDLL(g_symbol, InpMacro3TF,   g_bars_count, bars_m3))  return;

    // Update symbol info
    NX_SymbolInfo_MQL sym_info;
    FillSymbolInfo(g_symbol, sym_info);

    // Build position context for multi-position awareness
    NX_PositionContext_MQL pos_ctx;
    ZeroMemory(pos_ctx);
    pos_ctx.open_count = CountOpenPositions(pos_ctx.open_direction);

    // Call DLL tick processing
    NX_TickResult_MQL result;
    ZeroMemory(result);

    int tick_err = NX_OnTick(
        bars_op, ArraySize(bars_op),
        bars_m1, ArraySize(bars_m1),
        bars_m2, ArraySize(bars_m2),
        bars_m3, ArraySize(bars_m3),
        sym_info, pos_ctx, result
    );

    if(tick_err != 0)
    {
        PrintFormat("NX_OnTick error: %d", tick_err);
        return;
    }

    // Print log if available
    string log_msg = CharArrayToString(result.log_message);
    if(StringLen(log_msg) > 0 && InpLogLevel >= 2)
        Print(log_msg);

    // Execute trade if signal detected
    if(result.action == 1 || result.action == 2)
    {
        ExecuteOrder(result);
    }
}

//+------------------------------------------------------------------+
//| Timer function — position management (BE/TS/DD)                   |
//+------------------------------------------------------------------+
void OnTimer()
{
    if(!g_dll_ok) return;

    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(!g_position.SelectByIndex(i)) continue;
        if(g_position.Magic() != InpMagicNumber) continue;
        if(g_position.Symbol() != g_symbol) continue;

        // Build position info
        NX_PositionInfo_MQL pos;
        ZeroMemory(pos);
        pos.ticket        = g_position.Ticket();
        pos.type          = (g_position.PositionType() == POSITION_TYPE_BUY) ? 0 : 1;
        pos.entry_price   = g_position.PriceOpen();
        pos.current_sl    = g_position.StopLoss();
        pos.current_tp    = g_position.TakeProfit();
        pos.profit        = g_position.Profit();
        pos.open_time     = (long)g_position.Time();

        // Current price (bid for buy, ask for sell)
        if(pos.type == 0)
            pos.current_price = SymbolInfoDouble(g_symbol, SYMBOL_BID);
        else
            pos.current_price = SymbolInfoDouble(g_symbol, SYMBOL_ASK);

        // Calculate profit in steps
        double price_step = SymbolInfoDouble(g_symbol, SYMBOL_TRADE_TICK_SIZE);
        if(price_step <= 0) price_step = SymbolInfoDouble(g_symbol, SYMBOL_POINT);
        if(price_step > 0)
        {
            if(pos.type == 0) // BUY
                pos.profit_steps = (int)MathRound((pos.current_price - pos.entry_price) / price_step);
            else // SELL
                pos.profit_steps = (int)MathRound((pos.entry_price - pos.current_price) / price_step);
        }

        // Call DLL for management
        NX_ManageResult_MQL manage_result;
        ZeroMemory(manage_result);

        int manage_err = NX_ManagePosition(pos, manage_result);
        if(manage_err != 0) continue;

        // Process management action
        switch(manage_result.action)
        {
            case 1: // MODIFY_SL
            {
                if(MathAbs(manage_result.new_sl - g_position.StopLoss()) > price_step)
                {
                    string reason = CharArrayToString(manage_result.reason);
                    if(g_trade.PositionModify(g_position.Ticket(), manage_result.new_sl, g_position.TakeProfit()))
                        PrintFormat("[MANAGE] %s | Ticket=%lld", reason, g_position.Ticket());
                    else
                        PrintFormat("[MANAGE] FAIL: %s | Error=%d", reason, GetLastError());
                }
                break;
            }
            case 2: // CLOSE
            {
                string reason = CharArrayToString(manage_result.reason);
                if(g_trade.PositionClose(g_position.Ticket()))
                    PrintFormat("[MANAGE] CLOSE | Ticket=%lld | %s", g_position.Ticket(), reason);
                break;
            }
            case 3: // CIRCUIT_BREAK
            {
                PrintFormat("[CB] Circuit breaker activated! Closing position %lld", g_position.Ticket());
                g_trade.PositionClose(g_position.Ticket());
                break;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Trade transaction handler — notify DLL of trade results           |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
    if(!g_dll_ok) return;

    if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
    {
        if(trans.deal_type == DEAL_TYPE_BUY || trans.deal_type == DEAL_TYPE_SELL)
        {
            // Check if this is a close deal (entry=OUT)
            long deal_entry = 0;
            if(HistoryDealSelect(trans.deal) &&
               HistoryDealGetInteger(trans.deal, DEAL_ENTRY, deal_entry) &&
               deal_entry == DEAL_ENTRY_OUT)
            {
                long deal_magic = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
                if(deal_magic == InpMagicNumber)
                {
                    double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
                    profit += HistoryDealGetDouble(trans.deal, DEAL_SWAP);
                    profit += HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);

                    // Count remaining positions AFTER this close
                    int remaining_dir = 0;
                    int remaining = CountOpenPositions(remaining_dir);

                    int is_win = (profit > 0) ? 1 : 0;
                    NX_OnTradeResult(is_win, profit, remaining);

                    // Only reset state when ALL positions are closed
                    if(remaining <= 0)
                        NX_ResetState();
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Execute trade order based on DLL signal                           |
//+------------------------------------------------------------------+
void ExecuteOrder(const NX_TickResult_MQL &signal)
{
    // Position count/direction checks are done in DLL via NX_PositionContext
    // DLL already verified: count < max_positions AND same-direction-only

    double price_step = SymbolInfoDouble(g_symbol, SYMBOL_TRADE_TICK_SIZE);
    if(price_step <= 0) price_step = SymbolInfoDouble(g_symbol, SYMBOL_POINT);

    string comment = CharArrayToString(signal.comment);
    double lot = signal.lot_size;

    if(signal.action == 1) // BUY
    {
        double ask = SymbolInfoDouble(g_symbol, SYMBOL_ASK);
        double sl  = NormalizeDouble(ask - signal.sl_steps * price_step, _Digits);
        double tp  = NormalizeDouble(ask + signal.tp_steps * price_step, _Digits);

        if(g_trade.Buy(lot, g_symbol, ask, sl, tp, comment))
            PrintFormat("[TRADE] BUY %s Lot=%.2f SL=%.5f TP=%.5f | %s", g_symbol, lot, sl, tp, comment);
        else
        {
            PrintFormat("[TRADE] BUY FAILED: %d | %s", GetLastError(), comment);
            NX_ResetState();
        }
    }
    else if(signal.action == 2) // SELL
    {
        double bid = SymbolInfoDouble(g_symbol, SYMBOL_BID);
        double sl  = NormalizeDouble(bid + signal.sl_steps * price_step, _Digits);
        double tp  = NormalizeDouble(bid - signal.tp_steps * price_step, _Digits);

        if(g_trade.Sell(lot, g_symbol, bid, sl, tp, comment))
            PrintFormat("[TRADE] SELL %s Lot=%.2f SL=%.5f TP=%.5f | %s", g_symbol, lot, sl, tp, comment);
        else
        {
            PrintFormat("[TRADE] SELL FAILED: %d | %s", GetLastError(), comment);
            NX_ResetState();
        }
    }
}

//+------------------------------------------------------------------+
//| Count open positions and detect their direction                   |
//+------------------------------------------------------------------+
int CountOpenPositions(int &out_direction)
{
    int count = 0;
    out_direction = 0; // NX_DIR_NONE

    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(g_position.SelectByIndex(i))
        {
            if(g_position.Magic() == InpMagicNumber && g_position.Symbol() == g_symbol)
            {
                count++;
                // All positions must be same direction (enforced at entry)
                if(g_position.PositionType() == POSITION_TYPE_BUY)
                    out_direction = 1; // NX_DIR_BUY
                else
                    out_direction = 2; // NX_DIR_SELL
            }
        }
    }
    return count;
}

//+------------------------------------------------------------------+
//| Create visual indicator handles (PERIOD_CURRENT = chart TF)       |
//+------------------------------------------------------------------+
void CreateIndicatorHandles()
{
    g_hGG_TrendBar = iCustom(g_symbol, PERIOD_CURRENT,
        "NexusConfluenceEA\\GG_TrendBar_Indicator",
        clrLime, clrRed, clrYellow, clrAqua,
        CORNER_LEFT_UPPER, true,
        InpGG_ADX_Period, PRICE_CLOSE,
        InpGG_PSAR_Step, InpGG_PSAR_Max, 3.0);

    g_hTrendMagic = iCustom(g_symbol, PERIOD_CURRENT,
        "NexusConfluenceEA\\TrendMagic_MT5",
        InpST_CCI_Period, InpST_Vol_Period, InpST_BandMult);

    g_hOBV_MACD = iCustom(g_symbol, PERIOD_CURRENT,
        "NexusConfluenceEA\\OBV_MACD",
        InpMACD_FastEMA, InpMACD_SlowEMA, InpMACD_SignalSMA,
        InpMACD_ObvWindow, InpMACD_UseTickVol,
        true, true,
        InpMACD_ThreshPrd, InpMACD_ThreshMlt);

    g_hRSI_OMA = iCustom(g_symbol, PERIOD_CURRENT,
        "NexusConfluenceEA\\RSIOMA_v2HHLSX_MT5",
        InpRSI_Period, InpRSI_MA_Period, InpRSI_MA_Method,
        70.0, 30.0, true);

    if(InpCS_Enable)
    {
        g_hCurrStr = iCustom(g_symbol, PERIOD_CURRENT,
            "NexusConfluenceEA\\CurrencyStrengthMeter_MT5",
            InpCS_CalcPeriod, InpCS_Smoothing, true);
    }

    PrintFormat("[INDICATORS] Handles: GG=%d TM=%d OBV=%d RSI=%d CS=%d",
        g_hGG_TrendBar, g_hTrendMagic, g_hOBV_MACD, g_hRSI_OMA, g_hCurrStr);
}

//+------------------------------------------------------------------+
//| Fill NX_Config_MQL from input parameters                          |
//+------------------------------------------------------------------+
void FillConfig(NX_Config_MQL &config)
{
    config.lot_size     = InpLotSize;
    config.max_slippage = InpMaxSlippage;

    config.sl_buy        = InpStopLossBuy;
    config.tp_buy        = InpTakeProfitBuy;
    config.min_score_buy = InpMinScoreBuy;
    config.enable_buy    = InpEnableBuy;

    config.sl_sell        = InpStopLossSell;
    config.tp_sell        = InpTakeProfitSell;
    config.min_score_sell = InpMinScoreSell;
    config.enable_sell    = InpEnableSell;

    config.be_buy_enable  = InpBE_Buy_Enable;
    config.be_buy_trigger = InpBE_Buy_Trigger;
    config.be_buy_step    = InpBE_Buy_Step;

    config.be_sell_enable  = InpBE_Sell_Enable;
    config.be_sell_trigger = InpBE_Sell_Trigger;
    config.be_sell_step    = InpBE_Sell_Step;

    config.ts_buy_enable  = InpTS_Buy_Enable;
    config.ts_buy_trigger = InpTS_Buy_Trigger;
    config.ts_buy_step    = InpTS_Buy_Step;

    config.ts_sell_enable  = InpTS_Sell_Enable;
    config.ts_sell_trigger = InpTS_Sell_Trigger;
    config.ts_sell_step    = InpTS_Sell_Step;

    config.dd_enable     = InpDD_Enable;
    config.dd_daily_max  = InpDD_DailyMax;
    config.dd_consec_loss= InpDD_ConsecLoss;
    config.dd_lot_reduce = InpDD_LotReduce;

    config.spread_filter_enable = InpEnableSpreadFilter;
    config.max_spread      = InpMaxSpread;
    config.spread_multiplier = InpSpreadMulti;
    config.spread_period   = InpSpreadPeriod;

    config.use_time_filter = InpUseTimeFilter;
    ParseTimeInput(InpStartTime, config.start_hour, config.start_minute);
    ParseTimeInput(InpEndTime,   config.end_hour,   config.end_minute);

    config.trade_days[0] = InpTradeOnSunday;
    config.trade_days[1] = InpTradeOnMonday;
    config.trade_days[2] = InpTradeOnTuesday;
    config.trade_days[3] = InpTradeOnWednesday;
    config.trade_days[4] = InpTradeOnThursday;
    config.trade_days[5] = InpTradeOnFriday;
    config.trade_days[6] = InpTradeOnSaturday;

    config.macro1_tf      = (int)InpMacro1TF;
    config.macro2_tf      = (int)InpMacro2TF;
    config.macro3_tf      = (int)InpMacro3TF;
    config.operational_tf = (int)InpOperationalTF;

    config.buy_premium_enable  = InpBuyPremiumEnable;
    config.buy_good_enable     = InpBuyGoodEnable;
    config.sell_premium_enable = InpSellPremiumEnable;
    config.sell_good_enable    = InpSellGoodEnable;

    config.gg_adx_period   = InpGG_ADX_Period;
    config.gg_psar_step    = InpGG_PSAR_Step;
    config.gg_psar_max     = InpGG_PSAR_Max;

    config.st_cci_period        = InpST_CCI_Period;
    config.st_er_period         = InpST_ER_Period;
    config.st_volatility_period = InpST_Vol_Period;
    config.st_band_multiplier   = InpST_BandMult;

    config.macd_fast        = InpMACD_FastEMA;
    config.macd_slow        = InpMACD_SlowEMA;
    config.macd_signal      = InpMACD_SignalSMA;
    config.macd_obv_window  = InpMACD_ObvWindow;
    config.macd_use_tick_vol= InpMACD_UseTickVol;
    config.macd_thresh_period = InpMACD_ThreshPrd;
    config.macd_thresh_mult = InpMACD_ThreshMlt;

    config.rsi_period    = InpRSI_Period;
    config.rsi_ma_period = InpRSI_MA_Period;
    config.rsi_ma_method = (int)InpRSI_MA_Method;

    config.cs_enable      = InpCS_Enable;
    config.cs_calc_period = InpCS_CalcPeriod;
    config.cs_smoothing   = InpCS_Smoothing;

    config.cooldown_enable  = InpCooldownEnable;
    config.cooldown_candles = InpCooldownCandles;

    config.g4_rsi_ob          = InpG4_RSI_OB;
    config.g4_rsi_os          = InpG4_RSI_OS;

    config.g5_er_min          = InpG5_ER_Min;
    config.g5_er_decline      = InpG5_ER_Decline;
    config.g5_momentum_ratio  = InpG5_MomentumRatio;
    config.g5_macro_flip_cd   = InpG5_MacroFlipCD;

    config.dyn_sl_max         = InpDynSL_Max;
    config.dyn_sl_min         = InpDynSL_Min;
    config.dyn_tp_min         = InpDynTP_Min;
    config.dyn_tp_max         = InpDynTP_Max;
    config.min_sl_tp_steps    = InpMinSLTP_Steps;

    config.gg_di_separation   = InpGG_DI_Sep;

    config.st_band_trend_factor = InpST_BandTrendF;

    config.rsi_hysteresis     = InpRSI_Hysteresis;

    config.max_positions = InpMaxPositions;
    config.lot_scale_factor = InpLotScaleFactor;

    config.magic_number = InpMagicNumber;
    config.log_level    = InpLogLevel;
}
