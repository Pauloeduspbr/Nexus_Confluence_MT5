//+------------------------------------------------------------------+
//|                        rsi_oma.cpp                                |
//|                  Nexus V3 - RSI with Moving Average               |
//+------------------------------------------------------------------+
#include "../../include/indicators/rsi_oma.h"
#include <cmath>
#include <cstring>
#include <algorithm>

RsiOma::RsiOma()
    : m_rsi_period(14)
    , m_ma_period(9)
    , m_ma_method(NX_MA_SMA)
    , m_hysteresis(0.01)
    , m_rsi_value(50.0)
    , m_ma_value(50.0)
    , m_signal(0)
    , m_avg_gain(0.0)
    , m_avg_loss(0.0)
    , m_first_calc(true)
    , m_history_idx(0)
    , m_history_count(0)
{
    memset(m_rsi_history, 0, sizeof(m_rsi_history));
}

void RsiOma::Init(int rsi_period, int ma_period, int ma_method, double hysteresis)
{
    m_rsi_period = (rsi_period > 1) ? rsi_period : 14;
    m_ma_period  = (ma_period > 1)  ? ma_period  : 9;
    m_ma_method  = ma_method;
    m_hysteresis = (hysteresis >= 0) ? hysteresis : 0.01;

    m_rsi_value = 50.0;
    m_ma_value = 50.0;
    m_signal = 0;
    m_avg_gain = 0.0;
    m_avg_loss = 0.0;
    m_first_calc = true;
    m_history_idx = 0;
    m_history_count = 0;
    memset(m_rsi_history, 0, sizeof(m_rsi_history));
}

int RsiOma::Calculate(const NX_BarData* bars, int bar_count)
{
    int min_bars = m_rsi_period + m_ma_period + 2;
    if (bar_count < min_bars) {
        m_signal = 0;
        return 0;
    }

    // Calculate RSI
    m_rsi_value = CalcRSI(bars, bar_count);

    // Store in history for MA calculation
    m_rsi_history[m_history_idx % 256] = m_rsi_value;
    m_history_idx++;
    m_history_count = std::min(m_history_count + 1, 256);

    // Calculate MA of RSI
    m_ma_value = CalcMA();

    // Determine signal: Red (RSI) vs Blue (MA)
    if (m_rsi_value > m_ma_value + m_hysteresis) {
        m_signal = 1;  // BUY: RSI above MA
    } else if (m_rsi_value < m_ma_value - m_hysteresis) {
        m_signal = -1; // SELL: RSI below MA
    } else {
        m_signal = 0;  // Neutral
    }

    return m_signal;
}

//+------------------------------------------------------------------+
//| RSI Calculation using Wilder's smoothing                          |
//+------------------------------------------------------------------+
double RsiOma::CalcRSI(const NX_BarData* bars, int bar_count)
{
    if (m_first_calc) {
        // Initial calculation: simple average of gains/losses
        double gain_sum = 0.0;
        double loss_sum = 0.0;

        // bars[0] is most recent, bars[N] is oldest
        // We need to go from old to new for proper calculation
        for (int i = m_rsi_period; i > 0; i--) {
            if (i >= bar_count) continue;
            double change = bars[i - 1].close - bars[i].close;
            if (change > 0) gain_sum += change;
            else loss_sum += fabs(change);
        }

        m_avg_gain = gain_sum / m_rsi_period;
        m_avg_loss = loss_sum / m_rsi_period;
        m_first_calc = false;
    } else {
        // Wilder's smoothing (SMMA): incremental update
        double change = bars[0].close - bars[1].close;
        double current_gain = (change > 0) ? change : 0.0;
        double current_loss = (change < 0) ? fabs(change) : 0.0;

        m_avg_gain = (m_avg_gain * (m_rsi_period - 1) + current_gain) / m_rsi_period;
        m_avg_loss = (m_avg_loss * (m_rsi_period - 1) + current_loss) / m_rsi_period;
    }

    return NXMath::RSI(m_avg_gain, m_avg_loss);
}

//+------------------------------------------------------------------+
//| Moving Average of RSI values                                      |
//+------------------------------------------------------------------+
double RsiOma::CalcMA()
{
    if (m_history_count < m_ma_period) {
        return m_rsi_value; // not enough history
    }

    // Build array of recent RSI values (newest first)
    double recent[256];
    int count = std::min(m_ma_period, m_history_count);

    for (int i = 0; i < count; i++) {
        int idx = ((m_history_idx - 1 - i) % 256 + 256) % 256;
        recent[i] = m_rsi_history[idx];
    }

    switch (m_ma_method) {
        case NX_MA_EMA: {
            // EMA: use last MA value as previous
            double alpha = 2.0 / (m_ma_period + 1.0);
            return alpha * m_rsi_value + (1.0 - alpha) * m_ma_value;
        }
        case NX_MA_SMMA: {
            return (m_ma_value * (m_ma_period - 1) + m_rsi_value) / m_ma_period;
        }
        case NX_MA_LWMA: {
            return NXMath::LWMA(recent, 0, count);
        }
        default: { // SMA
            return NXMath::SMA(recent, 0, count);
        }
    }
}
