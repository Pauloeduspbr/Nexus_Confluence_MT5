//+------------------------------------------------------------------+
//|                      trend_magic.cpp                              |
//|           Nexus V3 - Adaptive Supertrend (CCI+ER+TR_EMA)         |
//+------------------------------------------------------------------+
#include "../../include/indicators/trend_magic.h"
#include <cmath>
#include <algorithm>

TrendMagic::TrendMagic()
    : m_cci_period(50)
    , m_er_period(10)
    , m_vol_period(5)
    , m_band_mult(1.5)
    , m_band_trend_factor(0.5)
    , m_upper_band(0.0)
    , m_lower_band(0.0)
    , m_close(0.0)
    , m_signal(0)
    , m_prev_upper(0.0)
    , m_prev_lower(0.0)
    , m_tr_ema(0.0)
    , m_er(0.5)
    , m_prev_er(0.5)
    , m_first_calc(true)
{
}

void TrendMagic::Init(int cci_period, int er_period, int vol_period, double band_mult, double band_trend_factor)
{
    m_cci_period = (cci_period > 1) ? cci_period : 50;
    m_er_period  = (er_period > 1)  ? er_period  : 10;
    m_vol_period = (vol_period > 1) ? vol_period : 5;
    m_band_mult  = (band_mult > 0)  ? band_mult  : 1.5;
    m_band_trend_factor = (band_trend_factor >= 0 && band_trend_factor <= 1.0) ? band_trend_factor : 0.5;

    m_upper_band = 0.0;
    m_lower_band = 0.0;
    m_prev_upper = 0.0;
    m_prev_lower = 0.0;
    m_tr_ema = 0.0;
    m_er = 0.5;
    m_prev_er = 0.5;
    m_signal = 0;
    m_first_calc = true;
}

int TrendMagic::Calculate(const NX_BarData* bars, int bar_count)
{
    // Need enough bars for CCI + ER + volatility calculations
    int min_bars = std::max({m_cci_period + 2, m_er_period + 2, m_vol_period + 2});
    if (bar_count < min_bars) {
        m_signal = 0;
        return 0;
    }

    // Current bar is index 0 (shift=1 from MQL5, most recent closed)
    int shift = 0;

    m_close = bars[shift].close;

    // Step 1: Calculate CCI (Commodity Channel Index)
    double cci = CalcCCI(bars, bar_count, shift);

    // Step 2: Calculate Kaufman Efficiency Ratio
    m_prev_er = m_er;
    double er = CalcEfficiencyRatio(bars, bar_count, shift);
    m_er = er;

    // Step 3: Calculate True Range EMA (replaces ATR)
    double tr = CalcTrueRange(bars, shift);
    if (m_first_calc) {
        // Initialize TR EMA with simple average
        double tr_sum = 0.0;
        int count = std::min(m_vol_period, bar_count - 1);
        for (int i = 0; i < count; i++) {
            tr_sum += CalcTrueRange(bars, i);
        }
        m_tr_ema = (count > 0) ? tr_sum / count : tr;
    } else {
        // EMA of True Range (faster response than ATR/SMA)
        double alpha = 2.0 / (m_vol_period + 1.0);
        m_tr_ema = alpha * tr + (1.0 - alpha) * m_tr_ema;
    }

    // Step 4: Adaptive band width
    // ER high (trend)  -> narrow bands (follow closely)
    // ER low  (range)  -> wide bands (avoid whipsaw)
    double adaptive_factor = (1.0 - er) * m_band_mult + er * (m_band_mult * m_band_trend_factor);
    double band_width = m_tr_ema * adaptive_factor;

    // Step 5: Calculate trend lines based on CCI direction
    double new_upper = 0.0;
    double new_lower = 0.0;

    if (cci >= 0.0) {
        // Bullish: lower band = support line
        new_lower = bars[shift].low - band_width;
        // Monotonic increase (SAR-style)
        if (!m_first_calc && new_lower < m_prev_lower) {
            new_lower = m_prev_lower;
        }
        new_upper = bars[shift].high + band_width;
    }

    if (cci <= 0.0) {
        // Bearish: upper band = resistance line
        new_upper = bars[shift].high + band_width;
        // Monotonic decrease
        if (!m_first_calc && new_upper > m_prev_upper && m_prev_upper > 0.0) {
            new_upper = m_prev_upper;
        }
        new_lower = bars[shift].low - band_width;
    }

    // Step 6: Determine signal
    if (m_close > new_lower && new_lower > 0.0 && cci >= 0.0) {
        m_signal = 1;  // Bullish
        m_lower_band = new_lower;
        m_upper_band = 0.0;  // not active
    } else if (m_close < new_upper && new_upper > 0.0 && cci <= 0.0) {
        m_signal = -1; // Bearish
        m_upper_band = new_upper;
        m_lower_band = 0.0;  // not active
    } else {
        m_signal = 0;  // Neutral / transition
        m_upper_band = new_upper;
        m_lower_band = new_lower;
    }

    // Store for next iteration
    m_prev_upper = new_upper;
    m_prev_lower = new_lower;
    m_first_calc = false;

    return m_signal;
}

