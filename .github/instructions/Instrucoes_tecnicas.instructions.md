---
applyTo: '**'
---
# 🔧 INSTRUÇÕES TÉCNICAS - NEXUS CONFLUENCE EA v4.27+

## ⚠️ REGRAS CRÍTICAS - LEIA PRIMEIRO

### 🚫 **PROIBIÇÕES ABSOLUTAS**

```
❌ PROIBIDO: Criar novos arquivos de código sem remover os antigos
❌ PROIBIDO: Criar documentos redundantes ou duplicados  
❌ PROIBIDO: Criar arquivos temporários que não sejam removidos
❌ PROIBIDO: Criar "versões novas" mantendo as antigas
❌ PROIBIDO: Criar relatórios/logs desnecessários
❌ PROIBIDO: Criar arquivos de teste/debug não essenciais

✅ OBRIGATÓRIO: Corrigir código existente ao invés de criar novo
✅ OBRIGATÓRIO: Remover arquivo antigo se criar novo
✅ OBRIGATÓRIO: Consolidar funcionalidades em arquivos existentes
✅ OBRIGATÓRIO: Manter repositório limpo e organizado
✅ OBRIGATÓRIO: Um arquivo por funcionalidade principal
```

### 📋 **HIERARQUIA DE AÇÕES**

```
1. SEMPRE TENTE PRIMEIRO: Corrigir o código existente
2. SE IMPOSSÍVEL CORRIGIR: Substituir arquivo (remove antigo + cria novo)
3. SE PRECISA NOVO ARQUIVO: Consolidar arquivos similares existentes
4. NUNCA: Criar arquivo duplicado ou redundante
```

---

## 📁 ESTRUTURA ATUAL DO PROJETO (v4.27)

### **Arquivos Principais**

```
Nexus_Confluence_MT5/
├── Experts/NexusConfluenceEA/
│   └── NexusConfluenceEA.mq5          ⚡ EA PRINCIPAL
│
├── Include/NexusConfluenceEA/
│   ├── Parametros.mqh                 📋 TODOS os inputs, enums, structs
│   ├── RogersSatchell.mqh             📊 Cálculo volatilidade alternativa
│   ├── Estrategias.mqh                🎯 TODA lógica de estratégia/indicadores
│   └── RiskManagement.mqh             💰 TODA gestão de risco/posições
│
├── Indicators/NexusConfluenceEA/
│   ├── GG_TrendBar_Indicator.mq5      🎨 Indicador macro principal
│   ├── TrendMagic_MT5.mq5             🔮 Supertrend (opcional)
│   ├── WaddahAttarExplosion_Professional.mq5  💥 WAE
│   ├── RSIOMA_v2HHLSX_MT5.mq5         📈 RSI com linhas
│   └── CurrencyStrengthMeter_MT5.mq5  💪 Força de moedas
│
├── Tools/                              🛠️ Ferramentas de análise
│   ├── master_analyzer.py             🎯 Analisador principal consolidado
│   ├── production_analyzer.py         📊 Métricas de produção
│   ├── advanced_analyzer.py           🔬 Análises avançadas
│   ├── complete_set_generator.py      ⚙️ Gerador de .set files
│   ├── parse_mt5_log.py               📝 Parser de logs MT5
│   └── realtime_monitor.py            👁️ Monitor tempo real
│
└── Presets/                            💾 Configurações otimizadas
    ├── NexusConfluence_USDJPY_CONSERVATIVE_v4.32.set
    ├── NexusConfluence_USDJPY_MODERATE_v4.32.set
    └── NexusConfluence_USDJPY_AGGRESSIVE_v4.32.set
```

### **❌ NÃO CRIAR:**
- ✗ `NexusConfluenceEA_v2.mq5` ou `NexusConfluenceEA_new.mq5`
- ✗ `Estrategias_fixed.mqh` ou `Estrategias_backup.mqh`
- ✗ `RELATORIO_*.md` ou `ANALISE_*.md` desnecessários
- ✗ `test_*.py` ou `debug_*.py` temporários
- ✗ Qualquer arquivo com sufixos: `_old`, `_backup`, `_temp`, `_test`

---

## 🏗️ ARQUITETURA MODULAR v4.27 (4 MÓDULOS .MQH)

### **1. ARQUIVO PRINCIPAL: NexusConfluenceEA.mq5**

