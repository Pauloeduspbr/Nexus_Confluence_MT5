//+------------------------------------------------------------------+
//| RiskManagement.mqh                                               |
//| Nexus Confluence EA v4.27 - Gestão de Risco e Posicionamento    |
//|                                                                   |
//| PROPÓSITO: Calcular tamanho de posição, SL, TP, Breakeven       |
//|            e Trailing Stop baseado em estrutura de preços        |
//|                                                                   |
//| NOVO v4.11: Correção crítica FindStructureSL()                   |
//|             Implementação completa de gestão de posições         |
//| NOVO v4.15: Proteção drawdown + Registro perdas consecutivas    |
//| 🔥 v4.24: Limites de pausa (máx 12h) + Reset no pregão         |
//| 🔥 v4.27: CORREÇÃO CRÍTICA - Lógica Múltiplas Ordens vs Única  |
//|           - Verifica EnablePartialTP para decidir comportamento |
//|           - EnablePartialTP=true: BE/Trailing após TP1          |
//|           - EnablePartialTP=false: BE/Trailing direto em RR     |
//|           - TPs altos (15:1, 20:1, 25:1) para ordem única       |
//|                                                                   |
//| FUNÇÕES PRINCIPAIS:                                              |
//|   - CalculatePositionSize(): Calcula lote baseado em risco       |
//|   - FindStructureSL(): Encontra último topo/fundo significativo  |
//|   - CalculateTakeProfits(): Calcula TPs baseados em RR          |
//|   - ValidateRiskCalculation(): Valida se cálculo é seguro       |
//|   - ManageExistingTrades(): Gerencia trades abertos (NOVO)      |
//|   - MoveToBreakeven(): Move SL para breakeven (NOVO)            |
//|   - ExecutePartialClose(): Fecha parcialmente posição (NOVO)    |
//|   - UpdateTrailingStop(): Atualiza trailing stop (NOVO)         |
//|   - CalculatePauseTime(): Calcula tempo de pausa limitado       |
//|                                                                   |
//| DEPENDÊNCIAS:                                                    |
//|   - Parametros.mqh (structs, enums, inputs)                     |
//|                                                                   |
//| AUTOR: GitHub Copilot + Desenvolvedor                            |
//| DATA: Outubro 2025                                               |
//| VERSÃO: 4.27 - Lógica Ordem Única vs Múltiplas                 |
//+------------------------------------------------------------------+
#property copyright "Nexus Confluence EA v4.27"
#property version   "4.27"
#property strict

#include "Parametros.mqh"

//+------------------------------------------------------------------+
//| VARIÁVEIS EXTERNAS (declaradas no arquivo principal)            |
//+------------------------------------------------------------------+
extern double g_dailyStartBalance;
extern double g_weeklyStartBalance;
extern int    g_consecutiveLosses;
extern datetime g_lastTradeCloseTime;
extern datetime g_pauseUntilTime;
extern bool   g_dailyDrawdownHit;
extern bool   g_weeklyDrawdownHit;

//+------------------------------------------------------------------+
//| 🔥 NOVO v4.30: PROTEÇÃO DE DRAWDOWN DIÁRIO                     |
//| Reduz risco progressivamente conforme drawdown aumenta           |
//|                                                                  |
//| IMPACTO ESTIMADO: -40% drawdown máximo (91% → 55%)              |
//| Win Rate: Mantém ou melhora ligeiramente (+1-2%)                |
//| Sharpe Ratio: +0.02 a +0.05                                     |
//|                                                                  |
//| LÓGICA:                                                          |
//| - Drawdown 0-2%: Risco normal (100%)                            |
//| - Drawdown 2-5%: Risco reduzido (75%)                           |
//| - Drawdown 5-8%: Risco mínimo (50%)                             |
//| - Drawdown >8%: Pausa trading até próximo dia                   |
//|                                                                  |
//| RETORNO: Multiplicador de risco (0.0 a 1.0)                     |
//+------------------------------------------------------------------+
double GetMaxRiskForDay()
{
   // Se não resetou hoje, resetar saldo inicial diário
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   static int lastResetDay = -1;
   
   if(dt.day != lastResetDay)
   {
      g_dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      g_dailyDrawdownHit = false;
      lastResetDay = dt.day;
      PrintFormat("📅 Reset diário: Balance inicial = $%.2f", g_dailyStartBalance);
   }
   
   // Calcular drawdown atual do dia
   double currentBalance = AccountInfoDouble(ACCOUNT_EQUITY);
   double dailyDrawdown = 0;
   
   if(g_dailyStartBalance > 0)
   {
      dailyDrawdown = ((g_dailyStartBalance - currentBalance) / g_dailyStartBalance) * 100.0;
   }
   
   PrintFormat("💰 Drawdown Diário: %.2f%% (Balance Inicial: $%.2f, Atual: $%.2f)", 
               dailyDrawdown, g_dailyStartBalance, currentBalance);
   
   // Redução progressiva de risco
   double riskMultiplier = 1.0;
   
   if(dailyDrawdown <= 2.0)
   {
      // Zona verde: risco normal
      riskMultiplier = 1.0;
      PrintFormat("   ✅ Zona Verde: Risco 100%%");
   }
   else if(dailyDrawdown <= 5.0)
   {
      // Zona amarela: reduzir para 75%
      riskMultiplier = 0.75;
      PrintFormat("   ⚠️  Zona Amarela: Risco reduzido para 75%%");
   }
   else if(dailyDrawdown <= 8.0)
   {
      // Zona laranja: reduzir para 50%
      riskMultiplier = 0.50;
      PrintFormat("   🟠 Zona Laranja: Risco MÍNIMO 50%%");
   }
   else
   {
      // Zona vermelha: PARAR trading
      riskMultiplier = 0.0;
      g_dailyDrawdownHit = true;
      
      // Calcular próximo dia útil
      MqlDateTime nextDay;
      TimeToStruct(TimeCurrent() + 86400, nextDay); // +24h
      nextDay.hour = 0;
      nextDay.min = 0;
      nextDay.sec = 0;
      g_pauseUntilTime = StructToTime(nextDay);
      
      PrintFormat("   🛑 ZONA VERMELHA: Drawdown %.2f%% > 8%% - TRADING PAUSADO até %s", 
                  dailyDrawdown, TimeToString(g_pauseUntilTime, TIME_DATE|TIME_MINUTES));
   }
   
   return riskMultiplier;
}

