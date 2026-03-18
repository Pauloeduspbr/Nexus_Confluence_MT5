//+------------------------------------------------------------------+
//|                      gg_trendbar.cpp                              |
//|         Nexus V3 - GG TrendBar (ADX+SAR Multi-Timeframe)         |
//+------------------------------------------------------------------+
#include "../../include/indicators/gg_trendbar.h"
#include <cmath>
#include <cstring>
#include <algorithm>

// MQL5 timeframe enum values -> internal index mapping
// Index: 0=M1, 1=M5, 2=M10, 3=M15, 4=M20, 5=M30,
//        6=H1, 7=H2, 8=H4, 9=H6, 10=H8, 11=H12,
//        12=D1, 13=W1, 14=MN1
static const int TF_MAP_VALUES[GG_MAX_TFS] = {
    1, 5, 10, 15, 20, 30,           // M1-M30
    16385, 16386, 16388, 16390,     // H1-H6
    16392, 16396,                   // H8, H12
    16408, 32769, 49153             // D1, W1, MN1
};

GGTrendBar::GGTrendBar()
    : m_adx_period(14)
    , m_psar_step(0.02)
    , m_psar_max(0.20)
    , m_di_separation(3.0)
{
    memset(m_trend_values, 0, sizeof(m_trend_values));
    memset(m_adx_state, 0, sizeof(m_adx_state));
    memset(m_sar_state, 0, sizeof(m_sar_state));
}

void GGTrendBar::Init(int adx_period, double psar_step, double psar_max, double di_separation)
{
    m_adx_period = (adx_period > 1) ? adx_period : 14;
    m_psar_step  = (psar_step > 0)  ? psar_step  : 0.02;
    m_psar_max   = (psar_max > m_psar_step) ? psar_max : 0.20;
    m_di_separation = (di_separation >= 0) ? di_separation : 3.0;

    memset(m_trend_values, 0, sizeof(m_trend_values));
    for (int i = 0; i < GG_MAX_TFS; i++) {
        m_adx_state[i].initialized = false;
        m_sar_state[i].initialized = false;
    }
}

int GGTrendBar::TFToIndex(int mql5_tf)
{
    for (int i = 0; i < GG_MAX_TFS; i++) {
        if (TF_MAP_VALUES[i] == mql5_tf) return i;
    }
    return -1;
}

int GGTrendBar::GetTrendByTF(int mql5_tf) const
{
    int idx = TFToIndex(mql5_tf);
    return (idx >= 0) ? m_trend_values[idx] : 0;
}

int GGTrendBar::CalculateForTF(const NX_BarData* bars, int bar_count, int tf_index)
{
    if (tf_index < 0 || tf_index >= GG_MAX_TFS) return 0;
    if (bar_count < m_adx_period + 3) return 0;

    // CRITICAL FIX: Skip recalculation if bar data hasn't changed.
    // Without this, stateful indicators (ADX EMA, SAR) get updated N times
    // per higher-TF bar (e.g., 16x for H4 on M15 operational TF), causing
    // the EMA to converge/drift and SAR to advance artificially.
    int64_t current_bar_time = bars[0].time;
    if (m_adx_state[tf_index].initialized &&
        m_adx_state[tf_index].last_bar_time == current_bar_time) {
        // Same bar as last call — return cached trend value
        return m_trend_values[tf_index];
    }

    // Calculate ADX components (+DI, -DI)
    double plus_di = 0.0, minus_di = 0.0;
    CalcADX(bars, bar_count, tf_index, plus_di, minus_di);

    // Calculate Parabolic SAR
    double sar = CalcSAR(bars, bar_count, tf_index);

    // Get current price (close of most recent bar)
    double price = bars[0].close;

    // Determine trend
    m_trend_values[tf_index] = DetermineTrend(plus_di, minus_di, sar, price);

    // Store processed bar time
    m_adx_state[tf_index].last_bar_time = current_bar_time;
    m_sar_state[tf_index].last_bar_time = current_bar_time;

    return m_trend_values[tf_index];
}

