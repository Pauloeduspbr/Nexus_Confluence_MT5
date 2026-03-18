//+------------------------------------------------------------------+
//|                         nexus_config.h                            |
//|                  Nexus Confluence V3 - Configuration               |
//+------------------------------------------------------------------+
#ifndef NEXUS_CONFIG_H
#define NEXUS_CONFIG_H

#include "nexus_types.h"
#include <cstring>
#include <cmath>

class NexusConfig {
public:
    NexusConfig() : m_market_type(NX_MARKET_UNKNOWN), m_initialized(false) {
        memset(&m_config, 0, sizeof(NX_Config));
        memset(&m_symbol, 0, sizeof(NX_SymbolInfo));
    }

    // Initialize from MQL5 config struct
    bool Init(const NX_Config* config, const NX_SymbolInfo* symbol) {
        if (!config || !symbol) return false;

        memcpy(&m_config, config, sizeof(NX_Config));
        memcpy(&m_symbol, symbol, sizeof(NX_SymbolInfo));

        m_market_type = DetectMarketType();
        m_use_tick_size = (m_symbol.tick_size > m_symbol.point);
        m_price_step = m_use_tick_size ? m_symbol.tick_size : m_symbol.point;

        // Convert input points to steps
        ConvertToSteps();

        m_initialized = true;
        return Validate();
    }

    // Update symbol info (called each tick)
    void UpdateSymbol(const NX_SymbolInfo* symbol) {
        if (symbol) {
            m_symbol.spread = symbol->spread;
            m_symbol.bid = symbol->bid;
            m_symbol.ask = symbol->ask;
        }
    }

    // Getters
    bool IsInitialized() const { return m_initialized; }
    const NX_Config& GetConfig() const { return m_config; }
    const NX_SymbolInfo& GetSymbol() const { return m_symbol; }
    NX_MarketType GetMarketType() const { return m_market_type; }
    double GetPriceStep() const { return m_price_step; }
    bool UseTickSize() const { return m_use_tick_size; }

    // Converted values (in steps)
    int GetSLSteps(int direction) const {
        return (direction == NX_DIR_BUY) ? m_sl_buy_steps : m_sl_sell_steps;
    }
    int GetTPSteps(int direction) const {
        return (direction == NX_DIR_BUY) ? m_tp_buy_steps : m_tp_sell_steps;
    }
    int GetBETriggerSteps(int direction) const {
        return (direction == NX_DIR_BUY) ? m_be_buy_trigger_steps : m_be_sell_trigger_steps;
    }
    int GetBEStepSteps(int direction) const {
        return (direction == NX_DIR_BUY) ? m_be_buy_step_steps : m_be_sell_step_steps;
    }
    int GetTSTriggerSteps(int direction) const {
        return (direction == NX_DIR_BUY) ? m_ts_buy_trigger_steps : m_ts_sell_trigger_steps;
    }
    int GetTSStepSteps(int direction) const {
        return (direction == NX_DIR_BUY) ? m_ts_buy_step_steps : m_ts_sell_step_steps;
    }

    // Normalize price to symbol precision
    double NormalizePrice(double price) const {
        if (m_use_tick_size && m_symbol.tick_size > 0) {
            return round(price / m_symbol.tick_size) * m_symbol.tick_size;
        }
        double factor = pow(10.0, m_symbol.digits);
        return round(price * factor) / factor;
    }

    // Normalize lot to symbol constraints
    double NormalizeLot(double lot) const {
        lot = fmax(m_symbol.lot_min, lot);
        lot = fmin(m_symbol.lot_max, lot);
        if (m_symbol.lot_step > 0) {
            lot = round(lot / m_symbol.lot_step) * m_symbol.lot_step;
        }
        return round(lot * 100.0) / 100.0; // 2 decimal places
    }

    // Check if Currency Strength is required for this market
    bool IsCSRequired() const {
        return (m_market_type == NX_MARKET_FOREX || m_market_type == NX_MARKET_METALS);
    }

    bool IsCSOptional() const {
        return (m_market_type == NX_MARKET_CRYPTO);
    }

