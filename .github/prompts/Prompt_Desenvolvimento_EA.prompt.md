---
mode: agent
---
# 🎯 PROMPT PARA DESENVOLVIMENTO - EA NEXUS CONFLUENCE MT5 V4.0

## 📋 OBJETIVO PRINCIPAL
Desenvolver um Expert Advisor (EA) completo para MetaTrader 5 que implemente fielmente o **Sistema de Trading Profissional v4.0 - Versão Universal**, capaz de operar automaticamente em múltiplas classes de ativos (Forex, Índices, Metais, B3) com gestão de risco profissional e adaptação inteligente por tipo de ativo.

---

## 🌍 VISÃO GERAL DO SISTEMA

### Filosofia Universal
O EA deve implementar um sistema que:
- ✅ **Funciona em qualquer ativo** (Forex, Índices, Metais, B3)
- ✅ **Adapta-se automaticamente** às características de cada classe
- ✅ **Usa confluência inteligente** de indicadores
- ✅ **Gestão de risco baseada em estrutura** de preços
- ✅ **Respeita horários de liquidez** globais sincronizados
- ✅ **Prioriza qualidade sobre quantidade** de trades

### Princípios Fundamentais
1. **Alinhamento Multi-Timeframe Obrigatório** (H4/H1 alinhados)
2. **Confluência de Indicadores Adaptável** (2/3 ou 2/2 conforme ativo)
3. **Gestão de Risco Baseada em Estrutura** (SL no último topo/fundo)
4. **Horários de Liquidez Inteligentes** (adaptados por ativo)
5. **Qualidade Suprema** (aguardar setups perfeitos)

---

## 🔧 ESPECIFICAÇÕES TÉCNICAS DETALHADAS

### **1. ESTRUTURA BASE DO EA**

```cpp
// Estrutura básica do EA
class CNexusConfluenceEA {
private:
    // Enumerações para tipos de ativos
    enum ASSET_CLASS {
        FOREX_MAJOR,    // EUR/USD, GBP/USD, USD/JPY, AUD/USD
        FOREX_MINOR,    // EUR/GBP, EUR/JPY, GBP/JPY, etc
        FOREX_EXOTIC,   // USD/BRL, USD/MXN, USD/ZAR, etc
        INDEX_US,       // S&P500, Nasdaq, Dow Jones
        INDEX_EU,       // DAX, FTSE, CAC40
        INDEX_B3,       // WIN (Mini Índice Bovespa)
        CURRENCY_B3,    // WDO (Mini Dólar)
        METALS,         // XAU/USD, XAG/USD
        CRYPTO          // BTC/USD, ETH/USD (futuro)
    };
    
    // Configurações por classe de ativo
    struct AssetConfig {
        ASSET_CLASS type;
        bool useCurrencyStrength;
        int requiredFilters;        // 2 ou 3
        int minFiltersForTrade;     // 2 ou 2
        double idealSLMin;          // Distância mínima SL
        double idealSLMax;          // Distância máxima SL
        double slBuffer;            // Buffer adicional
        int primeHourStart;         // Horário prime início (BR)
        int primeHourEnd;           // Horário prime fim (BR)
        double maxRiskPercent;      // Risco máximo para premium setups
    };
};
```

### **2. INDICADORES OBRIGATÓRIOS**

#### A) **Trader Magic (Indicador Principal)**
```cpp
// Função para detectar mudança do Trader Magic
bool CheckTraderMagicSignal(string symbol, ENUM_TIMEFRAMES timeframe) {
    // Verificar mudança de cor por 2+ candles
    // Para COMPRA: Mudou de VERMELHO → VERDE/AZUL
    // Para VENDA: Mudou de VERDE/AZUL → VERMELHO
    // Deve manter cor por pelo menos 2 candles fechados
}
```

