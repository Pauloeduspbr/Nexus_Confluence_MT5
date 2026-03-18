//+------------------------------------------------------------------+
//|                       obv_macd.cpp                                |
//|              Nexus V3 - OBV MACD v4 (Windowed OBV)               |
//+------------------------------------------------------------------+
#include "../../include/indicators/obv_macd.h"
#include <cmath>
#include <algorithm>

ObvMacd::ObvMacd()
    : m_fast_period(5)
    , m_slow_period(13)
    , m_signal_period(4)
    , m_obv_window(20)
    , m_use_tick_vol(true)
    , m_thresh_period(14)
    , m_thresh_mult(0.4)
    , m_fast_ema(0.0)
    , m_slow_ema(0.0)
    , m_signal_line(0.0)
    , m_macd_line(0.0)
    , m_histogram(0.0)
    , m_histogram_prev(0.0)
    , m_threshold(0.0)
    , m_thresh_ema(0.0)
    , m_first_calc(true)
{
}

void ObvMacd::Init(int fast_ema, int slow_ema, int signal_sma,
                   int obv_window, bool use_tick_vol,
                   int thresh_period, double thresh_mult)
{
    m_fast_period   = (fast_ema > 1)     ? fast_ema     : 5;
    m_slow_period   = (slow_ema > 1)     ? slow_ema     : 13;
    m_signal_period = (signal_sma > 1)   ? signal_sma   : 4;
    m_obv_window    = (obv_window > 1)   ? obv_window   : 20;
    m_use_tick_vol  = use_tick_vol;
    m_thresh_period = (thresh_period > 1) ? thresh_period : 14;
    m_thresh_mult   = (thresh_mult > 0)  ? thresh_mult  : 0.4;

    m_fast_ema = 0.0;
    m_slow_ema = 0.0;
    m_signal_line = 0.0;
    m_macd_line = 0.0;
    m_histogram = 0.0;
    m_histogram_prev = 0.0;
    m_threshold = 0.0;
    m_thresh_ema = 0.0;
    m_first_calc = true;
}

void ObvMacd::Calculate(const NX_BarData* bars, int bar_count)
{
    int min_bars = std::max(m_obv_window + m_slow_period + 5, 30);
    if (bar_count < min_bars) return;

    // Save previous histogram
    m_histogram_prev = m_histogram;

    // Step 1: Calculate windowed OBV for current bar
    double obv = CalcWindowedOBV(bars, bar_count, 0);

    // Step 2: EMA of windowed OBV (Fast and Slow)
    if (m_first_calc) {
        // Seed EMAs with simple averages
        double fast_sum = 0.0, slow_sum = 0.0;
        int fast_count = std::min(m_fast_period, bar_count - m_obv_window);
        int slow_count = std::min(m_slow_period, bar_count - m_obv_window);

        for (int i = 0; i < slow_count; i++) {
            double v = CalcWindowedOBV(bars, bar_count, i);
            slow_sum += v;
            if (i < fast_count) fast_sum += v;
        }

        m_fast_ema = (fast_count > 0) ? fast_sum / fast_count : obv;
        m_slow_ema = (slow_count > 0) ? slow_sum / slow_count : obv;
        m_first_calc = false;
    } else {
        double alpha_fast = 2.0 / (m_fast_period + 1.0);
        double alpha_slow = 2.0 / (m_slow_period + 1.0);

        m_fast_ema = alpha_fast * obv + (1.0 - alpha_fast) * m_fast_ema;
        m_slow_ema = alpha_slow * obv + (1.0 - alpha_slow) * m_slow_ema;
    }

    // Step 3: MACD Line = Fast EMA - Slow EMA
    m_macd_line = m_fast_ema - m_slow_ema;

    // Step 4: Signal Line = EMA of MACD
    double alpha_signal = 2.0 / (m_signal_period + 1.0);
    m_signal_line = alpha_signal * m_macd_line + (1.0 - alpha_signal) * m_signal_line;

    // Step 5: Histogram = MACD - Signal
    m_histogram = m_macd_line - m_signal_line;

    // Step 6: Adaptive Threshold = EMA of |histogram| * multiplier
    double abs_hist = fabs(m_histogram);
    double scaled_input = abs_hist * m_thresh_mult;

    if (m_thresh_period <= 1) {
        m_threshold = scaled_input;
    } else {
        double alpha_thresh = 2.0 / (m_thresh_period + 1.0);
        m_thresh_ema = alpha_thresh * scaled_input + (1.0 - alpha_thresh) * m_thresh_ema;
        m_threshold = m_thresh_ema;
    }
}

//+------------------------------------------------------------------+
//| Windowed OBV: Rolling sum of signed volume over last N bars       |
//| Eliminates infinite accumulation lag of traditional OBV           |
//+------------------------------------------------------------------+
double ObvMacd::CalcWindowedOBV(const NX_BarData* bars, int bar_count, int shift)
{
    double obv_sum = 0.0;
    int lookback = std::min(m_obv_window, bar_count - shift - 1);

    for (int j = 0; j < lookback; j++) {
        int idx = shift + j;
        if (idx + 1 >= bar_count) break;

        int64_t vol = bars[idx].volume;
        double delta;

        if (bars[idx].close > bars[idx + 1].close) {
            delta = (double)vol;
        } else if (bars[idx].close < bars[idx + 1].close) {
            delta = -(double)vol;
        } else {
            delta = 0.0;
        }

        obv_sum += delta;
    }

    return obv_sum;
}
