//+------------------------------------------------------------------+
//|                       trailing_stop.h                             |
//|                  Nexus Confluence V3 - Trailing Stop Manager       |
//+------------------------------------------------------------------+
#ifndef NEXUS_TRAILING_STOP_H
#define NEXUS_TRAILING_STOP_H

#include "../nexus_types.h"
#include "../nexus_config.h"
#include "../nexus_logger.h"
#include <cmath>

class TrailingStopManager {
public:
    TrailingStopManager() : m_config(nullptr), m_logger(nullptr) {}

    void Init(NexusConfig* config, NexusLogger* logger) {
        m_config = config;
        m_logger = logger;
    }

    // Check if trailing stop should be applied
    // Returns true if SL should be modified, sets new_sl
    bool Check(const NX_PositionInfo* pos, double &new_sl) {
        if (!m_config || !pos) return false;

        const NX_Config& cfg = m_config->GetConfig();
        bool is_buy = (pos->type == 0);

        bool ts_enabled = is_buy ? cfg.ts_buy_enable : cfg.ts_sell_enable;
        if (!ts_enabled) return false;

        int trigger_steps = m_config->GetTSTriggerSteps(is_buy ? NX_DIR_BUY : NX_DIR_SELL);
        int step_steps    = m_config->GetTSStepSteps(is_buy ? NX_DIR_BUY : NX_DIR_SELL);
        double price_step = m_config->GetPriceStep();

        if (trigger_steps <= 0 || step_steps <= 0 || price_step <= 0) return false;

        int profit_steps = pos->profit_steps;

        // Check if profit exceeds trigger
        if (profit_steps < trigger_steps) return false;

        // Calculate trailing SL
        double trail_sl;
        if (is_buy) {
            // For BUY: SL trails below current price by step_steps
            trail_sl = pos->current_price - (step_steps * price_step);
            // Only move SL up, never down
            if (pos->current_sl >= trail_sl) return false;
        } else {
            // For SELL: SL trails above current price by step_steps
            trail_sl = pos->current_price + (step_steps * price_step);
            // Only move SL down, never up
            if (pos->current_sl > 0 && pos->current_sl <= trail_sl) return false;
        }

        // Ensure trail SL is at least at entry (don't go negative)
        if (is_buy && trail_sl < pos->entry_price) return false;
        if (!is_buy && trail_sl > pos->entry_price) return false;

        new_sl = m_config->NormalizePrice(trail_sl);

        m_logger->Operational("[TS] %s Ticket=%lld Profit=%d steps | Price=%.5f NewSL=%.5f (trail %d steps)",
            is_buy ? "BUY" : "SELL",
            (long long)pos->ticket, profit_steps,
            pos->current_price, new_sl, step_steps);

        return true;
    }

private:
    NexusConfig* m_config;
    NexusLogger* m_logger;
};

#endif // NEXUS_TRAILING_STOP_H
