//+------------------------------------------------------------------+
//|                       state_machine.h                             |
//|                  Nexus Confluence V3 - State Machine               |
//+------------------------------------------------------------------+
#ifndef NEXUS_STATE_MACHINE_H
#define NEXUS_STATE_MACHINE_H

#include "../nexus_types.h"
#include "../nexus_logger.h"
#include <cstdint>

class StateMachine {
public:
    StateMachine()
        : m_state(NX_STATE_IDLE)
        , m_last_candle_time(0)
        , m_last_trade_time(0)
        , m_buffer_sync_time(0)
        , m_cooldown_buy(0)
        , m_cooldown_sell(0)
        , m_cooldown_candles(3)
        , m_cooldown_enable(false)
        , m_last_trade_direction(0)
        , m_max_positions(1)
        , m_last_macro_direction(0)
        , m_direction_change_cooldown(0)
        , m_macro_flip_candles(4)
    {}

    void Init(NexusLogger* logger, int cooldown_enable = 0, int cooldown_candles = 3, int max_positions = 1) {
        m_logger = logger;
        m_state = NX_STATE_IDLE;
        m_last_candle_time = 0;
        m_last_trade_time = 0;
        m_buffer_sync_time = 0;
        m_cooldown_buy = 0;
        m_cooldown_sell = 0;
        m_cooldown_enable = (cooldown_enable != 0);
        m_cooldown_candles = (cooldown_candles > 0) ? cooldown_candles : 3;
        m_max_positions = (max_positions > 0) ? max_positions : 1;
    }

    // Gate 0: Check if new candle has formed
    // Returns true if the bar time is different from last processed
    bool IsNewCandle(int64_t current_bar_time) {
        if (current_bar_time != m_last_candle_time) {
            m_last_candle_time = current_bar_time;

            // Tick down cooldown counters on each new candle
            if (m_cooldown_buy > 0) {
                m_cooldown_buy--;
                if (m_cooldown_buy == 0 && m_logger)
                    m_logger->Operational("Cooldown BUY expired");
            }
            if (m_cooldown_sell > 0) {
                m_cooldown_sell--;
                if (m_cooldown_sell == 0 && m_logger)
                    m_logger->Operational("Cooldown SELL expired");
            }
            // Tick down macro direction change cooldown
            if (m_direction_change_cooldown > 0) {
                m_direction_change_cooldown--;
                if (m_direction_change_cooldown == 0 && m_logger)
                    m_logger->Operational("Macro direction change cooldown expired");
            }

            // Reset state on new candle (allows new signal processing)
            if (m_state == NX_STATE_ORDER_SENT || m_state == NX_STATE_SIGNAL_DETECTED) {
                SetState(NX_STATE_IDLE);
            }
            // With multi-position, WAITING_CLOSE should also allow new signals
            // The actual position count check happens in CanProcessSignal()
            if (m_state == NX_STATE_WAITING_CLOSE && m_max_positions > 1) {
                SetState(NX_STATE_IDLE);
            }
            return true;
        }
        return false;
    }

    // Check if we can process a new signal (multi-position aware)
    // With max_positions > 1, we allow new signals even if positions are open
    bool CanProcessSignal(int open_count) const {
        if (open_count >= m_max_positions) return false;
        // Allow processing unless we're in error state
        return (m_state != NX_STATE_ERROR_RECOVERY);
    }

    // Check if we already traded on this candle
    bool CanTradeOnCandle(int64_t candle_time) const {
        return (m_last_trade_time != candle_time);
    }

    // Check if new signal direction is compatible with open positions
    // Same-direction only: no hedging allowed
    bool IsDirectionCompatible(int signal_direction, int open_direction) const {
        if (open_direction == NX_DIR_NONE) return true; // no positions open
        return (signal_direction == open_direction);     // must match
    }

    // State transitions
    void SetState(NX_EAState new_state) {
        if (m_state == new_state) return;

        if (m_logger) {
            m_logger->Operational("State: %s -> %s",
                StateToString(m_state), StateToString(new_state));
        }
        m_state = new_state;
    }

    void OnSignalDetected() {
        SetState(NX_STATE_SIGNAL_DETECTED);
    }

    void OnOrderSent(int64_t candle_time, int direction = 0) {
        SetState(NX_STATE_ORDER_SENT);
        m_last_trade_time = candle_time;
        m_last_trade_direction = direction;
    }

    int GetLastTradeDirection() const { return m_last_trade_direction; }

    void OnPositionOpen() {
        SetState(NX_STATE_WAITING_CLOSE);
    }

    void OnPositionClosed() {
        SetState(NX_STATE_IDLE);
    }

