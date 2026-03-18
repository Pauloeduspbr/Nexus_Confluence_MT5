//+------------------------------------------------------------------+
//|                      gate_system.cpp                              |
//|              Nexus V3 - Gate System Orchestrator                   |
//+------------------------------------------------------------------+
#include "../../include/gates/gate_system.h"
#include <cstring>
#include <cstdio>

GateSystem::GateSystem()
    : m_config(nullptr)
    , m_logger(nullptr)
    , m_state(nullptr)
{
}

void GateSystem::Init(NexusConfig* config, NexusLogger* logger, StateMachine* state)
{
    m_config = config;
    m_logger = logger;
    m_state = state;

    const NX_Config& cfg = config->GetConfig();

    // Initialize indicators
    m_gg.Init(cfg.gg_adx_period, cfg.gg_psar_step, cfg.gg_psar_max, cfg.gg_di_separation);
    m_tm.Init(cfg.st_cci_period, cfg.st_er_period, cfg.st_volatility_period, cfg.st_band_multiplier, cfg.st_band_trend_factor);
    m_macd.Init(cfg.macd_fast, cfg.macd_slow, cfg.macd_signal,
                cfg.macd_obv_window, cfg.macd_use_tick_vol,
                cfg.macd_thresh_period, cfg.macd_thresh_mult);
    m_rsi.Init(cfg.rsi_period, cfg.rsi_ma_period, cfg.rsi_ma_method, cfg.rsi_hysteresis);
    // Initialize gates
    m_gate1.Init(config, logger);
    m_gate2.Init(config, logger, &m_gg);
    m_gate3.Init(logger, &m_tm);
    m_gate4.Init(config, logger, &m_macd, &m_rsi);
    m_gate5.Init(config, logger, &m_tm, &m_macd);

    // Pass macro flip cooldown config to state machine
    if (m_state) {
        m_state->SetMacroFlipCooldown(cfg.g5_macro_flip_cd);
    }

    m_logger->Operational("GateSystem initialized. Indicators: GG(adx=%d) TM(cci=%d,er=%d,vol=%d,mult=%.1f) MACD(%d/%d/%d) RSI(%d/%d)",
        cfg.gg_adx_period, cfg.st_cci_period, cfg.st_er_period,
        cfg.st_volatility_period, cfg.st_band_multiplier,
        cfg.macd_fast, cfg.macd_slow, cfg.macd_signal,
        cfg.rsi_period, cfg.rsi_ma_period);
}

