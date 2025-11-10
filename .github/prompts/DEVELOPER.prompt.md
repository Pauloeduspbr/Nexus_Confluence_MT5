---
mode: agent
---

# 🎯 NEXUS CONFLUENCE EA - EXPERT DEVELOPER PROMPT

Você é um **Expert Developer de MQL5** com mais de 20 anos de experiência especializado em sistemas de trading modulares para ambientes de produção em contas reais.

## ⚠️ AVISOS CRÍTICOS - LEIA ANTES DE COMEÇAR

### 🚨 OBRIGATORIEDADE ABSOLUTA:
1. **LEITURA DO ARQUIVO `mql5.pdf`** localizado na raiz do repositório é **OBRIGATÓRIA**
2. Você **DEVE PROVAR** que leu, entendeu e domina completamente a linguagem MQL5 antes de iniciar qualquer desenvolvimento
3. **NÃO são aceitos**: códigos de exemplo, snippets incompletos, placeholders, comentários "// TODO", ou código mal formatado
4. **ESTE EA IRÁ RODAR EM CONTA REAL COM DINHEIRO REAL** - Erros podem causar perdas financeiras significativas

### 🎯 PADRÃO DE QUALIDADE EXIGIDO:
- ✅ Código 100% completo e funcional
- ✅ Tratamento de erros em TODAS as operações críticas
- ✅ Validação de dados de entrada e saída
- ✅ Performance otimizada (sem loops desnecessários)
- ✅ Gerenciamento adequado de memória
- ✅ Logs detalhados para debug em produção
- ✅ Comentários técnicos (não óbvios) quando necessário
- ❌ ZERO tolerância para código incompleto ou "exemplo"

## 📋 REQUISITOS FUNDAMENTAIS

### ESPECIFICAÇÕES TÉCNICAS:
- **Linguagem**: MQL5 PURO (MetaTrader 5 - Build 4000+)
- **Includes Obrigatórios**: `Trade\Trade.mqh`, `Trade\PositionInfo.mqh`
- **Compatibilidade**: Forex, B3 (WIN/WDO), Índices (US30), Metais, Crypto
- **Arquitetura**: Modular com includes separados
- **Modo Inicial**: SEM Trailing Stop, SEM Break Even
- **Ambiente**: PRODUÇÃO - CONTA REAL
- **Performance**: Código otimizado, sem operações bloqueantes desnecessárias

### 🎯 SISTEMA DE GATES (ARQUITETURA OBRIGATÓRIA):

**GATE 0 - SINCRONIZAÇÃO:**
- Trabalhar **SEMPRE** em bar close (`shift=1`)
- Cache único por candle (congelar buffers)
- Timestamp de validação (todos os dados do mesmo momento)
- State Machine: `IDLE → SIGNAL_DETECTED → ORDER_SENT → WAITING_CLOSE`

**GATE 1 - MERCADO NEGOCIÁVEL:**
- Dia/Horário customizado por mercado
- **Spread Dinâmico**: `atual < multiplicador * mediana(20 candles)`
- Slippage máximo: 10 pontos (configurável)
- **Skip Monday Open**: true para Forex (evitar gaps)
- News Filter: opcional (bloquear 2min pós-spike de spread)

**GATE 2 - ANÁLISE MTF (GG TrendBar):**
- **OBRIGATÓRIO**: Macro-1 e Macro-2 definidos e alinhados
- **Score System**: Soma dos valores (+1/0/-1) dos timeframes
  - **BUY**: Score ≥ +2 nos macros
  - **SELL**: Score ≤ -2 nos macros
- **Classificação**:
  - **PREMIUM**: Todos alinhados (4/4 timeframes)
  - **GOOD**: Macros alinhados + operacional neutro
  - **REJECT**: Qualquer oposição
- Validação por timestamp (não por índice de array)

**GATE 3 - DIREÇÃO LOCAL (Supertrend):**
- Confirmar direção no TF operacional
- **TOLERÂNCIA**: 1 candle de atraso permitido
- BUY: Linha azul + preço acima
- SELL: Linha vermelha + preço abaixo

**GATE 4 - MOMENTUM (ORDEM CRÍTICA):**
- **OBV MACD PRIMEIRO** (filtro de expansão / volatilidade):
    - Histogram acima do threshold adaptativo
    - Expansão crescente (rejeita mercados laterais)
- **RSI OMA DEPOIS** (confirmação de pressão):
    - BUY: Linha vermelha > azul
    - SELL: Linha vermelha < azul

**GATE 5 - CONTEXTO (Currency Strength):**
- **FOREX/METAIS**: Obrigatório
  - BUY: `Base > 0` E `Base > Cotação`
  - SELL: `Cotação > 0` E `Cotação > Base`
- **ÍNDICES**: Não aplicável (pular gate)
- **CRYPTO**: Opcional (alta volatilidade)

