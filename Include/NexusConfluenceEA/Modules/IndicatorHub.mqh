//+------------------------------------------------------------------+
//|                                                  IndicatorHub.mqh |
//|                             Nexus Confluence EA - Indicator Mgmt |
//|                          Buffer Cache & Synchronization Manager  |
//+------------------------------------------------------------------+
#property copyright "Nexus Confluence EA"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| IndicatorHub Class - Manages all 5 indicators                    |
//+------------------------------------------------------------------+
class CIndicatorHub
{
private:
    string          m_symbol;
    ENUM_TIMEFRAMES m_operational_tf;
    
    // Indicator handles (MUST check for INVALID_HANDLE)
    int             m_gg_handle;
    int             m_supertrend_handle;
    int             m_wae_handle;
    int             m_rsi_oma_handle;
    int             m_currency_handle;
    
    // GG TrendBar buffers (9 timeframes: M1, M5, M15, M30, H1, H4, D1, W1, MN1)
    // Returns: -1 (bearish), 0 (neutral), +1 (bullish)
    double          m_gg_buffer[9];
    
    // Supertrend buffers (TrendMagic_MT5)
    // Buffer 0: Upper band (blue line - bullish)
    // Buffer 1: Lower band (red line - bearish)
    double          m_st_upper[2];  // [0]=current, [1]=previous for tolerance
    double          m_st_lower[2];
    
    // WAE buffers (WaddahAttarExplosion)
    // Buffer 0: Trend Up (green bars)
    // Buffer 1: Trend Down (red bars)
    // Buffer 2: Explosion Line (threshold)
    double          m_wae_trend_up;
    double          m_wae_trend_down;
    double          m_wae_explosion_line;
    
    // RSI OMA buffers
    // Buffer 0: Red line (RSI)
    // Buffer 1: Blue line (RSI MA)
    double          m_rsi_red;
    double          m_rsi_blue;
    
    // Currency Strength buffers
    // Buffer 0: Base currency strength
    // Buffer 1: Quote currency strength
    double          m_cs_base;
    double          m_cs_quote;
    bool            m_cs_available;  // Fallback flag for indices
    
    // Synchronization timestamp
    datetime        m_last_update_time;
    
public:
    //+------------------------------------------------------------------+
    //| Constructor                                                      |
    //+------------------------------------------------------------------+
    CIndicatorHub(void)
    {
        m_symbol = _Symbol;
        m_operational_tf = PERIOD_CURRENT;
        
        m_gg_handle = INVALID_HANDLE;
        m_supertrend_handle = INVALID_HANDLE;
        m_wae_handle = INVALID_HANDLE;
        m_rsi_oma_handle = INVALID_HANDLE;
        m_currency_handle = INVALID_HANDLE;
        
        m_cs_available = false;
        m_last_update_time = 0;
        
        ArrayInitialize(m_gg_buffer, 0);
        ArrayInitialize(m_st_upper, EMPTY_VALUE);
        ArrayInitialize(m_st_lower, EMPTY_VALUE);
    }
    
    //+------------------------------------------------------------------+
    //| Destructor                                                       |
    //+------------------------------------------------------------------+
    ~CIndicatorHub(void)
    {
        Deinit();
    }
    
    //+------------------------------------------------------------------+
    //| Helper: Load indicator with multiple path attempts              |
    //+------------------------------------------------------------------+
    int LoadIndicator(string symbol, ENUM_TIMEFRAMES tf, string indicator_name, string display_name)
    {
        int handle = INVALID_HANDLE;
        string paths[] = {
            "NexusConfluenceEA\\",     // Subpasta recomendada
            "\\NexusConfluenceEA\\",   // Com barra inicial
            "",                         // Raiz de Indicators
            "Market\\"                  // Market folder (se baixado do Market)
        };
        
        for(int i = 0; i < ArraySize(paths); i++)
        {
            string full_path = paths[i] + indicator_name;
            handle = iCustom(symbol, tf, full_path);
            
            if(handle != INVALID_HANDLE)
            {
                Print("✅ ", display_name, " loaded from: ", full_path);
                return handle;
            }
            
            // Limpar erro
            ResetLastError();
        }
        
        Print("❌ ERROR: Failed to load ", display_name, " from any path");
        Print("   Tried paths: NexusConfluenceEA\\, \\NexusConfluenceEA\\, root, Market\\");
        Print("   Make sure ", indicator_name, " is compiled (.ex5 exists)");
        return INVALID_HANDLE;
    }
    
