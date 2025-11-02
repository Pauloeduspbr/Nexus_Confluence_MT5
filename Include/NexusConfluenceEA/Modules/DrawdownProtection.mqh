//+------------------------------------------------------------------+
//|                                        DrawdownProtection.mqh |
//|                      Nexus Confluence EA - Proteção de Drawdown  |
//|                       Circuit Breaker e Gestão de Perdas         |
//+------------------------------------------------------------------+
#property copyright "Nexus Confluence EA"
#property version   "2.00"
#property strict

//+------------------------------------------------------------------+
//| Classe de Proteção contra Drawdown                               |
//+------------------------------------------------------------------+
class CDrawdownProtection
{
private:
    // Configurações
    bool     m_enabled;
    double   m_daily_max_dd_percent;
    int      m_max_consec_loss;
    double   m_lot_reduce_factor;
    
    // Controle de estado
    bool     m_initialized;
    bool     m_circuit_breaker_active;
    datetime m_circuit_breaker_until;
    
    // Tracking diário
    datetime m_current_day;
    double   m_daily_start_balance;
    double   m_daily_dd_current;
    double   m_daily_dd_peak;
    
    // Tracking de perdas consecutivas
    int      m_current_consec_loss;
    int      m_max_consec_loss_reached;
    
    // Tracking de lote ajustado
    double   m_current_lot_factor;
    bool     m_lot_reduced;
    
    // Estatísticas
    int      m_total_circuit_breaks;
    int      m_total_lot_reductions;
    datetime m_last_circuit_break;
    
public:
    //--- Construtor/Destrutor
    CDrawdownProtection(void);
    ~CDrawdownProtection(void);
    
    //--- Inicialização
    bool Init(bool enabled, double daily_max_dd, int max_consec, double lot_factor);
    
    //--- Métodos de validação
    bool CanTrade(void);
    double GetAdjustedLot(double base_lot);
    
    //--- Atualização de estado
    void OnTradeResult(bool is_win, double profit_loss);
    void OnDayChange(void);
    void CheckDailyDrawdown(void);
    
    //--- Circuit Breaker
    void ActivateCircuitBreaker(string reason, int duration_minutes = 60);
    void DeactivateCircuitBreaker(void);
    bool IsCircuitBreakerActive(void);
    
    //--- Gestão de lote
    void ReduceLot(string reason);
    void RestoreLot(void);
    
    //--- Estatísticas
    double GetDailyDD(void);
    int GetConsecutiveLosses(void);
    int GetTotalCircuitBreaks(void) { return m_total_circuit_breaks; }
    
    //--- Utilidades
    void PrintStats(void);
    void Reset(void);
    
private:
    //--- Métodos internos
    void UpdateDailyTracking(void);
};

//+------------------------------------------------------------------+
//| Construtor                                                        |
//+------------------------------------------------------------------+
CDrawdownProtection::CDrawdownProtection(void)
{
    m_initialized = false;
    m_enabled = false;
    m_daily_max_dd_percent = 5.0;
    m_max_consec_loss = 7;
    m_lot_reduce_factor = 0.5;
    
    m_circuit_breaker_active = false;
    m_circuit_breaker_until = 0;
    
    m_current_day = 0;
    m_daily_start_balance = 0;
    m_daily_dd_current = 0;
    m_daily_dd_peak = 0;
    
    m_current_consec_loss = 0;
    m_max_consec_loss_reached = 0;
    
    m_current_lot_factor = 1.0;
    m_lot_reduced = false;
    
    m_total_circuit_breaks = 0;
    m_total_lot_reductions = 0;
    m_last_circuit_break = 0;
}

//+------------------------------------------------------------------+
//| Destrutor                                                         |
//+------------------------------------------------------------------+
CDrawdownProtection::~CDrawdownProtection(void)
{
}

