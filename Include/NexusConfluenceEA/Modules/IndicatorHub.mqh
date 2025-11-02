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

    // ──────────────────────────────────────────────────────────────
    // Indicator input parameters (configuráveis via EA Inputs)
    // ──────────────────────────────────────────────────────────────
    // GG TrendBar
    color               m_gg_up_color;
    color               m_gg_down_color;
    color               m_gg_flat_color;
    color               m_gg_text_color;
    ENUM_BASE_CORNER    m_gg_corner;
    bool                m_gg_create_objects;
    int                 m_gg_adx_period;
    ENUM_APPLIED_PRICE  m_gg_adx_price;
    double              m_gg_psar_step;
    double              m_gg_psar_max;

    // Supertrend (TrendMagic_MT5)
    int                 m_st_cci_period;
    int                 m_st_atr_period;
    double              m_st_atr_multiplier;

    // WAE
    int                 m_wae_fast_ma;
    int                 m_wae_slow_ma;
    int                 m_wae_bb_length;
    double              m_wae_bb_multiplier;
    int                 m_wae_sensitivity;

    // RSI OMA
    int                 m_rsi_period;
    int                 m_rsi_ma_period;
    ENUM_MA_METHOD      m_rsi_ma_method;
    double              m_rsi_high_level;
    double              m_rsi_low_level;
    bool                m_rsi_show_levels;

    // Currency Strength
    int                 m_cs_calc_period;
    int                 m_cs_smoothing;
    bool                m_cs_show_percent;
    
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
    bool Init(string symbol, ENUM_TIMEFRAMES operational_tf,
              // GG TrendBar
              color gg_up_color, color gg_down_color, color gg_flat_color, color gg_text_color,
              ENUM_BASE_CORNER gg_corner, bool gg_create_objects,
              int gg_adx_period, ENUM_APPLIED_PRICE gg_adx_price, double gg_psar_step, double gg_psar_max,
              // Supertrend (TrendMagic)
              int st_cci_period, int st_atr_period, double st_atr_multiplier,
              // WAE
              int wae_fast_ma, int wae_slow_ma, int wae_bb_length, double wae_bb_multiplier, int wae_sensitivity,
              // RSI OMA
              int rsi_period, int rsi_ma_period, ENUM_MA_METHOD rsi_ma_method, double rsi_high_level, double rsi_low_level, bool rsi_show_levels,
              // Currency Strength
              int cs_calc_period, int cs_smoothing, bool cs_show_percent)
    {
        m_symbol = symbol;
        m_operational_tf = operational_tf;
        
        // Store parameters
        m_gg_up_color = gg_up_color;
        m_gg_down_color = gg_down_color;
        m_gg_flat_color = gg_flat_color;
        m_gg_text_color = gg_text_color;
        m_gg_corner = gg_corner;
        m_gg_create_objects = gg_create_objects;
        m_gg_adx_period = gg_adx_period;
        m_gg_adx_price = gg_adx_price;
        m_gg_psar_step = gg_psar_step;
        m_gg_psar_max = gg_psar_max;
        
        m_st_cci_period = st_cci_period;
        m_st_atr_period = st_atr_period;
        m_st_atr_multiplier = st_atr_multiplier;
        
        m_wae_fast_ma = wae_fast_ma;
        m_wae_slow_ma = wae_slow_ma;
        m_wae_bb_length = wae_bb_length;
        m_wae_bb_multiplier = wae_bb_multiplier;
        m_wae_sensitivity = wae_sensitivity;
        
        m_rsi_period = rsi_period;
        m_rsi_ma_period = rsi_ma_period;
        m_rsi_ma_method = rsi_ma_method;
        m_rsi_high_level = rsi_high_level;
        m_rsi_low_level = rsi_low_level;
        m_rsi_show_levels = rsi_show_levels;
        
        m_cs_calc_period = cs_calc_period;
        m_cs_smoothing = cs_smoothing;
        m_cs_show_percent = cs_show_percent;
        
        Print("📊 Initializing IndicatorHub for ", m_symbol, " on ", EnumToString(operational_tf));
        Print("   Looking for indicators in MQL5\\Indicators\\NexusConfluenceEA\\");
        
        // 1. GG TrendBar Indicator (try multiple paths and names)
        {
            string paths[] = { "NexusConfluenceEA\\", "\\NexusConfluenceEA\\", "", "Market\\" };
            int handle = INVALID_HANDLE;
            for(int i = 0; i < ArraySize(paths); i++)
            {
                string full_path = paths[i] + "GG_TrendBar_Indicator.ex5";
                handle = iCustom(m_symbol, operational_tf, full_path,
                                 m_gg_up_color, m_gg_down_color, m_gg_flat_color, m_gg_text_color,
                                 m_gg_corner, m_gg_create_objects,
                                 m_gg_adx_period, m_gg_adx_price, m_gg_psar_step, m_gg_psar_max);
                if(handle != INVALID_HANDLE)
                {
                    m_gg_handle = handle;
                    Print("✅ GG TrendBar loaded from: ", full_path);
                    break;
                }
                // Try without extension as some terminals require base name
                string base_path = paths[i] + "GG_TrendBar_Indicator";
                handle = iCustom(m_symbol, operational_tf, base_path,
                                 m_gg_up_color, m_gg_down_color, m_gg_flat_color, m_gg_text_color,
                                 m_gg_corner, m_gg_create_objects,
                                 m_gg_adx_period, m_gg_adx_price, m_gg_psar_step, m_gg_psar_max);
                if(handle != INVALID_HANDLE)
                {
                    m_gg_handle = handle;
                    Print("✅ GG TrendBar loaded from: ", base_path);
                    break;
                }
                ResetLastError();
            }
            if(m_gg_handle == INVALID_HANDLE)
                return false;
        }
        
        // 2. TrendMagic (Supertrend) – try with and without extension
        {
            string paths[] = { "NexusConfluenceEA\\", "\\NexusConfluenceEA\\", "", "Market\\" };
            int handle = INVALID_HANDLE;
            for(int i = 0; i < ArraySize(paths); i++)
            {
                string full_path = paths[i] + "TrendMagic_MT5.ex5";
                handle = iCustom(m_symbol, operational_tf, full_path,
                                 m_st_cci_period, m_st_atr_period, m_st_atr_multiplier);
                if(handle != INVALID_HANDLE)
                {
                    m_supertrend_handle = handle;
                    Print("✅ Supertrend loaded from: ", full_path);
                    break;
                }
                string base_path = paths[i] + "TrendMagic_MT5";
                handle = iCustom(m_symbol, operational_tf, base_path,
                                 m_st_cci_period, m_st_atr_period, m_st_atr_multiplier);
                if(handle != INVALID_HANDLE)
                {
                    m_supertrend_handle = handle;
                    Print("✅ Supertrend loaded from: ", base_path);
                    break;
                }
                ResetLastError();
            }
            if(m_supertrend_handle == INVALID_HANDLE)
                return false;
        }
        
        // 3. Waddah Attar Explosion (WAE) – try with and without extension
        {
            string paths[] = { "NexusConfluenceEA\\", "\\NexusConfluenceEA\\", "", "Market\\" };
            int handle = INVALID_HANDLE;
            for(int i = 0; i < ArraySize(paths); i++)
            {
                string full_path = paths[i] + "WaddahAttarExplosion_Professional.ex5";
                handle = iCustom(m_symbol, operational_tf, full_path,
                                 m_wae_fast_ma, m_wae_slow_ma, m_wae_bb_length, m_wae_bb_multiplier, m_wae_sensitivity);
                if(handle != INVALID_HANDLE)
                {
                    m_wae_handle = handle;
                    Print("✅ WAE loaded from: ", full_path);
                    break;
                }
                string base_path = paths[i] + "WaddahAttarExplosion_Professional";
                handle = iCustom(m_symbol, operational_tf, base_path,
                                 m_wae_fast_ma, m_wae_slow_ma, m_wae_bb_length, m_wae_bb_multiplier, m_wae_sensitivity);
                if(handle != INVALID_HANDLE)
                {
                    m_wae_handle = handle;
                    Print("✅ WAE loaded from: ", base_path);
                    break;
                }
                ResetLastError();
            }
            if(m_wae_handle == INVALID_HANDLE)
                return false;
        }
        
        // 4. RSI OMA – try with and without extension
        {
            string paths[] = { "NexusConfluenceEA\\", "\\NexusConfluenceEA\\", "", "Market\\" };
            int handle = INVALID_HANDLE;
            for(int i = 0; i < ArraySize(paths); i++)
            {
                string full_path = paths[i] + "RSIOMA_v2HHLSX_MT5.ex5";
                handle = iCustom(m_symbol, operational_tf, full_path,
                                 m_rsi_period, m_rsi_ma_period, m_rsi_ma_method, m_rsi_high_level, m_rsi_low_level, m_rsi_show_levels);
                if(handle != INVALID_HANDLE)
                {
                    m_rsi_oma_handle = handle;
                    Print("✅ RSI OMA loaded from: ", full_path);
                    break;
                }
                string base_path = paths[i] + "RSIOMA_v2HHLSX_MT5";
                handle = iCustom(m_symbol, operational_tf, base_path,
                                 m_rsi_period, m_rsi_ma_period, m_rsi_ma_method, m_rsi_high_level, m_rsi_low_level, m_rsi_show_levels);
                if(handle != INVALID_HANDLE)
                {
                    m_rsi_oma_handle = handle;
                    Print("✅ RSI OMA loaded from: ", base_path);
                    break;
                }
                ResetLastError();
            }
            if(m_rsi_oma_handle == INVALID_HANDLE)
                return false;
        }
        
        // 5. Currency Strength (with fallback for indices) – try with and without extension
        {
            string paths[] = { "NexusConfluenceEA\\", "\\NexusConfluenceEA\\", "", "Market\\" };
            int handle = INVALID_HANDLE;
            for(int i = 0; i < ArraySize(paths); i++)
            {
                string full_path = paths[i] + "CurrencyStrengthMeter_MT5.ex5";
                handle = iCustom(m_symbol, operational_tf, full_path,
                                 m_cs_calc_period, m_cs_smoothing, m_cs_show_percent);
                if(handle != INVALID_HANDLE)
                {
                    m_currency_handle = handle;
                    m_cs_available = true;
                    Print("✅ Currency Strength loaded from: ", full_path);
                    break;
                }
                string base_path = paths[i] + "CurrencyStrengthMeter_MT5";
                handle = iCustom(m_symbol, operational_tf, base_path,
                                 m_cs_calc_period, m_cs_smoothing, m_cs_show_percent);
                if(handle != INVALID_HANDLE)
                {
                    m_currency_handle = handle;
                    m_cs_available = true;
                    Print("✅ Currency Strength loaded from: ", base_path);
                    break;
                }
                ResetLastError();
            }
            if(m_currency_handle == INVALID_HANDLE)
            {
                Print("⚠️ WARNING: Currency Strength not available - will skip Gate 5 for indices");
                m_cs_available = false;
            }
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
        
        // 1. Copy GG TrendBar (9 BUFFERS SEPARADOS at shift=1)
        // ✅ FIX CRÍTICO v2.20: GG_TrendBar agora desenha NO PREÇO (visual)
        // MAS os valores LÓGICOS -1/0/+1 ainda são acessíveis via buffers adicionais
        // PORÉM: Como modificamos para desenhar no preço, precisamos CONVERTER de volta
        // O buffer contém: EMPTY_VALUE (neutro) ou preço (com tendência)
        // A COR do buffer indica a direção: 0=verde(+1), 1=vermelho(-1), 2=amarelo(0)
        
        double temp_gg_val[1];
        double temp_gg_color[1];
        
        for(int i = 0; i < 9; i++)
        {
            // Copiar buffer de VALOR (contém preço ou EMPTY_VALUE)
            if(CopyBuffer(m_gg_handle, i, 1, 1, temp_gg_val) != 1)
            {
                Print("❌ ERROR: Failed to copy GG TrendBar value buffer ", i);
                return false;
            }
            
            // Copiar buffer de COR (índice 9+i, contém 0/1/2)
            if(CopyBuffer(m_gg_handle, 9 + i, 1, 1, temp_gg_color) != 1)
            {
                Print("❌ ERROR: Failed to copy GG TrendBar color buffer ", i);
                return false;
            }
            
            double val_raw = temp_gg_val[0];
            double color_idx = temp_gg_color[0];
            
            // Converter COR de volta para valor lógico
            double logical_val = 0.0;
            if(val_raw != EMPTY_VALUE && val_raw > 0)  // Há tendência
            {
                if(color_idx == 0) logical_val = 1.0;      // Verde = +1
                else if(color_idx == 1) logical_val = -1.0; // Vermelho = -1
                else logical_val = 0.0;                    // Amarelo = 0
            }
            else
            {
                logical_val = 0.0;  // EMPTY_VALUE = sem tendência = 0
            }
            
            m_gg_buffer[i] = logical_val;
        }
        
        // Log GG values for debugging synchronization
        Print(StringFormat("📊 GG TrendBar [shift=1]: M1:%.0f M5:%.0f M15:%.0f M30:%.0f H1:%.0f H4:%.0f D1:%.0f W1:%.0f MN1:%.0f",
              m_gg_buffer[0], m_gg_buffer[1], m_gg_buffer[2], m_gg_buffer[3],
              m_gg_buffer[4], m_gg_buffer[5], m_gg_buffer[6], m_gg_buffer[7], m_gg_buffer[8]));
        
        // 2. Copy Supertrend (2 candles for tolerance check)
        // 🔥 ATENÇÃO v2.03: INVERSÃO INTENCIONAL DOS NOMES!
        // 
        // TrendMagic_MT5.mq5 tem:
        //   Buffer 0 = bufferUp (linha AZUL/verde) - tendência de ALTA
        //   Buffer 1 = bufferDn (linha VERMELHA) - tendência de BAIXA
        //
        // Copiamos INVERTIDO para manter compatibilidade semântica interna:
        //   m_st_lower = Buffer 0 (linha de ALTA)   ← inversão proposital
        //   m_st_upper = Buffer 1 (linha de BAIXA)  ← inversão proposital
        //
        // A lógica em GetSupertrendSignal() compensa essa inversão!
        double temp_up[2], temp_down[2];
        if(CopyBuffer(m_supertrend_handle, 0, 1, 2, temp_up) < 1 ||
           CopyBuffer(m_supertrend_handle, 1, 1, 2, temp_down) < 1)
        {
            Print("❌ ERROR: Failed to copy Supertrend buffers");
            return false;
        }
        
        // Inversão intencional (compensada em GetSupertrendSignal):
        ArrayCopy(m_st_lower, temp_up);    // Buffer 0 (ALTA) → m_st_lower
        ArrayCopy(m_st_upper, temp_down);  // Buffer 1 (BAIXA) → m_st_upper
        
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
        
        // Explosion line index may vary across WAE versions; try a set of candidates
        int wae_explosion_candidates[3] = {2,3,4};
        bool got_explosion = false;
        for(int k=0; k<3 && !got_explosion; k++)
        {
            if(CopyBuffer(m_wae_handle, wae_explosion_candidates[k], 1, 1, temp_wae) == 1)
            {
                m_wae_explosion_line = temp_wae[0];
                got_explosion = true;
            }
            else
            {
                ResetLastError();
            }
        }
        if(!got_explosion)
        {
            Print("❌ ERROR: Failed to copy WAE Explosion Line buffer (2/3/4)");
            return false;
        }
        
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
        // 🔥 FIX v2.03: CORREÇÃO CRÍTICA da inversão de buffers
        // 
        // TrendMagic_MT5.mq5 tem:
        //   Buffer 0 = bufferUp (linha AZUL) - tendência de ALTA (CCI >= 0)
        //   Buffer 1 = bufferDn (linha VERMELHA) - tendência de BAIXA (CCI <= 0)
        //
        // MAS na linha 520, a cópia está INVERTIDA:
        //   ArrayCopy(m_st_lower, temp_up);    // m_st_lower recebe Buffer 0 (AZUL/ALTA)
        //   ArrayCopy(m_st_upper, temp_down);  // m_st_upper recebe Buffer 1 (VERMELHA/BAIXA)
        //
        // PORTANTO: A lógica de teste deve considerar essa INVERSÃO!
        
        // Se m_st_lower tem valor (que é Buffer 0 = linha AZUL = ALTA)
        if(m_st_lower[0] != EMPTY_VALUE && m_st_upper[0] == EMPTY_VALUE)
        {
            return 1;  // ✅ BULLISH - linha AZUL ativa
        }
        
        // Se m_st_upper tem valor (que é Buffer 1 = linha VERMELHA = BAIXA)
        if(m_st_upper[0] != EMPTY_VALUE && m_st_lower[0] == EMPTY_VALUE)
        {
            return -1;  // ✅ BEARISH - linha VERMELHA ativa
        }
        
        // Tolerância de 1 vela: verificar vela anterior se ambos estão EMPTY_VALUE
        if(ArraySize(m_st_lower) > 1 && ArraySize(m_st_upper) > 1)
        {
            if(m_st_lower[0] == EMPTY_VALUE && m_st_upper[0] == EMPTY_VALUE)
            {
                // Verificar vela anterior [1] = shift=2
                if(m_st_lower[1] != EMPTY_VALUE && m_st_upper[1] == EMPTY_VALUE)
                {
                    return 1;  // ✅ BULLISH na vela anterior
                }
                if(m_st_upper[1] != EMPTY_VALUE && m_st_lower[1] == EMPTY_VALUE)
                {
                    return -1;  // ✅ BEARISH na vela anterior
                }
            }
        }
        
        return 0; // Neutro/incerto
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
    //| Realtime (shift=0) accessors – guard right before placing order  |
    //+------------------------------------------------------------------+
    bool IsWAEExpandingRealtime(const int shift = 0)
    {
        double up[1], down[1], expl[1];
        if(CopyBuffer(m_wae_handle, 0, shift, 1, up) != 1) return false;
        if(CopyBuffer(m_wae_handle, 1, shift, 1, down) != 1) return false;
        if(CopyBuffer(m_wae_handle, 2, shift, 1, expl) != 1) return false;
        return (up[0] > expl[0]) || (down[0] > expl[0]);
    }

    int GetWAEDirectionRealtime(const int shift = 0)
    {
        double up[1], down[1];
        if(CopyBuffer(m_wae_handle, 0, shift, 1, up) != 1) return 0;
        if(CopyBuffer(m_wae_handle, 1, shift, 1, down) != 1) return 0;
        if(up[0] > down[0]) return 1;
        if(down[0] > up[0]) return -1;
        return 0;
    }

    int GetRSIOMASignalRealtime(const int shift = 0)
    {
        double red[1], blue[1];
        if(CopyBuffer(m_rsi_oma_handle, 0, shift, 1, red) != 1) return 0;
        if(CopyBuffer(m_rsi_oma_handle, 1, shift, 1, blue) != 1) return 0;
        if(red[0] > blue[0]) return 1;
        if(red[0] < blue[0]) return -1;
        return 0;
    }

    // Returns true when realtime momentum clearly opposes expected_dir
    // expected_dir: +1=BUY, -1=SELL
    bool IsRealtimeMomentumOppositeTo(const int expected_dir)
    {
        // If we cannot read, be conservative and return false (do not block)
        int wae_dir = GetWAEDirectionRealtime(0);
        bool wae_exp = IsWAEExpandingRealtime(0);
        int rsi_dir = GetRSIOMASignalRealtime(0);

        // Block if WAE is expanding strongly in the opposite direction
        if(wae_exp && wae_dir != 0 && wae_dir == -expected_dir)
            return true;

        // Secondary guard: RSI also flipped opposite (optional confirm)
        if(rsi_dir != 0 && rsi_dir == -expected_dir)
            return true;

        return false;
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
