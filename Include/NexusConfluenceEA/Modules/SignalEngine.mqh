//+------------------------------------------------------------------+
//|                                                  SignalEngine.mqh |
//|                           Nexus Confluence EA - Signal Processing|
//|                            Gates 0-5 Implementation & Scoring     |
//+------------------------------------------------------------------+
#property copyright "Nexus Confluence EA"
#property version   "1.00"
#property strict

#ifndef SIGNAL_ENGINE_MQH
#define SIGNAL_ENGINE_MQH

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
    
    // ✅ m_min_score REMOVED - validation now in AsymmetricRisk only

    // Throttle for repetitive Gate 2 rejections (reduce log noise)
    string          m_last_gate2_reason;
    
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
        // ✅ m_min_score removed - no longer used
        
        ArrayInitialize(m_gate_results, false);
        m_last_gate2_reason = "";
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
              ENUM_TIMEFRAMES macro3, ENUM_TIMEFRAMES operational)
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
        // ✅ min_score parameter removed - validation in AsymmetricRisk
        
        Print(StringFormat("✅ SignalEngine initialized | MTF: %s/%s/%s/%s",
              EnumToString(m_macro1_tf), EnumToString(m_macro2_tf),
              EnumToString(m_macro3_tf), EnumToString(m_operational_tf)));
        
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
    //| ✅ v2.12: Added DETAILED LOGGING for debugging                  |
    //+------------------------------------------------------------------+
    bool ProcessGate2_MTF(void)
    {
        // Get GG TrendBar signals - ORDEM: Macro1 → Macro2 → Macro3 → Operational (macro para micro)
        int gg_macro1      = m_indicators.GetGGTrendSignal(m_macro1_tf);      // Highest timeframe
        int gg_macro2      = m_indicators.GetGGTrendSignal(m_macro2_tf);      // High timeframe
        int gg_macro3      = m_indicators.GetGGTrendSignal(m_macro3_tf);      // Medium timeframe
        int gg_operational = m_indicators.GetGGTrendSignal(m_operational_tf); // Operational timeframe
        
        // ✅ v2.15: DYNAMIC LOGGING - Shows actual configured timeframes
        m_core.LogMessage(2, StringFormat("📊 Gate 2 MTF Signals: %s=%+d | %s=%+d | %s=%+d | %s=%+d",
                          EnumToString(m_macro1_tf), gg_macro1,
                          EnumToString(m_macro2_tf), gg_macro2,
                          EnumToString(m_macro3_tf), gg_macro3,
                          EnumToString(m_operational_tf), gg_operational));
        
        // Calculate MTF Score (for logging)
        m_mtf_score = gg_macro1 + gg_macro2 + gg_macro3 + gg_operational;
        
        // PASSO 1: Macro1 e Macro2 são MANDANTES - devem estar alinhados (ambos +1 ou ambos -1)
        bool macro12_bullish = (gg_macro1 == 1 && gg_macro2 == 1);
        bool macro12_bearish = (gg_macro1 == -1 && gg_macro2 == -1);
        
        if(!macro12_bullish && !macro12_bearish)
        {
            // Macro1 e Macro2 NÃO alinhados → REJECT (não chama filtros)
            m_signal_class = SIGNAL_REJECT;
            m_signal_direction = SIGNAL_DIR_NONE;
            
            m_gate_results[2] = false;
            m_gate_messages[2] = StringFormat("G2✗ %s/%s desalinhados", 
                                EnumToString(m_macro1_tf), EnumToString(m_macro2_tf));

            string reason = StringFormat("%s/%s desalinhados", 
                           EnumToString(m_macro1_tf), EnumToString(m_macro2_tf));
            if(m_last_gate2_reason != reason)
            {
                m_core.LogMessage(2, StringFormat("❌ Gate 2 REJECTED: %s | %s:%+d %s:%+d %s:%+d %s:%+d",
                                  reason, 
                                  EnumToString(m_macro1_tf), gg_macro1,
                                  EnumToString(m_macro2_tf), gg_macro2,
                                  EnumToString(m_macro3_tf), gg_macro3,
                                  EnumToString(m_operational_tf), gg_operational));
                m_last_gate2_reason = reason;
            }
            else
            {
                // Demote repeated messages to Debug to reduce spam
                m_core.LogMessage(3, StringFormat("❌ Gate 2 REJECTED: %s",
                                  reason));
            }
            return false;
        }
        
        // PASSO 2: Macro1+Macro2 alinhados - determinar direção
        if(macro12_bullish)
        {
            m_signal_direction = SIGNAL_DIR_BUY;
        }
        else if(macro12_bearish)
        {
            m_signal_direction = SIGNAL_DIR_SELL;
        }
        
        // PASSO 3A: CRÍTICO - Verificar se Macro3 ou Operational estão OPOSTOS aos macros
        // Se TF operacional está contra a tendência macro → REJEITAR
        bool macro3_opposite = (macro12_bullish && gg_macro3 == -1) || (macro12_bearish && gg_macro3 == 1);
        bool operational_opposite = (macro12_bullish && gg_operational == -1) || (macro12_bearish && gg_operational == 1);
        
        if(macro3_opposite || operational_opposite)
        {
            // REJECT: TF operacional contra a tendência macro
            m_signal_class = SIGNAL_REJECT;
            m_signal_direction = SIGNAL_DIR_NONE;
            
            m_gate_results[2] = false;
            m_gate_messages[2] = "G2✗ TF operacional oposto";
            
            string opposite_tf = macro3_opposite ? EnumToString(m_macro3_tf) : EnumToString(m_operational_tf);
            string reason = StringFormat("%s oposto aos macros", opposite_tf);
            if(m_last_gate2_reason != reason)
            {
                m_core.LogMessage(2, StringFormat("❌ Gate 2 REJECTED: %s | %s:%+d %s:%+d %s:%+d %s:%+d",
                                  reason,
                                  EnumToString(m_macro1_tf), gg_macro1,
                                  EnumToString(m_macro2_tf), gg_macro2,
                                  EnumToString(m_macro3_tf), gg_macro3,
                                  EnumToString(m_operational_tf), gg_operational));
                m_last_gate2_reason = reason;
            }
            else
            {
                m_core.LogMessage(3, StringFormat("❌ Gate 2 REJECTED: %s", reason));
            }
            return false;
        }
        
        // PASSO 3B: Analisar Macro3 e Operational para classificar PREMIUM vs GOOD
        // Neutros (0) são ACEITOS nesta etapa
        bool macro3_aligned = (macro12_bullish && gg_macro3 == 1) || (macro12_bearish && gg_macro3 == -1);
        bool operational_aligned = (macro12_bullish && gg_operational == 1) || (macro12_bearish && gg_operational == -1);
        
        if(macro3_aligned && operational_aligned)
        {
            // PREMIUM: Todos 4 timeframes alinhados (Macro1+Macro2+Macro3+Operational mesma cor)
            m_signal_class = SIGNAL_PREMIUM;
        }
        else if(macro3_aligned || operational_aligned)
        {
            // GOOD: Macro1+Macro2 alinhados + pelo menos 1 operacional alinhado
            // Neutros (0) são aceitos como GOOD
            m_signal_class = SIGNAL_GOOD;
        }
        else
        {
            // GOOD: Ambos Macro3 e Operational neutros (0) mas Macro1+Macro2 alinhados
            // Aceita pois não há oposição (foi validado no PASSO 3A)
            m_signal_class = SIGNAL_GOOD;
        }
        
        // ✅ PASSO 4: Score validation REMOVED - now handled by AsymmetricRisk module
        // AsymmetricRisk uses InpMinScoreBuy/InpMinScoreSell after ALL gates pass
        // This avoids duplicate validation and allows asymmetric thresholds per direction

        // PASSO 4 (renumbered from 5): PASSED - Log com ordem hierárquica (Macro → Operational)
        bool result = true;
        
        m_gate_results[2] = result;
        m_gate_messages[2] = StringFormat("G2✓ %s Score:%+d", 
                             EnumToString(m_signal_class),
                             m_mtf_score);
        
    m_core.LogMessage(2, StringFormat("✅ Gate 2 PASSED: %s %s | Score:%+d | %s:%+d → %s:%+d → %s:%+d → %s:%+d",
                          EnumToString(m_signal_class),
                          EnumToString(m_signal_direction),
                          m_mtf_score,
                          EnumToString(m_macro1_tf), gg_macro1,
                          EnumToString(m_macro2_tf), gg_macro2,
                          EnumToString(m_macro3_tf), gg_macro3,
                          EnumToString(m_operational_tf), gg_operational));
    // Reset last rejection reason after a pass
    m_last_gate2_reason = "";
        
        return result;
    }
    
    //+------------------------------------------------------------------+
    //| GATE 3: Supertrend Direction (with 1 candle tolerance)          |
    //| ✅ LÓGICA CORRETA:                                               |
    //|    PREMIUM = RIGOROSO (alinhamento perfeito)                     |
    //|    GOOD = FLEXÍVEL (aceita neutro; tolerância já embutida        |
    //|                        em GetSupertrendSignal via vela anterior) |
    //+------------------------------------------------------------------+
    bool ProcessGate3_Supertrend(void)
    {
        int st_signal = m_indicators.GetSupertrendSignal();
        
        bool result = false;
        
        // ══════════════════════════════════════════════════════════════
        // PREMIUM: Mais rigoroso - exige alinhamento PERFEITO
        // ══════════════════════════════════════════════════════════════
        if(m_signal_class == SIGNAL_PREMIUM)
        {
            // PREMIUM requer Supertrend perfeitamente alinhado
            if(m_signal_direction == SIGNAL_DIR_BUY)
            {
                result = (st_signal == 1);  // Apenas bullish aceito
            }
            else if(m_signal_direction == SIGNAL_DIR_SELL)
            {
                result = (st_signal == -1);  // Apenas bearish aceito
            }
        }
        // ══════════════════════════════════════════════════════════════
        // GOOD: Flexível - aceita neutro (0). A tolerância de 1 vela
        // já é aplicada dentro de GetSupertrendSignal(), que considera
        // a vela anterior. Portanto, NÃO aceita direção oposta aqui.
        // ══════════════════════════════════════════════════════════════
        else if(m_signal_class == SIGNAL_GOOD)
        {
            // GOOD: exigir alinhamento direto (sem aceitar neutro)
            if(m_signal_direction == SIGNAL_DIR_BUY)
                result = (st_signal == 1);
            else if(m_signal_direction == SIGNAL_DIR_SELL)
                result = (st_signal == -1);
        }
        
        m_gate_results[3] = result;
        
        // ✅ v2.50 FIX: Get Supertrend raw values for detailed logging
        double st_blue = 0, st_red = 0, close_price = 0;
        m_indicators.GetSupertrendValues(st_blue, st_red, close_price);
        
        // Format values for display (handle EMPTY_VALUE)
        string blue_str = (st_blue != EMPTY_VALUE && st_blue < 1e15) ? StringFormat("%.0f", st_blue) : "EMPTY";
        string red_str = (st_red != EMPTY_VALUE && st_red < 1e15) ? StringFormat("%.0f", st_red) : "EMPTY";
        
        m_gate_messages[3] = StringFormat("G3%s ST:%+d (Blue:%s Red:%s Close:%.0f) [%s]", 
                             result ? "✓" : "✗", 
                             st_signal,
                             blue_str, red_str, close_price,
                             EnumToString(m_signal_class));
        
        if(!result)
        {
            m_core.LogMessage(2, StringFormat("❌ Gate 3 REJECTED: Supertrend=%+d (Blue:%s Red:%s Close:%.0f) vs Direction=%s Class=%s | PREMIUM exige alinhamento perfeito; GOOD não aceita oposto",
                              st_signal, blue_str, red_str, close_price, EnumToString(m_signal_direction), EnumToString(m_signal_class)));
        }
        else
        {
            m_core.LogMessage(3, StringFormat("✅ Gate 3 PASSED: ST=%+d (Blue:%s Red:%s Close:%.0f) vs %s (Class: %s)",
                              st_signal, blue_str, red_str, close_price, EnumToString(m_signal_direction), EnumToString(m_signal_class)));
        }
        
        return result;
    }
    
    //+------------------------------------------------------------------+
    //| GATE 4: Momentum - OBV MACD FIRST, then RSI OMA (CRITICAL ORDER) |
    //| ✅ v2.15 CRITICAL FIX: Histogram analysis replaces color index  |
    //| ✅ v2.49 FIX: Compare histogram against OBV_MACD Buffer 4 (EMA threshold) |
    //| OBV_MACD histogram analysis:                                     |
    //|   Histogram > threshold AND expanding = Strong momentum - ACCEPT |
    //|   Histogram < threshold OR contracting = Weak - REJECT           |
    //+------------------------------------------------------------------+
    bool ProcessGate4_Momentum(void)
    {
        // ✅ v2.49 NEW: Adaptive threshold validation from Buffer 4
        // STEP 1: Check if momentum is EXPANDING (histogram > adaptive threshold)
        bool macd_strong = m_indicators.IsMomentumExpanding();
        if(!macd_strong)
        {
            m_gate_results[4] = false;
            double hist_current = m_indicators.GetMomentumHistogram();
            double hist_previous = m_indicators.GetMomentumHistogramPrevious();
            double threshold = m_indicators.GetMomentumThreshold();
            m_gate_messages[4] = StringFormat("G4✗ MOM weak (%.5f→%.5f | thr:%.5f)", hist_previous, hist_current, threshold);
            m_core.LogMessage(2, StringFormat("❌ Gate 4 REJECTED: Momentum (OBV MACD) below adaptive threshold | Hist: %.5f → %.5f | Threshold: %.5f", hist_previous, hist_current, threshold));
            return false;
        }

        // STEP 2: Get direction from histogram sign
        int macd_direction = m_indicators.GetMomentumDirection();

        // STEP 3: RSI OMA confirmation (SECOND check - confirms momentum direction)
        int rsi_signal = m_indicators.GetRSIOMASignal();

        bool result = false;
        if(m_signal_direction == SIGNAL_DIR_BUY)
        {
            result = (macd_direction == 1 && rsi_signal == 1);
        }
        else if(m_signal_direction == SIGNAL_DIR_SELL)
        {
            result = (macd_direction == -1 && rsi_signal == -1);
        }

        m_gate_results[4] = result;
        double hist_val = m_indicators.GetMomentumHistogram();
        double threshold = m_indicators.GetMomentumThreshold();
        
        // ✅ v2.50 FIX: Get RSI raw values for detailed logging
        double rsi_red = 0, rsi_blue = 0;
        m_indicators.GetRSIValues(rsi_red, rsi_blue);
        
        m_gate_messages[4] = StringFormat("G4%s MOM:%+d(%.5f>%.5f) RSI:%+d(R:%.2f B:%.2f)", result ? "✓" : "✗", macd_direction, hist_val, threshold, rsi_signal, rsi_red, rsi_blue);
        if(!result)
        {
            m_core.LogMessage(2, StringFormat("❌ Gate 4 REJECTED: MOM=%+d (hist=%.5f, thr=%.5f) RSI=%+d (RED:%.2f vs BLUE:%.2f) vs Direction=%s", 
                              macd_direction, hist_val, threshold, rsi_signal, rsi_red, rsi_blue, EnumToString(m_signal_direction)));
        }
        else
        {
            m_core.LogMessage(2, StringFormat("✅ Gate 4 PASSED: MOM expanding (hist=%.5f > threshold=%.5f) + RSI aligned (RED:%.2f vs BLUE:%.2f)", 
                              hist_val, threshold, rsi_red, rsi_blue));
        }
        return result;
    }
    
    //+------------------------------------------------------------------+
    //| GATE 5: Currency Strength Context (market-aware)                |
    //| Required: Forex, Metals | Skipped: Indices/B3 | Optional: Crypto|
    //+------------------------------------------------------------------+
    bool ProcessGate5_Context(void)
    {
        ENUM_MARKET_TYPE mtype = m_market.GetMarketType();

        // Indices/B3: skip Gate 5 (not applicable)
        if(mtype == MARKET_INDICES || mtype == MARKET_B3)
        {
            m_gate_results[5] = true;
            m_gate_messages[5] = "G5✓ Skipped (Index)";
            m_core.LogMessage(3, "Gate 5: Skipped for Indices/B3");
            return true;
        }

        // Optional for Crypto: if not available, pass; if available, evaluate
        // Required for Forex/Metals: must be available and valid
        bool cs_available = m_indicators.IsCurrencyStrengthAvailable();

        if((mtype == MARKET_FOREX || mtype == MARKET_METALS))
        {
            if(!cs_available)
            {
                m_gate_results[5] = false;
                m_gate_messages[5] = "G5✗ CS required";
                m_core.LogMessage(2, "❌ Gate 5 REJECTED: Currency Strength REQUIRED for Forex/Metals but not available");
                return false;
            }
        }
        else if(mtype == MARKET_CRYPTO)
        {
            if(!cs_available)
            {
                m_gate_results[5] = true;
                m_gate_messages[5] = "G5✓ CS N/A (Crypto)";
                m_core.LogMessage(3, "Gate 5: Currency Strength not available (Crypto) - PASS");
                return true;
            }
        }

        // If we reach here, we should attempt to read CS values (available)
        double base_strength, quote_strength;
        if(!m_indicators.GetCurrencyStrength(base_strength, quote_strength))
        {
            // For Forex/Metals treat as reject; for Crypto treat as skip/pass
            if(mtype == MARKET_FOREX || mtype == MARKET_METALS)
            {
                m_gate_results[5] = false;
                m_gate_messages[5] = "G5✗ CS read fail";
                m_core.LogMessage(2, "❌ Gate 5 REJECTED: Failed to get CS values (Forex/Metals)");
                return false;
            }
            else
            {
                m_gate_results[5] = true;
                m_gate_messages[5] = "G5✓ CS Skip";
                m_core.LogMessage(3, "Gate 5: Failed to get CS values (non-required) - SKIP");
                return true;
            }
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
            m_core.LogMessage(2, StringFormat("❌ Gate 5 REJECTED: Base=%.2f Quote=%.2f vs Direction=%s",
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
        
    // Gate 4: Momentum (OBV MACD → RSI OMA)
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

#endif // SIGNAL_ENGINE_MQH
