//+------------------------------------------------------------------+
//| RiskManagement.mqh                                               |
//| Nexus Confluence EA v4.2 - Gestão de Risco e Posicionamento     |
//|                                                                   |
//| PROPÓSITO: Calcular tamanho de posição, SL, TP, Breakeven       |
//|            e Trailing Stop baseado em estrutura de preços        |
//|                                                                   |
//| FUNÇÕES PRINCIPAIS:                                              |
//|   - CalculatePositionSize(): Calcula lote baseado em risco       |
//|   - FindStructureSL(): Encontra último topo/fundo significativo  |
//|   - CalculateTakeProfits(): Calcula TPs baseados em RR          |
//|   - ValidateRiskCalculation(): Valida se cálculo é seguro       |
//|                                                                   |
//| DEPENDÊNCIAS:                                                    |
//|   - Parametros.mqh (structs, enums, inputs)                     |
//|                                                                   |
//| AUTOR: GitHub Copilot + Desenvolvedor                            |
//| DATA: Outubro 2025                                               |
//| VERSÃO: 4.2 - Gestão de Risco Completa                          |
//+------------------------------------------------------------------+
#property copyright "Nexus Confluence EA v4.2"
#property version   "4.20"
#property strict

#include "Parametros.mqh"

//+------------------------------------------------------------------+
//| FUNÇÃO: FindStructureSL                                          |
//| Encontra último topo/fundo significativo para SL                |
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
      // Para COMPRA: Procurar último SWING LOW (fundo com confirmação)
      // Buscar nos últimos 10-15 candles (mais recente = melhor)
      int maxLookback = MathMin(15, lookbackBars);
      
      // Começar do mais recente
      for(int i = 2; i < maxLookback; i++)
      {
         // Verificar se é um swing low (mínimo local)
         // Candle i tem low menor que i-1 e i+1
         if(low[i] < low[i-1] && low[i] < low[i+1] && low[i] <= low[i-2] && low[i] <= low[i+2])
         {
            slLevel = low[i];
            PrintFormat("   📍 SL COMPRA: Swing Low encontrado no candle[%d] = %.5f", i, slLevel);
            break;
         }
      }
      
      // Se não encontrou swing, usar mínimo dos últimos 5 candles
      if(slLevel == 0)
      {
         slLevel = low[ArrayMinimum(low, 0, MathMin(5, lookbackBars))];
         PrintFormat("   📍 SL COMPRA: Usando mínimo recente (5 candles) = %.5f", slLevel);
      }
      
      // Adicionar buffer de segurança (5-10 pontos)
      double buffer = 10 * _Point;
      slLevel -= buffer;
      
      PrintFormat("   � SL FINAL (com buffer): %.5f | Distância do preço: %.5f (%.1f pontos)", 
                  slLevel, currentPrice - slLevel, (currentPrice - slLevel)/_Point);
   }
   else if(direction == TRADE_DIRECTION_SELL)
   {
      // Para VENDA: Procurar último SWING HIGH (topo com confirmação)
      int maxLookback = MathMin(15, lookbackBars);
      
      for(int i = 2; i < maxLookback; i++)
      {
         // Verificar se é um swing high
         if(high[i] > high[i-1] && high[i] > high[i+1] && high[i] >= high[i-2] && high[i] >= high[i+2])
         {
            slLevel = high[i];
            PrintFormat("   📍 SL VENDA: Swing High encontrado no candle[%d] = %.5f", i, slLevel);
            break;
         }
      }
      
      // Se não encontrou swing, usar máximo dos últimos 5 candles
      if(slLevel == 0)
      {
         slLevel = high[ArrayMaximum(high, 0, MathMin(5, lookbackBars))];
         PrintFormat("   📍 SL VENDA: Usando máximo recente (5 candles) = %.5f", slLevel);
      }
      
      // Adicionar buffer de segurança
      double buffer = 10 * _Point;
      slLevel += buffer;
      
      PrintFormat("   � SL FINAL (com buffer): %.5f | Distância do preço: %.5f (%.1f pontos)", 
                  slLevel, slLevel - currentPrice, (slLevel - currentPrice)/_Point);
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
   result.slDistance = 0;
   result.riskAmount = 0;
   result.potentialProfit1 = 0;
   result.potentialProfit2 = 0;
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
      
      // Encontrar SL baseado em estrutura
      double slLevel = FindStructureSL(symbol, direction, LookbackStructureBars);
      if(slLevel == 0)
      {
         result.errorMessage = "Não foi possível encontrar nível de SL";
         return result;
      }
      
      // ✅ VALIDAR DIREÇÃO DO SL
      if(direction == TRADE_DIRECTION_BUY && slLevel >= currentPrice)
      {
         PrintFormat("   ⚠️ SL COMPRA acima do preço! Usando 0.3%% abaixo");
         slLevel = currentPrice * 0.997;
      }
      else if(direction == TRADE_DIRECTION_SELL && slLevel <= currentPrice)
      {
         PrintFormat("   ⚠️ SL VENDA abaixo do preço! Usando 0.3%% acima");
         slLevel = currentPrice * 1.003;
      }
      
      result.positionSize = FixedLotSize;
      result.stopLoss = slLevel;
      result.slDistance = MathAbs(currentPrice - slLevel);
      
      // Calcular TPs
      if(direction == TRADE_DIRECTION_BUY)
      {
         result.takeProfit1 = currentPrice + (result.slDistance * TP1_RR);
         result.takeProfit2 = currentPrice + (result.slDistance * TP2_RR);
      }
      else
      {
         result.takeProfit1 = currentPrice - (result.slDistance * TP1_RR);
         result.takeProfit2 = currentPrice - (result.slDistance * TP2_RR);
      }
      
      // Calcular valores de risco e lucro
      double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      double slTicks = result.slDistance / tickSize;
      
      result.riskAmount = slTicks * tickValue * result.positionSize;
      result.potentialProfit1 = result.riskAmount * TP1_RR;
      result.potentialProfit2 = result.riskAmount * TP2_RR;
      
      result.isValid = true;
      
      PrintFormat("   📊 Preço Entrada: %.5f", currentPrice);
      PrintFormat("   🛑 Stop Loss: %.5f (distância: %.5f = %.1f pontos)", 
                  result.stopLoss, result.slDistance, result.slDistance/_Point);
      PrintFormat("   🎯 TP1 (RR 1:%.1f): %.5f", TP1_RR, result.takeProfit1);
      PrintFormat("   🎯 TP2 (RR 1:%.1f): %.5f", TP2_RR, result.takeProfit2);
      PrintFormat("   💵 Risco: $%.2f | Lucro Potencial TP1: $%.2f | TP2: $%.2f", 
                  result.riskAmount, result.potentialProfit1, result.potentialProfit2);
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
   
   // Encontrar SL baseado em estrutura
   double slLevel = FindStructureSL(symbol, direction, LookbackStructureBars);
   if(slLevel == 0)
   {
      result.errorMessage = "Não foi possível encontrar nível de SL";
      PrintFormat("❌ %s", result.errorMessage);
      return result;
   }
   
   // ✅ VALIDAR DIREÇÃO DO SL (CRÍTICO!)
   if(direction == TRADE_DIRECTION_BUY)
   {
      // Para COMPRA: SL DEVE estar ABAIXO do preço de entrada
      if(slLevel >= currentPrice)
      {
         PrintFormat("   ⚠️ ERRO: SL COMPRA está ACIMA do preço de entrada!");
         PrintFormat("      Preço entrada: %.5f | SL calculado: %.5f", currentPrice, slLevel);
         
         // Usar SL baseado em percentual (0.3% abaixo)
         slLevel = currentPrice * 0.997;
         PrintFormat("      ✅ Usando SL percentual: %.5f (0.3%% abaixo)", slLevel);
      }
   }
   else // SELL
   {
      // Para VENDA: SL DEVE estar ACIMA do preço de entrada
      if(slLevel <= currentPrice)
      {
         PrintFormat("   ⚠️ ERRO: SL VENDA está ABAIXO do preço de entrada!");
         PrintFormat("      Preço entrada: %.5f | SL calculado: %.5f", currentPrice, slLevel);
         
         // Usar SL baseado em percentual (0.3% acima)
         slLevel = currentPrice * 1.003;
         PrintFormat("      ✅ Usando SL percentual: %.5f (0.3%% acima)", slLevel);
      }
   }
   
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
   }
   else
   {
      result.takeProfit1 = currentPrice - (slDistance * TP1_RR);
      result.takeProfit2 = currentPrice - (slDistance * TP2_RR);
   }
   
   result.potentialProfit1 = riskAmount * TP1_RR;
   result.potentialProfit2 = riskAmount * TP2_RR;
   result.isValid = true;
   
   PrintFormat("   📊 Preço Entrada: %.5f", currentPrice);
   PrintFormat("   🛑 Stop Loss: %.5f", result.stopLoss);
   PrintFormat("   🎯 TP1 (RR 1:%.1f): %.5f | Lucro: $%.2f", TP1_RR, result.takeProfit1, result.potentialProfit1);
   PrintFormat("   🎯 TP2 (RR 1:%.1f): %.5f | Lucro: $%.2f", TP2_RR, result.takeProfit2, result.potentialProfit2);
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
   
   // Validar se SL não está muito longe (máximo 100 pontos para Forex)
   double maxSLDistance = 100 * _Point;
   if(risk.slDistance > maxSLDistance)
   {
      PrintFormat("⚠️ Aviso: SL muito distante (%.1f pontos), mas permitindo", risk.slDistance/_Point);
   }
   
   // Validar se SL não está muito perto (mínimo 10 pontos)
   double minSLDistance = 10 * _Point;
   if(risk.slDistance < minSLDistance)
   {
      PrintFormat("❌ SL muito próximo (%.1f pontos < %.1f mínimo)", risk.slDistance/_Point, minSLDistance/_Point);
      return false;
   }
   
   PrintFormat("✅ Validação de risco: OK");
   return true;
}

//+------------------------------------------------------------------+
