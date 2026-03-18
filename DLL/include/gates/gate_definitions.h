//+------------------------------------------------------------------+
//|                    gate_definitions.h                              |
//|              Nexus V3 - Individual Gate Logic                      |
//+------------------------------------------------------------------+
#ifndef NEXUS_GATE_DEFINITIONS_H
#define NEXUS_GATE_DEFINITIONS_H

#include "../nexus_types.h"
#include "../nexus_config.h"
#include "../nexus_logger.h"
#include "../indicators/gg_trendbar.h"
#include "../indicators/trend_magic.h"
#include "../indicators/obv_macd.h"
#include "../indicators/rsi_oma.h"
#include <cmath>
#include <cstring>
#include <algorithm>

// Helper: convert MQL5 TF enum to readable string
static const char* TFToString(int tf) {
    switch(tf) {
        case 1:     return "M1";
        case 5:     return "M5";
        case 10:    return "M10";
        case 15:    return "M15";
        case 20:    return "M20";
        case 30:    return "M30";
        case 16385: return "H1";
        case 16386: return "H2";
        case 16387: return "H3";
        case 16388: return "H4";
        case 16390: return "H6";
        case 16392: return "H8";
        case 16396: return "H12";
        case 16408: return "D1";
        case 32769: return "W1";
        case 49153: return "MN1";
        default:    return "??";
    }
}

//+------------------------------------------------------------------+
//| Gate 1: Market Access                                             |
//+------------------------------------------------------------------+
class Gate1_Market {
public:
    void Init(NexusConfig* config, NexusLogger* logger) {
        m_config = config;
        m_logger = logger;
        m_spread_idx = 0;
        m_spread_count = 0;
        memset(m_spread_history, 0, sizeof(m_spread_history));
    }

    bool Process() {
        const NX_Config& cfg = m_config->GetConfig();
        const NX_SymbolInfo& sym = m_config->GetSymbol();

        // Check spread filter
        if (cfg.spread_filter_enable) {
            double current_spread = sym.spread;

            // Store spread history
            m_spread_history[m_spread_idx % 100] = current_spread;
            m_spread_idx++;
            m_spread_count = std::min(m_spread_count + 1, 100);

            // Absolute max spread check
            if (current_spread > cfg.max_spread) {
                m_logger->Operational("Gate 1 FAIL: Spread %.1f > Max %d",
                    current_spread, cfg.max_spread);
                return false;
            }

            // Dynamic spread: current < multiplier * median
            if (m_spread_count >= cfg.spread_period) {
                double median = CalcMedianSpread(cfg.spread_period);
                if (median > 0 && current_spread > cfg.spread_multiplier * median) {
                    m_logger->Operational("Gate 1 FAIL: Spread %.1f > %.1f * median %.1f",
                        current_spread, cfg.spread_multiplier, median);
                    return false;
                }
            }
        }

        // Check time filter
        if (cfg.use_time_filter) {
            // Note: time validation requires current server time
            // This is passed via bar timestamp
            // Simplified: check hour/minute from last bar time
            // Full implementation requires server time from MQL5
        }

        // Check day filter
        // Day-of-week validation happens via bar timestamp

        m_logger->Debug("Gate 1 PASS: Spread=%.1f", m_config->GetSymbol().spread);
        return true;
    }

private:
    NexusConfig* m_config = nullptr;
    NexusLogger* m_logger = nullptr;
    double m_spread_history[100];
    int    m_spread_idx;
    int    m_spread_count;

    double CalcMedianSpread(int period) {
        int count = std::min(period, m_spread_count);
        if (count <= 0) return 0.0;

        double sorted[100];
        int valid = 0;
        for (int i = 0; i < count; i++) {
            int idx = ((m_spread_idx - 1 - i) % 100 + 100) % 100;
            if (m_spread_history[idx] > 0) {
                sorted[valid++] = m_spread_history[idx];
            }
        }
        if (valid == 0) return 0.0;

        // Simple sort for median
        std::sort(sorted, sorted + valid);
        return sorted[valid / 2];
    }
};

//+------------------------------------------------------------------+
//| Gate 2: Multi-Timeframe Analysis                                  |
//+------------------------------------------------------------------+
class Gate2_MTF {
public:
    void Init(NexusConfig* config, NexusLogger* logger, GGTrendBar* gg) {
        m_config = config;
        m_logger = logger;
        m_gg = gg;
    }

