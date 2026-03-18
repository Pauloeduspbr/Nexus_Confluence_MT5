//+------------------------------------------------------------------+
//|                       gg_trendbar.h                               |
//|         Nexus V3 - GG TrendBar (ADX+SAR Multi-Timeframe)         |
//+------------------------------------------------------------------+
#ifndef NEXUS_GG_TRENDBAR_H
#define NEXUS_GG_TRENDBAR_H

#include "indicator_base.h"

// Maximum number of timeframes analyzed
#define GG_MAX_TFS 15

// The GG TrendBar calculates trend direction for multiple timeframes
// using ADX (directional strength) + Parabolic SAR (direction).
//
// In the DLL version, each timeframe receives its own bar data array
// from MQL5. The DLL internally computes ADX and SAR from raw OHLC.
//
// For the EA, only 4 TFs are needed (macro1, macro2, macro3, operational)
// but we keep the full 15-TF capability for completeness.

class GGTrendBar {
public:
    GGTrendBar();

    void Init(int adx_period, double psar_step, double psar_max, double di_separation = 3.0);

    // Calculate trend for a specific timeframe using its bar data
    // Returns: +1 (bullish), 0 (neutral), -1 (bearish)
    int CalculateForTF(const NX_BarData* bars, int bar_count, int tf_index);

    // Get cached result for a timeframe index
    int GetTrendSignal(int tf_index) const {
        if (tf_index >= 0 && tf_index < GG_MAX_TFS)
            return m_trend_values[tf_index];
        return 0;
    }

    // Get trend for specific MQL5 timeframe enum value
    int GetTrendByTF(int mql5_tf) const;

    // Map MQL5 timeframe enum to internal index
    static int TFToIndex(int mql5_tf);

private:
    int    m_adx_period;
    double m_psar_step;
    double m_psar_max;
    double m_di_separation;

    int    m_trend_values[GG_MAX_TFS]; // -1/0/+1 per TF

    // ADX calculation from raw OHLC
    struct ADXState {
        double plus_di;
        double minus_di;
        double adx;
        double prev_plus_dm_ema;
        double prev_minus_dm_ema;
        double prev_tr_ema;
        double prev_adx;
        bool   initialized;
        int64_t last_bar_time;  // Track last processed bar to avoid recalc
    };

    // Parabolic SAR state
    struct SARState {
        double sar;
        double ep;     // extreme point
        double af;     // acceleration factor
        bool   is_long; // true = uptrend, false = downtrend
        bool   initialized;
        int64_t last_bar_time;  // Track last processed bar to avoid recalc
    };

    ADXState m_adx_state[GG_MAX_TFS];
    SARState m_sar_state[GG_MAX_TFS];

    void CalcADX(const NX_BarData* bars, int bar_count, int tf_idx,
                 double &plus_di, double &minus_di);
    double CalcSAR(const NX_BarData* bars, int bar_count, int tf_idx);
    int DetermineTrend(double plus_di, double minus_di, double sar, double price);
};

#endif // NEXUS_GG_TRENDBAR_H
