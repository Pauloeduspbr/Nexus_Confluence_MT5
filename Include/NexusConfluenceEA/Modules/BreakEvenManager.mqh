//+------------------------------------------------------------------+
//|                                            BreakEvenManager.mqh |
//|                      Nexus Confluence EA - Módulo Break Even     |
//|                       Gestão de Break Even Individual BUY/SELL   |
//+------------------------------------------------------------------+
#property copyright "Nexus Confluence EA"
#property version   "2.00"
#property strict

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Classe de Gerenciamento de Break Even                            |
//+------------------------------------------------------------------+
class CBreakEvenManager
{
private:
    // Configurações BUY
    bool     m_buy_enabled;
    int      m_trigger_buy;
    int      m_step_buy;
    
    // Configurações SELL
    bool     m_sell_enabled;
    int      m_trigger_sell;
    int      m_step_sell;
    
    // Controle interno
    bool     m_initialized;
    CTrade   m_trade;
    
    // Log de ativações (evita múltiplas ativações)
    ulong    m_activated_tickets[];
    
    // Estatísticas
    int      m_total_activations_buy;
    int      m_total_activations_sell;
    int      m_total_saves;  // Trades que saíram em BE ao invés de loss
    
public:
    //--- Construtor/Destrutor
    CBreakEvenManager(void);
    ~CBreakEvenManager(void);
    
    //--- Inicialização
    bool Init(bool buy_enabled, int trigger_buy, int step_buy,
              bool sell_enabled, int trigger_sell, int step_sell);
    
    //--- Métodos principais
    bool CheckAndApply(ulong ticket);
    bool IsBEActivated(ulong ticket);
    void Reset(void);
    
    //--- Estatísticas
    int GetTotalActivationsBuy(void) { return m_total_activations_buy; }
    int GetTotalActivationsSell(void) { return m_total_activations_sell; }
    int GetTotalSaves(void) { return m_total_saves; }
    
    //--- Utilidades
    void PrintStats(void);
};

//+------------------------------------------------------------------+
//| Construtor                                                        |
//+------------------------------------------------------------------+
CBreakEvenManager::CBreakEvenManager(void)
{
    m_initialized = false;
    m_buy_enabled = false;
    m_sell_enabled = false;
    m_trigger_buy = 0;
    m_step_buy = 0;
    m_trigger_sell = 0;
    m_step_sell = 0;
    
    m_total_activations_buy = 0;
    m_total_activations_sell = 0;
    m_total_saves = 0;
    
    ArrayResize(m_activated_tickets, 0);
}

//+------------------------------------------------------------------+
//| Destrutor                                                         |
//+------------------------------------------------------------------+
CBreakEvenManager::~CBreakEvenManager(void)
{
    ArrayFree(m_activated_tickets);
}

//+------------------------------------------------------------------+
//| Inicialização do módulo                                          |
//+------------------------------------------------------------------+
bool CBreakEvenManager::Init(bool buy_enabled, int trigger_buy, int step_buy,
                              bool sell_enabled, int trigger_sell, int step_sell)
{
    // Validação de parâmetros BUY
    if(buy_enabled)
    {
        if(trigger_buy <= 0 || step_buy < 0)
        {
            Print("❌ [BE] Erro: Parâmetros BUY inválidos. Trigger=", trigger_buy, " Step=", step_buy);
            return false;
        }
        
        if(trigger_buy <= step_buy)
        {
            Print("⚠️ [BE] Aviso: BE Trigger BUY (", trigger_buy, 
                  ") deve ser maior que Step (", step_buy, ")");
        }
    }
    
    // Validação de parâmetros SELL
    if(sell_enabled)
    {
        if(trigger_sell <= 0 || step_sell < 0)
        {
            Print("❌ [BE] Erro: Parâmetros SELL inválidos. Trigger=", trigger_sell, " Step=", step_sell);
            return false;
        }
        
        if(trigger_sell <= step_sell)
        {
            Print("⚠️ [BE] Aviso: BE Trigger SELL (", trigger_sell,
                  ") deve ser maior que Step (", step_sell, ")");
        }
    }
    
    // Armazenar configurações
    m_buy_enabled = buy_enabled;
    m_trigger_buy = trigger_buy;
    m_step_buy = step_buy;
    
    m_sell_enabled = sell_enabled;
    m_trigger_sell = trigger_sell;
    m_step_sell = step_sell;
    
    m_initialized = true;
    
    // Log de inicialização
    Print("✅ [BE] Break Even Manager inicializado:");
    Print("   📈 BUY: ", (m_buy_enabled ? "ATIVO" : "DESATIVADO"),
          " | Trigger=", m_trigger_buy, " | Step=", m_step_buy);
    Print("   📉 SELL: ", (m_sell_enabled ? "ATIVO" : "DESATIVADO"),
          " | Trigger=", m_trigger_sell, " | Step=", m_step_sell);
    
    return true;
}

