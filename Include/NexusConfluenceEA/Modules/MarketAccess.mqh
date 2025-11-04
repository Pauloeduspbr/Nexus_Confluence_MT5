//+------------------------------------------------------------------+
//|                                                  MarketAccess.mqh |
//|                                      Nexus Confluence EA - Gate 1 |
//|                          Market Conditions & Spread Filtering    |
//+------------------------------------------------------------------+
#property copyright "Nexus Confluence EA"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Market Type Enumeration                                          |
//+------------------------------------------------------------------+
enum ENUM_MARKET_TYPE
{
    MARKET_FOREX,       // Forex pairs (EURUSD, GBPJPY, etc)
    MARKET_B3,          // Brazilian futures (WIN, WDO)
    MARKET_INDICES,     // Indices (US30, NDX, etc)
    MARKET_METALS,      // Metals (XAUUSD, XAGUSD)
    MARKET_CRYPTO,      // Cryptocurrencies (BTCUSD, etc)
    MARKET_UNKNOWN      // Unknown/other
};

//+------------------------------------------------------------------+
//| MarketAccess Class - Gate 1 Implementation                       |
//+------------------------------------------------------------------+
class CMarketAccess
{
private:
    string          m_symbol;
    double          m_point;
    int             m_digits;
    double          m_tick_size;
    double          m_tick_value;
    double          m_lot_step;
    double          m_lot_min;
    double          m_lot_max;
    
    // Spread monitoring
    double          m_spread_array[];
    int             m_spread_period;
    int             m_spread_index;
    
    // Market configuration
    ENUM_MARKET_TYPE m_market_type;
    int             m_max_spread_points;
    double          m_spread_multiplier;
    
    // Trading hours
    bool            m_use_time_filter;
    int             m_start_hour;
    int             m_start_minute;
    int             m_end_hour;
    int             m_end_minute;
    
    // Weekly filter (individual days: Sunday=0, Monday=1, ..., Saturday=6)
    bool            m_trade_on_days[7];

    // Log throttling for weekly filter to avoid repetitive messages
    int             m_last_print_day;        // last day-of-week seen (0..6)
    bool            m_last_day_block_logged; // whether 'disabled' was already logged for the current day
    
public:
    //+------------------------------------------------------------------+
    //| Constructor                                                      |
    //+------------------------------------------------------------------+
    CMarketAccess(void)
    {
        m_symbol = _Symbol;
        m_spread_period = 20;
        m_spread_index = 0;
        m_market_type = MARKET_UNKNOWN;
        m_max_spread_points = 20;
        m_spread_multiplier = 1.5;
        m_use_time_filter = false;
        
        // Initialize all days as enabled by default
        for(int i = 0; i < 7; i++)
            m_trade_on_days[i] = true;

    // Initialize log throttling
    m_last_print_day = -1;
    m_last_day_block_logged = false;
    }
    
    //+------------------------------------------------------------------+
    //| Destructor                                                       |
    //+------------------------------------------------------------------+
    ~CMarketAccess(void)
    {
        ArrayFree(m_spread_array);
    }
    
