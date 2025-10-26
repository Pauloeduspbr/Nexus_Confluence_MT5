//+------------------------------------------------------------------+
//|                                                  SignalEngine.mqh |
//|                           Nexus Confluence EA - Signal Processing|
//|                            Gates 0-5 Implementation & Scoring     |
//+------------------------------------------------------------------+
#property copyright "Nexus Confluence EA"
#property version   "1.00"
#property strict

#include "Core.mqh"
#include "MarketAccess.mqh"
#include "IndicatorHub.mqh"

//+------------------------------------------------------------------+
//| Signal Classification Enumeration                                |
//+------------------------------------------------------------------+
enum ENUM_SIGNAL_CLASS
{
    SIGNAL_NONE,      // No valid signal
    SIGNAL_REJECT,    // Rejected by gates
    SIGNAL_GOOD,      // Good signal (score >= 2, not all aligned)
    SIGNAL_PREMIUM    // Premium signal (all 4 timeframes aligned)
};

//+------------------------------------------------------------------+
//| Signal Direction Enumeration                                     |
//+------------------------------------------------------------------+
enum ENUM_SIGNAL_DIRECTION
{
    SIGNAL_DIR_NONE,
    SIGNAL_DIR_BUY,
    SIGNAL_DIR_SELL
};

//+------------------------------------------------------------------+
//| SignalEngine Class - Implements all 6 gates                      |
//+------------------------------------------------------------------+
class CSignalEngine
{
private:
    CCore           *m_core;
    CMarketAccess   *m_market;
    CIndicatorHub   *m_indicators;
    
    // MTF Configuration
    ENUM_TIMEFRAMES m_macro1_tf;      // Highest timeframe
    ENUM_TIMEFRAMES m_macro2_tf;      // High timeframe
    ENUM_TIMEFRAMES m_macro3_tf;      // Medium timeframe
    ENUM_TIMEFRAMES m_operational_tf; // Operational timeframe
    
    // Signal state
    int             m_mtf_score;
    ENUM_SIGNAL_CLASS m_signal_class;
    ENUM_SIGNAL_DIRECTION m_signal_direction;
    
    // Gate results (for logging)
    bool            m_gate_results[6];
    string          m_gate_messages[6];
    
    // Minimum score threshold
    int             m_min_score;
    
public:
    //+------------------------------------------------------------------+
    //| Constructor                                                      |
    //+------------------------------------------------------------------+
    CSignalEngine(void)
    {
        m_core = NULL;
        m_market = NULL;
        m_indicators = NULL;
        
        m_macro1_tf = PERIOD_H4;
        m_macro2_tf = PERIOD_H1;
        m_macro3_tf = PERIOD_M30;
        m_operational_tf = PERIOD_M15;
        
        m_mtf_score = 0;
        m_signal_class = SIGNAL_NONE;
        m_signal_direction = SIGNAL_DIR_NONE;
        m_min_score = 2;
        
        ArrayInitialize(m_gate_results, false);
    }
    
    //+------------------------------------------------------------------+
    //| Destructor                                                       |
    //+------------------------------------------------------------------+
    ~CSignalEngine(void)
    {
    }
    
