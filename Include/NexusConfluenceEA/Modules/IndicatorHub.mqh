//+------------------------------------------------------------------+
//|                                                  IndicatorHub.mqh |
//|                             Nexus Confluence EA - Indicator Mgmt |
//|                          Buffer Cache & Synchronization Manager  |
//+------------------------------------------------------------------+
#property copyright "Nexus Confluence EA"
#property version   "2.36"
#property strict

#ifndef INDICATOR_HUB_MQH
#define INDICATOR_HUB_MQH

//+------------------------------------------------------------------+
//| v2.36: CRITICAL FIX - Ultra-tolerant CopyBuffer error handling  |
//| - CopyBuffer falhas NÃO bloqueiam mais UpdateBufferCache()      |
//| - Mantém valores anteriores em QUALQUER erro de CopyBuffer      |
//| - Logs detalhados de quais indicadores falharam (primeiras 10x) |
//| - Fix definitivo para backtest não-visual: nunca retorna false  |
//+------------------------------------------------------------------+
//| v2.35: CRITICAL FIX - Ultra-tolerant backtest synchronization   |
//| - Validação MÍNIMA: apenas 1 barra calculada por indicador      |
//| - Remove lógica complexa de current_bars vs calculated          |
//| - Backtest não-visual agora funciona IMEDIATAMENTE              |
//| - Logs limitados para evitar poluição (10 primeiras falhas)     |
//+------------------------------------------------------------------+
//| v2.34: CRITICAL FIX - Backtest não-visual sincronização          |
//| - Validação BarsCalculated() agora tolerante no início          |
//| - Permite continuar após 50+ barras calculadas                  |
//| - Resolve erro "Failed to update indicator buffers" em backtest |
//| - EA funciona corretamente sem modo visual habilitado           |
//+------------------------------------------------------------------+
//| v2.32: CRITICAL FIX - Retry com fallback para buffers 4806       |
//| - CopyBuffer agora trata erro 4806 (dados não disponíveis)      |
//| - Mantém valor anterior ao invés de falhar completamente         |
//| - Volta para start_pos=1 (correto para shift=1 com series)      |
//| - Fix resolve erro em timeframes superiores no início            |
//+------------------------------------------------------------------+
//| v2.31: CRITICAL FIX - CopyBuffer start_pos=0 para indicadores    |
//|        com ArraySetAsSeries=true                                 |
//| - CopyBuffer agora usa start_pos=0 (não 1) pois indicador tem   |
//|   buffers configurados como series (índice 0 = última barra)    |
//| - Removido ArraySetAsSeries do array temp (desnecessário)        |
//| - Fix resolve erro 4806 (ERR_INDICATOR_DATA_NOT_FOUND)          |
//+------------------------------------------------------------------+
//| v1.02: CRITICAL SYNC FIX - BarsCalculated() validation           |
//| - Added synchronization check before buffer copy                 |
//| - Ensures all indicators calculated closed bar before EA reads   |
//| - Prevents reading stale/incomplete data                         |
//+------------------------------------------------------------------+
//| v1.01: Fixed GG TrendBar attachment to chart                     |
//| - Added GG_TrendBar to AttachToChart() function                  |
//| - Now all 5 indicators attach properly                           |
//+------------------------------------------------------------------+
class CIndicatorHub
{
private:
    string          m_symbol;
    ENUM_TIMEFRAMES m_operational_tf;
    
    // ✅ v2.15 FIX: MTF Configuration (para GG handles separados)
    ENUM_TIMEFRAMES m_mtf_timeframes[4];  // [0]=H4, [1]=H1, [2]=M30, [3]=M15
    
    // Indicator handles (MUST check for INVALID_HANDLE)
    // ✅ v2.15 FIX: Array de handles GG - um por timeframe MTF
    int             m_gg_handles[4];      // [0]=H4, [1]=H1, [2]=M30, [3]=M15
    int             m_supertrend_handle;
    int             m_mom_handle;         // OBV_MACD (momentum)
    int             m_rsi_oma_handle;
    int             m_currency_handle;
    
    // ✅ v2.15 FIX: Buffers GG simplificados - um valor por TF MTF
    // Anteriormente: 15 timeframes em buffer único (incorreto)
    // Agora: 4 valores, um por handle MTF (correto)
    double          m_gg_buffer[4];       // [0]=H4, [1]=H1, [2]=M30, [3]=M15
    
    // Supertrend buffers (TrendMagic_MT5)
    // Buffer 0: Upper band (blue line - bullish)
    // Buffer 1: Lower band (red line - bearish)
    double          m_st_upper[2];  // [0]=current, [1]=previous for tolerance
    double          m_st_lower[2];
    
    // Momentum buffers (OBV_MACD)
    // Buffer 0: Histogram value (can be positive or negative)
    // Buffer 1: Color index (0=strong green, 1=strong red, 2=weak green, 3=weak red)
    // ✅ v2.15 FIX: Armazenar histórico do histograma para análise de tendência
    double          m_mom_histogram;          // ✅ Backward compatibility
    double          m_mom_histogram_current;
    double          m_mom_histogram_previous;
    int             m_mom_color_index;  // Mantido para compatibilidade, mas não usado
    
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

    // Visualization control
    bool            m_attached_to_chart;
    int             m_win_mom;
    int             m_win_rsi;
    int             m_win_cs;
    string          m_name_supertrend;
    string          m_name_mom;
    string          m_name_rsi;
    string          m_name_cs;
    // Track GG TrendBar name/window (v2.33 duplication fix)
    string          m_name_gg;
    int             m_attached_win_gg;
    // Remember actual windows we attached to (for robust detach)
    int             m_attached_win_supertrend;
    int             m_attached_win_mom;
    int             m_attached_win_rsi;
    int             m_attached_win_cs;

