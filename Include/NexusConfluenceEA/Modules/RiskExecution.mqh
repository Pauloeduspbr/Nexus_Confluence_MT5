//+------------------------------------------------------------------+
//|                                                 RiskExecution.mqh |
//|                        Nexus Confluence EA - Order Execution      |
//|                         Trade Management & Risk Control           |
//+------------------------------------------------------------------+
#property copyright "Nexus Confluence EA"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include "Core.mqh"
#include "MarketAccess.mqh"

//+------------------------------------------------------------------+
//| RiskExecution Class - Trade execution and management             |
//+------------------------------------------------------------------+
class CRiskExecution
{
private:
    CTrade          m_trade;
    CPositionInfo   m_position;
    CCore           *m_core;
    CMarketAccess   *m_market;
    
    // Trade parameters
    int             m_magic_number;
    double          m_lot_size;
    int             m_stop_loss_points;
    int             m_take_profit_points;
    int             m_max_slippage_points;
    
    string          m_symbol;
    
    // Last trade tracking
    ulong           m_last_ticket;
    datetime        m_last_trade_time;
    
    // Retry configuration
    int             m_max_retries;
    int             m_retry_delay_ms;
    
public:
    //+------------------------------------------------------------------+
    //| Constructor                                                      |
    //+------------------------------------------------------------------+
    CRiskExecution(void)
    {
        m_core = NULL;
        m_market = NULL;
        m_magic_number = 0;
        m_lot_size = 0.01;
        m_stop_loss_points = 100;
        m_take_profit_points = 200;
        m_max_slippage_points = 10;
        m_symbol = _Symbol;
        m_last_ticket = 0;
        m_last_trade_time = 0;
        m_max_retries = 3;
        m_retry_delay_ms = 1000;
    }
    
    //+------------------------------------------------------------------+
    //| Destructor                                                       |
    //+------------------------------------------------------------------+
    ~CRiskExecution(void)
    {
    }
    
    //+------------------------------------------------------------------+
    //| Initialization                                                   |
    //+------------------------------------------------------------------+
    bool Init(CCore *core, CMarketAccess *market, int magic_number, 
              double lot_size, int stop_loss, int take_profit, int max_slippage)
    {
        if(core == NULL || market == NULL)
        {
            Print("❌ ERROR: Invalid module references in RiskExecution");
            return false;
        }
        
        m_core = core;
        m_market = market;
        m_magic_number = magic_number;
        m_lot_size = lot_size;
        m_stop_loss_points = stop_loss;
        m_take_profit_points = take_profit;
        m_max_slippage_points = max_slippage;
        
        // Configure CTrade
        m_trade.SetExpertMagicNumber(m_magic_number);
        m_trade.SetDeviationInPoints(m_max_slippage_points);
        m_trade.SetTypeFilling(ORDER_FILLING_FOK);
        m_trade.SetAsyncMode(false); // Synchronous execution
        
        Print(StringFormat("✅ RiskExecution initialized | Magic: %d | Lot: %.2f | SL: %d | TP: %d",
              m_magic_number, m_lot_size, m_stop_loss_points, m_take_profit_points));
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Check if position is open for this EA                           |
    //+------------------------------------------------------------------+
    bool HasOpenPosition(void)
    {
        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            if(m_position.SelectByIndex(i))
            {
                if(m_position.Symbol() == m_symbol && 
                   m_position.Magic() == m_magic_number)
                {
                    return true;
                }
            }
        }
        
        return false;
    }
    
