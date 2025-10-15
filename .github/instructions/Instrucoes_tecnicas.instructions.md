---
applyTo: '**'
---
# 🔧 INSTRUÇÕES TÉCNICAS - DESENVOLVIMENTO EA NEXUS CONFLUENCE MT5

## 📋 INSTRUÇÕES PARA O DESENVOLVEDOR

### **OBJETIVO**
Desenvolver um Expert Advisor profissional em MQL5 que execute automaticamente o Sistema de Trading Universal v4.0, com capacidade de adaptação automática para múltiplas classes de ativos e gestão de risco baseada em estrutura de preços.

---

## 🏗️ ARQUITETURA DO SISTEMA

### **1. ESTRUTURA MODULAR OBRIGATÓRIA**

```cpp
// Arquivo principal: NexusConfluenceEA.mq5
// Estrutura modular para manutenibilidade

// === CLASSES PRINCIPAIS ===
class CAssetManager;      // Gerencia classificação e configuração de ativos
class CIndicatorManager;  // Gerencia todos os indicadores
class CTimeFrameAnalyzer; // Análise multi-timeframe
class CRiskManager;       // Gestão de risco e cálculo posições
class CTradeManager;      // Execução e gestão de trades
class CHoursManager;      // Controle de horários globais
class CStatistics;        // Coleta e análise de performance
class CProtectionSystem;  // Validações e proteções
```

### **2. FLUXO DE EXECUÇÃO PRINCIPAL**

```cpp
int OnTick() {
    // 1. Validações básicas de segurança
    if (!ValidateBasicConditions()) return 0;
    
    // 2. Classificar ativo atual  
    ASSET_CLASS assetType = assetManager.ClassifyAsset(_Symbol);
    
    // 3. Verificar se está em horário de trading
    if (!hoursManager.IsValidTradingTime(assetType)) return 0;
    
    // 4. Análise multi-timeframe obrigatória
    MultiTFResult mtfResult = tfAnalyzer.AnalyzeTimeframes(_Symbol);
    if (!mtfResult.isValid) return 0;
    
    // 5. Verificar sinais dos indicadores
    SignalResult signals = indicatorManager.GetAllSignals(_Symbol, assetType);
    
    // 6. Sistema de pontuação e classificação
    SetupClassification setup = CalculateSetupScore(signals, assetType);
    if (setup.quality == REJECT) return 0;
    
    // 7. Validações de qualidade de mercado
    if (!protectionSystem.ValidateMarketConditions(_Symbol)) return 0;
    
    // 8. Gestão de risco e cálculo de posição
    RiskCalculation risk = riskManager.CalculatePosition(_Symbol, setup);
    if (!risk.isValid) return 0;
    
    // 9. Execução do trade
    if (setup.quality >= GOOD) {
        tradeManager.ExecuteTrade(_Symbol, setup.direction, risk);
    }
    
    // 10. Gestão de trades existentes
    tradeManager.ManageExistingTrades();
    
    return 1;
}
```

---

## 📊 IMPLEMENTAÇÃO DOS INDICADORES

### **A) TRADER MAGIC - INDICADOR PRINCIPAL**

```cpp
class CTraderMagic {
private:
    int handle_tm_h4, handle_tm_h1, handle_tm_m30, handle_tm_m15;
    
public:
    bool Initialize(string symbol) {
        // Inicializar handles para todos os timeframes
        handle_tm_h4 = iCustom(symbol, PERIOD_H4, "TrendMagic_MT5");
        handle_tm_h1 = iCustom(symbol, PERIOD_H1, "TrendMagic_MT5");
        handle_tm_m30 = iCustom(symbol, PERIOD_M30, "TrendMagic_MT5");
        handle_tm_m15 = iCustom(symbol, PERIOD_M15, "TrendMagic_MT5");
    }
    
    TMSignal GetSignal(string symbol, ENUM_TIMEFRAMES timeframe) {
        TMSignal result;
        
        // Buffer 0 = Linha principal (cor determina direção)
        // Verde/Azul = Alta, Vermelho = Baixa
        
        double tm_current[3], tm_previous[3];
        int handle = GetHandle(timeframe);
        
        if (CopyBuffer(handle, 0, 0, 3, tm_current) != 3) {
            result.isValid = false;
            return result;
        }
        
        // Detectar mudança de cor confirmada por 2 candles
        bool isGreen = (tm_current[0] > 0); // Assumindo buffer positivo = verde
        bool wasRed = (tm_previous[2] < 0);  // Buffer negativo = vermelho
        
        // Para BUY: Mudou de vermelho para verde e manteve
        if (isGreen && wasRed && tm_current[1] > 0) {
            result.direction = BUY;
            result.isValid = true;
            result.strength = MathAbs(tm_current[0]);
        }
        // Para SELL: Mudou de verde para vermelho e manteve  
        else if (!isGreen && !wasRed && tm_current[1] < 0) {
            result.direction = SELL;
            result.isValid = true;
            result.strength = MathAbs(tm_current[0]);
        }
        
        return result;
    }
};
```

### **B) CURRENCY STRENGTH METER**

```cpp
class CCurrencyStrength {
private:
    int handle_cs;
    
public:
    bool IsApplicable(ASSET_CLASS assetType) {
        // Aplicável apenas para: Forex, WDO, Metais
        return (assetType == FOREX_MAJOR || 
                assetType == FOREX_MINOR || 
                assetType == FOREX_EXOTIC ||
                assetType == CURRENCY_B3 || 
                assetType == METALS);
    }
    
    CSSignal GetSignal(string symbol, bool isBuy, ASSET_CLASS assetType) {
        CSSignal result;
        
        if (!IsApplicable(assetType)) {
            result.isValid = false;
            return result;
        }
        
        // Extrair moedas base e cotação
        string baseCurrency = StringSubstr(symbol, 0, 3);
        string quoteCurrency = StringSubstr(symbol, 3, 3);
        
        double baseStrength = GetCurrencyStrength(baseCurrency);
        double quoteStrength = GetCurrencyStrength(quoteCurrency);
        
        // Para metais: interpretação INVERSA
        if (assetType == METALS) {
            // Ouro sobe quando USD fraco
            if (isBuy) result.isAligned = (quoteStrength < baseStrength); // USD fraco
            else result.isAligned = (quoteStrength > baseStrength);       // USD forte
        }
        else {
            // Forex normal: moeda base forte vs cotação fraca
            if (isBuy) result.isAligned = (baseStrength > quoteStrength);
            else result.isAligned = (baseStrength < quoteStrength);
        }
        
        result.isValid = true;
        result.strength = MathAbs(baseStrength - quoteStrength);
        
        return result;
    }
};
```

### **C) RSI OMA (RSI com Inclinação)**

```cpp
class CRSIOMA {
private:
    int handle_rsi;
    
public:
    RSISignal GetSignal(string symbol, ENUM_TIMEFRAMES timeframe, bool isBuy) {
        RSISignal result;
        
        double rsi_red[3], rsi_blue[3];
        
        // Buffer 0 = Linha vermelha, Buffer 1 = Linha azul
        if (CopyBuffer(handle_rsi, 0, 0, 3, rsi_red) != 3 ||
            CopyBuffer(handle_rsi, 1, 0, 3, rsi_blue) != 3) {
            result.isValid = false;
            return result;
        }
        
        // Verificar posição das linhas
        bool redAboveBlue = (rsi_red[0] > rsi_blue[0]);
        
        // Verificar inclinação (últimos 3 candles)
        double redSlope = (rsi_red[0] - rsi_red[2]) / 2.0;
        
        if (isBuy) {
            // Para compra: vermelha acima da azul + inclinação positiva
            result.isAligned = redAboveBlue && (redSlope > 0.1);
        }
        else {
            // Para venda: vermelha abaixo da azul + inclinação negativa  
            result.isAligned = !redAboveBlue && (redSlope < -0.1);
        }
        
        result.isValid = true;
        result.strength = MathAbs(rsi_red[0] - rsi_blue[0]);
        result.slope = redSlope;
        
        return result;
    }
};
```

