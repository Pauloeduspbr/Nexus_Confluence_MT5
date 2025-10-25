//+------------------------------------------------------------------+
//| RiskManagement_SIMPLE.mqh - VERSÃO SIMPLIFICADA                  |
//| Nexus Confluence EA v4.40 - Gestão Básica Simplificada          |
//|                                                                   |
//| PROPÓSITO: Executar ordens com SL/TP fixos e lote fixo          |
//|                                                                   |
//| 🔥 v4.40: SIMPLIFICAÇÃO RADICAL                                  |
//|   - Removido: Cálculo automático de lote                        |
//|   - Removido: SL estrutural                                      |
//|   - Removido: Breakeven                                          |
//|   - Removido: Trailing Stop                                      |
//|   - Removido: TP parcial                                         |
//|   - Mantido: Apenas execução com SL/TP fixos                    |
//|                                                                   |
//| FUNÇÕES:                                                         |
//|   - ExecuteSimpleTrade(): Executa ordem BUY/SELL simples        |
//|   - NormalizeLot(): Normaliza lote para o símbolo              |
//|                                                                   |
//| AUTOR: GitHub Copilot + Desenvolvedor                            |
//| DATA: Outubro 2025                                               |
//| VERSÃO: 4.40 - SIMPLIFICADO                                     |
//+------------------------------------------------------------------+
#property copyright "Nexus Confluence EA v4.40"
#property version   "4.40"

#include "Parametros.mqh"
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Normaliza lote para o símbolo                                   |
//+------------------------------------------------------------------+
double NormalizeLot(string symbol, double lot)
{
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
   // Normalizar para step
   lot = MathFloor(lot / lotStep) * lotStep;
   
   // Validar limites
   if(lot < minLot) lot = minLot;
   if(lot > maxLot) lot = maxLot;
   
   return NormalizeDouble(lot, 2);
}

//+------------------------------------------------------------------+
//| Executa ordem simples com SL/TP fixos                           |
//| ENTRADA:                                                         |
//|   - symbol: Símbolo (ex: "USDJPY")                              |
//|   - isBuy: true para BUY, false para SELL                       |
//|   - lotSize: Lote fixo                                          |
//|   - slPoints: Stop Loss em pontos                               |
//|   - tpPoints: Take Profit em pontos                             |
//|   - magicNumber: Magic number                                    |
//|   - comment: Comentário da ordem                                |
//| RETORNO:                                                         |
//|   - true se ordem executada com sucesso                         |
//+------------------------------------------------------------------+
bool ExecuteSimpleTrade(
   string symbol,
   bool isBuy,
   double lotSize,
   double slPoints,
   double tpPoints,
   int magicNumber,
   string comment = "Nexus Basic"
)
{
   CTrade trade;
   trade.SetExpertMagicNumber(magicNumber);
   trade.SetDeviationInPoints(MaxSlippagePoints);  // ✅ v4.42: ANTI-HARDCODE
   trade.SetTypeFilling(OrderFillingMode);          // ✅ v4.42: ANTI-HARDCODE
   
   // Normalizar lote
   lotSize = NormalizeLot(symbol, lotSize);
   
   // Validar lote
   if(lotSize < SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN))
   {
      PrintFormat("❌ Lote %.2f abaixo do mínimo %.2f", 
         lotSize, SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN));
      return false;
   }
   
   // Obter preço atual
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   if(ask == 0 || bid == 0 || point == 0)
   {
      PrintFormat("❌ Erro ao obter dados do símbolo %s", symbol);
      return false;
   }
   
   // Calcular SL e TP
   double sl = 0, tp = 0;
   double entryPrice = 0;
   
   if(isBuy)
   {
      entryPrice = ask;
      sl = entryPrice - (slPoints * point);
      tp = entryPrice + (tpPoints * point);
      
      PrintFormat("\n══════════════════════════════════════════════════════════════");
      PrintFormat("🔵 ABERTURA DE COMPRA (BUY)");
      PrintFormat("══════════════════════════════════════════════════════════════");
      PrintFormat("📊 Símbolo: %s", symbol);
      PrintFormat("💰 Lote: %.2f", lotSize);
      PrintFormat("📈 Preço Entrada: %.5f", entryPrice);
      PrintFormat("🛑 Stop Loss: %.5f (%.0f pontos / %.2f pips)", sl, slPoints, slPoints/10);
      PrintFormat("🎯 Take Profit: %.5f (%.0f pontos / %.2f pips)", tp, tpPoints, tpPoints/10);
      PrintFormat("💬 Comentário: %s", comment);
      PrintFormat("══════════════════════════════════════════════════════════════\n");
      
      if(!trade.Buy(lotSize, symbol, entryPrice, sl, tp, comment))
      {
         PrintFormat("❌ ERRO ao executar COMPRA: %d - %s", 
            GetLastError(), trade.ResultRetcodeDescription());
         return false;
      }
   }
   else
   {
      entryPrice = bid;
      sl = entryPrice + (slPoints * point);
      tp = entryPrice - (tpPoints * point);
      
      PrintFormat("\n══════════════════════════════════════════════════════════════");
      PrintFormat("🔴 ABERTURA DE VENDA (SELL)");
      PrintFormat("══════════════════════════════════════════════════════════════");
      PrintFormat("📊 Símbolo: %s", symbol);
      PrintFormat("💰 Lote: %.2f", lotSize);
      PrintFormat("📉 Preço Entrada: %.5f", entryPrice);
      PrintFormat("🛑 Stop Loss: %.5f (%.0f pontos / %.2f pips)", sl, slPoints, slPoints/10);
      PrintFormat("🎯 Take Profit: %.5f (%.0f pontos / %.2f pips)", tp, tpPoints, tpPoints/10);
      PrintFormat("💬 Comentário: %s", comment);
      PrintFormat("══════════════════════════════════════════════════════════════\n");
      
      if(!trade.Sell(lotSize, symbol, entryPrice, sl, tp, comment))
      {
         PrintFormat("❌ ERRO ao executar VENDA: %d - %s", 
            GetLastError(), trade.ResultRetcodeDescription());
         return false;
      }
   }
   
   ulong ticket = trade.ResultOrder();
   PrintFormat("✅ Ordem executada com sucesso! Ticket: %I64u", ticket);
   PrintFormat("⏰ Horário: %s\n", TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS));
   
   return true;
}

