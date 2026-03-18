//+------------------------------------------------------------------+
//|                        NexusV3Bridge.mqh                          |
//|                  Nexus Confluence V3 - DLL Bridge                  |
//|                     Copyright 2024-2026, Nexus EA                 |
//+------------------------------------------------------------------+
#property copyright "Nexus Confluence V3"
#property version   "3.00"

//+------------------------------------------------------------------+
//| Structs matching C++ NX_BarData (6 doubles per bar)               |
//| Must match DLL #pragma pack(push, 4) layout                      |
//+------------------------------------------------------------------+
struct NX_BarData_MQL
{
    double open;
    double high;
    double low;
    double close;
    long   volume;
    long   time;
};

struct NX_SymbolInfo_MQL
{
    char   symbol[32];
    double point;
    int    digits;
    double tick_size;
    double tick_value;
    double lot_min;
    double lot_max;
    double lot_step;
    int    stops_level;
    int    freeze_level;
    double spread;
    double bid;
    double ask;
};

// NOTE: All booleans use int (0/1) to guarantee identical
// struct layout between MQL5 and C++ across compilers.
struct NX_PositionContext_MQL
{
    int    open_count;
    int    open_direction;
};

struct NX_Config_MQL
{
    double lot_size;
    int    max_slippage;

    int    sl_buy;
    int    tp_buy;
    int    min_score_buy;
    int    enable_buy;

    int    sl_sell;
    int    tp_sell;
    int    min_score_sell;
    int    enable_sell;

    int    be_buy_enable;
    int    be_buy_trigger;
    int    be_buy_step;

    int    be_sell_enable;
    int    be_sell_trigger;
    int    be_sell_step;

    int    ts_buy_enable;
    int    ts_buy_trigger;
    int    ts_buy_step;

    int    ts_sell_enable;
    int    ts_sell_trigger;
    int    ts_sell_step;

    int    dd_enable;
    double dd_daily_max;
    int    dd_consec_loss;
    double dd_lot_reduce;

    int    spread_filter_enable;
    int    max_spread;
    double spread_multiplier;
    int    spread_period;

    int    use_time_filter;
    int    start_hour;
    int    start_minute;
    int    end_hour;
    int    end_minute;
    int    trade_days[7];

    int    macro1_tf;
    int    macro2_tf;
    int    macro3_tf;
    int    operational_tf;

    int    buy_premium_enable;
    int    buy_good_enable;
    int    sell_premium_enable;
    int    sell_good_enable;

    int    gg_adx_period;
    double gg_psar_step;
    double gg_psar_max;

    int    st_cci_period;
    int    st_er_period;
    int    st_volatility_period;
    double st_band_multiplier;

    int    macd_fast;
    int    macd_slow;
    int    macd_signal;
    int    macd_obv_window;
    int    macd_use_tick_vol;
    int    macd_thresh_period;
    double macd_thresh_mult;

    int    rsi_period;
    int    rsi_ma_period;
    int    rsi_ma_method;

    int    cs_enable;
    int    cs_calc_period;
    int    cs_smoothing;

    int    cooldown_enable;
    int    cooldown_candles;

    double g4_rsi_ob;
    double g4_rsi_os;

    double g5_er_min;
    double g5_er_decline;
    double g5_momentum_ratio;
    int    g5_macro_flip_cd;

    double dyn_sl_max;
    double dyn_sl_min;
    double dyn_tp_min;
    double dyn_tp_max;
    int    min_sl_tp_steps;

    double gg_di_separation;

    double st_band_trend_factor;

    double rsi_hysteresis;

    int    max_positions;
    double lot_scale_factor;

    int    magic_number;
    int    log_level;
};

struct NX_TickResult_MQL
{
    int    action;
    int    signal_class;
    int    mtf_score;
    int    sl_steps;
    int    tp_steps;
    double lot_size;
    char   comment[64];
    int    gate_results[6];
    char   log_message[512];
};

struct NX_PositionInfo_MQL
{
    long   ticket;
    int    type;
    double entry_price;
    double current_sl;
    double current_tp;
    double current_price;
    double profit;
    int    profit_steps;
    long   open_time;
};