int GateSystem::ProcessAllGates(
    const NX_BarData* bars, int bar_count,
    const NX_BarData* bars_m1, int m1_count,
    const NX_BarData* bars_m2, int m2_count,
    const NX_BarData* bars_m3, int m3_count,
    NX_TickResult* result)
{
    // Initialize gate results
    for (int i = 0; i < NX_NUM_GATES; i++) {
        result->gate_results[i] = NX_GATE_NOT_RUN;
    }

    result->action = NX_DIR_NONE;
    result->signal_class = NX_SIGNAL_NONE;
    result->mtf_score = 0;
    result->sl_steps = 0;
    result->tp_steps = 0;
    result->lot_size = m_config->GetConfig().lot_size;
    result->comment[0] = '\0';

    // ============================================================
    // GATE 0: Synchronization (already passed - we are on new candle)
    // ============================================================
    result->gate_results[NX_GATE_SYNC] = NX_GATE_PASS;

    // ============================================================
    // Calculate ALL indicators from bar data
    // ============================================================
    CalculateIndicators(bars, bar_count, bars_m1, m1_count, bars_m2, m2_count, bars_m3, m3_count);

    // ============================================================
    // GATE 1: Market Access (spread, hours, days)
    // ============================================================
    if (!m_gate1.Process()) {
        result->gate_results[NX_GATE_MARKET] = NX_GATE_FAIL;
        return NX_OK;
    }
    result->gate_results[NX_GATE_MARKET] = NX_GATE_PASS;

    // ============================================================
    // GATE 2: Multi-Timeframe Analysis (score, classification)
    // ============================================================
    int mtf_score = 0;
    NX_SignalDirection direction = NX_DIR_NONE;
    NX_SignalClass signal_class = m_gate2.Process(mtf_score, direction);

    result->mtf_score = mtf_score;

    if (signal_class == NX_SIGNAL_REJECT || signal_class == NX_SIGNAL_NONE) {
        result->gate_results[NX_GATE_MTF] = NX_GATE_FAIL;
        return NX_OK;
    }
    result->gate_results[NX_GATE_MTF] = NX_GATE_PASS;

    // ============================================================
    // MACRO DIRECTION CHANGE CHECK: Block trades after macro flip
    // Prevents whipsaw entries during trend reversals (Sep 2024 bug)
    // ============================================================
    if (m_state) {
        m_state->OnMacroDirection((int)direction);
        if (m_state->IsMacroFlipCooldown()) {
            m_logger->Operational("MACRO FLIP COOLDOWN: %s blocked for %d candles (waiting for new trend to establish)",
                (direction == NX_DIR_BUY) ? "BUY" : "SELL",
                m_state->GetMacroFlipCooldownRemaining());
            result->action = NX_DIR_NONE;
            return NX_OK;
        }
    }

    // ============================================================
    // COOLDOWN CHECK: Block re-entry in same direction after loss
    // ============================================================
    if (m_state && m_state->IsCooldownActive((int)direction)) {
        m_logger->Operational("COOLDOWN ACTIVE: %s blocked for %d more candles",
            (direction == NX_DIR_BUY) ? "BUY" : "SELL",
            m_state->GetCooldownRemaining((int)direction));
        result->action = NX_DIR_NONE;
        return NX_OK;
    }

    // ============================================================
    // GATE 3: Supertrend Confirmation
    // ============================================================
    if (!m_gate3.Process(direction, signal_class)) {
        result->gate_results[NX_GATE_SUPERTREND] = NX_GATE_FAIL;
        return NX_OK;
    }
    result->gate_results[NX_GATE_SUPERTREND] = NX_GATE_PASS;

    // ============================================================
    // GATE 4: Momentum (OBV MACD first -> RSI OMA second)
    // ============================================================
    if (!m_gate4.Process(direction)) {
        result->gate_results[NX_GATE_MOMENTUM] = NX_GATE_FAIL;
        return NX_OK;
    }
    result->gate_results[NX_GATE_MOMENTUM] = NX_GATE_PASS;

    // ============================================================
    // GATE 5: Currency Strength Context
    // ============================================================
    if (!m_gate5.Process(direction)) {
        result->gate_results[NX_GATE_CONTEXT] = NX_GATE_FAIL;
        return NX_OK;
    }
    result->gate_results[NX_GATE_CONTEXT] = NX_GATE_PASS;

    // ============================================================
    // ALL GATES PASSED - Check profile and prepare result
    // ============================================================

    // Check if this signal profile is enabled
    if (!IsProfileEnabled(direction, signal_class)) {
        m_logger->Executive("Profile DISABLED: %s %s not allowed by config",
            (signal_class == NX_SIGNAL_PREMIUM) ? "PREMIUM" : "GOOD",
            (direction == NX_DIR_BUY) ? "BUY" : "SELL");
        result->action = NX_DIR_NONE;
        return NX_OK;
    }

    // Check direction enabled
    const NX_Config& cfg = m_config->GetConfig();
    if (direction == NX_DIR_BUY && !cfg.enable_buy) {
        m_logger->Executive("BUY direction disabled");
        result->action = NX_DIR_NONE;
        return NX_OK;
    }
    if (direction == NX_DIR_SELL && !cfg.enable_sell) {
        m_logger->Executive("SELL direction disabled");
        result->action = NX_DIR_NONE;
        return NX_OK;
    }

    // Fill result with DYNAMIC SL/TP based on Efficiency Ratio
    result->action = (int)direction;
    result->signal_class = (int)signal_class;

    int base_sl = m_config->GetSLSteps((int)direction);
    int base_tp = m_config->GetTPSteps((int)direction);

    // Dynamic SL/TP scaling via Efficiency Ratio (all configurable)
    // ER high (trend, ~1.0) → SL tighter, TP wider
    // ER low  (range, ~0.0) → SL wider,  TP tighter
    double er = m_tm.GetEfficiencyRatio();
    double sl_max = cfg.dyn_sl_max;   // SL scale at ER=0 (default 1.5)
    double sl_min = cfg.dyn_sl_min;   // SL scale at ER=1 (default 0.7)
    double tp_min = cfg.dyn_tp_min;   // TP scale at ER=0 (default 0.8)
    double tp_max = cfg.dyn_tp_max;   // TP scale at ER=1 (default 1.5)

    double sl_scale = sl_max - (sl_max - sl_min) * er;
    double tp_scale = tp_min + (tp_max - tp_min) * er;

    // Clamp scales to configured range
    sl_scale = (sl_scale < sl_min) ? sl_min : ((sl_scale > sl_max) ? sl_max : sl_scale);
    tp_scale = (tp_scale < tp_min) ? tp_min : ((tp_scale > tp_max) ? tp_max : tp_scale);

    result->sl_steps = (int)(base_sl * sl_scale);
    result->tp_steps = (int)(base_tp * tp_scale);

    // Ensure minimum SL/TP (configurable)
    int min_steps = cfg.min_sl_tp_steps;
    if (result->sl_steps < min_steps) result->sl_steps = min_steps;
    if (result->tp_steps < min_steps) result->tp_steps = min_steps;

    result->lot_size = m_config->NormalizeLot(cfg.lot_size);

    // Format comment
    snprintf(result->comment, NX_MAX_COMMENT_LEN, "%s %s Score:%+d ER:%.2f",
        (signal_class == NX_SIGNAL_PREMIUM) ? "PREMIUM" : "GOOD",
        (direction == NX_DIR_BUY) ? "BUY" : "SELL",
        mtf_score, er);

    m_logger->Executive("ALL GATES PASSED: %s | SL=%d(base=%d×%.2f) TP=%d(base=%d×%.2f) Lot=%.2f",
        result->comment,
        result->sl_steps, base_sl, sl_scale,
        result->tp_steps, base_tp, tp_scale,
        result->lot_size);

    m_logger->Operational("Gates: G0=%c G1=%c G2=%c G3=%c G4=%c G5=%c | Score:%+d",
        'P', 'P', 'P', 'P', 'P', 'P', mtf_score);

    return NX_OK;
}