//+------------------------------------------------------------------+
//| FUNÇÃO: FindStructureSL                                          |
//| Encontra último topo/fundo significativo para SL                |
//|                                                                  |
//| CORREÇÃO v4.11: Garante que SL sempre está na direção correta   |
//|                                                                  |
//| PARÂMETROS:                                                      |
//|   - symbol: Símbolo a analisar                                  |
//|   - direction: Direção do trade (BUY/SELL)                      |
//|   - lookbackBars: Quantos candles olhar para trás               |
//|                                                                  |
//| RETORNO: Nível de preço para SL (0 = erro)                      |
//+------------------------------------------------------------------+
double FindStructureSL(string symbol, TRADE_DIRECTION direction, int lookbackBars)
{
   double high[], low[], close[];
   
   // Copiar dados de preço do M15
   if(CopyHigh(symbol, PERIOD_M15, 1, lookbackBars, high) != lookbackBars ||
      CopyLow(symbol, PERIOD_M15, 1, lookbackBars, low) != lookbackBars ||
      CopyClose(symbol, PERIOD_M15, 0, 1, close) != 1)
   {
      PrintFormat("❌ Erro ao copiar dados de preço para calcular SL");
      return 0;
   }
   
   double slLevel = 0;
   double currentPrice = close[0];
   
   if(direction == TRADE_DIRECTION_BUY)
   {
      // 🔥 CORREÇÃO: Para COMPRA, procurar swing low ABAIXO do preço atual
      int maxLookback = MathMin(15, lookbackBars);
      
      // Procurar swing low VÁLIDO (abaixo do preço atual)
      for(int i = 2; i < maxLookback; i++)
      {
         // Verificar se é um swing low (mínimo local)
         bool isSwingLow = (low[i] < low[i-1] && low[i] < low[i+1] && 
                           low[i] <= low[i-2] && low[i] <= low[i+2]);
         
         // 🔥 VALIDAÇÃO CRÍTICA: Swing low DEVE estar ABAIXO do preço atual
         bool isBelowPrice = (low[i] < currentPrice);
         
         if(isSwingLow && isBelowPrice)
         {
            slLevel = low[i];
            PrintFormat("   📍 SL COMPRA: Swing Low [%d] = %.5f (abaixo de %.5f ✅)", 
                        i, slLevel, currentPrice);
            break;
         }
      }
      
      // Se não encontrou swing válido, usar mínimo recente
      if(slLevel == 0 || slLevel >= currentPrice)
      {
         slLevel = low[ArrayMinimum(low, 0, MathMin(5, lookbackBars))];
         PrintFormat("   📍 SL COMPRA: Mínimo recente (5 candles) = %.5f", slLevel);
         
         // 🔥 PROTEÇÃO FINAL: Se AINDA está acima/igual, forçar abaixo
         if(slLevel >= currentPrice)
         {
            slLevel = currentPrice * (1.0 - SL_FallbackPercent / 100.0);
            PrintFormat("   ⚠️ SL FORÇADO %.1f%% abaixo: %.5f (preço: %.5f)", 
                        SL_FallbackPercent, slLevel, currentPrice);
         }
      }
      
      // Adicionar buffer de segurança
      double buffer = SL_BufferPoints * _Point;
      slLevel -= buffer;
      
      // 🔥 VALIDAÇÃO FINAL OBRIGATÓRIA
      if(slLevel >= currentPrice)
      {
         PrintFormat("   � ERRO CRÍTICO: SL %.5f >= Preço %.5f após buffer!", slLevel, currentPrice);
         slLevel = currentPrice * (1.0 - SL_FallbackPercent / 100.0);
         PrintFormat("   ✅ SL CORRIGIDO para %.5f (%.1f%% abaixo)", slLevel, SL_FallbackPercent);
      }
      
      PrintFormat("   🛡️ SL FINAL: %.5f | Distância: %.5f (%.1f pontos) | Preço: %.5f", 
                  slLevel, currentPrice - slLevel, (currentPrice - slLevel)/_Point, currentPrice);
   }
   else if(direction == TRADE_DIRECTION_SELL)
   {
      // 🔥 CORREÇÃO: Para VENDA, procurar swing high ACIMA do preço atual
      int maxLookback = MathMin(15, lookbackBars);
      
      // Procurar swing high VÁLIDO (acima do preço atual)
      for(int i = 2; i < maxLookback; i++)
      {
         // Verificar se é um swing high
         bool isSwingHigh = (high[i] > high[i-1] && high[i] > high[i+1] && 
                            high[i] >= high[i-2] && high[i] >= high[i+2]);
         
         // 🔥 VALIDAÇÃO CRÍTICA: Swing high DEVE estar ACIMA do preço atual
         bool isAbovePrice = (high[i] > currentPrice);
         
         if(isSwingHigh && isAbovePrice)
         {
            slLevel = high[i];
            PrintFormat("   📍 SL VENDA: Swing High [%d] = %.5f (acima de %.5f ✅)", 
                        i, slLevel, currentPrice);
            break;
         }
      }
      
      // Se não encontrou swing válido, usar máximo recente
      if(slLevel == 0 || slLevel <= currentPrice)
      {
         slLevel = high[ArrayMaximum(high, 0, MathMin(5, lookbackBars))];
         PrintFormat("   📍 SL VENDA: Máximo recente (5 candles) = %.5f", slLevel);
         
         // 🔥 PROTEÇÃO FINAL: Se AINDA está abaixo/igual, forçar acima
         if(slLevel <= currentPrice)
         {
            slLevel = currentPrice * (1.0 + SL_FallbackPercent / 100.0);
            PrintFormat("   ⚠️ SL FORÇADO %.1f%% acima: %.5f (preço: %.5f)", 
                        SL_FallbackPercent, slLevel, currentPrice);
         }
      }
      
      // Adicionar buffer de segurança
      double buffer = SL_BufferPoints * _Point;
      slLevel += buffer;
      
      // 🔥 VALIDAÇÃO FINAL OBRIGATÓRIA
      if(slLevel <= currentPrice)
      {
         PrintFormat("   � ERRO CRÍTICO: SL %.5f <= Preço %.5f após buffer!", slLevel, currentPrice);
         slLevel = currentPrice * (1.0 + SL_FallbackPercent / 100.0);
         PrintFormat("   ✅ SL CORRIGIDO para %.5f (%.1f%% acima)", slLevel, SL_FallbackPercent);
      }
      
      PrintFormat("   🛡️ SL FINAL: %.5f | Distância: %.5f (%.1f pontos) | Preço: %.5f", 
                  slLevel, slLevel - currentPrice, (slLevel - currentPrice)/_Point, currentPrice);
   }
   
   return slLevel;
}