```cpp
// RESPONSABILIDADES:
// - Função OnInit(): Inicialização de indicadores e sistema
// - Função OnTick(): Fluxo principal de execução  
// - Função OnDeinit(): Limpeza de recursos
// - Função OnTimer(): Resets diários/semanais
// - MÍNIMO de lógica aqui - delegar para módulos!

// INCLUDES OBRIGATÓRIOS (nesta ordem):
#include <Trade\Trade.mqh>
#include "..\..\Include\NexusConfluenceEA\Parametros.mqh"
#include "..\..\Include\NexusConfluenceEA\RogersSatchell.mqh"
#include "..\..\Include\NexusConfluenceEA\Estrategias.mqh"
#include "..\..\Include\NexusConfluenceEA\RiskManagement.mqh"
```

### **2. MÓDULO: Parametros.mqh**

```cpp
// RESPONSABILIDADES:
// - TODAS as enumerações (enums)
// - TODAS as estruturas (structs)
// - TODOS os inputs do usuário
// - Configurações globais do EA
// - ZERO lógica - apenas definições!

// ENUMS PRINCIPAIS:
enum TRADE_DIRECTION { NONE=-1, BUY=0, SELL=1 };
enum SETUP_CLASS { REJECT=0, GOOD=1, PREMIUM=2 };
enum ASSET_CLASS { UNKNOWN=0, FOREX_MAJOR=1, ..., METALS=8 };

// STRUCTS PRINCIPAIS:
struct TMSignal { ... };      // Sinal Trend Magic/GG TrendBar
struct CSSignal { ... };      // Sinal Currency Strength
struct RSISignal { ... };     // Sinal RSI OMA
struct WAESignal { ... };     // Sinal WAE
struct RiskCalculation { ... }; // Resultado cálculo de risco

// INPUTS: 100+ parâmetros organizados em grupos
input group "=== CONFIGURAÇÕES GERAIS ==="
input double AccountRiskPercent = 0.5;
input double MaxRiskPremium = 1.0;
// ... etc
```

### **3. MÓDULO: Estrategias.mqh**

```cpp
// RESPONSABILIDADES:
// - Definir timeframes macro conforme TF operacional
// - Analisar alinhamento multi-timeframe
// - Ler todos os indicadores (GG, Supertrend, WAE, RSI, CS)
// - Calcular pontuação e classificar setup
// - Implementar cache de buffers para otimização
// - Gerenciar handles dos indicadores

// FUNÇÕES PRINCIPAIS:
void DefineMultiTimeframes(ENUM_TIMEFRAMES tfOper, ...);
bool AnalyzeMultiTimeframeAlignment(string symbol, bool isBuy, ...);
void AnalyzeMicroFilters(string symbol, ...);
TMSignal GetGGTrendBarSignal(string symbol, ENUM_TIMEFRAMES tf);
TMSignal GetSupertrendSignal(string symbol, ENUM_TIMEFRAMES tf, bool isBuy);
WAESignal GetWAESignal(string symbol, ENUM_TIMEFRAMES tf, bool isBuy);
RSISignal GetRSIOMASignal(string symbol, ENUM_TIMEFRAMES tf, bool isBuy);
CSSignal GetCurrencyStrengthSignal(string symbol, bool isBuy);
void CalculateSetupScore(...);
void ReleaseIndicators();

// VARIÁVEIS GLOBAIS:
ENUM_TIMEFRAMES g_tfMacro1, g_tfMacro2, g_tfMacro3;
int g_numNiveisMacro; // 2 ou 3
IndicatorHandles g_handles; // Todos os handles
BufferCache g_cache; // Cache de buffers
```

### **4. MÓDULO: RiskManagement.mqh**

```cpp
// RESPONSABILIDADES:
// - Calcular tamanho de posição baseado em risco
// - Encontrar SL estrutural (último topo/fundo)
// - Calcular TPs baseados em RR ou ATR
// - Validar margem disponível (especialmente B3)
// - Gerenciar posições abertas (BE, TP parcial, Trailing)
// - Controlar drawdown diário/semanal
// - Registrar perdas consecutivas e pausas

// FUNÇÕES PRINCIPAIS:
double GetMaxRiskForDay(); // Redução progressiva de risco
bool CalculatePositionSize(string symbol, ...);
double FindStructureSL(string symbol, bool isBuy, ...);
void CalculateTakeProfits(...);
bool ValidateRiskCalculation(...);
void ManageExistingTrades();
void MoveToBreakeven(ulong ticket);
void ExecutePartialClose(ulong ticket, double percent);
void UpdateTrailingStop(ulong ticket);
datetime CalculatePauseTime(int losses); // Limita pause a 12h max
```