### **D) WAE (WADDAH ATTAR EXPLOSION)**

```cpp
class CWAE {
private:
    int handle_wae;
    
public:
    WAESignal GetSignal(string symbol, ENUM_TIMEFRAMES timeframe, bool isBuy) {
        WAESignal result;
        
        double wae_main[3], wae_explosion[3];
        
        // Buffer 0 = Histograma principal, Buffer 1 = Linha explosão
        if (CopyBuffer(handle_wae, 0, 0, 3, wae_main) != 3 ||
            CopyBuffer(handle_wae, 1, 0, 3, wae_explosion) != 3) {
            result.isValid = false;
            return result;
        }
        
        // Verificar cor do histograma (positivo = verde, negativo = vermelho)
        bool isGreen = (wae_main[0] > 0);
        
        // Verificar se está expandindo
        bool isExpanding = (MathAbs(wae_main[0]) > MathAbs(wae_main[1]) &&
                           MathAbs(wae_main[1]) > MathAbs(wae_main[2]));
        
        // Verificar força mínima
        double minForce = 10.0; // Ajustar conforme ativo
        bool hasStrength = (MathAbs(wae_main[0]) > minForce);
        
        if (isBuy) {
            result.isAligned = isGreen && isExpanding && hasStrength;
        }
        else {
            result.isAligned = !isGreen && isExpanding && hasStrength;
        }
        
        result.isValid = true;
        result.strength = MathAbs(wae_main[0]);
        result.isExpanding = isExpanding;
        
        return result;
    }
};
```

---

## 🎯 SISTEMA DE PONTUAÇÃO ADAPTÁVEL

```cpp
class CSetupScorer {
public:
    SetupScore CalculateScore(string symbol, ASSET_CLASS assetType, bool isBuy) {
        SetupScore score;
        
        // 1. Trader Magic é OBRIGATÓRIO
        TMSignal tm = traderMagic.GetSignal(symbol, PERIOD_M15);
        if (!tm.isValid || tm.direction != (isBuy ? BUY : SELL)) {
            score.classification = REJECT;
            return score;
        }
        score.traderMagicPoints = 1;
        
        // 2. Filtros secundários conforme tipo de ativo
        switch (assetType) {
            case FOREX_MAJOR:
            case FOREX_MINOR: 
            case FOREX_EXOTIC:
            case CURRENCY_B3:
            case METALS:
                // Usar 3 filtros: CS + RSI + WAE (precisa 2 de 3)
                score = ScoreForexType(symbol, assetType, isBuy);
                break;
                
            case INDEX_US:
            case INDEX_EU:
            case INDEX_B3:
                // Usar 2 filtros: RSI + WAE (precisa 2 de 2) 
                score = ScoreIndexType(symbol, assetType, isBuy);
                break;
        }
        
        return score;
    }
    
private:
    SetupScore ScoreForexType(string symbol, ASSET_CLASS assetType, bool isBuy) {
        SetupScore score;
        score.requiredPoints = 2; // Precisa 2 de 3
        
        // Currency Strength
        CSSignal cs = currencyStrength.GetSignal(symbol, isBuy, assetType);
        if (cs.isValid && cs.isAligned) score.currencyStrengthPoints = 1;
        
        // RSI OMA
        RSISignal rsi = rsiOMA.GetSignal(symbol, PERIOD_M15, isBuy);
        if (rsi.isValid && rsi.isAligned) score.rsiomaPoints = 1;
        
        // WAE
        WAESignal wae = waeIndicator.GetSignal(symbol, PERIOD_M15, isBuy);
        if (wae.isValid && wae.isAligned) score.waePoints = 1;
        
        score.totalPoints = score.currencyStrengthPoints + score.rsiomaPoints + score.waePoints;
        
        // Classificação
        if (score.totalPoints >= 3) score.classification = PREMIUM;
        else if (score.totalPoints >= 2) score.classification = GOOD;  
        else score.classification = REJECT;
        
        return score;
    }
    
    SetupScore ScoreIndexType(string symbol, ASSET_CLASS assetType, bool isBuy) {
        SetupScore score;
        score.requiredPoints = 2; // Precisa 2 de 2
        
        // RSI OMA
        RSISignal rsi = rsiOMA.GetSignal(symbol, PERIOD_M15, isBuy);
        if (rsi.isValid && rsi.isAligned) score.rsiomaPoints = 1;
        
        // WAE  
        WAESignal wae = waeIndicator.GetSignal(symbol, PERIOD_M15, isBuy);
        if (wae.isValid && wae.isAligned) score.waePoints = 1;
        
        score.totalPoints = score.rsiomaPoints + score.waePoints;
        
        // Classificação (mais rigorosa para índices)
        if (score.totalPoints >= 2) score.classification = PREMIUM;
        else score.classification = REJECT;
        
        return score;
    }
};
```

---

## 🕐 GESTÃO DE HORÁRIOS GLOBAIS

```cpp
class CHoursManager {
private:
    struct TimeWindow {
        int startHour;
        int startMinute;
        int endHour;
        int endMinute;
        int quality; // 1-5
    };
    
public:
    bool IsValidTradingTime(ASSET_CLASS assetType) {
        datetime currentTime = TimeLocal();
        MqlDateTime dt;
        TimeToStruct(currentTime, dt);
        
        int currentHourBR = ConvertToBrazilTime(dt);
        
        switch (assetType) {
            case FOREX_MAJOR:
            case FOREX_MINOR:
            case FOREX_EXOTIC:
                return IsForexTradingTime(currentHourBR);
                
            case INDEX_B3:
            case CURRENCY_B3:
                return IsB3TradingTime(currentHourBR);
                
            case INDEX_US:
                return IsUSIndexTradingTime(currentHourBR);
                
            case METALS:
                return IsMetalsTradingTime(currentHourBR);
                
            default:
                return false;
        }
    }
    
private:
    bool IsForexTradingTime(int hourBR) {
        // Horário prime: 10:00-14:00 BR (overlap Londres/NY)
        if (hourBR >= 1000 && hourBR <= 1400) return true;
        
        // Horário bom: 05:00-09:00 BR (Londres pura)
        if (EnableSecondaryHours && hourBR >= 500 && hourBR < 1000) return true;
        
        return false;
    }
    
    bool IsB3TradingTime(int hourBR) {
        // Pregão: 09:00-18:00, mas melhor: 14:00-16:00
        if (hourBR < 900 || hourBR > 1800) return false; // Fora do pregão
        if (hourBR < 930) return false;  // Evitar primeiros 30min
        if (hourBR > 1730) return false; // Evitar últimos 30min
        
        // Período prime
        if (hourBR >= 1400 && hourBR <= 1600) return true;
        
        // Manhã aceitável
        if (EnableMorningB3 && hourBR >= 930 && hourBR <= 1130) return true;
        
        return false;
    }
    
    bool IsUSIndexTradingTime(int hourBR) {
        // Abertura NY: 11:30-18:00 BR (considerando horário de verão)
        if (hourBR >= 1130 && hourBR <= 1800) return true;
        
        return false;
    }
    
    bool IsMetalsTradingTime(int hourBR) {
        // Londres: 05:00-09:00 BR
        if (hourBR >= 500 && hourBR <= 900) return true;
        
        // Overlap: 10:00-14:00 BR  
        if (hourBR >= 1000 && hourBR <= 1400) return true;
        
        return false;
    }
    
    int ConvertToBrazilTime(MqlDateTime &dt) {
        // Converter horário local/servidor para Brasil (GMT-3)
        // Considerar diferença de fuso horário do broker
        int localHour = dt.hour;
        int localMin = dt.min;
        
        // Se broker está na Europa (GMT+2/+3), ajustar
        int brazilHour = localHour - BROKER_GMT_OFFSET + 3;
        if (brazilHour < 0) brazilHour += 24;
        if (brazilHour >= 24) brazilHour -= 24;
        
        return brazilHour * 100 + localMin;
    }
};
```

---

## 💰 GESTÃO DE RISCO BASEADA EM ESTRUTURA