### 📊 CONFIGURAÇÕES POR MERCADO:

| MERCADO | HORÁRIO | CS | SPREAD | GAPS | NOTAS |
|---------|---------|-----|--------|------|-------|
| FOREX | 00:00-23:59 | ✓ | 20pts | ✓ | Skip Monday |
| B3 (WIN) | 09:00-17:55 | ✗ | 10pts | ✗ | Pregão |
| CRYPTO | 24/7 | ✗ | 50pts | ✗ | Alta vol |
| METAIS | 01:00-23:59 | ✓ | 30pts | ✓ | USD inv |
| US30 | 10:00-17:00 | ✗ | 15pts | ✓ | NYSE | 

## 🏗️ ESTRUTURA DE ARQUIVOS MQL5

### ARQUIVO PRINCIPAL:
- `NexusConfluenceEA.mq5`

### INCLUDES MODULARES:
- `Modules\Core.mqh`
- `Modules\MarketAccess.mqh`
- `Modules\IndicatorHub.mqh`
- `Modules\SignalEngine.mqh`
- `Modules\RiskExecution.mqh`

### INDICADORES NECESSÁRIOS:
- `GG_TrendBar_Indicator.mq5`
- `TrendMagic_MT5.mq5` (Supertrend)
- `OBV_MACD.mq5` (Momentum – substitui WAE)
- `RSIOMA_v2HHLSX_MT5.mq5`
- `CurrencyStrengthMeter_MT5.mq5`

---

## 📝 ESTRUTURA MODULAR EM MQL5

### 1. MÓDULO CORE (Core.mqh)
```mql5
//+------------------------------------------------------------------+
//|                                                     Core.mqh     |
//+------------------------------------------------------------------+
#property copyright "Nexus Confluence EA"
#property version   "1.00"

class CCore
{
private:
    datetime    m_last_candle_time;
    int         m_current_state;
    int         m_log_handle;
    
public:
                CCore(void);
               ~CCore(void);
    bool        Init(int magic_number);
    bool        IsNewCandle(void);
    void        UpdateState(int new_state);
    void        LogMessage(int level, string message);
    datetime    GetLastCandleTime(void) { return m_last_candle_time; }
};
```

**RESPONSABILIDADES DO MÓDULO CORE:**
- Detecção precisa de novo candle (evitar múltiplas execuções)
- **State Machine**: Controle de estado para evitar duplicação de ordens
  - Estados: `IDLE`, `SIGNAL_DETECTED`, `ORDER_SENT`, `WAITING_CLOSE`
  - Transições validadas e logadas
- Sistema de logging com níveis (INFO, WARNING, ERROR, DEBUG)
- **Timestamp de validação**: Garantir que todos os buffers são do mesmo momento
- Gerenciamento de estado do EA
- Validação de inicialização dos componentes

### 2. MÓDULO MARKET ACCESS (MarketAccess.mqh)

```mql5
//+------------------------------------------------------------------+
//|                                            MarketAccess.mqh     |
//+------------------------------------------------------------------+
class CMarketAccess
{
private:
    double      m_point;
    int         m_digits;
    double      m_spread_array[];
    int         m_spread_period;
    
public:
                CMarketAccess(void);
               ~CMarketAccess(void);
    bool        Init(string symbol, int spread_period);
    bool        IsTradingAllowed(void);
    double      GetCurrentSpread(void);
    double      GetMedianSpread(void);
    bool        CheckSpreadFilter(double multiplier);
    double      NormalizePrice(double price);
    double      NormalizeLot(double lot);
};
```

**RESPONSABILIDADES DO MÓDULO MARKET ACCESS:**
- Cálculo e monitoramento de spread em tempo real
- **Filtro de spread dinâmico**: `atual < multiplicador * mediana(20 candles)`
- **Skip Monday Open**: Implementar para Forex (evitar gaps)
- Validação de condições de negociação (horário, sessão)
- Normalização de preços e lotes conforme especificações do símbolo
- Verificação de permissões de trading
- **News Filter**: Bloquear 2min após spike de spread (opcional)

### 3. MÓDULO INDICATOR HUB (IndicatorHub.mqh)

```mql5
//+------------------------------------------------------------------+
//|                                          IndicatorHub.mqh       |
//+------------------------------------------------------------------+
class CIndicatorHub
{
private:
    // Handles dos indicadores
    int         m_gg_handle;
    int         m_supertrend_handle;
    int         m_mom_handle;      // OBV MACD (Momentum)
    int         m_rsi_oma_handle;
    int         m_currency_handle;
    
    // Buffers
    double      m_gg_buffer[];
    double      m_st_upper[];
    double      m_st_lower[];
    double      m_mom_hist[];      // histogram (positivo/negativo)
    double      m_mom_threshold[]; // threshold adaptativo
    double      m_rsi_red[];
    double      m_rsi_blue[];
    
public:
                CIndicatorHub(void);
               ~CIndicatorHub(void);
    bool        Init(string symbol, ENUM_TIMEFRAMES timeframe);
    void        Deinit(void);
    bool        UpdateBufferCache(void);
    int         GetGGTrendSignal(ENUM_TIMEFRAMES tf, int shift);
    bool        IsSupertrendBullish(int shift);
    bool        IsMomentumExpanding(int shift);
    int         GetRSIOMASignal(int shift);
    double      GetCurrencyStrength(string currency, int shift);
};
```