### **5. MÓDULO: RogersSatchell.mqh**

```cpp
// RESPONSABILIDADES:
// - Calcular volatilidade Rogers-Satchell como alternativa ao ATR
// - Usar OHLC completo (mais preciso que close-to-close)
// - Fornecer métrica de volatilidade normalizada

// FUNÇÕES:
double CalculateRogersSatchell(string symbol, ENUM_TIMEFRAMES tf, int period);
```

---

## 🎯 SISTEMA MULTI-TIMEFRAME DINÂMICO

### **Lógica de Definição Automática**

```cpp
// O sistema define automaticamente os TFs macro conforme TF operacional:

TF OPERACIONAL → MACRO-1 → MACRO-2 → MACRO-3
─────────────────────────────────────────────────
M1  ou M5      →   H1    →   M30   →  M15
M15            →   H4    →   H1    →  M30
M30            →   H4    →   H1    →  (M30 = operacional, não repete)
H1  ou H4      →   D1    →   H4    →  (apenas 2 níveis)

// REGRAS:
// 1. MACRO-1 + MACRO-2 devem estar ALINHADOS (mesma cor)
// 2. MACRO-3 alinhado = PREMIUM, divergente = GOOD
// 3. Se apenas 2 níveis macro, não usa MACRO-3
```

### **Análise Obrigatória**

```cpp
// ETAPA 1: Verificar alinhamento macro
bool macro1_aligned = GetGGTrendBarSignal(symbol, g_tfMacro1).direction == pretendedDirection;
bool macro2_aligned = GetGGTrendBarSignal(symbol, g_tfMacro2).direction == pretendedDirection;

if(!macro1_aligned || !macro2_aligned) {
    return false; // REJEITADO - macro não alinhado
}

// ETAPA 2: Verificar MACRO-3 (se aplicável)
bool macro3_aligned = (g_numNiveisMacro < 3) || 
    (GetGGTrendBarSignal(symbol, g_tfMacro3).direction == pretendedDirection);

// macro3_aligned define PREMIUM (true) vs GOOD (false)
```

---

## 📊 INDICADORES E FILTROS

### **A) GG TrendBar (PRINCIPAL - Indicador Macro)**

```cpp
// OBRIGATÓRIO para análise macro
// Substitui Trend Magic original
// Lê buffer [1] (candle fechado)

TMSignal GetGGTrendBarSignal(string symbol, ENUM_TIMEFRAMES tf) {
    double ggValue[];
    CopyBuffer(g_handles.gg_trendbar[tf], 0, 1, 1, ggValue); // [1] = fechado
    
    // Verde (1.0) = BUY
    // Vermelho (-1.0) = SELL
    // Amarelo (0.0) = INDECISO
}
```

### **B) Supertrend (OPCIONAL - Reforço)**

```cpp
// OPCIONAL - não obrigatório
// Usado para reforçar sinais se habilitado
// CORREÇÃO v4.27: Agora lê buffer [1] (antes era [0])

TMSignal GetSupertrendSignal(string symbol, ENUM_TIMEFRAMES tf, bool isBuy) {
    double stValue[];
    CopyBuffer(g_handles.supertrend[tf], 0, 1, 1, stValue); // [1] = fechado!
    
    // Supertrend > 0 = tendência alta
    // Supertrend < 0 = tendência baixa
}
```

### **C) WAE - Waddah Attar Explosion**

```cpp
// Verifica explosão de momentum
// CRITÉRIO: Barras expandindo + cor correta
// Lê buffer [1] (candle fechado)

WAESignal GetWAESignal(string symbol, ENUM_TIMEFRAMES tf, bool isBuy) {
    double trendUp[3], trendDown[3], explosion[3];
    
    CopyBuffer(g_handles.wae[tf], 0, 1, 3, trendUp);
    CopyBuffer(g_handles.wae[tf], 1, 1, 3, trendDown);
    CopyBuffer(g_handles.wae[tf], 2, 1, 3, explosion);
    
    // Para BUY: trendUp[0] > 0 E expandindo
    // Para SELL: trendDown[0] > 0 E expandindo
    // Verificar: barras[0] > barras[1] (expandindo)
}
```

