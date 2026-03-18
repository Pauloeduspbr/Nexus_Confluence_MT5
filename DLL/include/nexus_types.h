//+------------------------------------------------------------------+
//|                          nexus_types.h                            |
//|                  Nexus Confluence V3 - Type Definitions           |
//|                     Copyright 2024-2026, Nexus EA                 |
//+------------------------------------------------------------------+
#ifndef NEXUS_TYPES_H
#define NEXUS_TYPES_H

#include <cstdint>

#ifdef NEXUS_DLL_EXPORTS
    #define NEXUS_API __declspec(dllexport)
#else
    #define NEXUS_API __declspec(dllimport)
#endif

#define NEXUS_CALL __stdcall

// Version
#define NEXUS_VERSION_MAJOR 3
#define NEXUS_VERSION_MINOR 0
#define NEXUS_VERSION_BUILD 1
#define NEXUS_VERSION ((NEXUS_VERSION_MAJOR * 10000) + (NEXUS_VERSION_MINOR * 100) + NEXUS_VERSION_BUILD)

// Limits
#define NX_MAX_SYMBOL_LEN   32
#define NX_MAX_COMMENT_LEN  64
#define NX_MAX_LOG_LEN      512
#define NX_MAX_REASON_LEN   128
#define NX_MAX_BARS         500
#define NX_NUM_GATES        6
#define NX_NUM_TFS          15

//+------------------------------------------------------------------+
//| Enums                                                             |
//+------------------------------------------------------------------+

// EA State Machine
enum NX_EAState {
    NX_STATE_IDLE              = 0,
    NX_STATE_SIGNAL_DETECTED   = 1,
    NX_STATE_PROCESSING_ORDER  = 2,
    NX_STATE_ORDER_SENT        = 3,
    NX_STATE_WAITING_CLOSE     = 4,
    NX_STATE_ERROR_RECOVERY    = 5
};

// Signal Classification
enum NX_SignalClass {
    NX_SIGNAL_NONE    = 0,
    NX_SIGNAL_REJECT  = 1,
    NX_SIGNAL_GOOD    = 2,
    NX_SIGNAL_PREMIUM = 3
};

// Signal Direction
enum NX_SignalDirection {
    NX_DIR_NONE = 0,
    NX_DIR_BUY  = 1,
    NX_DIR_SELL = 2
};

// Market Type (auto-detected)
enum NX_MarketType {
    NX_MARKET_FOREX   = 0,
    NX_MARKET_B3      = 1,
    NX_MARKET_INDICES = 2,
    NX_MARKET_METALS  = 3,
    NX_MARKET_CRYPTO  = 4,
    NX_MARKET_UNKNOWN = 5
};

// Position Management Action
enum NX_ManageAction {
    NX_MANAGE_NONE          = 0,
    NX_MANAGE_MODIFY_SL     = 1,
    NX_MANAGE_CLOSE         = 2,
    NX_MANAGE_CIRCUIT_BREAK = 3
};

// Log Levels
enum NX_LogLevel {
    NX_LOG_EXECUTIVE   = 1,  // Trades and critical errors only
    NX_LOG_OPERATIONAL = 2,  // Gates, scores, decisions
    NX_LOG_DEBUG       = 3   // Raw indicator values
};

// Gate Indices
enum NX_GateIndex {
    NX_GATE_SYNC       = 0,
    NX_GATE_MARKET     = 1,
    NX_GATE_MTF        = 2,
    NX_GATE_SUPERTREND = 3,
    NX_GATE_MOMENTUM   = 4,
    NX_GATE_CONTEXT    = 5
};

// Gate Result
enum NX_GateResult {
    NX_GATE_NOT_RUN = 0,
    NX_GATE_PASS    = 1,
    NX_GATE_FAIL    = -1
};

// MA Methods (matching MQL5 ENUM_MA_METHOD)
enum NX_MAMethod {
    NX_MA_SMA  = 0,
    NX_MA_EMA  = 1,
    NX_MA_SMMA = 2,
    NX_MA_LWMA = 3
};

// Timeframe enum (matching MQL5 values for easy conversion)
enum NX_Timeframe {
    NX_TF_M1   = 1,
    NX_TF_M5   = 5,
    NX_TF_M10  = 10,
    NX_TF_M15  = 15,
    NX_TF_M20  = 20,
    NX_TF_M30  = 30,
    NX_TF_H1   = 16385,
    NX_TF_H2   = 16386,
    NX_TF_H4   = 16388,
    NX_TF_H6   = 16390,
    NX_TF_H8   = 16392,
    NX_TF_H12  = 16396,
    NX_TF_D1   = 16408,
    NX_TF_W1   = 32769,
    NX_TF_MN1  = 49153
};