    // Returns signal class and sets direction/score
    NX_SignalClass Process(int &out_score, NX_SignalDirection &out_direction) {
        const NX_Config& cfg = m_config->GetConfig();

        // Get GG TrendBar values for each macro TF
        int val_m1 = m_gg->GetTrendByTF(cfg.macro1_tf);   // Macro1 (mandante)
        int val_m2 = m_gg->GetTrendByTF(cfg.macro2_tf);   // Macro2 (mandante)
        int val_m3 = m_gg->GetTrendByTF(cfg.macro3_tf);   // Macro3
        int val_op = m_gg->GetTrendByTF(cfg.operational_tf); // Operational

        m_logger->Debug("Gate 2 GG Values: %s=%d %s=%d %s=%d %s=%d",
            TFToString(cfg.macro1_tf), val_m1, TFToString(cfg.macro2_tf), val_m2,
            TFToString(cfg.macro3_tf), val_m3, TFToString(cfg.operational_tf), val_op);

        // Rule 1: Macro1 MUST have a clear direction — it is the primary mandante.
        // Neutral means the higher timeframe has no conviction → no trade.
        if (val_m1 == 0) {
            m_logger->Operational("Gate 2 REJECT: %s (Macro1) neutral - no directional conviction",
                TFToString(cfg.macro1_tf));
            out_score = val_m1 + val_m2 + val_m3 + val_op;
            out_direction = NX_DIR_NONE;
            return NX_SIGNAL_REJECT;
        }

        // Rule 1b: Both macros neutral
        if (val_m2 == 0 && val_m1 == 0) {
            m_logger->Operational("Gate 2 REJECT: Both macros neutral (%s=%d, %s=%d)",
                TFToString(cfg.macro1_tf), val_m1, TFToString(cfg.macro2_tf), val_m2);
            out_score = 0;
            out_direction = NX_DIR_NONE;
            return NX_SIGNAL_REJECT;
        }

        // Determine direction from mandantes
        // Macro1 must agree with Macro2, or Macro2 can be neutral (Macro1 drives direction)
        bool macro_buy  = (val_m1 > 0 && val_m2 >= 0);
        bool macro_sell = (val_m1 < 0 && val_m2 <= 0);

        if (!macro_buy && !macro_sell) {
            m_logger->Operational("Gate 2 REJECT: Macros not aligned (%s=%d, %s=%d)",
                TFToString(cfg.macro1_tf), val_m1, TFToString(cfg.macro2_tf), val_m2);
            out_score = val_m1 + val_m2 + val_m3 + val_op;
            out_direction = NX_DIR_NONE;
            return NX_SIGNAL_REJECT;
        }

        out_direction = macro_buy ? NX_DIR_BUY : NX_DIR_SELL;

        // Rule 2: Operational TFs cannot be OPPOSITE to macros
        if ((macro_buy && val_m3 == -1) || (macro_sell && val_m3 == 1)) {
            m_logger->Operational("Gate 2 REJECT: %s (Macro3) opposite to macros",
                TFToString(cfg.macro3_tf));
            out_score = val_m1 + val_m2 + val_m3 + val_op;
            return NX_SIGNAL_REJECT;
        }
        if ((macro_buy && val_op == -1) || (macro_sell && val_op == 1)) {
            m_logger->Operational("Gate 2 REJECT: %s (OP) opposite to macros",
                TFToString(cfg.operational_tf));
            out_score = val_m1 + val_m2 + val_m3 + val_op;
            return NX_SIGNAL_REJECT;
        }

        // Calculate score
        out_score = val_m1 + val_m2 + val_m3 + val_op;

        // Check minimum score
        int abs_score = abs(out_score);
        int min_score = (out_direction == NX_DIR_BUY)
                        ? m_config->GetConfig().min_score_buy
                        : m_config->GetConfig().min_score_sell;

        if (abs_score < min_score) {
            m_logger->Operational("Gate 2 REJECT: Score %d < MinScore %d",
                out_score, min_score);
            return NX_SIGNAL_REJECT;
        }

        // Classification
        NX_SignalClass signal_class;
        if (abs_score == 4) {
            signal_class = NX_SIGNAL_PREMIUM;
        } else {
            signal_class = NX_SIGNAL_GOOD;
        }

        m_logger->Operational("Gate 2 PASS: Score=%d Class=%s Dir=%s | %s=%d %s=%d %s=%d %s=%d",
            out_score,
            (signal_class == NX_SIGNAL_PREMIUM) ? "PREMIUM" : "GOOD",
            (out_direction == NX_DIR_BUY) ? "BUY" : "SELL",
            TFToString(cfg.macro1_tf), val_m1,
            TFToString(cfg.macro2_tf), val_m2,
            TFToString(cfg.macro3_tf), val_m3,
            TFToString(cfg.operational_tf), val_op);

        return signal_class;
    }

private:
    NexusConfig*  m_config = nullptr;
    NexusLogger*  m_logger = nullptr;
    GGTrendBar*   m_gg = nullptr;
};

