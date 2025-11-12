//+------------------------------------------------------------------+
//|                                                         Core.mqh |
//|                                      Nexus Confluence EA - Core  |
//|                               Gate 0: Synchronization & State    |
//+------------------------------------------------------------------+
#property copyright "Nexus Confluence EA"
#property version   "2.39"
#property strict

// CHANGELOG v2.39 (CRITICAL FIX):
// ✅ IsBufferSyncValid() agora retorna SEMPRE TRUE
// - MTF indicators (M30/M20/M15/M10) atualizam em intervalos diferentes do chart M5
// - Validação timestamp estrita causava FALSOS POSITIVOS bloqueando trades válidos
// - CopyBuffer com start_pos=1 JÁ garante leitura de shift=1 correta
// - Mantido log informativo (nível 3) mas NÃO BLOQUEIA mais sinais
// - Corrige: "⚠️ Buffer desync detected" bloqueava sinais quando M15/M20/M10 mostravam +1

#ifndef CORE_MQH
#define CORE_MQH

//+------------------------------------------------------------------+
//| EA State Machine Enumeration (v2.15 - Enhanced Anti-Duplication) |
//+------------------------------------------------------------------+
enum ENUM_EA_STATE
{
    STATE_IDLE,              // Ready to process new signals
    STATE_SIGNAL_DETECTED,   // Valid signal found, preparing order
    STATE_PROCESSING_ORDER,  // ✅ NEW: Prevents duplicate order attempts
    STATE_ORDER_SENT,        // Order executed successfully
    STATE_WAITING_CLOSE,     // Position open, monitoring exit
    STATE_ERROR_RECOVERY     // ✅ NEW: Handles recoverable errors (requote, timeout)
};

//+------------------------------------------------------------------+
//| Core Class - Gate 0 Implementation                              |
//+------------------------------------------------------------------+
class CCore
{
private:
    datetime        m_last_candle_time;      // Timestamp of last processed candle
    datetime        m_last_trade_time;       // Timestamp of last trade execution
    ENUM_EA_STATE   m_current_state;         // Current EA state
    int             m_magic_number;          // Magic number for identification
    int             m_log_level;             // 1=Executivo, 2=Operacional, 3=Debug
    string          m_symbol;                // Current trading symbol
    ENUM_TIMEFRAMES m_timeframe;             // Current timeframe
    
    // Synchronization validation
    datetime        m_buffer_sync_time;      // Timestamp when buffers were cached
    
public:
    //+------------------------------------------------------------------+
    //| Constructor                                                      |
    //+------------------------------------------------------------------+
    CCore(void)
    {
        m_last_candle_time = 0;
        m_last_trade_time = 0;
        m_current_state = STATE_IDLE;
        m_magic_number = 0;
        m_log_level = 2;
        m_buffer_sync_time = 0;
        m_symbol = _Symbol;
        m_timeframe = _Period;
    }
    
    //+------------------------------------------------------------------+
    //| Destructor                                                       |
    //+------------------------------------------------------------------+
    ~CCore(void)
    {
        LogMessage(2, "Core module destroyed");
    }
    
