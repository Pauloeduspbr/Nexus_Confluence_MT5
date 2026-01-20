//+------------------------------------------------------------------+
//|                                             AsymmetricRisk.mqh |
//|                      Nexus Confluence EA - Gestão Assimétrica    |
//|                       Parâmetros Diferenciados BUY/SELL          |
//+------------------------------------------------------------------+
#property copyright "Nexus Confluence EA"
#property version   "2.00"
#property strict

//+------------------------------------------------------------------+
//| Classe de Gerenciamento de Risco Assimétrico                     |
//+------------------------------------------------------------------+
class CAsymmetricRisk
{
private:
    // Controle de direções
    bool     m_buy_enabled;
    bool     m_sell_enabled;
    
    // Parâmetros BUY
    int      m_sl_buy;
    int      m_tp_buy;
    int      m_min_score_buy;
    
    // Parâmetros SELL
    int      m_sl_sell;
    int      m_tp_sell;
    int      m_min_score_sell;
    
    // Controle interno
    bool     m_initialized;
    
    // Estatísticas
    int      m_signals_buy_accepted;
    int      m_signals_buy_rejected;
    int      m_signals_sell_accepted;
    int      m_signals_sell_rejected;
    
public:
    //--- Construtor/Destrutor
    CAsymmetricRisk(void);
    ~CAsymmetricRisk(void);
    
    //--- Inicialização
    bool Init(bool buy_enabled, bool sell_enabled,
              int sl_buy, int tp_buy, int score_buy,
              int sl_sell, int tp_sell, int score_sell);
    
    //--- Métodos de validação
    bool IsDirectionAllowed(ENUM_POSITION_TYPE type);
    bool IsScoreValid(ENUM_POSITION_TYPE type, int score, bool is_premium);
    
    //--- Getters de parâmetros
    int GetSL(ENUM_POSITION_TYPE type);
    int GetTP(ENUM_POSITION_TYPE type);
    int GetMinScore(ENUM_POSITION_TYPE type);
    
    //--- Estatísticas
    int GetSignalsAccepted(ENUM_POSITION_TYPE type);
    int GetSignalsRejected(ENUM_POSITION_TYPE type);
    double GetAcceptanceRate(ENUM_POSITION_TYPE type);
    
    //--- Utilidades
    void PrintStats(void);
    void Reset(void);
};

//+------------------------------------------------------------------+
//| Construtor                                                        |
//+------------------------------------------------------------------+
CAsymmetricRisk::CAsymmetricRisk(void)
{
    m_initialized = false;
    m_buy_enabled = true;
    m_sell_enabled = true;
    
    m_sl_buy = 0;
    m_tp_buy = 0;
    m_min_score_buy = 0;
    
    m_sl_sell = 0;
    m_tp_sell = 0;
    m_min_score_sell = 0;
    
    m_signals_buy_accepted = 0;
    m_signals_buy_rejected = 0;
    m_signals_sell_accepted = 0;
    m_signals_sell_rejected = 0;
}

//+------------------------------------------------------------------+
//| Destrutor                                                         |
//+------------------------------------------------------------------+
CAsymmetricRisk::~CAsymmetricRisk(void)
{
}