    // Helper: Get error description
    string ErrorDescription(int error_code)
    {
        switch(error_code)
        {
            case 0: return "Success";
            case 4106: return "Unknown symbol";
            case 4107: return "Invalid price";
            case 4108: return "Invalid ticket";
            case 4109: return "Trade not allowed";
            case 4110: return "Longs not allowed";
            case 4111: return "Shorts not allowed";
            case 4201: return "Object already exists";
            case 4202: return "Unknown object property";
            case 4203: return "Object does not exist";
            case 4204: return "Unknown object type";
            case 4205: return "No object name";
            case 4206: return "Object coordinates error";
            case 4207: return "No specified subwindow";
            case 5200: return "Invalid array access";
            default: return "Error " + IntegerToString(error_code);
        }
    }

    // Helper: delete indicator by short name, trying preferred window first then scanning all
    bool DeleteIndicatorFromChart(const long chart_id, const string name, const int preferred_win)
    {
        if(name == "")
            return true;

        if(preferred_win >= 0)
        {
            if(ChartIndicatorDelete(chart_id, preferred_win, name))
                return true;
        }

        long total_windows_long = 0;
        if(!ChartGetInteger(chart_id, CHART_WINDOWS_TOTAL, 0, total_windows_long))
            total_windows_long = 1; // fallback

        int total_windows = (int)total_windows_long;
        for(int w=0; w<total_windows; ++w)
        {
            int tot = ChartIndicatorsTotal(chart_id, w);
            for(int idx=0; idx<tot; ++idx)
            {
                string nm = ChartIndicatorName(chart_id, w, idx);
                if(nm == name)
                {
                    if(ChartIndicatorDelete(chart_id, w, name))
                        return true;
                }
            }
        }
        return false;
    }

    bool DeleteIndicatorFromChartByPattern(const long chart_id, const string pattern)
    {
        if(pattern == "") return false;
        long total_windows_long = 0;
        if(!ChartGetInteger(chart_id, CHART_WINDOWS_TOTAL, 0, total_windows_long))
            total_windows_long = 1;
        int total_windows = (int)total_windows_long;
        for(int w=0; w<total_windows; ++w)
        {
            int tot = ChartIndicatorsTotal(chart_id, w);
            for(int idx=0; idx<tot; ++idx)
            {
                string nm = ChartIndicatorName(chart_id, w, idx);
                if(StringFind(nm, pattern) >= 0)
                {
                    if(ChartIndicatorDelete(chart_id, w, nm))
                        return true;
                }
            }
        }
        return false;
    }

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

    // OBV MACD (Momentum)
    int                 m_obv_fast_ema;
    int                 m_obv_slow_ema;
    int                 m_obv_signal_sma;
    int                 m_obv_smooth;
    bool                m_obv_use_tick_volume;
    bool                m_obv_show_macd;
    bool                m_obv_show_signal;

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
        
        // ✅ v2.15 FIX: Inicializar array de handles GG
        for(int i = 0; i < 4; i++)
        {
            m_gg_handles[i] = INVALID_HANDLE;
            m_gg_buffer[i] = 0;
        }
        
        m_supertrend_handle = INVALID_HANDLE;
    m_mom_handle = INVALID_HANDLE;
        m_rsi_oma_handle = INVALID_HANDLE;
        m_currency_handle = INVALID_HANDLE;
        
        // ✅ v2.15 FIX: Inicializar variáveis de histograma
        m_mom_histogram = 0.0;
        m_mom_histogram_current = 0.0;
        m_mom_histogram_previous = 0.0;
        m_mom_color_index = 0;
        
