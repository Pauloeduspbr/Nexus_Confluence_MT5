//+------------------------------------------------------------------+
//|                          nexus_api.cpp                            |
//|                  Nexus Confluence V3 - API Implementation          |
//+------------------------------------------------------------------+
#ifndef NEXUS_DLL_EXPORTS
#define NEXUS_DLL_EXPORTS
#endif

#include "../include/nexus_api.h"
#include "../include/nexus_config.h"
#include "../include/nexus_logger.h"
#include "../include/engine/state_machine.h"
#include "../include/gates/gate_system.h"
#include "../include/risk/break_even.h"
#include "../include/risk/trailing_stop.h"
#include "../include/risk/drawdown_protection.h"

#include <cstring>
#include <cstdio>

//+------------------------------------------------------------------+
//| Global Engine State                                               |
//+------------------------------------------------------------------+
static NexusConfig         g_config;
static NexusLogger         g_logger;
static StateMachine        g_state;
static GateSystem          g_gates;
static BreakEvenManager    g_break_even;
static TrailingStopManager g_trailing_stop;
static DrawdownProtection  g_dd_protection;
static char                g_last_error[NX_MAX_LOG_LEN] = {0};
static bool                g_initialized = false;

static void SetError(const char* format, ...) {
    va_list args;
    va_start(args, format);
    vsnprintf(g_last_error, NX_MAX_LOG_LEN - 1, format, args);
    va_end(args);
    g_last_error[NX_MAX_LOG_LEN - 1] = '\0';
}

//+------------------------------------------------------------------+
//| DLL Entry Point                                                   |
//+------------------------------------------------------------------+
#ifdef _WIN32
#include <windows.h>
BOOL APIENTRY DllMain(HMODULE hModule, DWORD reason, LPVOID lpReserved) {
    switch (reason) {
        case DLL_PROCESS_ATTACH:
        case DLL_THREAD_ATTACH:
        case DLL_THREAD_DETACH:
        case DLL_PROCESS_DETACH:
            break;
    }
    return TRUE;
}
#endif

//+------------------------------------------------------------------+
//| API Implementation                                                |
//+------------------------------------------------------------------+

NEXUS_API int NEXUS_CALL NX_Init(
    const NX_Config* config,
    const NX_SymbolInfo* symbol)
{
    if (g_initialized) {
        SetError("Engine already initialized. Call NX_Deinit() first.");
        return NX_ERR_ALREADY_INIT;
    }

    if (!config || !symbol) {
        SetError("Invalid config or symbol pointer (null).");
        return NX_ERR_INVALID_CONFIG;
    }

    // Initialize config (validates and converts units)
    if (!g_config.Init(config, symbol)) {
        SetError("Configuration validation failed. Check SL/TP/BE/TS parameters.");
        return NX_ERR_INVALID_CONFIG;
    }

    // Initialize logger
    g_logger.SetLevel(config->log_level);

    // Initialize state machine (with cooldown + multi-position config)
    int max_pos = (config->max_positions > 0) ? config->max_positions : 1;
    g_state.Init(&g_logger, config->cooldown_enable, config->cooldown_candles, max_pos);

    // Initialize gate system (indicators + gates)
    g_gates.Init(&g_config, &g_logger, &g_state);

    // Initialize risk management
    g_break_even.Init(&g_config, &g_logger);
    g_trailing_stop.Init(&g_config, &g_logger);
    g_dd_protection.Init(&g_config, &g_logger);

    g_logger.Executive("Nexus Confluence V3 initialized. Symbol: %s | Market: %d | Version: %d",
        symbol->symbol,
        (int)g_config.GetMarketType(),
        NEXUS_VERSION);

    g_logger.Operational("Config: SL_Buy=%d TP_Buy=%d SL_Sell=%d TP_Sell=%d MinScore_Buy=%d MinScore_Sell=%d",
        config->sl_buy, config->tp_buy,
        config->sl_sell, config->tp_sell,
        config->min_score_buy, config->min_score_sell);

    g_initialized = true;
    return NX_OK;
}