    //+------------------------------------------------------------------+
    //| Initialization                                                   |
    //+------------------------------------------------------------------+
    bool Init(CCore *core, CMarketAccess *market, CIndicatorHub *indicators,
              ENUM_TIMEFRAMES macro1, ENUM_TIMEFRAMES macro2, 
              ENUM_TIMEFRAMES macro3, ENUM_TIMEFRAMES operational,
              int min_score = 2)
    {
        if(core == NULL || market == NULL || indicators == NULL)
        {
            Print("❌ ERROR: Invalid module references in SignalEngine");
            return false;
        }
        
        m_core = core;
        m_market = market;
        m_indicators = indicators;
        
        m_macro1_tf = macro1;
        m_macro2_tf = macro2;
        m_macro3_tf = macro3;
        m_operational_tf = operational;
        m_min_score = min_score;
        
        Print(StringFormat("✅ SignalEngine initialized | MTF: %s/%s/%s/%s | MinScore: %d",
              EnumToString(m_macro1_tf), EnumToString(m_macro2_tf),
              EnumToString(m_macro3_tf), EnumToString(m_operational_tf),
              m_min_score));
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| GATE 0: Synchronization (handled by Core)                       |
    //+------------------------------------------------------------------+
    bool ProcessGate0_Sync(void)
    {
        // Validation already done by Core::IsNewCandle()
        // Just verify buffer sync is valid
        bool result = m_core.IsBufferSyncValid();
        
        m_gate_results[0] = result;
        m_gate_messages[0] = result ? "G0✓ Sync" : "G0✗ Desync";
        
        return result;
    }
    
    //+------------------------------------------------------------------+
    //| GATE 1: Market Access                                            |
    //+------------------------------------------------------------------+
    bool ProcessGate1_Market(void)
    {
        bool result = m_market.IsTradingAllowed();
        
        m_gate_results[1] = result;
        m_gate_messages[1] = result ? "G1✓ Market" : "G1✗ Blocked";
        
        if(!result)
        {
            m_core.LogMessage(3, "Gate 1 REJECTED: Market not tradeable");
        }
        
        return result;
    }
    
    //+------------------------------------------------------------------+
    //| GATE 2: Multi-Timeframe Analysis (HIERARCHICAL LOGIC)           |
    //| ORDEM DE VALIDAÇÃO: H4 → H1 (MANDANTES) → M30/M15 (PREMIUM/GOOD)|
    //| CRITICAL: H4 e H1 devem estar alinhados primeiro!                |
    //| PREMIUM: H4+H1 alinhados E M30+M15 alinhados                     |
    //| GOOD: H4+H1 alinhados E (M30 OU M15 alinhado)                    |
    //| REJECT: H4 e H1 NÃO alinhados OU nenhum M30/M15 alinhado        |
    //+------------------------------------------------------------------+
    bool ProcessGate2_MTF(void)
    {
        // Get GG TrendBar signals - ORDEM: H4 → H1 → M30 → M15 (macro para micro)
        int gg_h4  = m_indicators.GetGGTrendSignal(m_macro1_tf);      // H4
        int gg_h1  = m_indicators.GetGGTrendSignal(m_macro2_tf);      // H1
        int gg_m30 = m_indicators.GetGGTrendSignal(m_macro3_tf);      // M30
        int gg_m15 = m_indicators.GetGGTrendSignal(m_operational_tf); // M15
        
        // Calculate MTF Score (for logging)
        m_mtf_score = gg_h4 + gg_h1 + gg_m30 + gg_m15;
        
        // PASSO 1: H4 e H1 são MANDANTES - devem estar alinhados (ambos +1 ou ambos -1)
        bool h4_h1_bullish = (gg_h4 == 1 && gg_h1 == 1);
        bool h4_h1_bearish = (gg_h4 == -1 && gg_h1 == -1);
        
        if(!h4_h1_bullish && !h4_h1_bearish)
        {
            // H4 e H1 NÃO alinhados → REJECT (não chama filtros)
            m_signal_class = SIGNAL_REJECT;
            m_signal_direction = SIGNAL_DIR_NONE;
            
            m_gate_results[2] = false;
            m_gate_messages[2] = "G2✗ H4/H1 desalinhados";
            
            m_core.LogMessage(2, StringFormat("[OPERACIONAL] ❌ Gate 2 REJECTED: H4/H1 não alinhados | H4:%+d H1:%+d M30:%+d M15:%+d",
                              gg_h4, gg_h1, gg_m30, gg_m15));
            return false;
        }
        
        // PASSO 2: H4+H1 alinhados - determinar direção
        if(h4_h1_bullish)
        {
            m_signal_direction = SIGNAL_DIR_BUY;
        }
        else if(h4_h1_bearish)
        {
            m_signal_direction = SIGNAL_DIR_SELL;
        }
        
        // PASSO 3A: CRÍTICO - Verificar se M30 ou M15 estão OPOSTOS aos macros
        // Se TF operacional está contra a tendência macro → REJEITAR
        bool m30_opposite = (h4_h1_bullish && gg_m30 == -1) || (h4_h1_bearish && gg_m30 == 1);
        bool m15_opposite = (h4_h1_bullish && gg_m15 == -1) || (h4_h1_bearish && gg_m15 == 1);
        
        if(m30_opposite || m15_opposite)
        {
            // REJECT: TF operacional contra a tendência macro
            m_signal_class = SIGNAL_REJECT;
            m_signal_direction = SIGNAL_DIR_NONE;
            
            m_gate_results[2] = false;
            m_gate_messages[2] = "G2✗ TF operacional oposto";
            
            string opposite_tf = m30_opposite ? "M30" : "M15";
            m_core.LogMessage(2, StringFormat("[OPERACIONAL] ❌ Gate 2 REJECTED: %s oposto aos macros | H4:%+d H1:%+d M30:%+d M15:%+d",
                              opposite_tf, gg_h4, gg_h1, gg_m30, gg_m15));
            return false;
        }
        
        // PASSO 3B: Analisar M30 e M15 para classificar PREMIUM vs GOOD
        // Neutros (0) são ACEITOS nesta etapa
        bool m30_aligned = (h4_h1_bullish && gg_m30 == 1) || (h4_h1_bearish && gg_m30 == -1);
        bool m15_aligned = (h4_h1_bullish && gg_m15 == 1) || (h4_h1_bearish && gg_m15 == -1);
        
        if(m30_aligned && m15_aligned)
        {
            // PREMIUM: Todos 4 timeframes alinhados (H4+H1+M30+M15 mesma cor)
            m_signal_class = SIGNAL_PREMIUM;
        }
        else if(m30_aligned || m15_aligned)
        {
            // GOOD: H4+H1 alinhados + pelo menos 1 operacional alinhado
            // Neutros (0) são aceitos como GOOD
            m_signal_class = SIGNAL_GOOD;
        }
        else
        {
            // GOOD: Ambos M30 e M15 neutros (0) mas H4+H1 alinhados
            // Aceita pois não há oposição (foi validado no PASSO 3A)
            m_signal_class = SIGNAL_GOOD;
        }
        
        // PASSO 4: PASSED - Log com ordem hierárquica (H4 → H1 → M30 → M15)
        bool result = true;
        
        m_gate_results[2] = result;
        m_gate_messages[2] = StringFormat("G2✓ %s Score:%+d", 
                             EnumToString(m_signal_class),
                             m_mtf_score);
        
        m_core.LogMessage(2, StringFormat("✅ Gate 2 PASSED: %s %s | Score:%+d | H4:%+d → H1:%+d → M30:%+d → M15:%+d",
                          EnumToString(m_signal_class),
                          EnumToString(m_signal_direction),
                          m_mtf_score,
                          gg_h4, gg_h1, gg_m30, gg_m15));
        
        return result;
    }
    
    //+------------------------------------------------------------------+
    //| GATE 3: Supertrend Direction (with 1 candle tolerance)          |
    //| TOLERÂNCIA: ST=0 permitido para GOOD e PREMIUM                  |
    //|             ST oposto permitido APENAS para PREMIUM              |
    //+------------------------------------------------------------------+
    bool ProcessGate3_Supertrend(void)
    {
        int st_signal = m_indicators.GetSupertrendSignal();
        
        bool result = false;
        
        // Check alignment with MTF direction
        if(m_signal_direction == SIGNAL_DIR_BUY)
        {
            if(st_signal == 1)
            {
                // Perfect alignment
                result = true;
            }
            else if(st_signal == 0)
            {
                // Neutral Supertrend - allow for GOOD and PREMIUM (tolerance)
                result = (m_signal_class == SIGNAL_GOOD || m_signal_class == SIGNAL_PREMIUM);
            }
            else if(st_signal == -1)
            {
                // Opposite - ONLY allow for PREMIUM (1 candle lag tolerance)
                result = (m_signal_class == SIGNAL_PREMIUM);
            }
        }
        else if(m_signal_direction == SIGNAL_DIR_SELL)
        {
            if(st_signal == -1)
            {
                // Perfect alignment
                result = true;
            }
            else if(st_signal == 0)
            {
                // Neutral Supertrend - allow for GOOD and PREMIUM (tolerance)
                result = (m_signal_class == SIGNAL_GOOD || m_signal_class == SIGNAL_PREMIUM);
            }
            else if(st_signal == 1)
            {
                // Opposite - ONLY allow for PREMIUM (1 candle lag tolerance)
                result = (m_signal_class == SIGNAL_PREMIUM);
            }
        }
        
        m_gate_results[3] = result;
        m_gate_messages[3] = StringFormat("G3%s ST:%+d", result ? "✓" : "✗", st_signal);
        
        if(!result)
        {
            m_core.LogMessage(2, StringFormat("[OPERACIONAL] ❌ Gate 3 REJECTED: Supertrend=%+d vs Direction=%s (Class=%s)",
                              st_signal, EnumToString(m_signal_direction), EnumToString(m_signal_class)));
        }
        
        return result;
    }
    
    //+------------------------------------------------------------------+
    //| GATE 4: Momentum - WAE FIRST, then RSI OMA (CRITICAL ORDER)     |
    //+------------------------------------------------------------------+
    bool ProcessGate4_Momentum(void)
    {
        // STEP 1: Check WAE expansion (filters lateral markets)
        bool wae_expanding = m_indicators.IsWAEExpanding();
        
        if(!wae_expanding)
        {
            m_gate_results[4] = false;
            m_gate_messages[4] = "G4✗ WAE flat";
            m_core.LogMessage(2, "[OPERACIONAL] ❌ Gate 4 REJECTED: WAE not expanding (lateral market)");
            return false;
        }
        
        // Get WAE direction
        int wae_direction = m_indicators.GetWAEDirection();
        
        // STEP 2: Confirm with RSI OMA (confirms directional pressure)
        int rsi_signal = m_indicators.GetRSIOMASignal();
        
        // Both must align with MTF direction
        bool result = false;
        
        if(m_signal_direction == SIGNAL_DIR_BUY)
        {
            result = (wae_direction == 1 && rsi_signal == 1);
        }
        else if(m_signal_direction == SIGNAL_DIR_SELL)
        {
            result = (wae_direction == -1 && rsi_signal == -1);
        }
        
        m_gate_results[4] = result;
        m_gate_messages[4] = StringFormat("G4%s WAE:%+d RSI:%+d", 
                             result ? "✓" : "✗", 
                             wae_direction, rsi_signal);
        
        if(!result)
        {
            m_core.LogMessage(2, StringFormat("[OPERACIONAL] ❌ Gate 4 REJECTED: WAE=%+d RSI=%+d vs Direction=%s",
                              wae_direction, rsi_signal, EnumToString(m_signal_direction)));
        }
        
        return result;
    }
    
    //+------------------------------------------------------------------+
    //| GATE 5: Currency Strength Context (with fallback for indices)   |
    //+------------------------------------------------------------------+
    bool ProcessGate5_Context(void)
    {
        // Check if Currency Strength is available
        if(!m_indicators.IsCurrencyStrengthAvailable())
        {
            // Fallback for indices - automatically pass
            m_gate_results[5] = true;
            m_gate_messages[5] = "G5✓ CS N/A";
            m_core.LogMessage(3, "Gate 5: Currency Strength not available (Index) - PASS");
            return true;
        }
        
        // Get Currency Strength values
        double base_strength, quote_strength;
        if(!m_indicators.GetCurrencyStrength(base_strength, quote_strength))
        {
            // If failed to get values, skip gate (fallback)
            m_gate_results[5] = true;
            m_gate_messages[5] = "G5✓ CS Skip";
            m_core.LogMessage(2, "⚠️ Gate 5: Failed to get CS values - SKIP");
            return true;
        }
        
        bool result = false;
        
        // Validate strength alignment with direction
        if(m_signal_direction == SIGNAL_DIR_BUY)
        {
            // BUY: Base currency should be stronger than quote
            result = (base_strength > 0 && base_strength > quote_strength);
        }
        else if(m_signal_direction == SIGNAL_DIR_SELL)
        {
            // SELL: Quote currency should be stronger than base
            result = (quote_strength > 0 && quote_strength > base_strength);
        }
        
        m_gate_results[5] = result;
        m_gate_messages[5] = StringFormat("G5%s Base:%.2f Quote:%.2f", 
                             result ? "✓" : "✗", 
                             base_strength, quote_strength);
        
        if(!result)
        {
            m_core.LogMessage(2, StringFormat("[OPERACIONAL] ❌ Gate 5 REJECTED: Base=%.2f Quote=%.2f vs Direction=%s",
                              base_strength, quote_strength, EnumToString(m_signal_direction)));
        }
        
        return result;
    }
    
    //+------------------------------------------------------------------+
    //| Process All Gates Sequentially                                  |
    //+------------------------------------------------------------------+
    bool ProcessAllGates(void)
    {
        // Reset state
        m_mtf_score = 0;
        m_signal_class = SIGNAL_NONE;
        m_signal_direction = SIGNAL_DIR_NONE;
        ArrayInitialize(m_gate_results, false);
        
        // Gate 0: Synchronization
        if(!ProcessGate0_Sync())
            return false;
        
        // Gate 1: Market Access
        if(!ProcessGate1_Market())
            return false;
        
        // Gate 2: Multi-Timeframe Analysis
        if(!ProcessGate2_MTF())
            return false;
        
        // Gate 3: Supertrend Direction
        if(!ProcessGate3_Supertrend())
            return false;
        
        // Gate 4: Momentum (WAE → RSI)
        if(!ProcessGate4_Momentum())
            return false;
        
        // Gate 5: Currency Strength Context
        if(!ProcessGate5_Context())
            return false;
        
        // All gates passed
        LogGateResults(true);
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Log Gate Results                                                 |
    //+------------------------------------------------------------------+
    void LogGateResults(bool all_passed)
    {
        string gate_summary = "Gates: ";
        for(int i = 0; i < 6; i++)
        {
            gate_summary += m_gate_messages[i];
            if(i < 5) gate_summary += " ";
        }
        
        if(all_passed)
        {
            m_core.LogMessage(2, StringFormat("✅ %s | %s %s | Score:%+d",
                              gate_summary,
                              EnumToString(m_signal_class),
                              EnumToString(m_signal_direction),
                              m_mtf_score));
        }
        else
        {
            // Find first failed gate
            int failed_gate = -1;
            for(int i = 0; i < 6; i++)
            {
                if(!m_gate_results[i])
                {
                    failed_gate = i;
                    break;
                }
            }
            
            m_core.LogMessage(3, StringFormat("❌ Signal REJECTED at Gate %d", failed_gate));
        }
    }
    
    //+------------------------------------------------------------------+
    //| Getters                                                          |
    //+------------------------------------------------------------------+
    ENUM_SIGNAL_CLASS GetSignalClass(void) const { return m_signal_class; }
    ENUM_SIGNAL_DIRECTION GetSignalDirection(void) const { return m_signal_direction; }
    int GetMTFScore(void) const { return m_mtf_score; }
};
//+------------------------------------------------------------------+