//+------------------------------------------------------------------+
//| Verifica e aplica Break Even em uma posição                      |
//+------------------------------------------------------------------+
bool CBreakEvenManager::CheckAndApply(ulong ticket)
{
    if(!m_initialized)
    {
        Print("❌ [BE] Erro: Módulo não inicializado. Chame Init() primeiro.");
        return false;
    }
    
    // Verificar se posição existe
    if(!PositionSelectByTicket(ticket))
    {
        Print("⚠️ [BE] Posição #", ticket, " não encontrada.");
        return false;
    }
    
    // Obter informações da posição
    ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    
    // Verificar se BE está habilitado para esta direção
    if(pos_type == POSITION_TYPE_BUY && !m_buy_enabled)
        return false;
    
    if(pos_type == POSITION_TYPE_SELL && !m_sell_enabled)
        return false;
    
    // Verificar se BE já foi ativado
    if(IsBEActivated(ticket))
        return true;  // Já está em BE
    
    // Obter dados da posição
    double entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
    double current_sl = PositionGetDouble(POSITION_SL);
    double current_tp = PositionGetDouble(POSITION_TP);
    string symbol = PositionGetString(POSITION_SYMBOL);
    
    // Obter preço atual
    double current_price;
    if(pos_type == POSITION_TYPE_BUY)
        current_price = SymbolInfoDouble(symbol, SYMBOL_BID);
    else
        current_price = SymbolInfoDouble(symbol, SYMBOL_ASK);
    
    // Informações do símbolo
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    
    // Calcular lucro em pontos/pips
    double profit_points;
    
    if(pos_type == POSITION_TYPE_BUY)
    {
        profit_points = (current_price - entry_price) / point;
        
        // Se o SL atual já atingiu ou superou o alvo de BE, marcar e sair
        // Alvo BUY: entry + step
        double target_be = NormalizeDouble(entry_price + (m_step_buy * point), digits);
        double tol = 2 * point; // tolerância de 2 pontos para arredondamentos
        if(m_step_buy >= 0 && current_sl > 0 && current_sl >= (target_be - tol))
        {
            // Adicionar ticket à lista se ainda não estiver
            int n = ArraySize(m_activated_tickets);
            bool found = false;
            for(int i=0;i<n;i++){ if(m_activated_tickets[i]==ticket){ found=true; break; } }
            if(!found){ ArrayResize(m_activated_tickets, n+1); m_activated_tickets[n]=ticket; }
            return true;
        }
        
        // Verificar se atingiu o trigger
        if(profit_points >= m_trigger_buy)
        {
            // Calcular novo SL (entry + step)
            double new_sl = NormalizeDouble(entry_price + (m_step_buy * point), digits);

            // ═══════════════════════════════════════════════════════
            // VALIDAÇÃO 1: SL não pode ultrapassar TP em BUY
            // ═══════════════════════════════════════════════════════
            if(current_tp > 0 && new_sl >= current_tp)
            {
                Print("❌ [BE] BUY #", ticket, ": SL alvo (", new_sl, ") ultrapassaria TP (", current_tp, "). Configuração inválida.");
                Print("   💡 Ajuste BE_Buy_Step para valor menor que distância até TP");
                return false;
            }
            
            // ═══════════════════════════════════════════════════════
            // VALIDAÇÃO CRÍTICA 2: SL deve estar ABAIXO do preço atual
            // ═══════════════════════════════════════════════════════
            double min_distance_for_be = (m_trigger_buy - m_step_buy) * point; // Distância segura
            double current_distance = current_price - new_sl;
            
            if(current_distance <= 0)
            {
                Print("⚠️ [BE] BUY #", ticket, ": SL alvo (", new_sl, ") está acima/igual ao preço atual (", current_price, "). Impossível ativar.");
                Print("   📊 Entry: ", entry_price, " | Profit: +", (int)profit_points, " pts | Trigger: ", m_trigger_buy, " | Step: ", m_step_buy);
                Print("   💡 CAUSA: Step (", m_step_buy, ") muito pequeno. Preço já ultrapassou Entry+Step.");
                Print("   🔧 SOLUÇÃO: Aumente BE_Buy_Step ou reduza BE_Buy_Trigger");
                return false;
            }
            
            if(current_distance < min_distance_for_be)
            {
                Print("⚠️ [BE] BUY #", ticket, ": Distância insuficiente entre SL e preço (", 
                      NormalizeDouble(current_distance/point, 0), " pts < ", 
                      NormalizeDouble(min_distance_for_be/point, 0), " pts necessários)");
                Print("   💡 Aguardando preço se afastar mais do SL alvo antes de ativar");
                return false;
            }
            
            // Verificar se novo SL é melhor que o atual
            if(new_sl > current_sl || current_sl == 0)
            {
                // Verificar distâncias mínimas (STOPS_LEVEL / FREEZE_LEVEL)
                long stop_level = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
                long freeze_level = SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
                int min_level = (int)MathMax((double)stop_level, (double)freeze_level);
                if(min_level > 0)
                {
                    double distance_to_price = (current_price - new_sl) / point;
                    if(distance_to_price < min_level)
                    {
                        Print("⚠️ [BE] BUY #", ticket, ": SL muito próximo do preço (min_level=", min_level, " | distância: ", (int)distance_to_price, " pontos)");
                        return false;
                    }
                }
                
                // Modificar posição (usar símbolo em MT5)
                if(m_trade.PositionModify(symbol, new_sl, current_tp))
                {
                    // Registrar ativação
                    int size = ArraySize(m_activated_tickets);
                    ArrayResize(m_activated_tickets, size + 1);
                    m_activated_tickets[size] = ticket;
                    
                    m_total_activations_buy++;
                    
                    double protected_points = (new_sl - entry_price) / point;
                    
                    Print("✅ [BE] Break Even ativado para BUY #", ticket);
                    Print("   📊 Lucro atual: +", (int)profit_points, " pontos/pips");
                    Print("   🎯 Novo SL: ", new_sl, " (+", (int)protected_points, " pontos protegidos)");
                    Print("   📈 Entry: ", entry_price, " | TP: ", current_tp);
                    
                    return true;
                }
                else
                {
                    int ret = (int)m_trade.ResultRetcode();
                    Print("❌ [BE] Falha ao modificar BUY #", ticket, " - Retcode: ", ret, " (", m_trade.ResultRetcodeDescription(), ")");
                    Print("   📍 Tentou: SL=", new_sl, " TP=", current_tp, " | Price=", current_price, " | Entry=", entry_price);
                    return false;
                }
            }
        }
    }
    else // POSITION_TYPE_SELL
    {
        profit_points = (entry_price - current_price) / point;
        
        // Se o SL atual já atingiu ou superou o alvo de BE, marcar e sair
        // Alvo SELL: entry - step
        double target_be = NormalizeDouble(entry_price - (m_step_sell * point), digits);
        double tol = 2 * point; // tolerância de 2 pontos para arredondamentos
        if(m_step_sell >= 0 && current_sl > 0 && current_sl <= (target_be + tol))
        {
            // Adicionar ticket à lista se ainda não estiver
            int n = ArraySize(m_activated_tickets);
            bool found = false;
            for(int i=0;i<n;i++){ if(m_activated_tickets[i]==ticket){ found=true; break; } }
            if(!found){ ArrayResize(m_activated_tickets, n+1); m_activated_tickets[n]=ticket; }
            return true;
        }
        
        // Verificar se atingiu o trigger
        if(profit_points >= m_trigger_sell)
        {
            // Calcular novo SL (entry - step)
            double new_sl = NormalizeDouble(entry_price - (m_step_sell * point), digits);

            // ═══════════════════════════════════════════════════════
            // VALIDAÇÃO 1: SL não pode ultrapassar TP em SELL
            // ═══════════════════════════════════════════════════════
            if(current_tp > 0 && new_sl <= current_tp)
            {
                Print("❌ [BE] SELL #", ticket, ": SL alvo (", new_sl, ") ultrapassaria TP (", current_tp, "). Configuração inválida.");
                Print("   💡 Ajuste BE_Sell_Step para valor menor que distância até TP");
                return false;
            }
            
            // ═══════════════════════════════════════════════════════
            // VALIDAÇÃO CRÍTICA 2: SL deve estar ACIMA do preço atual
            // ═══════════════════════════════════════════════════════
            double min_distance_for_be = (m_trigger_sell - m_step_sell) * point; // Distância segura
            double current_distance = new_sl - current_price;
            
            if(current_distance <= 0)
            {
                Print("⚠️ [BE] SELL #", ticket, ": SL alvo (", new_sl, ") está abaixo/igual ao preço atual (", current_price, "). Impossível ativar.");
                Print("   📊 Entry: ", entry_price, " | Profit: +", (int)profit_points, " pts | Trigger: ", m_trigger_sell, " | Step: ", m_step_sell);
                Print("   💡 CAUSA: Step (", m_step_sell, ") muito pequeno. Preço já ultrapassou Entry-Step.");
                Print("   🔧 SOLUÇÃO: Aumente BE_Sell_Step ou reduza BE_Sell_Trigger");
                return false;
            }
            
            if(current_distance < min_distance_for_be)
            {
                Print("⚠️ [BE] SELL #", ticket, ": Distância insuficiente entre SL e preço (", 
                      NormalizeDouble(current_distance/point, 0), " pts < ", 
                      NormalizeDouble(min_distance_for_be/point, 0), " pts necessários)");
                Print("   💡 Aguardando preço se afastar mais do SL alvo antes de ativar");
                return false;
            }
            
            // Verificar se novo SL é melhor que o atual (menor para SELL)
            if(new_sl < current_sl || current_sl == 0)
            {
                // Verificar distâncias mínimas (STOPS_LEVEL / FREEZE_LEVEL)
                long stop_level = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
                long freeze_level = SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
                int min_level = (int)MathMax((double)stop_level, (double)freeze_level);
                if(min_level > 0)
                {
                    double distance_to_price = (new_sl - current_price) / point;
                    if(distance_to_price < min_level)
                    {
                        Print("⚠️ [BE] SELL #", ticket, ": SL muito próximo do preço (min_level=", min_level, " | distância: ", (int)distance_to_price, " pontos)");
                        return false;
                    }
                }
                
                // Modificar posição (usar símbolo em MT5)
                if(m_trade.PositionModify(symbol, new_sl, current_tp))
                {
                    // Registrar ativação
                    int size = ArraySize(m_activated_tickets);
                    ArrayResize(m_activated_tickets, size + 1);
                    m_activated_tickets[size] = ticket;
                    
                    m_total_activations_sell++;
                    
                    double protected_points = (entry_price - new_sl) / point;
                    
                    Print("✅ [BE] Break Even ativado para SELL #", ticket);
                    Print("   📊 Lucro atual: +", (int)profit_points, " pontos/pips");
                    Print("   🎯 Novo SL: ", new_sl, " (+", (int)protected_points, " pontos protegidos)");
                    Print("   📉 Entry: ", entry_price, " | TP: ", current_tp);
                    
                    return true;
                }
                else
                {
                    int ret = (int)m_trade.ResultRetcode();
                    Print("❌ [BE] Falha ao modificar SELL #", ticket, " - Retcode: ", ret, " (", m_trade.ResultRetcodeDescription(), ")");
                    Print("   📍 Tentou: SL=", new_sl, " TP=", current_tp, " | Price=", current_price, " | Entry=", entry_price);
                    return false;
                }
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Verifica se Break Even já foi ativado para um ticket             |
//+------------------------------------------------------------------+
bool CBreakEvenManager::IsBEActivated(ulong ticket)
{
    // Verificar se está na lista de ativados
    int size = ArraySize(m_activated_tickets);
    for(int i = 0; i < size; i++)
    {
        if(m_activated_tickets[i] == ticket)
            return true;
    }
    
    // Verificação adicional: analisar distância do SL atual
    if(!PositionSelectByTicket(ticket))
        return false;
    
    double entry = PositionGetDouble(POSITION_PRICE_OPEN);
    double sl = PositionGetDouble(POSITION_SL);
    ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    if(sl == 0)
        return false;
    
    // Referência APENAS no valor de SL vs Entry ± Step (com tolerância pequena)
    int step_threshold = (type == POSITION_TYPE_BUY) ? m_step_buy : m_step_sell;
    double point = SymbolInfoDouble(PositionGetString(POSITION_SYMBOL), SYMBOL_POINT);
    double tol = 2 * point; // 2 pontos de tolerância para arredondamentos
    
    if(type == POSITION_TYPE_BUY)
    {
        double target = entry + (step_threshold * point);
        return (sl >= (target - tol));
    }
    else // SELL
    {
        double target = entry - (step_threshold * point);
        return (sl <= (target + tol));
    }
}

//+------------------------------------------------------------------+
//| Reset das estatísticas e lista de tickets                        |
//+------------------------------------------------------------------+
void CBreakEvenManager::Reset(void)
{
    ArrayResize(m_activated_tickets, 0);
    m_total_activations_buy = 0;
    m_total_activations_sell = 0;
    m_total_saves = 0;
    
    Print("🔄 [BE] Estatísticas resetadas.");
}

//+------------------------------------------------------------------+
//| Imprime estatísticas do Break Even                               |
//+------------------------------------------------------------------+
void CBreakEvenManager::PrintStats(void)
{
    Print("═══════════════════════════════════════");
    Print("📊 [BE] ESTATÍSTICAS BREAK EVEN");
    Print("═══════════════════════════════════════");
    Print("📈 Ativações BUY: ", m_total_activations_buy);
    Print("📉 Ativações SELL: ", m_total_activations_sell);
    Print("💰 Total de Saves: ", m_total_saves);
    Print("🎯 Tickets Ativos: ", ArraySize(m_activated_tickets));
    Print("═══════════════════════════════════════");
}

//+------------------------------------------------------------------+