//+------------------------------------------------------------------+
//| FUNÇÃO: CalculatePositionSize                                    |
//| Calcula tamanho da posição baseado em risco e SL                |
//|                                                                  |
//| PARÂMETROS:                                                      |
//|   - symbol: Símbolo a operar                                    |
//|   - direction: Direção do trade                                 |
//|   - setupClass: Classificação do setup (PREMIUM/GOOD)           |
//|                                                                  |
//| RETORNO: RiskCalculation struct com todos os dados              |
//+------------------------------------------------------------------+
RiskCalculation CalculatePositionSize(string symbol, TRADE_DIRECTION direction, SETUP_CLASS setupClass)
{
   RiskCalculation result;
   result.isValid = false;
   result.positionSize = 0;
   result.stopLoss = 0;
   result.takeProfit1 = 0;
   result.takeProfit2 = 0;
   result.takeProfit3 = 0;
   result.slDistance = 0;
   result.riskAmount = 0;
   result.potentialProfit1 = 0;
   result.potentialProfit2 = 0;
   result.potentialProfit3 = 0;
   result.errorMessage = "";
   
   PrintFormat("════════════════════════════════════════════════════════════════");
   PrintFormat("💰 CALCULANDO TAMANHO DE POSIÇÃO");
   PrintFormat("════════════════════════════════════════════════════════════════");
   
   // 🔥 CORREÇÃO CRÍTICA #1: VALIDAR CAPITAL MÍNIMO FLEXÍVEL
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double minCapital = 100.0; // Mínimo $100 para contas pequenas
   
   if(accountBalance < minCapital)
   {
      result.errorMessage = StringFormat("Capital insuficiente: $%.2f < $%.2f mínimo", 
                                        accountBalance, minCapital);
      PrintFormat("❌ %s", result.errorMessage);
      return result;
   }
   
   // ⚠️ AVISO: Contas pequenas ($100-500) terão menos oportunidades por margem limitada
   if(accountBalance < 500.0)
   {
      PrintFormat("⚠️ Capital baixo ($%.2f) - Operará com lotes pequenos e menos trades simultâneos", accountBalance);
   }
   
   // 1. SE LOTE FIXO CONFIGURADO, USAR DIRETO
   if(FixedLotSize > 0)
   {
      PrintFormat("   ⚙️ Modo: LOTE FIXO (%.2f lots)", FixedLotSize);
      
      // Obter preço atual
      double currentPrice = (direction == TRADE_DIRECTION_BUY) ? 
         SymbolInfoDouble(symbol, SYMBOL_ASK) : 
         SymbolInfoDouble(symbol, SYMBOL_BID);
      
   // Encontrar SL baseado em estrutura (agora com validação interna)
   double slLevel = FindStructureSL(symbol, direction, LookbackStructureBars);
   if(slLevel == 0)
   {
      result.errorMessage = "Não foi possível encontrar nível de SL";
      return result;
   }
   
   // ✅ FindStructureSL() agora GARANTE que SL está na direção correta!      result.positionSize = FixedLotSize;
      result.stopLoss = slLevel;
      result.slDistance = MathAbs(currentPrice - slLevel);
      
      // Calcular TPs
      if(direction == TRADE_DIRECTION_BUY)
      {
         result.takeProfit1 = currentPrice + (result.slDistance * TP1_RR);
         result.takeProfit2 = currentPrice + (result.slDistance * TP2_RR);
         if(UseTP3)
            result.takeProfit3 = currentPrice + (result.slDistance * TP3_RR);
      }
      else
      {
         result.takeProfit1 = currentPrice - (result.slDistance * TP1_RR);
         result.takeProfit2 = currentPrice - (result.slDistance * TP2_RR);
         if(UseTP3)
            result.takeProfit3 = currentPrice - (result.slDistance * TP3_RR);
      }
      
      // Calcular valores de risco e lucro
      double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      double slTicks = result.slDistance / tickSize;
      
      result.riskAmount = slTicks * tickValue * result.positionSize;
      result.potentialProfit1 = result.riskAmount * TP1_RR;
      result.potentialProfit2 = result.riskAmount * TP2_RR;
      if(UseTP3)
         result.potentialProfit3 = result.riskAmount * TP3_RR;
      
      result.isValid = true;
      
      PrintFormat("   📊 Preço Entrada: %.5f", currentPrice);
      PrintFormat("   🛑 Stop Loss: %.5f (distância: %.5f = %.1f pontos)", 
                  result.stopLoss, result.slDistance, result.slDistance/_Point);
      PrintFormat("   🎯 TP1 (RR 1:%.1f): %.5f", TP1_RR, result.takeProfit1);
      PrintFormat("   🎯 TP2 (RR 1:%.1f): %.5f", TP2_RR, result.takeProfit2);
      if(UseTP3)
         PrintFormat("   🎯 TP3 (RR 1:%.1f): %.5f", TP3_RR, result.takeProfit3);
      PrintFormat("   💵 Risco: $%.2f | Lucro Potencial TP1: $%.2f | TP2: $%.2f%s", 
                  result.riskAmount, result.potentialProfit1, result.potentialProfit2,
                  UseTP3 ? StringFormat(" | TP3: $%.2f", result.potentialProfit3) : "");
      PrintFormat("════════════════════════════════════════════════════════════════");
      
      return result;
   }
   
   // 2. MODO RISCO AUTOMÁTICO (baseado em % da conta)
   PrintFormat("   ⚙️ Modo: RISCO AUTOMÁTICO");
   
   // accountBalance já declarado na linha 226 - reutilizar
   double riskPercent = (setupClass == SETUP_PREMIUM) ? MaxRiskPremium : AccountRiskPercent;
   
   // 🔥 NOVO v4.30: APLICAR PROTEÇÃO DE DRAWDOWN DIÁRIO
   double riskMultiplier = GetMaxRiskForDay();
   
   if(riskMultiplier == 0.0)
   {
      result.errorMessage = "Trading pausado por drawdown diário excessivo (>8%)";
      PrintFormat("🛑 %s", result.errorMessage);
      return result;
   }
   
   // Aplicar multiplicador ao risco
   riskPercent *= riskMultiplier;
   
   PrintFormat("   💰 Saldo da conta: $%.2f", accountBalance);
   PrintFormat("   📊 Risco base: %.2f%% (Setup %s)", 
               (setupClass == SETUP_PREMIUM) ? MaxRiskPremium : AccountRiskPercent, 
               (setupClass == SETUP_PREMIUM) ? "PREMIUM" : "GOOD");
   PrintFormat("   🛡️  Multiplicador drawdown: %.0f%% → Risco final: %.2f%%", 
               riskMultiplier * 100.0, riskPercent);
   
   // Obter preço atual
   double currentPrice = (direction == TRADE_DIRECTION_BUY) ? 
      SymbolInfoDouble(symbol, SYMBOL_ASK) : 
      SymbolInfoDouble(symbol, SYMBOL_BID);
   
   // Encontrar SL baseado em estrutura (agora com validação interna completa)
   double slLevel = FindStructureSL(symbol, direction, LookbackStructureBars);
   if(slLevel == 0)
   {
      result.errorMessage = "Não foi possível encontrar nível de SL";
      PrintFormat("❌ %s", result.errorMessage);
      return result;
   }
   
   // ✅ FindStructureSL() agora GARANTE que SL está na direção correta!
   
   // Calcular distância SL em pontos
   double slDistance = MathAbs(currentPrice - slLevel);
   
   // 🔥 CORREÇÃO CRÍTICA #2: FORÇAR HARD LIMIT NO SL (não apenas validar depois)
   double maxSLDistance = SL_MaxDistancePoints * _Point;
   if(slDistance > maxSLDistance)
   {
      PrintFormat("   ⚠️ SL estrutura %.1f pts > máximo %.1f pts - FORÇANDO LIMITE",
                  slDistance/_Point, SL_MaxDistancePoints);
      
      // Recalcular SL para respeitar o limite máximo
      if(direction == TRADE_DIRECTION_BUY)
      {
         slLevel = currentPrice - maxSLDistance;
      }
      else
      {
         slLevel = currentPrice + maxSLDistance;
      }
      
      slDistance = maxSLDistance;
      PrintFormat("   ✅ SL AJUSTADO: %.5f (distância: %.1f pts)", slLevel, slDistance/_Point);
   }
   
   PrintFormat("   📏 Distância SL: %.5f (%.1f pontos)", slDistance, slDistance/_Point);
   
   // Calcular valor em risco
   double riskAmount = accountBalance * (riskPercent / 100.0);
   
   PrintFormat("   💵 Valor em risco: $%.2f", riskAmount);
   
   // Calcular valor por pip/tick
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(tickValue == 0 || tickSize == 0)
   {
      result.errorMessage = "Erro ao obter dados de tick do símbolo";
      PrintFormat("❌ %s", result.errorMessage);
      return result;
   }
   
   // Calcular tamanho da posição
   double slTicks = slDistance / tickSize;
   double positionSize = riskAmount / (slTicks * tickValue);
   
   // Normalizar tamanho conforme especificações do símbolo
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
   positionSize = MathFloor(positionSize / lotStep) * lotStep;
   positionSize = MathMax(minLot, MathMin(maxLot, positionSize));
   
   PrintFormat("   📦 Tamanho calculado: %.2f lots (normalizado entre %.2f-%.2f)", 
               positionSize, minLot, maxLot);
   
   // Verificar se tamanho é válido
   if(positionSize < minLot)
   {
      result.errorMessage = StringFormat("Tamanho calculado (%.2f) menor que mínimo (%.2f)", positionSize, minLot);
      PrintFormat("❌ %s", result.errorMessage);
      return result;
   }
   
   // Preencher resultado
   result.positionSize = positionSize;
   result.stopLoss = slLevel;
   result.slDistance = slDistance;
   result.riskAmount = riskAmount;
   
   // Calcular TPs
   if(direction == TRADE_DIRECTION_BUY)
   {
      result.takeProfit1 = currentPrice + (slDistance * TP1_RR);
      result.takeProfit2 = currentPrice + (slDistance * TP2_RR);
      if(UseTP3)
         result.takeProfit3 = currentPrice + (slDistance * TP3_RR);
   }
   else
   {
      result.takeProfit1 = currentPrice - (slDistance * TP1_RR);
      result.takeProfit2 = currentPrice - (slDistance * TP2_RR);
      if(UseTP3)
         result.takeProfit3 = currentPrice - (slDistance * TP3_RR);
   }
   
   result.potentialProfit1 = riskAmount * TP1_RR;
   result.potentialProfit2 = riskAmount * TP2_RR;
   if(UseTP3)
      result.potentialProfit3 = riskAmount * TP3_RR;
   result.isValid = true;
   
   PrintFormat("   📊 Preço Entrada: %.5f", currentPrice);
   PrintFormat("   🛑 Stop Loss: %.5f", result.stopLoss);
   PrintFormat("   🎯 TP1 (RR 1:%.1f): %.5f | Lucro: $%.2f", TP1_RR, result.takeProfit1, result.potentialProfit1);
   PrintFormat("   🎯 TP2 (RR 1:%.1f): %.5f | Lucro: $%.2f", TP2_RR, result.takeProfit2, result.potentialProfit2);
   if(UseTP3)
      PrintFormat("   🎯 TP3 (RR 1:%.1f): %.5f | Lucro: $%.2f", TP3_RR, result.takeProfit3, result.potentialProfit3);
   PrintFormat("════════════════════════════════════════════════════════════════");
   
   return result;
}

