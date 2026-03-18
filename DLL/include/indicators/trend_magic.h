//+------------------------------------------------------------------+
//|                       trend_magic.h                               |
//|           Nexus V3 - Adaptive Supertrend (CCI+ER+TR_EMA)         |
//+------------------------------------------------------------------+
#ifndef NEXUS_TREND_MAGIC_H
#define NEXUS_TREND_MAGIC_H

#include "indicator_base.h"

// Replaces ATR with Kaufman Efficiency Ratio + True Range EMA
// Adaptive bands: wide in ranging markets, tight in trending
class TrendMagic {
public:
    TrendMagic();

    void Init(int cci_period, int er_period, int vol_period, double band_mult, double band_trend_factor = 0.5);

    // Calculate on bar data (index 0 = most recent closed bar)
    // Returns: +1 (bullish), 0 (neutral), -1 (bearish)
    int Calculate(const NX_BarData* bars, int bar_count);

    // Get band values (after Calculate)
    double GetUpperBand() const { return m_upper_band; }
    double GetLowerBand() const { return m_lower_band; }
    double GetClosePrice() const { return m_close; }
    int    GetSignal() const { return m_signal; }

    // Expose adaptive metrics for dynamic SL and trend quality
    double GetEfficiencyRatio() const { return m_er; }
    double GetTR_EMA() const { return m_tr_ema; }
    double GetPrevEfficiencyRatio() const { return m_prev_er; }

private:
    // Parameters
    int    m_cci_period;
    int    m_er_period;
    int    m_vol_period;
    double m_band_mult;
    double m_band_trend_factor;

    // State
    double m_upper_band;
    double m_lower_band;
    double m_close;
    int    m_signal;
    double m_prev_upper;
    double m_prev_lower;
    double m_tr_ema;
    double m_er;           // current Efficiency Ratio
    double m_prev_er;      // previous ER (for decline detection)
    bool   m_first_calc;

    // Internal calculations
    double CalcCCI(const NX_BarData* bars, int bar_count, int shift);
    double CalcEfficiencyRatio(const NX_BarData* bars, int bar_count, int shift);
    double CalcTrueRange(const NX_BarData* bars, int shift);
};

#endif // NEXUS_TREND_MAGIC_H