#### B) **Currency Strength Meter**
```cpp
// Aplicável apenas para: Forex (todos), WDO, Metais
bool CheckCurrencyStrength(string symbol, ENUM_TIMEFRAMES timeframe, bool isBuy) {
    // Para pares forex: Moeda base forte vs moeda cotação fraca
    // Para WDO: USD vs BRL
    // Para Metais: Interpretar INVERSO (USD fraco = ouro forte)
}
```

#### C) **RSI OMA (RSI com inclinação)**
```cpp
bool CheckRSIOMA(string symbol, ENUM_TIMEFRAMES timeframe, bool isBuy) {
    // Verificar:
    // 1. RSI na cor correta (vermelho acima azul para compra)
    // 2. Linha com inclinação na direção correta
    // 3. Não oscilando (estável por 2+ candles)
}
```

#### D) **WAE (Waddah Attar Explosion)**
```cpp
bool CheckWAE(string symbol, ENUM_TIMEFRAMES timeframe, bool isBuy) {
    // Verificar:
    // 1. Histograma na cor correta
    // 2. Barras EXPANDINDO (não diminuindo)
    // 3. Força suficiente (acima de threshold mínimo)
}
```

### **3. SISTEMA MULTI-TIMEFRAME**

```cpp
struct MultiTimeframeAnalysis {
    bool H4_aligned;        // H4 na cor correta
    bool H1_aligned;        // H1 alinhado com H4
    bool M30_aligned;       // M30 alinhado (desejável)
    bool structure_valid;   // Estrutura H4 favorável
    int quality_score;      // 0-3 pontos
};

MultiTimeframeAnalysis AnalyzeTimeframes(string symbol, bool isBuy) {
    // REGRA OURO: H4 e H1 DEVEM estar alinhados
    // M30 alinhado = bonus (setup premium)
    // Estrutura: topos/fundos sequenciais corretos
}
```

### **4. SISTEMA DE PONTUAÇÃO ADAPTÁVEL**

```cpp
struct SetupScore {
    int traderMagicPoints;      // 1 ponto (obrigatório)
    int currencyStrengthPoints; // 0 ou 1 (se aplicável)
    int rsiomaPoints;          // 0 ou 1
    int waePoints;             // 0 ou 1
    int totalPoints;           // Soma total
    int requiredPoints;        // 2 ou 3 conforme ativo
    string classification;     // "PREMIUM", "BOM", "REJECT"
};

SetupScore CalculateSetupScore(string symbol, ENUM_TIMEFRAMES tf, bool isBuy) {
    ASSET_CLASS assetType = ClassifyAsset(symbol);
    
    // Forex/Metais/WDO: Precisa 2 de 3 (CS, RSI, WAE)
    // Índices/WIN: Precisa 2 de 2 (RSI, WAE) - CS não aplicável
}
```

### **5. GESTÃO DE RISCO BASEADA EM ESTRUTURA**

```cpp
struct RiskManagement {
    double entryPrice;
    double stopLoss;
    double slDistance;
    double tp1Level;
    double tp2Level;
    double positionSize;
    double riskAmount;
    bool marginValid;
};

RiskManagement CalculateRiskManagement(string symbol, bool isBuy, double riskPercent) {
    // 1. Identificar último topo/fundo significativo no M15
    // 2. Calcular SL com buffer apropriado por ativo
    // 3. Validar se SL está dentro do range ideal
    // 4. Calcular tamanho: (Capital × %Risco) ÷ (SL × Valor_pip)
    // 5. Para B3: Validar margem disponível
}
```

### **6. HORÁRIOS GLOBAIS SINCRONIZADOS**

```cpp
struct TradingHours {
    int primeStart;     // Horário início prime (BR)
    int primeEnd;       // Horário fim prime (BR)
    bool isActive;      // Se está em horário de trading
    bool isPrime;       // Se está no melhor horário
    int quality;        // 1-5 qualidade do horário
};

TradingHours GetTradingHours(string symbol, datetime currentTime) {
    // Converter horário servidor para BR
    // Aplicar regras específicas:
    // - Forex: 10:00-14:00 BR (overlap Londres/NY)
    // - B3: 14:00-16:00 BR (overlap B3/NY)  
    // - Índices US: 11:30-18:00 BR
    // - Metais: 05:00-09:00 + 10:00-14:00 BR
}
```