### **D) RSI OMA - v4.27 SIMPLIFICADO**

```cpp
// CORREÇÃO v4.27: SIMPLIFICADO!
// ❌ REMOVIDO: Validação de inclinação (slope)
// ❌ REMOVIDO: Validação de zona (overbought/oversold)
// ✅ CRITÉRIO: Apenas posição relativa das linhas

RSISignal GetRSIOMASignal(string symbol, ENUM_TIMEFRAMES tf, bool isBuy) {
    double redLine[1], blueLine[1];
    
    CopyBuffer(g_handles.rsioma[tf], 0, 1, 1, redLine);
    CopyBuffer(g_handles.rsioma[tf], 1, 1, 1, blueLine);
    
    // Para BUY: redLine > blueLine (simples!)
    // Para SELL: redLine < blueLine
    
    // NÃO verificar mais:
    // - Inclinação (slope > 0.5 ou < -0.5)
    // - Zona (overbought/oversold)
    
    return (isBuy && redLine[0] > blueLine[0]) ||
           (!isBuy && redLine[0] < blueLine[0]);
}
```

### **E) Currency Strength Meter**

```cpp
// APLICÁVEL: Forex (todos), WDO, Metais
// NÃO aplicável: WIN, Índices (não tem pares de moedas)

CSSignal GetCurrencyStrengthSignal(string symbol, bool isBuy) {
    // Extrair moedas do símbolo
    string baseCurrency = StringSubstr(symbol, 0, 3);
    string quoteCurrency = StringSubstr(symbol, 3, 3);
    
    // Ler força de cada moeda
    double baseStrength = GetCurrencyStrength(baseCurrency);
    double quoteStrength = GetCurrencyStrength(quoteCurrency);
    
    // ATENÇÃO: Para METAIS, interpretar INVERSO!
    // Ouro sobe quando USD fraco (inverso do normal)
    
    if(IsMetalPair(symbol)) {
        return (isBuy && quoteStrength < baseStrength) || // USD fraco = ouro forte
               (!isBuy && quoteStrength > baseStrength);
    }
    
    // Forex normal
    return (isBuy && baseStrength > quoteStrength) ||
           (!isBuy && baseStrength < quoteStrength);
}
```

---

## 🎯 SISTEMA DE PONTUAÇÃO

### **Matriz de Aplicação por Ativo**

```
╔═══════════════════════════════════════════════════════╗
║  ATIVO            │ FILTROS MICRO  │ PONTUAÇÃO        ║
╠═══════════════════════════════════════════════════════╣
║  Forex (todos)    │ CS + RSI + WAE │ 2/3 ou 3/3      ║
║  WDO (B3)         │ CS + RSI + WAE │ 2/3 ou 3/3      ║
║  Metais           │ CS + RSI + WAE │ 2/3 ou 3/3      ║
║  ─────────────────────────────────────────────────────║
║  WIN (B3)         │ RSI + WAE      │ 2/2 obrigatório ║
║  Índices (US/EU)  │ RSI + WAE      │ 2/2 obrigatório ║
╚═══════════════════════════════════════════════════════╝

CLASSIFICAÇÃO:
- PREMIUM: Todos filtros alinhados (3/3 ou 2/2) + MACRO-3 alinhado
- GOOD: Mínimo filtros (2/3 ou 2/2) + MACRO-1+2 alinhados
- REJECT: Menos que mínimo OU macro desalinhado
```

### **Função de Pontuação**

```cpp
void CalculateSetupScore(
    string symbol,
    SETUP_CLASS &outClass,
    int &outScore,
    string &outDetails
) {
    ASSET_CLASS assetClass = ClassifyAsset(symbol);
    int score = 0;
    int requiredScore = 0;
    
    // Determinar filtros aplicáveis
    bool useCS = (assetClass != ASSET_CLASS_INDEX_B3 && 
                  assetClass != ASSET_CLASS_INDEX_US && 
                  assetClass != ASSET_CLASS_INDEX_EU);
    
    if(useCS) {
        // Forex/WDO/Metais: 3 filtros
        if(CSAligned) score++;
        if(RSIAligned) score++;
        if(WAEAligned) score++;
        requiredScore = UseStrictFilters ? 3 : 2;
    } else {
        // Índices: 2 filtros
        if(RSIAligned) score++;
        if(WAEAligned) score++;
        requiredScore = 2; // Sempre obrigatório para índices
    }
    
    // Classificar
    if(score < requiredScore) {
        outClass = SETUP_REJECT;
    } else if(score == requiredScore && !macro3_aligned) {
        outClass = SETUP_GOOD;
    } else {
        outClass = SETUP_PREMIUM;
    }
    
    outScore = score;
}
```