        m_cs_available = false;
        m_last_update_time = 0;
    m_attached_to_chart = false;
    m_win_mom = 1; m_win_rsi = 2; m_win_cs = 3;
    m_name_supertrend = ""; m_name_mom = ""; m_name_rsi = ""; m_name_cs = "";
    m_attached_win_supertrend = -1; m_attached_win_mom = -1; m_attached_win_rsi = -1; m_attached_win_cs = -1;
    m_name_gg = ""; m_attached_win_gg = -1; // v2.33
        
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
    //| ✅ v2.15: Init signature extended with enable/disable flags     |
    //+------------------------------------------------------------------+
    bool Init(string symbol, ENUM_TIMEFRAMES operational_tf,
              // ✅ v2.15 NEW: Enable/Disable flags per indicator
              bool enable_gg, bool enable_st, bool enable_macd, bool enable_rsi, bool enable_cs,
              // GG TrendBar
              color gg_up_color, color gg_down_color, color gg_flat_color, color gg_text_color,
              ENUM_BASE_CORNER gg_corner, bool gg_create_objects,
              int gg_adx_period, ENUM_APPLIED_PRICE gg_adx_price, double gg_psar_step, double gg_psar_max,
              // Supertrend (TrendMagic)
              int st_cci_period, int st_atr_period, double st_atr_multiplier,
              // Momentum (OBV MACD)
              int macd_fast_ema, int macd_slow_ema, int macd_signal_sma, int macd_obv_smooth, bool macd_use_tick_volume, bool macd_show_macd, bool macd_show_signal,
              int macd_thresh_period, double macd_thresh_mult,
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
        
    m_obv_fast_ema = macd_fast_ema;
    m_obv_slow_ema = macd_slow_ema;
    m_obv_signal_sma = macd_signal_sma;
    m_obv_smooth = macd_obv_smooth;
    m_obv_use_tick_volume = macd_use_tick_volume;
    m_obv_show_macd = macd_show_macd;
    m_obv_show_signal = macd_show_signal;
    // store threshold controls to pass to indicator
    int _unused_tp = macd_thresh_period; double _unused_tm = macd_thresh_mult; // (kept for future use in hub if needed)
        
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
        
        // ✅ v2.15 CRITICAL FIX: Configurar timeframes MTF ANTES de criar handles
        // Assumindo que operational_tf é M15, os MTF são:
        ENUM_TIMEFRAMES macro1_tf = PERIOD_H4;   // Highest
        ENUM_TIMEFRAMES macro2_tf = PERIOD_H1;   // High
        ENUM_TIMEFRAMES macro3_tf = PERIOD_M30;  // Medium
        // operational_tf já está definido (M15 ou o que vier do EA)
        
        m_mtf_timeframes[0] = macro1_tf;
        m_mtf_timeframes[1] = macro2_tf;
        m_mtf_timeframes[2] = macro3_tf;
        m_mtf_timeframes[3] = operational_tf;
        
        Print("   ✅ MTF Configuration: ", EnumToString(m_mtf_timeframes[0]), " / ",
              EnumToString(m_mtf_timeframes[1]), " / ",
              EnumToString(m_mtf_timeframes[2]), " / ",
              EnumToString(m_mtf_timeframes[3]));
        
        // ✅ v2.15 CRITICAL FIX: GG TrendBar com 4 handles separados
        // Um handle por timeframe MTF (H4, H1, M30, M15)
        // ✅ v2.15: Conditionally load based on enable_gg flag
        if(enable_gg)
        {
            string paths[] = { "NexusConfluenceEA\\", "\\NexusConfluenceEA\\", "", "Market\\" };
            
            for(int tf_idx = 0; tf_idx < 4; tf_idx++)
            {
                ENUM_TIMEFRAMES tf = m_mtf_timeframes[tf_idx];
                bool loaded = false;
                
                for(int path_idx = 0; path_idx < ArraySize(paths); path_idx++)
                {
                    string full_path = paths[path_idx] + "GG_TrendBar_Indicator.ex5";
                    int handle = iCustom(m_symbol, tf, full_path,
                                     m_gg_up_color, m_gg_down_color, m_gg_flat_color, m_gg_text_color,
                                     m_gg_corner, m_gg_create_objects,
                                     m_gg_adx_period, m_gg_adx_price, m_gg_psar_step, m_gg_psar_max);
                    
                    if(handle != INVALID_HANDLE)
                    {
                        m_gg_handles[tf_idx] = handle;
                        Print("   ✅ GG TrendBar [", EnumToString(tf), "] loaded from: ", full_path);
                        loaded = true;
                        break;
                    }
                    
                    // Try without extension
                    string base_path = paths[path_idx] + "GG_TrendBar_Indicator";
                    handle = iCustom(m_symbol, tf, base_path,
                                 m_gg_up_color, m_gg_down_color, m_gg_flat_color, m_gg_text_color,
                                 m_gg_corner, m_gg_create_objects,
                                 m_gg_adx_period, m_gg_adx_price, m_gg_psar_step, m_gg_psar_max);
                    
                    if(handle != INVALID_HANDLE)
                    {
                        m_gg_handles[tf_idx] = handle;
                        Print("   ✅ GG TrendBar [", EnumToString(tf), "] loaded from: ", base_path);
                        loaded = true;
                        break;
                    }
                    
                    ResetLastError();
                }
                
                if(!loaded)
                {
                    Print("   ❌ CRITICAL ERROR: Failed to load GG TrendBar for ", EnumToString(tf));
                    return false;
                }
            }
        }
        else
        {
            Print("   ⚠️ GG TrendBar DISABLED by user input");
        }
        
        // 2. TrendMagic (Supertrend) – try with and without extension
        // ✅ v2.15: Conditionally load based on enable_st flag
        if(enable_st)
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
        else
        {
            Print("   ⚠️ Supertrend DISABLED by user input");
        }
        
    // 3. Momentum (OBV MACD) – legacy WAE removed
        // ✅ v2.15: Conditionally load based on enable_macd flag
        if(enable_macd)
        {
            string paths[] = { "NexusConfluenceEA\\", "\\NexusConfluenceEA\\", "", "Market\\" };
            int handle = INVALID_HANDLE;
            for(int i = 0; i < ArraySize(paths); i++)
            {
                string full_path = paths[i] + "OBV_MACD.ex5";
                handle = iCustom(m_symbol, operational_tf, full_path,
                                 m_obv_fast_ema, m_obv_slow_ema, m_obv_signal_sma,
                                 m_obv_smooth, m_obv_use_tick_volume, m_obv_show_macd, m_obv_show_signal,
                                 macd_thresh_period, macd_thresh_mult);
                if(handle != INVALID_HANDLE)
                {
                    m_mom_handle = handle;
                    Print("✅ Momentum (OBV MACD) loaded from: ", full_path);
                    break;
                }
                string base_path = paths[i] + "OBV_MACD";
                handle = iCustom(m_symbol, operational_tf, base_path,
                                 m_obv_fast_ema, m_obv_slow_ema, m_obv_signal_sma,
                                 m_obv_smooth, m_obv_use_tick_volume, m_obv_show_macd, m_obv_show_signal,
                                 macd_thresh_period, macd_thresh_mult);
                if(handle != INVALID_HANDLE)
                {
                    m_mom_handle = handle;
                    Print("✅ Momentum (OBV MACD) loaded from: ", base_path);
                    break;
                }
                ResetLastError();
            }
            if(m_mom_handle == INVALID_HANDLE)
                return false;
        }
        else
        {
            Print("   ⚠️ OBV MACD DISABLED by user input");
        }
        
        // 4. RSI OMA – try with and without extension
        // ✅ v2.15: Conditionally load based on enable_rsi flag
        if(enable_rsi)
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
        else
        {
            Print("   ⚠️ RSI OMA DISABLED by user input");
        }
        
        // 5. Currency Strength (with fallback for indices) – try with and without extension
        // ✅ v2.15: Conditionally load based on enable_cs flag
        if(enable_cs)
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
        else
        {
            Print("   ⚠️ Currency Strength DISABLED by user input");
            m_cs_available = false;
        }
        
        // Wait for indicators to initialize
        Sleep(1000);
        
        Print("✅ IndicatorHub fully initialized");
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Attach or detach indicators visually from the current chart      |
    //+------------------------------------------------------------------+
    bool AttachToChart(bool attach)
    {
        long chart_id = ChartID();
        if(attach)
        {
            if(m_attached_to_chart)
                return true; // already attached

            Print("📎 Attaching indicators to chart ID ", chart_id);
            bool ok = true;
            
            // Capture current totals to recover names after attach
            int tot_main_before = ChartIndicatorsTotal(chart_id, 0);
            int tot_mom_before  = ChartIndicatorsTotal(chart_id, m_win_mom);
            int tot_rsi_before  = ChartIndicatorsTotal(chart_id, m_win_rsi);
            int tot_cs_before   = ChartIndicatorsTotal(chart_id, m_win_cs);
            
            // ✅ v2.15 FIX: GG TrendBar - anexar apenas o operational TF (índice 3)
            // Não precisamos anexar todos os 4 handles ao gráfico
            if(m_gg_handles[3] != INVALID_HANDLE)
            {
                // v2.33 DUPLICATION GUARD: Check if already present
                bool gg_exists = false;
                int tot_scan = ChartIndicatorsTotal(chart_id, 0);
                for(int s=0; s<tot_scan; ++s)
                {
                    string nm = ChartIndicatorName(chart_id, 0, s);
                    if(StringFind(nm, "GG_TrendBar_Indicator") >= 0)
                    {
                        gg_exists = true;
                        m_name_gg = nm; // track existing instance for proper detach
                        m_attached_win_gg = 0;
                        break;
                    }
                }
                if(gg_exists)
                {
                    Print("ℹ️ GG TrendBar already present on chart - skipping duplicate attachment");
                }
                else
                {
                    ResetLastError();
                    // Anexar apenas o operational TF ao gráfico visual
                    if(!ChartIndicatorAdd(chart_id, 0, m_gg_handles[3]))
                    {
                        int err = GetLastError();
                        Print("❌ Could not attach GG TrendBar [Operational] to window 0 | Error: ", err, " (", ErrorDescription(err), ")");
                        ok = false;
                    }
                    else
                    {
                        int tot_after = ChartIndicatorsTotal(chart_id, 0);
                        if(tot_after > tot_main_before)
                        {
                            tot_main_before = tot_after; // Update for next indicator
                            // Capture name for detach
                            m_name_gg = ChartIndicatorName(chart_id, 0, tot_after - 1);
                            m_attached_win_gg = 0;
                            Print("✅ GG TrendBar [Operational TF] attached to main chart (window 0)");
                        }
                    }
                }
            }
            
            // Supertrend overlays main chart (window 0)
            if(m_supertrend_handle != INVALID_HANDLE)
            {
                ResetLastError();
                if(!ChartIndicatorAdd(chart_id, 0, m_supertrend_handle))
                {
                    int err = GetLastError();
                    Print("❌ Could not attach Supertrend to window 0 | Error: ", err, " (", ErrorDescription(err), ")");
                    ok = false;
                }
                else
                {
                    int tot_after = ChartIndicatorsTotal(chart_id, 0);
                    if(tot_after > tot_main_before)
                    {
                        m_name_supertrend = ChartIndicatorName(chart_id, 0, tot_after - 1);
                        m_attached_win_supertrend = 0;
                        Print("✅ Supertrend attached to main chart (window 0)");
                    }
                }
            }
            
            // Momentum (OBV MACD) in subwindow 1
            if(m_mom_handle != INVALID_HANDLE)
            {
                ResetLastError();
                if(!ChartIndicatorAdd(chart_id, m_win_mom, m_mom_handle))
                {
                    int err = GetLastError();
                    Print("❌ Could not attach OBV MACD to window ", m_win_mom, " | Error: ", err, " (", ErrorDescription(err), ")");
                    ok = false;
                }
                else
                {
                    int tot_after = ChartIndicatorsTotal(chart_id, m_win_mom);
                    if(tot_after > tot_mom_before)
                    {
                        m_name_mom = ChartIndicatorName(chart_id, m_win_mom, tot_after - 1);
                        m_attached_win_mom = m_win_mom;
                        Print("✅ OBV MACD attached to subwindow ", m_win_mom);
                    }
                }
            }
            
            // RSI OMA in subwindow 2
            if(m_rsi_oma_handle != INVALID_HANDLE)
            {
                ResetLastError();
                if(!ChartIndicatorAdd(chart_id, m_win_rsi, m_rsi_oma_handle))
                {
                    int err = GetLastError();
                    Print("❌ Could not attach RSI OMA to window ", m_win_rsi, " | Error: ", err, " (", ErrorDescription(err), ")");
                    ok = false;
                }
                else
                {
                    int tot_after = ChartIndicatorsTotal(chart_id, m_win_rsi);
                    if(tot_after > tot_rsi_before)
                    {
                        m_name_rsi = ChartIndicatorName(chart_id, m_win_rsi, tot_after - 1);
                        m_attached_win_rsi = m_win_rsi;
                        Print("✅ RSI OMA attached to subwindow ", m_win_rsi);
                    }
                }
            }
            
            // Currency Strength in subwindow 3 (if available)
            if(m_cs_available && m_currency_handle != INVALID_HANDLE)
            {
                ResetLastError();
                if(!ChartIndicatorAdd(chart_id, m_win_cs, m_currency_handle))
                {
                    int err = GetLastError();
                    Print("❌ Could not attach Currency Strength to window ", m_win_cs, " | Error: ", err, " (", ErrorDescription(err), ")");
                    ok = false;
                }
                else
                {
                    int tot_after = ChartIndicatorsTotal(chart_id, m_win_cs);
                    if(tot_after > tot_cs_before)
                    {
                        m_name_cs = ChartIndicatorName(chart_id, m_win_cs, tot_after - 1);
                        m_attached_win_cs = m_win_cs;
                        Print("✅ Currency Strength attached to subwindow ", m_win_cs);
                    }
                }
            }
            
            if(ok)
                Print("✅ All indicators successfully attached to chart!");
            else
                Print("⚠️ Some indicators failed to attach - check error messages above");
            
            m_attached_to_chart = true;
            ChartRedraw(chart_id);
            return ok;
        }
        else
        {
            if(!m_attached_to_chart)
                return true; // nothing to do
            bool d1 = DeleteIndicatorFromChart(chart_id, m_name_supertrend, m_attached_win_supertrend)
                      || DeleteIndicatorFromChartByPattern(chart_id, "TrendMagic_MT5");
            bool d2 = DeleteIndicatorFromChart(chart_id, m_name_mom,        m_attached_win_mom)
                      || DeleteIndicatorFromChartByPattern(chart_id, "OBV_MACD");
            bool d3 = DeleteIndicatorFromChart(chart_id, m_name_rsi,        m_attached_win_rsi)
                      || DeleteIndicatorFromChartByPattern(chart_id, "RSIOMA_v2HHLSX_MT5");
            bool d4 = DeleteIndicatorFromChart(chart_id, m_name_cs,         m_attached_win_cs)
                      || DeleteIndicatorFromChartByPattern(chart_id, "CurrencyStrengthMeter_MT5");
            // v2.33: ensure GG TrendBar is also removed
            bool d0 = DeleteIndicatorFromChart(chart_id, m_name_gg, m_attached_win_gg)
                      || DeleteIndicatorFromChartByPattern(chart_id, "GG_TrendBar_Indicator");

            if(!(d0 && d1 && d2 && d3 && d4))
                Print("⚠️ Some indicators could not be auto-removed; they may have been moved/renamed manually.");

            // Reset names and window trackers
            m_name_supertrend = ""; m_name_mom = ""; m_name_rsi = ""; m_name_cs = ""; m_name_gg = "";
            m_attached_win_supertrend = -1; m_attached_win_mom = -1; m_attached_win_rsi = -1; m_attached_win_cs = -1; m_attached_win_gg = -1;
            m_attached_to_chart = false;
            Print("🧹 Indicators detached from chart");
            return true;
        }
    }
    
    //+------------------------------------------------------------------+
    //| Deinitialization - Release all handles                          |
    //+------------------------------------------------------------------+
    //+------------------------------------------------------------------+
    //| Deinitialization - Release all handles                          |
    //+------------------------------------------------------------------+
    void Deinit(void)
    {
        // Ensure indicators are removed from chart if we attached them
        if(m_attached_to_chart)
        {
            AttachToChart(false);
        }
        
        // ✅ v2.15 FIX: Liberar array de handles GG
        for(int i = 0; i < 4; i++)
        {
            if(m_gg_handles[i] != INVALID_HANDLE)
            {
                IndicatorRelease(m_gg_handles[i]);
                m_gg_handles[i] = INVALID_HANDLE;
            }
        }
        
        if(m_supertrend_handle != INVALID_HANDLE)
        {
            IndicatorRelease(m_supertrend_handle);
            m_supertrend_handle = INVALID_HANDLE;
        }
        
        if(m_mom_handle != INVALID_HANDLE)
        {
            IndicatorRelease(m_mom_handle);
            m_mom_handle = INVALID_HANDLE;
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
        
        Print("📊 IndicatorHub released (4 GG handles + 4 other indicators)");
    }
    
    //+------------------------------------------------------------------+
    //| CRITICAL: Update Buffer Cache (ONCE per candle, shift=1 ALWAYS) |
    //| v2.36: NEVER FAILS - ultra-tolerant CopyBuffer error handling   |
    //| v2.35: ULTRA-TOLERANT for backtest - minimal validation         |
    //| v2.34: FIXED non-visual backtest - tolerant sync at startup     |
    //| v1.02: Added BarsCalculated() validation for synchronization    |
    //+------------------------------------------------------------------+
    bool UpdateBufferCache(datetime sync_time)
    {
        // ═══════════════════════════════════════════════════════════════
        // ✅ SYNC FIX v2.36: NUNCA FALHA - fallback para valores anteriores
        // CopyBuffer errors NÃO bloqueiam mais - mantém cache anterior
        // Log detalhado de quais indicadores falharam (primeiras 10x)
        // ═══════════════════════════════════════════════════════════════
        
        // ✅ v2.15 FIX: Verificar BarsCalculated para cada handle GG MTF
        int bars_calculated_gg_min = INT_MAX;
        for(int i = 0; i < 4; i++)
        {
            int bars = BarsCalculated(m_gg_handles[i]);
            if(bars < bars_calculated_gg_min)
                bars_calculated_gg_min = bars;
        }
        
        int bars_calculated_st = BarsCalculated(m_supertrend_handle);
        int bars_calculated_mom = BarsCalculated(m_mom_handle);
        int bars_calculated_rsi = BarsCalculated(m_rsi_oma_handle);
        
        // ✅ FIX v2.36: Se BarsCalculated() falha, loga mas NÃO retorna false
        // Permite EA continuar com valores anteriores do cache
        static int bars_fail_count = 0;
        if(bars_calculated_gg_min <= 0 || bars_calculated_st <= 0 || 
           bars_calculated_mom <= 0 || bars_calculated_rsi <= 0)
        {
            if(bars_fail_count < 10)
            {
                Print("[SYNC v2.15] BarsCalculated não pronto (usando cache anterior): GG_min=", bars_calculated_gg_min,
                      " ST=", bars_calculated_st, " MOM=", bars_calculated_mom, " RSI=", bars_calculated_rsi);
                bars_fail_count++;
            }
            // ✅ v2.36: NÃO retorna false - continua com valores em cache
            // return false;  // REMOVED
        }
        
        // Currency Strength é opcional - se falhar, apenas desabilita Gate 5
        if(m_cs_available && m_currency_handle != INVALID_HANDLE)
        {
            int bars_calculated_cs = BarsCalculated(m_currency_handle);
            if(bars_calculated_cs <= 0)
            {
                static int cs_fail_count = 0;
                if(cs_fail_count < 5)
                {
                    Print("[SYNC v2.36] Currency Strength não pronto (Gate 5 desabilitado): ", bars_calculated_cs);
                    cs_fail_count++;
                }
                // ✅ v2.36: Apenas marca como não disponível, não bloqueia
                // m_cs_available = false;  // Opcional: desabilitar temporariamente
            }
        }
        
        // ✅ Atualizar timestamp independente de sucesso dos buffers
        m_last_update_time = sync_time;
        
        // 1. Copy GG TrendBar (15 BUFFERS at shift=1)
        // ✅ v2.36 FIX: NUNCA falha - mantém valor anterior em caso de erro
        // ✅ v2.21 FIX: GG_TrendBar retorna APENAS valores -1/0/+1 nos buffers 0-14
        
        // ✅ v2.15 CRITICAL FIX: GG TrendBar com handles separados por TF
        // Cada handle retorna apenas o buffer 0 com o valor do próprio TF
        // Não usa mais o buffer array de 15 timeframes
        {
            double temp_gg_val[1];
            static int gg_copy_fails[4];  // Counter per MTF timeframe
            
            for(int tf_idx = 0; tf_idx < 4; tf_idx++)
            {
                if(m_gg_handles[tf_idx] == INVALID_HANDLE)
                {
                    if(gg_copy_fails[tf_idx] < 3)
                    {
                        string tf_names[] = {"H4", "H1", "M30", "M15"};
                        Print("[v2.15] ⚠️ GG TrendBar handle inválido para ", tf_names[tf_idx], " - usando valor em cache");
                        gg_copy_fails[tf_idx]++;
                    }
                    continue;
                }
                
                ResetLastError();
                // ✅ CORRETO: CopyBuffer do handle específico, buffer 0, shift=1
                int copied = CopyBuffer(m_gg_handles[tf_idx], 0, 1, 1, temp_gg_val);
                
                if(copied == 1)
                {
                    m_gg_buffer[tf_idx] = temp_gg_val[0];
                }
                else
                {
                    int err = GetLastError();
                    if(gg_copy_fails[tf_idx] < 3)
                    {
                        string tf_names[] = {"H4", "H1", "M30", "M15"};
                        Print("[v2.15] ⚠️ GG TrendBar[", tf_names[tf_idx], "] CopyBuffer falhou (Erro ", err, ") - mantendo valor anterior: ", m_gg_buffer[tf_idx]);
                        gg_copy_fails[tf_idx]++;
                    }
                }
            }
        }
        
      // Debug printing of GG values removed to avoid log pollution.
      // Use PrintDebugInfo() on-demand if necessary.
        
        // 2. Copy Supertrend (2 candles for tolerance check)
        // ✅ v2.36 FIX: NUNCA falha - mantém valor anterior em erro
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
        
        if(m_supertrend_handle == INVALID_HANDLE)
        {
            static int st_handle_warn = 0;
            if(st_handle_warn < 3)
            {
                Print("[v2.36] ⚠️ Supertrend handle inválido - usando valores em cache");
                st_handle_warn++;
            }
        }
        else
        {
            double temp_up[2], temp_down[2];
            static int st_copy_fail = 0;
            
            int copied_up = CopyBuffer(m_supertrend_handle, 0, 1, 2, temp_up);
            int copied_down = CopyBuffer(m_supertrend_handle, 1, 1, 2, temp_down);
            
            if(copied_up >= 1 && copied_down >= 1)
            {
                // ✅ Sucesso - inversão intencional (compensada em GetSupertrendSignal)
                ArrayCopy(m_st_lower, temp_up);    // Buffer 0 (ALTA) → m_st_lower
                ArrayCopy(m_st_upper, temp_down);  // Buffer 1 (BAIXA) → m_st_upper
            }
            else
            {
                if(st_copy_fail < 3)
                {
                    Print("[v2.36] ⚠️ Supertrend CopyBuffer falhou (Up:", copied_up, " Down:", copied_down, " Erro:", GetLastError(), ") - mantendo valores anteriores");
                    st_copy_fail++;
                }
                // ✅ v2.36: NÃO retorna false - mantém valores anteriores em m_st_upper/lower
            }
        }
        
        // 3. Copy Momentum (OBV MACD) buffers (histogram + color index) for Gate 4
        // ✅ v2.36 FIX: NUNCA falha - mantém valor anterior em erro
        
        if(m_mom_handle == INVALID_HANDLE)
        {
            static int mom_handle_warn = 0;
            if(mom_handle_warn < 3)
            {
                Print("[v2.36] ⚠️ Momentum (OBV MACD) handle inválido - usando valores em cache");
                mom_handle_warn++;
            }
        }
        else
        {
            double temp_mom[1];
            static int mom_copy_fail = 0;
            
            // ✅ v2.15 FIX: Armazenar valor anterior ANTES de sobrescrever
            m_mom_histogram_previous = m_mom_histogram_current;
            
            // Buffer 0: Histogram value (positive or negative)
            int copied_hist = CopyBuffer(m_mom_handle, 0, 1, 1, temp_mom);
            if(copied_hist == 1)
            {
                m_mom_histogram_current = temp_mom[0];
                m_mom_histogram = temp_mom[0]; // ✅ Manter backward compatibility
            }
            else
            {
                if(mom_copy_fail < 3)
                {
                    Print("[v2.36] ⚠️ OBV MACD Histogram CopyBuffer falhou (Erro:", GetLastError(), ") - mantendo valor anterior:", m_mom_histogram_current);
                    mom_copy_fail++;
                }
            }

            // Buffer 1: Color index (0=strong green, 1=strong red, 2=weak green, 3=weak red)
            // ⚠️ DEPRECATED in v2.15: Color index será removido do Gate 4
            // Mantido apenas para backward compatibility temporária
            int copied_color = CopyBuffer(m_mom_handle, 1, 1, 1, temp_mom);
            if(copied_color == 1)
            {
                m_mom_color_index = (int)temp_mom[0];
            }
            else
            {
                if(mom_copy_fail < 3)
                {
                    Print("[v2.36] ⚠️ OBV MACD Color Index CopyBuffer falhou (Erro:", GetLastError(), ") - mantendo valor anterior:", m_mom_color_index);
                }
            }
        }
        
        // 4. Copy RSI OMA (shift=1, single value)
        // ✅ v2.36 FIX: NUNCA falha - mantém valor anterior em erro
        
        if(m_rsi_oma_handle == INVALID_HANDLE)
        {
            static int rsi_handle_warn = 0;
            if(rsi_handle_warn < 3)
            {
                Print("[v2.36] ⚠️ RSI OMA handle inválido - usando valores em cache");
                rsi_handle_warn++;
            }
        }
        else
        {
            double temp_rsi[1];
            static int rsi_copy_fail = 0;
            
            int copied_red = CopyBuffer(m_rsi_oma_handle, 0, 1, 1, temp_rsi);
            if(copied_red == 1)
            {
                m_rsi_red = temp_rsi[0];
            }
            else
            {
                if(rsi_copy_fail < 3)
                {
                    Print("[v2.36] ⚠️ RSI Red CopyBuffer falhou (Erro:", GetLastError(), ") - mantendo valor anterior:", m_rsi_red);
                    rsi_copy_fail++;
                }
            }
            
            int copied_blue = CopyBuffer(m_rsi_oma_handle, 1, 1, 1, temp_rsi);
            if(copied_blue == 1)
            {
                m_rsi_blue = temp_rsi[0];
            }
            else
            {
                if(rsi_copy_fail < 3)
                {
                    Print("[v2.36] ⚠️ RSI Blue CopyBuffer falhou (Erro:", GetLastError(), ") - mantendo valor anterior:", m_rsi_blue);
                }
            }
        }
        
        // 5. Copy Currency Strength (with fallback)
        // ✅ v2.36 FIX: NUNCA falha - Gate 5 simplesmente usa valores anteriores
        if(m_cs_available)
        {
            double temp_cs[1];
            static int cs_copy_fail = 0;
            
            int copied_base = CopyBuffer(m_currency_handle, 0, 1, 1, temp_cs);
            if(copied_base == 1)
            {
                m_cs_base = temp_cs[0];
            }
            else
            {
                if(cs_copy_fail < 3)
                {
                    Print("[v2.36] ⚠️ CS Base CopyBuffer falhou (Erro:", GetLastError(), ") - mantendo valor anterior:", m_cs_base);
                    cs_copy_fail++;
                }
            }
            
            int copied_quote = CopyBuffer(m_currency_handle, 1, 1, 1, temp_cs);
            if(copied_quote == 1)
            {
                m_cs_quote = temp_cs[0];
            }
            else
            {
                if(cs_copy_fail < 3)
                {
                    Print("[v2.36] ⚠️ CS Quote CopyBuffer falhou (Erro:", GetLastError(), ") - mantendo valor anterior:", m_cs_quote);
                }
            }
        }
        
        // ✅ v2.36 CRITICAL: SEMPRE retorna true - EA nunca para por falha de buffer
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Get GG TrendBar signal for specific timeframe                   |
    //| Returns: -1 (bearish), 0 (neutral), +1 (bullish)                |
    //| ✅ v2.15 CRITICAL FIX: Usa handles separados por TF MTF         |
    //+------------------------------------------------------------------+
    int GetGGTrendSignal(ENUM_TIMEFRAMES tf)
    {
        // ✅ v2.15 FIX: Mapear TF para índice do array MTF
        // Array: [0]=H4, [1]=H1, [2]=M30, [3]=M15
        int index = -1;
        
        // Verificar se o TF é um dos 4 MTF configurados
        for(int i = 0; i < 4; i++)
        {
            if(m_mtf_timeframes[i] == tf)
            {
                index = i;
                break;
            }
        }
        
        if(index < 0)
        {
            Print("⚠️ [v2.15] WARNING: Timeframe ", EnumToString(tf), " não está nos MTF configurados");
            Print("   MTF disponíveis: ", EnumToString(m_mtf_timeframes[0]), ", ",
                  EnumToString(m_mtf_timeframes[1]), ", ",
                  EnumToString(m_mtf_timeframes[2]), ", ",
                  EnumToString(m_mtf_timeframes[3]));
            return 0;  // Neutro se TF não está configurado
        }
        
        // ✅ CORRETO: Ler do buffer correspondente ao handle correto
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
    //| Check if Momentum is expanding (Gate 4 - FIRST check)           |
    //| ✅ FIXED v2.33: Use color index to detect STRONG momentum       |
    //| Color 0 = Strong Green (bullish expanding)                      |
    //| Color 1 = Strong Red (bearish expanding)                        |
    //| Color 2 = Weak Green (bullish weakening) - REJECT               |
    //| Color 3 = Weak Red (bearish weakening) - REJECT                 |
    //+------------------------------------------------------------------+
    //| Check if momentum is expanding (Gate 4 - FIRST check)           |
    //| ✅ v2.15 FIX: Usa análise de histograma (valor absoluto + tendência) |
    //| Substitui a dependência do color index (buffers 1-3)            |
    //+------------------------------------------------------------------+
    bool IsMomentumExpanding(void)
    {
        // ⚠️ DEPRECATED OLD METHOD (removed in v2.15)
        // bool is_strong = (m_mom_color_index == 0 || m_mom_color_index == 1);
        
        // ✅ NEW LOGIC: Histogram deve estar ACIMA da threshold E CRESCENDO
        // 1. Verificar se o histograma atual está expandindo (crescendo em valor absoluto)
        // 2. Confirmar que estamos fora da zona de lateral (threshold)
        
        double hist_current = MathAbs(m_mom_histogram_current);
        double hist_previous = MathAbs(m_mom_histogram_previous);
        
        // Expansão = histograma cresceu OU manteve-se significativo
        bool expanding = (hist_current >= hist_previous * 0.95); // 5% tolerance
        
        // Deve estar acima de threshold mínimo (filtrar ruído)
        bool above_threshold = (hist_current > 0.00001); // Dynamic threshold will be added later
        
        return (expanding && above_threshold);
    }
    
    //+------------------------------------------------------------------+
    //| Get Momentum direction                                           |
    //| ✅ FIXED v2.33: Direction comes from histogram sign             |
    //+------------------------------------------------------------------+
    int GetMomentumDirection(void)
    {
        // ✅ v2.15: Usar m_mom_histogram_current para consistência
        if(m_mom_histogram_current > 0.0) return 1;   // Bullish (histogram above zero)
        if(m_mom_histogram_current < 0.0) return -1;  // Bearish (histogram below zero)
        return 0;                              // Neutral (exactly zero)
    }
    
    //+------------------------------------------------------------------+
    //| ✅ v2.15 NEW: Getter para histogram atual                       |
    //+------------------------------------------------------------------+
    double GetMomentumHistogram(void)
    {
        return m_mom_histogram_current;
    }
    
    //+------------------------------------------------------------------+
    //| ✅ v2.15 NEW: Getter para histogram anterior                    |
    //+------------------------------------------------------------------+
    double GetMomentumHistogramPrevious(void)
    {
        return m_mom_histogram_previous;
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
    // NOTE: Realtime (shift=0) accessors were intentionally removed to enforce
    // the project rule: ALWAYS use shift=1 (closed bar) across the system.
    // This avoids repaint and keeps Gate processing consistent and reproducible.
    
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
        // v2.27: Updated for 15 timeframes - M1,M5,M10,M15,M20,M30,H1,H2,H4,H6,H8,H12,D1,W1,MN1
        Print("GG TrendBar: M1=", m_gg_buffer[0], " M5=", m_gg_buffer[1], " M10=", m_gg_buffer[2], 
              " M15=", m_gg_buffer[3], " M20=", m_gg_buffer[4], " M30=", m_gg_buffer[5]);
        Print("GG TrendBar: H1=", m_gg_buffer[6], " H2=", m_gg_buffer[7], " H4=", m_gg_buffer[8], 
              " H6=", m_gg_buffer[9], " H8=", m_gg_buffer[10], " H12=", m_gg_buffer[11]);
        Print("GG TrendBar: D1=", m_gg_buffer[12], " W1=", m_gg_buffer[13], " MN1=", m_gg_buffer[14]);
        Print("Supertrend: Upper[0]=", m_st_upper[0], " Lower[0]=", m_st_lower[0]);
        Print("Momentum: Histogram=", m_mom_histogram, " ColorIndex=", m_mom_color_index,
              " (0=StrongGreen, 1=StrongRed, 2=WeakGreen, 3=WeakRed)");
        Print("RSI OMA: Red=", m_rsi_red, " Blue=", m_rsi_blue);
        Print("Currency Strength: Base=", m_cs_base, " Quote=", m_cs_quote, 
              " Available=", m_cs_available);
        Print("===============================");
    }
};
//+------------------------------------------------------------------+

#endif // INDICATOR_HUB_MQH
