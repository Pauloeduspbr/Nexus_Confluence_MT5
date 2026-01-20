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
    // ✅ v3.0: Increased to 7 gates (0-6)
    bool            m_gate_results[7];
    string          m_gate_messages[7];
    
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
    //| GATE 2: Multi-Timeframe Analysis (SIMPLIFIED v3.0)              |
    //| ✅ v3.0 FIX: Lógica simplificada para mais oportunidades        |
    //| REQUISITO: Macro1 (H4) indica direção principal                 |
    //| PREMIUM: Macro1+Macro2 alinhados (opcionalmente +Macro3+Op)     |
    //| GOOD: Macro1 tem direção definida (+1 ou -1)                    |
    //| REJECT: Macro1 neutro (0)                                        |
    //| ✅ NÃO REJEITA por TF menores opostos - aceita como GOOD        |
    //+------------------------------------------------------------------+
    bool ProcessGate2_MTF(void)
    {
        // Get GG TrendBar signals - ORDEM: Macro1 → Macro2 → Macro3 → Operational
        int gg_macro1      = m_indicators.GetGGTrendSignal(m_macro1_tf);
        int gg_macro2      = m_indicators.GetGGTrendSignal(m_macro2_tf);
        int gg_macro3      = m_indicators.GetGGTrendSignal(m_macro3_tf);
        int gg_operational = m_indicators.GetGGTrendSignal(m_operational_tf);
        
        m_core.LogMessage(2, StringFormat("📊 Gate 2 MTF: %s=%+d | %s=%+d | %s=%+d | %s=%+d",
                          EnumToString(m_macro1_tf), gg_macro1,
                          EnumToString(m_macro2_tf), gg_macro2,
                          EnumToString(m_macro3_tf), gg_macro3,
                          EnumToString(m_operational_tf), gg_operational));
        
        // Calculate MTF Score
        m_mtf_score = gg_macro1 + gg_macro2 + gg_macro3 + gg_operational;
        
        // ════════════════════════════════════════════════════════════════
        // ✅ v3.0 SIMPLIFIED: Apenas Macro1 precisa ter direção definida
        // TFs menores NÃO rejeitam mais - apenas afetam classificação
        // ════════════════════════════════════════════════════════════════
        
        // PASSO 1: Macro1 DEVE ter direção definida
        if(gg_macro1 == 0)
        {
            m_signal_class = SIGNAL_REJECT;
            m_signal_direction = SIGNAL_DIR_NONE;
            m_gate_results[2] = false;
            m_gate_messages[2] = StringFormat("G2✗ %s neutro", EnumToString(m_macro1_tf));
            
            if(m_last_gate2_reason != "macro1_neutral")
            {
                m_core.LogMessage(2, StringFormat("❌ Gate 2 REJECTED: %s neutro (0) - aguardando direção",
                                  EnumToString(m_macro1_tf)));
                m_last_gate2_reason = "macro1_neutral";
            }
            return false;
        }
        
        // PASSO 2: Definir direção baseado em Macro1
        m_signal_direction = (gg_macro1 == 1) ? SIGNAL_DIR_BUY : SIGNAL_DIR_SELL;
        
        // PASSO 3: Classificar PREMIUM vs GOOD baseado em alinhamento
        // ✅ v3.0: NÃO REJEITA por TF menores - apenas classifica
        bool macro2_aligned = (gg_macro1 == gg_macro2);
        bool macro3_aligned = (gg_macro1 == gg_macro3) || (gg_macro3 == 0);
        bool operational_aligned = (gg_macro1 == gg_operational) || (gg_operational == 0);
        
        // Contagem de TFs alinhados (para score)
        int aligned_count = 1;  // Macro1 sempre conta
        if(macro2_aligned) aligned_count++;
        if(gg_macro3 == gg_macro1) aligned_count++;
        if(gg_operational == gg_macro1) aligned_count++;
        
        // PREMIUM: 3+ TFs alinhados (Macro1 + 2 outros na mesma direção)
        // GOOD: Macro1 tem direção (outros podem ser neutros ou opostos)
        if(aligned_count >= 3)
        {
            m_signal_class = SIGNAL_PREMIUM;
        }
        else
        {
            m_signal_class = SIGNAL_GOOD;
        }
        
        // PASSED
        m_gate_results[2] = true;
        m_gate_messages[2] = StringFormat("G2✓ %s Score:%+d Aligned:%d", 
                             EnumToString(m_signal_class), m_mtf_score, aligned_count);
        
        m_core.LogMessage(2, StringFormat("✅ Gate 2 PASSED: %s %s | Score:%+d | Aligned:%d/4",
                          EnumToString(m_signal_class),
                          EnumToString(m_signal_direction),
                          m_mtf_score, aligned_count));
        m_last_gate2_reason = "";
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| GATE 3: Supertrend Direction (OPTIONAL via InpST_Enable)        |
    //| ✅ v3.0 FIX: Respects InpST_Enable input                         |
    //| Se InpST_Enable=false, gate passa automaticamente               |
    //| Se InpST_Enable=true, verifica alinhamento                      |
    //+------------------------------------------------------------------+
    bool ProcessGate3_Supertrend(void)
    {
        // ✅ v3.0: Check if Supertrend is enabled via input
        if(!m_indicators.IsSupertrendEnabled())
        {
            m_gate_results[3] = true;
            m_gate_messages[3] = "G3✓ ST disabled";
            m_core.LogMessage(3, "Gate 3 BYPASSED: Supertrend disabled via InpST_Enable=false");
            return true;
        }
        
        int st_signal = m_indicators.GetSupertrendSignal();
        bool result = false;
        
        // ✅ v3.0 SIMPLIFIED: Aceita alinhado OU neutro (não exige perfeição)
        if(m_signal_direction == SIGNAL_DIR_BUY)
        {
            // Aceita: bullish (+1) ou neutro (0)
            result = (st_signal >= 0);
        }
        else if(m_signal_direction == SIGNAL_DIR_SELL)
        {
            // Aceita: bearish (-1) ou neutro (0)
            result = (st_signal <= 0);
        }
        
        m_gate_results[3] = result;
        
        double st_blue = 0, st_red = 0, close_price = 0;
        m_indicators.GetSupertrendValues(st_blue, st_red, close_price);
        
        string blue_str = (st_blue != EMPTY_VALUE && st_blue < 1e15) ? StringFormat("%.0f", st_blue) : "EMPTY";
        string red_str = (st_red != EMPTY_VALUE && st_red < 1e15) ? StringFormat("%.0f", st_red) : "EMPTY";
        
        m_gate_messages[3] = StringFormat("G3%s ST:%+d", result ? "✓" : "✗", st_signal);
        
        if(!result)
        {
            m_core.LogMessage(2, StringFormat("❌ Gate 3 REJECTED: ST=%+d oposto a %s",
                              st_signal, EnumToString(m_signal_direction)));
        }
        else
        {
            m_core.LogMessage(3, StringFormat("✅ Gate 3 PASSED: ST=%+d (Close:%.0f)",
                              st_signal, close_price));
        }
        
        return result;
    }
    
    //+------------------------------------------------------------------+
    //| GATE 4: Momentum (SIMPLIFIED v3.0)                               |
    //| ✅ v3.0 FIX: RSI now optional via InpRSI_Enable                  |
    //| Se InpRSI_Enable=false, usa apenas OBV MACD                      |
    //| Se InpMACD_Enable=false, gate passa automaticamente              |
    //+------------------------------------------------------------------+
    bool ProcessGate4_Momentum(void)
    {
        // ✅ v3.0: Check if MACD is enabled
        if(!m_indicators.IsMomentumEnabled())
        {
            m_gate_results[4] = true;
            m_gate_messages[4] = "G4✓ MOM disabled";
            m_core.LogMessage(3, "Gate 4 BYPASSED: OBV MACD disabled via InpMACD_Enable=false");
            return true;
        }
        
        // STEP 1: Check if momentum is EXPANDING
        bool macd_strong = m_indicators.IsMomentumExpanding();
        if(!macd_strong)
        {
            m_gate_results[4] = false;
            double hist_current = m_indicators.GetMomentumHistogram();
            double threshold = m_indicators.GetMomentumThreshold();
            m_gate_messages[4] = StringFormat("G4✗ MOM weak (%.5f < %.5f)", hist_current, threshold);
            m_core.LogMessage(2, StringFormat("❌ Gate 4 REJECTED: Momentum below threshold | Hist: %.5f | Thr: %.5f", hist_current, threshold));
            return false;
        }

        // STEP 2: Get direction from histogram sign
        int macd_direction = m_indicators.GetMomentumDirection();
        
        // STEP 3: Check MACD direction alignment
        bool macd_aligned = false;
        if(m_signal_direction == SIGNAL_DIR_BUY)
            macd_aligned = (macd_direction >= 0);  // ✅ v3.0: Aceita positivo ou neutro
        else if(m_signal_direction == SIGNAL_DIR_SELL)
            macd_aligned = (macd_direction <= 0);  // ✅ v3.0: Aceita negativo ou neutro
        
        if(!macd_aligned)
        {
            m_gate_results[4] = false;
            m_gate_messages[4] = StringFormat("G4✗ MOM:%+d vs %s", macd_direction, EnumToString(m_signal_direction));
            m_core.LogMessage(2, StringFormat("❌ Gate 4 REJECTED: MACD=%+d contra %s", macd_direction, EnumToString(m_signal_direction)));
            return false;
        }
        
        // STEP 4: RSI OMA confirmation (OPTIONAL via InpRSI_Enable)
        // ✅ v3.0: Se RSI desabilitado, pula esta verificação
        if(m_indicators.IsRSIEnabled())
        {
            int rsi_signal = m_indicators.GetRSIOMASignal();
            
            // RSI só rejeita se estiver OPOSTO à direção (neutro aceita)
            bool rsi_opposing = false;
            if(m_signal_direction == SIGNAL_DIR_BUY && rsi_signal == -1)
                rsi_opposing = true;
            else if(m_signal_direction == SIGNAL_DIR_SELL && rsi_signal == 1)
                rsi_opposing = true;
            
            if(rsi_opposing)
            {
                m_gate_results[4] = false;
                m_gate_messages[4] = StringFormat("G4✗ RSI:%+d oposto", rsi_signal);
                m_core.LogMessage(2, StringFormat("❌ Gate 4 REJECTED: RSI=%+d oposto a %s", rsi_signal, EnumToString(m_signal_direction)));
                return false;
            }
        }
        
        // PASSED
        m_gate_results[4] = true;
        double hist_val = m_indicators.GetMomentumHistogram();
        m_gate_messages[4] = StringFormat("G4✓ MOM:%+d (%.5f)", macd_direction, hist_val);
        m_core.LogMessage(2, "✅ Gate 4 PASSED: MACD expanding, direction aligned");
        
        return true;
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
    //| GATE 6: Regime Filter (Flat Market / ADX)                        |
    //| ✅ v3.0: Blocks trades during flat markets                       |
    //+------------------------------------------------------------------+
    bool ProcessGate6_Regime(void)
    {
        // Check if disabled (helper in IndicatorHub)
        if(!m_indicators.IsRegimeFilterEnabled())
        {
             m_gate_results[6] = true;
             m_gate_messages[6] = "G6✓ Disabled";
             m_core.LogMessage(3, "Gate 6 BYPASSED: Regime Filter disabled");
             return true;
        }

        double adx = m_indicators.GetRegimeADX();
        double threshold = m_indicators.GetRegimeThreshold();
        
        // Logic: ADX < Threshold = FLAT
        if(adx < threshold)
        {
            m_gate_results[6] = false;
            m_gate_messages[6] = StringFormat("G6✗ Flat (%.1f<%.1f)", adx, threshold);
            m_core.LogMessage(2, StringFormat("❌ Gate 6 REJECTED: Flat Market (ADX %.1f < %.1f)", adx, threshold));
            return false;
        }

        m_gate_results[6] = true;
        m_gate_messages[6] = StringFormat("G6✓ Trend (%.1f)", adx);
        m_core.LogMessage(3, StringFormat("✅ Gate 6 PASSED: Strong Trend (ADX %.1f)", adx));
        return true;
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
            
        // Gate 6: Regime Filter (Flat Market)
        if(!ProcessGate6_Regime())
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
        for(int i = 0; i < 7; i++)
        {
            gate_summary += m_gate_messages[i];
            if(i < 6) gate_summary += " ";
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
            for(int i = 0; i < 7; i++)
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