---

## 💰 GESTÃO DE RISCO v4.30+

### **Redução Progressiva de Risco**

```cpp
// NOVO v4.30: Proteção inteligente contra drawdown

double GetMaxRiskForDay() {
    double dailyDD = CalculateDailyDrawdown();
    
    if(dailyDD <= 2.0) {
        return 1.0;  // 100% do risco configurado (zona verde)
    }
    else if(dailyDD <= 5.0) {
        return 0.75; // 75% do risco (zona amarela)
    }
    else if(dailyDD <= 8.0) {
        return 0.5;  // 50% do risco (zona laranja)
    }
    else {
        return 0.0;  // PAUSA trading (zona vermelha)
    }
}

// IMPACTO ESPERADO:
// - Drawdown máximo: -40% (91% → 55%)
// - Win Rate: +1-2%
// - Sharpe Ratio: +0.02 a +0.05
```

### **Cálculo de Posição**

```cpp
bool CalculatePositionSize(
    string symbol,
    bool isBuy,
    SETUP_CLASS setupClass,
    RiskCalculation &outRisk
) {
    // 1. Determinar % risco base
    double riskPercent = (setupClass == SETUP_PREMIUM) ? 
        MaxRiskPremium : AccountRiskPercent;
    
    // 2. Aplicar redução progressiva
    double riskMultiplier = GetMaxRiskForDay();
    riskPercent *= riskMultiplier;
    
    if(riskPercent <= 0) {
        PrintFormat("⛔ Risco = 0%% (drawdown diário alto ou pausa ativa)");
        return false;
    }
    
    // 3. Encontrar SL estrutural
    double slPrice = FindStructureSL(symbol, isBuy, ...);
    double slDistance = MathAbs(currentPrice - slPrice);
    
    // 4. Validar SL ideal
    if(!IsValidSLDistance(slDistance, symbol)) {
        return false; // SL muito largo ou muito apertado
    }
    
    // 5. Calcular lote
    double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * riskPercent / 100.0;
    double pointValue = GetPointValue(symbol);
    double lotSize = riskAmount / (slDistance / _Point * pointValue);
    
    // 6. Normalizar e validar margem (especialmente B3)
    lotSize = NormalizeLotSize(symbol, lotSize);
    
    if(!ValidateMargin(symbol, lotSize)) {
        return false;
    }
    
    // 7. Preencher resultado
    outRisk.lotSize = lotSize;
    outRisk.slPrice = slPrice;
    outRisk.slDistance = slDistance;
    outRisk.riskAmount = riskAmount;
    outRisk.riskPercent = riskPercent;
    
    return true;
}
```

### **SL Estrutural**

```cpp
double FindStructureSL(
    string symbol,
    bool isBuy,
    ENUM_TIMEFRAMES tfSearch,
    int lookbackBars
) {
    // Buscar no timeframe especificado (geralmente M15 ou M30)
    double highs[], lows[];
    
    CopyHigh(symbol, tfSearch, 1, lookbackBars, highs);
    CopyLow(symbol, tfSearch, 1, lookbackBars, lows);
    
    if(isBuy) {
        // Encontrar último FUNDO significativo
        double lastLow = FindLastSignificantLow(lows);
        
        // Aplicar buffer de segurança
        double buffer = CalculateSLBuffer(symbol);
        return lastLow - buffer;
    }
    else {
        // Encontrar último TOPO significativo
        double lastHigh = FindLastSignificantHigh(highs);
        
        double buffer = CalculateSLBuffer(symbol);
        return lastHigh + buffer;
    }
}

// VALIDAÇÃO: SL deve estar entre min e max ideal para o ativo
bool IsValidSLDistance(double distance, string symbol) {
    double minSL = GetMinSL(symbol);
    double maxSL = GetMaxSL(symbol);
    
    return (distance >= minSL && distance <= maxSL);
}
```

---

## 🎯 GESTÃO DE SAÍDAS