//+------------------------------------------------------------------+
//| Gate 3: Supertrend Confirmation                                   |
//+------------------------------------------------------------------+
class Gate3_Supertrend {
public:
    void Init(NexusLogger* logger, TrendMagic* tm) {
        m_logger = logger;
        m_tm = tm;
    }

    bool Process(NX_SignalDirection direction, NX_SignalClass signal_class) {
        int st_signal = m_tm->GetSignal();

        // ALL signals: require Supertrend to AGREE with direction.
        // Previously GOOD accepted neutral ST, giving Gate 3 a 96.4% pass rate
        // (essentially useless). Now both PREMIUM and GOOD require alignment.
        if (direction == NX_DIR_BUY && st_signal != 1) {
            m_logger->Operational("Gate 3 REJECT: BUY requires ST=+1, got %d (class=%s)",
                st_signal, (signal_class == NX_SIGNAL_PREMIUM) ? "PREMIUM" : "GOOD");
            return false;
        }
        if (direction == NX_DIR_SELL && st_signal != -1) {
            m_logger->Operational("Gate 3 REJECT: SELL requires ST=-1, got %d (class=%s)",
                st_signal, (signal_class == NX_SIGNAL_PREMIUM) ? "PREMIUM" : "GOOD");
            return false;
        }

        m_logger->Debug("Gate 3 PASS: ST=%d Dir=%d Class=%d",
            st_signal, (int)direction, (int)signal_class);
        return true;
    }

private:
    NexusLogger* m_logger = nullptr;
    TrendMagic*  m_tm = nullptr;
};

//+------------------------------------------------------------------+
//| Gate 4: Momentum (OBV MACD first, then RSI OMA)                  |
//+------------------------------------------------------------------+
class Gate4_Momentum {
public:
    void Init(NexusConfig* config, NexusLogger* logger, ObvMacd* macd, RsiOma* rsi) {
        m_config = config;
        m_logger = logger;
        m_macd = macd;
        m_rsi = rsi;
    }