// Error codes
enum NX_ErrorCode {
    NX_OK                    = 0,
    NX_ERR_NOT_INITIALIZED   = -1,
    NX_ERR_INVALID_CONFIG    = -2,
    NX_ERR_INVALID_DATA      = -3,
    NX_ERR_INSUFFICIENT_BARS = -4,
    NX_ERR_INTERNAL          = -5,
    NX_ERR_ALREADY_INIT      = -6,
    NX_ERR_LICENSE_INVALID   = -7,
    NX_ERR_LICENSE_EXPIRED   = -8
};

//+------------------------------------------------------------------+
//| Structs - Data Transfer (MQL5 <-> DLL)                           |
//+------------------------------------------------------------------+

#pragma pack(push, 4)

// Single bar of OHLCV data
struct NX_BarData {
    double open;
    double high;
    double low;
    double close;
    int64_t volume;         // tick_volume or real_volume
    int64_t time;           // datetime as unix timestamp (seconds)
};

// Symbol properties (updated each tick by MQL5)
struct NX_SymbolInfo {
    char    symbol[NX_MAX_SYMBOL_LEN];
    double  point;
    int     digits;
    double  tick_size;
    double  tick_value;
    double  lot_min;
    double  lot_max;
    double  lot_step;
    int     stops_level;
    int     freeze_level;
    double  spread;         // current spread in points
    double  bid;
    double  ask;
};

// Complete configuration (all EA inputs)
// NOTE: All booleans use int (0/1) to guarantee identical
// struct layout between MQL5 and C++ across compilers.
struct NX_Config {
    // --- Risk Management ---
    double lot_size;
    int    max_slippage;

    // --- Asymmetric BUY ---
    int    sl_buy;          // SL in price distance (points)
    int    tp_buy;          // TP in price distance (points)
    int    min_score_buy;
    int    enable_buy;      // 0/1

    // --- Asymmetric SELL ---
    int    sl_sell;
    int    tp_sell;
    int    min_score_sell;
    int    enable_sell;     // 0/1

    // --- Break Even BUY ---
    int    be_buy_enable;   // 0/1
    int    be_buy_trigger;
    int    be_buy_step;

    // --- Break Even SELL ---
    int    be_sell_enable;  // 0/1
    int    be_sell_trigger;
    int    be_sell_step;

    // --- Trailing Stop BUY ---
    int    ts_buy_enable;   // 0/1
    int    ts_buy_trigger;
    int    ts_buy_step;

    // --- Trailing Stop SELL ---
    int    ts_sell_enable;  // 0/1
    int    ts_sell_trigger;
    int    ts_sell_step;

    // --- Drawdown Protection ---
    int    dd_enable;       // 0/1
    double dd_daily_max;        // percentage
    int    dd_consec_loss;
    double dd_lot_reduce;       // factor 0.0-1.0

    // --- Spread Filter ---
    int    spread_filter_enable; // 0/1
    int    max_spread;
    double spread_multiplier;
    int    spread_period;

    // --- Time Filter ---
    int    use_time_filter; // 0/1
    int    start_hour;
    int    start_minute;
    int    end_hour;
    int    end_minute;
    int    trade_days[7];   // Sun=0..Sat=6, 0/1

    // --- Timeframes (MQL5 enum values) ---
    int    macro1_tf;
    int    macro2_tf;
    int    macro3_tf;
    int    operational_tf;

    // --- Signal Profiles ---
    int    buy_premium_enable;  // 0/1
    int    buy_good_enable;     // 0/1
    int    sell_premium_enable; // 0/1
    int    sell_good_enable;    // 0/1

    // --- GG TrendBar Params ---
    int    gg_adx_period;
    double gg_psar_step;
    double gg_psar_max;

    // --- Supertrend Adaptive Params ---
    int    st_cci_period;
    int    st_er_period;           // Kaufman Efficiency Ratio period
    int    st_volatility_period;   // True Range EMA period
    double st_band_multiplier;    // Band distance multiplier