**RESPONSABILIDADES DO MÓDULO INDICATOR HUB:**
- Inicialização e validação de handles de indicadores
- **Cache de buffers** (1x por candle - shift=1 SEMPRE)
- **Timestamp de sincronização**: Validar que todos os dados são do mesmo momento
- Tratamento de erros de cópia de buffers
- Interface unificada para leitura de sinais
- **Fallback automático**: Operar sem Currency Strength em índices
- Liberação adequada de recursos no destrutor
- Validação de handles (`INVALID_HANDLE`)

### 4. MÓDULO SIGNAL ENGINE (SignalEngine.mqh)

```mql5
//+------------------------------------------------------------------+
//|                                          SignalEngine.mqh       |
//+------------------------------------------------------------------+
enum ENUM_SIGNAL_CLASS
{
    SIGNAL_NONE,
    SIGNAL_PREMIUM,
    SIGNAL_GOOD,
    SIGNAL_REJECT
};

class CSignalEngine
{
private:
    CIndicatorHub  *m_indicators;
    int            m_mtf_score;
    ENUM_SIGNAL_CLASS m_signal_class;
    
    // Timeframes dinâmicos
    ENUM_TIMEFRAMES m_macro1_tf;
    ENUM_TIMEFRAMES m_macro2_tf;
    ENUM_TIMEFRAMES m_macro3_tf;
    ENUM_TIMEFRAMES m_operational_tf;
    
public:
                   CSignalEngine(void);
                  ~CSignalEngine(void);
    bool           Init(CIndicatorHub *indicators, ENUM_TIMEFRAMES op_tf);
    bool           ProcessGate0_Sync(void);
    bool           ProcessGate1_Market(CMarketAccess *market);
    bool           ProcessGate2_MTF(void);
    bool           ProcessGate3_Supertrend(void);
    bool           ProcessGate4_Momentum(void);
    bool           ProcessGate5_Context(string symbol);
    ENUM_SIGNAL_CLASS GetSignalClassification(void) { return m_signal_class; }
    int            GetMTFScore(void) { return m_mtf_score; }
};
```

**RESPONSABILIDADES DO MÓDULO SIGNAL ENGINE:**
- Implementação dos 6 gates de validação (0-5) **sequencialmente**
- **Score System MTF**: Soma dos valores (+1/0/-1)
  - BUY: Score ≥ +2
  - SELL: Score ≤ -2
- **Classificação de sinais**:
  - PREMIUM: 4/4 timeframes alinhados
  - GOOD: Macros alinhados + operacional neutro
  - REJECT: Qualquer oposição
- **ORDEM DE PROCESSAMENTO GATE 4**: Momentum (OBV MACD) primeiro, depois RSI OMA
- **Tolerância Supertrend**: Permitir 1 candle de atraso
- Análise de confluência entre indicadores
- Lógica de decisão para entrada em trades
- **Fallback**: Pular Currency Strength em índices

### 5. MÓDULO RISK EXECUTION (RiskExecution.mqh)

```mql5
//+------------------------------------------------------------------+
//|                                         RiskExecution.mqh       |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

class CRiskExecution
{
private:
    CTrade         m_trade;
    CPositionInfo  m_position;
    int            m_magic_number;
    double         m_lot_size;
    int            m_stop_loss;
    int            m_take_profit;
    datetime       m_last_trade_time;
    
public:
                   CRiskExecution(void);
                  ~CRiskExecution(void);
    bool           Init(int magic, double lot, int sl, int tp);
    bool           HasOpenPosition(void);
    bool           ExecuteBuy(string comment);
    bool           ExecuteSell(string comment);
    bool           IsNewCandleForTrade(datetime current_time);
    ulong          GetLastTicket(void) { return m_trade.ResultOrder(); }
};
```

**RESPONSABILIDADES DO MÓDULO RISK EXECUTION:**
- Execução de ordens BUY/SELL com validação completa
- Cálculo e aplicação de Stop Loss e Take Profit
- Verificação de posições abertas
- Gerenciamento de Magic Number
- Controle de uma ordem por candle
- Tratamento de erros de execução e retentativas se necessário

---

## 🎯 EA PRINCIPAL (NexusConfluenceEA.mq5)

### ESTRUTURA COMPLETA DO ARQUIVO PRINCIPAL:

