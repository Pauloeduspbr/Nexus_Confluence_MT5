//+------------------------------------------------------------------+
//|                    currency_strength.h                             |
//|              Nexus V3 - Currency Strength Meter                   |
//+------------------------------------------------------------------+
#ifndef NEXUS_CURRENCY_STRENGTH_H
#define NEXUS_CURRENCY_STRENGTH_H

#include "indicator_base.h"
#include <cstring>

class CurrencyStrength {
public:
    CurrencyStrength();

    void Init(int calc_period, int smoothing);

    // Calculate strength from bar data
    // Returns: base_strength and quote_strength in range [-100, +100]
    void Calculate(const NX_BarData* bars, int bar_count);

    double GetBaseStrength() const { return m_base_strength; }
    double GetQuoteStrength() const { return m_quote_strength; }
    bool   IsAvailable() const { return m_available; }

    // Gate 5 validation:
    // BUY:  base > quote
    // SELL: quote > base
    int GetSignal() const {
        if (!m_available) return 0;
        if (m_base_strength > m_quote_strength + 1.0) return 1;  // BUY
        if (m_quote_strength > m_base_strength + 1.0) return -1; // SELL
        return 0;
    }

private:
    int    m_calc_period;
    int    m_smoothing;

    double m_base_strength;
    double m_quote_strength;
    double m_base_smooth;
    double m_quote_smooth;
    bool   m_available;
    bool   m_first_calc;

    double CalcRSI(const NX_BarData* bars, int bar_count, int shift, int period);
    double CalcPricePosition(const NX_BarData* bars, int bar_count, int shift, int period);
    double CalcVolatility(const NX_BarData* bars, int bar_count, int shift);
};

#endif // NEXUS_CURRENCY_STRENGTH_H