### **Sistema Híbrido (v4.27)**

```cpp
// NOVO v4.27: Lógica adaptativa
// - EnablePartialTP = true: TPs parciais (TP1 50%, TP2 25%, Trail 25%)
// - EnablePartialTP = false: Ordem única com TPs altos (15:1, 20:1, 25:1)

if(EnablePartialTP) {
    // MODO PARCIAL
    TP1 = Entry + (SL_Distance × TP1_RR);  // RR padrão: 2:1
    TP2 = Entry + (SL_Distance × TP2_RR);  // RR padrão: 4:1
    TP3 = Entry + (SL_Distance × TP3_RR);  // RR padrão: 6:1
    
    // Após TP1: Move SL para breakeven + executa parcial 50%
    // Após TP2: Ativa trailing + executa parcial 25%
    // TP3: Trailing continua (25% restante)
}
else {
    // MODO ORDEM ÚNICA
    TP1 = Entry + (SL_Distance × 15.0); // 15:1
    TP2 = Entry + (SL_Distance × 20.0); // 20:1
    TP3 = Entry + (SL_Distance × 25.0); // 25:1
    
    // Breakeven e trailing baseados em RR atingido
    if(CurrentRR >= BreakevenActivationRR) {
        MoveToBreakeven();
    }
    if(CurrentRR >= TrailingActivationRR) {
        ActivateTrailing();
    }
}
```

### **Breakeven e Trailing**

```cpp
void ManageExistingTrades() {
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        if(!PositionSelectByIndex(i)) continue;
        if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
        
        ulong ticket = PositionGetInteger(POSITION_TICKET);
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
        double currentSL = PositionGetDouble(POSITION_SL);
        bool isLong = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
        
        // Calcular RR atual
        double slDistance = MathAbs(openPrice - currentSL);
        double currentProfit = isLong ? (currentPrice - openPrice) : (openPrice - currentPrice);
        double currentRR = currentProfit / slDistance;
        
        // BREAKEVEN
        if(currentRR >= BreakevenActivationRR && currentSL != openPrice) {
            MoveToBreakeven(ticket);
        }
        
        // TRAILING
        if(currentRR >= TrailingActivationRR) {
            UpdateTrailingStop(ticket);
        }
    }
}

void UpdateTrailingStop(ulong ticket) {
    // Trailing dinâmico baseado em ATR
    double atrValue = iATR(_Symbol, PERIOD_CURRENT, ATR_Period);
    double trailDistance = atrValue * TrailingStopATRMultiplier;
    
    // Atualizar SL seguindo preço
    // ... lógica de trailing ...
}
```

---

## 🛡️ PROTEÇÕES E VALIDAÇÕES

### **Proteção de Drawdown**

```cpp
// Verificado NO INÍCIO do OnTick()
bool ValidateDrawdownProtection() {
    double currentDD = CalculateDailyDrawdown();
    
    if(currentDD >= MaxDailyDrawdown) {
        if(!g_dailyDrawdownHit) {
            g_dailyDrawdownHit = true;
            g_pauseUntilTime = GetNextDayStart();
            
            PrintFormat("🔴 DRAWDOWN DIÁRIO ATINGIDO: %.2f%% (limite: %.2f%%)", 
                currentDD, MaxDailyDrawdown);
            PrintFormat("⏸️  Trading pausado até %s", 
                TimeToString(g_pauseUntilTime));
            
            SendNotification("Nexus: Drawdown diário atingido! Trading pausado.");
        }
        return false; // NÃO OPERAR
    }
    
    return true;
}
```

### **Controle de Perdas Consecutivas**

```cpp
// Registrado ao fechar trade perdedor
void OnTradeClose(double profit) {
    if(profit < 0) {
        g_consecutiveLosses++;
        
        if(g_consecutiveLosses >= MaxConsecutiveLosses) {
            // Pausar trading com limite máximo de 12h
            datetime pauseTime = CalculatePauseTime(g_consecutiveLosses);
            g_pauseUntilTime = pauseTime;
            
            PrintFormat("⏸️  %d perdas consecutivas - pausado até %s",
                g_consecutiveLosses, TimeToString(pauseTime));
        }
    }
    else {
        g_consecutiveLosses = 0; // Reset no primeiro ganho
    }
}

datetime CalculatePauseTime(int losses) {
    // v4.24: Limite máximo de pausa = 12h
    // Evita pausas excessivamente longas
    
    int pauseMinutes;
    
    switch(losses) {
        case 3: pauseMinutes = 60; break;   // 1h
        case 4: pauseMinutes = 120; break;  // 2h
        case 5: pauseMinutes = 300; break;  // 5h
        default: pauseMinutes = 720; break; // 12h max
    }
    
    datetime pauseUntil = TimeCurrent() + pauseMinutes * 60;
    
    // Não pausar além do próximo pregão
    datetime nextDayStart = GetNextDayStart();
    if(pauseUntil > nextDayStart) {
        pauseUntil = nextDayStart;
    }
    
    return pauseUntil;
}
```