    bool Process(NX_SignalDirection direction) {
        // STEP 1: OBV MACD must show expansion (FILTER)
        if (!m_macd->IsMomentumExpanding()) {
            m_logger->Operational("Gate 4 REJECT: Momentum not expanding (|hist|=%.5f <= thresh=%.5f)",
                fabs(m_macd->GetHistogram()), m_macd->GetThreshold());
            return false;
        }

        // Check MACD direction matches signal direction
        int macd_dir = m_macd->GetDirection();
        if (direction == NX_DIR_BUY && macd_dir != 1) {
            m_logger->Operational("Gate 4 REJECT: BUY but MACD direction=%d", macd_dir);
            return false;
        }
        if (direction == NX_DIR_SELL && macd_dir != -1) {
            m_logger->Operational("Gate 4 REJECT: SELL but MACD direction=%d", macd_dir);
            return false;
        }

        // STEP 2: RSI OMA must confirm direction (CONFIRMATION)
        int rsi_signal = m_rsi->GetSignal();
        double rsi_value = m_rsi->GetRSI();

        if (rsi_signal == 0) {
            m_logger->Operational("Gate 4 REJECT: RSI OMA neutral");
            return false;
        }

        if (direction == NX_DIR_BUY && rsi_signal != 1) {
            m_logger->Operational("Gate 4 REJECT: BUY but RSI signal=%d", rsi_signal);
            return false;
        }
        if (direction == NX_DIR_SELL && rsi_signal != -1) {
            m_logger->Operational("Gate 4 REJECT: SELL but RSI signal=%d", rsi_signal);
            return false;
        }

        // STEP 3: Reject entries at RSI extremes (entering too late in trend)
        const NX_Config& cfg = m_config->GetConfig();
        double rsi_ob = cfg.g4_rsi_ob;  // configurable overbought (default 75.0)
        double rsi_os = cfg.g4_rsi_os;  // configurable oversold (default 25.0)

        if (direction == NX_DIR_BUY && rsi_value > rsi_ob) {
            m_logger->Operational("Gate 4 REJECT: BUY at RSI=%.1f > OB=%.1f (overbought, late entry)", rsi_value, rsi_ob);
            return false;
        }
        if (direction == NX_DIR_SELL && rsi_value < rsi_os) {
            m_logger->Operational("Gate 4 REJECT: SELL at RSI=%.1f < OS=%.1f (oversold, late entry)", rsi_value, rsi_os);
            return false;
        }

        m_logger->Debug("Gate 4 PASS: MACD hist=%.5f thresh=%.5f dir=%d | RSI=%.2f MA=%.2f sig=%d",
            m_macd->GetHistogram(), m_macd->GetThreshold(), macd_dir,
            m_rsi->GetRSI(), m_rsi->GetMA(), rsi_signal);

        return true;
    }

private:
    NexusConfig* m_config = nullptr;
    NexusLogger* m_logger = nullptr;
    ObvMacd*     m_macd = nullptr;
    RsiOma*      m_rsi = nullptr;
};

//+------------------------------------------------------------------+
//| Gate 5: Trend Quality Filter (replaces fake Currency Strength)   |
//| Detects trend exhaustion via:                                     |
//|   1. Efficiency Ratio decline (trend losing quality)             |
//|   2. MACD histogram weakening (momentum divergence)              |
//+------------------------------------------------------------------+
class Gate5_Context {
public:
    void Init(NexusConfig* config, NexusLogger* logger,
              TrendMagic* tm, ObvMacd* macd) {
        m_config = config;
        m_logger = logger;
        m_tm = tm;
        m_macd = macd;
    }

    bool Process(NX_SignalDirection direction) {
        const NX_Config& cfg = m_config->GetConfig();
        double er      = m_tm->GetEfficiencyRatio();
        double prev_er = m_tm->GetPrevEfficiencyRatio();
        double hist    = m_macd->GetHistogram();
        double thresh  = m_macd->GetThreshold();

        double er_min     = cfg.g5_er_min;           // configurable (default 0.35)
        double er_decline = cfg.g5_er_decline;        // configurable (default 0.65)
        double mom_ratio  = cfg.g5_momentum_ratio;    // configurable (default 1.5)

        // CHECK 1: Minimum trend quality
        if (er < er_min) {
            m_logger->Operational("Gate 5 REJECT: ER=%.3f < min=%.2f (choppy/ranging)", er, er_min);
            return false;
        }

        // CHECK 2: ER declining sharply = trend exhaustion
        if (prev_er > er_min && er < prev_er * er_decline) {
            m_logger->Operational("Gate 5 REJECT: ER declining %.3f->%.3f (ratio < %.2f)",
                prev_er, er, er_decline);
            return false;
        }

        // CHECK 3: Momentum must be clearly above threshold
        double abs_hist = fabs(hist);
        if (thresh > 0 && abs_hist < thresh * mom_ratio) {
            m_logger->Operational("Gate 5 REJECT: Momentum weak |hist|=%.5f < %.1f*thresh=%.5f",
                abs_hist, mom_ratio, thresh);
            return false;
        }

        m_logger->Debug("Gate 5 PASS: ER=%.3f(min=%.2f) prevER=%.3f |hist|=%.5f thresh=%.5f(x%.1f)",
            er, er_min, prev_er, abs_hist, thresh, mom_ratio);

        return true;
    }

private:
    NexusConfig*  m_config = nullptr;
    NexusLogger*  m_logger = nullptr;
    TrendMagic*   m_tm = nullptr;
    ObvMacd*      m_macd = nullptr;
};

#endif // NEXUS_GATE_DEFINITIONS_H