### **7. GESTÃO HÍBRIDA DE SAÍDAS**

```cpp
class TradeManagement {
private:
    struct TradeExits {
        double tp1Price;        // TP1 - 50% posição (RR 1:1)
        double tp2Price;        // TP2 - 25% posição (RR 1:2)  
        double trailingDistance; // Trailing - 25% restante
        bool tp1Hit;
        bool tp2Hit;
        bool trailingActive;
    };
    
public:
    void ManagePosition(int ticket) {
        // Após TP1: Mover SL para breakeven
        // Após TP2: Ativar trailing stop
        // Trailing distance adaptada por ativo
    }
};
```

---

## 🎯 CONFIGURAÇÕES POR CLASSE DE ATIVO

### **FOREX MAJORS/MINORS**
```cpp
AssetConfig forexMajor = {
    .type = FOREX_MAJOR,
    .useCurrencyStrength = true,
    .requiredFilters = 3,
    .minFiltersForTrade = 2,
    .idealSLMin = 15,           // pips
    .idealSLMax = 50,           // pips
    .slBuffer = 5,              // pips
    .primeHourStart = 1000,     // 10:00 BR
    .primeHourEnd = 1400,       // 14:00 BR
    .maxRiskPercent = 2.0       // 2% para premium
};
```

### **B3 - WIN (Mini Índice)**
```cpp
AssetConfig b3Win = {
    .type = INDEX_B3,
    .useCurrencyStrength = false,  // NÃO usar (é índice)
    .requiredFilters = 2,
    .minFiltersForTrade = 2,
    .idealSLMin = 150,             // pontos
    .idealSLMax = 600,             // pontos  
    .slBuffer = 50,                // pontos
    .primeHourStart = 1400,        // 14:00 BR
    .primeHourEnd = 1600,          // 16:00 BR
    .maxRiskPercent = 2.0
};
```

### **B3 - WDO (Mini Dólar)**
```cpp
AssetConfig b3Wdo = {
    .type = CURRENCY_B3,
    .useCurrencyStrength = true,   // USAR (é USD/BRL!)
    .requiredFilters = 3,
    .minFiltersForTrade = 2,
    .idealSLMin = 10,              // pontos
    .idealSLMax = 50,              // pontos
    .slBuffer = 5,                 // pontos
    .primeHourStart = 1400,        // 14:00 BR
    .primeHourEnd = 1600,          // 16:00 BR  
    .maxRiskPercent = 1.5          // Mais conservador
};
```

### **METAIS (Ouro/Prata)**
```cpp
AssetConfig metals = {
    .type = METALS,
    .useCurrencyStrength = true,   // Usar INVERSO
    .requiredFilters = 3,
    .minFiltersForTrade = 2,
    .idealSLMin = 3,               // USD para ouro
    .idealSLMax = 25,              // USD para ouro
    .slBuffer = 2,                 // USD
    .primeHourStart = 500,         // 05:00 BR (Londres)
    .primeHourEnd = 1400,          // 14:00 BR
    .maxRiskPercent = 2.0
};
```

---

## 📊 PARÂMETROS DE INPUT DO EA