```cpp
class CRiskManager {
public:
    RiskCalculation CalculatePosition(string symbol, SetupClassification setup) {
        RiskCalculation result;
        
        ASSET_CLASS assetType = assetManager.ClassifyAsset(symbol);
        
        // 1. Identificar último topo/fundo
        double slLevel = FindStructureSL(symbol, setup.direction);
        if (slLevel == 0) {
            result.isValid = false;
            return result;
        }
        
        // 2. Calcular distância SL
        double currentPrice = (setup.direction == BUY) ? 
            SymbolInfoDouble(symbol, SYMBOL_ASK) :
            SymbolInfoDouble(symbol, SYMBOL_BID);
            
        double slDistance = MathAbs(currentPrice - slLevel);
        
        // 3. Validar se SL está dentro do range ideal
        AssetConfig config = GetAssetConfig(assetType);
        if (slDistance < config.idealSLMin || slDistance > config.idealSLMax) {
            result.isValid = false;
            result.errorMessage = "SL fora do range ideal";
            return result;
        }
        
        // 4. Calcular tamanho da posição
        double riskPercent = GetRiskPercent(setup.classification);
        double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        double riskAmount = accountBalance * riskPercent / 100.0;
        
        double pipValue = GetPipValue(symbol);
        double riskPerLot = slDistance * pipValue;
        
        double positionSize = riskAmount / riskPerLot;
        
        // 5. Para B3: Validar margem
        if (assetType == INDEX_B3 || assetType == CURRENCY_B3) {
            if (!ValidateB3Margin(symbol, positionSize)) {
                result.isValid = false;
                result.errorMessage = "Margem insuficiente para B3";
                return result;
            }
        }
        
        // 6. Arredondar posição conforme especificações do ativo
        positionSize = NormalizePositionSize(symbol, positionSize);
        
        result.entryPrice = currentPrice;
        result.stopLoss = slLevel;
        result.slDistance = slDistance;
        result.positionSize = positionSize;
        result.riskAmount = riskAmount;
        result.isValid = true;
        
        // 7. Calcular TPs
        CalculateTakeProfits(result, setup.direction);
        
        return result;
    }
    
private:
    double FindStructureSL(string symbol, TRADE_DIRECTION direction) {
        // Procurar último topo/fundo significativo no M15
        double high[], low[];
        
        if (CopyHigh(symbol, PERIOD_M15, 1, 50, high) != 50 ||
            CopyLow(symbol, PERIOD_M15, 1, 50, low) != 50) {
            return 0;
        }
        
        if (direction == BUY) {
            // Procurar último fundo significativo
            return FindLastSignificantLow(low);
        }
        else {
            // Procurar último topo significativo  
            return FindLastSignificantHigh(high);
        }
    }
    
    double FindLastSignificantLow(double &low[]) {
        // Algoritmo para identificar último fundo com pelo menos
        // 3 candles de confirmação após o fundo
        for (int i = 3; i < ArraySize(low) - 3; i++) {
            bool isLow = true;
            
            // Verificar se é mínimo local
            for (int j = i - 2; j <= i + 2; j++) {
                if (j != i && low[j] <= low[i]) {
                    isLow = false;
                    break;
                }
            }
            
            if (isLow) {
                // Adicionar buffer de segurança
                AssetConfig config = GetAssetConfig(assetManager.ClassifyAsset(_Symbol));
                return low[i] - config.slBuffer * _Point;
            }
        }
        
        return 0; // Não encontrou
    }
    
    bool ValidateB3Margin(string symbol, double lots) {
        double marginRequired = 0;
        
        // Calcular margem necessária
        if (!OrderCalcMargin(ORDER_TYPE_BUY, symbol, lots, 
                            SymbolInfoDouble(symbol, SYMBOL_ASK), marginRequired)) {
            return false;
        }
        
        double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
        double safetyMargin = AccountInfoDouble(ACCOUNT_BALANCE) * 0.3; // 30% segurança
        
        return (freeMargin - marginRequired) > safetyMargin;
    }
    
    double GetRiskPercent(SETUP_CLASSIFICATION classification) {
        switch (classification) {
            case PREMIUM: return MaxRiskPremium;     // 2% max
            case GOOD:    return AccountRiskPercent; // 1.5% default  
            default:      return 0;
        }
    }
};
```

---

## 🎯 GESTÃO DE TRADES E SAÍDAS

```cpp
class CTradeManager {
private:
    struct ActiveTrade {
        ulong ticket;
        double entryPrice;
        double stopLoss;
        double tp1Level;
        double tp2Level;  
        double trailingDistance;
        bool tp1Hit;
        bool tp2Hit;
        bool trailingActive;
        datetime entryTime;
        SETUP_CLASSIFICATION setupClass;
    };
    
    ActiveTrade activeTrades[];
    
public:
    bool ExecuteTrade(string symbol, TRADE_DIRECTION direction, RiskCalculation risk) {
        MqlTradeRequest request;
        MqlTradeResult result;
        
        ZeroMemory(request);
        
        // Configurar ordem
        request.action = TRADE_ACTION_DEAL;
        request.symbol = symbol;
        request.volume = risk.positionSize;
        request.type = (direction == BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
        request.price = (direction == BUY) ? 
            SymbolInfoDouble(symbol, SYMBOL_ASK) :
            SymbolInfoDouble(symbol, SYMBOL_BID);
        request.sl = risk.stopLoss;
        request.tp = 0; // Não usar TP automático, gestão manual
        request.deviation = 10;
        request.magic = EA_MAGIC_NUMBER;
        request.comment = StringFormat("Nexus_%s_%s", 
            direction == BUY ? "BUY" : "SELL",
            EnumToString(risk.setupClass));
        
        if (!OrderSend(request, result)) {
            Print("Erro ao abrir trade: ", result.retcode, " - ", result.comment);
            return false;
        }
        
        // Registrar trade para gestão
        RegisterActiveTrade(result.deal, risk);
        
        // Log detalhado
        LogTradeExecution(symbol, direction, risk, result);
        
        // Alertas
        if (SendAlerts) {
            SendNotification(StringFormat("Nexus: %s %s aberto em %.5f", 
                direction == BUY ? "COMPRA" : "VENDA", symbol, request.price));
        }
        
        return true;
    }
    
    void ManageExistingTrades() {
        for (int i = ArraySize(activeTrades) - 1; i >= 0; i--) {
            ManageSingleTrade(activeTrades[i]);
        }
    }
    
private:
    void ManageSingleTrade(ActiveTrade &trade) {
        if (!PositionSelectByTicket(trade.ticket)) {
            // Trade fechado, remover da lista
            RemoveFromActiveTrades(trade.ticket);
            return;
        }
        
        double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
        double openPrice = trade.entryPrice;
        bool isLong = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
        
        // Verificar TPs
        if (!trade.tp1Hit) {
            if (CheckTP1Hit(currentPrice, trade, isLong)) {
                ExecutePartialClose(trade, 0.5); // Fechar 50%
                MoveToBreakeven(trade);
                trade.tp1Hit = true;
                
                LogTakeProfit(trade, "TP1", currentPrice);
            }
        }
        else if (!trade.tp2Hit) {
            if (CheckTP2Hit(currentPrice, trade, isLong)) {
                ExecutePartialClose(trade, 0.5); // Fechar mais 25% (50% do restante)
                ActivateTrailing(trade);
                trade.tp2Hit = true;
                
                LogTakeProfit(trade, "TP2", currentPrice);
            }
        }
        else if (trade.trailingActive) {
            UpdateTrailingStop(trade, currentPrice, isLong);
        }
        
        // Verificar sinais de saída antecipada
        if (CheckEarlyExitSignals(trade)) {
            ClosePosition(trade.ticket, "Sinal de saída antecipada");
            RemoveFromActiveTrades(trade.ticket);
        }
    }
    
    bool CheckTP1Hit(double currentPrice, ActiveTrade &trade, bool isLong) {
        if (isLong) {
            return currentPrice >= trade.tp1Level;
        } else {
            return currentPrice <= trade.tp1Level;
        }
    }
    
    void MoveToBreakeven(ActiveTrade &trade) {
        MqlTradeRequest request;
        MqlTradeResult result;
        
        ZeroMemory(request);
        request.action = TRADE_ACTION_SLTP;
        request.position = trade.ticket;
        request.sl = trade.entryPrice; // Breakeven
        request.tp = 0;
        
        if (!OrderSend(request, result)) {
            Print("Erro ao mover para breakeven: ", result.retcode);
        } else {
            trade.stopLoss = trade.entryPrice;
            Print("SL movido para breakeven: ", trade.entryPrice);
        }
    }
    
    void ActivateTrailing(ActiveTrade &trade) {
        trade.trailingActive = true;
        
        // Calcular distância trailing baseada no ativo
        ASSET_CLASS assetType = assetManager.ClassifyAsset(PositionGetString(POSITION_SYMBOL));
        AssetConfig config = GetAssetConfig(assetType);
        
        // Distância padrão por tipo de ativo
        if (assetType == FOREX_MAJOR || assetType == FOREX_MINOR) {
            trade.trailingDistance = 25 * _Point; // 25 pips
        }
        else if (assetType == INDEX_B3) {
            trade.trailingDistance = 300 * _Point; // 300 pontos WIN
        }
        else if (assetType == CURRENCY_B3) {
            trade.trailingDistance = 25 * _Point; // 25 pontos WDO
        }
        else if (assetType == METALS) {
            trade.trailingDistance = 10 * _Point; // $10 ouro
        }
        
        // Ajustar conforme multiplicador configurado
        trade.trailingDistance *= TrailingDistanceMultiplier;
    }
    
    void UpdateTrailingStop(ActiveTrade &trade, double currentPrice, bool isLong) {
        double newSL;
        
        if (isLong) {
            newSL = currentPrice - trade.trailingDistance;
            // Só move SL para cima
            if (newSL > trade.stopLoss) {
                ModifyStopLoss(trade.ticket, newSL);
                trade.stopLoss = newSL;
            }
        } else {
            newSL = currentPrice + trade.trailingDistance;
            // Só move SL para baixo (em valor absoluto)
            if (newSL < trade.stopLoss) {
                ModifyStopLoss(trade.ticket, newSL);
                trade.stopLoss = newSL;
            }
        }
    }
    
    bool CheckEarlyExitSignals(ActiveTrade &trade) {
        string symbol = PositionGetString(POSITION_SYMBOL);
        bool isLong = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
        
        // 1. Verificar se H4 mudou de cor
        TMSignal tmH4 = traderMagic.GetSignal(symbol, PERIOD_H4);
        if (tmH4.isValid) {
            bool h4Bullish = (tmH4.direction == BUY);
            if (isLong && !h4Bullish) return true; // H4 virou baixista
            if (!isLong && h4Bullish) return true; // H4 virou altista
        }
        
        // 2. Verificar se Trader Magic M15 inverteu
        TMSignal tmM15 = traderMagic.GetSignal(symbol, PERIOD_M15);
        if (tmM15.isValid) {
            bool m15Bullish = (tmM15.direction == BUY);
            if (isLong && !m15Bullish) return true;
            if (!isLong && m15Bullish) return true;
        }
        
        // 3. Verificar final de sessão
        ASSET_CLASS assetType = assetManager.ClassifyAsset(symbol);
        if (!hoursManager.IsValidTradingTime(assetType)) {
            return true; // Fora do horário, fechar
        }
        
        // 4. Verificar véspera de fim de semana
        MqlDateTime dt;
        TimeToStruct(TimeLocal(), dt);
        if (dt.day_of_week == 5 && dt.hour >= 16) { // Sexta 16h+
            return true;
        }
        
        return false;
    }
};
```

