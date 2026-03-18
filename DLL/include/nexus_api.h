//+------------------------------------------------------------------+
//|                          nexus_api.h                              |
//|                  Nexus Confluence V3 - Public API                  |
//|                     Copyright 2024-2026, Nexus EA                 |
//+------------------------------------------------------------------+
#ifndef NEXUS_API_H
#define NEXUS_API_H

#include "nexus_types.h"

#ifdef __cplusplus
extern "C" {
#endif

//+------------------------------------------------------------------+
//| Lifecycle                                                         |
//+------------------------------------------------------------------+

// Initialize the engine with config and symbol info
// Returns: NX_OK on success, error code on failure
NEXUS_API int NEXUS_CALL NX_Init(
    const NX_Config* config,
    const NX_SymbolInfo* symbol
);

// Shutdown and release all resources
NEXUS_API void NEXUS_CALL NX_Deinit(void);

//+------------------------------------------------------------------+
//| Tick Processing                                                   |
//+------------------------------------------------------------------+

// Process a new candle (called by MQL5 OnTick when new bar detected)
// Runs all 6 gates and returns signal decision
//
// bars          = OHLCV array for operational TF (shift=1, latest first)
// bar_count     = number of bars in operational array
// bars_macro1-3 = OHLCV arrays for macro timeframes
// macro1-3_count= bar counts for each macro TF
// current_symbol= updated symbol info (spread, bid, ask)
// result        = output: action, signal class, SL/TP, logs
//
// Returns: NX_OK on success, error code on failure
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
    NX_TickResult* result
);

//+------------------------------------------------------------------+
//| Position Management                                               |
//+------------------------------------------------------------------+

// Check and apply BE/TS/DD on an open position
// Called by MQL5 for each open position (OnTimer or OnTick)
//
// position = current position data from MT5
// result   = output: action (NONE, MODIFY_SL, CLOSE, CIRCUIT_BREAK)
//
// Returns: NX_OK on success
NEXUS_API int NEXUS_CALL NX_ManagePosition(
    const NX_PositionInfo* position,
    NX_ManageResult* result
);

// Notify DLL about trade result (for DD tracking)
NEXUS_API void NEXUS_CALL NX_OnTradeResult(
    int is_win,            // 1=win, 0=loss
    double profit_loss,    // P&L in account currency
    int remaining_positions // positions still open after this close
);

//+------------------------------------------------------------------+
//| Utilities                                                         |
//+------------------------------------------------------------------+

// Get DLL version number (MAJOR*10000 + MINOR*100 + BUILD)
NEXUS_API int NEXUS_CALL NX_GetVersion(void);

// Get last error message
// Returns: error code, fills buffer with message
NEXUS_API int NEXUS_CALL NX_GetLastError(
    char* buffer,
    int buffer_size
);

// Reset engine state (force IDLE, clear counters)
NEXUS_API void NEXUS_CALL NX_ResetState(void);

// Get current engine state (NX_EAState enum)
NEXUS_API int NEXUS_CALL NX_GetState(void);

#ifdef __cplusplus
}
#endif

#endif // NEXUS_API_H