```cpp
// === CONFIGURAÇÕES GERAIS ===
input group "=== CONFIGURAÇÕES GERAIS ==="
input bool EnableAutoTrading = true;               // Ativar trading automático
input double AccountRiskPercent = 1.5;             // % risco por trade
input double MaxRiskPremium = 2.0;                 // % risco máximo (setups premium)
input int MaxSimultaneousTrades = 3;               // Máximo trades simultâneos
input bool EnableB3 = false;                       // Ativar trading B3
input bool EnableForex = true;                     // Ativar Forex
input bool EnableIndices = true;                   // Ativar Índices
input bool EnableMetals = true;                    // Ativar Metais

// === FILTROS E CONFLUÊNCIA ===
input group "=== SISTEMA DE FILTROS ==="
input bool RequirePerfectMTF = true;               // H4+H1+M30 alinhados
input bool AllowGoodSetups = true;                 // Aceitar H4+H1 apenas
input int MinFilterScore = 2;                      // Mínimo filtros ativos
input bool StrictCurrencyStrength = false;         // CS mais rigoroso

// === GESTÃO DE RISCO ===
input group "=== GESTÃO DE RISCO ==="
input bool UseStructureBasedSL = true;             // SL baseado em estrutura
input double SLBufferMultiplier = 1.0;             // Multiplicador buffer SL
input bool ValidateATRRange = true;                // Validar ATR ideal
input double MaxSLDistanceMultiplier = 1.5;        // Máx SL (× ideal máximo)

// === HORÁRIOS DE TRADING ===
input group "=== HORÁRIOS DE TRADING ==="
input bool RespectPrimeHours = true;               // Só operar horários prime
input int CustomPrimeStart = -1;                   // Início customizado (-1=auto)
input int CustomPrimeEnd = -1;                     // Fim customizado (-1=auto)
input bool AvoidNews = true;                       // Evitar 30min antes notícias
input bool WeekendClose = true;                    // Fechar antes fim de semana

// === SAÍDAS E TRAILING ===
input group "=== GESTÃO DE SAÍDAS ==="
input bool UseHybridExits = true;                  // TP1+TP2+Trailing
input double TP1Ratio = 1.0;                       // TP1 RR (1:1)
input double TP2Ratio = 2.0;                       // TP2 RR (1:2)
input double TrailingDistanceMultiplier = 1.0;     // Multiplicador trailing
input bool MoveToBreakeven = true;                 // Mover SL para BE após TP1

// === LOGS E ALERTAS ===
input group "=== SISTEMA DE LOGS ==="
input bool EnableDetailedLogs = true;              // Logs detalhados
input bool SendAlerts = true;                      // Alertas push
input bool SendEmails = false;                     // Alertas email
input bool EnableStatistics = true;                // Coleta estatísticas
```

---

## 🔍 VALIDAÇÕES E FILTROS DE QUALIDADE

### **1. Validações Pré-Entrada**
```cpp
bool ValidateMarketConditions(string symbol) {
    // ✅ Verificar spread não alargado
    // ✅ Validar ATR dentro do range ideal
    // ✅ Confirmar liquidez adequada
    // ✅ Checar se não há notícias em 30min
    // ✅ Validar horário de trading ativo
    // ✅ Verificar margem disponível (B3)
}
```

### **2. Validações de Estrutura**
```cpp
bool ValidateMarketStructure(string symbol, bool isBuy) {
    // ✅ H4: Sequência topos/fundos correta
    // ✅ Espaço adequado até próximo S/R
    // ✅ Preço posicionado corretamente vs EMA
    // ✅ Último topo/fundo claramente identificável
}
```

### **3. Sistema de Proteções**
```cpp
class ProtectionSystem {
    // ✅ Máximo trades por dia/hora
    // ✅ Drawdown máximo permitido  
    // ✅ Validação de conexão servidor
    // ✅ Proteção contra slippage excessivo
    // ✅ Verificação de margem contínua
};
```

---

## 📈 SISTEMA DE MONITORAMENTO E ESTATÍSTICAS

### **Métricas Coletadas Automaticamente**
```cpp
struct Statistics {
    // Performance Geral
    int totalTrades;
    int winningTrades;
    int losingTrades;
    double winRate;
    double averageRR;
    double profitFactor;
    
    // Por Classificação
    int premiumTrades;
    double premiumWinRate;
    int goodTrades;
    double goodWinRate;
    
    // Por Ativo
    map<string, AssetStats> assetPerformance;
    
    // Por Horário
    map<int, HourlyStats> hourlyPerformance;
    
    // Disciplina
    int rulesFollowed;
    int rulesViolated;
};
```