//+------------------------------------------------------------------+
//| Inicialização do módulo                                          |
//+------------------------------------------------------------------+
bool CDrawdownProtection::Init(bool enabled, double daily_max_dd, int max_consec, double lot_factor)
{
    // Validação de parâmetros
    if(daily_max_dd <= 0 || daily_max_dd > 100)
    {
        Print("❌ [DD] Erro: Daily Max DD deve estar entre 0 e 100%. Valor: ", daily_max_dd);
        return false;
    }
    
    if(max_consec <= 0)
    {
        Print("❌ [DD] Erro: Max Consecutive Loss deve ser maior que zero. Valor: ", max_consec);
        return false;
    }
    
    if(lot_factor <= 0 || lot_factor > 1.0)
    {
        Print("❌ [DD] Erro: Lot Reduce Factor deve estar entre 0 e 1. Valor: ", lot_factor);
        return false;
    }
    
    // Armazenar configurações
    m_enabled = enabled;
    m_daily_max_dd_percent = daily_max_dd;
    m_max_consec_loss = max_consec;
    m_lot_reduce_factor = lot_factor;
    
    // Inicializar tracking diário
    m_current_day = TimeCurrent();
    m_daily_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    
    m_initialized = true;
    
    // Log de inicialização
    Print("✅ [DD] Drawdown Protection inicializado:");
    Print("   🛡️ Status: ", (m_enabled ? "ATIVO" : "DESATIVADO"));
    Print("   📊 DD Diário Máximo: ", m_daily_max_dd_percent, "%");
    Print("   🔢 Perdas Consecutivas Máx: ", m_max_consec_loss);
    Print("   📉 Fator Redução Lote: ", DoubleToString(m_lot_reduce_factor * 100, 0), "%");
    Print("   💰 Balance Inicial: $", DoubleToString(m_daily_start_balance, 2));
    
    return true;
}