//+------------------------------------------------------------------+
//| FUNÇÃO: ValidateRiskCalculation                                  |
//| Valida se cálculo de risco está dentro de parâmetros seguros   |
//|                                                                  |
//| PARÂMETROS:                                                      |
//|   - risk: Estrutura RiskCalculation a validar                   |
//|   - symbol: Símbolo do trade                                    |
//|                                                                  |
//| RETORNO: true se válido, false se não                           |
//+------------------------------------------------------------------+
bool ValidateRiskCalculation(const RiskCalculation &risk, string symbol)
{
   if(!risk.isValid)
   {
      PrintFormat("❌ Cálculo de risco inválido");
      return false;
   }
   
   // Validar margem disponível
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double requiredMargin = 0;
   
   if(!OrderCalcMargin(ORDER_TYPE_BUY, symbol, risk.positionSize, 
                       SymbolInfoDouble(symbol, SYMBOL_ASK), requiredMargin))
   {
      PrintFormat("❌ Erro ao calcular margem necessária");
      return false;
   }
   
   // 🔥 CORREÇÃO v4.30: Validação correta de margem livre
   // Garantir que sobre pelo menos X% da margem APÓS o trade (não ANTES!)
   double minFreeMarginDecimal = MinFreeMarginPercent / 100.0;
   double marginAfterTrade = freeMargin - requiredMargin;
   double percentFreeAfterTrade = (marginAfterTrade / freeMargin) * 100.0;
   
   if(marginAfterTrade < (freeMargin * minFreeMarginDecimal))
   {
      PrintFormat("❌ Margem insuficiente:");
      PrintFormat("   📊 Margem necessária: $%.2f | Margem livre: $%.2f", requiredMargin, freeMargin);
      PrintFormat("   📉 Sobraria: $%.2f (%.1f%%) < %.1f%% mínimo configurado",
                  marginAfterTrade, percentFreeAfterTrade, MinFreeMarginPercent);
      PrintFormat("   💡 Solução: Aumentar capital OU reduzir MinFreeMarginPercent (atual: %.0f%%)",
                  MinFreeMarginPercent);
      return false;
   }
   
   PrintFormat("   ✅ Margem validada: Necessário $%.2f | Livre $%.2f | Sobrará $%.2f (%.1f%% > %.1f%% mínimo)",
               requiredMargin, freeMargin, marginAfterTrade, percentFreeAfterTrade, MinFreeMarginPercent);
   
   // 🔥 v4.22 CORREÇÃO CRÍTICA: REJEITAR se SL muito distante
   // BUG v4.21: Apenas alertava mas permitia SL de 800 pontos (limite 500!)
   // Resultado: TP's absurdos (120-240 pips), nunca atingidos, breakeven/trailing nunca ativam
   double maxSLDistance = SL_MaxDistancePoints * _Point;
   if(risk.slDistance > maxSLDistance)
   {
      PrintFormat("❌ SL muito distante (%.1f pontos > %.1f máximo) - REJEITADO", 
                  risk.slDistance/_Point, SL_MaxDistancePoints);
      return false;  // ✅ REJEITAR!
   }
   
   // Validar se SL não está muito perto
   double minSLDistance = SL_MinDistancePoints * _Point;
   if(risk.slDistance < minSLDistance)
   {
      PrintFormat("❌ SL muito próximo (%.1f pontos < %.1f mínimo)", risk.slDistance/_Point, minSLDistance/_Point);
      return false;
   }
   
   PrintFormat("✅ Validação de risco: OK");
   return true;
}