    //+------------------------------------------------------------------+
    //| Initialization - Create all indicator handles                   |
    //+------------------------------------------------------------------+
    bool Init(string symbol, ENUM_TIMEFRAMES operational_tf)
    {
        m_symbol = symbol;
        m_operational_tf = operational_tf;
        
        Print("📊 Initializing IndicatorHub for ", m_symbol, " on ", EnumToString(operational_tf));
        Print("   Looking for indicators in MQL5\\Indicators\\NexusConfluenceEA\\");
        
        // 1. GG TrendBar Indicator
        m_gg_handle = LoadIndicator(m_symbol, operational_tf, "GG_TrendBar_Indicator.ex5", "GG TrendBar");
        if(m_gg_handle == INVALID_HANDLE)
        {
            return false;
        }
        
        // 2. TrendMagic (Supertrend)
        m_supertrend_handle = LoadIndicator(m_symbol, operational_tf, "TrendMagic_MT5.ex5", "Supertrend");
        if(m_supertrend_handle == INVALID_HANDLE)
        {
            return false;
        }
        
        // 3. Waddah Attar Explosion
        m_wae_handle = LoadIndicator(m_symbol, operational_tf, "WaddahAttarExplosion_Professional.ex5", "WAE");
        if(m_wae_handle == INVALID_HANDLE)
        {
            return false;
        }
        
        // 4. RSI OMA
        m_rsi_oma_handle = LoadIndicator(m_symbol, operational_tf, "RSIOMA_v2HHLSX_MT5.ex5", "RSI OMA");
        if(m_rsi_oma_handle == INVALID_HANDLE)
        {
            return false;
        }
        
        // 5. Currency Strength (with fallback for indices)
        m_currency_handle = LoadIndicator(m_symbol, operational_tf, "CurrencyStrengthMeter_MT5.ex5", "Currency Strength");
        if(m_currency_handle == INVALID_HANDLE)
        {
            Print("⚠️ WARNING: Currency Strength not available - will skip Gate 5 for indices");
            m_cs_available = false;
        }
        else
        {
            m_cs_available = true;
        }
        
        // Wait for indicators to initialize
        Sleep(1000);
        
        Print("✅ IndicatorHub fully initialized");
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Deinitialization - Release all handles                          |
    //+------------------------------------------------------------------+
    void Deinit(void)
    {
        if(m_gg_handle != INVALID_HANDLE)
        {
            IndicatorRelease(m_gg_handle);
            m_gg_handle = INVALID_HANDLE;
        }
        
        if(m_supertrend_handle != INVALID_HANDLE)
        {
            IndicatorRelease(m_supertrend_handle);
            m_supertrend_handle = INVALID_HANDLE;
        }
        
        if(m_wae_handle != INVALID_HANDLE)
        {
            IndicatorRelease(m_wae_handle);
            m_wae_handle = INVALID_HANDLE;
        }
        
        if(m_rsi_oma_handle != INVALID_HANDLE)
        {
            IndicatorRelease(m_rsi_oma_handle);
            m_rsi_oma_handle = INVALID_HANDLE;
        }
        
        if(m_currency_handle != INVALID_HANDLE)
        {
            IndicatorRelease(m_currency_handle);
            m_currency_handle = INVALID_HANDLE;
        }
        
        Print("📊 IndicatorHub released");
    }
    
    //+------------------------------------------------------------------+
    //| CRITICAL: Update Buffer Cache (ONCE per candle, shift=1 ALWAYS) |
    //+------------------------------------------------------------------+
    bool UpdateBufferCache(datetime sync_time)
    {
        m_last_update_time = sync_time;
        
        // 1. Copy GG TrendBar (9 timeframes at shift=1)
        // Buffer index 0-8 corresponds to M1, M5, M15, M30, H1, H4, D1, W1, MN1
        double temp_gg[9];
        if(CopyBuffer(m_gg_handle, 0, 1, 9, temp_gg) != 9)
        {
            Print("❌ ERROR: Failed to copy GG TrendBar buffer");
            return false;
        }
        ArrayCopy(m_gg_buffer, temp_gg);
        
        // 2. Copy Supertrend (2 candles for tolerance check)
        double temp_upper[2], temp_lower[2];
        if(CopyBuffer(m_supertrend_handle, 0, 1, 2, temp_upper) < 1 ||
           CopyBuffer(m_supertrend_handle, 1, 1, 2, temp_lower) < 1)
        {
            Print("❌ ERROR: Failed to copy Supertrend buffers");
            return false;
        }
        ArrayCopy(m_st_upper, temp_upper);
        ArrayCopy(m_st_lower, temp_lower);
        
        // 3. Copy WAE (shift=1, single value)
        double temp_wae[1];
        if(CopyBuffer(m_wae_handle, 0, 1, 1, temp_wae) != 1)
        {
            Print("❌ ERROR: Failed to copy WAE Trend Up buffer");
            return false;
        }
        m_wae_trend_up = temp_wae[0];
        
        if(CopyBuffer(m_wae_handle, 1, 1, 1, temp_wae) != 1)
        {
            Print("❌ ERROR: Failed to copy WAE Trend Down buffer");
            return false;
        }
        m_wae_trend_down = temp_wae[0];
        
        if(CopyBuffer(m_wae_handle, 2, 1, 1, temp_wae) != 1)
        {
            Print("❌ ERROR: Failed to copy WAE Explosion Line buffer");
            return false;
        }
        m_wae_explosion_line = temp_wae[0];
        
        // 4. Copy RSI OMA (shift=1, single value)
        double temp_rsi[1];
        if(CopyBuffer(m_rsi_oma_handle, 0, 1, 1, temp_rsi) != 1)
        {
            Print("❌ ERROR: Failed to copy RSI Red buffer");
            return false;
        }
        m_rsi_red = temp_rsi[0];
        
        if(CopyBuffer(m_rsi_oma_handle, 1, 1, 1, temp_rsi) != 1)
        {
            Print("❌ ERROR: Failed to copy RSI Blue buffer");
            return false;
        }
        m_rsi_blue = temp_rsi[0];
        
        // 5. Copy Currency Strength (with fallback)
        if(m_cs_available)
        {
            double temp_cs[1];
            if(CopyBuffer(m_currency_handle, 0, 1, 1, temp_cs) == 1)
            {
                m_cs_base = temp_cs[0];
            }
            else
            {
                Print("⚠️ WARNING: Failed to copy CS Base buffer");
                m_cs_base = 0;
            }
            
            if(CopyBuffer(m_currency_handle, 1, 1, 1, temp_cs) == 1)
            {
                m_cs_quote = temp_cs[0];
            }
            else
            {
                Print("⚠️ WARNING: Failed to copy CS Quote buffer");
                m_cs_quote = 0;
            }
        }
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Get GG TrendBar signal for specific timeframe                   |
    //| Returns: -1 (bearish), 0 (neutral), +1 (bullish)                |
    //+------------------------------------------------------------------+
    int GetGGTrendSignal(ENUM_TIMEFRAMES tf)
    {
        // Map timeframe to buffer index
        int index = -1;
        
        switch(tf)
        {
            case PERIOD_M1:  index = 0; break;
            case PERIOD_M5:  index = 1; break;
            case PERIOD_M15: index = 2; break;
            case PERIOD_M30: index = 3; break;
            case PERIOD_H1:  index = 4; break;
            case PERIOD_H4:  index = 5; break;
            case PERIOD_D1:  index = 6; break;
            case PERIOD_W1:  index = 7; break;
            case PERIOD_MN1: index = 8; break;
            default:
                Print("⚠️ WARNING: Invalid timeframe for GG TrendBar");
                return 0;
        }
        
        double value = m_gg_buffer[index];
        
        // Return as integer (-1, 0, +1)
        if(value > 0.5) return 1;   // Bullish
        if(value < -0.5) return -1; // Bearish
        return 0;                    // Neutral
    }
    
    //+------------------------------------------------------------------+
    //| Check Supertrend direction (with 1 candle tolerance)            |
    //+------------------------------------------------------------------+
    int GetSupertrendSignal(void)
    {
        double price = iClose(m_symbol, m_operational_tf, 1); // Closed bar price
        
        // Current candle (shift=1)
        bool bullish_current = (m_st_lower[0] != EMPTY_VALUE && price > m_st_lower[0]);
        bool bearish_current = (m_st_upper[0] != EMPTY_VALUE && price < m_st_upper[0]);
        
        if(bullish_current) return 1;
        if(bearish_current) return -1;
        
        // Check previous candle (tolerance)
        if(ArraySize(m_st_lower) > 1 && ArraySize(m_st_upper) > 1)
        {
            bool bullish_prev = (m_st_lower[1] != EMPTY_VALUE && price > m_st_lower[1]);
            bool bearish_prev = (m_st_upper[1] != EMPTY_VALUE && price < m_st_upper[1]);
            
            if(bullish_prev) return 1;
            if(bearish_prev) return -1;
        }
        
        return 0; // Neutral/uncertain
    }
    
    //+------------------------------------------------------------------+
    //| Check if WAE is expanding (Gate 4 - FIRST check)                |
    //+------------------------------------------------------------------+
    bool IsWAEExpanding(void)
    {
        // Check if either trend bar is above explosion line
        bool expanding = (m_wae_trend_up > m_wae_explosion_line) || 
                         (m_wae_trend_down > m_wae_explosion_line);
        
        return expanding;
    }
    
    //+------------------------------------------------------------------+
    //| Get WAE direction                                                |
    //+------------------------------------------------------------------+
    int GetWAEDirection(void)
    {
        if(m_wae_trend_up > m_wae_trend_down) return 1;   // Bullish
        if(m_wae_trend_down > m_wae_trend_up) return -1;  // Bearish
        return 0;
    }
    
    //+------------------------------------------------------------------+
    //| Get RSI OMA signal (Gate 4 - SECOND check)                      |
    //| Returns: 1 (buy), -1 (sell), 0 (neutral)                        |
    //+------------------------------------------------------------------+
    int GetRSIOMASignal(void)
    {
        if(m_rsi_red > m_rsi_blue) return 1;   // Buy signal
        if(m_rsi_red < m_rsi_blue) return -1;  // Sell signal
        return 0;
    }
    
    //+------------------------------------------------------------------+
    //| Get Currency Strength values                                     |
    //+------------------------------------------------------------------+
    bool GetCurrencyStrength(double &base_strength, double &quote_strength)
    {
        if(!m_cs_available)
        {
            return false; // Not available (fallback for indices)
        }
        
        base_strength = m_cs_base;
        quote_strength = m_cs_quote;
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Check if Currency Strength is available                         |
    //+------------------------------------------------------------------+
    bool IsCurrencyStrengthAvailable(void) const
    {
        return m_cs_available;
    }
    
    //+------------------------------------------------------------------+
    //| Get last update time                                             |
    //+------------------------------------------------------------------+
    datetime GetLastUpdateTime(void) const
    {
        return m_last_update_time;
    }
    
    //+------------------------------------------------------------------+
    //| Debug: Print all cached values                                   |
    //+------------------------------------------------------------------+
    void PrintDebugInfo(void)
    {
        Print("=== IndicatorHub Debug Info ===");
        Print("GG TrendBar: M1=", m_gg_buffer[0], " M5=", m_gg_buffer[1], 
              " M15=", m_gg_buffer[2], " M30=", m_gg_buffer[3]);
        Print("GG TrendBar: H1=", m_gg_buffer[4], " H4=", m_gg_buffer[5], 
              " D1=", m_gg_buffer[6], " W1=", m_gg_buffer[7], " MN1=", m_gg_buffer[8]);
        Print("Supertrend: Upper[0]=", m_st_upper[0], " Lower[0]=", m_st_lower[0]);
        Print("WAE: Up=", m_wae_trend_up, " Down=", m_wae_trend_down, 
              " Explosion=", m_wae_explosion_line);
        Print("RSI OMA: Red=", m_rsi_red, " Blue=", m_rsi_blue);
        Print("Currency Strength: Base=", m_cs_base, " Quote=", m_cs_quote, 
              " Available=", m_cs_available);
        Print("===============================");
    }
};
//+------------------------------------------------------------------+