//+------------------------------------------------------------------+
//| Verifica se pode operar (circuit breaker)                        |
//+------------------------------------------------------------------+
bool CDrawdownProtection::CanTrade(void)
{
    if(!m_initialized || !m_enabled)
        return true;  // Se não inicializado ou desabilitado, permite trade
    
    // Verificar circuit breaker
    if(m_circuit_breaker_active)
    {
        if(TimeCurrent() >= m_circuit_breaker_until)
        {
            // Desativar circuit breaker
            DeactivateCircuitBreaker();
            return true;
        }
        else
        {
            // Ainda em pausa
            int minutes_left = (int)((m_circuit_breaker_until - TimeCurrent()) / 60);
            Print("⏸️ [DD] Trading pausado. Circuit Breaker ativo por mais ", minutes_left, " minutos.");
            return false;
        }
    }
    
    // Verificar drawdown diário
    CheckDailyDrawdown();
    
    // Verificar perdas consecutivas
    if(m_current_consec_loss >= m_max_consec_loss)
    {
        ActivateCircuitBreaker("Perdas consecutivas excedidas", 120);  // 2 horas
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Retorna lote ajustado baseado em proteção                        |
//+------------------------------------------------------------------+
double CDrawdownProtection::GetAdjustedLot(double base_lot)
{
    if(!m_initialized || !m_enabled)
        return base_lot;
    
    if(m_lot_reduced)
    {
        double adjusted = base_lot * m_current_lot_factor;
        Print("📉 [DD] Lote ajustado: ", base_lot, " → ", adjusted, 
              " (fator: ", DoubleToString(m_current_lot_factor * 100, 0), "%)");
        return adjusted;
    }
    
    return base_lot;
}

//+------------------------------------------------------------------+
//| Processa resultado de trade                                      |
//+------------------------------------------------------------------+
void CDrawdownProtection::OnTradeResult(bool is_win, double profit_loss)
{
    if(!m_initialized || !m_enabled)
        return;
    
    // Atualizar tracking diário
    UpdateDailyTracking();
    
    // Atualizar contador de perdas consecutivas
    if(is_win)
    {
        m_current_consec_loss = 0;
        
        // Se lote estava reduzido e teve vitória, considerar restaurar
        if(m_lot_reduced && m_current_consec_loss == 0)
        {
            Print("✅ [DD] Vitória após período de perdas. Considerando restaurar lote...");
            // Restaurar após 2 vitórias consecutivas seria mais seguro
        }
    }
    else
    {
        m_current_consec_loss++;
        
        if(m_current_consec_loss > m_max_consec_loss_reached)
            m_max_consec_loss_reached = m_current_consec_loss;
        
        Print("📉 [DD] Perda registrada. Perdas consecutivas: ", m_current_consec_loss, 
              "/", m_max_consec_loss);
        
        // Reduzir lote após várias perdas
        if(m_current_consec_loss >= (m_max_consec_loss / 2) && !m_lot_reduced)
        {
            ReduceLot("Múltiplas perdas consecutivas");
        }
        
        // Ativar circuit breaker se atingiu limite
        if(m_current_consec_loss >= m_max_consec_loss)
        {
            ActivateCircuitBreaker("Limite de perdas consecutivas atingido", 120);
        }
    }
    
    // Atualizar DD diário
    m_daily_dd_current += profit_loss;
    
    if(m_daily_dd_current < m_daily_dd_peak)
        m_daily_dd_peak = m_daily_dd_current;
    
    // Verificar DD diário
    CheckDailyDrawdown();
}

//+------------------------------------------------------------------+
//| Processa mudança de dia                                          |
//+------------------------------------------------------------------+
void CDrawdownProtection::OnDayChange(void)
{
    if(!m_initialized)
        return;
    
    Print("🌅 [DD] Novo dia detectado. Resetando tracking diário.");
    
    // Log do dia anterior
    if(m_daily_dd_peak < 0)
    {
        double dd_percent = (m_daily_dd_peak / m_daily_start_balance) * 100;
        Print("📊 [DD] DD Máximo do dia anterior: $", DoubleToString(m_daily_dd_peak, 2),
              " (", DoubleToString(dd_percent, 2), "%)");
    }
    
    // Reset tracking
    m_current_day = TimeCurrent();
    m_daily_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    m_daily_dd_current = 0;
    m_daily_dd_peak = 0;
    
    // Considerar restaurar lote no novo dia
    if(m_lot_reduced && m_current_consec_loss == 0)
    {
        RestoreLot();
    }
}

//+------------------------------------------------------------------+
//| Verifica drawdown diário                                         |
//+------------------------------------------------------------------+
void CDrawdownProtection::CheckDailyDrawdown(void)
{
    if(!m_initialized || !m_enabled)
        return;
    
    double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double dd_value = current_balance - m_daily_start_balance;
    
    if(dd_value < 0)
    {
        double dd_percent = (MathAbs(dd_value) / m_daily_start_balance) * 100;
        
        if(dd_percent >= m_daily_max_dd_percent)
        {
            Print("🚨 [DD] DD DIÁRIO CRÍTICO: ", DoubleToString(dd_percent, 2), "% (limite: ",
                  m_daily_max_dd_percent, "%)");
            
            // Pausa progressiva: iniciar com 60 min; aumentar após múltiplas ativações
            int pause_minutes = 60;
            if(m_total_circuit_breaks > 2)
                pause_minutes = 120;  // 2 horas após múltiplas ativações
            
            ActivateCircuitBreaker("DD diário máximo", pause_minutes);
        }
        else if(dd_percent >= m_daily_max_dd_percent * 0.75)
        {
            Print("⚠️ [DD] DD Diário Alto: ", DoubleToString(dd_percent, 2), "% (75% do limite)");
            
            if(!m_lot_reduced)
                ReduceLot("DD diário próximo do limite");
        }
    }
}

//+------------------------------------------------------------------+
//| Ativa circuit breaker                                            |
//+------------------------------------------------------------------+
void CDrawdownProtection::ActivateCircuitBreaker(string reason, int duration_minutes = 60)
{
    if(m_circuit_breaker_active)
        return;  // Já está ativo
    
    m_circuit_breaker_active = true;
    m_circuit_breaker_until = TimeCurrent() + (duration_minutes * 60);
    m_total_circuit_breaks++;
    m_last_circuit_break = TimeCurrent();
    
    Print("🔴 [DD] ═══════════════════════════════════");
    Print("🔴 [DD] CIRCUIT BREAKER ATIVADO!");
    Print("🔴 [DD] Motivo: ", reason);
    Print("🔴 [DD] Duração: ", duration_minutes, " minutos");
    Print("🔴 [DD] Até: ", TimeToString(m_circuit_breaker_until));
    Print("🔴 [DD] ═══════════════════════════════════");
    
    // Enviar alerta
    if(TerminalInfoInteger(TERMINAL_NOTIFICATIONS_ENABLED))
        SendNotification("🔴 Circuit Breaker Ativado: " + reason);
}

//+------------------------------------------------------------------+
//| Desativa circuit breaker                                         |
//+------------------------------------------------------------------+
void CDrawdownProtection::DeactivateCircuitBreaker(void)
{
    if(!m_circuit_breaker_active)
        return;
    
    m_circuit_breaker_active = false;
    m_circuit_breaker_until = 0;
    
    Print("🟢 [DD] ═══════════════════════════════════");
    Print("🟢 [DD] CIRCUIT BREAKER DESATIVADO");
    Print("🟢 [DD] Trading retomado.");
    Print("🟢 [DD] ═══════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Verifica se circuit breaker está ativo                           |
//+------------------------------------------------------------------+
bool CDrawdownProtection::IsCircuitBreakerActive(void)
{
    return m_circuit_breaker_active;
}

//+------------------------------------------------------------------+
//| Reduz tamanho do lote                                            |
//+------------------------------------------------------------------+
void CDrawdownProtection::ReduceLot(string reason)
{
    if(m_lot_reduced)
        return;  // Já está reduzido
    
    m_lot_reduced = true;
    m_current_lot_factor = m_lot_reduce_factor;
    m_total_lot_reductions++;
    
    Print("📉 [DD] ═══════════════════════════════════");
    Print("📉 [DD] LOTE REDUZIDO");
    Print("📉 [DD] Motivo: ", reason);
    Print("📉 [DD] Fator: ", DoubleToString(m_current_lot_factor * 100, 0), "%");
    Print("📉 [DD] ═══════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Restaura tamanho do lote                                         |
//+------------------------------------------------------------------+
void CDrawdownProtection::RestoreLot(void)
{
    if(!m_lot_reduced)
        return;
    
    m_lot_reduced = false;
    m_current_lot_factor = 1.0;
    
    Print("📈 [DD] ═══════════════════════════════════");
    Print("📈 [DD] LOTE RESTAURADO");
    Print("📈 [DD] Fator: 100%");
    Print("📈 [DD] ═══════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Retorna DD diário atual em percentual                            |
//+------------------------------------------------------------------+
double CDrawdownProtection::GetDailyDD(void)
{
    double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double dd_value = current_balance - m_daily_start_balance;
    
    if(dd_value >= 0 || m_daily_start_balance == 0)
        return 0.0;
    
    return (MathAbs(dd_value) / m_daily_start_balance) * 100;
}

//+------------------------------------------------------------------+
//| Retorna contador de perdas consecutivas                          |
//+------------------------------------------------------------------+
int CDrawdownProtection::GetConsecutiveLosses(void)
{
    return m_current_consec_loss;
}

//+------------------------------------------------------------------+
//| Imprime estatísticas do módulo                                   |
//+------------------------------------------------------------------+
void CDrawdownProtection::PrintStats(void)
{
    Print("═══════════════════════════════════════");
    Print("📊 [DD] ESTATÍSTICAS DRAWDOWN PROTECTION");
    Print("═══════════════════════════════════════");
    Print("🛡️ Status: ", (m_enabled ? "ATIVO" : "DESATIVADO"));
    Print("🔴 Circuit Breakers: ", m_total_circuit_breaks);
    if(m_last_circuit_break > 0)
        Print("   └─ Último: ", TimeToString(m_last_circuit_break));
    Print("📉 Reduções de Lote: ", m_total_lot_reductions);
    Print("📊 DD Diário Atual: ", DoubleToString(GetDailyDD(), 2), "%");
    Print("🔢 Perdas Consecutivas: ", m_current_consec_loss, "/", m_max_consec_loss);
    Print("🏆 Máx Perdas Consecutivas: ", m_max_consec_loss_reached);
    Print("💰 Balance Início Dia: $", DoubleToString(m_daily_start_balance, 2));
    Print("💰 Balance Atual: $", DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2));
    Print("═══════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Reset das estatísticas                                           |
//+------------------------------------------------------------------+
void CDrawdownProtection::Reset(void)
{
    m_circuit_breaker_active = false;
    m_circuit_breaker_until = 0;
    m_current_consec_loss = 0;
    m_max_consec_loss_reached = 0;
    m_lot_reduced = false;
    m_current_lot_factor = 1.0;
    m_total_circuit_breaks = 0;
    m_total_lot_reductions = 0;
    
    OnDayChange();  // Reset tracking diário
    
    Print("🔄 [DD] Estatísticas resetadas.");
}

//+------------------------------------------------------------------+
//| Atualiza tracking diário                                         |
//+------------------------------------------------------------------+
void CDrawdownProtection::UpdateDailyTracking(void)
{
    datetime current_time = TimeCurrent();
    MqlDateTime dt_current, dt_stored;
    
    TimeToStruct(current_time, dt_current);
    TimeToStruct(m_current_day, dt_stored);
    
    // Verificar se mudou o dia
    if(dt_current.day != dt_stored.day || 
       dt_current.mon != dt_stored.mon || 
       dt_current.year != dt_stored.year)
    {
        OnDayChange();
    }
}

//+------------------------------------------------------------------+
