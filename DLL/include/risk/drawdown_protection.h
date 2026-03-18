//+------------------------------------------------------------------+
//|                    drawdown_protection.h                          |
//|              Nexus Confluence V3 - Drawdown / Circuit Breaker      |
//+------------------------------------------------------------------+
#ifndef NEXUS_DRAWDOWN_PROTECTION_H
#define NEXUS_DRAWDOWN_PROTECTION_H

#include "../nexus_types.h"
#include "../nexus_config.h"
#include "../nexus_logger.h"
#include <cmath>
#include <cstdio>
#include <cstring>

class DrawdownProtection {
public:
    DrawdownProtection()
        : m_config(nullptr)
        , m_logger(nullptr)
        , m_consec_losses(0)
        , m_daily_loss(0.0)
        , m_daily_start_balance(0.0)
        , m_current_day(0)
        , m_circuit_breaker_active(false)
        , m_lot_reduction_active(false)
    {}

    void Init(NexusConfig* config, NexusLogger* logger) {
        m_config = config;
        m_logger = logger;
        Reset();
    }

    void Reset() {
        m_consec_losses = 0;
        m_daily_loss = 0.0;
        m_circuit_breaker_active = false;
        m_lot_reduction_active = false;
    }

    // Called when a trade closes
    void OnTradeResult(bool is_win, double profit_loss) {
        if (!m_config) return;
        const NX_Config& cfg = m_config->GetConfig();
        if (!cfg.dd_enable) return;

        if (is_win) {
            m_consec_losses = 0;
            m_lot_reduction_active = false;
        } else {
            m_consec_losses++;
            m_daily_loss += fabs(profit_loss);

            m_logger->Operational("[DD] Loss #%d | Daily loss: %.2f",
                m_consec_losses, m_daily_loss);

            // Check consecutive loss limit
            if (cfg.dd_consec_loss > 0 && m_consec_losses >= cfg.dd_consec_loss) {
                m_lot_reduction_active = true;
                m_logger->Executive("[DD] Consecutive losses=%d >= limit=%d -> Lot reduction active",
                    m_consec_losses, cfg.dd_consec_loss);
            }

            // Check daily max drawdown
            if (cfg.dd_daily_max > 0 && m_daily_start_balance > 0) {
                double dd_pct = (m_daily_loss / m_daily_start_balance) * 100.0;
                if (dd_pct >= cfg.dd_daily_max) {
                    m_circuit_breaker_active = true;
                    m_logger->Executive("[DD] CIRCUIT BREAKER: Daily DD %.2f%% >= Max %.2f%%",
                        dd_pct, cfg.dd_daily_max);
                }
            }
        }
    }

    // Called at start of new day (from MQL5 via bar timestamp)
    void OnNewDay(int day_number, double balance) {
        if (day_number != m_current_day) {
            m_current_day = day_number;
            m_daily_loss = 0.0;
            m_daily_start_balance = balance;
            m_circuit_breaker_active = false;
            m_logger->Debug("[DD] New day: balance=%.2f", balance);
        }
    }

    // Check if trading is allowed
    bool IsCircuitBreakerActive() const { return m_circuit_breaker_active; }

    // Get adjusted lot size
    double GetAdjustedLot() const {
        if (!m_config) return 0.01;
        const NX_Config& cfg = m_config->GetConfig();
        double lot = cfg.lot_size;

        if (m_lot_reduction_active && cfg.dd_lot_reduce > 0 && cfg.dd_lot_reduce < 1.0) {
            lot *= cfg.dd_lot_reduce;
            lot = m_config->NormalizeLot(lot);
        }

        return lot;
    }

    // Fill manage result with DD info
    void FillResult(NX_ManageResult* result) const {
        if (!result) return;
        result->circuit_breaker = m_circuit_breaker_active ? 1 : 0;
        result->adjusted_lot = GetAdjustedLot();

        if (m_circuit_breaker_active) {
            result->action = NX_MANAGE_CIRCUIT_BREAK;
            snprintf(result->reason, NX_MAX_REASON_LEN,
                "Circuit breaker: daily loss limit reached");
        }
    }

    int GetConsecLosses() const { return m_consec_losses; }
    double GetDailyLoss() const { return m_daily_loss; }

private:
    NexusConfig* m_config;
    NexusLogger* m_logger;
    int    m_consec_losses;
    double m_daily_loss;
    double m_daily_start_balance;
    int    m_current_day;
    bool   m_circuit_breaker_active;
    bool   m_lot_reduction_active;
};

#endif // NEXUS_DRAWDOWN_PROTECTION_H
