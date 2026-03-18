//+------------------------------------------------------------------+
//|                      indicator_base.h                             |
//|                  Nexus Confluence V3 - Indicator Interface         |
//+------------------------------------------------------------------+
#ifndef NEXUS_INDICATOR_BASE_H
#define NEXUS_INDICATOR_BASE_H

#include "../nexus_types.h"
#include <cstring>
#include <algorithm>
#include <cmath>

// Common math utilities for indicators
namespace NXMath {

    // Exponential Moving Average (single step)
    inline double EMA(double current, double prev, int period) {
        double alpha = 2.0 / (period + 1.0);
        return alpha * current + (1.0 - alpha) * prev;
    }

    // Simple Moving Average over array segment
    inline double SMA(const double* data, int start, int period) {
        double sum = 0.0;
        for (int i = 0; i < period; i++) {
            sum += data[start + i];
        }
        return sum / period;
    }

    // Smoothed Moving Average (single step)
    inline double SMMA(double current, double prev, int period) {
        return (prev * (period - 1) + current) / period;
    }

    // Linear Weighted Moving Average
    inline double LWMA(const double* data, int start, int period) {
        double weighted_sum = 0.0;
        double weight_total = 0.0;
        for (int i = 0; i < period; i++) {
            double weight = (double)(period - i);
            weighted_sum += data[start + i] * weight;
            weight_total += weight;
        }
        return (weight_total > 0) ? weighted_sum / weight_total : 0.0;
    }

    // Calculate MA by method
    inline double CalcMA(const double* data, int pos, int period, int method) {
        switch (method) {
            case NX_MA_EMA: {
                // For EMA, we need the previous value - use SMA as seed
                // This function should be called iteratively
                return SMA(data, pos, period);
            }
            case NX_MA_SMMA: return SMA(data, pos, period); // seed
            case NX_MA_LWMA: return LWMA(data, pos, period);
            default:         return SMA(data, pos, period);
        }
    }

    // True Range
    inline double TrueRange(double high, double low, double prev_close) {
        double hl = high - low;
        double hc = fabs(high - prev_close);
        double lc = fabs(low - prev_close);
        return fmax(hl, fmax(hc, lc));
    }

    // Clamp value to range
    inline double Clamp(double val, double min_val, double max_val) {
        return fmax(min_val, fmin(max_val, val));
    }

    // RSI calculation from gains/losses arrays
    inline double RSI(double avg_gain, double avg_loss) {
        if (avg_loss < 1e-10) return 100.0;
        double rs = avg_gain / avg_loss;
        return 100.0 - (100.0 / (1.0 + rs));
    }
}

// Base class for bar data access
// Bars are passed as arrays with index 0 = most recent (shift=1 from MQL5)
class BarDataAccess {
public:
    void SetBars(const NX_BarData* bars, int count) {
        m_bars = bars;
        m_count = count;
    }

    int BarCount() const { return m_count; }

    double Open(int shift) const {
        return (shift >= 0 && shift < m_count) ? m_bars[shift].open : 0.0;
    }
    double High(int shift) const {
        return (shift >= 0 && shift < m_count) ? m_bars[shift].high : 0.0;
    }
    double Low(int shift) const {
        return (shift >= 0 && shift < m_count) ? m_bars[shift].low : 0.0;
    }
    double Close(int shift) const {
        return (shift >= 0 && shift < m_count) ? m_bars[shift].close : 0.0;
    }
    int64_t Volume(int shift) const {
        return (shift >= 0 && shift < m_count) ? m_bars[shift].volume : 0;
    }
    int64_t Time(int shift) const {
        return (shift >= 0 && shift < m_count) ? m_bars[shift].time : 0;
    }

protected:
    const NX_BarData* m_bars = nullptr;
    int m_count = 0;
};

#endif // NEXUS_INDICATOR_BASE_H