//+------------------------------------------------------------------+
//| CCI = (Typical Price - SMA of TP) / (0.015 * Mean Deviation)     |
//+------------------------------------------------------------------+
double TrendMagic::CalcCCI(const NX_BarData* bars, int bar_count, int shift)
{
    if (shift + m_cci_period >= bar_count) return 0.0;

    // Calculate typical prices
    double tp_sum = 0.0;
    for (int i = 0; i < m_cci_period; i++) {
        int idx = shift + i;
        double tp = (bars[idx].high + bars[idx].low + bars[idx].close) / 3.0;
        tp_sum += tp;
    }
    double tp_sma = tp_sum / m_cci_period;

    // Current typical price
    double tp_current = (bars[shift].high + bars[shift].low + bars[shift].close) / 3.0;

    // Mean deviation
    double md_sum = 0.0;
    for (int i = 0; i < m_cci_period; i++) {
        int idx = shift + i;
        double tp = (bars[idx].high + bars[idx].low + bars[idx].close) / 3.0;
        md_sum += fabs(tp - tp_sma);
    }
    double mean_dev = md_sum / m_cci_period;

    if (mean_dev < 1e-10) return 0.0;

    return (tp_current - tp_sma) / (0.015 * mean_dev);
}

//+------------------------------------------------------------------+
//| Efficiency Ratio = |Direction| / Sum(|Changes|)                   |
//| ER -> 1.0 in trending, ER -> 0.0 in ranging                     |
//+------------------------------------------------------------------+
double TrendMagic::CalcEfficiencyRatio(const NX_BarData* bars, int bar_count, int shift)
{
    if (shift + m_er_period >= bar_count) return 0.5; // default mid

    // Direction: net price change over period
    double direction = fabs(bars[shift].close - bars[shift + m_er_period].close);

    // Volatility: sum of absolute per-bar changes
    double volatility = 0.0;
    for (int i = 0; i < m_er_period; i++) {
        int idx = shift + i;
        if (idx + 1 < bar_count) {
            volatility += fabs(bars[idx].close - bars[idx + 1].close);
        }
    }

    if (volatility < 1e-10) return 1.0; // no noise = perfect efficiency

    return NXMath::Clamp(direction / volatility, 0.0, 1.0);
}

//+------------------------------------------------------------------+
//| True Range = max(H-L, |H-PrevC|, |L-PrevC|)                     |
//+------------------------------------------------------------------+
double TrendMagic::CalcTrueRange(const NX_BarData* bars, int shift)
{
    double hl = bars[shift].high - bars[shift].low;

    if (shift + 1 < m_vol_period + shift + 5) { // bounds check
        double prev_close = bars[shift + 1].close;
        return NXMath::TrueRange(bars[shift].high, bars[shift].low, prev_close);
    }

    return hl; // fallback if no previous bar
}
