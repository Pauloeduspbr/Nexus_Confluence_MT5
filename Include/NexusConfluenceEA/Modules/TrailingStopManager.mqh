//+------------------------------------------------------------------+
//|                                         TrailingStopManager.mqh |
//|                      Nexus Confluence EA - Módulo Trailing Stop  |
//|                       Gestão de Trailing Stop Individual BUY/SELL|
//+------------------------------------------------------------------+
#property copyright "Nexus Confluence EA"
#property version   "2.00"
#property strict

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Classe de Gerenciamento de Trailing Stop                         |
//+------------------------------------------------------------------+
class CTrailingStopManager
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
    datetime m_last_market_closed_log;
    
    // Registro de última atualização (evita updates excessivos)
    struct TrailingRecord
    {
        ulong    ticket;
        double   last_price;
        datetime last_update; // armazenará o horário da barra em que o último trailing foi aplicado
    };
    TrailingRecord m_trailing_records[];
    
    // Estatísticas
    int      m_total_updates_buy;
    int      m_total_updates_sell;
    int      m_total_profits_protected;
    
public:
    //--- Construtor/Destrutor
    CTrailingStopManager(void);
    ~CTrailingStopManager(void);
    
    //--- Inicialização
    bool Init(bool buy_enabled, int trigger_buy, int step_buy,
              bool sell_enabled, int trigger_sell, int step_sell);
    
    //--- Métodos principais
    bool Update(ulong ticket);
    bool IsTrailing(ulong ticket);
    void Reset(void);
    
    //--- Estatísticas
    int GetTotalUpdatesBuy(void) { return m_total_updates_buy; }
    int GetTotalUpdatesSell(void) { return m_total_updates_sell; }
    int GetTotalProfitsProtected(void) { return m_total_profits_protected; }
    
    //--- Utilidades
    void PrintStats(void);
    
private:
    //--- Métodos internos
    int FindRecordIndex(ulong ticket);
    void UpdateRecord(ulong ticket, double price, datetime bar_time);
    bool IsMarketOpenNow(const string symbol);
};

//+------------------------------------------------------------------+
//| Construtor                                                        |
//+------------------------------------------------------------------+
CTrailingStopManager::CTrailingStopManager(void)
{
    m_initialized = false;
    m_buy_enabled = false;
    m_sell_enabled = false;
    m_trigger_buy = 0;
    m_step_buy = 0;
    m_trigger_sell = 0;
    m_step_sell = 0;
    
    m_total_updates_buy = 0;
    m_total_updates_sell = 0;
    m_total_profits_protected = 0;
    
    ArrayResize(m_trailing_records, 0);
    m_last_market_closed_log = 0;
}

//+------------------------------------------------------------------+
//| Destrutor                                                         |
//+------------------------------------------------------------------+
CTrailingStopManager::~CTrailingStopManager(void)
{
    ArrayFree(m_trailing_records);
}