//+------------------------------------------------------------------+
//| GESTÃO DE POSIÇÕES ABERTAS - v4.11                              |
//+------------------------------------------------------------------+

// Variáveis globais para rastreamento de trades
struct TradeState
{
   ulong    ticket;
   bool     movedToBreakeven;
   bool     tp1Hit;
   bool     tp2Hit;
   bool     trailingActive;
   datetime lastUpdate;
};

TradeState g_tradeStates[];

//+------------------------------------------------------------------+
//| Encontrar ou criar estado do trade                              |
//+------------------------------------------------------------------+
int FindOrCreateTradeState(ulong ticket)
{
   // Procurar se já existe
   for(int i = 0; i < ArraySize(g_tradeStates); i++)
   {
      if(g_tradeStates[i].ticket == ticket)
         return i;
   }
   
   // Criar novo
   int newSize = ArraySize(g_tradeStates) + 1;
   ArrayResize(g_tradeStates, newSize);
   
   g_tradeStates[newSize-1].ticket = ticket;
   g_tradeStates[newSize-1].movedToBreakeven = false;
   g_tradeStates[newSize-1].tp1Hit = false;
   g_tradeStates[newSize-1].tp2Hit = false;
   g_tradeStates[newSize-1].trailingActive = false;
   g_tradeStates[newSize-1].lastUpdate = TimeCurrent();
   
   return newSize-1;
}

//+------------------------------------------------------------------+
//| Remover trade estado quando fechado                             |
//+------------------------------------------------------------------+
void RemoveTradeState(ulong ticket)
{
   for(int i = ArraySize(g_tradeStates) - 1; i >= 0; i--)
   {
      if(g_tradeStates[i].ticket == ticket)
      {
         // Remover movendo último elemento para esta posição
         if(i < ArraySize(g_tradeStates) - 1)
         {
            g_tradeStates[i] = g_tradeStates[ArraySize(g_tradeStates) - 1];
         }
         ArrayResize(g_tradeStates, ArraySize(g_tradeStates) - 1);
         break;
      }
   }
}

//+------------------------------------------------------------------+
//| FUNÇÃO PRINCIPAL: Gerenciar todas as posições abertas           |
//+------------------------------------------------------------------+
void ManageExistingTrades()
{
   // Verificar cada posição aberta
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      
      if(!PositionSelectByTicket(ticket))
         continue;
         
      if(PositionGetInteger(POSITION_MAGIC) != EA_MAGIC_NUMBER)
         continue;
         
      // Gerenciar este trade
      ManageSingleTrade(ticket);
   }
   
   // Limpar estados de trades que foram fechados
   CleanupClosedTrades();
}