    bool ShouldSkipCS() const {
        return (m_market_type == NX_MARKET_INDICES ||
                m_market_type == NX_MARKET_B3 ||
                m_market_type == NX_MARKET_UNKNOWN);
    }

private:
    NX_Config    m_config;
    NX_SymbolInfo m_symbol;
    NX_MarketType m_market_type;
    bool         m_initialized;
    bool         m_use_tick_size;
    double       m_price_step;

    // Converted values (steps)
    int m_sl_buy_steps, m_tp_buy_steps;
    int m_sl_sell_steps, m_tp_sell_steps;
    int m_be_buy_trigger_steps, m_be_buy_step_steps;
    int m_be_sell_trigger_steps, m_be_sell_step_steps;
    int m_ts_buy_trigger_steps, m_ts_buy_step_steps;
    int m_ts_sell_trigger_steps, m_ts_sell_step_steps;

    // Detect market type from symbol name
    NX_MarketType DetectMarketType() const {
        const char* sym = m_symbol.symbol;

        // B3 assets
        if (strstr(sym, "WIN") || strstr(sym, "WDO") ||
            strstr(sym, "IND") || strstr(sym, "DOL"))
            return NX_MARKET_B3;

        // Metals
        if (strstr(sym, "XAU") || strstr(sym, "XAG") ||
            strstr(sym, "GOLD") || strstr(sym, "SILVER"))
            return NX_MARKET_METALS;

        // Indices
        if (strstr(sym, "US30") || strstr(sym, "US500") ||
            strstr(sym, "NAS") || strstr(sym, "NDX") ||
            strstr(sym, "SPX") || strstr(sym, "DAX") ||
            strstr(sym, "USTEC") || strstr(sym, "US100"))
            return NX_MARKET_INDICES;

        // Crypto
        if (strstr(sym, "BTC") || strstr(sym, "ETH") ||
            strstr(sym, "LTC") || strstr(sym, "XRP"))
            return NX_MARKET_CRYPTO;

        // Default: Forex (6-char pairs like EURUSD)
        int len = (int)strlen(sym);
        if (len >= 6 && len <= 7) {
            return NX_MARKET_FOREX;
        }

        return NX_MARKET_UNKNOWN;
    }

    // Inputs are already in steps/points — assign directly (no conversion needed)
    void ConvertToSteps() {
        m_sl_buy_steps  = m_config.sl_buy;
        m_tp_buy_steps  = m_config.tp_buy;
        m_sl_sell_steps = m_config.sl_sell;
        m_tp_sell_steps = m_config.tp_sell;

        m_be_buy_trigger_steps  = m_config.be_buy_trigger;
        m_be_buy_step_steps     = m_config.be_buy_step;
        m_be_sell_trigger_steps = m_config.be_sell_trigger;
        m_be_sell_step_steps    = m_config.be_sell_step;

        m_ts_buy_trigger_steps  = m_config.ts_buy_trigger;
        m_ts_buy_step_steps     = m_config.ts_buy_step;
        m_ts_sell_trigger_steps = m_config.ts_sell_trigger;
        m_ts_sell_step_steps    = m_config.ts_sell_step;
    }

    // Validate configuration
    bool Validate() const {
        if (m_config.lot_size <= 0) return false;
        if (m_config.sl_buy <= 0 || m_config.tp_buy <= 0) return false;
        if (m_config.sl_sell <= 0 || m_config.tp_sell <= 0) return false;
        if (m_config.min_score_buy < 1 || m_config.min_score_buy > 4) return false;
        if (m_config.min_score_sell < 1 || m_config.min_score_sell > 4) return false;

        // BE: trigger must be > step
        if (m_config.be_buy_enable && m_be_buy_trigger_steps <= m_be_buy_step_steps) return false;
        if (m_config.be_sell_enable && m_be_sell_trigger_steps <= m_be_sell_step_steps) return false;

        // TS: trigger must be > step
        if (m_config.ts_buy_enable && m_ts_buy_trigger_steps <= m_ts_buy_step_steps) return false;
        if (m_config.ts_sell_enable && m_ts_sell_trigger_steps <= m_ts_sell_step_steps) return false;

        return true;
    }
};

#endif // NEXUS_CONFIG_H