    //+------------------------------------------------------------------+
    //| Execute BUY order                                                |
    //+------------------------------------------------------------------+
    bool ExecuteBuy(string comment)
    {
        // Validate trade mode allows opening BUY
        if(!m_market->IsBuyAllowedNow())
        {
            int mode = m_market->GetTradeMode();
            m_core->LogMessage(2, StringFormat("⏸️ BUY blocked by trade mode | Mode:%d (DISABLED/CLOSEONLY/SHORTONLY)", mode));
            return false;
        }

        // Validate lot size
        double lot = m_market.NormalizeLot(m_lot_size);
        if(lot <= 0)
        {
            m_core->LogMessage(1, "❌ ERROR: Invalid lot size");
            return false;
        }
        
        // Get current prices
        double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
        double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        double point = m_market.GetPoint();
        
        // Calculate SL and TP
        double sl = m_market.NormalizePrice(bid - (m_stop_loss_points * point));
        double tp = m_market.NormalizePrice(bid + (m_take_profit_points * point));
        
        // Log trade attempt
    m_core->LogMessage(2, StringFormat("🔵 Attempting BUY | Lot: %.2f | Entry: %.5f | SL: %.5f | TP: %.5f",
                          lot, ask, sl, tp));
        
        // Execute with retry logic
        bool result = ExecuteOrderWithRetry(ORDER_TYPE_BUY, lot, ask, sl, tp, comment);
        
        if(result)
        {
            m_last_ticket = m_trade.ResultOrder();
            m_last_trade_time = TimeCurrent();
            m_core->SetLastTradeTime(m_last_trade_time);
            
            m_core->LogMessage(1, StringFormat("✅ BUY EXECUTED | Ticket: %llu | %s | Entry: %.5f",
                              m_last_ticket, comment, ask));
            
            // Update state machine
            m_core->UpdateStateMachine(STATE_ORDER_SENT);
        }
        else
        {
            m_core->LogMessage(1, StringFormat("❌ BUY FAILED | Error: %d | %s",
                              GetLastError(), m_trade.ResultRetcodeDescription()));
        }
        
        return result;
    }
    
    //+------------------------------------------------------------------+
    //| Execute SELL order                                               |
    //+------------------------------------------------------------------+
    bool ExecuteSell(string comment)
    {
        // Validate trade mode allows opening SELL
        if(!m_market->IsSellAllowedNow())
        {
            int mode = m_market->GetTradeMode();
            m_core->LogMessage(2, StringFormat("⏸️ SELL blocked by trade mode | Mode:%d (DISABLED/CLOSEONLY/LONGONLY)", mode));
            return false;
        }

        // Validate lot size
        double lot = m_market.NormalizeLot(m_lot_size);
        if(lot <= 0)
        {
            m_core->LogMessage(1, "❌ ERROR: Invalid lot size");
            return false;
        }
        
        // Get current prices
        double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
        double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        double point = m_market.GetPoint();
        
        // Calculate SL and TP
        double sl = m_market.NormalizePrice(ask + (m_stop_loss_points * point));
        double tp = m_market.NormalizePrice(ask - (m_take_profit_points * point));
        
        // Log trade attempt
    m_core->LogMessage(2, StringFormat("🔴 Attempting SELL | Lot: %.2f | Entry: %.5f | SL: %.5f | TP: %.5f",
                          lot, bid, sl, tp));
        
        // Execute with retry logic
        bool result = ExecuteOrderWithRetry(ORDER_TYPE_SELL, lot, bid, sl, tp, comment);
        
        if(result)
        {
            m_last_ticket = m_trade.ResultOrder();
            m_last_trade_time = TimeCurrent();
            m_core->SetLastTradeTime(m_last_trade_time);
            
            m_core->LogMessage(1, StringFormat("✅ SELL EXECUTED | Ticket: %llu | %s | Entry: %.5f",
                              m_last_ticket, comment, bid));
            
            // Update state machine
            m_core->UpdateStateMachine(STATE_ORDER_SENT);
        }
        else
        {
            m_core->LogMessage(1, StringFormat("❌ SELL FAILED | Error: %d | %s",
                              GetLastError(), m_trade.ResultRetcodeDescription()));
        }
        
        return result;
    }
    