//+------------------------------------------------------------------+
//| Calculate all indicators from bar data arrays                     |
//+------------------------------------------------------------------+
void GateSystem::CalculateIndicators(
    const NX_BarData* bars, int bar_count,
    const NX_BarData* bars_m1, int m1_count,
    const NX_BarData* bars_m2, int m2_count,
    const NX_BarData* bars_m3, int m3_count)
{
    const NX_Config& cfg = m_config->GetConfig();

    // GG TrendBar: calculate for each macro TF using its bar data
    if (bars_m1 && m1_count > 0) {
        int idx = GGTrendBar::TFToIndex(cfg.macro1_tf);
        if (idx >= 0) m_gg.CalculateForTF(bars_m1, m1_count, idx);
    }
    if (bars_m2 && m2_count > 0) {
        int idx = GGTrendBar::TFToIndex(cfg.macro2_tf);
        if (idx >= 0) m_gg.CalculateForTF(bars_m2, m2_count, idx);
    }
    if (bars_m3 && m3_count > 0) {
        int idx = GGTrendBar::TFToIndex(cfg.macro3_tf);
        if (idx >= 0) m_gg.CalculateForTF(bars_m3, m3_count, idx);
    }
    // Operational TF
    if (bars && bar_count > 0) {
        int idx = GGTrendBar::TFToIndex(cfg.operational_tf);
        if (idx >= 0) m_gg.CalculateForTF(bars, bar_count, idx);
    }

    // TrendMagic: operational TF only
    if (bars && bar_count > 0) {
        m_tm.Calculate(bars, bar_count);
    }

    // OBV MACD: operational TF only
    if (bars && bar_count > 0) {
        m_macd.Calculate(bars, bar_count);
    }

    // RSI OMA: operational TF only
    if (bars && bar_count > 0) {
        m_rsi.Calculate(bars, bar_count);
    }

    m_logger->Debug("Indicators calculated: GG[M1=%d M2=%d M3=%d OP=%d] TM=%d(ER=%.3f) MACD=%.5f RSI=%.1f/%.1f",
        m_gg.GetTrendByTF(cfg.macro1_tf),
        m_gg.GetTrendByTF(cfg.macro2_tf),
        m_gg.GetTrendByTF(cfg.macro3_tf),
        m_gg.GetTrendByTF(cfg.operational_tf),
        m_tm.GetSignal(), m_tm.GetEfficiencyRatio(),
        m_macd.GetHistogram(),
        m_rsi.GetRSI(), m_rsi.GetMA());
}

//+------------------------------------------------------------------+
//| Check if signal profile is enabled in config                      |
//+------------------------------------------------------------------+
bool GateSystem::IsProfileEnabled(NX_SignalDirection dir, NX_SignalClass cls)
{
    const NX_Config& cfg = m_config->GetConfig();

    if (dir == NX_DIR_BUY) {
        if (cls == NX_SIGNAL_PREMIUM) return cfg.buy_premium_enable;
        if (cls == NX_SIGNAL_GOOD) return cfg.buy_good_enable;
    } else if (dir == NX_DIR_SELL) {
        if (cls == NX_SIGNAL_PREMIUM) return cfg.sell_premium_enable;
        if (cls == NX_SIGNAL_GOOD) return cfg.sell_good_enable;
    }
    return false;
}