---

## 📝 FORMATO DE ARQUIVOS .SET

### **CRÍTICO: Formato MT5 Exato**

```ini
; Nexus Confluence EA v4.32 - CONSERVATIVE Profile
; saved on 2025.01.24
;
; FORMATO OBRIGATÓRIO: ParameterName=Value||Default||Min||Max||Optimize
;
AccountRiskPercent=0.5||0.5||0.1||5.0||N
MaxRiskPremium=1.0||1.0||0.1||5.0||N
MaxDailyDrawdown=5.0||5.0||1.0||15.0||N
MaxWeeklyDrawdown=10.0||10.0||5.0||25.0||N
EnablePartialTP=true||true||0||true||N
TP1_RiskRewardRatio=2.0||2.0||1.0||10.0||Y
TP2_RiskRewardRatio=4.0||4.0||2.0||20.0||Y
TP3_RiskRewardRatio=6.0||6.0||3.0||30.0||Y
TrailingStopATRMultiplier=2.5||2.5||1.0||5.0||Y
BreakevenActivationRR=1.5||1.5||0.5||3.0||Y
UseStrictFilters=false||false||0||true||N
RequireSupertrend=false||false||0||true||N
MagicNumber=20241015||20241015||1||999999999||N
```

### **TIPOS DE VALORES:**
- `double`: `X.X||X.X||Min||Max||N/Y`
- `int`: `X||X||Min||Max||N/Y`
- `bool`: `true||false||0||true||N/Y`
- `string`: `Value` (sem pipes)
- `color`: `ColorCode` (sem pipes)

### **❌ NUNCA USE:**
- Seções decorativas `═══════`
- Comentários multilinha dentro
- Valores sem pipes `||`
- Linhas vazias excessivas

---

## 🧪 PROCESSO DE DESENVOLVIMENTO

### **FLUXO DE CORREÇÃO/MELHORIA**

```
1. IDENTIFICAR PROBLEMA NO CÓDIGO EXISTENTE
   ↓
2. TENTAR CORRIGIR IN-PLACE (no arquivo atual)
   ↓
3. SE IMPOSSÍVEL: Planejar refatoração
   ↓
4. CRIAR VERSÃO CORRIGIDA
   ↓
5. TESTAR EXAUSTIVAMENTE
   ↓
6. SUBSTITUIR ARQUIVO ANTIGO (remover!)
   ↓
7. ATUALIZAR DOCUMENTAÇÃO (se necessário)
   ↓
8. COMMIT COM MENSAGEM CLARA
```

### **EXEMPLO CORRETO:**

```bash
# ❌ ERRADO:
git add Estrategias_new.mqh
git commit -m "nova versão estrategias"
# (mantém Estrategias.mqh antigo = redundância!)

# ✅ CORRETO:
git rm Include/NexusConfluenceEA/Estrategias.mqh
git add Include/NexusConfluenceEA/Estrategias.mqh  # versão corrigida
git commit -m "fix: Corrigido sincronização Supertrend (buffer [0] → [1])"
```

---

## ✅ CHECKLIST DE QUALIDADE

### **Antes de Commitar Código:**

- [ ] ✅ Código compila sem erros/warnings
- [ ] ✅ Testado em Strategy Tester (mínimo 1 mês dados)
- [ ] ✅ Nenhum arquivo duplicado/redundante criado
- [ ] ✅ Arquivos antigos removidos (se substituídos)
- [ ] ✅ Logs detalhados adicionados para debug
- [ ] ✅ Comentários atualizados no código
- [ ] ✅ Versão incrementada no header
- [ ] ✅ Changelog atualizado no header do arquivo
- [ ] ✅ Commit message descritivo