    //+------------------------------------------------------------------+
    //| Execute order with retry logic                                  |
    //+------------------------------------------------------------------+
    bool ExecuteOrderWithRetry(ENUM_ORDER_TYPE order_type, double lot, 
                               double price, double sl, double tp, string comment)
    {
        int attempts = 0;
        bool result = false;
        
        while(attempts < m_max_retries && !result)
        {
            attempts++;
            
            // Execute order
            if(order_type == ORDER_TYPE_BUY)
            {
                result = m_trade.Buy(lot, m_symbol, price, sl, tp, comment);
            }
            else if(order_type == ORDER_TYPE_SELL)
            {
                result = m_trade.Sell(lot, m_symbol, price, sl, tp, comment);
            }
            
            if(result)
            {
                // Validate result
                if(m_trade.ResultRetcode() == TRADE_RETCODE_DONE)
                {
                    return true;
                }
                else if(m_trade.ResultRetcode() == TRADE_RETCODE_PLACED)
                {
                    return true; // Order placed successfully
                }
                else
                {
                    // Check if error is recoverable
                    if(IsRecoverableError(m_trade.ResultRetcode()))
                    {
                        m_core->LogMessage(2, StringFormat("⚠️ Recoverable error on attempt %d: %s",
                                          attempts, m_trade.ResultRetcodeDescription()));
                        
                        Sleep(m_retry_delay_ms);
                        result = false; // Retry
                        continue;
                    }
                    else
                    {
                        // Non-recoverable error
                        return false;
                    }
                }
            }
            else
            {
                // Check error code
                int error_code = GetLastError();
                
                if(IsRecoverableError(error_code))
                {
                    m_core->LogMessage(2, StringFormat("⚠️ Recoverable error on attempt %d: %d",
                                      attempts, error_code));
                    
                    Sleep(m_retry_delay_ms);
                }
                else
                {
                    // Non-recoverable error
                    return false;
                }
            }
        }
        
        return false;
    }
    
    //+------------------------------------------------------------------+
    //| Check if error is recoverable (worthy of retry)                 |
    //+------------------------------------------------------------------+
    bool IsRecoverableError(int error_code)
    {
        switch(error_code)
        {
            case TRADE_RETCODE_REQUOTE:
            case TRADE_RETCODE_CONNECTION:
            case TRADE_RETCODE_PRICE_CHANGED:
            case TRADE_RETCODE_TIMEOUT:
            case TRADE_RETCODE_PRICE_OFF:
            case TRADE_RETCODE_REJECT:
                return true;
                
            default:
                return false;
        }
    }
    
    //+------------------------------------------------------------------+
    //| Get position info                                                |
    //+------------------------------------------------------------------+
    bool GetPositionInfo(double &profit, double &open_price, string &comment)
    {
        if(!HasOpenPosition())
            return false;
        
        profit = m_position.Profit();
        open_price = m_position.PriceOpen();
        comment = m_position.Comment();
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Check if new candle allows new trade                            |
    //+------------------------------------------------------------------+
    bool CanTradeOnNewCandle(datetime current_candle_time)
    {
    return m_core->IsNewCandleForTrade(current_candle_time);
    }
    
    //+------------------------------------------------------------------+
    //| Close position                                                   |
    //+------------------------------------------------------------------+
    bool ClosePosition(string reason = "Manual close")
    {
        if(!HasOpenPosition())
            return false;
        
        ulong ticket = m_position.Ticket();
        
        bool result = m_trade.PositionClose(ticket);
        
        if(result)
        {
            m_core->LogMessage(1, StringFormat("✅ Position CLOSED | Ticket: %llu | Reason: %s",
                              ticket, reason));
            
            m_core->UpdateStateMachine(STATE_IDLE);
        }
        else
        {
            m_core->LogMessage(1, StringFormat("❌ Position CLOSE FAILED | Ticket: %llu | Error: %s",
                              ticket, m_trade.ResultRetcodeDescription()));
        }
        
        return result;
    }
    
    //+------------------------------------------------------------------+
    //| Getters                                                          |
    //+------------------------------------------------------------------+
    ulong GetLastTicket(void) const { return m_last_ticket; }
    datetime GetLastTradeTime(void) const { return m_last_trade_time; }
    
    //+------------------------------------------------------------------+
    //| Setters                                                          |
    //+------------------------------------------------------------------+
    void SetLotSize(double lot) { m_lot_size = lot; }
    void SetStopLoss(int points) { m_stop_loss_points = points; }
    void SetTakeProfit(int points) { m_take_profit_points = points; }
};
//+------------------------------------------------------------------+