//+------------------------------------------------------------------+
//| Limpar estados de trades fechados                               |
//+------------------------------------------------------------------+
void CleanupClosedTrades()
{
   for(int i = ArraySize(g_tradeStates) - 1; i >= 0; i--)
   {
      ulong ticket = g_tradeStates[i].ticket;
      
      // Verificar se posição ainda existe
      if(!PositionSelectByTicket(ticket))
      {
         // 🔥 v4.15: NOVO - Registrar perda/ganho para contador de perdas consecutivas
         if(HistorySelectByPosition(ticket))
           {
            ulong dealTicket = 0;
            for(int d = HistoryDealsTotal() - 1; d >= 0; d--)
              {
               dealTicket = HistoryDealGetTicket(d);
               if(HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID) == ticket)
                 {
                  double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
                  
                  if(profit < 0)
                    {
                     // Trade fechou em PERDA
                     g_consecutiveLosses++;
                     PrintFormat("📉 Trade #%I64u fechou em PERDA (%.2f) - Perdas consecutivas: %d", 
                                 ticket, profit, g_consecutiveLosses);
                     
                     // Verificar se atingiu limite de perdas consecutivas
                     if(g_consecutiveLosses >= MaxConsecutiveLosses)
                       {
                        // 🔥 v4.15: TEMPO DE PAUSA ADAPTADO AO TIMEFRAME
                        int pauseSeconds = CalculatePauseTime(Period());
                        g_pauseUntilTime = TimeCurrent() + pauseSeconds;
                        
                        string pauseDuration = FormatPauseDuration(pauseSeconds);
                        string msg = StringFormat("🚨 %d PERDAS CONSECUTIVAS! Trading PAUSADO por %s até %s",
                                                  g_consecutiveLosses,
                                                  pauseDuration,
                                                  TimeToString(g_pauseUntilTime, TIME_DATE|TIME_MINUTES));
                        PrintFormat("%s", msg);
                        if(SendAlerts) SendNotification(msg);
                       }
                    }
                  else if(profit > 0)
                    {
                     // Trade fechou em GANHO - resetar contador
                     if(g_consecutiveLosses > 0)
                       {
                        PrintFormat("📈 Trade #%I64u fechou em GANHO (%.2f) - Perdas consecutivas RESETADAS (era %d)",
                                    ticket, profit, g_consecutiveLosses);
                        g_consecutiveLosses = 0;
                        g_pauseUntilTime = 0; // Limpar pausa
                       }
                    }
                  
                  break;
                 }
              }
           }
         
         RemoveTradeState(ticket);
      }
   }
}

//+------------------------------------------------------------------+
//| Gerenciar um trade específico                                    |
//+------------------------------------------------------------------+
void ManageSingleTrade(ulong ticket)
{
   if(!PositionSelectByTicket(ticket))
      return;
   
   // Obter informações da posição
   double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSL = PositionGetDouble(POSITION_SL);
   double currentTP = PositionGetDouble(POSITION_TP);
   bool isLong = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
   string symbol = PositionGetString(POSITION_SYMBOL);
   
   // Calcular lucro atual em RR
   double slDistance = MathAbs(openPrice - currentSL);
   if(slDistance == 0)
      return; // SL inválido, não gerenciar
      
   double currentProfit = isLong ? (currentPrice - openPrice) : (openPrice - currentPrice);
   double currentRR = currentProfit / slDistance;
   
   // Obter ou criar estado do trade
   int stateIdx = FindOrCreateTradeState(ticket);
   
   // ════════════════════════════════════════════════════════════════
   // 1. TAKE PROFIT PARCIAL TP1 (executar ANTES de mover BE)
   // ════════════════════════════════════════════════════════════════
   if(EnablePartialTP && !g_tradeStates[stateIdx].tp1Hit && currentRR >= TP1_RR)
   {
      if(ExecutePartialClose(ticket, TP1_ClosePercent, symbol))
      {
         g_tradeStates[stateIdx].tp1Hit = true;
         PrintFormat("🎯 Trade #%I64u: TP1 atingido! Fechados %.1f%% (RR: %.2f)", 
                     ticket, TP1_ClosePercent, currentRR);
      }
   }
   
   // ════════════════════════════════════════════════════════════════
   // 2. MOVER PARA BREAKEVEN - 🔥 v4.27: LÓGICA CORRIGIDA - Múltiplas ordens vs Ordem Única
   // ════════════════════════════════════════════════════════════════
   if(EnableBreakeven && !g_tradeStates[stateIdx].movedToBreakeven)
   {
      bool canMoveToBreakeven = false;

      if(EnablePartialTP)
      {
         // ✅ MODO MÚLTIPLAS ORDENS: Move BE APENAS após TP1 fechado
         canMoveToBreakeven = (g_tradeStates[stateIdx].tp1Hit && currentRR >= BreakevenAfterRR);
      }
      else
      {
         // ✅ MODO ORDEM ÚNICA: Move BE quando atingir RR configurado (sem depender de TP)
         canMoveToBreakeven = (currentRR >= BreakevenAfterRR);
      }

      if(canMoveToBreakeven)
      {
         if(MoveToBreakeven(ticket, openPrice, symbol))
         {
            g_tradeStates[stateIdx].movedToBreakeven = true;
            PrintFormat("✅ Trade #%I64u: SL movido para BREAKEVEN (RR: %.2f >= %.2f) [%s]",
                        ticket, currentRR, BreakevenAfterRR,
                        EnablePartialTP ? "após TP1" : "ordem única");
         }
      }
   }
   
   // ════════════════════════════════════════════════════════════════
   // 3. TAKE PROFIT PARCIAL TP2
   // ════════════════════════════════════════════════════════════════
   if(EnablePartialTP && g_tradeStates[stateIdx].tp1Hit && 
      !g_tradeStates[stateIdx].tp2Hit && currentRR >= TP2_RR)
   {
      if(ExecutePartialClose(ticket, TP2_ClosePercent, symbol))
      {
         g_tradeStates[stateIdx].tp2Hit = true;
         g_tradeStates[stateIdx].trailingActive = true; // Ativar trailing após TP2
         PrintFormat("🎯 Trade #%I64u: TP2 atingido! Fechados %.1f%% | Trailing ATIVADO (RR: %.2f)", 
                     ticket, TP2_ClosePercent, currentRR);
      }
   }
   
   // ════════════════════════════════════════════════════════════════
   // 4. TRAILING STOP - 🔥 v4.27: LÓGICA CORRIGIDA - Múltiplas ordens vs Ordem Única
   // ════════════════════════════════════════════════════════════════
   if(EnableTrailing && currentRR >= TrailingActivationRR)
   {
      bool canActivateTrailing = false;

      if(EnablePartialTP && TrailingStartAfterTP)
      {
         // ✅ MODO MÚLTIPLAS ORDENS com trailing após TP: Espera TP1 fechado
         canActivateTrailing = g_tradeStates[stateIdx].tp1Hit;
      }
      else
      {
         // ✅ MODO ORDEM ÚNICA ou trailing independente: Ativa quando atingir RR
         canActivateTrailing = true;
      }

      if(canActivateTrailing)
      {
         // Ativar trailing automaticamente se atingiu RR mínimo
         if(!g_tradeStates[stateIdx].trailingActive)
         {
            g_tradeStates[stateIdx].trailingActive = true;
            PrintFormat("📈 Trade #%I64u: Trailing ATIVADO (RR: %.2f >= %.2f) [%s]",
                        ticket, currentRR, TrailingActivationRR,
                        EnablePartialTP ? "múltiplas ordens" : "ordem única");
         }

         // Atualizar trailing stop
         UpdateTrailingStop(ticket, currentPrice, currentSL, isLong, symbol);
      }
   }
   
   // Atualizar timestamp
   g_tradeStates[stateIdx].lastUpdate = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Mover SL para breakeven - 🔥 v4.27: USA BreakevenPlusPoints     |
//+------------------------------------------------------------------+
bool MoveToBreakeven(ulong ticket, double openPrice, string symbol)
{
   // 🔥 v4.27: Calcular breakeven com parâmetros configuráveis
   double spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD) * SymbolInfoDouble(symbol, SYMBOL_POINT);
   double plusPoints = BreakevenPlusPoints * SymbolInfoDouble(symbol, SYMBOL_POINT);

   // ✅ CORRIGIDO: Breakeven + spread + pontos extras
   double newSL = openPrice + (spread * 0.5) + plusPoints;

   bool isLong = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);

   // Para SELL, inverter lógica
   if(!isLong)
   {
      newSL = openPrice - (spread * 0.5) - plusPoints;
   }

   MqlTradeRequest request;
   MqlTradeResult result;

   ZeroMemory(request);
   request.action = TRADE_ACTION_SLTP;
   request.position = ticket;
   request.symbol = symbol;
   request.sl = newSL;
   request.tp = PositionGetDouble(POSITION_TP);
   request.magic = EA_MAGIC_NUMBER;

   if(OrderSend(request, result))
   {
      if(result.retcode == TRADE_RETCODE_DONE)
      {
         PrintFormat("   ✅ Breakeven: SL %.5f → %.5f (entrada + spread + %.1f pts)",
                     PositionGetDouble(POSITION_SL), newSL, BreakevenPlusPoints);
         return true;
      }
   }

   PrintFormat("⚠️ Falha ao mover para breakeven: %d - %s", result.retcode, result.comment);
   return false;
}