//+------------------------------------------------------------------+
//| Inicialização do módulo                                          |
//+------------------------------------------------------------------+
bool CTrailingStopManager::Init(bool buy_enabled, int trigger_buy, int step_buy,
                                 bool sell_enabled, int trigger_sell, int step_sell)
{
    // Obter STOPS_LEVEL do símbolo atual
    long stops_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
    
    // Validação de parâmetros BUY
    if(buy_enabled)
    {
        if(trigger_buy <= 0 || step_buy <= 0)
        {
            Print("❌ [TS] Erro: Parâmetros BUY inválidos. Trigger=", trigger_buy, " Step=", step_buy);
            return false;
        }
        
        // CRÍTICO: Step deve ser MAIOR que STOPS_LEVEL
        if(stops_level > 0 && step_buy <= stops_level)
        {
            Print("❌ [TS] ERRO CRÍTICO: Step BUY (", step_buy, ") deve ser MAIOR que STOPS_LEVEL (", stops_level, ")");
            Print("   💡 Configure InpTS_Buy_Step para pelo menos ", (stops_level + 10), " pontos");
            return false;
        }
        
        if(trigger_buy <= step_buy)
        {
            Print("⚠️ [TS] Aviso: TS Trigger BUY (", trigger_buy,
                  ") deve ser maior que Step (", step_buy, ")");
        }
    }
    
    // Validação de parâmetros SELL
    if(sell_enabled)
    {
        if(trigger_sell <= 0 || step_sell <= 0)
        {
            Print("❌ [TS] Erro: Parâmetros SELL inválidos. Trigger=", trigger_sell, " Step=", step_sell);
            return false;
        }
        
        // CRÍTICO: Step deve ser MAIOR que STOPS_LEVEL
        if(stops_level > 0 && step_sell <= stops_level)
        {
            Print("❌ [TS] ERRO CRÍTICO: Step SELL (", step_sell, ") deve ser MAIOR que STOPS_LEVEL (", stops_level, ")");
            Print("   💡 Configure InpTS_Sell_Step para pelo menos ", (stops_level + 10), " pontos");
            return false;
        }
        
        if(trigger_sell <= step_sell)
        {
            Print("⚠️ [TS] Aviso: TS Trigger SELL (", trigger_sell,
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
    Print("✅ [TS] Trailing Stop Manager inicializado:");
    Print("   📈 BUY: ", (m_buy_enabled ? "ATIVO" : "DESATIVADO"),
          " | Trigger=", m_trigger_buy, " | Step=", m_step_buy);
    Print("   📉 SELL: ", (m_sell_enabled ? "ATIVO" : "DESATIVADO"),
          " | Trigger=", m_trigger_sell, " | Step=", m_step_sell);
    
    return true;
}

//+------------------------------------------------------------------+
//| Atualiza Trailing Stop para uma posição                          |
//+------------------------------------------------------------------+
bool CTrailingStopManager::Update(ulong ticket)
{
    if(!m_initialized)
    {
        Print("❌ [TS] Erro: Módulo não inicializado. Chame Init() primeiro.");
        return false;
    }
    
    // Verificar se posição existe
    if(!PositionSelectByTicket(ticket))
    {
        return false;  // Posição já fechou
    }
    
    // Obter informações da posição
    ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    
    // Verificar se TS está habilitado para esta direção
    if(pos_type == POSITION_TYPE_BUY && !m_buy_enabled)
        return false;
    
    if(pos_type == POSITION_TYPE_SELL && !m_sell_enabled)
        return false;
    
    // Obter dados da posição
    double entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
    double current_sl = PositionGetDouble(POSITION_SL);
    double current_tp = PositionGetDouble(POSITION_TP);
    string symbol = PositionGetString(POSITION_SYMBOL);
    
    // DEBUG: Log do SL atual lido do broker
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    if(g_log_level >= 3)
    {
        Print("🔍 [TS DEBUG] #", ticket, " | current_sl lido do broker: ", DoubleToString(current_sl, digits),
              " | entry: ", DoubleToString(entry_price, digits), 
              " | tp: ", DoubleToString(current_tp, digits));
    }

    // ═══════════════════════════════════════════════════════
    // CRITICAL: Bloquear modificações quando mercado fechado
    // ═══════════════════════════════════════════════════════
    
    // Verificação 1: Trade mode do símbolo
    int trade_mode = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE);
    if(trade_mode == SYMBOL_TRADE_MODE_DISABLED || trade_mode == SYMBOL_TRADE_MODE_CLOSEONLY)
    {
        datetime now = TimeCurrent();
        if(m_last_market_closed_log==0 || (now - m_last_market_closed_log) >= 300)
        {
            Print("⏸️ [TS] Mercado FECHADO/CLOSEONLY para ", symbol, " (trade_mode=", trade_mode, ") - aguardando reabertura");
            m_last_market_closed_log = now;
        }
        return false;
    }
    
    // Verificação 2: Sessão de negociação
    if(!IsMarketOpenNow(symbol))
    {
        datetime now = TimeCurrent();
        if(m_last_market_closed_log==0 || (now - m_last_market_closed_log) >= 300)
        {
            Print("⏸️ [TS] Fora do horário de negociação para ", symbol, " - aguardando sessão abrir");
            m_last_market_closed_log = now;
        }
        return false;
    }
    
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
    int trigger, step;
    
    if(pos_type == POSITION_TYPE_BUY)
    {
        profit_points = (current_price - entry_price) / point;
        trigger = m_trigger_buy;
        step = m_step_buy;
        
        // Verificar se atingiu o trigger
        if(profit_points >= trigger)
        {
            // Tempo da barra atual (limitar a 1 ajuste por barra)
            datetime bar_time = iTime(symbol, PERIOD_CURRENT, 0);
            // ═══════════════════════════════════════════════════════
            // THROTTLING: Evitar updates excessivos
            // ═══════════════════════════════════════════════════════
            int record_idx = FindRecordIndex(ticket);
            if(record_idx >= 0)
            {
                double last_price = m_trailing_records[record_idx].last_price;
                double price_change = MathAbs(current_price - last_price) / point;
                
                // Só atualizar se preço moveu pelo menos 75% do step
                if(price_change < step * 0.75)
                {
                    // Se o preço não moveu o suficiente, bloquear updates
                    // inclusive na mesma barra
                    if(m_trailing_records[record_idx].last_update == bar_time)
                        return false;
                    
                    return false;
                }
                
                // Permitir update na mesma barra se movimento significativo (>=75% step)
                if(m_trailing_records[record_idx].last_update == bar_time && price_change < step * 0.75)
                    return false;
            }
            
            // ═══════════════════════════════════════════════════════
            // CÁLCULO DO TRAILING STOP (MODO GRADUAL)
            // ═══════════════════════════════════════════════════════
            // Para BUY: mover no máximo 1 passo (step) acima do SL atual
            // e nunca ultrapassar o alvo de distância do preço (preço_atual - step)
            double target_sl = NormalizeDouble(current_price - (step * point), digits);
            double candidate_sl;
            if(current_sl > 0)
                candidate_sl = NormalizeDouble(current_sl + (step * point), digits);
            else
                candidate_sl = NormalizeDouble(entry_price + ((trigger - step) * point), digits);
            
            // CORREÇÃO CRÍTICA: Usar MathMax para BUY (SL deve SUBIR)
            double new_sl = MathMax(current_sl, MathMin(target_sl, candidate_sl));
            new_sl = NormalizeDouble(new_sl, digits);
            
            // DEBUG: Log do cálculo do trailing
            if(g_log_level >= 3)
            {
                Print("🔍 [TS DEBUG CALC] #", ticket, " BUY:");
                Print("   current_sl: ", DoubleToString(current_sl, digits));
                Print("   target_sl: ", DoubleToString(target_sl, digits), " (preço - step)");
                Print("   candidate_sl: ", DoubleToString(candidate_sl, digits), " (current + step)");
                Print("   new_sl calculado: ", DoubleToString(new_sl, digits));
                Print("   Diferença |new_sl - current_sl|: ", DoubleToString(MathAbs(new_sl - current_sl), digits + 3));
                Print("   point: ", DoubleToString(point, digits + 3));
            }
            
            // Garantir que SL só SOBE (nunca desce em BUY)
            if(current_sl > 0 && new_sl <= current_sl)
            {
                // Preço não moveu o suficiente, manter SL atual
                if(g_log_level >= 3)
                {
                    Print("⏸️ [TS DEBUG] #", ticket, " BUY: new_sl <= current_sl, bloqueando");
                }
                return false;
            }
            
            // ═══════════════════════════════════════════════════════
            // VALIDAÇÃO CRÍTICA: Evitar modificação se SL é idêntico
            // ═══════════════════════════════════════════════════════
            if(current_sl > 0 && MathAbs(new_sl - current_sl) < point)
            {
                // SL já está no valor calculado, não modificar
                if(g_log_level >= 3)
                {
                    Print("⏸️ [TS DEBUG] #", ticket, " BUY: SL idêntico detectado!");
                    Print("   new_sl: ", DoubleToString(new_sl, digits));
                    Print("   current_sl: ", DoubleToString(current_sl, digits));
                    Print("   Diferença: ", DoubleToString(MathAbs(new_sl - current_sl), digits + 3));
                    Print("   Limite (point): ", DoubleToString(point, digits + 3));
                }
                return false;
            }
            
            // ═══════════════════════════════════════════════════════
            // VALIDAÇÃO CRÍTICA: SL não pode ultrapassar TP em BUY
            // ═══════════════════════════════════════════════════════
            if(current_tp > 0)
            {
                // Para BUY: SL deve estar ABAIXO do TP
                if(new_sl >= current_tp)
                {
                    // Ajustar SL para ficar alguns pips abaixo do TP
                    double safe_distance = 10 * point; // 10 pontos de segurança
                    new_sl = NormalizeDouble(current_tp - safe_distance, digits);
                    
                    // Se ainda assim SL não é válido, não atualizar
                    if(new_sl <= current_sl)
                    {
                        Print("⚠️ [TS] BUY #", ticket, ": SL já próximo ao TP. Não é possível trailing.");
                        return false;
                    }
                    
                    Print("⚠️ [TS] BUY #", ticket, ": SL ajustado para ficar abaixo do TP");
                }
            }
            
            // Verificar se novo SL é melhor que o atual
            if(new_sl > current_sl || current_sl == 0)
            {
                // Verificar distância mínima do stop level
                long stop_level = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
                double min_distance = stop_level * point;
                
                if(stop_level > 0)
                {
                    double distance_to_price = (current_price - new_sl) / point;
                    if(distance_to_price <= stop_level)
                    {
                        Print("⚠️ [TS] BUY #", ticket, ": SL muito próximo do preço (stops_level=", stop_level, ")");
                        Print("   🔍 DEBUG: price=", DoubleToString(current_price, digits), 
                              " | new_sl=", DoubleToString(new_sl, digits),
                              " | distance=", DoubleToString(distance_to_price, 1), " pontos",
                              " | step=", step, " | point=", DoubleToString(point, digits));
                        Print("   💡 Aumente InpTS_Buy_Step para pelo menos ", (stop_level + 10), " pontos");
                        return false;
                    }
                }
                
                // Modificar posição (usar símbolo em MT5)
                if(m_trade.PositionModify(symbol, new_sl, current_tp))
                {
                    m_total_updates_buy++;
                    
                    // ═══════════════════════════════════════════════════════
                    // CORREÇÃO CRÍTICA: Gravar preço ATUAL, não new_sl + step
                    // Isso permite que o próximo trailing seja baseado no preço real
                    // ═══════════════════════════════════════════════════════
                    UpdateRecord(ticket, current_price, bar_time);
                    
                    double protected_profit = (new_sl - entry_price) / point;
                    
                    Print("🚀 [TS] Trailing Stop ajustado para BUY #", ticket);
                    Print("   📊 Lucro atual: +", (int)profit_points, " pontos/pips");
                    Print("   🎯 Novo SL: ", new_sl, " (protegendo +", (int)protected_profit, " pontos)");
                    Print("   📈 Preço: ", current_price, " | Entry: ", entry_price, " | TP: ", current_tp);
                    
                    return true;
                }
                else
                {
                    uint retcode = m_trade.ResultRetcode();
                    int error = GetLastError();
                    
                    // Tratamento especial para mercado fechado
                    if(retcode == TRADE_RETCODE_MARKET_CLOSED)
                    {
                        datetime now = TimeCurrent();
                        if(m_last_market_closed_log==0 || (now - m_last_market_closed_log) >= 300)
                        {
                            Print("⏸️ [TS] BUY #", ticket, ": Mercado fechado (retcode=", retcode, ") - aguardando reabertura");
                            m_last_market_closed_log = now;
                        }
                        return false;
                    }
                    
                    Print("❌ [TS] Falha ao modificar BUY #", ticket, " - Retcode: ", retcode, " | Erro: ", error);
                    Print("   📍 Tentou: SL=", new_sl, " TP=", current_tp, " | Preço=", current_price);
                    return false;
                }
            }
        }
    }
    else // POSITION_TYPE_SELL
    {
        profit_points = (entry_price - current_price) / point;
        trigger = m_trigger_sell;
        step = m_step_sell;
        
        // Verificar se atingiu o trigger
        if(profit_points >= trigger)
        {
            // Tempo da barra atual (limitar a 1 ajuste por barra)
            datetime bar_time = iTime(symbol, PERIOD_CURRENT, 0);
            // ═══════════════════════════════════════════════════════
            // THROTTLING: Evitar updates excessivos
            // ═══════════════════════════════════════════════════════
            int record_idx = FindRecordIndex(ticket);
            if(record_idx >= 0)
            {
                double last_price = m_trailing_records[record_idx].last_price;
                double price_change = MathAbs(current_price - last_price) / point;
                
                // Só atualizar se preço moveu pelo menos 75% do step
                if(price_change < step * 0.75)
                {
                    // Se o preço não moveu o suficiente, bloquear updates
                    // inclusive na mesma barra
                    if(m_trailing_records[record_idx].last_update == bar_time)
                        return false;
                    
                    return false;
                }
                
                // Permitir update na mesma barra se movimento significativo (>=75% step)
                if(m_trailing_records[record_idx].last_update == bar_time && price_change < step * 0.75)
                    return false;
            }
            
            // ═══════════════════════════════════════════════════════
            // CÁLCULO DO TRAILING STOP (MODO GRADUAL)
            // ═══════════════════════════════════════════════════════
            // Para SELL: mover no máximo 1 passo (step) abaixo do SL atual
            // e nunca ultrapassar o alvo de distância do preço (preço_atual + step)
            double target_sl = NormalizeDouble(current_price + (step * point), digits);
            double candidate_sl;
            if(current_sl > 0)
                candidate_sl = NormalizeDouble(current_sl - (step * point), digits);
            else
                candidate_sl = NormalizeDouble(entry_price - ((trigger - step) * point), digits);
            
            // CORREÇÃO CRÍTICA: Usar MathMin para SELL (SL deve DESCER)
            double new_sl = MathMin(current_sl, MathMax(target_sl, candidate_sl));
            new_sl = NormalizeDouble(new_sl, digits);
            
            // DEBUG: Log do cálculo do trailing
            if(g_log_level >= 3)
            {
                Print("🔍 [TS DEBUG CALC] #", ticket, " SELL:");
                Print("   current_sl: ", DoubleToString(current_sl, digits));
                Print("   target_sl: ", DoubleToString(target_sl, digits), " (preço + step)");
                Print("   candidate_sl: ", DoubleToString(candidate_sl, digits), " (current - step)");
                Print("   new_sl calculado: ", DoubleToString(new_sl, digits));
                Print("   Diferença |new_sl - current_sl|: ", DoubleToString(MathAbs(new_sl - current_sl), digits + 3));
                Print("   point: ", DoubleToString(point, digits + 3));
            }
            
            // Garantir que SL só DESCE (nunca sobe em SELL)
            if(current_sl > 0 && new_sl >= current_sl)
            {
                // Preço não moveu o suficiente, manter SL atual
                if(g_log_level >= 3)
                {
                    Print("⏸️ [TS DEBUG] #", ticket, " SELL: new_sl >= current_sl, bloqueando");
                }
                return false;
            }
            
            // ═══════════════════════════════════════════════════════
            // VALIDAÇÃO CRÍTICA: Evitar modificação se SL é idêntico
            // ═══════════════════════════════════════════════════════
            if(current_sl > 0 && MathAbs(new_sl - current_sl) < point)
            {
                // SL já está no valor calculado, não modificar
                if(g_log_level >= 3)
                {
                    Print("⏸️ [TS DEBUG] #", ticket, " SELL: SL idêntico detectado!");
                    Print("   new_sl: ", DoubleToString(new_sl, digits));
                    Print("   current_sl: ", DoubleToString(current_sl, digits));
                    Print("   Diferença: ", DoubleToString(MathAbs(new_sl - current_sl), digits + 3));
                    Print("   Limite (point): ", DoubleToString(point, digits + 3));
                }
                return false;
            }
            
            // ═══════════════════════════════════════════════════════
            // VALIDAÇÃO CRÍTICA: SL não pode ultrapassar TP em SELL
            // ═══════════════════════════════════════════════════════
            if(current_tp > 0)
            {
                // Para SELL: SL deve estar ACIMA do TP
                if(new_sl <= current_tp)
                {
                    // Ajustar SL para ficar alguns pips acima do TP
                    double safe_distance = 10 * point; // 10 pontos de segurança
                    new_sl = NormalizeDouble(current_tp + safe_distance, digits);
                    
                    // Se ainda assim SL não é válido, não atualizar
                    if(new_sl >= current_sl && current_sl > 0)
                    {
                        Print("⚠️ [TS] SELL #", ticket, ": SL já próximo ao TP. Não é possível trailing.");
                        return false;
                    }
                    
                    Print("⚠️ [TS] SELL #", ticket, ": SL ajustado para ficar acima do TP");
                }
            }
            
            // Verificar se novo SL é melhor que o atual (menor para SELL)
            if(new_sl < current_sl || current_sl == 0)
            {
                // Verificar distância mínima do stop level
                long stop_level = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
                double min_distance = stop_level * point;
                
                if(stop_level > 0)
                {
                    double distance_to_price = (new_sl - current_price) / point;
                    if(distance_to_price <= stop_level)
                    {
                        Print("⚠️ [TS] SELL #", ticket, ": SL muito próximo do preço (stops_level=", stop_level, ")");
                        Print("   🔍 DEBUG: price=", DoubleToString(current_price, digits),
                              " | new_sl=", DoubleToString(new_sl, digits),
                              " | distance=", DoubleToString(distance_to_price, 1), " pontos",
                              " | step=", step, " | point=", DoubleToString(point, digits));
                        Print("   💡 Aumente InpTS_Sell_Step para pelo menos ", (stop_level + 10), " pontos");
                        return false;
                    }
                }
                
                // Modificar posição (usar símbolo em MT5)
                if(m_trade.PositionModify(symbol, new_sl, current_tp))
                {
                    m_total_updates_sell++;
                    
                    // ═══════════════════════════════════════════════════════
                    // CORREÇÃO CRÍTICA: Gravar preço ATUAL, não new_sl - step
                    // Isso permite que o próximo trailing seja baseado no preço real
                    // ═══════════════════════════════════════════════════════
                    UpdateRecord(ticket, current_price, bar_time);
                    
                    double protected_profit = (entry_price - new_sl) / point;
                    
                    Print("🚀 [TS] Trailing Stop ajustado para SELL #", ticket);
                    Print("   📊 Lucro atual: +", (int)profit_points, " pontos/pips");
                    Print("   🎯 Novo SL: ", new_sl, " (protegendo +", (int)protected_profit, " pontos)");
                    Print("   📉 Preço: ", current_price, " | Entry: ", entry_price, " | TP: ", current_tp);
                    
                    return true;
                }
                else
                {
                    uint retcode = m_trade.ResultRetcode();
                    int error = GetLastError();
                    
                    // Tratamento especial para mercado fechado
                    if(retcode == TRADE_RETCODE_MARKET_CLOSED)
                    {
                        datetime now = TimeCurrent();
                        if(m_last_market_closed_log==0 || (now - m_last_market_closed_log) >= 300)
                        {
                            Print("⏸️ [TS] SELL #", ticket, ": Mercado fechado (retcode=", retcode, ") - aguardando reabertura");
                            m_last_market_closed_log = now;
                        }
                        return false;
                    }
                    
                    Print("❌ [TS] Falha ao modificar SELL #", ticket, " - Retcode: ", retcode, " | Erro: ", error);
                    Print("   📍 Tentou: SL=", new_sl, " TP=", current_tp, " | Preço=", current_price);
                    return false;
                }
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Verifica se Trailing Stop está ativo para um ticket              |
//+------------------------------------------------------------------+
bool CTrailingStopManager::IsTrailing(ulong ticket)
{
    return (FindRecordIndex(ticket) >= 0);
}

//+------------------------------------------------------------------+
//| Reset das estatísticas e registros                               |
//+------------------------------------------------------------------+
void CTrailingStopManager::Reset(void)
{
    ArrayResize(m_trailing_records, 0);
    m_total_updates_buy = 0;
    m_total_updates_sell = 0;
    m_total_profits_protected = 0;
    
    Print("🔄 [TS] Estatísticas resetadas.");
}

//+------------------------------------------------------------------+
//| Imprime estatísticas do Trailing Stop                            |
//+------------------------------------------------------------------+
void CTrailingStopManager::PrintStats(void)
{
    Print("═══════════════════════════════════════");
    Print("📊 [TS] ESTATÍSTICAS TRAILING STOP");
    Print("═══════════════════════════════════════");
    Print("📈 Atualizações BUY: ", m_total_updates_buy);
    Print("📉 Atualizações SELL: ", m_total_updates_sell);
    Print("💰 Lucros Protegidos: ", m_total_profits_protected);
    Print("🎯 Posições em Trailing: ", ArraySize(m_trailing_records));
    Print("═══════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Encontra índice de um ticket nos registros                       |
//+------------------------------------------------------------------+
int CTrailingStopManager::FindRecordIndex(ulong ticket)
{
    int size = ArraySize(m_trailing_records);
    for(int i = 0; i < size; i++)
    {
        if(m_trailing_records[i].ticket == ticket)
            return i;
    }
    return -1;
}

//+------------------------------------------------------------------+
//| Atualiza ou cria registro de trailing para um ticket             |
//+------------------------------------------------------------------+
void CTrailingStopManager::UpdateRecord(ulong ticket, double price, datetime bar_time)
{
    int idx = FindRecordIndex(ticket);
    
    if(idx >= 0)
    {
        // Atualizar registro existente
        m_trailing_records[idx].last_price = price;
        m_trailing_records[idx].last_update = bar_time;
    }
    else
    {
        // Criar novo registro
        int size = ArraySize(m_trailing_records);
        ArrayResize(m_trailing_records, size + 1);
        
        m_trailing_records[size].ticket = ticket;
        m_trailing_records[size].last_price = price;
        m_trailing_records[size].last_update = bar_time;
    }
}

//+------------------------------------------------------------------+
//| Helper: Verifica se o símbolo está em sessão de negociação       |
//+------------------------------------------------------------------+
bool CTrailingStopManager::IsMarketOpenNow(const string symbol)
{
    MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
    datetime from=0, to=0;
    bool has_sessions=false;
    for(uint i=0; SymbolInfoSessionTrade(symbol, (ENUM_DAY_OF_WEEK)dt.day_of_week, i, from, to); i++)
    {
        has_sessions=true;
        MqlDateTime f; TimeToStruct(from, f);
        MqlDateTime t; TimeToStruct(to, t);
        int nowMin = dt.hour*60 + dt.min;
        int fromMin = f.hour*60 + f.min;
        int toMin   = t.hour*60 + t.min;
        if(fromMin <= toMin)
        {
            if(nowMin >= fromMin && nowMin < toMin)
                return true;
        }
        else
        {
            if(nowMin >= fromMin || nowMin < toMin)
                return true;
        }
    }
    if(!has_sessions) return true;
    return false;
}

//+------------------------------------------------------------------+