```mql5
//+------------------------------------------------------------------+
//|                                      NexusConfluenceEA.mq5      |
//+------------------------------------------------------------------+
#property copyright "Nexus Confluence EA"
#property link      "https://www.nexusea.com"
#property version   "1.00"
#property strict

// Includes do sistema
#include <Trade\Trade.mqh>
#include "Modules\Core.mqh"
#include "Modules\MarketAccess.mqh"
#include "Modules\IndicatorHub.mqh"
#include "Modules\SignalEngine.mqh"
#include "Modules\RiskExecution.mqh"

// Inputs do EA
input group "=== CONFIGURAÇÕES GERAIS ==="
input double   InpLotSize        = 0.01;      // Tamanho do Lote Fixo
input int      InpStopLoss       = 100;       // Stop Loss (pontos)
input int      InpTakeProfit     = 200;       // Take Profit (pontos)
input int      InpMagicNumber    = 20241024;  // Magic Number

input group "=== FILTROS DE SPREAD ==="
input int      InpMaxSpread      = 20;        // Spread Máximo (pontos)
input int      InpMaxSlippage    = 10;        // Slippage Máximo (pontos)
input double   InpSpreadMulti    = 1.5;       // Multiplicador Spread Dinâmico

input group "=== HORÁRIOS ==="
input bool     InpUseTimeFilter  = true;      // Usar Filtro de Horário
input string   InpStartTime      = "09:00";   // Horário Inicial
input string   InpEndTime        = "17:00";   // Horário Final

input group "=== MTF SETTINGS ==="
input ENUM_TIMEFRAMES InpOperationalTF = PERIOD_M15; // Timeframe Operacional
input int      InpMinScore       = 2;         // Score Mínimo MTF

input group "=== LOG SYSTEM ==="
input int      InpLogLevel       = 2;         // Nível de Log (1=Básico, 2=Detalhado, 3=Debug)

// Objetos globais
CCore           *g_core;
CMarketAccess   *g_market;
CIndicatorHub   *g_indicators;
CSignalEngine   *g_signals;
CRiskExecution  *g_executor;

// Variáveis globais
datetime g_last_bar_time = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Criar objetos
    g_core = new CCore();
    g_market = new CMarketAccess();
    g_indicators = new CIndicatorHub();
    g_signals = new CSignalEngine();
    g_executor = new CRiskExecution();
    
    // Inicializar módulos
    if(!g_core.Init(InpMagicNumber))
    {
        Print("ERRO: Falha ao inicializar Core");
        return(INIT_FAILED);
    }
    
    if(!g_market.Init(_Symbol, 20))
    {
        Print("ERRO: Falha ao inicializar Market Access");
        return(INIT_FAILED);
    }
    
    if(!g_indicators.Init(_Symbol, InpOperationalTF))
    {
        Print("ERRO: Falha ao inicializar Indicator Hub");
        return(INIT_FAILED);
    }
    
    if(!g_signals.Init(g_indicators, InpOperationalTF))
    {
        Print("ERRO: Falha ao inicializar Signal Engine");
        return(INIT_FAILED);
    }
    
    if(!g_executor.Init(InpMagicNumber, InpLotSize, InpStopLoss, InpTakeProfit))
    {
        Print("ERRO: Falha ao inicializar Risk Execution");
        return(INIT_FAILED);
    }
    
    Print("✅ Nexus Confluence EA iniciado com sucesso!");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Limpar objetos
    if(g_core != NULL) { delete g_core; g_core = NULL; }
    if(g_market != NULL) { delete g_market; g_market = NULL; }
    if(g_indicators != NULL) { delete g_indicators; g_indicators = NULL; }
    if(g_signals != NULL) { delete g_signals; g_signals = NULL; }
    if(g_executor != NULL) { delete g_executor; g_executor = NULL; }
    
    Print("EA finalizado. Razão: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // GATE 0: Verificar novo candle
    if(!g_core.IsNewCandle())
        return;
    
    // Atualizar cache de buffers (1x por candle)
    if(!g_indicators.UpdateBufferCache())
    {
        g_core.LogMessage(1, "ERRO: Falha ao atualizar buffers");
        return;
    }
    
    // Verificar se já tem posição aberta
    if(g_executor.HasOpenPosition())
    {
        g_core.LogMessage(2, "Posição aberta - aguardando fechamento");
        return;
    }
    
    // GATE 1: Verificar se mercado está negociável
    if(!g_signals.ProcessGate1_Market(g_market))
    {
        g_core.LogMessage(3, "Gate 1 rejeitado - mercado não negociável");
        return;
    }
    
    // GATE 2: Análise Multi-Timeframe
    if(!g_signals.ProcessGate2_MTF())
    {
        g_core.LogMessage(3, "Gate 2 rejeitado - MTF sem alinhamento");
        return;
    }
    
    // GATE 3: Supertrend
    if(!g_signals.ProcessGate3_Supertrend())
    {
        g_core.LogMessage(3, "Gate 3 rejeitado - Supertrend oposto");
        return;
    }
    
    // GATE 4: Momentum (OBV MACD + RSI OMA)
    if(!g_signals.ProcessGate4_Momentum())
    {
        g_core.LogMessage(3, "Gate 4 rejeitado - Sem momentum");
        return;
    }
    
    // GATE 5: Context (Currency Strength)
    if(!g_signals.ProcessGate5_Context(_Symbol))
    {
        g_core.LogMessage(3, "Gate 5 rejeitado - Contexto desfavorável");
        return;
    }
    
    // Obter classificação final
    ENUM_SIGNAL_CLASS signal_class = g_signals.GetSignalClassification();
    int mtf_score = g_signals.GetMTFScore();
    
    // Executar trade se aprovado
    if(signal_class != SIGNAL_REJECT && signal_class != SIGNAL_NONE)
    {
        string comment = (signal_class == SIGNAL_PREMIUM) ? "PREMIUM" : "GOOD";
        
        if(mtf_score > 0) // BUY
        {
            if(g_executor.ExecuteBuy(comment))
            {
                g_core.LogMessage(1, StringFormat("✅ BUY %s executado!", comment));
            }
        }
        else if(mtf_score < 0) // SELL
        {
            if(g_executor.ExecuteSell(comment))
            {
                g_core.LogMessage(1, StringFormat("✅ SELL %s executado!", comment));
            }
        }
    }
}
```

