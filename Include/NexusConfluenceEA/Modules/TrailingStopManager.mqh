//+------------------------------------------------------------------+
//|                                         TrailingStopManager.mqh |
//|                      Nexus Confluence EA - Módulo Trailing Stop  |
//|                       Gestão de Trailing Stop Individual BUY/SELL|
//|                                   v2.54 - Directional Throttling |
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
    
    // ✅ v2.53: Throttling de log "Aguardando trigger"
    datetime m_last_waiting_log_time;
    
    // Registro de última atualização (evita updates excessivos)
    struct TrailingRecord
    {
        ulong    ticket;
        double   last_price;
        datetime last_update; // armazenará o horário da barra em que o último trailing foi aplicado
        // Controle de falhas/deduplicação por candle
        uint     last_retcode;
        int      last_error;
        double   last_attempt_sl;
        datetime last_failure_log_time;
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
    
    m_last_waiting_log_time = 0;  // ✅ v2.53: Inicializa throttling de log
    
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
    // ✅ v2.63 UNIVERSAL CONVERSION: User input = PRICE DISTANCE (points)
    string symbol = Symbol();
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    
    int trigger_buy_converted = trigger_buy;
    int step_buy_converted = step_buy;
    int trigger_sell_converted = trigger_sell;
    int step_sell_converted = step_sell;
    
    if(tick_size > point)
    {
        // B3/Special assets: convert input points to steps
        // Formula: steps = input_points / tick_size
        trigger_buy_converted = (int)MathRound(trigger_buy / tick_size);
        step_buy_converted = (int)MathRound(step_buy / tick_size);
        trigger_sell_converted = (int)MathRound(trigger_sell / tick_size);
        step_sell_converted = (int)MathRound(step_sell / tick_size);
        
        Print("✅ v2.63 [TS]: Universal conversion (input points → steps):");
        Print(StringFormat("   • BUY Trigger: %d input → %d steps (%.1f distance)",
              trigger_buy, trigger_buy_converted, trigger_buy_converted * tick_size));
        Print(StringFormat("   • BUY Step: %d input → %d steps (%.1f distance)",
              step_buy, step_buy_converted, step_buy_converted * tick_size));
        Print(StringFormat("   • SELL Trigger: %d input → %d steps (%.1f distance)",
              trigger_sell, trigger_sell_converted, trigger_sell_converted * tick_size));
        Print(StringFormat("   • SELL Step: %d input → %d steps (%.1f distance)",
              step_sell, step_sell_converted, step_sell_converted * tick_size));
    }
    
    // ✅ v2.63: STOPS_LEVEL validation REMOVED for Trailing Stop
    // STOPS_LEVEL is for INITIAL SL/TP distance from entry
    // Trailing Stop moves SL PROGRESSIVELY as profit increases
    // TS can use smaller steps because SL is already far from entry!
    // Example Forex: STOPS_LEVEL=20 pips, but TS Step=5 pips is perfectly fine!
    
    // Validação de parâmetros BUY
    if(buy_enabled)
    {
        if(trigger_buy_converted <= 0 || step_buy_converted <= 0)
        {
            Print("❌ [TS] Erro: Parâmetros BUY inválidos. Trigger=", trigger_buy_converted, " Step=", step_buy_converted);
            return false;
        }
        
        // ✅ v2.63 RELAXED VALIDATION: Minimum ratio 2:1 (was 20:1)
        // With correct price distance conversion, 3:1 ratio is perfectly valid!
        // Technical minimum: 2:1 for throttling to work (75% rule)
        // User example: Trigger=15 / Step=5 = 3:1 ✅ (good ratio!)
        double ratio;
        if(tick_size > point)
        {
            // Use original user inputs for ratio validation
            ratio = (double)trigger_buy / (double)step_buy;
        }
        else
        {
            // Use converted values for point-based assets (indices)
            ratio = (double)trigger_buy_converted / (double)step_buy_converted;
        }
        
        if(ratio < 2.0)
        {
            Print("❌ [TS] ERRO: Proporção Trigger:Step BUY muito baixa!");
            Print("   📊 Atual: Trigger=", trigger_buy, " / Step=", step_buy, " = ", DoubleToString(ratio, 1), ":1");
            Print("   ⚠️ Mínimo técnico: ratio >= 2:1 (para throttling funcionar)");
            Print("   💡 RECOMENDAÇÃO:");
            Print("      Opção 1: Reduza Step para ", (int)(trigger_buy / 3), " pontos (ratio 3:1)");
            Print("      Opção 2: Aumente Trigger para ", (step_buy * 3), " pontos (ratio 3:1)");
            Print("   ✅ BOAS PROPORÇÕES: 2:1 (mínimo) | 3:1 (bom) | 5:1 (ótimo)");
            return false;
        }
        
        // ✅ v2.59 CRITICAL VALIDATION: After conversion, Trigger MUST be > Step
        // With WDOZ25: 400pts→1, 15pts→1 both round to 1 → Trigger=Step=1 ❌
        // This breaks throttling (75% rule requires Step × 1.33 movement)
        if(trigger_buy_converted <= step_buy_converted)
        {
            Print("❌ [TS] ERRO CRÍTICO: Trigger BUY convertido não é maior que Step convertido!");
            Print("   📊 Após conversão: Trigger=", trigger_buy_converted, " Step=", step_buy_converted);
            Print("   ⚠️ IMPOSSÍVEL: Throttling (75% rule) falha com Trigger≤Step");
            Print("   💡 SOLUÇÃO:");
            Print("      Para WDOZ25 (tick_size=0.5):");
            Print("      - Aumente Trigger para >= 1000 pontos (→ 2 steps = 1.0 distance)");
            Print("      - Mantenha Step em 15 pontos (→ 1 step = 0.5 distance)");
            Print("      - Resultado: ratio 2:1 permite throttling");
            return false;
        }
    }
    
    // Validação de parâmetros SELL
    if(sell_enabled)
    {
        if(trigger_sell_converted <= 0 || step_sell_converted <= 0)
        {
            Print("❌ [TS] Erro: Parâmetros SELL inválidos. Trigger=", trigger_sell_converted, " Step=", step_sell_converted);
            return false;
        }
        
        // ✅ v2.63: STOPS_LEVEL validation REMOVED for Trailing Stop
        // STOPS_LEVEL is for INITIAL SL/TP distance from entry
        // Trailing Stop moves SL PROGRESSIVELY as profit increases
        // TS can use smaller steps because SL is already far from entry!
        // Example Forex: STOPS_LEVEL=20 pips, but TS Step=5 pips is perfectly fine!
        
        // ✅ v2.63 RELAXED VALIDATION: Minimum ratio 2:1 (was 20:1)
        // With correct price distance conversion, 3:1 ratio is perfectly valid!
        // Technical minimum: 2:1 for throttling to work (75% rule)
        double ratio;
        if(tick_size > point)
        {
            // Use original user inputs for ratio validation
            ratio = (double)trigger_sell / (double)step_sell;
        }
        else
        {
            // Use converted values for point-based assets (indices)
            ratio = (double)trigger_sell_converted / (double)step_sell_converted;
        }
        
        if(ratio < 2.0)
        {
            Print("❌ [TS] ERRO: Proporção Trigger:Step SELL muito baixa!");
            Print("   📊 Atual: Trigger=", trigger_sell, " / Step=", step_sell, " = ", DoubleToString(ratio, 1), ":1");
            Print("   ⚠️ Mínimo técnico: ratio >= 2:1 (para throttling funcionar)");
            Print("   💡 RECOMENDAÇÃO:");
            Print("      Opção 1: Reduza Step para ", (int)(trigger_sell / 3), " pontos (ratio 3:1)");
            Print("      Opção 2: Aumente Trigger para ", (step_sell * 3), " pontos (ratio 3:1)");
            Print("   ✅ BOAS PROPORÇÕES: 2:1 (mínimo) | 3:1 (bom) | 5:1 (ótimo)");
            return false;
        }
        
        // ✅ v2.59 CRITICAL VALIDATION: After conversion, Trigger MUST be > Step
        // With WDOZ25: 400pts→1, 15pts→1 both round to 1 → Trigger=Step=1 ❌
        // This breaks throttling (75% rule requires Step × 1.33 movement)
        if(trigger_sell_converted <= step_sell_converted)
        {
            Print("❌ [TS] ERRO CRÍTICO: Trigger SELL convertido não é maior que Step convertido!");
            Print("   📊 Após conversão: Trigger=", trigger_sell_converted, " Step=", step_sell_converted);
            Print("   ⚠️ IMPOSSÍVEL: Throttling (75% rule) falha com Trigger≤Step");
            Print("   💡 SOLUÇÃO:");
            Print("      Para WDOZ25 (tick_size=0.5):");
            Print("      - Aumente Trigger para >= 1000 pontos (→ 2 steps = 1.0 distance)");
            Print("      - Mantenha Step em 15 pontos (→ 1 step = 0.5 distance)");
            Print("      - Resultado: ratio 2:1 permite throttling");
            return false;
        }
    }
    
    // Armazenar configurações CONVERTIDAS
    m_buy_enabled = buy_enabled;
    m_trigger_buy = trigger_buy_converted;  // v2.58: Now in STEPS
    m_step_buy = step_buy_converted;        // v2.58: Now in STEPS
    
    m_sell_enabled = sell_enabled;
    m_trigger_sell = trigger_sell_converted;  // v2.58: Now in STEPS
    m_step_sell = step_sell_converted;        // v2.58: Now in STEPS
    
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

    // ═══════════════════════════════════════════════════════
    // CRITICAL: Bloquear modificações quando mercado fechado
    // ═══════════════════════════════════════════════════════
    
    // ═══════════════════════════════════════════════════════
    // CRITICAL: Bloquear modificações quando mercado fechado
    // ═══════════════════════════════════════════════════════
    // ✅ CORREÇÃO v2.50: Trailing Stop pode modificar posições existentes
    //    MESMO FORA do horário de abertura de novas ordens!
    // ❌ ERRO ANTERIOR: Checava IsMarketOpenNow() que usa sessões TRADE
    //    → Bloqueava TS às 11:05 (fora da sessão B3 mas mercado ABERTO)
    // ✅ CORRETO: Apenas verificar se mercado não está FECHADO (TRADE_MODE)
    // ═══════════════════════════════════════════════════════
    
    // Verificação ÚNICA: Trade mode do símbolo (mercado não pode estar completamente fechado)
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
    
    // ✅ REMOVIDO: IsMarketOpenNow() - Trailing Stop pode operar a qualquer momento
    //    que o mercado tenha quotes, mesmo fora do horário de abertura de novas posições
    
    // Obter preço atual
    double current_price;
    if(pos_type == POSITION_TYPE_BUY)
        current_price = SymbolInfoDouble(symbol, SYMBOL_BID);
    else
        current_price = SymbolInfoDouble(symbol, SYMBOL_ASK);
    
    // Informações do símbolo
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    // ✅ v2.57 FIX: Usar TICK_SIZE (B3/Forex) ou POINT (Índices) universalmente
    // WDOZ25: tick_size=0.5 > point=0.001 → usa 0.5
    // WINZ25: tick_size=1 = point=1 → usa 1
    double price_step = (tick_size > point) ? tick_size : point;
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    
    // Calcular lucro em pontos/pips
    double profit_points;
    int trigger, step;
    
    if(pos_type == POSITION_TYPE_BUY)
    {
        profit_points = (current_price - entry_price) / price_step;  // v2.57
        trigger = m_trigger_buy;
        step = m_step_buy;
        
        // ✅ v2.53 FIX: Log throttling - apenas a cada 60s para evitar spam
        if(profit_points < trigger)
        {
            datetime now = TimeCurrent();
            if(now - m_last_waiting_log_time >= 60)
            {
                Print("⏳ [TS] BUY #", ticket, ": Aguardando trigger (lucro=", DoubleToString(profit_points, 1), 
                      " / ", trigger, " pontos) | ", DoubleToString((profit_points/trigger)*100, 1), "%");
                m_last_waiting_log_time = now;
            }
            return false;
        }
        
        // Verificar se atingiu o trigger
        if(profit_points >= trigger)
        {
            // ✅ v2.51 FIX: Log detalhado quando trigger é atingido
            Print("🔍 [TS] BUY #", ticket, " TRIGGER ATINGIDO:");
            Print("   💰 Lucro atual: +", DoubleToString(profit_points, 1), " pontos (trigger=", trigger, ")");
            Print("   📍 Entry=", entry_price, " | Current=", current_price, " | SL=", current_sl, " | TP=", current_tp);
            
            // Tempo da barra atual (limitar a 1 ajuste por barra)
            datetime bar_time = iTime(symbol, PERIOD_CURRENT, 0);
            // ═══════════════════════════════════════════════════════
            // THROTTLING: Evitar updates excessivos
            // ✅ v2.54 FIX BUG #13: Throttling direcional (apenas movimentos favoráveis)
            // ═══════════════════════════════════════════════════════
            int record_idx = FindRecordIndex(ticket);
            if(record_idx >= 0)
            {
                double last_price = m_trailing_records[record_idx].last_price;
                
                // ✅ v2.54 CRITICAL FIX: Movimento DIRECIONAL (sem MathAbs)
                // Para BUY: Apenas aceitar quando preço SUBIU (price_change > 0)
                double price_change = (current_price - last_price) / price_step;  // v2.57
                double min_required = step * 0.75;
                
                // ✅ v2.54 FIX: Log com sinal (positivo/negativo)
                Print("   📊 Throttling: last_price=", last_price, 
                      " | price_change=", (price_change >= 0 ? "+" : ""), DoubleToString(price_change, 1), 
                      " pontos | min_required=+", DoubleToString(min_required, 1), " (75% de ", step, ")");
                
                // ✅ v2.54 CRITICAL: BUY só aceita movimento POSITIVO >= min_required
                if(price_change < min_required)
                {
                    if(price_change < 0)
                        Print("   ⏸️ [TS] BUY #", ticket, " BLOQUEADO: Preço CAIU (", 
                              DoubleToString(price_change, 1), " pontos) - TS só sobe quando preço sobe");
                    else
                        Print("   ⏸️ [TS] BUY #", ticket, " BLOQUEADO: Movimento insuficiente (", 
                              DoubleToString(price_change, 1), " < +", DoubleToString(min_required, 1), " pontos)");
                    
                    // Se o preço não moveu o suficiente, bloquear updates
                    // inclusive na mesma barra
                    if(m_trailing_records[record_idx].last_update == bar_time)
                        return false;
                    
                    return false;
                }
                
                // Permitir update na mesma barra se movimento significativo (>=75% step)
                if(m_trailing_records[record_idx].last_update == bar_time && price_change < min_required)
                    return false;
            }
            else
            {
                // ✅ v2.51 FIX: Primeira vez que TS é acionado para este ticket
                Print("   ✨ [TS] BUY #", ticket, " PRIMEIRA ATIVAÇÃO (sem registro anterior)");
            }
            
            // ═══════════════════════════════════════════════════════
            // CÁLCULO DO TRAILING STOP (MODO GRADUAL)
            // ═══════════════════════════════════════════════════════
            // Para BUY: mover no máximo 1 passo (step) acima do SL atual
            // e nunca ultrapassar o alvo de distância do preço (preço_atual - step)
            double target_sl = NormalizeDouble(current_price - (step * price_step), digits);  // v2.57
            double candidate_sl;
            if(current_sl > 0)
                candidate_sl = NormalizeDouble(current_sl + (step * price_step), digits);  // v2.57
            else
                candidate_sl = NormalizeDouble(entry_price + ((trigger - step) * price_step), digits);  // v2.57
            
            // ✅ v2.51 FIX: Log detalhado do cálculo
            Print("   🧮 Cálculo SL: target_sl=", target_sl, " | candidate_sl=", candidate_sl);
            
            // CORREÇÃO CRÍTICA: Usar MathMax para BUY (SL deve SUBIR)
            double new_sl = MathMax(current_sl, MathMin(target_sl, candidate_sl));
            new_sl = NormalizeDouble(new_sl, digits);
            
            Print("   🎯 Novo SL calculado: ", new_sl, " (current_sl=", current_sl, ")");
            
            // Garantir que SL só SOBE (nunca desce em BUY)
            if(current_sl > 0 && new_sl <= current_sl)
            {
                Print("   ⏸️ [TS] BUY #", ticket, " BLOQUEADO: SL não subiu (new=", new_sl, " <= current=", current_sl, ")");
                // Preço não moveu o suficiente, manter SL atual
                return false;
            }
            
            // ═══════════════════════════════════════════════════════
            // VALIDAÇÃO CRÍTICA: Evitar modificação se SL é idêntico
            // ═══════════════════════════════════════════════════════
            if(current_sl > 0 && MathAbs(new_sl - current_sl) < price_step)  // v2.57
            {
                Print("   ⏸️ [TS] BUY #", ticket, " BLOQUEADO: SL já está no valor calculado (diff < 1 step)");
                // SL já está no valor calculado, não modificar
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
                    Print("   ⚠️ [TS] BUY #", ticket, " AVISO: SL (", new_sl, ") >= TP (", current_tp, ") - ajustando...");
                    
                    // Ajustar SL para ficar alguns pips abaixo do TP
                    double safe_distance = 10 * point; // 10 pontos de segurança
                    new_sl = NormalizeDouble(current_tp - safe_distance, digits);
                    
                    // Se ainda assim SL não é válido, não atualizar
                    if(new_sl <= current_sl)
                    {
                        Print("   ⏸️ [TS] BUY #", ticket, " BLOQUEADO: SL já próximo ao TP. Não é possível trailing.");
                        return false;
                    }
                    
                    Print("   ✅ [TS] BUY #", ticket, ": SL ajustado para ", new_sl, " (abaixo do TP)");
                }
            }
            
            // Verificar se novo SL é melhor que o atual
            if(new_sl > current_sl || current_sl == 0)
            {
                Print("   ✅ [TS] BUY #", ticket, " VALIDANDO: new_sl=", new_sl, " > current_sl=", current_sl);
                
                // Verificar distância mínima do stop level
                long stop_level = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
                double min_distance = stop_level * price_step;  // v2.57
                
                Print("   📏 STOPS_LEVEL: ", stop_level, " pontos | min_distance: ", DoubleToString(min_distance, digits));
                
                if(stop_level > 0)
                {
                    double distance_to_price = (current_price - new_sl) / price_step;  // v2.57
                    Print("   📏 Distance to price: ", DoubleToString(distance_to_price, 1), " pontos (required > ", stop_level, ")");
                    
                    if(distance_to_price <= stop_level)
                    {
                        Print("   ⏸️ [TS] BUY #", ticket, " BLOQUEADO: SL muito próximo do preço");
                        Print("      ❌ distance=", DoubleToString(distance_to_price, 1), " <= stops_level=", stop_level);
                        Print("      🔍 DEBUG: price=", DoubleToString(current_price, digits), 
                              " | new_sl=", DoubleToString(new_sl, digits),
                              " | step=", step, " | price_step=", DoubleToString(price_step, digits));  // v2.57
                        Print("      💡 Aumente InpTS_Buy_Step para pelo menos ", (stop_level + 10), " pontos");
                        return false;
                    }
                }
                
                // Verificar FREEZE_LEVEL do broker (bloqueia modificações muito próximas)
                long freeze_level = SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
                Print("   ❄️ FREEZE_LEVEL: ", freeze_level, " pontos");
                
                if(freeze_level > 0)
                {
                    double freeze_distance = (current_price - new_sl) / price_step;  // v2.57
                    Print("   ❄️ Freeze distance: ", DoubleToString(freeze_distance, 1), " pontos (required > ", freeze_level, ")");
                    
                    if(freeze_distance <= freeze_level)
                    {
                        // Logar no máximo uma vez por barra/valor de SL
                        int ridx = FindRecordIndex(ticket);
                        bool should_log = true;
                        if(ridx >= 0)
                        {
                            if(m_trailing_records[ridx].last_update == bar_time && MathAbs(m_trailing_records[ridx].last_attempt_sl - new_sl) < point)
                                should_log = false;
                        }
                        if(should_log)
                        {
                            Print("   ⏸️ [TS] BUY #", ticket, " BLOQUEADO: Dentro do FREEZE_LEVEL");
                            Print("      ❌ freeze_distance=", DoubleToString(freeze_distance, 1), " <= freeze_level=", freeze_level);
                            Print("      📍 Tentou: SL=", new_sl, " TP=", current_tp, " | Preço=", current_price);
                        }
                        // Bloquear novas tentativas nesta barra
                        UpdateRecord(ticket, current_price, bar_time);
                        int idxf = FindRecordIndex(ticket);
                        if(idxf >= 0)
                        {
                            m_trailing_records[idxf].last_attempt_sl = new_sl;
                            m_trailing_records[idxf].last_retcode = 0;
                            m_trailing_records[idxf].last_error = 0;
                            m_trailing_records[idxf].last_failure_log_time = TimeCurrent();
                        }
                        return false;
                    }
                }
                
                // ✅ v2.53 CRITICAL FIX - BUY: PositionModify no MT5 usa TICKET, não símbolo
                // ❌ ERRO ANTERIOR: m_trade.PositionModify(symbol, new_sl, tp) → Retcode: 0
                // ✅ CORRETO: Selecionar posição primeiro, depois modificar com ticket
                if(!PositionSelectByTicket(ticket))
                {
                    Print("   ❌ [TS] BUY #", ticket, ": Posição não encontrada para modificação");
                    return false;
                }
                
                // Modificar posição usando ticket (método correto MT5)
                bool modify_result = m_trade.PositionModify(ticket, new_sl, current_tp);
                uint retcode = m_trade.ResultRetcode();
                
                if(modify_result && retcode == TRADE_RETCODE_DONE)
                {
                    m_total_updates_buy++;
                    
                    // ═══════════════════════════════════════════════════════
                    // CORREÇÃO CRÍTICA: Gravar preço ATUAL, não new_sl + step
                    // Isso permite que o próximo trailing seja baseado no preço real
                    // ═══════════════════════════════════════════════════════
                    UpdateRecord(ticket, current_price, bar_time);
                    int idxs = FindRecordIndex(ticket);
                    if(idxs >= 0)
                    {
                        m_trailing_records[idxs].last_attempt_sl = new_sl;
                        m_trailing_records[idxs].last_retcode = TRADE_RETCODE_DONE;
                        m_trailing_records[idxs].last_error = 0;
                        m_trailing_records[idxs].last_failure_log_time = 0;
                    }
                    
                    double protected_profit = (new_sl - entry_price) / price_step;  // v2.57
                    
                    Print("🚀 [TS] Trailing Stop ajustado para BUY #", ticket);
                    Print("   📊 Lucro atual: +", (int)profit_points, " pontos/pips");
                    Print("   🎯 Novo SL: ", new_sl, " (protegendo +", (int)protected_profit, " pontos)");
                    Print("   📈 Preço: ", current_price, " | Entry: ", entry_price, " | TP: ", current_tp);
                    
                    return true;
                }
                else
                {
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
                    
                    // Deduplicação: logar no máximo uma vez por barra/SL/erro
                    int ridx = FindRecordIndex(ticket);
                    bool should_log = true;
                    if(ridx >= 0)
                    {
                        if(m_trailing_records[ridx].last_update == bar_time &&
                           MathAbs(m_trailing_records[ridx].last_attempt_sl - new_sl) < point &&
                           m_trailing_records[ridx].last_retcode == retcode &&
                           m_trailing_records[ridx].last_error == error)
                        {
                            should_log = false;
                        }
                    }
                    if(should_log)
                    {
                        Print("❌ [TS] Falha ao modificar BUY #", ticket, " - Retcode: ", retcode, " | Erro: ", error);
                        Print("   📍 Tentou: SL=", new_sl, " TP=", current_tp, " | Preço=", current_price);
                    }
                    // Bloquear novas tentativas nesta barra e registrar falha
                    UpdateRecord(ticket, current_price, bar_time);
                    int idxf = FindRecordIndex(ticket);
                    if(idxf >= 0)
                    {
                        m_trailing_records[idxf].last_attempt_sl = new_sl;
                        m_trailing_records[idxf].last_retcode = retcode;
                        m_trailing_records[idxf].last_error = error;
                        m_trailing_records[idxf].last_failure_log_time = TimeCurrent();
                    }
                    return false;
                }
            }
        }
    }
    else // POSITION_TYPE_SELL
    {
        profit_points = (entry_price - current_price) / price_step;  // v2.57
        trigger = m_trigger_sell;
        step = m_step_sell;
        
        // Verificar se atingiu o trigger
        if(profit_points >= trigger)
        {
            // Tempo da barra atual (limitar a 1 ajuste por barra)
            datetime bar_time = iTime(symbol, PERIOD_CURRENT, 0);
            // ═══════════════════════════════════════════════════════
            // THROTTLING: Evitar updates excessivos
            // v2.54 FIX BUG #13: Throttling direcional para SELL
            // ═══════════════════════════════════════════════════════
            int record_idx = FindRecordIndex(ticket);
            if(record_idx >= 0)
            {
                double last_price = m_trailing_records[record_idx].last_price;
                // SELL: preço deve CAIR (negativo) para mover TS
                double price_change = (current_price - last_price) / price_step;  // v2.57: Sem MathAbs
                double min_required = step * 0.75;
                
                // SELL só aceita movimento NEGATIVO >= min_required
                if(price_change > -min_required)
                {
                    if(price_change > 0)
                    {
                        Print("   ⏸️ [TS] SELL #", ticket, " BLOQUEADO: Preço SUBIU (", 
                              DoubleToString(price_change, 1), " pontos) - TS só desce quando preço desce");
                    }
                    else
                    {
                        Print("   ⏸️ [TS] SELL #", ticket, " BLOQUEADO: Movimento insuficiente (", 
                              DoubleToString(price_change, 1), " < -", DoubleToString(min_required, 1), " pontos)");
                    }
                    return false;
                }
                
                // Movimento válido (preço caiu >= 11.3 pontos), permitir update
                Print("   ✅ [TS] SELL #", ticket, " Throttling OK: Preço caiu ", 
                      DoubleToString(-price_change, 1), " pontos (>= ", 
                      DoubleToString(min_required, 1), " requeridos)");
            }
            
            // ═══════════════════════════════════════════════════════
            // CÁLCULO DO TRAILING STOP (MODO GRADUAL)
            // ═══════════════════════════════════════════════════════
            // Para SELL: mover no máximo 1 passo (step) abaixo do SL atual
            // e nunca ultrapassar o alvo de distância do preço (preço_atual + step)
            double target_sl = NormalizeDouble(current_price + (step * price_step), digits);  // v2.57
            double candidate_sl;
            if(current_sl > 0)
                candidate_sl = NormalizeDouble(current_sl - (step * price_step), digits);  // v2.57
            else
                candidate_sl = NormalizeDouble(entry_price - ((trigger - step) * price_step), digits);  // v2.57
            
            // CORREÇÃO CRÍTICA: Usar MathMin para SELL (SL deve DESCER)
            double new_sl = MathMin(current_sl, MathMax(target_sl, candidate_sl));
            new_sl = NormalizeDouble(new_sl, digits);
            
            // Garantir que SL só DESCE (nunca sobe em SELL)
            if(current_sl > 0 && new_sl >= current_sl)
            {
                // Preço não moveu o suficiente, manter SL atual
                return false;
            }
            
            // ═══════════════════════════════════════════════════════
            // VALIDAÇÃO CRÍTICA: Evitar modificação se SL é idêntico
            // ═══════════════════════════════════════════════════════
            if(current_sl > 0 && MathAbs(new_sl - current_sl) < price_step)  // v2.57
            {
                // SL já está no valor calculado, não modificar
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
                    double safe_distance = 10 * price_step;  // v2.57: 10 steps de segurança
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
                double min_distance = stop_level * price_step;  // v2.57
                
                if(stop_level > 0)
                {
                    double distance_to_price = (new_sl - current_price) / price_step;  // v2.57
                    if(distance_to_price <= stop_level)
                    {
                        Print("⚠️ [TS] SELL #", ticket, ": SL muito próximo do preço (stops_level=", stop_level, ")");
                        Print("   🔍 DEBUG: price=", DoubleToString(current_price, digits),
                              " | new_sl=", DoubleToString(new_sl, digits),
                              " | distance=", DoubleToString(distance_to_price, 1), " pontos",
                              " | step=", step, " | price_step=", DoubleToString(price_step, digits));  // v2.57
                        Print("   💡 Aumente InpTS_Sell_Step para pelo menos ", (stop_level + 10), " pontos");
                        return false;
                    }
                }
                
                // Verificar FREEZE_LEVEL
                long freeze_level = SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
                if(freeze_level > 0)
                {
                    double freeze_distance = (new_sl - current_price) / price_step;  // v2.57
                    if(freeze_distance <= freeze_level)
                    {
                        int ridx = FindRecordIndex(ticket);
                        bool should_log = true;
                        if(ridx >= 0)
                        {
                            if(m_trailing_records[ridx].last_update == bar_time && MathAbs(m_trailing_records[ridx].last_attempt_sl - new_sl) < point)
                                should_log = false;
                        }
                        if(should_log)
                        {
                            Print("⛔ [TS] SELL #", ticket, ": Dentro do FREEZE_LEVEL (", freeze_level, ") | distance=", DoubleToString(freeze_distance, 1), " pontos");
                            Print("   📍 Tentou: SL=", new_sl, " TP=", current_tp, " | Preço=", current_price);
                        }
                        UpdateRecord(ticket, current_price, bar_time);
                        int idxf = FindRecordIndex(ticket);
                        if(idxf >= 0)
                        {
                            m_trailing_records[idxf].last_attempt_sl = new_sl;
                            m_trailing_records[idxf].last_retcode = 0;
                            m_trailing_records[idxf].last_error = 0;
                            m_trailing_records[idxf].last_failure_log_time = TimeCurrent();
                        }
                        return false;
                    }
                }
                
                // ✅ v2.53 CRITICAL FIX - SELL: PositionModify no MT5 usa TICKET, não símbolo
                if(!PositionSelectByTicket(ticket))
                {
                    Print("   ❌ [TS] SELL #", ticket, ": Posição não encontrada para modificação");
                    return false;
                }
                
                // Modificar posição usando ticket (método correto MT5)
                bool modify_result = m_trade.PositionModify(ticket, new_sl, current_tp);
                uint retcode = m_trade.ResultRetcode();
                
                if(modify_result && retcode == TRADE_RETCODE_DONE)
                {
                    m_total_updates_sell++;
                    
                    // ═══════════════════════════════════════════════════════
                    // CORREÇÃO CRÍTICA: Gravar preço ATUAL, não new_sl - step
                    // Isso permite que o próximo trailing seja baseado no preço real
                    // ═══════════════════════════════════════════════════════
                    UpdateRecord(ticket, current_price, bar_time);
                    int idxs = FindRecordIndex(ticket);
                    if(idxs >= 0)
                    {
                        m_trailing_records[idxs].last_attempt_sl = new_sl;
                        m_trailing_records[idxs].last_retcode = TRADE_RETCODE_DONE;
                        m_trailing_records[idxs].last_error = 0;
                        m_trailing_records[idxs].last_failure_log_time = 0;
                    }
                    
                    double protected_profit = (entry_price - new_sl) / price_step;  // v2.57
                    
                    Print("🚀 [TS] Trailing Stop ajustado para SELL #", ticket);
                    Print("   📊 Lucro atual: +", (int)profit_points, " pontos/pips");
                    Print("   🎯 Novo SL: ", new_sl, " (protegendo +", (int)protected_profit, " pontos)");
                    Print("   📉 Preço: ", current_price, " | Entry: ", entry_price, " | TP: ", current_tp);
                    
                    return true;
                }
                else
                {
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
                    
                    // Deduplicação: logar no máximo uma vez por barra/SL/erro
                    int ridx = FindRecordIndex(ticket);
                    bool should_log = true;
                    if(ridx >= 0)
                    {
                        if(m_trailing_records[ridx].last_update == bar_time &&
                           MathAbs(m_trailing_records[ridx].last_attempt_sl - new_sl) < point &&
                           m_trailing_records[ridx].last_retcode == retcode &&
                           m_trailing_records[ridx].last_error == error)
                        {
                            should_log = false;
                        }
                    }
                    if(should_log)
                    {
                        Print("❌ [TS] Falha ao modificar SELL #", ticket, " - Retcode: ", retcode, " | Erro: ", error);
                        Print("   📍 Tentou: SL=", new_sl, " TP=", current_tp, " | Preço=", current_price);
                    }
                    UpdateRecord(ticket, current_price, bar_time);
                    int idxf = FindRecordIndex(ticket);
                    if(idxf >= 0)
                    {
                        m_trailing_records[idxf].last_attempt_sl = new_sl;
                        m_trailing_records[idxf].last_retcode = retcode;
                        m_trailing_records[idxf].last_error = error;
                        m_trailing_records[idxf].last_failure_log_time = TimeCurrent();
                    }
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
        m_trailing_records[size].last_retcode = 0;
        m_trailing_records[size].last_error = 0;
        m_trailing_records[size].last_attempt_sl = 0.0;
        m_trailing_records[size].last_failure_log_time = 0;
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