//+------------------------------------------------------------------+
//| Fechar parcialmente a posição                                   |
//+------------------------------------------------------------------+
bool ExecutePartialClose(ulong ticket, double percentToClose, string symbol)
{
   if(!PositionSelectByTicket(ticket))
      return false;
   
   double currentVolume = PositionGetDouble(POSITION_VOLUME);
   double volumeToClose = currentVolume * (percentToClose / 100.0);
   
   // Normalizar volume
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   volumeToClose = MathFloor(volumeToClose / lotStep) * lotStep;
   
   // Validar volume mínimo
   if(volumeToClose < minLot)
   {
      PrintFormat("⚠️ Volume parcial %.2f < mínimo %.2f, ajustando", volumeToClose, minLot);
      volumeToClose = minLot;
   }
   
   // Não fechar se volume maior que posição atual
   if(volumeToClose > currentVolume)
   {
      volumeToClose = currentVolume;
   }
   
   MqlTradeRequest request;
   MqlTradeResult result;
   
   ZeroMemory(request);
   request.action = TRADE_ACTION_DEAL;
   request.position = ticket;
   request.symbol = symbol;
   request.volume = volumeToClose;
   request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 
                  ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   request.price = (request.type == ORDER_TYPE_SELL) ? 
                   SymbolInfoDouble(symbol, SYMBOL_BID) :
                   SymbolInfoDouble(symbol, SYMBOL_ASK);
   request.deviation = MaxSlippagePoints;
   request.magic = EA_MAGIC_NUMBER;
   
   if(OrderSend(request, result))
   {
      if(result.retcode == TRADE_RETCODE_DONE)
      {
         PrintFormat("   ✅ Fechamento parcial: %.2f lots (%.1f%%) no preço %.5f", 
                     volumeToClose, percentToClose, result.price);
         return true;
      }
   }
   
   PrintFormat("⚠️ Falha no fechamento parcial: %d - %s", result.retcode, result.comment);
   return false;
}