---

## 🚀 CRONOGRAMA DE DESENVOLVIMENTO

### **FASE 1 - FUNDAÇÃO (Semanas 1-2)**
- Estrutura base do EA
- Sistema de classificação de ativos
- Implementação dos 4 indicadores
- Sistema multi-timeframe básico

### **FASE 2 - LÓGICA PRINCIPAL (Semanas 3-4)**
- Sistema de pontuação adaptável
- Gestão de risco baseada em estrutura
- Horários globais sincronizados
- Validações de qualidade

### **FASE 3 - GESTÃO AVANÇADA (Semanas 5-6)**
- Gestão híbrida de saídas
- Sistema de proteções
- Monitoramento e estatísticas
- Interface de configuração

### **FASE 4 - TESTES E OTIMIZAÇÃO (Semanas 7-8)**
- Backtests extensivos
- Otimização de performance
- Validação em demo
- Documentação final

---

## ⚠️ CONSIDERAÇÕES CRÍTICAS

### **PRIORIDADES ABSOLUTAS**
1. **NUNCA violar gestão de risco** - SL é sagrado
2. **SEGUIR sistema 100%** - sem exceções ou "melhorias"
3. **QUALIDADE > QUANTIDADE** - aguardar setups perfeitos
4. **LOGS DETALHADOS** - rastreabilidade total
5. **VALIDAÇÕES RIGOROSAS** - multiple fail-safes

### **ADAPTAÇÕES INTELIGENTES**
- Detecção automática de tipo de ativo
- Configurações dinâmicas por classe
- Horários adaptativos por mercado
- Gestão de risco proporcional

### **PERFORMANCE E ROBUSTEZ**
- Código otimizado (execução < 100ms)
- Tratamento de erros completo
- Reconexão automática
- Backup de configurações

---

## 📋 CHECKLIST DE ENTREGA

### **ARQUIVOS OBRIGATÓRIOS**
- [ ] `NexusConfluenceEA.mq5` - EA principal
- [ ] `TraderMagic.mq5` - Indicador (se necessário)
- [ ] `CurrencyStrength.mq5` - Indicador (se necessário)  
- [ ] `RSIOMA.mq5` - Indicador (se necessário)
- [ ] `WAE.mq5` - Indicador (se necessário)
- [ ] `ManualTecnico.pdf` - Documentação completa
- [ ] `ConfiguracaoIndicadores.txt` - Guia setup
- [ ] `ExemplosConfiguracao.txt` - Configs por ativo

### **TESTES OBRIGATÓRIOS**
- [ ] Backtest 2 anos dados históricos
- [ ] Teste demo 30 dias mínimo
- [ ] Validação em múltiplos ativos
- [ ] Teste de estresse (alta volatilidade)
- [ ] Verificação conformidade regras

### **DOCUMENTAÇÃO FINAL**
- [ ] Manual de instalação step-by-step
- [ ] Explicação de todos os parâmetros
- [ ] Troubleshooting comum
- [ ] Exemplos de configuração
- [ ] FAQ técnico

---

## 🎯 RESULTADO ESPERADO

Um Expert Advisor completo, profissional e robusto que:

✅ **Implementa fielmente** o Sistema v4.0  
✅ **Adapta-se automaticamente** a qualquer ativo  
✅ **Respeita rigorosamente** a gestão de risco  
✅ **Opera apenas setups de qualidade** Premium/Bom  
✅ **Monitora performance** continuamente  
✅ **É totalmente configurável** pelo usuário  
✅ **Documenta tudo** para auditoria  
✅ **É escalável** do micro ao profissional  

**Este EA deve ser uma ferramenta profissional capaz de executar o sistema universal com precisão, disciplina e consistência que supere a capacidade humana de execução manual.**

---

*"Um sistema mediano executado perfeitamente supera um sistema perfeito executado medianamente."*

**O EA Nexus Confluence v4.0 deve ser a execução perfeita do Sistema Universal.**