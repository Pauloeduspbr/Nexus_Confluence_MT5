//+------------------------------------------------------------------+
//|                          break_even.h                             |
//|                  Nexus Confluence V3 - Break Even Manager          |
//+------------------------------------------------------------------+
#ifndef NEXUS_BREAK_EVEN_H
#define NEXUS_BREAK_EVEN_H

#include "../nexus_types.h"
#include "../nexus_config.h"
#include "../nexus_logger.h"
#include <cmath>

class BreakEvenManager {
public:
    BreakEvenManager() : m_config(nullptr), m_logger(nullptr) {}

    void Init(NexusConfig* config, NexusLogger* logger) {
        m_config = config;
        m_logger = logger;
    }

    // Check if break even should be applied to position
    // Returns true if SL should be modified, sets new_sl
    bool Check(const NX_PositionInfo* pos, double &new_sl) {
        if (!m_config || !pos) return false;

        const NX_Config& cfg = m_config->GetConfig();
        bool is_buy = (pos->type == 0); // 0=BUY, 1=SELL

        // Check if BE is enabled for this direction
        bool be_enabled = is_buy ? cfg.be_buy_enable : cfg.be_sell_enable;
        if (!be_enabled) return false;

        int trigger_steps = m_config->GetBETriggerSteps(is_buy ? NX_DIR_BUY : NX_DIR_SELL);
        int step_steps    = m_config->GetBEStepSteps(is_buy ? NX_DIR_BUY : NX_DIR_SELL);
        double price_step = m_config->GetPriceStep();

        if (trigger_steps <= 0 || price_step <= 0) return false;

        // Calculate profit in steps
        int profit_steps = pos->profit_steps;

        // Check if profit exceeds trigger
        if (profit_steps < trigger_steps) return false;

        // Calculate new SL at entry + step
        double be_sl;
        if (is_buy) {
            be_sl = pos->entry_price + (step_steps * price_step);
            // Only modify if new SL is better than current
            if (pos->current_sl >= be_sl) return false;
        } else {
            be_sl = pos->entry_price - (step_steps * price_step);
            // For sell, lower SL is better
            if (pos->current_sl > 0 && pos->current_sl <= be_sl) return false;
        }

        // Normalize price
        new_sl = m_config->NormalizePrice(be_sl);

        m_logger->Operational("[BE] %s Ticket=%lld Profit=%d steps >= Trigger=%d | NewSL=%.5f (entry %.5f + %d steps)",
            is_buy ? "BUY" : "SELL",
            (long long)pos->ticket, profit_steps, trigger_steps,
            new_sl, pos->entry_price, step_steps);

        return true;
    }

private:
    NexusConfig* m_config;
    NexusLogger* m_logger;
};

#endif // NEXUS_BREAK_EVEN_H