---

## 📊 SISTEMA DE ESTATÍSTICAS E LOGS

```cpp
class CStatistics {
private:
    struct TradeRecord {
        datetime openTime;
        datetime closeTime;
        string symbol;
        TRADE_DIRECTION direction;
        double openPrice;
        double closePrice;
        double profit;
        double riskAmount;
        double rr; // Risk/Reward real
        SETUP_CLASSIFICATION setupClass;
        string closeReason;
        bool tp1Hit;
        bool tp2Hit;
    };
    
    TradeRecord tradeHistory[];
    
public:
    void RecordTrade(const TradeRecord &record) {
        int size = ArraySize(tradeHistory);
        ArrayResize(tradeHistory, size + 1);
        tradeHistory[size] = record;
        
        // Atualizar estatísticas em tempo real
        UpdateRealTimeStats();
        
        // Salvar em arquivo para persistência
        SaveTradeRecord(record);
    }
    
    void GenerateMonthlyReport() {
        string report = "=== RELATÓRIO MENSAL NEXUS CONFLUENCE ===\n\n";
        
        // Performance geral
        int totalTrades = ArraySize(tradeHistory);
        int winners = 0;
        double totalProfit = 0;
        double totalLoss = 0;
        
        for (int i = 0; i < totalTrades; i++) {
            if (tradeHistory[i].profit > 0) {
                winners++;
                totalProfit += tradeHistory[i].profit;
            } else {
                totalLoss += MathAbs(tradeHistory[i].profit);
            }
        }
        
        double winRate = (totalTrades > 0) ? (double)winners / totalTrades * 100.0 : 0;
        double profitFactor = (totalLoss > 0) ? totalProfit / totalLoss : 0;
        
        report += StringFormat("Trades total: %d\n", totalTrades);
        report += StringFormat("Win Rate: %.1f%%\n", winRate);
        report += StringFormat("Profit Factor: %.2f\n", profitFactor);
        report += StringFormat("Lucro líquido: %.2f\n", totalProfit - totalLoss);
        
        // Performance por classificação
        report += "\n=== POR CLASSIFICAÇÃO ===\n";
        AnalyzeByClassification(report);
        
        // Performance por ativo
        report += "\n=== POR ATIVO ===\n";
        AnalyzeByAsset(report);
        
        // Performance por horário
        report += "\n=== POR HORÁRIO ===\n";
        AnalyzeByHour(report);
        
        // Disciplina
        report += "\n=== DISCIPLINA ===\n";
        AnalyzeDiscipline(report);
        
        // Salvar relatório
        string filename = StringFormat("Nexus_Report_%s.txt", 
            TimeToString(TimeLocal(), TIME_DATE));
        SaveStringToFile(filename, report);
        
        Print("Relatório mensal gerado: ", filename);
    }
    
private:
    void AnalyzeByClassification(string &report) {
        int premiumTrades = 0, goodTrades = 0;
        int premiumWins = 0, goodWins = 0;
        
        for (int i = 0; i < ArraySize(tradeHistory); i++) {
            if (tradeHistory[i].setupClass == PREMIUM) {
                premiumTrades++;
                if (tradeHistory[i].profit > 0) premiumWins++;
            }
            else if (tradeHistory[i].setupClass == GOOD) {
                goodTrades++;
                if (tradeHistory[i].profit > 0) goodWins++;
            }
        }
        
        double premiumWR = (premiumTrades > 0) ? (double)premiumWins / premiumTrades * 100 : 0;
        double goodWR = (goodTrades > 0) ? (double)goodWins / goodTrades * 100 : 0;
        
        report += StringFormat("PREMIUM: %d trades, %.1f%% win rate\n", premiumTrades, premiumWR);
        report += StringFormat("GOOD: %d trades, %.1f%% win rate\n", goodTrades, goodWR);
    }
    
    void LogDetailedTrade(const TradeRecord &record) {
        string logEntry = StringFormat(
            "[%s] %s %s | Entry: %.5f | Exit: %.5f | P&L: %.2f | RR: 1:%.2f | Setup: %s | Reason: %s",
            TimeToString(record.openTime, TIME_DATE|TIME_MINUTES),
            record.symbol,
            EnumToString(record.direction),
            record.openPrice,
            record.closePrice,
            record.profit,
            record.rr,
            EnumToString(record.setupClass),
            record.closeReason
        );
        
        Print(logEntry);
        
        // Salvar em arquivo de log detalhado
        string filename = StringFormat("Nexus_Detailed_%s.log", 
            TimeToString(TimeLocal(), TIME_DATE));
        AppendStringToFile(filename, logEntry + "\n");
    }
};
```

