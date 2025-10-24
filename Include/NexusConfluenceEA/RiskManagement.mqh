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
   trade.SetDeviationInPoints(30);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   
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
      
      PrintFormat("🔵 BUY %s | Lote: %.2f | Entry: %.5f | SL: %.5f (%.0f pts) | TP: %.5f (%.0f pts)",
         symbol, lotSize, entryPrice, sl, slPoints, tp, tpPoints);
      
      if(!trade.Buy(lotSize, symbol, entryPrice, sl, tp, comment))
      {
         PrintFormat("❌ Erro ao executar BUY: %d - %s", 
            GetLastError(), trade.ResultRetcodeDescription());
         return false;
      }
   }
   else
   {
      entryPrice = bid;
      sl = entryPrice + (slPoints * point);
      tp = entryPrice - (tpPoints * point);
      
      PrintFormat("🔴 SELL %s | Lote: %.2f | Entry: %.5f | SL: %.5f (%.0f pts) | TP: %.5f (%.0f pts)",
         symbol, lotSize, entryPrice, sl, slPoints, tp, tpPoints);
      
      if(!trade.Sell(lotSize, symbol, entryPrice, sl, tp, comment))
      {
         PrintFormat("❌ Erro ao executar SELL: %d - %s", 
            GetLastError(), trade.ResultRetcodeDescription());
         return false;
      }
   }
   
   PrintFormat("✅ Ordem executada com sucesso! Ticket: %d", trade.ResultOrder());
   return true;
}

//+------------------------------------------------------------------+