//+------------------------------------------------------------------+
//| ADX Calculation from raw OHLC                                     |
//| Implements Wilder's directional movement system                   |
//+------------------------------------------------------------------+
void GGTrendBar::CalcADX(const NX_BarData* bars, int bar_count, int tf_idx,
                         double &plus_di, double &minus_di)
{
    ADXState& state = m_adx_state[tf_idx];

    if (!state.initialized) {
        // First calculation: compute initial averages
        double plus_dm_sum = 0.0, minus_dm_sum = 0.0, tr_sum = 0.0;

        for (int i = 0; i < m_adx_period && (i + 1) < bar_count; i++) {
            double high_curr = bars[i].high;
            double low_curr  = bars[i].low;
            double high_prev = bars[i + 1].high;
            double low_prev  = bars[i + 1].low;
            double close_prev = bars[i + 1].close;

            // Directional Movement
            double up_move = high_curr - high_prev;
            double down_move = low_prev - low_curr;

            double pdm = (up_move > down_move && up_move > 0) ? up_move : 0.0;
            double mdm = (down_move > up_move && down_move > 0) ? down_move : 0.0;

            plus_dm_sum += pdm;
            minus_dm_sum += mdm;

            // True Range
            tr_sum += NXMath::TrueRange(high_curr, low_curr, close_prev);
        }

        state.prev_plus_dm_ema = plus_dm_sum;
        state.prev_minus_dm_ema = minus_dm_sum;
        state.prev_tr_ema = tr_sum;
        state.initialized = true;
    } else {
        // Wilder's smoothing update
        double high_curr = bars[0].high;
        double low_curr  = bars[0].low;
        double high_prev = bars[1].high;
        double low_prev  = bars[1].low;
        double close_prev = bars[1].close;

        double up_move = high_curr - high_prev;
        double down_move = low_prev - low_curr;

        double pdm = (up_move > down_move && up_move > 0) ? up_move : 0.0;
        double mdm = (down_move > up_move && down_move > 0) ? down_move : 0.0;
        double tr = NXMath::TrueRange(high_curr, low_curr, close_prev);

        // Wilder smoothing: prev - (prev/period) + current
        state.prev_plus_dm_ema = state.prev_plus_dm_ema
                                 - (state.prev_plus_dm_ema / m_adx_period) + pdm;
        state.prev_minus_dm_ema = state.prev_minus_dm_ema
                                  - (state.prev_minus_dm_ema / m_adx_period) + mdm;
        state.prev_tr_ema = state.prev_tr_ema
                            - (state.prev_tr_ema / m_adx_period) + tr;
    }

    // Calculate +DI and -DI
    if (state.prev_tr_ema > 0) {
        plus_di = 100.0 * state.prev_plus_dm_ema / state.prev_tr_ema;
        minus_di = 100.0 * state.prev_minus_dm_ema / state.prev_tr_ema;
    } else {
        plus_di = 0.0;
        minus_di = 0.0;
    }

    state.plus_di = plus_di;
    state.minus_di = minus_di;
}

//+------------------------------------------------------------------+
//| Parabolic SAR Calculation                                         |
//+------------------------------------------------------------------+
double GGTrendBar::CalcSAR(const NX_BarData* bars, int bar_count, int tf_idx)
{
    SARState& state = m_sar_state[tf_idx];

    if (!state.initialized || bar_count < 3) {
        // Initialize SAR
        // Start as long (uptrend) with SAR at recent low
        state.is_long = (bars[0].close > bars[1].close);
        state.af = m_psar_step;

        if (state.is_long) {
            state.sar = bars[1].low;
            state.ep = bars[0].high;
        } else {
            state.sar = bars[1].high;
            state.ep = bars[0].low;
        }
        state.initialized = true;
        return state.sar;
    }

    double prev_sar = state.sar;
    double prev_ep = state.ep;
    double prev_af = state.af;

    // Calculate new SAR
    double new_sar = prev_sar + prev_af * (prev_ep - prev_sar);

    if (state.is_long) {
        // Uptrend
        // SAR cannot be above previous two lows
        new_sar = fmin(new_sar, bars[1].low);
        if (bar_count > 2) {
            new_sar = fmin(new_sar, bars[2].low);
        }

        if (bars[0].low <= new_sar) {
            // Reversal: switch to downtrend
            state.is_long = false;
            new_sar = prev_ep; // SAR = highest high during uptrend
            state.ep = bars[0].low;
            state.af = m_psar_step;
        } else {
            // Continue uptrend
            if (bars[0].high > prev_ep) {
                state.ep = bars[0].high;
                state.af = fmin(prev_af + m_psar_step, m_psar_max);
            }
        }
    } else {
        // Downtrend
        // SAR cannot be below previous two highs
        new_sar = fmax(new_sar, bars[1].high);
        if (bar_count > 2) {
            new_sar = fmax(new_sar, bars[2].high);
        }

        if (bars[0].high >= new_sar) {
            // Reversal: switch to uptrend
            state.is_long = true;
            new_sar = prev_ep; // SAR = lowest low during downtrend
            state.ep = bars[0].high;
            state.af = m_psar_step;
        } else {
            // Continue downtrend
            if (bars[0].low < prev_ep) {
                state.ep = bars[0].low;
                state.af = fmin(prev_af + m_psar_step, m_psar_max);
            }
        }
    }

    state.sar = new_sar;
    return new_sar;
}

//+------------------------------------------------------------------+
//| Determine trend: +1 bullish, 0 neutral, -1 bearish               |
//| Logic: SAR direction + ADX DI confirmation                       |
//+------------------------------------------------------------------+
int GGTrendBar::DetermineTrend(double plus_di, double minus_di, double sar, double price)
{
    bool sar_bullish = (price > sar);
    bool sar_bearish = (price < sar);

    double di_diff = fabs(plus_di - minus_di);
    bool di_bullish = (plus_di > minus_di);
    bool di_bearish = (minus_di > plus_di);

    // Minimum DI separation required to confirm a direction (configurable).
    // If +DI and -DI are within this threshold, ADX is considered neutral
    // and we do NOT confirm the SAR direction — return 0 instead.
    double min_di_separation = m_di_separation;

    // Require BOTH: SAR direction AND DI agreement with sufficient separation
    if (sar_bullish && di_bullish && di_diff >= min_di_separation) {
        return 1;  // Bullish: SAR above price AND +DI clearly dominates
    }

    if (sar_bearish && di_bearish && di_diff >= min_di_separation) {
        return -1; // Bearish: SAR below price AND -DI clearly dominates
    }

    return 0; // Neutral: no clear agreement between SAR and ADX
}