---

## 🛡️ SISTEMA DE PROTEÇÕES

```cpp
class CProtectionSystem {
public:
    bool ValidateBasicConditions() {
        // 1. Verificar se trading está habilitado
        if (!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) {
            Print("Trading não permitido no terminal");
            return false;
        }
        
        // 2. Verificar conexão
        if (!TerminalInfoInteger(TERMINAL_CONNECTED)) {
            Print("Terminal desconectado");
            return false;
        }
        
        // 3. Verificar se é horário de mercado
        if (!IsMarketOpen()) {
            return false;
        }
        
        // 4. Verificar drawdown máximo
        if (CheckMaxDrawdown()) {
            Print("Drawdown máximo atingido - trading pausado");
            return false;
        }
        
        // 5. Verificar máximo de trades
        if (GetActiveTradesCount() >= MaxSimultaneousTrades) {
            return false;
        }
        
        return true;
    }
    
    bool ValidateMarketConditions(string symbol) {
        // 1. Verificar spread
        double spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD) * _Point;
        double maxSpread = GetMaxSpreadForAsset(symbol);
        
        if (spread > maxSpread) {
            Print("Spread muito alto: ", spread);
            return false;
        }
        
        // 2. Verificar ATR
        if (ValidateATRRange && !IsATRInRange(symbol)) {
            Print("ATR fora do range ideal");
            return false;
        }
        
        // 3. Verificar se não há notícias importantes
        if (AvoidNews && IsNewsTime()) {
            Print("Próximo de notícia importante");
            return false;
        }
        
        // 4. Verificar liquidez mínima
        if (!HasAdequateLiquidity(symbol)) {
            Print("Liquidez insuficiente");
            return false;
        }
        
        return true;
    }
    
private:
    bool CheckMaxDrawdown() {
        double equity = AccountInfoDouble(ACCOUNT_EQUITY);
        double balance = AccountInfoDouble(ACCOUNT_BALANCE);
        double initialBalance = GetInitialBalance(); // Salvar no OnInit
        
        double currentDrawdown = (initialBalance - equity) / initialBalance * 100.0;
        
        return currentDrawdown >= MAX_DRAWDOWN_PERCENT;
    }
    
    bool IsATRInRange(string symbol) {
        int atrHandle = iATR(symbol, PERIOD_M15, 14);
        double atr[1];
        
        if (CopyBuffer(atrHandle, 0, 0, 1, atr) != 1) return true; // Se erro, permite
        
        ASSET_CLASS assetType = assetManager.ClassifyAsset(symbol);
        AssetConfig config = GetAssetConfig(assetType);
        
        return (atr[0] >= config.minATR && atr[0] <= config.maxATR);
    }
    
    bool IsNewsTime() {
        // Implementar verificação de calendário econômico
        // Por simplicidade, pode usar horários fixos conhecidos
        MqlDateTime dt;
        TimeToStruct(TimeLocal(), dt);
        
        // Exemplo: NFP primeira sexta do mês às 15:30 BR
        if (dt.day_of_week == 5 && dt.hour == 15 && dt.min >= 0 && dt.min <= 60) {
            // Verificar se é primeira sexta
            if (dt.day <= 7) return true;
        }
        
        // Adicionar outros eventos importantes
        return false;
    }
};
```

---

## ⚙️ CONFIGURAÇÃO E INICIALIZAÇÃO

```cpp
// Parâmetros globais e inicialização
const int EA_MAGIC_NUMBER = 20241015; // Data criação
const string EA_VERSION = "4.0";
const string EA_NAME = "Nexus Confluence Universal";

// Instâncias globais das classes
CAssetManager *assetManager;
CIndicatorManager *indicatorManager;
CTimeFrameAnalyzer *tfAnalyzer;
CRiskManager *riskManager;
CTradeManager *tradeManager;
CHoursManager *hoursManager;
CStatistics *statistics;
CProtectionSystem *protectionSystem;

int OnInit() {
    Print("=== INICIANDO NEXUS CONFLUENCE EA v", EA_VERSION, " ===");
    
    // 1. Inicializar todas as classes
    assetManager = new CAssetManager();
    indicatorManager = new CIndicatorManager();
    tfAnalyzer = new CTimeFrameAnalyzer();
    riskManager = new CRiskManager();
    tradeManager = new CTradeManager();
    hoursManager = new CHoursManager();
    statistics = new CStatistics();
    protectionSystem = new CProtectionSystem();
    
    // 2. Validar parâmetros de entrada
    if (!ValidateInputParameters()) {
        Print("Parâmetros inválidos!");
        return INIT_PARAMETERS_INCORRECT;
    }
    
    // 3. Inicializar indicadores
    if (!indicatorManager.Initialize(_Symbol)) {
        Print("Erro ao inicializar indicadores!");
        return INIT_FAILED;
    }
    
    // 4. Configurar ativo atual
    ASSET_CLASS currentAsset = assetManager.ClassifyAsset(_Symbol);
    Print("Ativo classificado como: ", EnumToString(currentAsset));
    
    // 5. Validar se ativo é suportado
    if (!IsAssetEnabled(currentAsset)) {
        Print("Tipo de ativo não habilitado nas configurações");
        return INIT_FAILED;
    }
    
    // 6. Carregar configurações históricas
    statistics.LoadHistoricalData();
    
    // 7. Configurar timer para limpezas e relatórios
    EventSetTimer(3600); // A cada hora
    
    Print("EA inicializado com sucesso!");
    Print("Configurações ativas:");
    PrintConfiguration(currentAsset);
    
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
    Print("=== FINALIZANDO NEXUS CONFLUENCE EA ===");
    Print("Razão: ", reason);
    
    // Salvar estatísticas finais
    if (statistics != NULL) {
        statistics.SaveFinalReport();
        delete statistics;
    }
    
    // Limpar recursos
    if (indicatorManager != NULL) delete indicatorManager;
    if (assetManager != NULL) delete assetManager;
    if (tfAnalyzer != NULL) delete tfAnalyzer;
    if (riskManager != NULL) delete riskManager;
    if (tradeManager != NULL) delete tradeManager;
    if (hoursManager != NULL) delete hoursManager;
    if (protectionSystem != NULL) delete protectionSystem;
    
    EventKillTimer();
    
    Print("EA finalizado com segurança");
}

void OnTimer() {
    // Executado a cada hora
    
    // 1. Limpeza de logs antigos
    CleanupOldLogs();
    
    // 2. Verificar se é fim do mês para relatório
    static int lastMonth = -1;
    MqlDateTime dt;
    TimeToStruct(TimeLocal(), dt);
    
    if (dt.mon != lastMonth && lastMonth != -1) {
        statistics.GenerateMonthlyReport();
    }
    lastMonth = dt.mon;
    
    // 3. Validar integridade do sistema
    ValidateSystemIntegrity();
}
```

---

## 📝 DOCUMENTAÇÃO E COMENTÁRIOS

### **Padrão de Comentários Obrigatório**

```cpp
//+------------------------------------------------------------------+
//| Nexus Confluence EA v4.0 - Sistema Universal de Trading         |
//| Baseado no Sistema de Trading Profissional v4.0                 |
//|                                                                  |
//| Descrição: Expert Advisor completo que implementa sistema       |
//| multi-ativo com gestão de risco baseada em estrutura           |
//|                                                                  |
//| Autor: [Nome do Desenvolvedor]                                  |
//| Data: Outubro 2024                                             |
//| Versão: 4.0                                                    |
//+------------------------------------------------------------------+

/**
 * @brief Função principal de análise multi-timeframe
 * 
 * Verifica alinhamento obrigatório entre H4 e H1, com M30 como bônus.
 * Implementa a regra fundamental do sistema: H4+H1 devem estar alinhados.
 * 
 * @param symbol String do símbolo a ser analisado
 * @param direction Direção pretendida do trade (BUY/SELL)  
 * @return MultiTFResult Estrutura com resultado da análise
 * 
 * @note Esta função é CRÍTICA - sem alinhamento MTF, não há trade
 * @see Documentação Sistema v4.0, Seção 3.1
 */
MultiTFResult AnalyzeMultiTimeframes(string symbol, TRADE_DIRECTION direction) {
    // Implementação com comentários detalhados
}
```

