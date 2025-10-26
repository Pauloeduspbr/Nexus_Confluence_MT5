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
    bool            m_skip_monday_open;
    int             m_max_spread_points;
    double          m_spread_multiplier;
    
    // Trading hours
    bool            m_use_time_filter;
    int             m_start_hour;
    int             m_start_minute;
    int             m_end_hour;
    int             m_end_minute;
    
    // Monday open protection
    datetime        m_monday_open_time;
    int             m_monday_skip_minutes;
    
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
        m_skip_monday_open = false;
        m_max_spread_points = 20;
        m_spread_multiplier = 1.5;
        m_use_time_filter = false;
        m_monday_open_time = 0;
        m_monday_skip_minutes = 30;
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
              int max_spread, bool skip_monday, bool use_time_filter,
              string start_time, string end_time)
    {
        m_symbol = symbol;
        m_spread_period = spread_period;
        m_spread_multiplier = spread_multiplier;
        m_max_spread_points = max_spread;
        m_skip_monday_open = skip_monday;
        m_use_time_filter = use_time_filter;
        
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
        
        // Check Monday Open skip (Forex/Metals/Indices)
        if(m_skip_monday_open && ShouldSkipMondayOpen())
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
        
        // Calculate median spread
        double median_spread = GetMedianSpread();
        
        // Check against multiplier
        double max_allowed = median_spread * m_spread_multiplier;
        
        // Also check absolute maximum
        double max_absolute = m_max_spread_points * m_point;
        
        if(current_spread > max_allowed || current_spread > max_absolute)
        {
            Print(StringFormat("⚠️ Spread too high: %.1f pts (Median: %.1f | Max: %.1f | Limit: %d)",
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
    double GetMedianSpread(void)
    {
        double temp_array[];
        ArrayResize(temp_array, m_spread_period);
        ArrayCopy(temp_array, m_spread_array);
        ArraySort(temp_array);
        
        int middle = m_spread_period / 2;
        return temp_array[middle];
    }
    
    //+------------------------------------------------------------------+
    //| Skip Monday Open Protection                                     |
    //+------------------------------------------------------------------+
    bool ShouldSkipMondayOpen(void)
    {
        MqlDateTime dt;
        datetime current_time = TimeCurrent(dt);
        
        // Only apply to Forex, Metals, and Indices
        if(m_market_type != MARKET_FOREX && 
           m_market_type != MARKET_METALS && 
           m_market_type != MARKET_INDICES)
        {
            return false;
        }
        
        // Check if it's Monday
        if(dt.day_of_week != 1)
        {
            m_monday_open_time = 0; // Reset
            return false;
        }
        
        // Set Monday open time (00:00 Monday server time)
        if(m_monday_open_time == 0)
        {
            MqlDateTime monday_dt = dt;
            monday_dt.hour = 0;
            monday_dt.min = 0;
            monday_dt.sec = 0;
            m_monday_open_time = StructToTime(monday_dt);
            
            Print("🗓️ Monday detected - Skip window active for ", m_monday_skip_minutes, " minutes");
        }
        
        // Check if we're within skip window
        int minutes_since_open = (int)((current_time - m_monday_open_time) / 60);
        
        if(minutes_since_open < m_monday_skip_minutes)
        {
            Print(StringFormat("⏸️ Monday Open skip active (%d/%d minutes)", 
                  minutes_since_open, m_monday_skip_minutes));
            return true;
        }
        
        return false;
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
        
        if(current_minutes < start_minutes || current_minutes >= end_minutes)
        {
            return false;
        }
        
        return true;
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