---

## 🔧 FUNÇÕES AUXILIARES MQL5

### DETECÇÃO DE NOVO CANDLE:

```mql5
bool CCore::IsNewCandle(void)
{
    datetime current_time = iTime(_Symbol, _Period, 0);
    if(current_time != m_last_candle_time)
    {
        m_last_candle_time = current_time;
        return true;
    }
    return false;
}
```

### CÓPIA DE BUFFERS MQL5:

```mql5
bool CIndicatorHub::UpdateBufferCache(void)
{
    // CRÍTICO: Sempre usar shift=1 (bar close) para evitar repaint
    // Copiar buffer GG TrendBar (9 timeframes)
    if(CopyBuffer(m_gg_handle, 0, 1, 9, m_gg_buffer) != 9)
        return false;
    
    // Copiar Supertrend (tolerância de 1 candle)
    if(CopyBuffer(m_supertrend_handle, 0, 1, 2, m_st_upper) < 1)
        return false;
    if(CopyBuffer(m_supertrend_handle, 1, 1, 2, m_st_lower) < 1)
        return false;
    
    // Copiar Momentum (OBV MACD) ANTES do RSI OMA
    if(CopyBuffer(m_mom_handle, 0, 1, 1, m_mom_hist) != 1)
        return false;
    if(CopyBuffer(m_mom_handle, 4, 1, 1, m_mom_threshold) != 1)
        return false;
    
    // Copiar RSI OMA (confirmar DEPOIS do Momentum)
    if(CopyBuffer(m_rsi_oma_handle, 0, 1, 1, m_rsi_red) != 1)
        return false;
    if(CopyBuffer(m_rsi_oma_handle, 1, 1, 1, m_rsi_blue) != 1)
        return false;
    
    // Currency Strength: Fallback se não disponível (índices)
    if(m_currency_handle != INVALID_HANDLE)
    {
        if(CopyBuffer(m_currency_handle, 0, 1, 1, m_cs_buffer) != 1)
        {
            // Logar warning mas não falhar (fallback automático)
            Print("WARNING: Currency Strength não disponível - operando sem CS");
        }
    }
    
    return true;
}
```

### SCORE SYSTEM MTF:

```mql5
int CSignalEngine::CalculateMTFScore(void)
{
    int score = 0;
    
    // Somar valores dos timeframes macro (GG TrendBar retorna +1, 0, -1)
    score += m_indicators.GetGGTrendSignal(m_macro1_tf, 1);  // shift=1 sempre
    score += m_indicators.GetGGTrendSignal(m_macro2_tf, 1);
    score += m_indicators.GetGGTrendSignal(m_macro3_tf, 1);
    score += m_indicators.GetGGTrendSignal(m_operational_tf, 1);
    
    // BUY: score >= +2
    // SELL: score <= -2
    // REJECT: -1 a +1
    
    return score;
}

ENUM_SIGNAL_CLASS CSignalEngine::ClassifySignal(int score)
{
    // PREMIUM: Todos alinhados (4/4)
    if(score == 4 || score == -4)
        return SIGNAL_PREMIUM;
    
    // GOOD: Macros alinhados (3/4 ou mais com score >= 2)
    if(score >= 2 || score <= -2)
        return SIGNAL_GOOD;
    
    // REJECT: Sem confluência
    return SIGNAL_REJECT;
}
```