### **Headers Obrigatórios em Cada Arquivo**

```cpp
//+------------------------------------------------------------------+
//| ARQUIVO: [Nome do arquivo]                                       |
//| PROPÓSITO: [Descrição concisa]                                   |
//| DEPENDÊNCIAS: [Lista de dependências]                            |
//| VERSÃO: 4.0                                                      |
//+------------------------------------------------------------------+
```

---

## 🧪 TESTES E VALIDAÇÃO

### **Protocolo de Testes Obrigatório**

1. **Teste Unitário de Cada Função**
   - Validar cada indicador individualmente
   - Testar cálculos de risco com diferentes cenários
   - Verificar classificação de ativos
   - Validar horários para diferentes fusos

2. **Teste de Integração**
   - Sistema completo em modo demo
   - Múltiplos ativos simultaneamente
   - Diferentes condições de mercado
   - Stress test com alta volatilidade

3. **Backtest Extensivo**
   - Mínimo 2 anos de dados históricos
   - Múltiplos pares/ativos
   - Validar métricas vs expectativas
   - Comparar com execução manual

4. **Validação de Conformidade**
   - Verificar se segue 100% as regras
   - Auditar cada decisão de entrada/saída
   - Confirmar gestão de risco correta
   - Validar horários e filtros

### **Critérios de Aceitação**

- ✅ **Win rate ≥ 50%** em backtest
- ✅ **Risk/Reward médio ≥ 1:1.3**
- ✅ **Profit Factor ≥ 1.5**
- ✅ **Drawdown máximo ≤ 15%**
- ✅ **100% conformidade** com regras
- ✅ **Zero violações** de gestão risco
- ✅ **Performance estável** em demo 30+ dias

---

## 🎯 ENTREGÁVEIS FINAIS

### **Pacote de Entrega Completo**

1. **Códigos Fonte**
   - `NexusConfluenceEA.mq5` - EA principal
   - Indicadores necessários (se customizados)
   - Arquivos de biblioteca (se aplicável)

2. **Documentação**
   - Manual de instalação step-by-step
   - Manual de configuração detalhado
   - Guia de troubleshooting
   - FAQ técnico

3. **Recursos de Suporte**
   - Templates de configuração por ativo
   - Planilha de cálculo de risco
   - Guia de backtest
   - Scripts de utilidade

4. **Validação**
   - Relatórios de backtest
   - Screenshots de funcionamento
   - Logs de teste em demo
   - Certificação de conformidade

---

## ⚠️ AVISOS CRÍTICOS PARA O DESENVOLVEDOR

### **NÃO NEGOCIÁVEIS**

1. **JAMAIS violar gestão de risco** - SL é sagrado
2. **SEGUIR sistema 100%** - zero interpretações pessoais  
3. **DOCUMENTAR tudo** - cada função, cada decisão
4. **TESTAR extensivamente** - não há pressa, há qualidade
5. **MANTER logs detalhados** - rastreabilidade total

### **PRIORIDADE ABSOLUTA**

1. **Robustez > Performance** - deve funcionar sempre
2. **Segurança > Lucro** - proteger capital é #1
3. **Qualidade > Velocidade** - prefira desenvolvimento mais lento mas correto
4. **Simplicidade > Complexidade** - código claro e mantível

---

# 📋 REQUISITOS TÉCNICOS EXTRAÍDOS - SISTEMA v4.0

## 🎯 ANÁLISE COMPLETA DA DOCUMENTAÇÃO

### **RESUMO EXECUTIVO**
Baseado na documentação completa do Sistema de Trading Profissional v4.0, foi extraída uma especificação técnica abrangente para desenvolvimento de um Expert Advisor universal que implementa todas as regras, filtros, gestão de risco e adaptações por classe de ativo.

---

## 🏗️ ARQUITETURA PRINCIPAL

### **1. FILTROS MACRO (Obrigatórios)**

#### **Multi-Timeframe Analysis**
- **H4 (4 horas)**: Timeframe diretor - define tendência principal
- **H1 (1 hora)**: Deve estar ALINHADO com H4 (mesma cor)
- **M30 (30 minutos)**: Desejável alinhamento (bônus para setup Premium)
- **M15 (15 minutos)**: Timeframe operacional para entrada

#### **Regras de Alinhamento**
```
✅ PREMIUM: H4 + H1 + M30 alinhados
✅ BOM: H4 + H1 alinhados (M30 pode diferir)
❌ REJEITADO: H4 e H1 com cores opostas
❌ AGUARDAR: H4 ou H1 em amarelo (indeciso)
```

#### **Análise de Estrutura H4**
- **Para COMPRA**: Sequência topos/fundos ascendentes + preço acima EMA 50
- **Para VENDA**: Sequência topos/fundos descendentes + preço abaixo EMA 50
- **Espaço mínimo até próximo S/R**: Varia por ativo (ver tabela)

---

### **2. FILTROS MICRO (Confluência Adaptável)**

#### **A) TRADER MAGIC (Principal - Obrigatório)**
- **Função**: Indicador de tendência com mudança de cor
- **Sinal BUY**: Mudou VERMELHO → VERDE/AZUL (mantido 2+ candles)
- **Sinal SELL**: Mudou VERDE/AZUL → VERMELHO (mantido 2+ candles)
- **Validação**: Aguardar 2º candle fechar antes de entrar

#### **B) CURRENCY STRENGTH METER (Aplicação Condicional)**
```
✅ USAR EM:
- Forex Majors: EUR/USD, GBP/USD, USD/JPY, AUD/USD
- Forex Minors: EUR/GBP, EUR/JPY, GBP/JPY, etc
- Forex Exóticos: USD/BRL, USD/MXN, USD/ZAR
- WDO (Mini Dólar B3): USD/BRL
- Metais: XAU/USD, XAG/USD (interpretação INVERSA)

❌ NÃO USAR EM:
- WIN (Mini Índice B3): É índice, não moeda
- S&P500, Nasdaq, DAX: São índices
- Qualquer índice de ações
```

#### **Interpretação por Ativo**
- **Forex Normal**: Moeda base forte > moeda cotação fraca
- **Metais (INVERSO)**: USD fraco = ouro forte, USD forte = ouro fraco
- **WDO**: USD forte vs BRL fraco (para compra WDO)

#### **C) RSI OMA (RSI com Inclinação)**
- **Aplicação**: Universal (todos os ativos)
- **Sinal BUY**: Linha vermelha acima azul + inclinação positiva
- **Sinal SELL**: Linha vermelha abaixo azul + inclinação negativa
- **Validação**: Inclinação deve ser clara (não oscilando)

#### **D) WAE (Waddah Attar Explosion)**
- **Aplicação**: Universal, mas CRÍTICO para índices
- **Sinal BUY**: Histograma verde + expandindo
- **Sinal SELL**: Histograma vermelho + expandindo
- **Força Mínima**: Barras devem ter amplitude significativa

---

### **3. SISTEMA DE PONTUAÇÃO ADAPTÁVEL**