NEXUS_API void NEXUS_CALL NX_Deinit(void)
{
    if (g_initialized) {
        g_logger.Executive("Nexus Confluence V3 shutting down.");
    }
    g_initialized = false;
    g_state.Reset();
    g_dd_protection.Reset();
    memset(g_last_error, 0, sizeof(g_last_error));
}

NEXUS_API int NEXUS_CALL NX_OnTick(
    const NX_BarData* bars,
    int bar_count,
    const NX_BarData* bars_macro1,
    int macro1_count,
    const NX_BarData* bars_macro2,
    int macro2_count,
    const NX_BarData* bars_macro3,
    int macro3_count,
    const NX_SymbolInfo* current_symbol,
    const NX_PositionContext* pos_ctx,
    NX_TickResult* result)
{
    if (!g_initialized) {
        SetError("Engine not initialized.");
        return NX_ERR_NOT_INITIALIZED;
    }

    if (!bars || bar_count < 2 || !result || !pos_ctx) {
        SetError("Invalid bars data, pos_ctx, or result pointer.");
        return NX_ERR_INVALID_DATA;
    }

    // Clear result
    memset(result, 0, sizeof(NX_TickResult));

    // Update symbol info (spread, bid, ask)
    g_config.UpdateSymbol(current_symbol);

    // Clear logger for this tick
    g_logger.ClearBuffer();

    // Gate 0: New candle check
    int64_t bar_time = bars[0].time;
    if (!g_state.IsNewCandle(bar_time)) {
        // Same candle, no processing needed
        result->action = NX_DIR_NONE;
        return NX_OK;
    }

    // Check if we can process signals (multi-position aware)
    if (!g_state.CanProcessSignal(pos_ctx->open_count)) {
        g_logger.Debug("Max positions reached (%d/%d) or error state. State: %s",
            pos_ctx->open_count, g_config.GetConfig().max_positions,
            StateMachine::StateToString(g_state.GetState()));
        result->action = NX_DIR_NONE;
        g_logger.AppendToBuffer(result->log_message, NX_MAX_LOG_LEN);
        return NX_OK;
    }

    // Check one-trade-per-candle rule
    if (!g_state.CanTradeOnCandle(bar_time)) {
        g_logger.Debug("Already traded on this candle.");
        result->action = NX_DIR_NONE;
        g_logger.AppendToBuffer(result->log_message, NX_MAX_LOG_LEN);
        return NX_OK;
    }

    // Check drawdown circuit breaker
    if (g_dd_protection.IsCircuitBreakerActive()) {
        g_logger.Executive("Circuit breaker active - no new trades");
        result->action = NX_DIR_NONE;
        result->lot_size = g_dd_protection.GetAdjustedLot();
        g_logger.AppendToBuffer(result->log_message, NX_MAX_LOG_LEN);
        return NX_OK;
    }

    // Process all 6 gates via GateSystem
    int gate_result = g_gates.ProcessAllGates(
        bars, bar_count,
        bars_macro1, macro1_count,
        bars_macro2, macro2_count,
        bars_macro3, macro3_count,
        result
    );

    // Post-gate: check direction compatibility with open positions
    if (result->action != NX_DIR_NONE && pos_ctx->open_count > 0) {
        if (!g_state.IsDirectionCompatible(result->action, pos_ctx->open_direction)) {
            g_logger.Operational("Signal %s rejected: open positions are %s (no hedging)",
                (result->action == NX_DIR_BUY) ? "BUY" : "SELL",
                (pos_ctx->open_direction == NX_DIR_BUY) ? "BUY" : "SELL");
            result->action = NX_DIR_NONE;
            g_logger.AppendToBuffer(result->log_message, NX_MAX_LOG_LEN);
            return NX_OK;
        }
    }

    // Apply DD-adjusted lot size + multi-position lot scaling
    if (result->action != NX_DIR_NONE) {
        double base_lot = g_dd_protection.GetAdjustedLot();

        // Lot scaling: pos1 = base, pos2 = base*factor, pos3 = base*factor^2
        if (pos_ctx->open_count > 0) {
            double scale = g_config.GetConfig().lot_scale_factor;
            if (scale > 0.0 && scale < 1.0) {
                for (int i = 0; i < pos_ctx->open_count; i++)
                    base_lot *= scale;
                base_lot = g_config.NormalizeLot(base_lot);
                g_logger.Operational("Lot scaled: pos #%d -> %.4f (factor=%.2f)",
                    pos_ctx->open_count + 1, base_lot, scale);
            }
        }
        result->lot_size = base_lot;

        // Update state machine on signal (store direction for cooldown tracking)
        g_state.OnSignalDetected();
        g_state.OnOrderSent(bar_time, result->action);
    }

    // Fill log buffer into result
    g_logger.AppendToBuffer(result->log_message, NX_MAX_LOG_LEN);

    return gate_result;
}