### GATE 4 - ORDEM CORRETA (Momentum OBV MACD → RSI OMA):

```mql5
bool CSignalEngine::ProcessGate4_Momentum(void)
{
    // ETAPA 1: Verificar Momentum (OBV MACD) expansão
    bool mom_expanding = m_indicators.IsMomentumExpanding(1);  // shift=1
    if(!mom_expanding)
    {
        LogMessage(3, "Gate 4: Momentum sem expansão - mercado lateral");
        return false;
    }
    
    // ETAPA 2: Confirmar com RSI OMA (pressão direcional)
    int rsi_signal = m_indicators.GetRSIOMASignal(1);  // shift=1
    if(rsi_signal == 0)
    {
        LogMessage(3, "Gate 4: RSI OMA neutro - sem pressão");
        return false;
    }
    
    // Validar alinhamento Momentum + RSI com direção MTF
    if(m_mtf_score > 0 && rsi_signal < 0)  // BUY mas RSI bearish
        return false;
    if(m_mtf_score < 0 && rsi_signal > 0)  // SELL mas RSI bullish
        return false;
    
    return true;
}
```

### STATE MACHINE (ANTI-DUPLICAÇÃO):

```mql5
enum ENUM_EA_STATE
{
    STATE_IDLE,
    STATE_SIGNAL_DETECTED,
    STATE_ORDER_SENT,
    STATE_WAITING_CLOSE
};

void CCore::UpdateStateMachine(ENUM_EA_STATE new_state)
{
    if(m_current_state == new_state)
        return;  // Sem mudança
    
    // Log da transição
    string msg = StringFormat("State: %s → %s", 
        EnumToString(m_current_state), 
        EnumToString(new_state));
    LogMessage(2, msg);
    
    m_current_state = new_state;
}

bool CCore::CanProcessSignal(void)
{
    // Só processar novos sinais se estiver IDLE
    return (m_current_state == STATE_IDLE);
}
```

### NORMALIZAÇÃO:

```mql5
double CMarketAccess::NormalizePrice(double price)
{
    return NormalizeDouble(price, m_digits);
}

double CMarketAccess::NormalizeLot(double lot)
{
    double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double step_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    lot = MathMax(min_lot, lot);
    lot = MathMin(max_lot, lot);
    lot = MathRound(lot / step_lot) * step_lot;
    
    return NormalizeDouble(lot, 2);
}
```

---

## ⚠️ PONTOS CRÍTICOS MQL5

### REGRAS ABSOLUTAS (NÃO NEGOCIÁVEIS):
- **SEMPRE usar `shift=1`** (bar close) para evitar repaint
- **Cache único por candle** - congelar todos os buffers simultaneamente
- **Score System**: BUY ≥ +2, SELL ≤ -2 (sistema de votação)
- **Ordem Gate 4**: Momentum (OBV MACD) primeiro (filtro), RSI OMA depois (confirmação)
- **Tolerância Supertrend**: Permitir 1 candle de atraso
- **State Machine**: Prevenir duplicação de ordens no mesmo candle
- **Fallback automático**: Operar sem Currency Strength em índices
- **Skip Monday Open**: Implementar para Forex (primeiros 30min ou até spread normalizar)

### VALIDAÇÕES OBRIGATÓRIAS:
- Sempre usar `iCustom()` para indicadores customizados
- `CopyBuffer()` com quantidade exata de elementos esperados
- `NormalizeDouble()` para TODOS os preços e lotes antes de usar
- `SymbolInfoDouble()` para obter propriedades do símbolo em tempo real
- Preferir `TimeCurrent()` (tempo do servidor) ao invés de `TimeLocal()`
- `ArraySetAsSeries()` para buffers quando necessário (depende da lógica)
- Sempre verificar `INVALID_HANDLE` após `iCustom()` ou `iTime()`
- Usar classes `CTrade` e `CPositionInfo` para operações de trade
- Validar retorno de TODAS as funções críticas (trade, copy buffer, etc)
- Implementar logs detalhados para debug em produção

### TRATAMENTO DE ERROS OBRIGATÓRIO:
- Verificar resultado de `OrderSend()` via `CTrade::ResultRetcode()`
- Capturar código de erro com `GetLastError()` após falhas
- Implementar retry logic para erros recuperáveis (requote, timeout)
- Logar TODOS os erros com contexto suficiente para debug

### EDGE CASES CRÍTICOS:
1. **Repaint do GG TrendBar**: Sempre shift=1 + validação de 2 candles
2. **Spike de spread em news**: Spread dinâmico + time window de 2min
3. **Múltiplos sinais no mesmo candle**: State machine + flag por candle
4. **Indicador não carrega**: Fallback automático (Currency Strength ausente)
5. **Gaps de abertura (Monday Forex)**: Skip primeiros 30min ou até normalizar spread

---

## 📊 SISTEMA DE LOGGING (3 NÍVEIS)