    // Called when a trade closes with a loss — activates directional cooldown
    void OnLoss(int direction) {
        if (!m_cooldown_enable) return;
        if (direction == NX_DIR_BUY) {
            m_cooldown_buy = m_cooldown_candles;
            if (m_logger) m_logger->Executive("Cooldown BUY activated: %d candles", m_cooldown_candles);
        } else if (direction == NX_DIR_SELL) {
            m_cooldown_sell = m_cooldown_candles;
            if (m_logger) m_logger->Executive("Cooldown SELL activated: %d candles", m_cooldown_candles);
        }
    }

    // Check if a specific direction is in cooldown
    bool IsCooldownActive(int direction) const {
        if (!m_cooldown_enable) return false;
        if (direction == NX_DIR_BUY) return (m_cooldown_buy > 0);
        if (direction == NX_DIR_SELL) return (m_cooldown_sell > 0);
        return false;
    }

    int GetCooldownRemaining(int direction) const {
        if (direction == NX_DIR_BUY) return m_cooldown_buy;
        if (direction == NX_DIR_SELL) return m_cooldown_sell;
        return 0;
    }

    // Set configurable macro flip cooldown candles
    void SetMacroFlipCooldown(int candles) {
        m_macro_flip_candles = candles;
    }

    // Called after Gate 2 determines direction — detects macro flips
    // Returns true if direction just changed and cooldown should block
    bool OnMacroDirection(int direction) {
        if (m_macro_flip_candles <= 0) return false; // disabled
        if (m_last_macro_direction == 0) {
            // First time — no flip
            m_last_macro_direction = direction;
            return false;
        }
        if (direction != 0 && direction != m_last_macro_direction) {
            // Direction FLIPPED (BUY→SELL or SELL→BUY)
            m_direction_change_cooldown = m_macro_flip_candles;
            if (m_logger)
                m_logger->Executive("MACRO DIRECTION FLIP: %s -> %s — cooldown %d candles",
                    (m_last_macro_direction == NX_DIR_BUY) ? "BUY" : "SELL",
                    (direction == NX_DIR_BUY) ? "BUY" : "SELL",
                    m_macro_flip_candles);
            m_last_macro_direction = direction;
            return true;
        }
        m_last_macro_direction = direction;
        return false;
    }

    bool IsMacroFlipCooldown() const {
        return (m_direction_change_cooldown > 0);
    }

    int GetMacroFlipCooldownRemaining() const {
        return m_direction_change_cooldown;
    }

    void OnError() {
        SetState(NX_STATE_ERROR_RECOVERY);
    }

    void Reset() {
        SetState(NX_STATE_IDLE);
    }

    // Buffer sync validation
    void SetBufferSyncTime(int64_t sync_time) {
        m_buffer_sync_time = sync_time;
    }

    bool IsBufferSyncValid() const {
        // v2.39 lesson: MTF indicators update at different times
        // Always return true, log warning only
        return true;
    }

    // Getters
    NX_EAState GetState() const { return m_state; }
    int64_t GetLastCandleTime() const { return m_last_candle_time; }
    int64_t GetLastTradeTime() const { return m_last_trade_time; }

    static const char* StateToString(NX_EAState state) {
        switch (state) {
            case NX_STATE_IDLE:             return "IDLE";
            case NX_STATE_SIGNAL_DETECTED:  return "SIGNAL_DETECTED";
            case NX_STATE_PROCESSING_ORDER: return "PROCESSING_ORDER";
            case NX_STATE_ORDER_SENT:       return "ORDER_SENT";
            case NX_STATE_WAITING_CLOSE:    return "WAITING_CLOSE";
            case NX_STATE_ERROR_RECOVERY:   return "ERROR_RECOVERY";
            default:                        return "UNKNOWN";
        }
    }

private:
    NexusLogger* m_logger = nullptr;
    NX_EAState   m_state;
    int64_t      m_last_candle_time;
    int64_t      m_last_trade_time;
    int64_t      m_buffer_sync_time;

    // Cooldown anti-churn
    int          m_cooldown_buy;       // candles remaining for BUY cooldown
    int          m_cooldown_sell;      // candles remaining for SELL cooldown
    int          m_cooldown_candles;   // N candles to block after loss
    bool         m_cooldown_enable;
    int          m_last_trade_direction; // last trade direction (NX_DIR_BUY/SELL)
    int          m_max_positions;       // max simultaneous positions

    // Macro direction change tracking
    int          m_last_macro_direction; // last Gate 2 direction (+1 BUY, -1 SELL)
    int          m_direction_change_cooldown; // candles remaining after macro flip
    int          m_macro_flip_candles;  // configurable: N candles to block (0=disabled)
};

#endif // NEXUS_STATE_MACHINE_H