    // --- OBV MACD Params ---
    int    macd_fast;
    int    macd_slow;
    int    macd_signal;
    int    macd_obv_window;
    int    macd_use_tick_vol;  // 0/1
    int    macd_thresh_period;
    double macd_thresh_mult;

    // --- RSI OMA Params ---
    int    rsi_period;
    int    rsi_ma_period;
    int    rsi_ma_method;       // NX_MAMethod

    // --- Currency Strength Params ---
    int    cs_enable;       // 0/1
    int    cs_calc_period;
    int    cs_smoothing;

    // --- Cooldown Anti-Churn ---
    int    cooldown_enable;     // 0/1
    int    cooldown_candles;    // N candles to block same direction after SL

    // --- Gate 4 RSI Extremes Filter ---
    double g4_rsi_ob;           // RSI overbought threshold (e.g. 75.0)
    double g4_rsi_os;           // RSI oversold threshold (e.g. 25.0)

    // --- Gate 5 Trend Quality Filter ---
    double g5_er_min;           // Minimum ER to allow trade (0.0-1.0)
    double g5_er_decline;       // Max ER decline ratio (e.g. 0.65 = reject if ER drops 35%)
    double g5_momentum_ratio;   // Histogram must be > threshold × this (e.g. 1.5)
    int    g5_macro_flip_cd;    // Candles to block after macro direction change (0=disabled)

    // --- Dynamic SL/TP Scaling ---
    double dyn_sl_max;          // SL multiplier when ER=0 (ranging, e.g. 1.5)
    double dyn_sl_min;          // SL multiplier when ER=1 (trending, e.g. 0.7)
    double dyn_tp_min;          // TP multiplier when ER=0 (ranging, e.g. 0.8)
    double dyn_tp_max;          // TP multiplier when ER=1 (trending, e.g. 1.5)
    int    min_sl_tp_steps;     // Minimum SL/TP in steps (e.g. 10)

    // --- GG TrendBar Advanced ---
    double gg_di_separation;    // Min DI separation for trend confirmation (e.g. 3.0)

    // --- Supertrend Advanced ---
    double st_band_trend_factor;// Band narrowing in trend (0.0-1.0, e.g. 0.5)

    // --- RSI OMA Advanced ---
    double rsi_hysteresis;      // RSI vs MA crossing threshold (e.g. 0.01)

    // --- Multi-Position ---
    int    max_positions;       // Max simultaneous positions (1=classic, >1=pyramid)
    double lot_scale_factor;   // Lot reduction per additional position (e.g. 0.5 = 50% each)

    // --- General ---
    int    magic_number;
    int    log_level;           // NX_LogLevel

    // --- License ---
    int    account_number;      // MT5 account number for license validation
    char   license_key[32];     // License key (XXXX-XXXX-XXXX-XXXX format)
};

// Multi-position context (MQL5 -> DLL, passed with each tick)
struct NX_PositionContext {
    int    open_count;          // Number of currently open positions
    int    open_direction;      // Direction of open positions (0=none, 1=BUY, 2=SELL)
};

// Result from tick processing
struct NX_TickResult {
    int    action;              // NX_SignalDirection: 0=NONE, 1=BUY, 2=SELL
    int    signal_class;        // NX_SignalClass
    int    mtf_score;           // -4 to +4
    int    sl_steps;            // SL in steps (converted)
    int    tp_steps;            // TP in steps (converted)
    double lot_size;            // Adjusted lot (DD protection)
    char   comment[NX_MAX_COMMENT_LEN];
    int    gate_results[NX_NUM_GATES]; // NX_GateResult per gate
    char   log_message[NX_MAX_LOG_LEN];
};

// Position info (MQL5 -> DLL for BE/TS/DD management)
struct NX_PositionInfo {
    int64_t ticket;
    int     type;               // 0=BUY, 1=SELL
    double  entry_price;
    double  current_sl;
    double  current_tp;
    double  current_price;      // bid or ask depending on direction
    double  profit;             // in account currency
    int     profit_steps;       // profit in steps
    int64_t open_time;          // unix timestamp
};

// Result from position management
struct NX_ManageResult {
    int    action;              // NX_ManageAction
    double new_sl;              // new SL price if action=MODIFY_SL
    char   reason[NX_MAX_REASON_LEN];
    int    circuit_breaker;     // CB activated? 0/1
    double adjusted_lot;        // lot after DD reduction
};

#pragma pack(pop)

#endif // NEXUS_TYPES_H
