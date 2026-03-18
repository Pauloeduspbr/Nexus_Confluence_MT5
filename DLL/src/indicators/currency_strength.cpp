//+------------------------------------------------------------------+
//|                   currency_strength.cpp                           |
//|              Nexus V3 - Currency Strength Meter                   |
//+------------------------------------------------------------------+
#include "../../include/indicators/currency_strength.h"
#include <cmath>
#include <algorithm>

CurrencyStrength::CurrencyStrength()
    : m_calc_period(24)
    , m_smoothing(5)
    , m_base_strength(0.0)
    , m_quote_strength(0.0)
    , m_base_smooth(0.0)
    , m_quote_smooth(0.0)
    , m_available(false)
    , m_first_calc(true)
{
}

void CurrencyStrength::Init(int calc_period, int smoothing)
{
    m_calc_period = (calc_period > 2) ? calc_period : 24;
    m_smoothing   = (smoothing > 0)   ? smoothing   : 5;

    m_base_strength = 0.0;
    m_quote_strength = 0.0;
    m_base_smooth = 0.0;
    m_quote_smooth = 0.0;
    m_available = false;
    m_first_calc = true;
}

void CurrencyStrength::Calculate(const NX_BarData* bars, int bar_count)
{
    int min_bars = m_calc_period + m_smoothing + 5;
    if (bar_count < min_bars) {
        m_available = false;
        return;
    }

    int shift = 0;
    double close_curr = bars[shift].close;

    // Short-term momentum (5 bars)
    int short_period = std::min(5, bar_count - shift - 1);
    double short_term = 0.0;
    if (short_period > 0 && bars[shift + short_period].close > 0) {
        short_term = (close_curr - bars[shift + short_period].close)
                     / bars[shift + short_period].close;
    }

    // Medium-term momentum (half period)
    int med_period = std::min(m_calc_period / 2, bar_count - shift - 1);
    double medium_term = 0.0;
    if (med_period > 0 && bars[shift + med_period].close > 0) {
        medium_term = (close_curr - bars[shift + med_period].close)
                      / bars[shift + med_period].close;
    }

    // Long-term momentum (full period)
    int long_period = std::min(m_calc_period, bar_count - shift - 1);
    double long_term = 0.0;
    if (long_period > 0 && bars[shift + long_period].close > 0) {
        long_term = (close_curr - bars[shift + long_period].close)
                    / bars[shift + long_period].close;
    }

    // RSI momentum (normalized to -1..+1)
    double rsi = CalcRSI(bars, bar_count, shift, 14);
    double rsi_momentum = (rsi - 50.0) / 50.0;

    // Volatility adjustment factor
    double volatility = CalcVolatility(bars, bar_count, shift);
    double vol_factor = (volatility > 0.001) ? (1.0 + volatility * 200.0) : 1.0;

    // Weighted base signal
    double base_signal = (short_term * 0.2) + (medium_term * 0.2)
                        + (long_term * 0.5) + (rsi_momentum * 0.1);

    // Quote signal is strict inverse
    double quote_signal = -base_signal;

    // Amplify and apply volatility
    double raw_base = base_signal * 500.0 * vol_factor;
    double raw_quote = quote_signal * 500.0 * vol_factor;

    // Clamp to [-100, +100]
    raw_base = NXMath::Clamp(raw_base, -100.0, 100.0);
    raw_quote = NXMath::Clamp(raw_quote, -100.0, 100.0);

    // Apply EMA smoothing
    if (m_smoothing > 1) {
        double alpha = 2.0 / (m_smoothing + 1.0);
        if (m_first_calc) {
            m_base_smooth = raw_base;
            m_quote_smooth = raw_quote;
            m_first_calc = false;
        } else {
            m_base_smooth = alpha * raw_base + (1.0 - alpha) * m_base_smooth;
            m_quote_smooth = alpha * raw_quote + (1.0 - alpha) * m_quote_smooth;
        }
        m_base_strength = m_base_smooth;
        m_quote_strength = m_quote_smooth;
    } else {
        m_base_strength = raw_base;
        m_quote_strength = raw_quote;
    }

    m_available = true;
}

//+------------------------------------------------------------------+
//| Simple RSI calculation                                            |
//+------------------------------------------------------------------+
double CurrencyStrength::CalcRSI(const NX_BarData* bars, int bar_count, int shift, int period)
{
    if (shift + period >= bar_count) return 50.0;

    double gains = 0.0, losses = 0.0;
    for (int i = 0; i < period; i++) {
        int idx = shift + i;
        if (idx + 1 >= bar_count) break;
        double change = bars[idx].close - bars[idx + 1].close;
        if (change > 0) gains += change;
        else losses += fabs(change);
    }

    if (losses < 1e-10) return 100.0;
    double rs = gains / losses;
    return 100.0 - (100.0 / (1.0 + rs));
}

//+------------------------------------------------------------------+
//| Price position in high/low range: -1 (at low) to +1 (at high)    |
//+------------------------------------------------------------------+
double CurrencyStrength::CalcPricePosition(const NX_BarData* bars, int bar_count, int shift, int period)
{
    if (shift + period >= bar_count) return 0.0;

    double highest = bars[shift].high;
    double lowest  = bars[shift].low;

    for (int i = 1; i < period && (shift + i) < bar_count; i++) {
        highest = fmax(highest, bars[shift + i].high);
        lowest  = fmin(lowest, bars[shift + i].low);
    }

    double range = highest - lowest;
    if (range < 1e-10) return 0.0;

    return ((bars[shift].close - lowest) / range) * 2.0 - 1.0;
}

//+------------------------------------------------------------------+
//| Average absolute percent change (volatility measure)              |
//+------------------------------------------------------------------+
double CurrencyStrength::CalcVolatility(const NX_BarData* bars, int bar_count, int shift)
{
    int period = std::min(20, bar_count - shift - 1);
    if (period <= 0) return 0.001;

    double sum = 0.0;
    int count = 0;

    for (int i = 0; i < period; i++) {
        int idx = shift + i;
        if (idx + 1 >= bar_count || bars[idx + 1].close < 1e-10) continue;
        double pct_change = fabs((bars[idx].close - bars[idx + 1].close) / bars[idx + 1].close);
        sum += pct_change;
        count++;
    }

    return (count > 0) ? fmax(sum / count, 0.001) : 0.001;
}
