//+------------------------------------------------------------------+
//|                         rsi_oma.h                                 |
//|                  Nexus V3 - RSI with Moving Average               |
//+------------------------------------------------------------------+
#ifndef NEXUS_RSI_OMA_H
#define NEXUS_RSI_OMA_H

#include "indicator_base.h"

class RsiOma {
public:
    RsiOma();

    void Init(int rsi_period, int ma_period, int ma_method, double hysteresis = 0.01);

    // Calculate RSI and MA on bar data
    // Returns: +1 (bullish: red > blue), 0 (neutral), -1 (bearish: red < blue)
    int Calculate(const NX_BarData* bars, int bar_count);

    double GetRSI() const { return m_rsi_value; }
    double GetMA() const { return m_ma_value; }
    int    GetSignal() const { return m_signal; }

private:
    int    m_rsi_period;
    int    m_ma_period;
    int    m_ma_method;
    double m_hysteresis;

    double m_rsi_value;   // Red line
    double m_ma_value;    // Blue line
    int    m_signal;

    // Internal state for incremental RSI
    double m_avg_gain;
    double m_avg_loss;
    bool   m_first_calc;

    // MA history buffer for smoothing
    double m_rsi_history[256]; // ring buffer
    int    m_history_idx;
    int    m_history_count;

    double CalcRSI(const NX_BarData* bars, int bar_count);
    double CalcMA();
};

#endif // NEXUS_RSI_OMA_H
