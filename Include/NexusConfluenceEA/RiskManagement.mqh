//+------------------------------------------------------------------+
//| RiskManagement.mqh                                               |
//| Nexus Confluence EA v4.11 - Gestão de Risco e Posicionamento    |
//|                                                                   |
//| PROPÓSITO: Calcular tamanho de posição, SL, TP, Breakeven       |
//|            e Trailing Stop baseado em estrutura de preços        |
//|                                                                   |
//| NOVO v4.11: Correção crítica FindStructureSL()                   |
//|             Implementação completa de gestão de posições         |
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
//|                                                                   |
//| DEPENDÊNCIAS:                                                    |
//|   - Parametros.mqh (structs, enums, inputs)                     |
//|                                                                   |
//| AUTOR: GitHub Copilot + Desenvolvedor                            |
//| DATA: Outubro 2025                                               |
//| VERSÃO: 4.11 - Correção SL + Gestão Completa                    |
//+------------------------------------------------------------------+
#property copyright "Nexus Confluence EA v4.11"
#property version   "4.11"
#property strict

#include "Parametros.mqh"

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
   
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskPercent = (setupClass == SETUP_PREMIUM) ? MaxRiskPremium : AccountRiskPercent;
   
   PrintFormat("   💰 Saldo da conta: $%.2f", accountBalance);
   PrintFormat("   📊 Risco configurado: %.2f%% (Setup %s)", 
               riskPercent, 
               (setupClass == SETUP_PREMIUM) ? "PREMIUM" : "GOOD");
   
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
   
   if(requiredMargin > freeMargin * 0.7) // Usar no máximo 70% da margem
   {
      PrintFormat("❌ Margem insuficiente: Necessário $%.2f, Disponível $%.2f", requiredMargin, freeMargin);
      return false;
   }
   
   // Validar se SL não está muito longe
   double maxSLDistance = SL_MaxDistancePoints * _Point;
   if(risk.slDistance > maxSLDistance)
   {
      PrintFormat("⚠️ Aviso: SL muito distante (%.1f pontos), mas permitindo", risk.slDistance/_Point);
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
                        g_pauseUntilTime = TimeCurrent() + 86400; // Pausar 24 horas
                        string msg = StringFormat("🚨 %d PERDAS CONSECUTIVAS! Trading PAUSADO por 24 horas até %s",
                                                  g_consecutiveLosses,
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
   // 2. MOVER PARA BREAKEVEN - 🔥 v4.15: APENAS APÓS TP1 FECHADO
   // ════════════════════════════════════════════════════════════════
   if(!g_tradeStates[stateIdx].movedToBreakeven && 
      g_tradeStates[stateIdx].tp1Hit &&              // 🔥 NOVO: Só após TP1 fechado
      currentRR >= 1.2)                              // 🔥 NOVO: Em 1.2:1, não 1.0
   {
      if(MoveToBreakeven(ticket, openPrice, symbol))
      {
         g_tradeStates[stateIdx].movedToBreakeven = true;
         PrintFormat("✅ Trade #%I64u: SL movido para BREAKEVEN após TP1 (RR atual: %.2f)", ticket, currentRR);
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
   // 4. TRAILING STOP após TP1 ou quando configurado
   // ════════════════════════════════════════════════════════════════
   if(EnableTrailing && currentRR >= TrailingActivationRR)
   {
      // Ativar trailing automaticamente se atingiu RR mínimo
      if(!g_tradeStates[stateIdx].trailingActive)
      {
         g_tradeStates[stateIdx].trailingActive = true;
         PrintFormat("📈 Trade #%I64u: Trailing ATIVADO (RR: %.2f >= %.2f)", 
                     ticket, currentRR, TrailingActivationRR);
      }
      
      // Atualizar trailing stop
      UpdateTrailingStop(ticket, currentPrice, currentSL, isLong, symbol);
   }
   
   // Atualizar timestamp
   g_tradeStates[stateIdx].lastUpdate = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Mover SL para breakeven                                         |
//+------------------------------------------------------------------+
bool MoveToBreakeven(ulong ticket, double openPrice, string symbol)
{
   // Adicionar pequeno spread ao breakeven (garantir lucro mínimo)
   double spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD) * SymbolInfoDouble(symbol, SYMBOL_POINT);
   double newSL = openPrice + (spread * 0.5); // Breakeven + metade do spread
   
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
//| Atualizar trailing stop                                         |
//+------------------------------------------------------------------+
void UpdateTrailingStop(ulong ticket, double currentPrice, double currentSL, bool isLong, string symbol)
{
   double trailingDist = TrailingDistancePoints * SymbolInfoDouble(symbol, SYMBOL_POINT);
   double stepDist = TrailingStepPoints * SymbolInfoDouble(symbol, SYMBOL_POINT);
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
         PrintFormat("   📈 Trailing SL: %.5f → %.5f (distância: %.1f pts)", 
                     currentSL, newSL, MathAbs(currentPrice - newSL) / SymbolInfoDouble(symbol, SYMBOL_POINT));
      }
   }
}

//+------------------------------------------------------------------+