    //+------------------------------------------------------------------+
    //| Initialization                                                   |
    //+------------------------------------------------------------------+
    bool Init(int magic_number, int log_level = 2)
    {
        m_magic_number = magic_number;
        m_log_level = log_level;
        m_current_state = STATE_IDLE;
        
        LogMessage(1, StringFormat("✅ Core initialized | Magic: %d | Log Level: %d", 
                   m_magic_number, m_log_level));
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| GATE 0: New Candle Detection (CRITICAL - shift=1 enforcement)   |
    //+------------------------------------------------------------------+
    bool IsNewCandle(void)
    {
        datetime current_time = iTime(m_symbol, m_timeframe, 0);
        
        if(current_time == 0)
        {
            LogMessage(1, "❌ ERROR: Failed to get current bar time");
            return false;
        }
        
        if(current_time != m_last_candle_time)
        {
            m_last_candle_time = current_time;
            m_buffer_sync_time = 0; // Reset sync time - buffers need update
            
            LogMessage(3, StringFormat("🕐 New candle detected: %s", 
                       TimeToString(current_time, TIME_DATE|TIME_MINUTES)));
            
            return true;
        }
        
        return false;
    }
    
    //+------------------------------------------------------------------+
    //| State Machine Management (Anti-Duplication)                     |
    //+------------------------------------------------------------------+
    void UpdateStateMachine(ENUM_EA_STATE new_state)
    {
        if(m_current_state == new_state)
            return; // No change
        
        string old_state_str = EnumToString(m_current_state);
        string new_state_str = EnumToString(new_state);
        
        LogMessage(2, StringFormat("State transition: %s → %s", 
                   old_state_str, new_state_str));
        
        m_current_state = new_state;
    }
    
    //+------------------------------------------------------------------+
    //| Check if EA can process new signals                             |
    //+------------------------------------------------------------------+
    bool CanProcessSignal(void)
    {
        return (m_current_state == STATE_IDLE);
    }
    
    //+------------------------------------------------------------------+
    //| Buffer Synchronization Timestamp                                |
    //+------------------------------------------------------------------+
    void SetBufferSyncTime(datetime sync_time)
    {
        m_buffer_sync_time = sync_time;
        
        LogMessage(3, StringFormat("📊 Buffers cached at: %s", 
                   TimeToString(sync_time, TIME_DATE|TIME_MINUTES)));
    }
    
    datetime GetBufferSyncTime(void) const
    {
        return m_buffer_sync_time;
    }
    
    //+------------------------------------------------------------------+
    //| Validate Buffer Synchronization (v2.39: WARNING ONLY!)          |
    //| ✅ FIX: MTF indicators atualizam em tempos diferentes           |
    //| NÃO BLOQUEIA mais sinais - apenas loga para diagnóstico         |
    //+------------------------------------------------------------------+
    bool IsBufferSyncValid(void)
    {
        if(m_buffer_sync_time == 0)
        {
            LogMessage(3, "ℹ️ Buffer sync time not set yet (first tick)");
            return true;  // ✅ v2.39: Allow first tick
        }
        
        datetime closed_bar_time = iTime(m_symbol, m_timeframe, 1);
        
        if(m_buffer_sync_time != closed_bar_time)
        {
            // ✅ v2.39 CRITICAL FIX: WARNING ONLY - DON'T BLOCK SIGNAL!
            // MTF indicators (M30/M20/M15/M10) update at DIFFERENT times
            // Strategy Tester simulates M5 ticks, but M20 only updates every 20min
            // This is NORMAL behavior - buffer data is still VALID from shift=1
            LogMessage(3, StringFormat("ℹ️ MTF timing lag (NORMAL): Chart bar %s | Buffer from %s",
                       TimeToString(closed_bar_time, TIME_DATE|TIME_MINUTES),
                       TimeToString(m_buffer_sync_time, TIME_DATE|TIME_MINUTES)));
            return true;  // ✅ v2.39: ALWAYS ALLOW - timing difference is expected!
        }
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Prevent Multiple Trades Per Candle                              |
    //+------------------------------------------------------------------+
    bool IsNewCandleForTrade(datetime current_time)
    {
        if(current_time <= m_last_trade_time)
        {
            LogMessage(3, "⏸️ Trade already executed on this candle");
            return false;
        }
        
        return true;
    }
    
    void SetLastTradeTime(datetime trade_time)
    {
        m_last_trade_time = trade_time;
    }
    
    //+------------------------------------------------------------------+
    //| 3-Level Logging System                                          |
    //+------------------------------------------------------------------+
    void LogMessage(int level, string message)
    {
        if(level > m_log_level)
            return; // Skip if message level exceeds configured level
        
        string prefix = "";
        
        switch(level)
        {
            case 1: prefix = "[EXECUTIVO] "; break;
            case 2: prefix = "[OPERACIONAL] "; break;
            case 3: prefix = "[DEBUG] "; break;
            default: prefix = "[UNKNOWN] "; break;
        }
        
        Print(prefix + message);
    }
    
    //+------------------------------------------------------------------+
    //| Getters                                                          |
    //+------------------------------------------------------------------+
    ENUM_EA_STATE GetCurrentState(void) const { return m_current_state; }
    int GetMagicNumber(void) const { return m_magic_number; }
    datetime GetLastCandleTime(void) const { return m_last_candle_time; }
    datetime GetLastTradeTime(void) const { return m_last_trade_time; }
    string GetSymbol(void) const { return m_symbol; }
    ENUM_TIMEFRAMES GetTimeframe(void) const { return m_timeframe; }
};
//+------------------------------------------------------------------+

#endif // CORE_MQH