struct NX_ManageResult_MQL
{
    int    action;
    double new_sl;
    char   reason[128];
    int    circuit_breaker;
    double adjusted_lot;
};

//+------------------------------------------------------------------+
//| DLL Import                                                        |
//+------------------------------------------------------------------+
#import "NexusConfluence.dll"

int  NX_Init(NX_Config_MQL &config, NX_SymbolInfo_MQL &symbol);
void NX_Deinit();
int  NX_OnTick(
    NX_BarData_MQL &bars[], int bar_count,
    NX_BarData_MQL &bars_macro1[], int macro1_count,
    NX_BarData_MQL &bars_macro2[], int macro2_count,
    NX_BarData_MQL &bars_macro3[], int macro3_count,
    NX_SymbolInfo_MQL &current_symbol,
    NX_PositionContext_MQL &pos_ctx,
    NX_TickResult_MQL &result
);
int  NX_ManagePosition(NX_PositionInfo_MQL &position, NX_ManageResult_MQL &result);
void NX_OnTradeResult(int is_win, double profit_loss, int remaining_positions);
int  NX_GetVersion();
int  NX_GetLastError(char &buffer[], int buffer_size);
void NX_ResetState();
int  NX_GetState();

#import

//+------------------------------------------------------------------+
//| Helper: Copy OHLCV bars into NX_BarData_MQL array                 |
//| Always copies from shift=1 (most recent CLOSED bar)               |
//+------------------------------------------------------------------+
bool CopyBarsForDLL(string symbol, ENUM_TIMEFRAMES tf, int count, NX_BarData_MQL &out_array[])
{
    if(count <= 0) return false;

    ArrayResize(out_array, count);

    MqlRates rates[];
    ArraySetAsSeries(rates, true);

    int copied = CopyRates(symbol, tf, 1, count, rates);
    if(copied < count)
    {
        Print("WARNING: CopyRates returned ", copied, " bars (requested ", count, ") for ", symbol, " ", EnumToString(tf));
        if(copied <= 0) return false;
        count = copied;
        ArrayResize(out_array, count);
    }

    for(int i = 0; i < count; i++)
    {
        out_array[i].open   = rates[i].open;
        out_array[i].high   = rates[i].high;
        out_array[i].low    = rates[i].low;
        out_array[i].close  = rates[i].close;
        out_array[i].volume = rates[i].tick_volume;
        out_array[i].time   = (long)rates[i].time;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Helper: Fill NX_SymbolInfo_MQL from current symbol                 |
//+------------------------------------------------------------------+
void FillSymbolInfo(string sym, NX_SymbolInfo_MQL &info)
{
    ZeroMemory(info);

    // Copy symbol name (max 31 chars + null)
    StringToCharArray(sym, info.symbol, 0, MathMin(StringLen(sym), 31));

    info.point        = SymbolInfoDouble(sym, SYMBOL_POINT);
    info.digits       = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
    info.tick_size    = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
    info.tick_value   = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
    info.lot_min      = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
    info.lot_max      = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);
    info.lot_step     = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
    info.stops_level  = (int)SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL);
    info.freeze_level = (int)SymbolInfoInteger(sym, SYMBOL_TRADE_FREEZE_LEVEL);
    info.spread       = (double)SymbolInfoInteger(sym, SYMBOL_SPREAD);
    info.bid          = SymbolInfoDouble(sym, SYMBOL_BID);
    info.ask          = SymbolInfoDouble(sym, SYMBOL_ASK);
}

//+------------------------------------------------------------------+
//| Signal Class names                                                |
//+------------------------------------------------------------------+
string SignalClassToString(int signal_class)
{
    switch(signal_class)
    {
        case 0: return "NONE";
        case 1: return "REJECT";
        case 2: return "GOOD";
        case 3: return "PREMIUM";
        default: return "UNKNOWN";
    }
}

string SignalDirectionToString(int direction)
{
    switch(direction)
    {
        case 0: return "NONE";
        case 1: return "BUY";
        case 2: return "SELL";
        default: return "UNKNOWN";
    }
}