#### **Matriz de Aplicação por Ativo**
```
╔═══════════════════════════════════════════════════╗
║  ATIVO TYPE        │ FILTROS    │ SISTEMA          ║
╠═══════════════════════════════════════════════════╣
║  Forex Majors      │ TM+CS+R+W  │ 2 de 3 (CS/R/W) ║
║  Forex Minors      │ TM+CS+R+W  │ 2 de 3 (CS/R/W) ║
║  Forex Exóticos    │ TM+CS+R+W  │ 2 de 3 (CS/R/W) ║
║  WDO (Mini Dólar)  │ TM+CS+R+W  │ 2 de 3 (CS/R/W) ║
║  Metais (Au/Ag)    │ TM+CS+R+W  │ 2 de 3 (CS/R/W) ║
║ ─────────────────────────────────────────────────── ║
║  WIN (Mini Índice) │ TM+R+W     │ 2 de 2 (R/W)    ║
║  S&P500           │ TM+R+W     │ 2 de 2 (R/W)    ║
║  Nasdaq           │ TM+R+W     │ 2 de 2 (R/W)    ║
║  DAX              │ TM+R+W     │ 2 de 2 (R/W)    ║
║  Índices (geral)   │ TM+R+W     │ 2 de 2 (R/W)    ║
╚═══════════════════════════════════════════════════╝

Legenda: TM=Trader Magic, CS=Currency Strength, R=RSI OMA, W=WAE
```

#### **Classificação de Setups**
```
🏆 PREMIUM (Máxima qualidade):
- Forex/Metais/WDO: 3/3 pontos (CS + RSI + WAE alinhados)
- Índices/WIN: 2/2 pontos (RSI + WAE alinhados)
- Risco permitido: até 2%

⭐ BOM (Boa qualidade):
- Forex/Metais/WDO: 2/3 pontos (2 dos 3 filtros)
- Índices/WIN: Não aplicável (precisa 2/2)
- Risco permitido: até 1.5%

❌ REJEITADO:
- Forex/Metais/WDO: 1/3 ou 0/3 pontos
- Índices/WIN: 1/2 ou 0/2 pontos
- Não operar
```

---

### **4. GESTÃO DE RISCO BASEADA EM ESTRUTURA**

#### **Metodologia de Stop Loss**
- **Princípio**: SL baseado em estrutura, NÃO em valores fixos
- **COMPRA**: SL abaixo do último fundo significativo M15 + buffer
- **VENDA**: SL acima do último topo significativo M15 + buffer

#### **Distâncias Ideais por Ativo**
```
╔══════════════════════════════════════════════════════╗
║  ATIVO                │ SL IDEAL      │ BUFFER       ║
╠══════════════════════════════════════════════════════╣
║  EUR/USD, USD/JPY     │ 20-40 pips    │ +5 pips      ║
║  GBP/USD, EUR/GBP     │ 25-45 pips    │ +7 pips      ║
║  USD/BRL (exóticos)   │ 40-80 pips    │ +10-15 pips  ║
║ ──────────────────────────────────────────────────── ║
║  S&P500               │ 10-25 pontos  │ +2-3 pontos  ║
║  Nasdaq               │ 30-60 pontos  │ +5-8 pontos  ║
║  DAX                  │ 20-50 pontos  │ +5 pontos    ║
║ ──────────────────────────────────────────────────── ║
║  WIN (Mini Índice)    │ 200-400 pontos│ +50 pontos   ║
║  WDO (Mini Dólar)     │ 15-30 pontos  │ +3-5 pontos  ║
║ ──────────────────────────────────────────────────── ║
║  XAU/USD (Ouro)       │ $5-15         │ +$1-2        ║
║  XAG/USD (Prata)      │ $0.15-0.40    │ +$0.05       ║
╚══════════════════════════════════════════════════════╝
```

#### **Cálculo de Tamanho de Posição**
```
Fórmula Universal:
Tamanho = (Capital × %Risco) ÷ (Distância_SL × Valor_por_pip)

Onde:
- Capital: Saldo da conta
- %Risco: 1.5% (BOM) ou 2% (PREMIUM)
- Distância_SL: Em pips/pontos até SL
- Valor_por_pip: Específico do ativo/lote
```

#### **Validações B3 (Críticas)**
```
WIN (Mini Índice):
- Valor por ponto: R$ 0,20
- Margem aproximada: R$ 2.000-4.000/contrato
- SEMPRE manter 50%+ capital livre
- Exemplo: Capital R$ 20.000 → máx 5 contratos

WDO (Mini Dólar):
- Valor por ponto: R$ 10,00
- Margem aproximada: R$ 1.500-3.000/contrato
- MUITO alavancado - máxima cautela
- Exemplo: Capital R$ 15.000 → máx 1-2 contratos
```

---

### **5. HORÁRIOS GLOBAIS SINCRONIZADOS**

#### **Conversão de Fusos Horários**
```
BROKER (EasyMarkets - Chipre):
- Inverno: GMT+2 (5h à frente do Brasil)
- Verão: GMT+3 (6h à frente do Brasil)

BRASIL: GMT-3 (sempre, sem horário de verão)

CONVERSÃO CRÍTICA:
- 10:00 BR = 15:00/16:00 Chipre (inv/ver)
- Usar horário Brasil como referência padrão
```

#### **Horários Prime por Ativo (Horário Brasil)**
```
╔═══════════════════════════════════════════════════════╗
║  CLASSE DE ATIVO      │ HORÁRIOS PRIME (BR)           ║
╠═══════════════════════════════════════════════════════╣
║  🌐 FOREX (todos)     │ 10:00-14:00 ⭐⭐⭐⭐⭐       ║
║                       │ Overlap Londres/NY (MELHOR)   ║
║                       │ 05:00-09:00 ⭐⭐⭐ (Londres)   ║
║ ───────────────────────────────────────────────────── ║
║  🇧🇷 B3 (WIN/WDO)    │ 14:00-16:00 ⭐⭐⭐⭐⭐       ║
║                       │ Overlap B3/NY (CRÍTICO!)     ║
║                       │ 09:30-11:30 ⭐⭐⭐ (manhã)     ║
║ ───────────────────────────────────────────────────── ║
║  📈 ÍNDICES US        │ 11:30-18:00 ⭐⭐⭐⭐         ║
║                       │ Pregão NY completo            ║
║ ───────────────────────────────────────────────────── ║
║  📈 ÍNDICES EUROPA    │ 05:00-07:00 ⭐⭐⭐⭐         ║
║                       │ Abertura Europa               ║
║                       │ 11:30-13:30 ⭐⭐⭐⭐⭐       ║
║                       │ Overlap Europa/NY             ║
║ ───────────────────────────────────────────────────── ║
║  🥇 METAIS           │ 05:00-09:00 ⭐⭐⭐⭐⭐       ║
║                       │ Sessão Londres (fixação)     ║
║                       │ 10:00-14:00 ⭐⭐⭐⭐⭐       ║
║                       │ Overlap máxima liquidez       ║
╚═══════════════════════════════════════════════════════╝
```

#### **Horários PROIBIDOS**
```
❌ NUNCA OPERAR:
- B3: 09:00-09:30 (gaps abertura)
- B3: 11:30-14:00 (almoço, baixa liquidez)
- B3: 17:30-18:15 (after-market)
- Forex: 30min antes/depois notícias alto impacto
- Qualquer ativo: Finais de semana
- Vésperas de feriados importantes
```

---

### **6. GESTÃO HÍBRIDA DE SAÍDAS**

#### **Sistema TP + Trailing**
```
ENTRADA: 100% da posição

SAÍDA ESCALONADA:
├─ TP1 (50% posição): RR 1:1
│  └─ Garante lucro inicial
│  └─ Move SL restante para breakeven
│
├─ TP2 (25% posição): RR 1:2  
│  └─ Lucro substancial garantido
│  └─ Ativa trailing nos 25% finais
│
└─ TRAILING (25% posição): Sem limite
   └─ Captura movimentos excepcionais
   └─ Distância adaptada por ativo
```

#### **Distâncias de Trailing por Ativo**
```
- Forex Majors: 25-30 pips
- Forex Minors: 30-40 pips  
- WIN: 250-400 pontos
- WDO: 20-30 pontos
- Ouro: $8-15
- Índices US: 15-40 pontos (conforme ativo)
```

#### **Movimento para Breakeven**
- **Trigger**: TP1 atingido OU lucro flutuante >= 1.5× risco
- **Ação**: SL = preço entrada + spread
- **Resultado**: Trade torna-se "risk-free"

---

### **7. CLASSIFICAÇÃO AUTOMÁTICA DE ATIVOS**

