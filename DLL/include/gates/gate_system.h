//+------------------------------------------------------------------+
//|                       gate_system.h                               |
//|              Nexus V3 - Gate System Orchestrator                   |
//+------------------------------------------------------------------+
#ifndef NEXUS_GATE_SYSTEM_H
#define NEXUS_GATE_SYSTEM_H

#include "../nexus_types.h"
#include "../nexus_config.h"
#include "../nexus_logger.h"
#include "../engine/state_machine.h"
#include "../indicators/gg_trendbar.h"
#include "../indicators/trend_magic.h"
#include "../indicators/obv_macd.h"
#include "../indicators/rsi_oma.h"
#include "gate_definitions.h"

class GateSystem {
public:
    GateSystem();

    void Init(NexusConfig* config, NexusLogger* logger, StateMachine* state);

    // Calculate all indicators and process all 6 gates
    // Returns action (NONE/BUY/SELL) and fills result struct
    int ProcessAllGates(
        const NX_BarData* bars, int bar_count,
        const NX_BarData* bars_m1, int m1_count,
        const NX_BarData* bars_m2, int m2_count,
        const NX_BarData* bars_m3, int m3_count,
        NX_TickResult* result
    );

    // Access indicators (for position management)
    GGTrendBar*       GetGG() { return &m_gg; }
    TrendMagic*       GetTM() { return &m_tm; }
    ObvMacd*          GetMACD() { return &m_macd; }
    RsiOma*           GetRSI() { return &m_rsi; }
    // CS removed — Gate 5 now uses TrendMagic ER + OBV MACD for trend quality

private:
    NexusConfig*  m_config;
    NexusLogger*  m_logger;
    StateMachine* m_state;

    // Indicators
    GGTrendBar       m_gg;
    TrendMagic       m_tm;
    ObvMacd          m_macd;
    RsiOma           m_rsi;

    // Gate instances
    Gate1_Market     m_gate1;
    Gate2_MTF        m_gate2;
    Gate3_Supertrend m_gate3;
    Gate4_Momentum   m_gate4;
    Gate5_Context    m_gate5;

    // Calculate all indicators from bar data
    void CalculateIndicators(
        const NX_BarData* bars, int bar_count,
        const NX_BarData* bars_m1, int m1_count,
        const NX_BarData* bars_m2, int m2_count,
        const NX_BarData* bars_m3, int m3_count
    );

    // Check signal profiles (enabled in config)
    bool IsProfileEnabled(NX_SignalDirection dir, NX_SignalClass cls);
};

#endif // NEXUS_GATE_SYSTEM_H