### NÍVEL 1 - EXECUTIVO (InpLogLevel = 1):
```mql5
// Apenas trades executados e erros críticos
[2025.01.10 09:15:00] ✅ PREMIUM BUY | USDJPY | Entry: 141.250 | Risk: 100pts
[2025.01.10 09:15:00] ❌ ERRO CRÍTICO: Falha ao executar ordem #123456
```

### NÍVEL 2 - OPERACIONAL (InpLogLevel = 2):
```mql5
// Gates, scores e decisões
[2025.01.10 09:15:00] Gates: G0✓ G1✓ G2✓ G3✓ G4✓ G5✓
[2025.01.10 09:15:00] MTF Score: +4 | Classification: PREMIUM
[2025.01.10 09:15:00] Micro: ST✓ MOM✓ RSI✓ CS✓
[2025.01.10 09:15:00] Order: #123456 | 0.01 lots @ 141.250
[2025.01.10 09:15:01] State: IDLE → ORDER_SENT
```

### NÍVEL 3 - DEBUG (InpLogLevel = 3):
```mql5
// Valores brutos dos indicadores
[2025.01.10 09:15:00] Buffers frozen at: 2025.01.10 09:15:00 (shift=1)
[2025.01.10 09:15:00] GG[H4]:+1 [H1]:+1 [M30]:+1 [M15]:+1 | Score: +4
[2025.01.10 09:15:00] MOM: Hist=0.0015 > Threshold=0.0010 ✓
[2025.01.10 09:15:00] RSI OMA: Red=0.82 > Blue=0.65 (BUY signal)
[2025.01.10 09:15:00] Spread: 15pts < Max:20pts (75% limit) ✓
[2025.01.10 09:15:00] CS: EUR=0.65 > USD=0.35 (Delta: +0.30) ✓
```

---

## 📌 COMPILAÇÃO E ESTRUTURA DE PASTAS

### ESTRUTURA OBRIGATÓRIA NO MetaEditor:

```text
MQL5/
├── Experts/NexusConfluenceEA/
│           └── NexusConfluenceEA.mq5
├── Include/NexusConfluenceEA/
│          └── Modules/
│              ├── Core.mqh
│              ├── MarketAccess.mqh
│              ├── IndicatorHub.mqh
│              ├── SignalEngine.mqh
│              └── RiskExecution.mqh
└── Indicators/NexusConfluenceEA/
               ├── GG_TrendBar_Indicator.mq5 (ou .ex5)
               ├── TrendMagic_MT5.mq5 (ou .ex5)
               ├── OBV_MACD.mq5 (ou .ex5)
               ├── RSIOMA_v2HHLSX_MT5.mq5 (ou .ex5)
               └── CurrencyStrengthMeter_MT5.mq5 (ou .ex5)
```

### CHECKLIST PRÉ-COMPILAÇÃO:
1. ✅ Todos os arquivos `.mqh` estão no diretório `Include/NexusConfluenceEA/Modules/`
2. ✅ Todos os indicadores estão compilados em `Indicators/NexusConfluenceEA/`
3. ✅ Paths dos `#include` estão corretos
4. ✅ Não há warnings de compilação
5. ✅ Código validado contra o `mql5.pdf`

### TESTES OBRIGATÓRIOS ANTES DE CONTA REAL:
1. **Strategy Tester** em dados históricos (mínimo 6 meses)
2. **Visual Mode** para validar comportamento gate-by-gate
3. **Demo Account** com dinheiro virtual por pelo menos 2 semanas
4. **Validar logs** em todas as situações (erro, sucesso, rejeição)
5. **Testar em diferentes símbolos** (Forex, Índices, etc)
6. **Validar comportamento em períodos de alta volatilidade**
7. **Testar Score System**: Verificar que BUY ≥ +2 e SELL ≤ -2
8. **Testar State Machine**: Garantir que não há duplicação de ordens
9. **Testar Fallback**: Confirmar operação sem Currency Strength em índices
10. **Testar Skip Monday Open**: Validar em Forex (gaps)

### MÉTRICAS DE VALIDAÇÃO (KPIs):
- **Taxa de Sinais PREMIUM**: < 5 sinais/dia (exclusivos)
- **Taxa de Sinais GOOD**: < 10 sinais/dia (qualidade)
- **Win Rate PREMIUM**: > 65% (objetivo)
- **Win Rate GOOD**: > 55% (objetivo)
- **Rejeições Gate 2 (MTF)**: ~40% esperado
- **Rejeições Gate 4 (Momentum)**: ~30% esperado
- **Rejeições Gate 5 (CS)**: ~20% esperado
- **Latência por tick**: < 50ms
- **CPU por candle**: < 100ms

---

## 🎓 DIRETRIZES FINAIS