NEXUS_API int NEXUS_CALL NX_ManagePosition(
    const NX_PositionInfo* position,
    NX_ManageResult* result)
{
    if (!g_initialized) return NX_ERR_NOT_INITIALIZED;
    if (!position || !result) return NX_ERR_INVALID_DATA;

    // Clear result
    memset(result, 0, sizeof(NX_ManageResult));
    result->action = NX_MANAGE_NONE;
    result->adjusted_lot = g_dd_protection.GetAdjustedLot();

    // Check circuit breaker first
    if (g_dd_protection.IsCircuitBreakerActive()) {
        g_dd_protection.FillResult(result);
        return NX_OK;
    }

    // Check trailing stop (higher priority than break even)
    double new_sl = 0.0;
    if (g_trailing_stop.Check(position, new_sl)) {
        result->action = NX_MANAGE_MODIFY_SL;
        result->new_sl = new_sl;
        snprintf(result->reason, NX_MAX_REASON_LEN,
            "Trailing Stop: new SL=%.5f", new_sl);
        return NX_OK;
    }

    // Check break even
    if (g_break_even.Check(position, new_sl)) {
        result->action = NX_MANAGE_MODIFY_SL;
        result->new_sl = new_sl;
        snprintf(result->reason, NX_MAX_REASON_LEN,
            "Break Even: new SL=%.5f", new_sl);
        return NX_OK;
    }

    return NX_OK;
}

NEXUS_API void NEXUS_CALL NX_OnTradeResult(
    int is_win,
    double profit_loss,
    int remaining_positions)
{
    if (!g_initialized) return;

    // Activate directional cooldown on loss BEFORE resetting state
    if (!is_win) {
        int last_dir = g_state.GetLastTradeDirection();
        g_state.OnLoss(last_dir);
    }

    g_logger.Executive("Trade result: %s | P&L: %.2f | Remaining: %d",
        is_win ? "WIN" : "LOSS", profit_loss, remaining_positions);

    // Only reset state to IDLE when ALL positions are closed
    if (remaining_positions <= 0) {
        if (g_state.GetState() == NX_STATE_ORDER_SENT ||
            g_state.GetState() == NX_STATE_WAITING_CLOSE) {
            g_state.OnPositionClosed();
        }
    }

    // Forward to DrawdownProtection
    g_dd_protection.OnTradeResult(is_win != 0, profit_loss);
}

NEXUS_API int NEXUS_CALL NX_GetVersion(void)
{
    return NEXUS_VERSION;
}

NEXUS_API int NEXUS_CALL NX_GetLastError(char* buffer, int buffer_size)
{
    if (buffer && buffer_size > 0) {
        strncpy(buffer, g_last_error, buffer_size - 1);
        buffer[buffer_size - 1] = '\0';
    }
    return (g_last_error[0] != '\0') ? NX_ERR_INTERNAL : NX_OK;
}

NEXUS_API void NEXUS_CALL NX_ResetState(void)
{
    if (g_initialized) {
        g_state.Reset();
        g_logger.Executive("Engine state reset to IDLE.");
    }
}

NEXUS_API int NEXUS_CALL NX_GetState(void)
{
    return g_initialized ? (int)g_state.GetState() : (int)NX_STATE_IDLE;
}