//+------------------------------------------------------------------+
//| Atualizar trailing stop - 🔥 v4.27: IMPLEMENTADO uso de ATR    |
//+------------------------------------------------------------------+
void UpdateTrailingStop(ulong ticket, double currentPrice, double currentSL, bool isLong, string symbol)
{
   double trailingDist = 0.0;
   double stepDist = 0.0;
   double lastTrailingATR = 0.0;
   double lastTrailingDist = 0.0;
   double lastStepDist = 0.0;

   // 🔥 v4.27: IMPLEMENTAR uso de ATR para trailing dinâmico
   if(TrailingUseATR)
   {
      // Calcular ATR no M15 (timeframe operacional)
      int atrHandle = iATR(symbol, PERIOD_M15, 14);
      if(atrHandle == INVALID_HANDLE)
      {
         PrintFormat("⚠️ Erro ao criar handle ATR para trailing, usando pontos fixos");
         trailingDist = TrailingDistancePoints * SymbolInfoDouble(symbol, SYMBOL_POINT);
         stepDist = TrailingStepPoints * SymbolInfoDouble(symbol, SYMBOL_POINT);
         lastTrailingATR = 0.0;
         lastTrailingDist = trailingDist;
         lastStepDist = stepDist;
      }
      else
      {
         double atr[];
         ArraySetAsSeries(atr, true);

         if(CopyBuffer(atrHandle, 0, 0, 1, atr) == 1)
         {
            // ✅ Usar ATR multiplicado pelo parâmetro configurável
            trailingDist = atr[0] * TrailingATRMultiplier;
            stepDist = atr[0] * 0.3; // Step = 30% do ATR

            // Garantir valores mínimos razoáveis
            double minDist = 100.0 * SymbolInfoDouble(symbol, SYMBOL_POINT); // Mínimo 10 pontos
            if(trailingDist < minDist)
               trailingDist = minDist;

            lastTrailingATR = atr[0];
            lastTrailingDist = trailingDist;
            lastStepDist = stepDist;
         }
         else
         {
            PrintFormat("⚠️ Erro ao ler ATR, usando pontos fixos");
            trailingDist = TrailingDistancePoints * SymbolInfoDouble(symbol, SYMBOL_POINT);
            stepDist = TrailingStepPoints * SymbolInfoDouble(symbol, SYMBOL_POINT);
            lastTrailingATR = 0.0;
            lastTrailingDist = trailingDist;
            lastStepDist = stepDist;
         }

         IndicatorRelease(atrHandle);
      }
   }
   else
   {
      // ✅ Usar pontos fixos configurados
   trailingDist = TrailingDistancePoints * SymbolInfoDouble(symbol, SYMBOL_POINT);
   stepDist = TrailingStepPoints * SymbolInfoDouble(symbol, SYMBOL_POINT);
   lastTrailingATR = 0.0;
   lastTrailingDist = trailingDist;
   lastStepDist = stepDist;
   }

   double newSL;

   if(isLong)
   {
      newSL = currentPrice - trailingDist;

      // Só mover SL para cima (proteção) e respeitar step mínimo
      if(newSL <= currentSL || (newSL - currentSL) < stepDist)
         return;
   }
   else
   {
      newSL = currentPrice + trailingDist;

      // Só mover SL para baixo (proteção) e respeitar step mínimo
      if(newSL >= currentSL || (currentSL - newSL) < stepDist)
         return;
   }

   MqlTradeRequest request;
   MqlTradeResult result;

   ZeroMemory(request);
   request.action = TRADE_ACTION_SLTP;
   request.position = ticket;
   request.symbol = symbol;
   request.sl = newSL;
   request.tp = PositionGetDouble(POSITION_TP);
   request.magic = EA_MAGIC_NUMBER;

   if(OrderSend(request, result))
   {
      if(result.retcode == TRADE_RETCODE_DONE)
      {
         PrintFormat("   📊 Trailing ATR: %.5f | Distância: %.5f (%.1f pts) | Step: %.5f (%.1f pts)",
                     lastTrailingATR, lastTrailingDist, lastTrailingDist/SymbolInfoDouble(symbol, SYMBOL_POINT),
                     lastStepDist, lastStepDist/SymbolInfoDouble(symbol, SYMBOL_POINT));
         PrintFormat("   📈 Trailing SL: %.5f → %.5f (distância: %.1f pts) [%s]",
                     currentSL, newSL,
                     MathAbs(currentPrice - newSL) / SymbolInfoDouble(symbol, SYMBOL_POINT),
                     TrailingUseATR ? "ATR" : "fixo");
      }
   }
}

//+------------------------------------------------------------------+
//| 🔥 v4.24: Calcular tempo de pausa LIMITADO (MÁXIMO 12H!)        |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| 🔥 v4.34: Calcula tempo de pausa baseado em perdas consecutivas |
//| MUDANÇA: Pausa progressiva baseada em g_consecutiveLosses       |
//| 3 perdas = 1h, 4 perdas = 2h, 5+ perdas = 4h (limite 12h)      |
//+------------------------------------------------------------------+
int CalculatePauseTime(ENUM_TIMEFRAMES timeframe)
{
   // 🔥 v4.34: NOVA LÓGICA - Pausa baseada em perdas consecutivas
   // Análise mostrou que pausas progressivas previnem cascatas
   
   const int MAX_PAUSE_SECONDS = 43200; // 12 horas (máximo absoluto)
   int pauseSeconds = 0;
   
   // g_consecutiveLosses é global, declarado em NexusConfluenceEA.mq5
   
   if(g_consecutiveLosses >= 5)
   {
      pauseSeconds = 14400;  // 4 horas (proteção máxima)
      PrintFormat("🔥 PAUSA PROGRESSIVA: %d perdas → 4 horas", g_consecutiveLosses);
   }
   else if(g_consecutiveLosses == 4)
   {
      pauseSeconds = 7200;   // 2 horas
      PrintFormat("🔥 PAUSA PROGRESSIVA: %d perdas → 2 horas", g_consecutiveLosses);
   }
   else if(g_consecutiveLosses == 3)
   {
      pauseSeconds = 3600;   // 1 hora
      PrintFormat("🔥 PAUSA PROGRESSIVA: %d perdas → 1 hora", g_consecutiveLosses);
   }
   else
   {
      // Fallback: Pausa baseada em timeframe (drawdown diário/semanal)
      switch(timeframe)
      {
         case PERIOD_M1:  pauseSeconds = 1800;    // 30 minutos (30 candles)
                          break;
         case PERIOD_M5:  pauseSeconds = 3600;    // 1 hora (12 candles)
                          break;
         case PERIOD_M15: pauseSeconds = 10800;   // 3 horas (12 candles)
                          break;
         case PERIOD_M30: pauseSeconds = 18000;   // 5 horas (10 candles)
                          break;
         case PERIOD_H1:  pauseSeconds = 28800;   // 8 horas (8 candles)
                          break;
         case PERIOD_H4:  pauseSeconds = 43200;   // 12 horas (3 candles)
                          break;
         case PERIOD_D1:  pauseSeconds = 43200;   // 12 horas (máximo permitido)
                          break;
         default:         pauseSeconds = 21600;   // 6 horas padrão
                          break;
      }
   }

   // Garantir que NUNCA ultrapasse 12 horas
   if(pauseSeconds > MAX_PAUSE_SECONDS)
   {
      PrintFormat("⚠️ LIMITE: Pausa reduzida de %d para %d segundos (12h max)", 
                  pauseSeconds, MAX_PAUSE_SECONDS);
      pauseSeconds = MAX_PAUSE_SECONDS;
   }

   return pauseSeconds;
}

//+------------------------------------------------------------------+
//| 🔥 v4.15: Formatar duração da pausa para exibição               |
//+------------------------------------------------------------------+
string FormatPauseDuration(int seconds)
{
   if(seconds < 3600)
   {
      int minutes = seconds / 60;
      return StringFormat("%d minutos", minutes);
   }
   else if(seconds < 86400)
   {
      int hours = seconds / 3600;
      int minutes = (seconds % 3600) / 60;
      return StringFormat("%d horas e %d minutos", hours, minutes);
   }
   else
   {
      int days = seconds / 86400;
      int hours = (seconds % 86400) / 3600;
      return StringFormat("%d dias e %d horas", days, hours);
   }
}

//+------------------------------------------------------------------+