### **Antes de Criar Novo Arquivo:**

- [ ] ❓ Realmente IMPOSSÍVEL corrigir arquivo existente?
- [ ] ❓ Funcionalidade não pode ser adicionada a arquivo existente?
- [ ] ❓ Não é possível consolidar arquivos similares?
- [ ] ✅ Se criar novo: Remover arquivo antigo equivalente
- [ ] ✅ Atualizar includes no arquivo principal
- [ ] ✅ Documentar razão da criação no commit

---

## 📚 DOCUMENTAÇÃO OBRIGATÓRIA

### **Header de Arquivo .MQH/.MQ5**

```cpp
//+------------------------------------------------------------------+
//| ARQUIVO: NomeDoArquivo.mqh                                       |
//| PROPÓSITO: Descrição concisa (1 linha)                          |
//|                                                                   |
//| RESPONSABILIDADES:                                               |
//|   - Lista de responsabilidades principais                        |
//|   - Cada responsabilidade em uma linha                          |
//|                                                                   |
//| DEPENDÊNCIAS:                                                    |
//|   - Lista de arquivos incluídos                                 |
//|                                                                   |
//| CHANGELOG:                                                       |
//|   v4.27 (2025-01-XX): Descrição das mudanças                    |
//|   v4.26 (2025-01-XX): Mudanças anteriores                       |
//|                                                                   |
//| AUTOR: GitHub Copilot + Desenvolvedor                            |
//| DATA: Janeiro 2025                                               |
//| VERSÃO: 4.27                                                     |
//+------------------------------------------------------------------+
#property copyright "Nexus Confluence EA v4.27"
#property version   "4.27"
#property strict
```

### **Comentários de Função**

```cpp
//+------------------------------------------------------------------+
//| Calcula tamanho de posição baseado em risco estrutural          |
//|                                                                   |
//| PARÂMETROS:                                                      |
//|   symbol      - Símbolo do ativo                                |
//|   isBuy       - true para compra, false para venda              |
//|   setupClass  - PREMIUM ou GOOD (determina % risco)             |
//|   outRisk     - Estrutura de saída com resultado do cálculo     |
//|                                                                   |
//| RETORNA:                                                         |
//|   true se cálculo válido, false se rejeitado                    |
//|                                                                   |
//| VALIDAÇÕES:                                                      |
//|   - SL dentro do range ideal do ativo                           |
//|   - Margem suficiente disponível                                |
//|   - Drawdown diário dentro do limite                            |
//|   - Lote mínimo/máximo respeitado                               |
//+------------------------------------------------------------------+
bool CalculatePositionSize(
    string symbol,
    bool isBuy,
    SETUP_CLASS setupClass,
    RiskCalculation &outRisk
) {
    // Implementação...
}
```

---

## 🎯 PRIORIDADES DE DESENVOLVIMENTO

### **SEMPRE:**
1. **Robustez > Performance** - código deve funcionar sempre
2. **Segurança > Lucro** - proteger capital é prioridade #1
3. **Clareza > Complexidade** - código simples e mantível
4. **Correção > Criação** - corrigir existente antes de criar novo
5. **Consolidação > Fragmentação** - menos arquivos, mais organizados

### **NUNCA:**
1. ❌ Violar gestão de risco (SL é sagrado)
2. ❌ Criar arquivos redundantes
3. ❌ Deixar código duplicado
4. ❌ Commitar sem testar
5. ❌ Ignorar warnings/erros

---

## 📋 RESUMO EXECUTIVO

**O EA Nexus Confluence v4.27+ é um sistema modular, limpo e profissional que:**

✅ Implementa fielmente o Sistema Universal v4.0
✅ Adapta-se automaticamente a qualquer ativo
✅ Usa estrutura modular clara (4 arquivos .mqh principais)
✅ Respeita rigorosamente gestão de risco com proteções
✅ Opera apenas setups de qualidade (PREMIUM/GOOD)
✅ Mantém código consolidado (zero redundância)
✅ É totalmente configurável via inputs
✅ Documenta tudo para auditoria
✅ É escalável e profissional

**⚠️ REGRA DE OURO: Corrigir, Consolidar, Nunca Duplicar!**

---

*"Código limpo não é sobre escrever pouco, mas sobre escrever certo."*

**Este documento reflete a estrutura REAL do EA v4.27. Siga-o fielmente.**