//+------------------------------------------------------------------+
//| Monitora fechamento de posições e registra resultado            |
//+------------------------------------------------------------------+
void CheckClosedPositions(ulong &lastTicket, double &lastOpenPrice, string &lastType)
{
   // Verificar se tinha posição aberta
   if(lastTicket == 0)
      return;
   
   // Verificar se posição ainda existe
   bool positionExists = false;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == lastTicket)
      {
         positionExists = true;
         break;
      }
   }
   
   // Se posição não existe mais, foi fechada
   if(!positionExists)
   {
      // Buscar dados da posição fechada no histórico
      HistorySelect(0, TimeCurrent());
      
      for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
      {
         ulong dealTicket = HistoryDealGetTicket(i);
         if(dealTicket == 0) continue;
         
         long dealEntry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
         ulong dealPosition = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
         
         // Se é deal de saída e corresponde à nossa posição
         if(dealEntry == DEAL_ENTRY_OUT && dealPosition == lastTicket)
         {
            double closePrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
            double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
            double volume = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
            string symbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
            datetime closeTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
            
            // Calcular pips
            double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
            double priceDiff = 0;
            
            if(lastType == "BUY")
               priceDiff = closePrice - lastOpenPrice;
            else
               priceDiff = lastOpenPrice - closePrice;
            
            double pips = (priceDiff / point) / 10; // Converter para pips
            
            // Determinar motivo do fechamento
            string closeReason = "Manual";
            if(profit > 0)
               closeReason = "Take Profit";
            else if(profit < 0)
               closeReason = "Stop Loss";
            
            // Log detalhado
            PrintFormat("\n══════════════════════════════════════════════════════════════");
            PrintFormat("%s FECHAMENTO DE %s", 
               profit > 0 ? "💚" : "❌", 
               lastType);
            PrintFormat("══════════════════════════════════════════════════════════════");
            PrintFormat("🎫 Ticket: %I64u", lastTicket);
            PrintFormat("📊 Símbolo: %s", symbol);
            PrintFormat("💰 Volume: %.2f", volume);
            PrintFormat("📈 Preço Abertura: %.5f", lastOpenPrice);
            PrintFormat("📉 Preço Fechamento: %.5f", closePrice);
            PrintFormat("📏 Diferença: %.1f pips (%s%.5f)", 
               MathAbs(pips), 
               priceDiff >= 0 ? "+" : "", 
               priceDiff);
            PrintFormat("💵 Resultado: %s%.2f USD", 
               profit >= 0 ? "+" : "", 
               profit);
            PrintFormat("🏁 Motivo: %s", closeReason);
            PrintFormat("⏰ Horário: %s", TimeToString(closeTime, TIME_DATE|TIME_SECONDS));
            
            if(profit > 0)
            {
               PrintFormat("══════════════════════════════════════════════════════════════");
               PrintFormat("✅ TRADE VENCEDOR! 🎉");
               PrintFormat("══════════════════════════════════════════════════════════════\n");
            }
            else
            {
               PrintFormat("══════════════════════════════════════════════════════════════");
               PrintFormat("⚠️  TRADE PERDEDOR");
               PrintFormat("══════════════════════════════════════════════════════════════\n");
            }
            
            // Resetar variáveis de controle
            lastTicket = 0;
            lastOpenPrice = 0;
            lastType = "";
            
            break;
         }
      }
   }
}

//+------------------------------------------------------------------+