//+------------------------------------------------------------------+
//| Inicialização do módulo                                          |
//+------------------------------------------------------------------+
bool CAsymmetricRisk::Init(bool buy_enabled, bool sell_enabled,
                            int sl_buy, int tp_buy, int score_buy,
                            int sl_sell, int tp_sell, int score_sell)
{
    // Validar que pelo menos uma direção está habilitada
    if(!buy_enabled && !sell_enabled)
    {
        Print("❌ [AR] Erro: Pelo menos uma direção (BUY ou SELL) deve estar habilitada.");
        return false;
    }
    
    // Validar parâmetros BUY
    if(buy_enabled)
    {
        if(sl_buy <= 0 || tp_buy <= 0)
        {
            Print("❌ [AR] Erro: SL/TP BUY devem ser maiores que zero.");
            Print("   SL_BUY=", sl_buy, " TP_BUY=", tp_buy);
            return false;
        }
        
        if(score_buy < 0)
        {
            Print("❌ [AR] Erro: Score mínimo BUY não pode ser negativo.");
            return false;
        }
    }
    
    // Validar parâmetros SELL
    if(sell_enabled)
    {
        if(sl_sell <= 0 || tp_sell <= 0)
        {
            Print("❌ [AR] Erro: SL/TP SELL devem ser maiores que zero.");
            Print("   SL_SELL=", sl_sell, " TP_SELL=", tp_sell);
            return false;
        }
        
        if(score_sell < 0)
        {
            Print("❌ [AR] Erro: Score mínimo SELL não pode ser negativo.");
            return false;
        }
    }
    
    // ✅ v2.63 UNIVERSAL CONVERSION: User input = PRICE DISTANCE (points)
    string symbol = Symbol();
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    
    int sl_buy_converted = sl_buy;
    int tp_buy_converted = tp_buy;
    int sl_sell_converted = sl_sell;
    int tp_sell_converted = tp_sell;
    
    if(tick_size > point)
    {
        // B3/Special assets: convert input points to steps
        // Formula: steps = input_points / tick_size
        sl_buy_converted = (int)MathRound(sl_buy / tick_size);
        tp_buy_converted = (int)MathRound(tp_buy / tick_size);
        sl_sell_converted = (int)MathRound(sl_sell / tick_size);
        tp_sell_converted = (int)MathRound(tp_sell / tick_size);
        
        Print("✅ v2.63 [AR]: Universal conversion (input points → steps):");
        Print(StringFormat("   • BUY SL: %d input → %d steps (%.1f distance)",
              sl_buy, sl_buy_converted, sl_buy_converted * tick_size));
        Print(StringFormat("   • BUY TP: %d input → %d steps (%.1f distance)",
              tp_buy, tp_buy_converted, tp_buy_converted * tick_size));
        Print(StringFormat("   • SELL SL: %d input → %d steps (%.1f distance)",
              sl_sell, sl_sell_converted, sl_sell_converted * tick_size));
        Print(StringFormat("   • SELL TP: %d input → %d steps (%.1f distance)",
              tp_sell, tp_sell_converted, tp_sell_converted * tick_size));
    }
    
    // Armazenar configurações CONVERTIDAS
    m_buy_enabled = buy_enabled;
    m_sell_enabled = sell_enabled;
    
    m_sl_buy = sl_buy_converted;      // v2.59: Now in STEPS
    m_tp_buy = tp_buy_converted;      // v2.59: Now in STEPS
    m_min_score_buy = score_buy;
    
    m_sl_sell = sl_sell_converted;    // v2.59: Now in STEPS
    m_tp_sell = tp_sell_converted;    // v2.59: Now in STEPS
    m_min_score_sell = score_sell;
    
    m_initialized = true;
    
    // Log de inicialização
    Print("✅ [AR] Asymmetric Risk Manager inicializado:");
    Print("   📈 BUY: ", (m_buy_enabled ? "HABILITADO" : "DESABILITADO"));
    if(m_buy_enabled)
    {
        Print("      ├─ SL: ", m_sl_buy, " | TP: ", m_tp_buy);
        Print("      └─ Score Mínimo: ", m_min_score_buy);
        Print("      └─ R:R Ratio: 1:", DoubleToString((double)m_tp_buy / m_sl_buy, 2));
    }
    
    Print("   📉 SELL: ", (m_sell_enabled ? "HABILITADO" : "DESABILITADO"));
    if(m_sell_enabled)
    {
        Print("      ├─ SL: ", m_sl_sell, " | TP: ", m_tp_sell);
        Print("      └─ Score Mínimo: ", m_min_score_sell);
        Print("      └─ R:R Ratio: 1:", DoubleToString((double)m_tp_sell / m_sl_sell, 2));
    }
    
    // Avisos se parâmetros forem muito diferentes
    if(m_buy_enabled && m_sell_enabled)
    {
        double sl_ratio = (double)m_sl_buy / m_sl_sell;
        double tp_ratio = (double)m_tp_buy / m_tp_sell;
        
        if(sl_ratio > 2.5 || sl_ratio < 0.4)
        {
            Print("⚠️ [AR] Aviso: Diferença significativa entre SL BUY e SELL (ratio: ", 
                  DoubleToString(sl_ratio, 2), ")");
        }
        
        if(tp_ratio > 2.5 || tp_ratio < 0.4)
        {
            Print("⚠️ [AR] Aviso: Diferença significativa entre TP BUY e SELL (ratio: ",
                  DoubleToString(tp_ratio, 2), ")");
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Verifica se uma direção está permitida                           |
//+------------------------------------------------------------------+
bool CAsymmetricRisk::IsDirectionAllowed(ENUM_POSITION_TYPE type)
{
    if(!m_initialized)
    {
        Print("❌ [AR] Erro: Módulo não inicializado.");
        return false;
    }
    
    if(type == POSITION_TYPE_BUY)
        return m_buy_enabled;
    else
        return m_sell_enabled;
}

//+------------------------------------------------------------------+
//| Valida se um score é suficiente para abrir operação              |
//+------------------------------------------------------------------+
bool CAsymmetricRisk::IsScoreValid(ENUM_POSITION_TYPE type, int score, bool is_premium)
{
    if(!m_initialized)
    {
        Print("❌ [AR] Erro: Módulo não inicializado.");
        return false;
    }
    
    bool valid = false;
    
    if(type == POSITION_TYPE_BUY)
    {
        // 🔥 FIX v2.03: REMOVIDO o incremento +1 para PREMIUM
        // PROBLEMA ANTERIOR: required = m_min_score_buy + (is_premium ? 1 : 0)
        // Com InpMinScoreBuy=4 e score máximo=4:
        //   - PREMIUM: exigia 4+1=5 → IMPOSSÍVEL! ❌
        //   - GOOD: exigia 4 → possível com score=4
        //
        // CORREÇÃO: O score mínimo já define o filtro necessário.
        // A classificação PREMIUM/GOOD é feita ANTES no SignalEngine.
        // PREMIUM (score=4) já indica TODOS os timeframes alinhados!
        // Adicionar +1 para PREMIUM é contraditório e torna impossível trades PREMIUM.
        
        int required = m_min_score_buy;  // ✅ Sem incremento adicional
        valid = (score >= required);
        
        if(valid)
            m_signals_buy_accepted++;
        else
            m_signals_buy_rejected++;
    }
    else // SELL
    {
        // 🔥 FIX v2.03: Mesma correção para SELL
        int required = m_min_score_sell;  // ✅ Sem incremento adicional
        valid = (score >= required);
        
        if(valid)
            m_signals_sell_accepted++;
        else
            m_signals_sell_rejected++;
    }
    
    return valid;
}

//+------------------------------------------------------------------+
//| Retorna Stop Loss para uma direção                               |
//+------------------------------------------------------------------+
int CAsymmetricRisk::GetSL(ENUM_POSITION_TYPE type)
{
    if(!m_initialized)
    {
        Print("❌ [AR] Erro: Módulo não inicializado.");
        return 0;
    }
    
    return (type == POSITION_TYPE_BUY) ? m_sl_buy : m_sl_sell;
}

//+------------------------------------------------------------------+
//| Retorna Take Profit para uma direção                             |
//+------------------------------------------------------------------+
int CAsymmetricRisk::GetTP(ENUM_POSITION_TYPE type)
{
    if(!m_initialized)
    {
        Print("❌ [AR] Erro: Módulo não inicializado.");
        return 0;
    }
    
    return (type == POSITION_TYPE_BUY) ? m_tp_buy : m_tp_sell;
}

//+------------------------------------------------------------------+
//| Retorna Score Mínimo para uma direção                            |
//+------------------------------------------------------------------+
int CAsymmetricRisk::GetMinScore(ENUM_POSITION_TYPE type)
{
    if(!m_initialized)
    {
        Print("❌ [AR] Erro: Módulo não inicializado.");
        return 0;
    }
    
    return (type == POSITION_TYPE_BUY) ? m_min_score_buy : m_min_score_sell;
}

//+------------------------------------------------------------------+
//| Retorna quantidade de sinais aceitos                             |
//+------------------------------------------------------------------+
int CAsymmetricRisk::GetSignalsAccepted(ENUM_POSITION_TYPE type)
{
    return (type == POSITION_TYPE_BUY) ? m_signals_buy_accepted : m_signals_sell_accepted;
}

//+------------------------------------------------------------------+
//| Retorna quantidade de sinais rejeitados                          |
//+------------------------------------------------------------------+
int CAsymmetricRisk::GetSignalsRejected(ENUM_POSITION_TYPE type)
{
    return (type == POSITION_TYPE_BUY) ? m_signals_buy_rejected : m_signals_sell_rejected;
}

//+------------------------------------------------------------------+
//| Calcula taxa de aceitação de sinais                              |
//+------------------------------------------------------------------+
double CAsymmetricRisk::GetAcceptanceRate(ENUM_POSITION_TYPE type)
{
    int accepted, rejected, total;
    
    if(type == POSITION_TYPE_BUY)
    {
        accepted = m_signals_buy_accepted;
        rejected = m_signals_buy_rejected;
    }
    else
    {
        accepted = m_signals_sell_accepted;
        rejected = m_signals_sell_rejected;
    }
    
    total = accepted + rejected;
    
    if(total == 0)
        return 0.0;
    
    return (double)accepted / total * 100.0;
}

//+------------------------------------------------------------------+
//| Imprime estatísticas do módulo                                   |
//+------------------------------------------------------------------+
void CAsymmetricRisk::PrintStats(void)
{
    Print("═══════════════════════════════════════");
    Print("📊 [AR] ESTATÍSTICAS ASYMMETRIC RISK");
    Print("═══════════════════════════════════════");
    
    Print("📈 BUY:");
    Print("   ├─ Status: ", (m_buy_enabled ? "HABILITADO" : "DESABILITADO"));
    Print("   ├─ SL: ", m_sl_buy, " | TP: ", m_tp_buy);
    Print("   ├─ Score Mínimo: ", m_min_score_buy);
    Print("   ├─ Sinais Aceitos: ", m_signals_buy_accepted);
    Print("   ├─ Sinais Rejeitados: ", m_signals_buy_rejected);
    Print("   └─ Taxa Aceitação: ", DoubleToString(GetAcceptanceRate(POSITION_TYPE_BUY), 1), "%");
    
    Print("📉 SELL:");
    Print("   ├─ Status: ", (m_sell_enabled ? "HABILITADO" : "DESABILITADO"));
    Print("   ├─ SL: ", m_sl_sell, " | TP: ", m_tp_sell);
    Print("   ├─ Score Mínimo: ", m_min_score_sell);
    Print("   ├─ Sinais Aceitos: ", m_signals_sell_accepted);
    Print("   ├─ Sinais Rejeitados: ", m_signals_sell_rejected);
    Print("   └─ Taxa Aceitação: ", DoubleToString(GetAcceptanceRate(POSITION_TYPE_SELL), 1), "%");
    
    Print("═══════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Reset das estatísticas                                           |
//+------------------------------------------------------------------+
void CAsymmetricRisk::Reset(void)
{
    m_signals_buy_accepted = 0;
    m_signals_buy_rejected = 0;
    m_signals_sell_accepted = 0;
    m_signals_sell_rejected = 0;
    
    Print("🔄 [AR] Estatísticas resetadas.");
}

//+------------------------------------------------------------------+