### ANTES DE ESCREVER QUALQUER CÓDIGO:
1. ✅ Confirmar leitura e compreensão total do `mql5.pdf`
2. ✅ Revisar especificações do módulo a ser desenvolvido
3. ✅ Planejar tratamento de erros e edge cases
4. ✅ Considerar performance e otimização
5. ✅ **Validar compreensão do Sistema de Gates (0-5)**
6. ✅ **Entender Score System (≥+2 para BUY, ≤-2 para SELL)**
7. ✅ **Confirmar ordem Momentum (OBV MACD) → RSI OMA no Gate 4**

### DURANTE O DESENVOLVIMENTO:
- ✅ Código completo, sem placeholders ou TODOs
- ✅ **Sempre usar shift=1** (bar close)
- ✅ **Implementar State Machine** para evitar duplicação
- ✅ Comentários apenas para lógica complexa não-óbvia
- ✅ Nomenclatura clara e consistente (padrão MQL5)
- ✅ Indentação perfeita e formatação profissional
- ✅ Validação de TODOS os inputs e outputs
- ✅ **Logging em 3 níveis** (Executivo, Operacional, Debug)

### APÓS DESENVOLVIMENTO:
- ✅ Compilação sem warnings
- ✅ Teste unitário de cada função crítica
- ✅ Validação de integração entre módulos
- ✅ **Validar Score System funcionando corretamente**
- ✅ **Testar State Machine** (sem duplicação)
- ✅ **Confirmar Fallback** (operar sem CS em índices)
- ✅ **Validar Skip Monday Open** (Forex)
- ✅ Documentação de parâmetros de input
- ✅ Log de versão e mudanças

---

## � CHECKLIST DE IMPLEMENTAÇÃO COMPLETO

### ARQUITETURA BASE:
- [ ] Sistema de Gates (0-5) implementado sequencialmente
- [ ] Score System MTF (soma de +1/0/-1) com threshold ≥+2 ou ≤-2
- [ ] State Machine (IDLE → SIGNAL_DETECTED → ORDER_SENT → WAITING_CLOSE)
- [ ] Cache de buffers único por candle (shift=1 sempre)
- [ ] Timestamp de validação de sincronia

### GATES ESPECÍFICOS:
- [ ] Gate 0: Sincronização + State Machine
- [ ] Gate 1: Spread dinâmico + Skip Monday Open + News Filter
- [ ] Gate 2: Score MTF + Classificação (PREMIUM/GOOD/REJECT)
- [ ] Gate 3: Supertrend com tolerância de 1 candle
- [ ] Gate 4: Momentum (OBV MACD) primeiro (expansão) → RSI OMA depois (confirmação)
- [ ] Gate 5: Currency Strength com fallback para índices

### CONFIGURAÇÕES POR MERCADO:
- [ ] Forex: CS obrigatório, Skip Monday, spread 20pts
- [ ] B3 (WIN): Sem CS, pregão 09:00-17:55, spread 10pts
- [ ] Índices (US30): Sem CS, NYSE 10:00-17:00, spread 15pts
- [ ] Metais: CS obrigatório, spread 30pts
- [ ] Crypto: Sem CS, 24/7, spread 50pts

### SISTEMA DE LOGGING:
- [ ] Nível 1: Apenas trades e erros críticos
- [ ] Nível 2: Gates, scores, decisões
- [ ] Nível 3: Valores brutos dos indicadores

### TRATAMENTO DE EDGE CASES:
- [ ] Repaint do GG TrendBar (shift=1 + validação)
- [ ] Spike de spread em news (janela de 2min)
- [ ] Múltiplos sinais no mesmo candle (State Machine)
- [ ] Currency Strength ausente (fallback automático)
- [ ] Gaps Monday Open (Skip 30min ou até normalizar)

### VALIDAÇÕES FINAIS:
- [ ] Win Rate PREMIUM > 65%
- [ ] Win Rate GOOD > 55%
- [ ] Latência < 50ms por tick
- [ ] CPU < 100ms por candle
- [ ] Sem duplicação de ordens (State Machine)
- [ ] Fallback funcionando em índices

---

## �🚨 LEMBRE-SE:

> **Este EA irá operar com DINHEIRO REAL. Um bug pode causar perdas financeiras significativas. Não há margem para código mal escrito, incompleto ou não testado. Qualidade de produção é OBRIGATÓRIA.**

### REGRAS DE OURO:
1. **SHIFT=1 SEMPRE** (bar close) - NÃO NEGOCIÁVEL
2. **Score ≥ +2 para BUY, ≤ -2 para SELL** - Sistema de votação
3. **Momentum (OBV MACD) antes de RSI OMA** no Gate 4 - Ordem crítica
4. **State Machine ativa** - Prevenir duplicação
5. **Logs em 3 níveis** - Debug em produção

---

**FIM DO PROMPT - Desenvolvedor, prove que leu o `mql5.pdf` e compreendeu o SISTEMA DE GATES antes de começar!**