    //+------------------------------------------------------------------+
    //| Initialization                                                   |
    //+------------------------------------------------------------------+
    bool Init(string symbol, int spread_period, double spread_multiplier, 
              int max_spread, bool use_time_filter, string start_time, 
              string end_time, bool trade_sunday, bool trade_monday, 
              bool trade_tuesday, bool trade_wednesday, bool trade_thursday,
              bool trade_friday, bool trade_saturday)
    {
        m_symbol = symbol;
        m_spread_period = spread_period;
        m_spread_multiplier = spread_multiplier;
        m_max_spread_points = max_spread;
        m_use_time_filter = use_time_filter;
        
        // Set weekly filter
        m_trade_on_days[0] = trade_sunday;
        m_trade_on_days[1] = trade_monday;
        m_trade_on_days[2] = trade_tuesday;
        m_trade_on_days[3] = trade_wednesday;
        m_trade_on_days[4] = trade_thursday;
        m_trade_on_days[5] = trade_friday;
        m_trade_on_days[6] = trade_saturday;
        
        // Get symbol properties
        m_point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
        m_digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
        m_tick_size = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
        m_tick_value = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
        m_lot_step = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
        m_lot_min = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
        m_lot_max = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
        
        // Validate symbol properties
        if(m_point == 0 || m_digits == 0)
        {
            Print("❌ ERROR: Failed to get symbol properties for ", m_symbol);
            return false;
        }
        
        // Initialize spread array
        ArrayResize(m_spread_array, m_spread_period);
        ArrayInitialize(m_spread_array, 0);
        
        // Detect market type
        m_market_type = DetectMarketType();
        
        // Parse time filter
        if(m_use_time_filter)
        {
            if(!ParseTimeString(start_time, m_start_hour, m_start_minute) ||
               !ParseTimeString(end_time, m_end_hour, m_end_minute))
            {
                Print("⚠️ WARNING: Invalid time format, disabling time filter");
                m_use_time_filter = false;
            }
        }
        
        Print(StringFormat("✅ MarketAccess initialized | Type: %s | Spread: %.1fx median | Max: %dpts",
              EnumToString(m_market_type), m_spread_multiplier, m_max_spread_points));
        
        // Log weekly filter settings
        string days_enabled = "";
        string day_names[] = {"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"};
        for(int i = 0; i < 7; i++)
        {
            if(m_trade_on_days[i])
                days_enabled += day_names[i] + " ";
        }
        if(days_enabled != "")
            Print("📅 Trading allowed on: ", days_enabled);
        else
            Print("⚠️ WARNING: No days enabled for trading!");
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Detect Market Type                                              |
    //+------------------------------------------------------------------+
    ENUM_MARKET_TYPE DetectMarketType(void)
    {
        string symbol_upper = m_symbol;
        StringToUpper(symbol_upper);
        
        // Forex detection
        if(StringFind(symbol_upper, "USD") >= 0 || 
           StringFind(symbol_upper, "EUR") >= 0 ||
           StringFind(symbol_upper, "GBP") >= 0 ||
           StringFind(symbol_upper, "JPY") >= 0 ||
           StringFind(symbol_upper, "AUD") >= 0 ||
           StringFind(symbol_upper, "CAD") >= 0 ||
           StringFind(symbol_upper, "CHF") >= 0 ||
           StringFind(symbol_upper, "NZD") >= 0)
        {
            // Exclude metals
            if(StringFind(symbol_upper, "XAU") < 0 && 
               StringFind(symbol_upper, "XAG") < 0 &&
               StringFind(symbol_upper, "GOLD") < 0 &&
               StringFind(symbol_upper, "SILVER") < 0)
            {
                return MARKET_FOREX;
            }
        }
        
        // B3 detection
        if(StringFind(symbol_upper, "WIN") >= 0 || 
           StringFind(symbol_upper, "WDO") >= 0)
        {
            return MARKET_B3;
        }
        
        // Indices detection
        if(StringFind(symbol_upper, "US30") >= 0 ||
           StringFind(symbol_upper, "NAS100") >= 0 ||
           StringFind(symbol_upper, "SPX") >= 0 ||
           StringFind(symbol_upper, "NDX") >= 0 ||
           StringFind(symbol_upper, "DOW") >= 0)
        {
            return MARKET_INDICES;
        }
        
        // Metals detection
        if(StringFind(symbol_upper, "XAU") >= 0 ||
           StringFind(symbol_upper, "XAG") >= 0 ||
           StringFind(symbol_upper, "GOLD") >= 0 ||
           StringFind(symbol_upper, "SILVER") >= 0)
        {
            return MARKET_METALS;
        }
        
        // Crypto detection
        if(StringFind(symbol_upper, "BTC") >= 0 ||
           StringFind(symbol_upper, "ETH") >= 0 ||
           StringFind(symbol_upper, "CRYPTO") >= 0)
        {
            return MARKET_CRYPTO;
        }
        
        return MARKET_UNKNOWN;
    }
    
    //+------------------------------------------------------------------+
    //| GATE 1: Check if market is tradeable                            |
    //+------------------------------------------------------------------+
    bool IsTradingAllowed(void)
    {
        // Check if trading is enabled for symbol
        if(!SymbolInfoInteger(m_symbol, SYMBOL_TRADE_MODE))
        {
            Print("⚠️ Trading disabled for ", m_symbol);
            return false;
        }
        
        // Check weekly filter (individual days)
        if(!IsDayTradingAllowed())
        {
            return false;
        }
        
        // Check time filter
        if(m_use_time_filter && !IsWithinTradingHours())
        {
            return false;
        }
        
        // Check spread filter
        if(!CheckSpreadFilter())
        {
            return false;
        }
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Dynamic Spread Filter                                           |
    //+------------------------------------------------------------------+
    bool CheckSpreadFilter(void)
    {
        double current_spread = GetCurrentSpread();
        
        // Update spread array
        m_spread_array[m_spread_index] = current_spread;
        m_spread_index = (m_spread_index + 1) % m_spread_period;
        
    // Absolute maximum in points (always enforced)
    double max_absolute = m_max_spread_points * m_point;

        // Warm-up: require at least half of the window filled with non-zero values
        int valid_count = 0;
        for(int i=0;i<m_spread_period;i++)
            if(m_spread_array[i] > 0.0) valid_count++;

        if(valid_count < (m_spread_period/2))
        {
            // During warm-up, only enforce absolute max to avoid blocking all trades
            if(current_spread > max_absolute)
            {
                Print(StringFormat("⚠️ Spread too high (warm-up): %.1f pts | AbsLimit: %d",
                      current_spread / m_point, m_max_spread_points));
                return false;
            }
            return true;
        }

        // Calculate median spread from NON-ZERO samples once warmed up
        int nz_count = 0;
        double median_spread = GetMedianSpreadNonZero(nz_count);

        // If after warm-up we still don't have enough non-zero samples,
        // fallback to absolute cap only (don't use dynamic threshold yet)
        if(nz_count < (m_spread_period/2) || median_spread <= 0.0)
        {
            if(current_spread > max_absolute)
            {
                Print(StringFormat("⚠️ Spread too high: %.1f pts (AbsLimit: %d)",
                      current_spread / m_point, m_max_spread_points));
                return false;
            }
            return true;
        }

        double max_allowed = median_spread * m_spread_multiplier;

        if(current_spread > max_allowed || current_spread > max_absolute)
        {
            Print(StringFormat("⚠️ Spread too high: %.1f pts (Median: %.1f | DynMax: %.1f | AbsLimit: %d)",
                  current_spread / m_point, median_spread / m_point, 
                  max_allowed / m_point, m_max_spread_points));
            return false;
        }
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Get Current Spread                                              |
    //+------------------------------------------------------------------+
    double GetCurrentSpread(void)
    {
        double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
        double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        return ask - bid;
    }
    
    //+------------------------------------------------------------------+
    //| Calculate Median Spread                                         |
    //+------------------------------------------------------------------+
    // Calculate median considering only non-zero entries. Returns 0 if none.
    double GetMedianSpreadNonZero(int &non_zero_count)
    {
        // Count non-zero entries
        non_zero_count = 0;
        for(int i=0;i<m_spread_period;i++)
        {
            if(m_spread_array[i] > 0.0)
                non_zero_count++;
        }

        if(non_zero_count == 0)
            return 0.0;

        // Copy non-zero values into a temp array
        double temp_array[];
        ArrayResize(temp_array, non_zero_count);
        int idx = 0;
        for(int i=0;i<m_spread_period;i++)
        {
            if(m_spread_array[i] > 0.0)
            {
                temp_array[idx++] = m_spread_array[i];
            }
        }

        ArraySort(temp_array);
        int middle = non_zero_count / 2;
        return temp_array[middle];
    }
    
    //+------------------------------------------------------------------+
    //| Check if current day of week is allowed for trading             |
    //+------------------------------------------------------------------+
    bool IsDayTradingAllowed(void)
    {
        MqlDateTime dt;
        TimeCurrent(dt);
        
        // day_of_week: 0=Sunday, 1=Monday, 2=Tuesday, 3=Wednesday, 4=Thursday, 5=Friday, 6=Saturday
        int day = dt.day_of_week;

        // Reset daily throttling when day changes
        if(day != m_last_print_day)
        {
            m_last_print_day = day;
            m_last_day_block_logged = false;
        }
        
        if(!m_trade_on_days[day])
        {
            string day_names[] = {"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"};
            // Print only once per day to avoid log pollution
            if(!m_last_day_block_logged)
            {
                Print("⏸️ Trading disabled for ", day_names[day]);
                m_last_day_block_logged = true;
            }
            return false;
        }
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Check Trading Hours                                             |
    //+------------------------------------------------------------------+
    bool IsWithinTradingHours(void)
    {
        MqlDateTime dt;
        TimeCurrent(dt);
        
        int current_minutes = dt.hour * 60 + dt.min;
        int start_minutes = m_start_hour * 60 + m_start_minute;
        int end_minutes = m_end_hour * 60 + m_end_minute;

        // Handle windows that do not cross midnight
        if(start_minutes <= end_minutes)
        {
            return !(current_minutes < start_minutes || current_minutes >= end_minutes);
        }

        // Window crosses midnight: allow if after start OR before end
        if(current_minutes >= start_minutes || current_minutes < end_minutes)
            return true;
        return false;
    }
    
    //+------------------------------------------------------------------+
    //| Normalize Price                                                 |
    //+------------------------------------------------------------------+
    double NormalizePrice(double price)
    {
        return NormalizeDouble(price, m_digits);
    }
    
    //+------------------------------------------------------------------+
    //| Normalize Lot Size                                              |
    //+------------------------------------------------------------------+
    double NormalizeLot(double lot)
    {
        lot = MathMax(m_lot_min, lot);
        lot = MathMin(m_lot_max, lot);
        lot = MathRound(lot / m_lot_step) * m_lot_step;
        
        return NormalizeDouble(lot, 2);
    }
    
    //+------------------------------------------------------------------+
    //| Parse Time String (HH:MM)                                       |
    //+------------------------------------------------------------------+
    bool ParseTimeString(string time_str, int &hour, int &minute)
    {
        StringTrimLeft(time_str);
        StringTrimRight(time_str);
        
        int pos = StringFind(time_str, ":");
        if(pos < 0)
            return false;
        
        hour = (int)StringToInteger(StringSubstr(time_str, 0, pos));
        minute = (int)StringToInteger(StringSubstr(time_str, pos + 1));
        
        if(hour < 0 || hour > 23 || minute < 0 || minute > 59)
            return false;
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Getters                                                          |
    //+------------------------------------------------------------------+
    ENUM_MARKET_TYPE GetMarketType(void) const { return m_market_type; }
    double GetPoint(void) const { return m_point; }
    int GetDigits(void) const { return m_digits; }
};
//+------------------------------------------------------------------+
