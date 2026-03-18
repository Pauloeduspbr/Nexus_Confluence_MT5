//+------------------------------------------------------------------+
//|                         obv_macd.h                                |
//|              Nexus V3 - OBV MACD v4 (Windowed OBV)               |
//+------------------------------------------------------------------+
#ifndef NEXUS_OBV_MACD_H
#define NEXUS_OBV_MACD_H

#include "indicator_base.h"

class ObvMacd {
public:
    ObvMacd();

    void Init(int fast_ema, int slow_ema, int signal_sma,
              int obv_window, bool use_tick_vol,
              int thresh_period, double thresh_mult);

    // Calculate OBV MACD on bar data
    // Needs multiple bars for proper calculation
    void Calculate(const NX_BarData* bars, int bar_count);

    // Results
    double GetHistogram() const { return m_histogram; }
    double GetHistogramPrev() const { return m_histogram_prev; }
    double GetThreshold() const { return m_threshold; }
    double GetMACDLine() const { return m_macd_line; }
    double GetSignalLine() const { return m_signal_line; }

    // Is momentum expanding? |histogram| > threshold
    bool IsMomentumExpanding() const {
        return fabs(m_histogram) > m_threshold;
    }

    // Direction: +1 bullish, -1 bearish, 0 neutral
    int GetDirection() const {
        if (!IsMomentumExpanding()) return 0;
        return (m_histogram > 0) ? 1 : -1;
    }

    // Is histogram growing in magnitude?
    bool IsHistogramGrowing() const {
        return fabs(m_histogram) > fabs(m_histogram_prev);
    }

private:
    // Parameters
    int    m_fast_period;
    int    m_slow_period;
    int    m_signal_period;
    int    m_obv_window;
    bool   m_use_tick_vol;
    int    m_thresh_period;
    double m_thresh_mult;

    // State
    double m_fast_ema;
    double m_slow_ema;
    double m_signal_line;
    double m_macd_line;
    double m_histogram;
    double m_histogram_prev;
    double m_threshold;
    double m_thresh_ema;
    bool   m_first_calc;

    // Internal
    double CalcWindowedOBV(const NX_BarData* bars, int bar_count, int shift);
};

#endif // NEXUS_OBV_MACD_H
