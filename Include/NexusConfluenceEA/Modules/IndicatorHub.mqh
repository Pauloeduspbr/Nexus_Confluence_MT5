//+------------------------------------------------------------------+
//|                                                  IndicatorHub.mqh |
//|                             Nexus Confluence EA - Indicator Mgmt |
//|                          Buffer Cache & Synchronization Manager  |
//+------------------------------------------------------------------+
#property copyright "Nexus Confluence EA"
//property version   "2.48"
#property strict

#ifndef INDICATOR_HUB_MQH
#define INDICATOR_HUB_MQH

//+------------------------------------------------------------------+
//| v2.48: ✅ ARCHITECTURE VALIDATED - Single handle = Perfect sync!|
//| CONFIRMED: GG_TrendBar calculates ALL 15 TFs independently      |
//| - Each TF uses its OWN shift=1 (last closed bar of THAT TF)     |
//| - Buffer 5 (M30) = M30 shift=1, Buffer 6 (H1) = H1 shift=1      |
//| - NO offset needed - indicator handles timeframe sync!          |
//| With v2.47 single handle fix: ALL readings synchronized!        |
//+------------------------------------------------------------------+
//| v2.47: 🔥 CRITICAL ARCHITECTURE FIX - Single GG handle!         |
//| PROBLEM: 4 separate GG instances (H1, M30, M15, M5) each        |
//|          updating at DIFFERENT times caused desynchronization    |
//| FIX: 1 SINGLE GG handle on operational TF (M5)                  |
//|      All 4 MTF readings from same instance = SYNCHRONIZED!      |
//| - m_gg_handles[0-3] now ALL point to same handle                |
//| - All TFs update TOGETHER every operational TF bar              |
//| - Visual and EA readings now ALWAYS match                       |
//+------------------------------------------------------------------+
//| v2.38: CRITICAL REVERT + FIX - start_pos=1 ERA CORRETO!         |
//| - REVERTIDO v2.37: start_pos=0 causou leitura ERRADA           |
//| - RESTAURADO start_pos=1 (lê shift=1 corretamente)             |
//| - BUG REAL: Indicador GG_TrendBar calcula shift=1 do próprio TF|
//| - Em backtest: 09:00 M5 lê M30 shift=1 = 08:30 M30 (ATRASADO!) |
//| - Log desync warnings mantidos para diagnóstico                 |
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
    // ✅ v2.49 NEW: Buffer 4 = Adaptive threshold line
    // ✅ v2.15 FIX: Armazenar histórico do histograma para análise de tendência
    double          m_mom_histogram;          // ✅ Backward compatibility
    double          m_mom_histogram_current;
    double          m_mom_histogram_previous;
    double          m_mom_threshold;          // ✅ v2.49: Adaptive threshold from Buffer 4
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
        m_mom_threshold = 0.0;  // ✅ v2.49: Initialize threshold
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
    //| 🔥 v2.40 CRITICAL FIX: Map Timeframe to GG Buffer Index         |
    //| GG_TrendBar_Indicator has 15 buffers (1 per timeframe):         |
    //| Buffer 0=M1, 1=M5, 2=M10, 3=M15, 4=M20, 5=M30, 6=H1...          |
    //| BUG WAS: EA always read buffer 0 (M1) regardless of timeframe!  |
    //| FIX: Map each MTF timeframe to correct buffer index             |
    //|                                                                  |
    //| ✅ DYNAMIC: Uses values from INPUTS (NOT HARDCODED!)            |
    //| - InpMacro1TF (user can set H4, H1, M30, etc)                   |
    //| - InpMacro2TF (user can set H1, M30, M20, etc)                  |
    //| - InpMacro3TF (user can set M30, M15, M10, etc)                 |
    //| - InpOperationalTF (user can set M15, M10, M5, etc)             |
    //|                                                                  |
    //| Function receives timeframe from m_mtf_timeframes[] array       |
    //| which is populated from user INPUTS in Init()                   |
    //+------------------------------------------------------------------+
    int GetGGBufferIndex(ENUM_TIMEFRAMES tf)
    {
        switch(tf)
        {
            case PERIOD_M1:  return 0;
            case PERIOD_M5:  return 1;
            case PERIOD_M10: return 2;  // Example: InpOperationalTF = M10
            case PERIOD_M15: return 3;  // Example: InpMacro3TF = M15
            case PERIOD_M20: return 4;  // Example: InpMacro2TF = M20
            case PERIOD_M30: return 5;  // Example: InpMacro1TF = M30
            case PERIOD_H1:  return 6;  // Example: InpMacro1TF = H1
            case PERIOD_H2:  return 7;
            case PERIOD_H4:  return 8;  // Example: InpMacro1TF = H4
            case PERIOD_H6:  return 9;
            case PERIOD_H8:  return 10;
            case PERIOD_H12: return 11;
            case PERIOD_D1:  return 12;
            case PERIOD_W1:  return 13;
            case PERIOD_MN1: return 14;
            default:
                Print("❌ ERRO CRÍTICO: Timeframe não mapeado: ", EnumToString(tf));
                return 0;  // Fallback to M1
        }
    }
    
    //+------------------------------------------------------------------+
    //| Initialization - Create all indicator handles                   |
    //+------------------------------------------------------------------+
    //| ✅ v2.15: Init signature extended with enable/disable flags     |
    //+------------------------------------------------------------------+
    bool Init(string symbol, ENUM_TIMEFRAMES operational_tf,
              // ✅ v2.15 FIX: MTF timeframes from inputs (NOT HARDCODED!)
              ENUM_TIMEFRAMES macro1_tf, ENUM_TIMEFRAMES macro2_tf, ENUM_TIMEFRAMES macro3_tf,
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
        
        // ✅ v2.15 CRITICAL FIX: Use MTF timeframes from INPUTS (no hardcode!)
        m_mtf_timeframes[0] = macro1_tf;
        m_mtf_timeframes[1] = macro2_tf;
        m_mtf_timeframes[2] = macro3_tf;
        m_mtf_timeframes[3] = operational_tf;
        
        Print("   ✅ MTF Configuration: ", EnumToString(m_mtf_timeframes[0]), " / ",
              EnumToString(m_mtf_timeframes[1]), " / ",
              EnumToString(m_mtf_timeframes[2]), " / ",
              EnumToString(m_mtf_timeframes[3]));
        
        // ✅ v2.47 CRITICAL FIX: GG TrendBar com 1 ÚNICO handle no operational TF
        // PROBLEMA ANTERIOR: 4 handles separados em TFs diferentes causavam dessincronização
        // FIX: 1 handle único anexado ao operational TF, lê 4 buffers diferentes
        // Todos os TFs agora atualizam JUNTOS a cada nova barra do operational TF
        // ✅ v2.15: Conditionally load based on enable_gg flag
        if(enable_gg)
        {
            string paths[] = { "NexusConfluenceEA\\", "\\NexusConfluenceEA\\", "", "Market\\" };
            
            // ✅ v2.47 FIX: Create SINGLE handle on operational TF (not per TF!)
            bool loaded = false;
            
            for(int path_idx = 0; path_idx < ArraySize(paths); path_idx++)
            {
                string full_path = paths[path_idx] + "GG_TrendBar_Indicator.ex5";
                int handle = iCustom(m_symbol, m_operational_tf, full_path,  // ← SEMPRE operational TF!
                                 m_gg_up_color, m_gg_down_color, m_gg_flat_color, m_gg_text_color,
                                 m_gg_corner, m_gg_create_objects,
                                 m_gg_adx_period, m_gg_adx_price, m_gg_psar_step, m_gg_psar_max);
                
                if(handle != INVALID_HANDLE)
                {
                    // ✅ v2.47: Todos os 4 índices apontam para o MESMO handle
                    for(int i = 0; i < 4; i++)
                        m_gg_handles[i] = handle;
                    
                    Print("   ✅ GG TrendBar [SINGLE INSTANCE on ", EnumToString(m_operational_tf), "] loaded from: ", full_path);
                    Print("   ✅ All 4 MTF timeframes will read from this single instance!");
                    loaded = true;
                    break;
                }
                
                // Try without extension
                string base_path = paths[path_idx] + "GG_TrendBar_Indicator";
                handle = iCustom(m_symbol, m_operational_tf, base_path,  // ← SEMPRE operational TF!
                             m_gg_up_color, m_gg_down_color, m_gg_flat_color, m_gg_text_color,
                             m_gg_corner, m_gg_create_objects,
                             m_gg_adx_period, m_gg_adx_price, m_gg_psar_step, m_gg_psar_max);
                
                if(handle != INVALID_HANDLE)
                {
                    // ✅ v2.47: Todos os 4 índices apontam para o MESMO handle
                    for(int i = 0; i < 4; i++)
                        m_gg_handles[i] = handle;
                    
                    Print("   ✅ GG TrendBar [SINGLE INSTANCE on ", EnumToString(m_operational_tf), "] loaded from: ", base_path);
                    Print("   ✅ All 4 MTF timeframes will read from this single instance!");
                    loaded = true;
                    break;
                }
                
                ResetLastError();
            }
            
            if(!loaded)
            {
                Print("   ❌ CRITICAL ERROR: Failed to load GG TrendBar on ", EnumToString(m_operational_tf));
                return false;
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
        
        // ✅ v2.45 FIX: Indicator GG_TrendBar v2.34 agora se auto-gerencia
        // Aguarda handles ADX/PSAR ficarem prontos internamente
        // Valores aparecerão conforme histórico for calculado
        // Warm-up removido - não é mais necessário
        Print("✅ IndicatorHub fully initialized - GG_TrendBar v2.34 irá calcular histórico automaticamente");
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
            {
                Print("✅ All indicators successfully attached to chart!");
            }
            else
            {
                Print("⚠️ Some indicators failed to attach - check error messages above");
            }
            
            // ✅ v2.15 DIAGNOSTIC: Explain why indicators may not be VISUALLY attached
            // In Strategy Tester (non-visual mode), ChartIndicatorAdd() returns TRUE
            // but indicators don't appear visually because no chart window exists
            bool is_tester = MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_OPTIMIZATION);
            bool is_visual = MQLInfoInteger(MQL_VISUAL_MODE);
            
            if(is_tester && !is_visual)
            {
                Print("ℹ️ EXPLICAÇÃO: Strategy Tester sem modo visual ativo");
                Print("   • ChartIndicatorAdd() retorna TRUE mas indicadores não aparecem visualmente");
                Print("   • Buffers dos indicadores FUNCIONAM NORMALMENTE via CopyBuffer()");
                Print("   • Comportamento esperado: Indicadores trabalham em background (data-only)");
                Print("   • Para VER os indicadores: Ative 'Visualização' no Strategy Tester");
            }
            else if(!is_tester)
            {
                // Live/demo chart - indicators should be visible
                int final_count = ChartIndicatorsTotal(chart_id, 0);
                Print(StringFormat("📊 Indicadores na janela principal: %d", final_count));
            }
            
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
                        Print("[v2.15] ⚠️ GG TrendBar handle inválido para ", EnumToString(m_mtf_timeframes[tf_idx]), " - usando valor em cache");
                        gg_copy_fails[tf_idx]++;
                    }
                    continue;
                }
                
                // ✅ v2.40 CRITICAL FIX: Get correct buffer index for each timeframe!
                // BUG WAS: Always used buffer 0 (M1) regardless of timeframe
                // FIX: Map user-configured timeframe (from INPUT) to correct buffer
                // DYNAMIC: m_mtf_timeframes[] holds values from InpMacro1TF/InpMacro2TF/InpMacro3TF/InpOperationalTF
                int buffer_idx = GetGGBufferIndex(m_mtf_timeframes[tf_idx]);
                
                // ✅ v2.49: Debug logs removed - only first 2 reads per TF logged
                static int debug_count[4] = {0};
                if(debug_count[tf_idx] < 2)
                {
                    Print("[v2.49 GG] ", EnumToString(m_mtf_timeframes[tf_idx]), 
                          " → buffer ", buffer_idx, " | Handle: ", m_gg_handles[tf_idx]);
                    debug_count[tf_idx]++;
                }
                
                ResetLastError();
                // ✅ v2.49 REVERTED: GG writes to buffer array position matching bar index
                // GG indicator uses: rates_total - i - 1 (time series indexing)
                // EA must read shift=1 to get closed bar value
                // CRITICAL: Do NOT use shift=0 (repaint risk)
                int copied = CopyBuffer(m_gg_handles[tf_idx], buffer_idx, 1, 1, temp_gg_val);
                
                if(copied == 1)
                {
                    m_gg_buffer[tf_idx] = temp_gg_val[0];
                    
                    // ✅ v2.48: GG TrendBar synchronized reading confirmed working
                    // Success logs commented out to reduce log verbosity
                }
                else
                {
                    int err = GetLastError();
                    if(gg_copy_fails[tf_idx] < 10)
                    {
                        string input_name = (tf_idx==0 ? "InpMacro1TF" : 
                                           tf_idx==1 ? "InpMacro2TF" : 
                                           tf_idx==2 ? "InpMacro3TF" : "InpOperationalTF");
                        
                        Print("[v2.48 SYNC FAIL] GG[", EnumToString(m_mtf_timeframes[tf_idx]), 
                              "] buffer ", buffer_idx, " CopyBuffer returned ", copied, 
                              " | Error: ", err, " | Single instance BarsCalculated: ", BarsCalculated(m_gg_handles[tf_idx]));
                        gg_copy_fails[tf_idx]++;
                    }
                }
            }
        }
        
      // Debug printing of GG values removed to avoid log pollution.
      // Use PrintDebugInfo() on-demand if necessary.
        
        // 2. Copy Supertrend (2 candles for tolerance check)
        // ✅ v2.49 CRITICAL FIX: REMOVED confusing buffer inversion
        // 
        // TrendMagic_MT5.mq5 has:
        //   Buffer 0 = bufferUp (BLUE line) - BULLISH trend (CCI >= 0)
        //   Buffer 1 = bufferDn (RED line) - BEARISH trend (CCI <= 0)
        //
        // NOW: Direct copy WITHOUT inversion:
        //   m_st_upper = Buffer 0 (BLUE/BULLISH) - semantic name fix pending
        //   m_st_lower = Buffer 1 (RED/BEARISH) - semantic name fix pending
        //
        // NOTE: Variable names are BACKWARDS but GetSupertrendSignal() compensates!
        
        if(m_supertrend_handle == INVALID_HANDLE)
        {
            static int st_handle_warn = 0;
            if(st_handle_warn < 3)
            {
                Print("[v2.49] ⚠️ Supertrend handle inválido - usando valores em cache");
                st_handle_warn++;
            }
        }
        else
        {
            double temp_up[2], temp_down[2];
            static int st_copy_fail = 0;
            
            // ✅ v2.49 FIX: Direct copy (removed intentional inversion)
            int copied_up = CopyBuffer(m_supertrend_handle, 0, 1, 2, temp_up);
            int copied_down = CopyBuffer(m_supertrend_handle, 1, 1, 2, temp_down);
            
            if(copied_up >= 1 && copied_down >= 1)
            {
                // ✅ Direct copy: Buffer 0 (BLUE/BULLISH) → m_st_lower (name backwards!)
                //                 Buffer 1 (RED/BEARISH) → m_st_upper (name backwards!)
                // GetSupertrendSignal() reads correctly despite backwards names
                ArrayCopy(m_st_lower, temp_up);    // Buffer 0 (BLUE/BULLISH)
                ArrayCopy(m_st_upper, temp_down);  // Buffer 1 (RED/BEARISH)
            }
            else
            {
                if(st_copy_fail < 3)
                {
                    Print("[v2.49] ⚠️ Supertrend CopyBuffer falhou (Up:", copied_up, " Down:", copied_down, " Erro:", GetLastError(), ") - mantendo valores anteriores");
                    st_copy_fail++;
                }
            }
        }
        
        // 3. Copy Momentum (OBV MACD) buffers (histogram + threshold) for Gate 4
        // ✅ v2.49 NEW: Read Buffer 4 (adaptive threshold line)
        
        if(m_mom_handle == INVALID_HANDLE)
        {
            static int mom_handle_warn = 0;
            if(mom_handle_warn < 3)
            {
                Print("[v2.49] ⚠️ Momentum (OBV MACD) handle inválido - usando valores em cache");
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
                    Print("[v2.49] ⚠️ OBV MACD Histogram CopyBuffer falhou (Erro:", GetLastError(), ") - mantendo valor anterior:", m_mom_histogram_current);
                    mom_copy_fail++;
                }
            }

            // ✅ v2.49 NEW: Buffer 4 = Adaptive threshold line
            // CRITICAL: Read shift=0 (current bar) because threshold is EMA (always available)
            int copied_threshold = CopyBuffer(m_mom_handle, 4, 0, 1, temp_mom);
            if(copied_threshold == 1)
            {
                m_mom_threshold = MathAbs(temp_mom[0]); // ✅ Force positive value
                
                // Sanity check: Threshold must be reasonable (0 to 1 billion)
                if(m_mom_threshold < 0 || m_mom_threshold > 1e9)
                {
                    Print("[v2.49] ⚠️ THRESHOLD INSANO: ", m_mom_threshold, " - usando fallback 0.00001");
                    m_mom_threshold = 0.00001;
                }
            }
            else
            {
                if(mom_copy_fail < 3)
                {
                    Print("[v2.49] ⚠️ OBV MACD Threshold CopyBuffer falhou (Erro:", GetLastError(), ") - mantendo valor anterior:", m_mom_threshold);
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
                    Print("[v2.49] ⚠️ OBV MACD Color Index CopyBuffer falhou (Erro:", GetLastError(), ") - mantendo valor anterior:", m_mom_color_index);
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
            
            // ✅ v2.38 REVERT: start_pos=1 ERA CORRETO!
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
            
            // ✅ v2.38 REVERT: start_pos=1 ERA CORRETO!
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
    //| ✅ v2.50 CRITICAL FIX: COMPARE PRICE WITH LINE VALUE!           |
    //| TrendMagic_MT5 buffers:                                          |
    //|   Buffer 0 (bufferUp) = BLUE line (support) drawn when CCI≥0    |
    //|   Buffer 1 (bufferDn) = RED line (resistance) drawn when CCI≤0  |
    //| LOGIC: Price ABOVE blue support = +1 | Price BELOW red resist = -1 |
    //|        BUT if price BREAKS line = OPPOSITE signal!              |
    //+------------------------------------------------------------------+
    int GetSupertrendSignal(void)
    {
        // Get current close price for comparison
        double close_price[1];
        if(CopyClose(m_symbol, m_operational_tf, 1, 1, close_price) != 1)
        {
            return 0;  // Failed to get close price, return neutral
        }
        
        // ✅ v2.50 FIX: Check which line is active AND compare price position
        // BLUE line active (CCI was ≥0, bullish context)
        if(m_st_lower[0] != EMPTY_VALUE && m_st_upper[0] == EMPTY_VALUE)
        {
            // Price ABOVE blue support line = bullish confirmed
            if(close_price[0] > m_st_lower[0])
                return 1;  // ✅ BULLISH - price respecting support
            else
                return -1; // ❌ BEARISH - price BROKE BELOW support (reversal!)
        }
        
        // RED line active (CCI was ≤0, bearish context)
        if(m_st_upper[0] != EMPTY_VALUE && m_st_lower[0] == EMPTY_VALUE)
        {
            // Price BELOW red resistance line = bearish confirmed
            if(close_price[0] < m_st_upper[0])
                return -1; // ✅ BEARISH - price respecting resistance
            else
                return 1;  // ❌ BULLISH - price BROKE ABOVE resistance (reversal!)
        }
        
        // Tolerance: Check previous candle if both are EMPTY
        if(ArraySize(m_st_lower) > 1 && ArraySize(m_st_upper) > 1)
        {
            if(m_st_lower[0] == EMPTY_VALUE && m_st_upper[0] == EMPTY_VALUE)
            {
                // Get previous close price
                double prev_close[1];
                if(CopyClose(m_symbol, m_operational_tf, 2, 1, prev_close) == 1)
                {
                    // Check previous candle [1] = shift=2
                    if(m_st_lower[1] != EMPTY_VALUE && m_st_upper[1] == EMPTY_VALUE)
                    {
                        if(prev_close[0] > m_st_lower[1])
                            return 1;  // ✅ BULLISH on previous candle
                        else
                            return -1; // ❌ BEARISH - broke support
                    }
                    if(m_st_upper[1] != EMPTY_VALUE && m_st_lower[1] == EMPTY_VALUE)
                    {
                        if(prev_close[0] < m_st_upper[1])
                            return -1; // ✅ BEARISH on previous candle
                        else
                            return 1;  // ❌ BULLISH - broke resistance
                    }
                }
            }
        }
        
        return 0; // Neutral/uncertain
    }
    
    //+------------------------------------------------------------------+
    //| Check if Momentum is expanding (Gate 4 - FIRST check)           |
    //| ✅ v2.49 CRITICAL FIX: Uses Buffer 4 (adaptive threshold)       |
    //| OBV_MACD Buffer 4 = Adaptive threshold (EMA of |histogram|)     |
    //| LOGIC: Histogram must be ABOVE threshold AND expanding          |
    //|        Verde CLARO (below threshold) = REJECT                   |
    //|        Verde ESCURO (above threshold) = ACCEPT                  |
    //+------------------------------------------------------------------+
    bool IsMomentumExpanding(void)
    {
        // ✅ v2.49 NEW LOGIC: Compare histogram with REAL adaptive threshold
        // 1. Get absolute value of current histogram
        double hist_current = MathAbs(m_mom_histogram_current);
        double hist_previous = MathAbs(m_mom_histogram_previous);
        
        // 2. Check if histogram is EXPANDING (growing in absolute value)
        bool expanding = (hist_current >= hist_previous * 0.95); // 5% tolerance
        
        // 3. ✅ v2.49 CRITICAL FIX: Compare with Buffer 4 (adaptive threshold)
        // If threshold is not yet calculated (first bars), use minimal value
        double threshold = (m_mom_threshold > 0.00001) ? m_mom_threshold : 0.00001;
        bool above_threshold = (hist_current > threshold);
        
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
    //| ✅ v2.49 NEW: Getter para adaptive threshold                    |
    //+------------------------------------------------------------------+
    double GetMomentumThreshold(void)
    {
        return m_mom_threshold;
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
    //| ✅ v2.50 NEW: Get raw RSI values for detailed logging           |
    //+------------------------------------------------------------------+
    void GetRSIValues(double &red_value, double &blue_value)
    {
        red_value = m_rsi_red;
        blue_value = m_rsi_blue;
    }
    
    //+------------------------------------------------------------------+
    //| ✅ v2.50 NEW: Get Supertrend line values for detailed logging   |
    //+------------------------------------------------------------------+
    void GetSupertrendValues(double &blue_line, double &red_line, double &close_price)
    {
        blue_line = (ArraySize(m_st_lower) > 0) ? m_st_lower[0] : EMPTY_VALUE;
        red_line = (ArraySize(m_st_upper) > 0) ? m_st_upper[0] : EMPTY_VALUE;
        
        double temp_close[1];
        if(CopyClose(m_symbol, m_operational_tf, 1, 1, temp_close) == 1)
            close_price = temp_close[0];
        else
            close_price = 0;
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