#### **Algoritmo de Detecção**
```cpp
// Detecção baseada no símbolo
string symbol = _Symbol;

// Forex Majors
if (symbol == "EURUSD" || symbol == "GBPUSD" || 
    symbol == "USDJPY" || symbol == "AUDUSD" ||
    symbol == "USDCAD" || symbol == "NZDUSD" ||
    symbol == "USDCHF") return FOREX_MAJOR;

// Forex Minors  
if (StringFind(symbol, "EUR") >= 0 || StringFind(symbol, "GBP") >= 0 ||
    StringFind(symbol, "JPY") >= 0 || StringFind(symbol, "AUD") >= 0) {
    if (StringFind(symbol, "USD") < 0) return FOREX_MINOR;
}

// B3 Brasil
if (symbol == "WIN" || StringFind(symbol, "IND") >= 0) return INDEX_B3;
if (symbol == "WDO" || StringFind(symbol, "DOL") >= 0) return CURRENCY_B3;

// Metais
if (symbol == "XAUUSD" || symbol == "XAGUSD") return METALS;

// Índices US
if (symbol == "US500" || symbol == "NAS100" || symbol == "US30") return INDEX_US;

// Índices Europa
if (symbol == "GER30" || symbol == "UK100" || symbol == "FRA40") return INDEX_EU;

// Exóticos (contém USD mas não é major)
if (StringFind(symbol, "USD") >= 0) return FOREX_EXOTIC;
```

#### **Configurações Automáticas por Classe**
```cpp
struct AssetConfig {
    bool useCurrencyStrength;    // CS aplicável?
    int requiredFilters;         // Quantos filtros usar
    int minFiltersForTrade;      // Mínimo para trade
    double idealSLMin;           // SL mínimo ideal
    double idealSLMax;           // SL máximo ideal  
    double slBuffer;             // Buffer adicional
    int primeHourStart;          // Início horário prime (HHMM)
    int primeHourEnd;            // Fim horário prime (HHMM)
    double maxRiskPremium;       // Risco máximo permitido
    double trailingDistance;     // Distância trailing padrão
};
```

---

### **8. VALIDAÇÕES DE QUALIDADE DE MERCADO**

#### **Filtros ATR (Average True Range)**
```
Ranges Ideais por Ativo:

FOREX:
- Majors: 15-40 pips
- Minors: 20-50 pips
- Exóticos: 30-80 pips

ÍNDICES:
- S&P500: 3-8 pontos
- Nasdaq: 10-25 pontos
- DAX: 15-40 pontos

B3:
- WIN: 200-600 pontos
- WDO: 10-40 pontos

METAIS:
- Ouro: $3-10
- Prata: $0.10-0.40

Ação: Se ATR fora da faixa → aguardar normalização
```

#### **Validações de Spread**
```cpp
// Spreads máximos aceitáveis
double maxSpread;
switch (assetClass) {
    case FOREX_MAJOR: maxSpread = 2.0 * _Point; break;    // 2 pips
    case FOREX_MINOR: maxSpread = 3.0 * _Point; break;    // 3 pips
    case FOREX_EXOTIC: maxSpread = 15.0 * _Point; break;  // 15 pips
    case INDEX_B3: maxSpread = 15.0 * _Point; break;      // 15 pontos
    case CURRENCY_B3: maxSpread = 3.0 * _Point; break;    // 3 pontos
    case METALS: maxSpread = 1.0 * _Point; break;         // $1
}

double currentSpread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
if (currentSpread > maxSpread) return false; // Não operar
```

---

### **9. SISTEMA DE PROTEÇÕES E SEGURANÇA**

#### **Proteções Obrigatórias**
```
✅ Máximo trades simultâneos: 3
✅ Drawdown máximo: 15% (pausa trading)
✅ Perda máxima por trade: 2% capital
✅ Validação margem B3: sempre >30% livre
✅ Reconexão automática: sim
✅ Validação conexão: antes cada trade
✅ Proteção slippage: máx 3 pips/pontos
✅ Stop loss obrigatório: sempre
✅ Timeout ordens: 30 segundos
✅ Log todas operações: obrigatório
```

#### **Regras de Disciplina**
```
❌ JAMAIS mover SL contra posição
❌ JAMAIS adicionar à posição perdedora  
❌ JAMAIS operar sem confluência mínima
❌ JAMAIS operar fora horários prime
❌ JAMAIS violar gestão de risco
❌ JAMAIS operar após 2 perdas seguidas (pause 24h)
❌ JAMAIS operar para "recuperar" perdas
```

---

### **10. MÉTRICAS E ESTATÍSTICAS**

#### **KPIs Obrigatórios**
```
Performance Geral:
- Win Rate (meta: ≥50%)
- Risk/Reward médio (meta: ≥1:1.5)
- Profit Factor (meta: ≥1.5)
- Drawdown máximo (limite: ≤15%)
- ROI mensal (acompanhar)

Por Classificação:
- Premium: Win rate, RR médio, total trades
- Bom: Win rate, RR médio, total trades

Por Ativo:
- Performance individual cada símbolo
- Melhores/piores ativos

Por Horário:
- Performance por faixa horária
- Validar horários prime

Disciplina:
- % trades seguindo sistema 100%
- Violações de regras (meta: 0%)
- Trades emocionais (meta: 0%)
```

#### **Relatórios Automáticos**
```
Diário: Resumo trades do dia
Semanal: Performance + ajustes necessários  
Mensal: Relatório completo + estatísticas
Trimestral: Análise profunda + otimizações
```

---

## 🎯 PRIORIDADES DE IMPLEMENTAÇÃO

### **FASE 1 - CORE (Crítico)**
1. Sistema multi-timeframe (H4/H1/M30/M15)
2. Indicadores principais (TM, CS, RSI, WAE)  
3. Sistema de pontuação adaptável
4. Gestão risco baseada em estrutura
5. Classificação automática de ativos

### **FASE 2 - OPERACIONAL (Essencial)**
6. Horários globais sincronizados
7. Gestão híbrida saídas (TP+trailing)
8. Sistema proteções/validações
9. Execução e gestão trades
10. Logs e alertas básicos

### **FASE 3 - AVANÇADO (Importante)**  
11. Estatísticas completas
12. Interface configuração
13. Filtros qualidade mercado
14. Otimizações performance
15. Documentação técnica

---

## ✅ CRITÉRIOS DE SUCESSO

### **Funcionais**
- ✅ Detecta corretamente alinhamento MTF
- ✅ Classifica ativos automaticamente  
- ✅ Aplica filtros conforme classe ativo
- ✅ Calcula SL baseado em estrutura
- ✅ Respeita horários prime por ativo
- ✅ Executa gestão híbrida saídas
- ✅ Nunca viola regras gestão risco

### **Performance** 
- ✅ Win rate ≥50% em backtest
- ✅ RR médio ≥1:1.3
- ✅ Profit factor ≥1.5  
- ✅ Drawdown ≤15%
- ✅ Tempo execução <100ms
- ✅ 100% conformidade regras

### **Robustez**
- ✅ Funciona 24h sem intervenção
- ✅ Reconecta automaticamente  
- ✅ Trata todos erros possíveis
- ✅ Logs completos auditáveis
- ✅ Performance estável longo prazo

---

## 📋 RESUMO EXECUTIVO DOS REQUISITOS

O EA Nexus Confluence v4.0 deve ser um **sistema universal adaptável** que:

1. **Funciona em qualquer ativo** com configurações automáticas
2. **Segue rigorosamente** todas as regras do sistema v4.0  
3. **Adapta filtros** conforme classe de ativo (2/3 ou 2/2)
4. **Calcula risco** baseado em estrutura de preços
5. **Respeita horários** de liquidez por mercado
6. **Executa gestão híbrida** de saídas profissional
7. **Protege capital** com validações múltiplas
8. **Documenta tudo** para auditoria completa
9. **Reporta métricas** para melhoria contínua
10. **É escalável** do micro ao institucional

**Este EA deve ser a execução perfeita e automatizada do Sistema Universal v4.0, superando a capacidade humana através de disciplina inabalável e precisão cirúrgica.**